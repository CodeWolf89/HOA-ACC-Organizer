// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import Foundation
import SQLite3
import CryptoKit

/// Describes SQLite open, execution, and availability failures.
enum StoreError: Error, LocalizedError {
    case open(String)
    case sql(String)
    case unavailable

    /// A localized description of the error suitable for display to the user.
    var errorDescription: String? {
        switch self {
        case .open(let value), .sql(let value): return value
        case .unavailable: return "Database is not open."
        }
    }
}

/// Reports whether an owner-master upsert inserted a lot and whether its address differed from existing data.
struct OwnerUpsertResult {
    /// The number of new records inserted by the operation.
    let inserted: Bool
    /// Indicates whether imported owner data disagreed with an existing nonblank property address.
    let addressMismatch: Bool
}

/// Owns the local SQLite database, attachment storage, migrations, queries, audit logging, imports, exports, and workflow mutations.
final class SQLiteStore {
    /// The active SQLite database handle, or `nil` while the store is closed.
    private var db: OpaquePointer?
    /// The serial dispatch queue that protects SQLite access and store mutations.
    private let queue = DispatchQueue(label: "org.smoketree.hoaacc.sqlite")
    /// The URL used for configured database url.
    private let configuredDatabaseURL: URL?
    /// The URL used for configured attachments directory url.
    private let configuredAttachmentsDirectoryURL: URL?

    /// Creates a database store. Production callers normally use the default
    /// locations in Application Support. Tests can inject isolated temporary
    /// locations so database and attachment behavior can be exercised without
    /// touching a user's real HOA records.
    /// - Parameters:
    ///   - databaseURL: Optional SQLite file URL. `nil` uses the app's normal database.
    ///   - attachmentsDirectoryURL: Optional directory for attachment files.
    init(
        databaseURL: URL? = nil,
        attachmentsDirectoryURL: URL? = nil
    ) {
        configuredDatabaseURL = databaseURL
        configuredAttachmentsDirectoryURL =
            attachmentsDirectoryURL
    }

    /// Releases resources owned by `OwnerUpsertResult` when the instance is deallocated.
    deinit {
        if db != nil { sqlite3_close(db) }
    }

    /// Opens the SQLite database, enables foreign keys and WAL mode, and runs
    /// all schema migrations required by the current application version.
    func open() throws {
        try queue.sync {
            guard db == nil else { return }

            let fm = FileManager.default
            let databaseURL: URL

            if let configuredDatabaseURL {
                databaseURL = configuredDatabaseURL
                try fm.createDirectory(
                    at: databaseURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
            } else {
                let base = try fm.url(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                ).appendingPathComponent("HOAACCOrganizer", isDirectory: true)

                try fm.createDirectory(at: base, withIntermediateDirectories: true)
                databaseURL = base.appendingPathComponent("hoa-acc.sqlite")
            }

            let path = databaseURL.path

            var handle: OpaquePointer?
            guard sqlite3_open_v2(
                path,
                &handle,
                SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
                nil
            ) == SQLITE_OK else {
                throw StoreError.open("Unable to open SQLite database.")
            }

            db = handle
            try execute("PRAGMA foreign_keys = ON;")
            _ = try scalar("PRAGMA journal_mode = WAL;")
            try migrate()
        }
    }

    /// Closes the SQLite connection if it is open. This is primarily useful for
    /// deterministic test teardown and is safe to call more than once.
    func close() {
        queue.sync {
            guard let db else { return }
            sqlite3_close(db)
            self.db = nil
        }
    }

    /// Creates or upgrades the SQLite schema required by the current application version.
    private func migrate() throws {
        try executeScript("""
        CREATE TABLE IF NOT EXISTS lots (
            id TEXT PRIMARY KEY,
            lot_number TEXT NOT NULL UNIQUE,
            owner_name TEXT NOT NULL DEFAULT '',
            primary_address TEXT NOT NULL DEFAULT '',
            billing_address TEXT NOT NULL DEFAULT '',
            primary_phone TEXT NOT NULL DEFAULT '',
            secondary_phone TEXT NOT NULL DEFAULT '',
            primary_email TEXT NOT NULL DEFAULT '',
            secondary_email TEXT NOT NULL DEFAULT '',
            is_rental_unit INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS violations (
            id TEXT PRIMARY KEY,
            lot_id TEXT NOT NULL REFERENCES lots(id) ON DELETE CASCADE,
            observed_at TEXT,
            correction_deadline TEXT,
            created_at TEXT,
            escalation_date TEXT,
            final_warning_date TEXT,
            resolved_date TEXT,
            inspector_name TEXT NOT NULL DEFAULT '',
            notes TEXT NOT NULL DEFAULT '',
            status TEXT NOT NULL DEFAULT '',
            source_hash TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_violations_lot ON violations(lot_id);
        CREATE INDEX IF NOT EXISTS idx_violations_status ON violations(status);

        CREATE TABLE IF NOT EXISTS violation_rules (
            violation_id TEXT NOT NULL REFERENCES violations(id) ON DELETE CASCADE,
            rule_id TEXT NOT NULL,
            title TEXT NOT NULL DEFAULT '',
            category TEXT NOT NULL DEFAULT '',
            rule_section TEXT NOT NULL DEFAULT '',
            correction_days INTEGER,
            notice_text TEXT NOT NULL DEFAULT '',
            corrective_action TEXT NOT NULL DEFAULT '',
            rule_text TEXT NOT NULL DEFAULT '',
            PRIMARY KEY (violation_id, rule_id)
        );

        CREATE TABLE IF NOT EXISTS attachments (
            id TEXT PRIMARY KEY,
            lot_id TEXT REFERENCES lots(id) ON DELETE CASCADE,
            violation_id TEXT REFERENCES violations(id) ON DELETE CASCADE,
            acc_request_id TEXT,
            kind TEXT NOT NULL,
            file_name TEXT NOT NULL,
            original_file_name TEXT NOT NULL DEFAULT '',
            mime_type TEXT NOT NULL DEFAULT '',
            content_hash TEXT NOT NULL,
            captured_at TEXT,
            caption TEXT NOT NULL DEFAULT '',
            created_at TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS import_batches (
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            source_file_name TEXT NOT NULL,
            source_exported_at TEXT,
            imported_at TEXT NOT NULL,
            record_count INTEGER NOT NULL,
            content_hash TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS change_journal (
            id TEXT PRIMARY KEY,
            entity_type TEXT NOT NULL,
            entity_id TEXT NOT NULL,
            operation TEXT NOT NULL,
            device_id TEXT NOT NULL,
            revision INTEGER NOT NULL,
            changed_at TEXT NOT NULL,
            payload TEXT NOT NULL,
            is_sent INTEGER NOT NULL DEFAULT 0
        );

        CREATE TABLE IF NOT EXISTS sync_state (
            id INTEGER PRIMARY KEY CHECK(id=1),
            last_successful_sync_at TEXT,
            last_sync_method TEXT NOT NULL DEFAULT '',
            last_peer_name TEXT NOT NULL DEFAULT ''
        );

        INSERT OR IGNORE INTO sync_state(
            id,last_successful_sync_at,last_sync_method,last_peer_name
        ) VALUES(1,NULL,'','');

        CREATE TABLE IF NOT EXISTS backup_history (
            id TEXT PRIMARY KEY,
            created_at TEXT NOT NULL,
            file_name TEXT NOT NULL,
            attachment_count INTEGER NOT NULL DEFAULT 0
        );

        CREATE TABLE IF NOT EXISTS acc_requests (
            id TEXT PRIMARY KEY,
            lot_id TEXT NOT NULL REFERENCES lots(id) ON DELETE CASCADE,
            applicant_name TEXT NOT NULL DEFAULT '',
            applicant_phone TEXT NOT NULL DEFAULT '',
            proposed_change_address TEXT NOT NULL DEFAULT '',
            description TEXT NOT NULL DEFAULT '',
            color TEXT NOT NULL DEFAULT '',
            proposed_start_date TEXT,
            proposed_completion_date TEXT,
            submitted_at TEXT,
            imported_at TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'Draft',
            acc_recommendation TEXT NOT NULL DEFAULT '',
            remarks TEXT NOT NULL DEFAULT '',
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );
        """)

        try ensureColumn(table: "lots", column: "primary_phone", definition: "TEXT NOT NULL DEFAULT ''")
        try ensureColumn(table: "lots", column: "secondary_phone", definition: "TEXT NOT NULL DEFAULT ''")
        try ensureColumn(table: "lots", column: "primary_email", definition: "TEXT NOT NULL DEFAULT ''")
        try ensureColumn(table: "lots", column: "secondary_email", definition: "TEXT NOT NULL DEFAULT ''")

        // Phase Two ACC application fields.
        try ensureColumn(table: "acc_requests", column: "applicant_signature", definition: "TEXT NOT NULL DEFAULT ''")
        try ensureColumn(table: "acc_requests", column: "applicant_signature_date", definition: "TEXT")
        try ensureColumn(table: "acc_requests", column: "chairperson_signature", definition: "TEXT NOT NULL DEFAULT ''")
        try ensureColumn(table: "acc_requests", column: "chairperson_signature_date", definition: "TEXT")
        try ensureColumn(table: "acc_requests", column: "source_ocr_text", definition: "TEXT NOT NULL DEFAULT ''")
        try ensureColumn(table: "acc_requests", column: "imported_at", definition: "TEXT NOT NULL DEFAULT ''")
        try ensureColumn(table: "violations", column: "fee_assessment_date", definition: "TEXT")
        try ensureColumn(table: "violations", column: "admin_notes", definition: "TEXT NOT NULL DEFAULT ''")
        try ensureColumn(table: "violation_rules", column: "correction_days", definition: "INTEGER")

        try executeScript("""
        CREATE TABLE IF NOT EXISTS acc_neighbors (
            id TEXT PRIMARY KEY,
            acc_request_id TEXT NOT NULL REFERENCES acc_requests(id) ON DELETE CASCADE,
            sort_order INTEGER NOT NULL,
            name TEXT NOT NULL DEFAULT '',
            address TEXT NOT NULL DEFAULT '',
            lot_number TEXT NOT NULL DEFAULT '',
            signature_observed INTEGER NOT NULL DEFAULT 0
        );

        CREATE INDEX IF NOT EXISTS idx_acc_requests_lot
        ON acc_requests(lot_id);

        CREATE INDEX IF NOT EXISTS idx_acc_neighbors_request
        ON acc_neighbors(acc_request_id);

        CREATE TABLE IF NOT EXISTS violation_actions (
            id TEXT PRIMARY KEY,
            violation_id TEXT NOT NULL REFERENCES violations(id) ON DELETE CASCADE,
            from_status TEXT NOT NULL DEFAULT '',
            to_status TEXT NOT NULL DEFAULT '',
            notes TEXT NOT NULL DEFAULT '',
            changed_at TEXT NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_violation_actions_violation
        ON violation_actions(violation_id);

        CREATE TABLE IF NOT EXISTS users (
            id TEXT PRIMARY KEY,
            username TEXT NOT NULL UNIQUE COLLATE NOCASE,
            display_name TEXT NOT NULL,
            role TEXT NOT NULL DEFAULT 'admin',
            password_hash TEXT NOT NULL,
            password_salt TEXT NOT NULL,
            password_iterations INTEGER NOT NULL,
            is_active INTEGER NOT NULL DEFAULT 1,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            last_login_at TEXT
        );

        CREATE TABLE IF NOT EXISTS audit_log (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            username TEXT NOT NULL,
            action TEXT NOT NULL,
            entity_type TEXT NOT NULL,
            entity_id TEXT NOT NULL,
            before_json TEXT NOT NULL DEFAULT '{}',
            after_json TEXT NOT NULL DEFAULT '{}',
            changed_at TEXT NOT NULL,
            device_id TEXT NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_audit_log_entity
        ON audit_log(entity_type, entity_id, changed_at);

        CREATE INDEX IF NOT EXISTS idx_audit_log_user
        ON audit_log(user_id, changed_at);

        CREATE TABLE IF NOT EXISTS deletion_tombstones (
            entity_type TEXT NOT NULL,
            entity_id TEXT NOT NULL,
            deleted_at TEXT NOT NULL,
            username TEXT NOT NULL,
            reason TEXT NOT NULL,
            PRIMARY KEY(entity_type, entity_id)
        );

        CREATE INDEX IF NOT EXISTS idx_deletion_tombstones_date
        ON deletion_tombstones(deleted_at);
        """)
    }

    /// Adds a SQLite column when it is not already present, allowing idempotent schema migration.
    private func ensureColumn(table: String, column: String, definition: String) throws {
        var exists = false
        try rows("PRAGMA table_info(\(table));") { stmt in
            if text(stmt, 1) == column { exists = true }
        }
        if !exists {
            try execute("ALTER TABLE \(table) ADD COLUMN \(column) \(definition);")
        }
    }

    /// Executes a closure inside a SQLite transaction and rolls back if any operation throws.
    func transaction<T>(_ block: () throws -> T) throws -> T {
        try queue.sync {
            try execute("BEGIN IMMEDIATE;")
            do {
                let value = try block()
                try execute("COMMIT;")
                return value
            } catch {
                try? execute("ROLLBACK;")
                throw error
            }
        }
    }

    /// Executes a multi-statement SQLite script using `sqlite3_exec`.
    func executeScript(_ sql: String) throws {
        guard let db else { throw StoreError.unavailable }

        var errorMessage: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(db, sql, nil, nil, &errorMessage)

        if result != SQLITE_OK {
            let value = errorMessage.map { String(cString: $0) } ?? message()
            sqlite3_free(errorMessage)
            throw StoreError.sql(value)
        }
    }

    /// Executes a parameterized SQLite statement and accepts statements that return rows or complete normally.
    func execute(_ sql: String, bindings: [String?] = []) throws {
        guard let db else { throw StoreError.unavailable }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw StoreError.sql(message())
        }
        defer { sqlite3_finalize(stmt) }

        bind(bindings, to: stmt)

        let step = sqlite3_step(stmt)
        guard step == SQLITE_DONE || step == SQLITE_ROW else {
            throw StoreError.sql(message())
        }
    }

    /// Executes a query and returns the first column of the first row as text.
    func scalar(_ sql: String, bindings: [String?] = []) throws -> String? {
        guard let db else { throw StoreError.unavailable }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw StoreError.sql(message())
        }
        defer { sqlite3_finalize(stmt) }

        bind(bindings, to: stmt)

        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        guard let c = sqlite3_column_text(stmt, 0) else { return nil }
        return String(cString: c)
    }

    /// Executes a query and invokes the supplied row handler for each result row.
    private func rows(
        _ sql: String,
        bindings: [String?] = [],
        map: (OpaquePointer) throws -> Void
    ) throws {
        guard let db else { throw StoreError.unavailable }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw StoreError.sql(message())
        }
        defer { sqlite3_finalize(stmt) }

        bind(bindings, to: stmt)

        while sqlite3_step(stmt) == SQLITE_ROW {
            try map(stmt!)
        }
    }

    /// Binds Swift values to positional parameters on a prepared SQLite statement.
    private func bind(_ bindings: [String?], to stmt: OpaquePointer?) {
        for (i, value) in bindings.enumerated() {
            if let value {
                sqlite3_bind_text(stmt, Int32(i + 1), value, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, Int32(i + 1))
            }
        }
    }


    /// Fetches lot summaries from the local application data.
    func fetchLotSummaries(search: String) throws -> [LotSummary] {
        var result: [LotSummary] = []
        let pattern = "%\(search)%"

        try queue.sync {
            try rows("""
            SELECT
                l.id,
                l.lot_number,
                l.owner_name,
                l.primary_address,
                (
                    SELECT COUNT(*)
                    FROM violations v
                    WHERE v.lot_id = l.id
                      AND lower(v.status) NOT IN ('resolved','closed')
                ),
                (
                    SELECT COUNT(*)
                    FROM violations v
                    WHERE v.lot_id = l.id
                      AND lower(v.status) IN ('resolved','closed')
                ),
                (
                    SELECT COUNT(*)
                    FROM acc_requests a
                    WHERE a.lot_id = l.id
                      AND lower(a.status) IN (
                        'under review',
                        'pending',
                        'submitted',
                        'needs information'
                      )
                ),
                MAX(
                    COALESCE(
                        (
                            SELECT MAX(COALESCE(v.observed_at, v.created_at))
                            FROM violations v
                            WHERE v.lot_id = l.id
                        ),
                        ''
                    ),
                    COALESCE(
                        (
                            SELECT MAX(COALESCE(a.submitted_at, a.created_at))
                            FROM acc_requests a
                            WHERE a.lot_id = l.id
                        ),
                        ''
                    )
                )
            FROM lots l
            WHERE ? = '%%'
               OR l.lot_number LIKE ?
               OR l.owner_name LIKE ?
               OR l.primary_address LIKE ?
               OR l.primary_phone LIKE ?
               OR l.secondary_phone LIKE ?
               OR l.primary_email LIKE ?
               OR l.secondary_email LIKE ?
            ORDER BY CAST(l.lot_number AS INTEGER), l.lot_number
            """, bindings: [
                pattern, pattern, pattern, pattern,
                pattern, pattern, pattern, pattern
            ]) { stmt in
                result.append(
                    LotSummary(
                        id: text(stmt, 0),
                        lotNumber: text(stmt, 1),
                        ownerName: text(stmt, 2),
                        primaryAddress: text(stmt, 3),
                        openViolations: Int(sqlite3_column_int(stmt, 4)),
                        previousViolations: Int(sqlite3_column_int(stmt, 5)),
                        activeACCApplications: Int(sqlite3_column_int(stmt, 6)),
                        lastActivity: optionalText(stmt, 7)
                    )
                )
            }
        }

        return result
    }


    /// Fetches dashboard summary from the local application data.
    func fetchDashboardSummary() throws -> DashboardSummary {
        var propertiesWithViolations = 0
        var activeApplications = 0

        try queue.sync {
            propertiesWithViolations = Int(
                try scalar("""
                SELECT COUNT(DISTINCT lot_id)
                FROM violations
                WHERE lower(status) NOT IN ('resolved','closed')
                """) ?? "0"
            ) ?? 0

            activeApplications = Int(
                try scalar("""
                SELECT COUNT(*)
                FROM acc_requests
                WHERE lower(status) IN (
                    'under review',
                    'pending',
                    'submitted',
                    'needs information'
                )
                """) ?? "0"
            ) ?? 0
        }

        return DashboardSummary(
            propertiesWithActiveViolations: propertiesWithViolations,
            activeACCApplications: activeApplications
        )
    }

    /// Fetches lot from the local application data.
    func fetchLot(_ id: String) throws -> LotDetail? {
        var found: LotDetail?

        try queue.sync {
            try rows("""
            SELECT id, lot_number, owner_name, primary_address, billing_address,
                   primary_phone, secondary_phone, primary_email, secondary_email,
                   is_rental_unit
            FROM lots
            WHERE id = ?
            """, bindings: [id]) { stmt in
                found = LotDetail(
                    id: text(stmt, 0),
                    lotNumber: text(stmt, 1),
                    ownerName: text(stmt, 2),
                    primaryAddress: text(stmt, 3),
                    billingAddress: text(stmt, 4),
                    primaryPhone: text(stmt, 5),
                    secondaryPhone: text(stmt, 6),
                    primaryEmail: text(stmt, 7),
                    secondaryEmail: text(stmt, 8),
                    isRentalUnit: sqlite3_column_int(stmt, 9) != 0
                )
            }
        }

        return found
    }

    /// Creates violation and returns the resulting value when applicable.
    @discardableResult
    func createViolation(
        _ draft: ViolationCreationDraft
    ) throws -> String {
        guard
            try scalar(
                "SELECT id FROM lots WHERE id=? LIMIT 1",
                bindings: [draft.lotID]
            ) != nil
        else {
            throw StoreError.sql(
                "The selected property could not be found."
            )
        }

        guard !draft.rules.isEmpty else {
            throw StoreError.sql(
                "Select at least one violation rule."
            )
        }

        let now = ISODateStorage.now()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let sourceData = try encoder.encode(draft)
        let sourceHash =
            SHA256.hash(data: sourceData)
                .map {
                    String(
                        format: "%02x",
                        $0
                    )
                }
                .joined()

        var writtenFiles: [URL] = []

        do {
            try transaction {
                try execute("""
                INSERT INTO violations(
                    id,
                    lot_id,
                    observed_at,
                    correction_deadline,
                    created_at,
                    escalation_date,
                    final_warning_date,
                    fee_assessment_date,
                    resolved_date,
                    inspector_name,
                    notes,
                    admin_notes,
                    status,
                    source_hash,
                    updated_at
                ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
                """, bindings: [
                    draft.id,
                    draft.lotID,
                    ISODateStorage.string(
                        from: draft.observedAt
                    ),
                    ISODateStorage.string(
                        from: draft.correctionDeadline
                    ),
                    now,
                    nil,
                    nil,
                    nil,
                    nil,
                    draft.inspectorName,
                    draft.notes,
                    "",
                    "Open",
                    sourceHash,
                    now
                ])

                for rule in draft.rules {
                    try execute("""
                    INSERT INTO violation_rules(
                        violation_id,
                        rule_id,
                        title,
                        category,
                        rule_section,
                        correction_days,
                        notice_text,
                        corrective_action,
                        rule_text
                    ) VALUES(?,?,?,?,?,?,?,?,?)
                    """, bindings: [
                        draft.id,
                        rule.id,
                        rule.title,
                        rule.category,
                        rule.ruleSection,
                        String(
                            rule.correctionDays
                        ),
                        rule.noticeText,
                        rule.correctiveAction,
                        rule.ruleText
                    ])
                }

                for photo in draft.photos {
                    let hash =
                        SHA256.hash(
                            data: photo.imageData
                        )
                        .map {
                            String(
                                format: "%02x",
                                $0
                            )
                        }
                        .joined()

                    let fileName =
                        photo.id + ".jpg"

                    let url =
                        try attachmentURL(
                            fileName: fileName
                        )

                    try photo.imageData.write(
                        to: url,
                        options: .atomic
                    )

                    writtenFiles.append(url)

                    try execute("""
                    INSERT INTO attachments(
                        id,
                        lot_id,
                        violation_id,
                        acc_request_id,
                        kind,
                        file_name,
                        original_file_name,
                        mime_type,
                        content_hash,
                        captured_at,
                        caption,
                        created_at
                    ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?)
                    """, bindings: [
                        photo.id,
                        draft.lotID,
                        draft.id,
                        nil,
                        "violationPhoto",
                        fileName,
                        fileName,
                        "image/jpeg",
                        hash,
                        ISODateStorage.string(
                            from: photo.capturedAt
                        ),
                        photo.caption,
                        now
                    ])
                }

                try execute("""
                INSERT INTO violation_actions(
                    id,
                    violation_id,
                    from_status,
                    to_status,
                    notes,
                    changed_at
                ) VALUES(?,?,?,?,?,?)
                """, bindings: [
                    UUID().uuidString,
                    draft.id,
                    "",
                    "Open",
                    "Created in HOA ACC Organizer on iOS",
                    now
                ])

                try journal(
                    entityType: "violation",
                    entityID: draft.id,
                    operation: "create",
                    payload:
                        "{\"source\":\"Organizer iOS\"}"
                )
            }
        } catch {
            for url in writtenFiles {
                try? FileManager.default
                    .removeItem(at: url)
            }

            throw error
        }

        return draft.id
    }

    /// Fetches violations from the local application data.
    func fetchViolations(lotID: String) throws -> [ViolationListItem] {
        var result: [ViolationListItem] = []

        try queue.sync {
            try rows("""
            SELECT
                v.id,
                v.status,
                v.observed_at,
                v.correction_deadline,
                v.escalation_date,
                v.final_warning_date,
                v.fee_assessment_date,
                v.resolved_date,
                v.notes,
                v.admin_notes,
                COALESCE(GROUP_CONCAT(r.title, ', '), ''),
                (
                    SELECT COUNT(*)
                    FROM attachments a
                    WHERE a.violation_id=v.id
                      AND a.kind='violationPhoto'
                )
            FROM violations v
            LEFT JOIN violation_rules r
              ON r.violation_id=v.id
            WHERE v.lot_id=?
            GROUP BY v.id
            ORDER BY COALESCE(v.observed_at, v.created_at) DESC
            """, bindings: [lotID]) { stmt in
                result.append(
                    ViolationListItem(
                        id: text(stmt, 0),
                        status: text(stmt, 1),
                        observedAt: optionalText(stmt, 2),
                        correctionDeadline: optionalText(stmt, 3),
                        escalationDate: optionalText(stmt, 4),
                        finalWarningDate: optionalText(stmt, 5),
                        feeAssessmentDate: optionalText(stmt, 6),
                        resolvedDate: optionalText(stmt, 7),
                        notes: text(stmt, 8),
                        adminNotes: text(stmt, 9),
                        ruleTitles: text(stmt, 10),
                        photoCount: Int(sqlite3_column_int(stmt, 11))
                    )
                )
            }
        }

        return result
    }

    /// Fetches violation from the local application data.
    func fetchViolation(_ id: String) throws -> ViolationListItem? {
        var found: ViolationListItem?

        try queue.sync {
            try rows("""
            SELECT
                v.id,
                v.status,
                v.observed_at,
                v.correction_deadline,
                v.escalation_date,
                v.final_warning_date,
                v.fee_assessment_date,
                v.resolved_date,
                v.notes,
                v.admin_notes,
                COALESCE(GROUP_CONCAT(r.title, ', '), ''),
                (
                    SELECT COUNT(*)
                    FROM attachments a
                    WHERE a.violation_id=v.id
                      AND a.kind='violationPhoto'
                )
            FROM violations v
            LEFT JOIN violation_rules r
              ON r.violation_id=v.id
            WHERE v.id=?
            GROUP BY v.id
            """, bindings: [id]) { stmt in
                found = ViolationListItem(
                    id: text(stmt, 0),
                    status: text(stmt, 1),
                    observedAt: optionalText(stmt, 2),
                    correctionDeadline: optionalText(stmt, 3),
                    escalationDate: optionalText(stmt, 4),
                    finalWarningDate: optionalText(stmt, 5),
                    feeAssessmentDate: optionalText(stmt, 6),
                    resolvedDate: optionalText(stmt, 7),
                    notes: text(stmt, 8),
                    adminNotes: text(stmt, 9),
                    ruleTitles: text(stmt, 10),
                    photoCount: Int(sqlite3_column_int(stmt, 11))
                )
            }
        }

        return found
    }

    /// Fetches violation rules from the local application data.
    func fetchViolationRules(
        violationID: String
    ) throws -> [ViolationRuleDetail] {
        var result: [ViolationRuleDetail] = []

        try queue.sync {
            try rows("""
            SELECT
                rule_id,
                title,
                category,
                rule_section,
                notice_text,
                corrective_action,
                rule_text
            FROM violation_rules
            WHERE violation_id=?
            ORDER BY rule_section, title, rule_id
            """, bindings: [violationID]) { stmt in
                result.append(
                    ViolationRuleDetail(
                        id: text(stmt, 0),
                        title: text(stmt, 1),
                        category: text(stmt, 2),
                        ruleSection: text(stmt, 3),
                        noticeText: text(stmt, 4),
                        correctiveAction: text(stmt, 5),
                        ruleText: text(stmt, 6)
                    )
                )
            }
        }

        return result
    }

    /// Fetches violation actions from the local application data.
    func fetchViolationActions(
        violationID: String
    ) throws -> [ViolationAction] {
        var result: [ViolationAction] = []

        try queue.sync {
            try rows("""
            SELECT id, from_status, to_status, notes, changed_at
            FROM violation_actions
            WHERE violation_id=?
            ORDER BY changed_at DESC, id DESC
            """, bindings: [violationID]) { stmt in
                result.append(
                    ViolationAction(
                        id: text(stmt, 0),
                        fromStatus: text(stmt, 1),
                        toStatus: text(stmt, 2),
                        notes: text(stmt, 3),
                        changedAt: text(stmt, 4)
                    )
                )
            }
        }

        return result
    }

    /// Advances or resolves a violation, records enforcement history, journals the mutation, and writes an audit event.
    func adjudicateViolation(
        id: String,
        toStatus: String,
        notes: String,
        actor: AuthenticatedAdmin
    ) throws {
        let before =
            try fetchViolationAuditSnapshot(
                id: id
            )

        let now = ISODateStorage.now()

        try transaction {
            let currentStatus =
                try scalar(
                    "SELECT status FROM violations WHERE id=?",
                    bindings: [id]
                ) ?? ""

            switch toStatus {
            case "Escalated":
                try execute("""
                UPDATE violations
                SET status=?,
                    escalation_date=COALESCE(escalation_date, ?),
                    updated_at=?
                WHERE id=?
                """, bindings: [
                    toStatus, now, now, id
                ])

            case "Final Warning":
                try execute("""
                UPDATE violations
                SET status=?,
                    final_warning_date=COALESCE(final_warning_date, ?),
                    updated_at=?
                WHERE id=?
                """, bindings: [
                    toStatus, now, now, id
                ])

            case "Fee Assessment":
                try execute("""
                UPDATE violations
                SET status=?,
                    fee_assessment_date=COALESCE(fee_assessment_date, ?),
                    updated_at=?
                WHERE id=?
                """, bindings: [
                    toStatus, now, now, id
                ])

            case "Resolved":
                try execute("""
                UPDATE violations
                SET status=?,
                    resolved_date=COALESCE(resolved_date, ?),
                    updated_at=?
                WHERE id=?
                """, bindings: [
                    toStatus, now, now, id
                ])

            default:
                try execute("""
                UPDATE violations
                SET status=?, updated_at=?
                WHERE id=?
                """, bindings: [
                    toStatus, now, id
                ])
            }

            try execute("""
            INSERT INTO violation_actions(
                id,violation_id,from_status,to_status,notes,changed_at
            ) VALUES(?,?,?,?,?,?)
            """, bindings: [
                UUID().uuidString,
                id,
                currentStatus,
                toStatus,
                notes,
                now
            ])

            try journal(
                entityType: "violation",
                entityID: id,
                operation: "adjudicate",
                payload: """
                {"from":"\(currentStatus)","to":"\(toStatus)"}
                """
            )

            try recordAudit(
                actor: actor,
                action: "adjudicateViolation",
                entityType: "violation",
                entityID: id,
                beforeJSON: before,
                afterJSON:
                    fetchViolationAuditSnapshot(
                        id: id
                    )
            )
        }
    }

    /// Fetches open issues from the local application data.
    func fetchOpenIssues() throws -> [OpenIssue] {
        var result: [OpenIssue] = []

        try queue.sync {
            try rows("""
            SELECT
                issue_id,
                issue_kind,
                lot_id,
                lot_number,
                owner_name,
                title,
                status,
                sort_date
            FROM (
                SELECT
                    v.id AS issue_id,
                    'violation' AS issue_kind,
                    l.id AS lot_id,
                    l.lot_number AS lot_number,
                    l.owner_name AS owner_name,
                    COALESCE(
                        (
                            SELECT GROUP_CONCAT(vr.title, ', ')
                            FROM violation_rules vr
                            WHERE vr.violation_id=v.id
                        ),
                        'Violation'
                    ) AS title,
                    v.status AS status,
                    COALESCE(
                        v.correction_deadline,
                        v.observed_at,
                        v.created_at
                    ) AS sort_date
                FROM violations v
                JOIN lots l ON l.id=v.lot_id
                WHERE lower(v.status) NOT IN ('resolved','closed')

                UNION ALL

                SELECT
                    a.id AS issue_id,
                    'accApplication' AS issue_kind,
                    l.id AS lot_id,
                    l.lot_number AS lot_number,
                    l.owner_name AS owner_name,
                    CASE
                        WHEN trim(a.description) <> ''
                        THEN a.description
                        ELSE 'ACC Application'
                    END AS title,
                    a.status AS status,
                    COALESCE(
                        a.submitted_at,
                        a.created_at
                    ) AS sort_date
                FROM acc_requests a
                JOIN lots l ON l.id=a.lot_id
                WHERE lower(a.status) IN (
                    'under review',
                    'pending',
                    'submitted',
                    'needs information'
                )
            )
            ORDER BY
                CASE WHEN sort_date IS NULL OR sort_date='' THEN 1 ELSE 0 END,
                sort_date,
                CAST(lot_number AS INTEGER),
                issue_kind
            """) { stmt in
                let kindString = text(stmt, 1)

                guard let kind =
                    OpenIssue.Kind(rawValue: kindString)
                else {
                    return
                }

                result.append(
                    OpenIssue(
                        id: text(stmt, 0),
                        kind: kind,
                        lotID: text(stmt, 2),
                        lotNumber: text(stmt, 3),
                        ownerName: text(stmt, 4),
                        title: text(stmt, 5),
                        status: text(stmt, 6),
                        sortDate: optionalText(stmt, 7)
                    )
                )
            }
        }

        return result
    }


    /// Fetches violation attachments from the local application data.
    func fetchViolationAttachments(
        violationID: String
    ) throws -> [ViolationAttachment] {
        var result: [ViolationAttachment] = []

        try queue.sync {
            try rows("""
            SELECT id, file_name, mime_type, captured_at, caption
            FROM attachments
            WHERE violation_id = ?
              AND kind = 'violationPhoto'
            ORDER BY COALESCE(captured_at, created_at), id
            """, bindings: [violationID]) { stmt in
                result.append(
                    ViolationAttachment(
                        id: text(stmt, 0),
                        fileName: text(stmt, 1),
                        mimeType: text(stmt, 2),
                        capturedAt: optionalText(stmt, 3),
                        caption: text(stmt, 4)
                    )
                )
            }
        }

        return result
    }

    /// Fetches violation pdfreport data from the local application data.
    func fetchViolationPDFReportData(
        violationID: String
    ) throws -> ViolationPDFReportData? {
        guard
            let violation =
                try fetchViolation(
                    violationID
                )
        else {
            return nil
        }

        let rules =
            try fetchViolationRules(
                violationID:
                    violationID
            )

        let actions =
            try fetchViolationActions(
                violationID:
                    violationID
            )

        let attachments =
            try fetchViolationAttachments(
                violationID:
                    violationID
            )

        var lot: LotDetail?
        var inspectorName = ""

        try queue.sync {
            try rows("""
            SELECT
                l.id,
                l.lot_number,
                l.owner_name,
                l.primary_address,
                l.billing_address,
                l.primary_phone,
                l.secondary_phone,
                l.primary_email,
                l.secondary_email,
                l.is_rental_unit,
                v.inspector_name
            FROM violations v
            JOIN lots l
              ON l.id=v.lot_id
            WHERE v.id=?
            LIMIT 1
            """, bindings: [
                violationID
            ]) { stmt in
                lot =
                    LotDetail(
                        id: text(stmt, 0),
                        lotNumber: text(stmt, 1),
                        ownerName: text(stmt, 2),
                        primaryAddress: text(stmt, 3),
                        billingAddress: text(stmt, 4),
                        primaryPhone: text(stmt, 5),
                        secondaryPhone: text(stmt, 6),
                        primaryEmail: text(stmt, 7),
                        secondaryEmail: text(stmt, 8),
                        isRentalUnit:
                            sqlite3_column_int(
                                stmt,
                                9
                            ) != 0
                    )

                inspectorName =
                    text(stmt, 10)
            }
        }

        guard let lot else {
            return nil
        }

        let photos =
            attachments.compactMap {
                attachment ->
                    ViolationPDFPhotoData? in

                guard
                    let url =
                        try? attachmentURL(
                            fileName:
                                attachment
                                    .fileName
                        ),
                    FileManager.default
                        .fileExists(
                            atPath:
                                url.path
                        )
                else {
                    return nil
                }

                return
                    ViolationPDFPhotoData(
                        caption:
                            attachment
                                .caption,
                        capturedAt:
                            attachment
                                .capturedAt,
                        fileURL:
                            url
                    )
            }

        return
            ViolationPDFReportData(
                violation:
                    violation,
                lot:
                    lot,
                inspectorName:
                    inspectorName,
                rules:
                    rules,
                actions:
                    actions,
                photos:
                    photos
            )
    }

    /// Resolves an app-managed attachment filename to its on-disk Application Support URL.
    func attachmentURL(
        fileName: String
    ) throws -> URL {
        let fm = FileManager.default
        let base: URL

        if let configuredAttachmentsDirectoryURL {
            base = configuredAttachmentsDirectoryURL
        } else {
            let appSupport =
                try fm.url(
                    for:
                        .applicationSupportDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                )

            base =
                appSupport
                    .appendingPathComponent(
                        "HOAACCOrganizer",
                        isDirectory: true
                    )
                    .appendingPathComponent(
                        "Attachments",
                        isDirectory: true
                    )
        }

        try fm.createDirectory(
            at: base,
            withIntermediateDirectories: true
        )

        return base.appendingPathComponent(
            fileName
        )
    }

    /// Fetches import batches from the local application data.
    func fetchImportBatches() throws -> [ImportBatchSummary] {
        var result: [ImportBatchSummary] = []

        try queue.sync {
            try rows("""
            SELECT id,type,source_file_name,imported_at,record_count
            FROM import_batches
            ORDER BY imported_at DESC
            LIMIT 100
            """) { stmt in
                result.append(ImportBatchSummary(
                    id: text(stmt, 0),
                    type: text(stmt, 1),
                    sourceFileName: text(stmt, 2),
                    importedAt: text(stmt, 3),
                    recordCount: Int(sqlite3_column_int(stmt, 4))
                ))
            }
        }

        return result
    }

    /// Inserts or updates a lot using lot number as the canonical property identity.
    func upsertLot(property: PropertyPayload) throws -> String {
        let lotNumber = property.lotNumber?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !lotNumber.isEmpty else {
            throw StoreError.sql("Report is missing a lot number.")
        }

        let existingID = try scalar(
            "SELECT id FROM lots WHERE lot_number=?",
            bindings: [lotNumber]
        )

        let id = existingID ?? property.id ?? UUID().uuidString
        let now = ISODateStorage.now()

        if existingID == nil {
            try execute("""
            INSERT INTO lots(
              id,lot_number,owner_name,primary_address,billing_address,
              is_rental_unit,created_at,updated_at
            ) VALUES(?,?,?,?,?,?,?,?)
            """, bindings: [
                id,
                lotNumber,
                property.ownerName ?? "",
                property.primaryAddress ?? "",
                property.billingAddress ?? "",
                (property.isRentalUnit ?? false) ? "1" : "0",
                now,
                now
            ])
        } else {
            try execute("""
            UPDATE lots SET
              owner_name=CASE WHEN length(trim(?))>0 THEN ? ELSE owner_name END,
              primary_address=CASE WHEN length(trim(?))>0 THEN ? ELSE primary_address END,
              billing_address=CASE WHEN length(trim(?))>0 THEN ? ELSE billing_address END,
              is_rental_unit=CASE WHEN ? IS NOT NULL THEN ? ELSE is_rental_unit END,
              updated_at=?
            WHERE id=?
            """, bindings: [
                property.ownerName ?? "",
                property.ownerName ?? "",
                property.primaryAddress ?? "",
                property.primaryAddress ?? "",
                property.billingAddress ?? "",
                property.billingAddress ?? "",
                property.isRentalUnit == nil ? nil : "present",
                (property.isRentalUnit ?? false) ? "1" : "0",
                now,
                id
            ])
        }

        return id
    }

    /// Applies current owner/contact master data to a lot while preserving violation and ACC history.
    func upsertOwnerMaster(_ record: OwnerMasterRecord) throws -> OwnerUpsertResult {
        let lotNumber = String(record.lotNumber)
        let existingID = try scalar(
            "SELECT id FROM lots WHERE lot_number=?",
            bindings: [lotNumber]
        )
        let previousAddress = try scalar(
            "SELECT primary_address FROM lots WHERE lot_number=?",
            bindings: [lotNumber]
        ) ?? ""

        let now = ISODateStorage.now()
        let owner = clean(record.homeownerListing)
        let primaryAddress = clean(record.fullSmoketreeAddress)
        let billingAddress = clean(record.billingAddress)
        let primaryPhone = cleanPhone(record.primaryPhone)
        let secondaryPhone = cleanPhone(record.secondaryPhone)
        let primaryEmail = clean(record.primaryEmail).lowercased()
        let secondaryEmail = clean(record.secondaryEmail).lowercased()

        let mismatch =
            !previousAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            normalizeAddress(previousAddress) != normalizeAddress(primaryAddress)

        if let id = existingID {
            try execute("""
            UPDATE lots SET
              owner_name=?,
              primary_address=?,
              billing_address=?,
              primary_phone=?,
              secondary_phone=?,
              primary_email=?,
              secondary_email=?,
              is_rental_unit=?,
              updated_at=?
            WHERE id=?
            """, bindings: [
                owner,
                primaryAddress,
                billingAddress,
                primaryPhone,
                secondaryPhone,
                primaryEmail,
                secondaryEmail,
                record.isRentalUnit ? "1" : "0",
                now,
                id
            ])

            try journal(
                entityType: "lot",
                entityID: id,
                operation: "ownerMasterUpdate"
            )

            return OwnerUpsertResult(
                inserted: false,
                addressMismatch: mismatch
            )
        }

        let id = UUID().uuidString

        try execute("""
        INSERT INTO lots(
          id,lot_number,owner_name,primary_address,billing_address,
          primary_phone,secondary_phone,primary_email,secondary_email,
          is_rental_unit,created_at,updated_at
        ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?)
        """, bindings: [
            id,
            lotNumber,
            owner,
            primaryAddress,
            billingAddress,
            primaryPhone,
            secondaryPhone,
            primaryEmail,
            secondaryEmail,
            record.isRentalUnit ? "1" : "0",
            now,
            now
        ])

        try journal(
            entityType: "lot",
            entityID: id,
            operation: "ownerMasterInsert"
        )

        return OwnerUpsertResult(
            inserted: true,
            addressMismatch: false
        )
    }

    /// Updates owner while preserving workflow and audit requirements.
    func updateOwner(
        lotNumber: String,
        owner: String,
        address: String?
    ) throws -> Bool {
        let existing = try scalar(
            "SELECT id FROM lots WHERE lot_number=?",
            bindings: [lotNumber]
        )

        guard let id = existing else { return false }

        let now = ISODateStorage.now()

        try execute("""
        UPDATE lots SET
          owner_name=?,
          primary_address=CASE WHEN length(trim(?))>0 THEN ? ELSE primary_address END,
          updated_at=?
        WHERE id=?
        """, bindings: [
            owner,
            address ?? "",
            address ?? "",
            now,
            id
        ])

        try journal(
            entityType: "lot",
            entityID: id,
            operation: "update"
        )

        return true
    }

    /// Appends a record-level mutation to the change journal for synchronization and diagnostics.
    func journal(
        entityType: String,
        entityID: String,
        operation: String,
        payload: String = "{}"
    ) throws {
        let now = ISODateStorage.now()

        try execute("""
        INSERT INTO change_journal(
          id,entity_type,entity_id,operation,device_id,
          revision,changed_at,payload,is_sent
        ) VALUES(?,?,?,?,?,?,?,?,0)
        """, bindings: [
            UUID().uuidString,
            entityType,
            entityID,
            operation,
            ProcessInfo.processInfo.hostName,
            String(Int(Date().timeIntervalSince1970)),
            now,
            payload
        ])
    }

    /// Records metadata about a completed import operation.
    func insertImportBatch(
        id: String,
        type: String,
        fileName: String,
        exportedAt: String?,
        count: Int,
        hash: String
    ) throws {
        try execute("""
        INSERT OR IGNORE INTO import_batches(
          id,type,source_file_name,source_exported_at,
          imported_at,record_count,content_hash
        ) VALUES(?,?,?,?,?,?,?)
        """, bindings: [
            id,
            type,
            fileName,
            ISODateStorage.canonical(exportedAt),
            ISODateStorage.now(),
            String(count),
            hash
        ])
    }


    /// Fetches accrequests from the local application data.
    func fetchACCRequests(
        lotID: String
    ) throws -> [ACCRequestSummary] {
        var result: [ACCRequestSummary] = []

        try queue.sync {
            try rows("""
            SELECT id, lot_id, applicant_name, description,
                   status, submitted_at, imported_at, updated_at
            FROM acc_requests
            WHERE lot_id=?
            ORDER BY COALESCE(submitted_at, created_at) DESC
            """, bindings: [lotID]) { stmt in
                result.append(
                    ACCRequestSummary(
                        id: text(stmt, 0),
                        lotID: text(stmt, 1),
                        applicantName: text(stmt, 2),
                        description: text(stmt, 3),
                        status: text(stmt, 4),
                        submittedAt: optionalText(stmt, 5),
                        importedAt: text(stmt, 6),
                        updatedAt: text(stmt, 7)
                    )
                )
            }
        }

        return result
    }

    /// Fetches accrequest from the local application data.
    func fetchACCRequest(
        _ id: String
    ) throws -> ACCRequestDetail? {
        var base:
            (
                lotID: String,
                applicantName: String,
                applicantPhone: String,
                proposedChangeAddress: String,
                description: String,
                color: String,
                proposedStartDate: String?,
                proposedCompletionDate: String?,
                submittedAt: String?,
                importedAt: String,
                status: String,
                applicantSignature: String,
                applicantSignatureDate: String?,
                accRecommendation: String,
                remarks: String,
                chairpersonSignature: String,
                chairpersonSignatureDate: String?,
                createdAt: String,
                updatedAt: String
            )?

        try queue.sync {
            try rows("""
            SELECT lot_id, applicant_name, applicant_phone,
                   proposed_change_address, description, color,
                   proposed_start_date, proposed_completion_date,
                   submitted_at, imported_at, status, applicant_signature,
                   applicant_signature_date, acc_recommendation,
                   remarks, chairperson_signature,
                   chairperson_signature_date, created_at, updated_at
            FROM acc_requests
            WHERE id=?
            """, bindings: [id]) { stmt in
                base = (
                    text(stmt, 0),
                    text(stmt, 1),
                    text(stmt, 2),
                    text(stmt, 3),
                    text(stmt, 4),
                    text(stmt, 5),
                    optionalText(stmt, 6),
                    optionalText(stmt, 7),
                    optionalText(stmt, 8),
                    text(stmt, 9),
                    text(stmt, 10),
                    text(stmt, 11),
                    optionalText(stmt, 12),
                    text(stmt, 13),
                    text(stmt, 14),
                    text(stmt, 15),
                    optionalText(stmt, 16),
                    text(stmt, 17),
                    text(stmt, 18)
                )
            }
        }

        guard let base else {
            return nil
        }

        var neighbors: [ACCNeighbor] = []
        var pdfFileName: String?
        var pdfOriginalName: String?

        try queue.sync {
            try rows("""
            SELECT id, name, address, lot_number,
                   signature_observed
            FROM acc_neighbors
            WHERE acc_request_id=?
            ORDER BY sort_order
            """, bindings: [id]) { stmt in
                neighbors.append(
                    ACCNeighbor(
                        id: text(stmt, 0),
                        name: text(stmt, 1),
                        address: text(stmt, 2),
                        lotNumber: text(stmt, 3),
                        signatureObserved:
                            sqlite3_column_int(
                                stmt,
                                4
                            ) != 0
                    )
                )
            }

            try rows("""
            SELECT file_name, original_file_name
            FROM attachments
            WHERE acc_request_id=?
              AND kind='accApplicationPDF'
            ORDER BY created_at DESC
            LIMIT 1
            """, bindings: [id]) { stmt in
                pdfFileName = text(stmt, 0)
                pdfOriginalName = text(stmt, 1)
            }
        }

        return ACCRequestDetail(
            id: id,
            lotID: base.lotID,
            applicantName: base.applicantName,
            applicantPhone: base.applicantPhone,
            proposedChangeAddress:
                base.proposedChangeAddress,
            description: base.description,
            color: base.color,
            proposedStartDate:
                base.proposedStartDate,
            proposedCompletionDate:
                base.proposedCompletionDate,
            submittedAt: base.submittedAt,
            importedAt: base.importedAt,
            status: base.status,
            applicantSignature:
                base.applicantSignature,
            applicantSignatureDate:
                base.applicantSignatureDate,
            accRecommendation:
                base.accRecommendation,
            remarks: base.remarks,
            chairpersonSignature:
                base.chairpersonSignature,
            chairpersonSignatureDate:
                base.chairpersonSignatureDate,
            createdAt: base.createdAt,
            updatedAt: base.updatedAt,
            neighbors: neighbors,
            pdfFileName: pdfFileName,
            pdfOriginalName: pdfOriginalName
        )
    }

    /// Fetches accattachments from the local application data.
    func fetchACCAttachments(
        requestID: String
    ) throws -> [ACCAttachment] {
        var result: [ACCAttachment] = []

        try queue.sync {
            try rows("""
            SELECT
                id,
                kind,
                file_name,
                original_file_name,
                mime_type,
                content_hash,
                caption,
                created_at
            FROM attachments
            WHERE acc_request_id=?
            ORDER BY created_at DESC, id DESC
            """, bindings: [
                requestID
            ]) { stmt in
                result.append(
                    ACCAttachment(
                        id:
                            text(stmt, 0),
                        kind:
                            text(stmt, 1),
                        fileName:
                            text(stmt, 2),
                        originalFileName:
                            text(stmt, 3),
                        mimeType:
                            text(stmt, 4),
                        contentHash:
                            text(stmt, 5),
                        caption:
                            text(stmt, 6),
                        createdAt:
                            text(stmt, 7)
                    )
                )
            }
        }

        return result
    }

    /// Stores a homeowner-supplied ACC photo and creates the corresponding attachment metadata.
    @discardableResult
    func addACCPhoto(
        requestID: String,
        lotID: String,
        data: Data,
        originalFileName: String,
        mimeType: String,
        fileExtension: String,
        caption: String = "Homeowner supplied photo",
        actor: AuthenticatedAdmin
    ) throws -> ACCAttachment {
        let now =
            ISODateStorage.now()

        let hash =
            SHA256.hash(
                data: data
            )
            .map {
                String(
                    format: "%02x",
                    $0
                )
            }
            .joined()

        let cleanExtension =
            fileExtension
                .trimmingCharacters(
                    in: CharacterSet(
                        charactersIn: "."
                    )
                )
                .lowercased()

        let storedName =
            UUID().uuidString +
            "." +
            (
                cleanExtension.isEmpty
                ? "jpg"
                : cleanExtension
            )

        let destination =
            try attachmentURL(
                fileName:
                    storedName
            )

        try data.write(
            to: destination,
            options: .atomic
        )

        let attachment =
            ACCAttachment(
                id:
                    UUID().uuidString,
                kind:
                    "accHomeownerPhoto",
                fileName:
                    storedName,
                originalFileName:
                    originalFileName,
                mimeType:
                    mimeType,
                contentHash:
                    hash,
                caption:
                    caption,
                createdAt:
                    now
            )

        do {
            try transaction {
                try execute("""
                INSERT INTO attachments(
                    id,
                    lot_id,
                    violation_id,
                    acc_request_id,
                    kind,
                    file_name,
                    original_file_name,
                    mime_type,
                    content_hash,
                    captured_at,
                    caption,
                    created_at
                )
                VALUES(?,?,?,?,?,?,?,?,?,?,?,?)
                """, bindings: [
                    attachment.id,
                    lotID,
                    nil,
                    requestID,
                    attachment.kind,
                    attachment.fileName,
                    attachment.originalFileName,
                    attachment.mimeType,
                    attachment.contentHash,
                    nil,
                    attachment.caption,
                    attachment.createdAt
                ])

                try journal(
                    entityType:
                        "accRequest",
                    entityID:
                        requestID,
                    operation:
                        "addPhoto"
                )

                let auditData =
                    try JSONSerialization.data(
                        withJSONObject: [
                            "attachmentID":
                                attachment.id,
                            "kind":
                                attachment.kind,
                            "originalFileName":
                                attachment.originalFileName,
                            "contentHash":
                                attachment.contentHash
                        ],
                        options: [
                            .sortedKeys
                        ]
                    )

                try recordAudit(
                    actor: actor,
                    action:
                        "addACCPhoto",
                    entityType:
                        "accRequest",
                    entityID:
                        requestID,
                    beforeJSON:
                        "{}",
                    afterJSON:
                        String(
                            data: auditData,
                            encoding: .utf8
                        )
                        ?? "{}"
                )
            }
        } catch {
            try? FileManager.default
                .removeItem(
                    at: destination
                )

            throw error
        }

        return attachment
    }

    /// Saves accdecision letter using the current application data model.
    @discardableResult
    func saveACCDecisionLetter(
        requestID: String,
        lotID: String,
        decision: String,
        data: Data,
        originalFileName: String,
        actor: AuthenticatedAdmin
    ) throws -> ACCAttachment {
        let now =
            ISODateStorage.now()

        let hash =
            SHA256.hash(
                data: data
            )
            .map {
                String(
                    format: "%02x",
                    $0
                )
            }
            .joined()

        let storedName =
            "ACC-Decision-" +
            UUID().uuidString +
            ".pdf"

        let destination =
            try attachmentURL(
                fileName:
                    storedName
            )

        try data.write(
            to: destination,
            options: .atomic
        )

        let attachment =
            ACCAttachment(
                id:
                    UUID().uuidString,
                kind:
                    "accDecisionLetter",
                fileName:
                    storedName,
                originalFileName:
                    originalFileName,
                mimeType:
                    "application/pdf",
                contentHash:
                    hash,
                caption:
                    "\(decision) ACC decision letter",
                createdAt:
                    now
            )

        do {
            try transaction {
                try execute("""
                INSERT INTO attachments(
                    id,
                    lot_id,
                    violation_id,
                    acc_request_id,
                    kind,
                    file_name,
                    original_file_name,
                    mime_type,
                    content_hash,
                    captured_at,
                    caption,
                    created_at
                )
                VALUES(?,?,?,?,?,?,?,?,?,?,?,?)
                """, bindings: [
                    attachment.id,
                    lotID,
                    nil,
                    requestID,
                    attachment.kind,
                    attachment.fileName,
                    attachment.originalFileName,
                    attachment.mimeType,
                    attachment.contentHash,
                    nil,
                    attachment.caption,
                    attachment.createdAt
                ])

                try journal(
                    entityType:
                        "accRequest",
                    entityID:
                        requestID,
                    operation:
                        "decisionLetter"
                )

                let auditData =
                    try JSONSerialization.data(
                        withJSONObject: [
                            "attachmentID":
                                attachment.id,
                            "decision":
                                decision,
                            "fileName":
                                attachment.originalFileName,
                            "contentHash":
                                attachment.contentHash
                        ],
                        options: [
                            .sortedKeys
                        ]
                    )

                try recordAudit(
                    actor: actor,
                    action:
                        "generateACCDecisionLetter",
                    entityType:
                        "accRequest",
                    entityID:
                        requestID,
                    beforeJSON:
                        "{}",
                    afterJSON:
                        String(
                            data: auditData,
                            encoding: .utf8
                        )
                        ?? "{}"
                )
            }
        } catch {
            try? FileManager.default
                .removeItem(
                    at: destination
                )

            throw error
        }

        return attachment
    }

    /// Saves accrequest using the current application data model.
    func saveACCRequest(
        _ draft: ACCApplicationDraft,
        actor: AuthenticatedAdmin
    ) throws {
        let now = ISODateStorage.now()

        try transaction {
            try execute("""
            INSERT INTO acc_requests(
              id,lot_id,applicant_name,applicant_phone,
              proposed_change_address,description,color,
              proposed_start_date,proposed_completion_date,
              submitted_at,imported_at,status,acc_recommendation,remarks,
              applicant_signature,applicant_signature_date,
              chairperson_signature,chairperson_signature_date,
              source_ocr_text,created_at,updated_at
            ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
            ON CONFLICT(id) DO UPDATE SET
              applicant_name=excluded.applicant_name,
              applicant_phone=excluded.applicant_phone,
              proposed_change_address=excluded.proposed_change_address,
              description=excluded.description,
              color=excluded.color,
              proposed_start_date=excluded.proposed_start_date,
              proposed_completion_date=excluded.proposed_completion_date,
              submitted_at=excluded.submitted_at,
              status=excluded.status,
              acc_recommendation=excluded.acc_recommendation,
              remarks=excluded.remarks,
              applicant_signature=excluded.applicant_signature,
              applicant_signature_date=excluded.applicant_signature_date,
              chairperson_signature=excluded.chairperson_signature,
              chairperson_signature_date=excluded.chairperson_signature_date,
              source_ocr_text=excluded.source_ocr_text,
              updated_at=excluded.updated_at
            """, bindings: [
                draft.id,
                draft.lotID,
                draft.applicantName,
                draft.applicantPhone,
                draft.proposedChangeAddress,
                draft.description,
                draft.color,
                ISODateStorage.optionalString(from: draft.proposedStartDate),
                ISODateStorage.optionalString(from: draft.proposedCompletionDate),
                ISODateStorage.optionalString(from: draft.submittedAt),
                now,
                draft.status,
                draft.accRecommendation,
                draft.remarks,
                draft.applicantSignature,
                ISODateStorage.optionalString(from: draft.applicantSignatureDate),
                draft.chairpersonSignature,
                ISODateStorage.optionalString(from: draft.chairpersonSignatureDate),
                draft.ocrText,
                now,
                now
            ])

            try execute(
                "DELETE FROM acc_neighbors WHERE acc_request_id=?",
                bindings: [draft.id]
            )

            for (
                index,
                neighbor
            ) in draft.neighbors.enumerated() {
                let hasContent =
                    !neighbor.name
                        .trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                        .isEmpty ||
                    !neighbor.address
                        .trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                        .isEmpty ||
                    !neighbor.lotNumber
                        .trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                        .isEmpty ||
                    neighbor.signatureObserved

                guard hasContent else {
                    continue
                }

                try execute("""
                INSERT INTO acc_neighbors(
                  id,acc_request_id,sort_order,name,address,
                  lot_number,signature_observed
                ) VALUES(?,?,?,?,?,?,?)
                """, bindings: [
                    neighbor.id,
                    draft.id,
                    String(index),
                    neighbor.name,
                    neighbor.address,
                    neighbor.lotNumber,
                    neighbor.signatureObserved
                        ? "1"
                        : "0"
                ])
            }

            if let fileName =
                draft.sourcePDFFileName {
                let existing = try scalar("""
                SELECT id
                FROM attachments
                WHERE acc_request_id=?
                  AND kind='accApplicationPDF'
                  AND file_name=?
                """, bindings: [
                    draft.id,
                    fileName
                ])

                if existing == nil {
                    let url = try attachmentURL(
                        fileName: fileName
                    )
                    let data = try Data(
                        contentsOf: url
                    )
                    let hash = SHA256.hash(
                        data: data
                    )
                    .map {
                        String(
                            format: "%02x",
                            $0
                        )
                    }
                    .joined()

                    try execute("""
                    INSERT INTO attachments(
                      id,lot_id,violation_id,acc_request_id,
                      kind,file_name,original_file_name,
                      mime_type,content_hash,captured_at,
                      caption,created_at
                    ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?)
                    """, bindings: [
                        UUID().uuidString,
                        draft.lotID,
                        nil,
                        draft.id,
                        "accApplicationPDF",
                        fileName,
                        draft.sourcePDFOriginalName ??
                            "ACC Application.pdf",
                        "application/pdf",
                        hash,
                        nil,
                        "Original ACC Application",
                        now
                    ])
                }
            }

            try journal(
                entityType: "accRequest",
                entityID: draft.id,
                operation: "save"
            )

            try recordAudit(
                actor: actor,
                action: "createACCApplication",
                entityType: "accRequest",
                entityID: draft.id,
                beforeJSON: "{}",
                afterJSON:
                    fetchACCRequestAuditSnapshot(
                        id: draft.id
                    )
            )
        }
    }


    /// Updates accrequest while preserving workflow and audit requirements.
    func updateACCRequest(
        id: String,
        actor: AuthenticatedAdmin,
        applicantName: String,
        applicantPhone: String,
        proposedChangeAddress: String,
        description: String,
        color: String,
        proposedStartDate: Date?,
        proposedCompletionDate: Date?,
        submittedAt: Date?,
        applicantSignature: String,
        applicantSignatureDate: Date?,
        chairpersonSignature: String,
        chairpersonSignatureDate: Date?,
        accRecommendation: String,
        remarks: String
    ) throws {
        let before =
            try fetchACCRequestAuditSnapshot(
                id: id
            )

        let now = ISODateStorage.now()

        try transaction {
            try execute("""
            UPDATE acc_requests SET
              applicant_name=?,
              applicant_phone=?,
              proposed_change_address=?,
              description=?,
              color=?,
              proposed_start_date=?,
              proposed_completion_date=?,
              submitted_at=?,
              applicant_signature=?,
              applicant_signature_date=?,
              chairperson_signature=?,
              chairperson_signature_date=?,
              acc_recommendation=?,
              remarks=?,
              updated_at=?
            WHERE id=?
            """, bindings: [
                applicantName,
                applicantPhone,
                proposedChangeAddress,
                description,
                color,
                ISODateStorage.optionalString(
                    from:
                        proposedStartDate
                ),
                ISODateStorage.optionalString(
                    from:
                        proposedCompletionDate
                ),
                ISODateStorage.optionalString(
                    from:
                        submittedAt
                ),
                applicantSignature,
                ISODateStorage.optionalString(
                    from:
                        applicantSignatureDate
                ),
                chairpersonSignature,
                ISODateStorage.optionalString(
                    from:
                        chairpersonSignatureDate
                ),
                accRecommendation,
                remarks,
                now,
                id
            ])

            try journal(
                entityType: "accRequest",
                entityID: id,
                operation: "edit"
            )

            try recordAudit(
                actor: actor,
                action: "editACCApplication",
                entityType: "accRequest",
                entityID: id,
                beforeJSON: before,
                afterJSON:
                    fetchACCRequestAuditSnapshot(
                        id: id
                    )
            )
        }
    }

    /// Persists an ACC decision, journals the mutation, and records before/after audit snapshots.
    func adjudicateACCRequest(
        id: String,
        adjudication: ACCAdjudication,
        actor: AuthenticatedAdmin
    ) throws {
        let before =
            try fetchACCRequestAuditSnapshot(
                id: id
            )

        let now = ISODateStorage.now()

        try transaction {
            try execute("""
            UPDATE acc_requests SET
              status=?,
              acc_recommendation=?,
              remarks=?,
              chairperson_signature=?,
              chairperson_signature_date=?,
              updated_at=?
            WHERE id=?
            """, bindings: [
                adjudication.status,
                adjudication.recommendation,
                adjudication.remarks,
                adjudication.chairpersonSignature,
                ISODateStorage.optionalString(from: adjudication.chairpersonDate),
                now,
                id
            ])

            try journal(
                entityType: "accRequest",
                entityID: id,
                operation: "adjudicate"
            )

            try recordAudit(
                actor: actor,
                action: "adjudicateACCApplication",
                entityType: "accRequest",
                entityID: id,
                beforeJSON: before,
                afterJSON:
                    fetchACCRequestAuditSnapshot(
                        id: id
                    )
            )
        }
    }


    // MARK: - SuperUser cleanup

    /// Permanently removes a violation when and only when the provisioned
    /// SuperUser performs the action and supplies a non-empty reason.
    ///
    /// The record snapshot and removal reason remain in the immutable audit log.
    /// A deletion tombstone is also retained so an older device or backup cannot
    /// silently recreate the removed record during a later synchronization.
    func removeViolation(
        id: String,
        reason: String,
        actor: AuthenticatedAdmin
    ) throws {
        let cleanReason =
            try validatedRemovalReason(
                reason,
                actor: actor
            )

        guard
            try scalar(
                "SELECT id FROM violations WHERE id=? LIMIT 1",
                bindings: [id]
            ) != nil
        else {
            throw StoreError.sql(
                "The violation no longer exists."
            )
        }

        let before =
            try fetchViolationAuditSnapshot(
                id: id
            )

        let fileNames =
            try attachmentFileNames(
                violationID: id,
                accRequestID: nil
            )

        let now = ISODateStorage.now()

        try transaction {
            try recordAudit(
                actor: actor,
                action: "removeViolation",
                entityType: "violation",
                entityID: id,
                beforeJSON: before,
                afterJSON:
                    jsonObject([
                        "removed": true,
                        "reason": cleanReason
                    ])
            )

            try upsertDeletionTombstone(
                entityType: "violation",
                entityID: id,
                deletedAt: now,
                username: actor.username,
                reason: cleanReason
            )

            try journal(
                entityType: "violation",
                entityID: id,
                operation: "delete",
                payload:
                    jsonObject([
                        "reason": cleanReason,
                        "deletedAt": now,
                        "username": actor.username
                    ])
            )

            // Rules, adjudication actions, and violation attachments cascade
            // through the schema's foreign keys.
            try execute(
                "DELETE FROM violations WHERE id=?",
                bindings: [id]
            )
        }

        removeAttachmentFilesIfUnreferenced(
            fileNames
        )
    }

    /// Permanently removes an ACC application under the same SuperUser-only
    /// policy used for violation cleanup.
    func removeACCRequest(
        id: String,
        reason: String,
        actor: AuthenticatedAdmin
    ) throws {
        let cleanReason =
            try validatedRemovalReason(
                reason,
                actor: actor
            )

        guard
            try scalar(
                "SELECT id FROM acc_requests WHERE id=? LIMIT 1",
                bindings: [id]
            ) != nil
        else {
            throw StoreError.sql(
                "The ACC application no longer exists."
            )
        }

        let before =
            try fetchACCRequestAuditSnapshot(
                id: id
            )

        let fileNames =
            try attachmentFileNames(
                violationID: nil,
                accRequestID: id
            )

        let now = ISODateStorage.now()

        try transaction {
            try recordAudit(
                actor: actor,
                action: "removeACCApplication",
                entityType: "accRequest",
                entityID: id,
                beforeJSON: before,
                afterJSON:
                    jsonObject([
                        "removed": true,
                        "reason": cleanReason
                    ])
            )

            try upsertDeletionTombstone(
                entityType: "accRequest",
                entityID: id,
                deletedAt: now,
                username: actor.username,
                reason: cleanReason
            )

            try journal(
                entityType: "accRequest",
                entityID: id,
                operation: "delete",
                payload:
                    jsonObject([
                        "reason": cleanReason,
                        "deletedAt": now,
                        "username": actor.username
                    ])
            )

            // ACC attachment rows do not use an acc_request_id foreign-key
            // constraint, so remove them explicitly before deleting the request.
            try execute(
                "DELETE FROM attachments WHERE acc_request_id=?",
                bindings: [id]
            )

            // Neighbor acknowledgements cascade through their foreign key.
            try execute(
                "DELETE FROM acc_requests WHERE id=?",
                bindings: [id]
            )
        }

        removeAttachmentFilesIfUnreferenced(
            fileNames
        )
    }

    /// Returns durable removal tombstones for backup and nearby sync export.
    private func exportDeletionRecords() throws -> [ExportDeletionRecord] {
        var result: [ExportDeletionRecord] = []

        try rows(
            """
            SELECT
                entity_type,
                entity_id,
                deleted_at,
                username,
                reason
            FROM deletion_tombstones
            ORDER BY deleted_at, entity_type, entity_id
            """
        ) { stmt in
            result.append(
                ExportDeletionRecord(
                    entityType: text(stmt, 0),
                    entityID: text(stmt, 1),
                    deletedAt: text(stmt, 2),
                    username: text(stmt, 3),
                    reason: text(stmt, 4)
                )
            )
        }

        return result
    }

    /// Mirrors a synchronized SuperUser deletion into the local audit log so
    /// every updated device retains the same human-readable cleanup history.
    private func recordImportedDeletionAuditIfNeeded(
        _ deletion: ExportDeletionRecord,
        beforeJSON: String
    ) throws {
        let action =
            deletion.entityType == "violation"
            ? "removeViolation"
            : "removeACCApplication"

        let existing =
            try scalar(
                """
                SELECT id
                FROM audit_log
                WHERE action=?
                  AND entity_type=?
                  AND entity_id=?
                  AND username=? COLLATE NOCASE
                  AND changed_at=?
                LIMIT 1
                """,
                bindings: [
                    action,
                    deletion.entityType,
                    deletion.entityID,
                    deletion.username,
                    deletion.deletedAt
                ]
            )

        guard existing == nil else {
            return
        }

        let userID =
            try scalar(
                """
                SELECT id
                FROM users
                WHERE username=? COLLATE NOCASE
                LIMIT 1
                """,
                bindings: [
                    deletion.username
                ]
            ) ?? "remote:\(deletion.username)"

        try execute(
            """
            INSERT INTO audit_log(
                id,user_id,username,action,entity_type,
                entity_id,before_json,after_json,
                changed_at,device_id
            ) VALUES(?,?,?,?,?,?,?,?,?,?)
            """,
            bindings: [
                UUID().uuidString,
                userID,
                deletion.username,
                action,
                deletion.entityType,
                deletion.entityID,
                beforeJSON,
                jsonObject([
                    "removed": true,
                    "reason": deletion.reason,
                    "synchronized": true
                ]),
                deletion.deletedAt,
                "Synchronized deletion"
            ]
        )
    }

    /// Validates the immutable authorization boundary for destructive cleanup.
    private func validatedRemovalReason(
        _ reason: String,
        actor: AuthenticatedAdmin
    ) throws -> String {
        guard
            /// Represents actor within HOA ACC Organizer.
            actor.username.caseInsensitiveCompare(
                "SHOA_ACC_SuperUser"
            ) == .orderedSame
        else {
            throw StoreError.sql(
                "Only SHOA_ACC_SuperUser can remove violations or ACC applications."
            )
        }

        let cleanReason =
            reason.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !cleanReason.isEmpty else {
            throw StoreError.sql(
                "A reason for removal is required."
            )
        }

        return cleanReason
    }

    /// Inserts or updates one durable deletion tombstone.
    private func upsertDeletionTombstone(
        entityType: String,
        entityID: String,
        deletedAt: String,
        username: String,
        reason: String
    ) throws {
        try execute(
            """
            INSERT INTO deletion_tombstones(
                entity_type,
                entity_id,
                deleted_at,
                username,
                reason
            ) VALUES(?,?,?,?,?)
            ON CONFLICT(entity_type, entity_id) DO UPDATE SET
                deleted_at=excluded.deleted_at,
                username=excluded.username,
                reason=excluded.reason
            """,
            bindings: [
                entityType,
                entityID,
                deletedAt,
                username,
                reason
            ]
        )
    }

    /// Returns whether a durable tombstone exists for a synchronized record.
    private func hasDeletionTombstone(
        entityType: String,
        entityID: String
    ) throws -> Bool {
        try scalar(
            """
            SELECT entity_id
            FROM deletion_tombstones
            WHERE entity_type=? AND entity_id=?
            LIMIT 1
            """,
            bindings: [
                entityType,
                entityID
            ]
        ) != nil
    }

    /// Returns attachment filenames associated with one workflow entity.
    private func attachmentFileNames(
        violationID: String?,
        accRequestID: String?
    ) throws -> [String] {
        var result: [String] = []

        try queue.sync {
            if let violationID {
                try rows(
                    """
                    SELECT file_name
                    FROM attachments
                    WHERE violation_id=?
                    """,
                    bindings: [violationID]
                ) { stmt in
                    result.append(
                        text(stmt, 0)
                    )
                }
            } else if let accRequestID {
                try rows(
                    """
                    SELECT file_name
                    FROM attachments
                    WHERE acc_request_id=?
                    """,
                    bindings: [accRequestID]
                ) { stmt in
                    result.append(
                        text(stmt, 0)
                    )
                }
            }
        }

        return result
    }

    /// Removes physical files after their final database reference disappears.
    private func removeAttachmentFilesIfUnreferenced(
        _ fileNames: [String]
    ) {
        for fileName in Set(fileNames) {
            let isReferenced: Bool

            do {
                isReferenced = try queue.sync {
                    try scalar(
                        """
                        SELECT id
                        FROM attachments
                        WHERE file_name=?
                        LIMIT 1
                        """,
                        bindings: [fileName]
                    ) != nil
                }
            } catch {
                // If reference verification fails, leave the file intact rather
                // than risking removal of data still used by another record.
                continue
            }

            guard !isReferenced else {
                continue
            }

            guard
                let url = try? attachmentURL(
                    fileName: fileName
                )
            else {
                continue
            }

            try? FileManager.default.removeItem(
                at: url
            )
        }
    }


    // MARK: - Administration
    
    // Passowrd follow the OPT_2 algor. With a=256 and q=true

    /// Inserts or repairs every account that is provisioned with the application.
    func bootstrapProvisionedAccounts() throws {
        try migrateLegacyProvisionedUsernames()

        for credential in
            ProvisionedAccounts.accounts {
            try repairProvisionedAccount(
                credential
            )
        }
    }

    /// Renames the previously misspelled volunteer username without losing the local account identity.
    private func migrateLegacyProvisionedUsernames() throws {
        let legacyUsername =
            "SHOA_BOD_Volunteecr"

        let correctedUsername =
            "SHOA_BOD_Volunteer"

        let now =
            ISODateStorage.now()

        try queue.sync {
            guard
                let legacyID =
                    try scalar(
                        """
                        SELECT id
                        FROM users
                        WHERE username=?
                        COLLATE NOCASE
                        LIMIT 1
                        """,
                        bindings: [
                            legacyUsername
                        ]
                    )
            else {
                return
            }

            let correctedID =
                try scalar(
                    """
                    SELECT id
                    FROM users
                    WHERE username=?
                    COLLATE NOCASE
                    LIMIT 1
                    """,
                    bindings: [
                        correctedUsername
                    ]
                )

            if correctedID == nil {
                try execute(
                    """
                    UPDATE users
                    SET username=?,
                        display_name=?,
                        updated_at=?
                    WHERE id=?
                    """,
                    bindings: [
                        correctedUsername,
                        "SHOA BOD Volunteer",
                        now,
                        legacyID
                    ]
                )
            } else {
                // If both spellings somehow exist, keep the corrected account
                // and disable the obsolete misspelled credential.
                try execute(
                    """
                    UPDATE users
                    SET is_active=0,
                        updated_at=?
                    WHERE id=?
                    """,
                    bindings: [
                        now,
                        legacyID
                    ]
                )
            }
        }
    }

    /// Backward-compatible wrapper retained for existing startup code.
    func bootstrapProvisionedAdministrator() throws {
        try bootstrapProvisionedAccounts()
    }

    /// Inserts or repairs one provisioned account while preserving its role.
    func repairProvisionedAccount(
        _ credential:
            ProvisionedAccountCredential
    ) throws {
        let now =
            ISODateStorage.now()

        try queue.sync {
            let existing =
                try scalar("""
                SELECT id
                FROM users
                WHERE username=?
                COLLATE NOCASE
                LIMIT 1
                """, bindings: [
                    credential.username
                ])

            if let existing {
                try execute("""
                UPDATE users SET
                    username=?,
                    display_name=?,
                    role=?,
                    password_hash=?,
                    password_salt=?,
                    password_iterations=?,
                    is_active=1,
                    updated_at=?
                WHERE id=?
                """, bindings: [
                    credential.username,
                    credential.displayName,
                    credential.role,
                    credential.passwordHash,
                    credential.passwordSalt,
                    String(
                        credential.iterations
                    ),
                    now,
                    existing
                ])
            } else {
                try execute("""
                INSERT INTO users(
                    id,
                    username,
                    display_name,
                    role,
                    password_hash,
                    password_salt,
                    password_iterations,
                    is_active,
                    created_at,
                    updated_at
                )
                VALUES(?,?,?,?,?,?,?,?,?,?)
                """, bindings: [
                    UUID().uuidString,
                    credential.username,
                    credential.displayName,
                    credential.role,
                    credential.passwordHash,
                    credential.passwordSalt,
                    String(
                        credential.iterations
                    ),
                    "1",
                    now,
                    now
                ])
            }
        }
    }

    /// Backward-compatible administrator repair wrapper.
    func repairProvisionedAdministrator(
        _ credential:
            ProvisionedAdministratorCredential
    ) throws {
        try repairProvisionedAccount(
            credential
        )
    }

    /// Returns whether at least one active administrator account exists in the local database.
    func hasActiveAdministrators() throws -> Bool {
        let count = try queue.sync {
            Int(
                try scalar("""
                SELECT COUNT(*)
                FROM users
                WHERE role='admin' AND is_active=1
                """) ?? "0"
            ) ?? 0
        }

        return count > 0
    }

    /// Fetches users from the local application data.
    func fetchUsers() throws -> [UserAccount] {
        var result: [UserAccount] = []

        try queue.sync {
            try rows("""
            SELECT
                id, username, display_name, role,
                is_active, created_at, updated_at, last_login_at
            FROM users
            ORDER BY lower(username)
            """) { stmt in
                result.append(
                    UserAccount(
                        id: text(stmt, 0),
                        username: text(stmt, 1),
                        displayName: text(stmt, 2),
                        role: text(stmt, 3),
                        isActive: sqlite3_column_int(stmt, 4) != 0,
                        createdAt: text(stmt, 5),
                        updatedAt: text(stmt, 6),
                        lastLoginAt: optionalText(stmt, 7)
                    )
                )
            }
        }

        return result
    }

    /// Fetches user from the local application data.
    func fetchUser(
        username: String
    ) throws -> (
        account: UserAccount,
        passwordHash: String,
        passwordSalt: String,
        iterations: Int
    )? {
        var result:
            (
                UserAccount,
                String,
                String,
                Int
            )?

        try queue.sync {
            try rows("""
            SELECT
                id, username, display_name, role,
                is_active, created_at, updated_at, last_login_at,
                password_hash, password_salt, password_iterations
            FROM users
            WHERE username=? COLLATE NOCASE
            LIMIT 1
            """, bindings: [username]) { stmt in
                let account = UserAccount(
                    id: text(stmt, 0),
                    username: text(stmt, 1),
                    displayName: text(stmt, 2),
                    role: text(stmt, 3),
                    isActive: sqlite3_column_int(stmt, 4) != 0,
                    createdAt: text(stmt, 5),
                    updatedAt: text(stmt, 6),
                    lastLoginAt: optionalText(stmt, 7)
                )

                result = (
                    account,
                    text(stmt, 8),
                    text(stmt, 9),
                    Int(sqlite3_column_int(stmt, 10))
                )
            }
        }

        guard let result else {
            return nil
        }

        return (
            result.0,
            result.1,
            result.2,
            result.3
        )
    }

    /// Fetches user from the local application data.
    func fetchUser(
        id: String
    ) throws -> UserAccount? {
        var result: UserAccount?

        try queue.sync {
            try rows("""
            SELECT
                id, username, display_name, role,
                is_active, created_at, updated_at, last_login_at
            FROM users
            WHERE id=?
            LIMIT 1
            """, bindings: [id]) { stmt in
                result = UserAccount(
                    id: text(stmt, 0),
                    username: text(stmt, 1),
                    displayName: text(stmt, 2),
                    role: text(stmt, 3),
                    isActive: sqlite3_column_int(stmt, 4) != 0,
                    createdAt: text(stmt, 5),
                    updatedAt: text(stmt, 6),
                    lastLoginAt: optionalText(stmt, 7)
                )
            }
        }

        return result
    }

    /// Creates administrator and returns the resulting value when applicable.
    func createAdministrator(
        username: String,
        displayName: String,
        passwordHash: String,
        passwordSalt: String,
        iterations: Int,
        actor: AuthenticatedAdmin?
    ) throws -> UserAccount {
        let now =
            ISODateStorage.now()

        let id = UUID().uuidString

        try transaction {
            try execute("""
            INSERT INTO users(
                id,username,display_name,role,
                password_hash,password_salt,password_iterations,
                is_active,created_at,updated_at
            ) VALUES(?,?,?,?,?,?,?,?,?,?)
            """, bindings: [
                id,
                username,
                displayName,
                "admin",
                passwordHash,
                passwordSalt,
                String(iterations),
                "1",
                now,
                now
            ])

            if let actor {
                try recordAudit(
                    actor: actor,
                    action: "createUser",
                    entityType: "user",
                    entityID: id,
                    beforeJSON: "{}",
                    afterJSON:
                        jsonObject([
                            "username": username,
                            "displayName": displayName,
                            "role": "admin",
                            "isActive": true
                        ])
                )
            }
        }

        return UserAccount(
            id: id,
            username: username,
            displayName: displayName,
            role: "admin",
            isActive: true,
            createdAt: now,
            updatedAt: now,
            lastLoginAt: nil
        )
    }

    /// Replaces the persisted password verifier for an existing administrator account.
    func resetAdministratorPassword(
        userID: String,
        passwordHash: String,
        passwordSalt: String,
        iterations: Int,
        actor: AuthenticatedAdmin
    ) throws {
        let now =
            ISODateStorage.now()

        try transaction {
            try execute("""
            UPDATE users SET
                password_hash=?,
                password_salt=?,
                password_iterations=?,
                updated_at=?
            WHERE id=?
            """, bindings: [
                passwordHash,
                passwordSalt,
                String(iterations),
                now,
                userID
            ])

            try recordAudit(
                actor: actor,
                action: "resetPassword",
                entityType: "user",
                entityID: userID,
                beforeJSON: "{}",
                afterJSON:
                    jsonObject([
                        "passwordReset": true
                    ])
            )
        }
    }

    /// Activates or deactivates an administrator account in the local database.
    func setAdministratorActive(
        userID: String,
        isActive: Bool,
        actor: AuthenticatedAdmin
    ) throws {
        let oldValue =
            try scalar(
                "SELECT is_active FROM users WHERE id=?",
                bindings: [userID]
            ) ?? "0"

        let now =
            ISODateStorage.now()

        try transaction {
            try execute("""
            UPDATE users
            SET is_active=?, updated_at=?
            WHERE id=?
            """, bindings: [
                isActive ? "1" : "0",
                now,
                userID
            ])

            try recordAudit(
                actor: actor,
                action:
                    isActive
                    ? "activateUser"
                    : "deactivateUser",
                entityType: "user",
                entityID: userID,
                beforeJSON:
                    jsonObject([
                        "isActive":
                            oldValue == "1"
                    ]),
                afterJSON:
                    jsonObject([
                        "isActive": isActive
                    ])
            )
        }
    }

    /// Marks login for `SQLiteStore`.
    func markLogin(
        userID: String
    ) throws {
        let now =
            ISODateStorage.now()

        try queue.sync {
            try execute("""
            UPDATE users
            SET last_login_at=?, updated_at=?
            WHERE id=?
            """, bindings: [
                now, now, userID
            ])
        }
    }

    /// Fetches audit entries from the local application data.
    func fetchAuditEntries(
        entityType: String? = nil,
        entityID: String? = nil,
        limit: Int = 500
    ) throws -> [AuditEntry] {
        var result: [AuditEntry] = []

        try queue.sync {
            if let entityType,
               let entityID {
                try rows("""
                SELECT
                    id,user_id,username,action,entity_type,
                    entity_id,before_json,after_json,
                    changed_at,device_id
                FROM audit_log
                WHERE entity_type=? AND entity_id=?
                ORDER BY changed_at DESC, id DESC
                LIMIT ?
                """, bindings: [
                    entityType,
                    entityID,
                    String(limit)
                ]) { stmt in
                    result.append(
                        auditEntry(stmt)
                    )
                }
            } else {
                try rows("""
                SELECT
                    id,user_id,username,action,entity_type,
                    entity_id,before_json,after_json,
                    changed_at,device_id
                FROM audit_log
                ORDER BY changed_at DESC, id DESC
                LIMIT ?
                """, bindings: [
                    String(limit)
                ]) { stmt in
                    result.append(
                        auditEntry(stmt)
                    )
                }
            }
        }

        return result
    }

    /// Updates violation details while preserving workflow and audit requirements.
    func updateViolationDetails(
        id: String,
        notes: String,
        adminNotes: String,
        observedAt: Date?,
        correctionDeadline: Date?,
        actor: AuthenticatedAdmin
    ) throws {
        let before =
            try fetchViolationAuditSnapshot(id: id)

        let now =
            ISODateStorage.now()

        try transaction {
            try execute("""
            UPDATE violations SET
                notes=?,
                admin_notes=?,
                observed_at=?,
                correction_deadline=?,
                updated_at=?
            WHERE id=?
            """, bindings: [
                notes,
                adminNotes,
                ISODateStorage.optionalString(
                    from:
                        observedAt
                ),
                ISODateStorage.optionalString(
                    from:
                        correctionDeadline
                ),
                now,
                id
            ])

            let after =
                try fetchViolationAuditSnapshot(id: id)

            try recordAudit(
                actor: actor,
                action: "editViolation",
                entityType: "violation",
                entityID: id,
                beforeJSON: before,
                afterJSON: after
            )

            try journal(
                entityType: "violation",
                entityID: id,
                operation: "edit"
            )
        }
    }

    /// Records audit in persistent application history.
    func recordAudit(
        actor: AuthenticatedAdmin,
        action: String,
        entityType: String,
        entityID: String,
        beforeJSON: String,
        afterJSON: String
    ) throws {
        let now =
            ISODateStorage.now()

        try execute("""
        INSERT INTO audit_log(
            id,user_id,username,action,entity_type,
            entity_id,before_json,after_json,
            changed_at,device_id
        ) VALUES(?,?,?,?,?,?,?,?,?,?)
        """, bindings: [
            UUID().uuidString,
            actor.id,
            actor.username,
            action,
            entityType,
            entityID,
            beforeJSON,
            afterJSON,
            now,
            ProcessInfo.processInfo.hostName
        ])
    }

    /// Fetches violation audit snapshot from the local application data.
    private func fetchViolationAuditSnapshot(
        id: String
    ) throws -> String {
        var values: [String: Any] = [:]

        try rows("""
        SELECT
            v.lot_id,
            l.lot_number,
            v.observed_at,
            v.inspector_name,
            v.status,
            v.notes,
            v.admin_notes,
            v.correction_deadline,
            v.escalation_date,
            v.final_warning_date,
            v.fee_assessment_date,
            v.resolved_date
        FROM violations v
        LEFT JOIN lots l ON l.id=v.lot_id
        WHERE v.id=?
        """, bindings: [id]) { stmt in
            values = [
                "lotID": text(stmt, 0),
                "lotNumber": text(stmt, 1),
                "observedAt":
                    optionalText(stmt, 2) ?? "",
                "inspectorName": text(stmt, 3),
                "status": text(stmt, 4),
                "notes": text(stmt, 5),
                "adminNotes": text(stmt, 6),
                "correctionDeadline":
                    optionalText(stmt, 7) ?? "",
                "escalationDate":
                    optionalText(stmt, 8) ?? "",
                "finalWarningDate":
                    optionalText(stmt, 9) ?? "",
                "feeAssessmentDate":
                    optionalText(stmt, 10) ?? "",
                "resolvedDate":
                    optionalText(stmt, 11) ?? ""
            ]
        }

        let ruleTitles =
            try scalar(
                """
                SELECT GROUP_CONCAT(title, ' | ')
                FROM violation_rules
                WHERE violation_id=?
                """,
                bindings: [id]
            ) ?? ""

        if !ruleTitles.isEmpty {
            values["ruleTitles"] =
                ruleTitles
        }

        return jsonObject(values)
    }

    /// Fetches accrequest audit snapshot from the local application data.
    private func fetchACCRequestAuditSnapshot(
        id: String
    ) throws -> String {
        var values: [String: Any] = [:]

        try rows("""
        SELECT
            applicant_name,applicant_phone,
            proposed_change_address,description,color,
            proposed_start_date,proposed_completion_date,
            submitted_at,
            applicant_signature,applicant_signature_date,
            status,acc_recommendation,remarks,
            chairperson_signature,chairperson_signature_date
        FROM acc_requests
        WHERE id=?
        """, bindings: [id]) { stmt in
            values = [
                "applicantName": text(stmt, 0),
                "applicantPhone": text(stmt, 1),
                "proposedChangeAddress": text(stmt, 2),
                "description": text(stmt, 3),
                "color": text(stmt, 4),
                "proposedStartDate":
                    optionalText(stmt, 5) ?? "",
                "proposedCompletionDate":
                    optionalText(stmt, 6) ?? "",
                "submittedAt":
                    optionalText(stmt, 7) ?? "",
                "applicantSignature":
                    text(stmt, 8),
                "applicantSignatureDate":
                    optionalText(stmt, 9) ?? "",
                "status": text(stmt, 10),
                "recommendation": text(stmt, 11),
                "remarks": text(stmt, 12),
                "chairperson": text(stmt, 13),
                "chairpersonDate":
                    optionalText(stmt, 14) ?? ""
            ]
        }

        return jsonObject(values)
    }

    /// Builds an `AuditEntry` model from the current SQLite result row.
    private func auditEntry(
        _ stmt: OpaquePointer
    ) -> AuditEntry {
        AuditEntry(
            id: text(stmt, 0),
            userID: text(stmt, 1),
            username: text(stmt, 2),
            action: text(stmt, 3),
            entityType: text(stmt, 4),
            entityID: text(stmt, 5),
            beforeJSON: text(stmt, 6),
            afterJSON: text(stmt, 7),
            changedAt: text(stmt, 8),
            deviceID: text(stmt, 9)
        )
    }

    /// Serializes a dictionary into stable JSON text for audit or journal payloads.
    private func jsonObject(
        _ value: [String: Any]
    ) -> String {
        guard
            JSONSerialization.isValidJSONObject(
                value
            ),
            let data =
                try? JSONSerialization.data(
                    withJSONObject: value,
                    options: [.sortedKeys]
                ),
            let string = String(
                data: data,
                encoding: .utf8
            )
        else {
            return "{}"
        }

        return string
    }

    // MARK: - Full JSON data transfer

    /// Builds full data export package for `SQLiteStore`.
    func buildFullDataExportPackage(
        includeAttachmentData: Bool = true
    ) throws -> FullDataExportPackage {
        var lots: [ExportLotRecord] = []
        var deletions: [ExportDeletionRecord] = []

        try queue.sync {
            var lotIDs: [String] = []

            try rows("""
            SELECT id
            FROM lots
            ORDER BY CAST(lot_number AS INTEGER), lot_number
            """) { stmt in
                lotIDs.append(text(stmt, 0))
            }

            for lotID in lotIDs {
                var lotRecord: ExportLotRecord?

                try rows("""
                SELECT
                    id,
                    lot_number,
                    owner_name,
                    primary_address,
                    billing_address,
                    primary_phone,
                    secondary_phone,
                    primary_email,
                    secondary_email,
                    is_rental_unit
                FROM lots
                WHERE id=?
                """, bindings: [lotID]) { stmt in
                    lotRecord = ExportLotRecord(
                        id: text(stmt, 0),
                        lotNumber: text(stmt, 1),
                        ownerName: text(stmt, 2),
                        primaryAddress: text(stmt, 3),
                        billingAddress: text(stmt, 4),
                        primaryPhone: text(stmt, 5),
                        secondaryPhone: text(stmt, 6),
                        primaryEmail: text(stmt, 7),
                        secondaryEmail: text(stmt, 8),
                        isRentalUnit:
                            sqlite3_column_int(stmt, 9) != 0,
                        violations:
                            try exportViolations(
                                lotID: lotID,
                                includeAttachmentData: includeAttachmentData
                            ),
                        accApplications:
                            try exportACCRequests(
                                lotID: lotID,
                                includeAttachmentData: includeAttachmentData
                            )
                    )
                }

                if let lotRecord {
                    lots.append(lotRecord)
                }
            }

            deletions =
                try exportDeletionRecords()
        }

        return FullDataExportPackage(
            format: FullDataTransferService.format,
            version: FullDataTransferService.version,
            exportedAt:
                ISODateStorage.now(),
            lots: lots,
            deletions: deletions
        )
    }

    /// Merges one lot and its workflow records from a full-data or nearby-sync transfer.
    private func upsertTransferredLot(
        _ lot: ExportLotRecord,
        now: String
    ) throws -> String {
        let normalizedLotNumber =
            lot.lotNumber
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        guard !normalizedLotNumber.isEmpty else {
            throw StoreError.sql(
                "A synchronized property is missing its lot number."
            )
        }

        // Lot number is authoritative. UUIDs are installation/import artifacts
        // and are not guaranteed to match if two devices created their owner
        // master records independently.
        if let existingID =
            try scalar(
                """
                SELECT id
                FROM lots
                WHERE lot_number=?
                LIMIT 1
                """,
                bindings: [
                    normalizedLotNumber
                ]
            ) {
            try execute("""
            UPDATE lots SET
                owner_name=?,
                primary_address=?,
                billing_address=?,
                primary_phone=?,
                secondary_phone=?,
                primary_email=?,
                secondary_email=?,
                is_rental_unit=?,
                updated_at=?
            WHERE id=?
            """, bindings: [
                lot.ownerName,
                lot.primaryAddress,
                lot.billingAddress,
                lot.primaryPhone,
                lot.secondaryPhone,
                lot.primaryEmail,
                lot.secondaryEmail,
                lot.isRentalUnit ? "1" : "0",
                now,
                existingID
            ])

            return existingID
        }

        // If this exact UUID already exists locally, it can safely be reused
        // because no row currently owns the incoming lot number.
        if let existingByID =
            try scalar(
                """
                SELECT id
                FROM lots
                WHERE id=?
                LIMIT 1
                """,
                bindings: [
                    lot.id
                ]
            ) {
            try execute("""
            UPDATE lots SET
                lot_number=?,
                owner_name=?,
                primary_address=?,
                billing_address=?,
                primary_phone=?,
                secondary_phone=?,
                primary_email=?,
                secondary_email=?,
                is_rental_unit=?,
                updated_at=?
            WHERE id=?
            """, bindings: [
                normalizedLotNumber,
                lot.ownerName,
                lot.primaryAddress,
                lot.billingAddress,
                lot.primaryPhone,
                lot.secondaryPhone,
                lot.primaryEmail,
                lot.secondaryEmail,
                lot.isRentalUnit ? "1" : "0",
                now,
                existingByID
            ])

            return existingByID
        }

        try execute("""
        INSERT INTO lots(
            id,
            lot_number,
            owner_name,
            primary_address,
            billing_address,
            primary_phone,
            secondary_phone,
            primary_email,
            secondary_email,
            is_rental_unit,
            created_at,
            updated_at
        )
        VALUES(?,?,?,?,?,?,?,?,?,?,?,?)
        """, bindings: [
            lot.id,
            normalizedLotNumber,
            lot.ownerName,
            lot.primaryAddress,
            lot.billingAddress,
            lot.primaryPhone,
            lot.secondaryPhone,
            lot.primaryEmail,
            lot.secondaryEmail,
            lot.isRentalUnit ? "1" : "0",
            now,
            now
        ])

        return lot.id
    }

    /// Imports full data export package and validates it before persistence.
    func importFullDataExportPackage(
        _ package: FullDataExportPackage,
        sourceFileName: String
    ) throws {
        let now =
            ISODateStorage.now()

        let trustedDeletions =
            package.deletions.filter { deletion in
                let supportedType =
                    deletion.entityType == "violation" ||
                    deletion.entityType == "accRequest"

                let hasReason =
                    !deletion.reason
                        .trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                        .isEmpty

                return
                    supportedType &&
                    hasReason &&
                    deletion.username
                        .caseInsensitiveCompare(
                            "SHOA_ACC_SuperUser"
                        ) == .orderedSame
            }

        let incomingDeletionKeys =
            Set(
                trustedDeletions.map {
                    $0.entityType + "\u{1F}" + $0.entityID
                }
            )

        var removedAttachmentFiles: [String] = []

        try transaction {
            for lot in package.lots {
                // Lot number is the stable HOA identity across devices.
                // Different devices may have generated different UUIDs for the
                // same lot when owner master data was imported independently.
                // Resolve the local canonical lot ID before importing children.
                let localLotID =
                    try upsertTransferredLot(
                        lot,
                        now: now
                    )

                for violation in lot.violations {
                    let deletionKey =
                        "violation" + "\u{1F}" + violation.id

                    let hasIncomingDeletion =
                        incomingDeletionKeys.contains(
                            deletionKey
                        )

                    let hasLocalDeletion =
                        try hasDeletionTombstone(
                            entityType: "violation",
                            entityID: violation.id
                        )

                    if hasIncomingDeletion ||
                        hasLocalDeletion {
                        continue
                    }

                    try execute("""
                    INSERT INTO violations(
                        id,
                        lot_id,
                        observed_at,
                        correction_deadline,
                        created_at,
                        escalation_date,
                        final_warning_date,
                        fee_assessment_date,
                        resolved_date,
                        inspector_name,
                        notes,
                        admin_notes,
                        status,
                        source_hash,
                        updated_at
                    )
                    VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
                    ON CONFLICT(id) DO UPDATE SET
                        lot_id=excluded.lot_id,
                        observed_at=excluded.observed_at,
                        correction_deadline=excluded.correction_deadline,
                        created_at=excluded.created_at,
                        escalation_date=excluded.escalation_date,
                        final_warning_date=excluded.final_warning_date,
                        fee_assessment_date=excluded.fee_assessment_date,
                        resolved_date=excluded.resolved_date,
                        inspector_name=excluded.inspector_name,
                        notes=excluded.notes,
                        admin_notes=excluded.admin_notes,
                        status=excluded.status,
                        source_hash=excluded.source_hash,
                        updated_at=excluded.updated_at
                    """, bindings: [
                        violation.id,
                        localLotID,
                        ISODateStorage.canonical(violation.observedAt),
                        ISODateStorage.canonical(violation.correctionDeadline),
                        ISODateStorage.canonical(violation.createdAt),
                        ISODateStorage.canonical(violation.escalationDate),
                        ISODateStorage.canonical(violation.finalWarningDate),
                        ISODateStorage.canonical(violation.feeAssessmentDate),
                        ISODateStorage.canonical(violation.resolvedDate),
                        violation.inspectorName,
                        violation.notes,
                        violation.adminNotes,
                        violation.status,
                        violation.sourceHash,
                        ISODateStorage.canonical(violation.updatedAt) ?? now
                    ])

                    try execute(
                        "DELETE FROM violation_rules WHERE violation_id=?",
                        bindings: [violation.id]
                    )

                    for rule in violation.rules {
                        try execute("""
                        INSERT INTO violation_rules(
                            violation_id,
                            rule_id,
                            title,
                            category,
                            rule_section,
                            correction_days,
                            notice_text,
                            corrective_action,
                            rule_text
                        )
                        VALUES(?,?,?,?,?,?,?,?,?)
                        """, bindings: [
                            violation.id,
                            rule.ruleID,
                            rule.title,
                            rule.category,
                            rule.ruleSection,
                            rule.correctionDays.map(String.init),
                            rule.noticeText,
                            rule.correctiveAction,
                            rule.ruleText
                        ])
                    }

                    try importAttachments(
                        violation.attachments,
                        lotID: localLotID,
                        violationID: violation.id,
                        accRequestID: nil
                    )
                }

                for application in lot.accApplications {
                    let deletionKey =
                        "accRequest" + "\u{1F}" + application.id

                    let hasIncomingDeletion =
                        incomingDeletionKeys.contains(
                            deletionKey
                        )

                    let hasLocalDeletion =
                        try hasDeletionTombstone(
                            entityType: "accRequest",
                            entityID: application.id
                        )

                    if hasIncomingDeletion ||
                        hasLocalDeletion {
                        continue
                    }

                    try execute("""
                    INSERT INTO acc_requests(
                        id,
                        lot_id,
                        applicant_name,
                        applicant_phone,
                        proposed_change_address,
                        description,
                        color,
                        proposed_start_date,
                        proposed_completion_date,
                        submitted_at,
                        imported_at,
                        status,
                        acc_recommendation,
                        remarks,
                        applicant_signature,
                        applicant_signature_date,
                        chairperson_signature,
                        chairperson_signature_date,
                        source_ocr_text,
                        created_at,
                        updated_at
                    )
                    VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
                    ON CONFLICT(id) DO UPDATE SET
                        lot_id=excluded.lot_id,
                        applicant_name=excluded.applicant_name,
                        applicant_phone=excluded.applicant_phone,
                        proposed_change_address=excluded.proposed_change_address,
                        description=excluded.description,
                        color=excluded.color,
                        proposed_start_date=excluded.proposed_start_date,
                        proposed_completion_date=excluded.proposed_completion_date,
                        submitted_at=excluded.submitted_at,
                        imported_at=excluded.imported_at,
                        status=excluded.status,
                        acc_recommendation=excluded.acc_recommendation,
                        remarks=excluded.remarks,
                        applicant_signature=excluded.applicant_signature,
                        applicant_signature_date=excluded.applicant_signature_date,
                        chairperson_signature=excluded.chairperson_signature,
                        chairperson_signature_date=excluded.chairperson_signature_date,
                        source_ocr_text=excluded.source_ocr_text,
                        created_at=excluded.created_at,
                        updated_at=excluded.updated_at
                    """, bindings: [
                        application.id,
                        localLotID,
                        application.applicantName,
                        application.applicantPhone,
                        application.proposedChangeAddress,
                        application.description,
                        application.color,
                        ISODateStorage.canonical(application.proposedStartDate),
                        ISODateStorage.canonical(application.proposedCompletionDate),
                        ISODateStorage.canonical(application.submittedAt),
                        ISODateStorage.canonical(application.importedAt) ?? now,
                        application.status,
                        application.accRecommendation,
                        application.remarks,
                        application.applicantSignature,
                        ISODateStorage.canonical(application.applicantSignatureDate),
                        application.chairpersonSignature,
                        ISODateStorage.canonical(application.chairpersonSignatureDate),
                        application.sourceOCRText,
                        ISODateStorage.canonical(application.createdAt) ?? now,
                        ISODateStorage.canonical(application.updatedAt) ?? now
                    ])

                    try execute(
                        "DELETE FROM acc_neighbors WHERE acc_request_id=?",
                        bindings: [application.id]
                    )

                    for (index, neighbor) in
                        application.neighbors.enumerated() {
                        try execute("""
                        INSERT INTO acc_neighbors(
                            id,
                            acc_request_id,
                            sort_order,
                            name,
                            address,
                            lot_number,
                            signature_observed
                        )
                        VALUES(?,?,?,?,?,?,?)
                        """, bindings: [
                            neighbor.id,
                            application.id,
                            String(index),
                            neighbor.name,
                            neighbor.address,
                            neighbor.lotNumber,
                            neighbor.signatureObserved ? "1" : "0"
                        ])
                    }

                    try importAttachments(
                        application.attachments,
                        lotID: localLotID,
                        violationID: nil,
                        accRequestID: application.id
                    )
                }
            }

            // Apply removal tombstones after all incoming upserts. This makes a
            // SuperUser cleanup durable across nearby sync and backup restore.
            for deletion in trustedDeletions {
                let beforeJSON: String

                switch deletion.entityType {
                case "violation":
                    beforeJSON =
                        try fetchViolationAuditSnapshot(
                            id: deletion.entityID
                        )

                    try rows(
                        """
                        SELECT file_name
                        FROM attachments
                        WHERE violation_id=?
                        """,
                        bindings: [
                            deletion.entityID
                        ]
                    ) { stmt in
                        removedAttachmentFiles.append(
                            text(stmt, 0)
                        )
                    }

                    try execute(
                        "DELETE FROM violations WHERE id=?",
                        bindings: [
                            deletion.entityID
                        ]
                    )

                case "accRequest":
                    beforeJSON =
                        try fetchACCRequestAuditSnapshot(
                            id: deletion.entityID
                        )

                    try rows(
                        """
                        SELECT file_name
                        FROM attachments
                        WHERE acc_request_id=?
                        """,
                        bindings: [
                            deletion.entityID
                        ]
                    ) { stmt in
                        removedAttachmentFiles.append(
                            text(stmt, 0)
                        )
                    }

                    try execute(
                        "DELETE FROM attachments WHERE acc_request_id=?",
                        bindings: [
                            deletion.entityID
                        ]
                    )

                    try execute(
                        "DELETE FROM acc_requests WHERE id=?",
                        bindings: [
                            deletion.entityID
                        ]
                    )

                default:
                    // Current cleanup policy supports only violations and ACC
                    // applications. Unknown tombstones are ignored safely.
                    continue
                }

                try upsertDeletionTombstone(
                    entityType:
                        deletion.entityType,
                    entityID:
                        deletion.entityID,
                    deletedAt:
                        deletion.deletedAt,
                    username:
                        deletion.username,
                    reason:
                        deletion.reason
                )

                try recordImportedDeletionAuditIfNeeded(
                    deletion,
                    beforeJSON: beforeJSON
                )
            }

            try insertImportBatch(
                id: UUID().uuidString,
                type: "fullDataTransfer",
                fileName: sourceFileName,
                exportedAt: package.exportedAt,
                count: package.lots.count,
                hash: package.exportedAt
            )
        }

        removeAttachmentFilesIfUnreferenced(
            removedAttachmentFiles
        )
    }

    /// Exports violations in the application transfer format.
    private func exportViolations(
        lotID: String,
        includeAttachmentData: Bool
    ) throws -> [ExportViolationRecord] {
        var result: [ExportViolationRecord] = []
        var violationIDs: [String] = []

        try rows("""
        SELECT id
        FROM violations
        WHERE lot_id=?
        ORDER BY COALESCE(observed_at, created_at), id
        """, bindings: [lotID]) { stmt in
            violationIDs.append(text(stmt, 0))
        }

        for id in violationIDs {
            var rules: [ExportViolationRule] = []

            try rows("""
            SELECT
                rule_id,
                title,
                category,
                rule_section,
                correction_days,
                notice_text,
                corrective_action,
                rule_text
            FROM violation_rules
            WHERE violation_id=?
            ORDER BY rule_section, title
            """, bindings: [id]) { stmt in
                rules.append(
                    ExportViolationRule(
                        ruleID: text(stmt, 0),
                        title: text(stmt, 1),
                        category: text(stmt, 2),
                        ruleSection: text(stmt, 3),
                        correctionDays:
                            sqlite3_column_type(stmt, 4) == SQLITE_NULL
                            ? nil
                            : Int(sqlite3_column_int(stmt, 4)),
                        noticeText: text(stmt, 5),
                        correctiveAction: text(stmt, 6),
                        ruleText: text(stmt, 7)
                    )
                )
            }

            let attachments =
                try exportAttachments(
                    violationID: id,
                    accRequestID: nil,
                    includeData: includeAttachmentData
                )

            try rows("""
            SELECT
                id,
                observed_at,
                correction_deadline,
                created_at,
                escalation_date,
                final_warning_date,
                fee_assessment_date,
                resolved_date,
                inspector_name,
                notes,
                admin_notes,
                status,
                source_hash,
                updated_at
            FROM violations
            WHERE id=?
            """, bindings: [id]) { stmt in
                result.append(
                    ExportViolationRecord(
                        id: text(stmt, 0),
                        observedAt: optionalText(stmt, 1),
                        correctionDeadline: optionalText(stmt, 2),
                        createdAt: optionalText(stmt, 3),
                        escalationDate: optionalText(stmt, 4),
                        finalWarningDate: optionalText(stmt, 5),
                        feeAssessmentDate: optionalText(stmt, 6),
                        resolvedDate: optionalText(stmt, 7),
                        inspectorName: text(stmt, 8),
                        notes: text(stmt, 9),
                        adminNotes: text(stmt, 10),
                        status: text(stmt, 11),
                        sourceHash: text(stmt, 12),
                        updatedAt: text(stmt, 13),
                        rules: rules,
                        attachments: attachments
                    )
                )
            }
        }

        return result
    }

    /// Exports accrequests in the application transfer format.
    private func exportACCRequests(
        lotID: String,
        includeAttachmentData: Bool
    ) throws -> [ExportACCRequestRecord] {
        var result: [ExportACCRequestRecord] = []
        var requestIDs: [String] = []

        try rows("""
        SELECT id
        FROM acc_requests
        WHERE lot_id=?
        ORDER BY COALESCE(submitted_at, created_at), id
        """, bindings: [lotID]) { stmt in
            requestIDs.append(text(stmt, 0))
        }

        for id in requestIDs {
            var neighbors: [ACCNeighbor] = []

            try rows("""
            SELECT
                id,
                name,
                address,
                lot_number,
                signature_observed
            FROM acc_neighbors
            WHERE acc_request_id=?
            ORDER BY sort_order, id
            """, bindings: [id]) { stmt in
                neighbors.append(
                    ACCNeighbor(
                        id: text(stmt, 0),
                        name: text(stmt, 1),
                        address: text(stmt, 2),
                        lotNumber: text(stmt, 3),
                        signatureObserved:
                            sqlite3_column_int(stmt, 4) != 0
                    )
                )
            }

            let attachments =
                try exportAttachments(
                    violationID: nil,
                    accRequestID: id,
                    includeData: includeAttachmentData
                )

            try rows("""
            SELECT
                id,
                applicant_name,
                applicant_phone,
                proposed_change_address,
                description,
                color,
                proposed_start_date,
                proposed_completion_date,
                submitted_at,
                imported_at,
                status,
                acc_recommendation,
                remarks,
                applicant_signature,
                applicant_signature_date,
                chairperson_signature,
                chairperson_signature_date,
                source_ocr_text,
                created_at,
                updated_at
            FROM acc_requests
            WHERE id=?
            """, bindings: [id]) { stmt in
                result.append(
                    ExportACCRequestRecord(
                        id: text(stmt, 0),
                        applicantName: text(stmt, 1),
                        applicantPhone: text(stmt, 2),
                        proposedChangeAddress: text(stmt, 3),
                        description: text(stmt, 4),
                        color: text(stmt, 5),
                        proposedStartDate: optionalText(stmt, 6),
                        proposedCompletionDate: optionalText(stmt, 7),
                        submittedAt: optionalText(stmt, 8),
                        importedAt: text(stmt, 9),
                        status: text(stmt, 10),
                        accRecommendation: text(stmt, 11),
                        remarks: text(stmt, 12),
                        applicantSignature: text(stmt, 13),
                        applicantSignatureDate: optionalText(stmt, 14),
                        chairpersonSignature: text(stmt, 15),
                        chairpersonSignatureDate: optionalText(stmt, 16),
                        sourceOCRText: text(stmt, 17),
                        createdAt: text(stmt, 18),
                        updatedAt: text(stmt, 19),
                        neighbors: neighbors,
                        attachments: attachments
                    )
                )
            }
        }

        return result
    }

    /// Exports attachments in the application transfer format.
    private func exportAttachments(
        violationID: String?,
        accRequestID: String?,
        includeData: Bool
    ) throws -> [ExportAttachment] {
        var result: [ExportAttachment] = []

        let sql: String
        let binding: String

        if let violationID {
            sql = """
            SELECT
                id, kind, file_name, original_file_name,
                mime_type, content_hash, captured_at,
                caption, created_at
            FROM attachments
            WHERE violation_id=?
            ORDER BY created_at, id
            """
            binding = violationID
        } else if let accRequestID {
            sql = """
            SELECT
                id, kind, file_name, original_file_name,
                mime_type, content_hash, captured_at,
                caption, created_at
            FROM attachments
            WHERE acc_request_id=?
            ORDER BY created_at, id
            """
            binding = accRequestID
        } else {
            return result
        }

        try rows(sql, bindings: [binding]) { stmt in
            let fileName = text(stmt, 2)
            let url = try attachmentURL(fileName: fileName)

            guard FileManager.default.fileExists(
                atPath: url.path
            ) else {
                return
            }

            let encodedData: String

            if includeData {
                let data = try Data(contentsOf: url)
                encodedData = data.base64EncodedString()
            } else {
                encodedData = ""
            }

            result.append(
                ExportAttachment(
                    id: text(stmt, 0),
                    kind: text(stmt, 1),
                    fileName: fileName,
                    originalFileName: text(stmt, 3),
                    mimeType: text(stmt, 4),
                    contentHash: text(stmt, 5),
                    capturedAt: optionalText(stmt, 6),
                    caption: text(stmt, 7),
                    createdAt: text(stmt, 8),
                    base64Data: encodedData
                )
            )
        }

        return result
    }

    /// Imports attachments and validates it before persistence.
    private func importAttachments(
        _ attachments: [ExportAttachment],
        lotID: String,
        violationID: String?,
        accRequestID: String?
    ) throws {
        for attachment in attachments {
            if !attachment.base64Data.isEmpty,
               let data = Data(
                    base64Encoded: attachment.base64Data
               ) {
                let url =
                    try attachmentURL(
                        fileName: attachment.fileName
                    )

                try data.write(
                    to: url,
                    options: .atomic
                )
            }

            try execute("""
            INSERT INTO attachments(
                id,
                lot_id,
                violation_id,
                acc_request_id,
                kind,
                file_name,
                original_file_name,
                mime_type,
                content_hash,
                captured_at,
                caption,
                created_at
            )
            VALUES(?,?,?,?,?,?,?,?,?,?,?,?)
            ON CONFLICT(id) DO UPDATE SET
                lot_id=excluded.lot_id,
                violation_id=excluded.violation_id,
                acc_request_id=excluded.acc_request_id,
                kind=excluded.kind,
                file_name=excluded.file_name,
                original_file_name=excluded.original_file_name,
                mime_type=excluded.mime_type,
                content_hash=excluded.content_hash,
                captured_at=excluded.captured_at,
                caption=excluded.caption,
                created_at=excluded.created_at
            """, bindings: [
                attachment.id,
                lotID,
                violationID,
                accRequestID,
                attachment.kind,
                attachment.fileName,
                attachment.originalFileName,
                attachment.mimeType,
                attachment.contentHash,
                ISODateStorage.canonical(attachment.capturedAt),
                attachment.caption,
                ISODateStorage.canonical(attachment.createdAt) ?? ISODateStorage.now()
            ])
        }
    }


    /// Fetches reminder candidates from the local application data.
    func fetchReminderCandidates() throws -> ReminderCandidates {
        var violations: [ViolationReminderCandidate] = []
        var applications: [ACCReminderCandidate] = []

        try queue.sync {
            try rows("""
            SELECT
                v.id,
                l.lot_number,
                v.status,
                v.correction_deadline,
                v.escalation_date
            FROM violations v
            JOIN lots l ON l.id=v.lot_id
            WHERE lower(v.status) NOT IN ('resolved','closed')
            """) { stmt in
                violations.append(
                    ViolationReminderCandidate(
                        id: text(stmt, 0),
                        lotNumber: text(stmt, 1),
                        status: text(stmt, 2),
                        correctionDeadline: optionalText(stmt, 3),
                        escalationDate: optionalText(stmt, 4)
                    )
                )
            }

            try rows("""
            SELECT
                a.id,
                l.lot_number,
                a.status,
                a.imported_at
            FROM acc_requests a
            JOIN lots l ON l.id=a.lot_id
            WHERE lower(a.status) IN (
                'under review',
                'pending',
                'submitted',
                'needs information'
            )
            """) { stmt in
                applications.append(
                    ACCReminderCandidate(
                        id: text(stmt, 0),
                        lotNumber: text(stmt, 1),
                        status: text(stmt, 2),
                        importedAt: text(stmt, 3)
                    )
                )
            }
        }

        return ReminderCandidates(
            violations: violations,
            applications: applications
        )
    }

    // MARK: - Sync state and attachment transport

    /// Fetches sync state from the local application data.
    func fetchSyncState() throws -> SyncStateSnapshot {
        var result = SyncStateSnapshot(
            lastSuccessfulSyncAt: nil,
            lastSyncMethod: "",
            lastPeerName: ""
        )

        try queue.sync {
            try rows("""
            SELECT
                last_successful_sync_at,
                last_sync_method,
                last_peer_name
            FROM sync_state
            WHERE id=1
            """) { stmt in
                result = SyncStateSnapshot(
                    lastSuccessfulSyncAt:
                        optionalText(stmt, 0),
                    lastSyncMethod:
                        text(stmt, 1),
                    lastPeerName:
                        text(stmt, 2)
                )
            }
        }

        return result
    }

    /// Records successful sync in persistent application history.
    func recordSuccessfulSync(
        method: String,
        peerName: String = ""
    ) throws {
        let now = ISODateStorage.now()

        try queue.sync {
            try execute("""
            INSERT INTO sync_state(
                id,
                last_successful_sync_at,
                last_sync_method,
                last_peer_name
            )
            VALUES(1,?,?,?)
            ON CONFLICT(id) DO UPDATE SET
                last_successful_sync_at=
                    excluded.last_successful_sync_at,
                last_sync_method=
                    excluded.last_sync_method,
                last_peer_name=
                    excluded.last_peer_name
            """, bindings: [
                now,
                method,
                peerName
            ])
        }
    }

    /// Returns whether enough time has elapsed since the last successful sync for the selected cadence.
    func syncIsDue(
        cadence: SyncCadence
    ) throws -> Bool {
        let state = try fetchSyncState()

        guard
            let value =
                state.lastSuccessfulSyncAt,
            let date =
                ISODateStorage.date(
                    from: value
                )
        else {
            return true
        }

        return Date()
            .timeIntervalSince(date)
            >= cadence.interval
    }

    /// Returns the required content hashes that are not currently present in local attachment storage.
    func missingAttachmentHashes(
        requiredHashes: Set<String>? = nil
    ) throws -> [String] {
        var fileNamesByHash:
            [String: Set<String>] = [:]

        try queue.sync {
            try rows("""
            SELECT
                content_hash,
                file_name
            FROM attachments
            WHERE content_hash <> ''
            """) { stmt in
                let hash =
                    text(stmt, 0)

                let fileName =
                    text(stmt, 1)

                guard
                    !hash.isEmpty,
                    !fileName.isEmpty
                else {
                    return
                }

                fileNamesByHash[
                    hash,
                    default: []
                ]
                .insert(fileName)
            }
        }

        let hashesToCheck:
            Set<String>

        if let requiredHashes {
            hashesToCheck =
                requiredHashes
                    .filter {
                        !$0.isEmpty
                    }
        } else {
            hashesToCheck =
                Set(
                    fileNamesByHash.keys
                )
        }

        var missing: [String] = []

        for hash in
            hashesToCheck.sorted() {
            let fileNames =
                fileNamesByHash[hash]
                ?? []

            let hasLocalFile =
                fileNames.contains {
                    fileName in

                    guard
                        let url =
                            try? attachmentURL(
                                fileName:
                                    fileName
                            )
                    else {
                        return false
                    }

                    return FileManager
                        .default
                        .fileExists(
                            atPath:
                                url.path
                        )
                }

            if !hasLocalFile {
                missing.append(hash)
            }
        }

        return missing
    }

    /// Returns transfer metadata for a specific attachment content hash.
    func attachmentTransferInfo(
        contentHash: String
    ) throws -> AttachmentTransferInfo? {
        var candidates:
            [AttachmentTransferInfo] = []

        try queue.sync {
            try rows("""
            SELECT
                content_hash,
                file_name
            FROM attachments
            WHERE content_hash=?
            ORDER BY created_at, id
            """, bindings: [
                contentHash
            ]) { stmt in
                candidates.append(
                    AttachmentTransferInfo(
                        contentHash:
                            text(stmt, 0),
                        fileName:
                            text(stmt, 1)
                    )
                )
            }
        }

        for candidate in candidates {
            guard
                let url =
                    try? attachmentURL(
                        fileName:
                            candidate.fileName
                    )
            else {
                continue
            }

            if FileManager.default
                .fileExists(
                    atPath:
                        url.path
                ) {
                return candidate
            }
        }

        // Returning the first metadata row keeps diagnostics useful if
        // the database references an attachment whose file was deleted.
        return candidates.first
    }

    /// Returns transfer metadata for every locally stored attachment.
    func allAttachmentTransferInfo()
        throws -> [AttachmentTransferInfo] {
        var result: [AttachmentTransferInfo] = []

        try queue.sync {
            try rows("""
            SELECT DISTINCT
                content_hash,
                file_name
            FROM attachments
            WHERE content_hash <> ''
            ORDER BY content_hash
            """) { stmt in
                result.append(
                    AttachmentTransferInfo(
                        contentHash: text(stmt, 0),
                        fileName: text(stmt, 1)
                    )
                )
            }
        }

        return result
    }

    /// Records backup in persistent application history.
    func recordBackup(
        fileName: String,
        attachmentCount: Int
    ) throws {
        try queue.sync {
            try execute("""
            INSERT INTO backup_history(
                id,
                created_at,
                file_name,
                attachment_count
            ) VALUES(?,?,?,?)
            """, bindings: [
                UUID().uuidString,
                ISODateStorage.now(),
                fileName,
                String(attachmentCount)
            ])
        }
    }

    /// Returns the Application Support directory used while assembling or restoring backup content.
    func backupURL() throws -> URL {
        if let configuredDatabaseURL {
            return configuredDatabaseURL
        }

        let fm = FileManager.default
        let base = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("HOAACCOrganizer", isDirectory: true)

        return base.appendingPathComponent("hoa-acc.sqlite")
    }

    /// Converts a blank or whitespace-only string into `nil` for optional persistence fields.
    private func blankToNil(_ value: String) -> String? {
        let cleaned = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return cleaned.isEmpty ? nil : cleaned
    }

    /// Trims and normalizes user/imported text before comparison or persistence.
    private func clean(_ value: String?) -> String {
        (value ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(
                of: #"\s+"#,
                with: " ",
                options: .regularExpression
            )
    }

    /// Normalizes imported phone text while retaining a human-readable value.
    private func cleanPhone(_ value: String?) -> String {
        clean(value)
            .replacingOccurrences(
                of: #"^(Phone|Mobile):\s*"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Normalizes address for `SQLiteStore`.
    private func normalizeAddress(_ value: String) -> String {
        value.lowercased()
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(
                of: #"\s+"#,
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Builds a `StoreError` message from the current SQLite error state.
    private func message() -> String {
        guard let db, let c = sqlite3_errmsg(db) else {
            return "Unknown SQLite error."
        }
        return String(cString: c)
    }
}

/// Reads a non-optional UTF-8 text column from the current SQLite row.
private func text(_ stmt: OpaquePointer, _ col: Int32) -> String {
    guard let c = sqlite3_column_text(stmt, col) else { return "" }
    return String(cString: c)
}

/// Reads an optional UTF-8 text column from the current SQLite row.
private func optionalText(_ stmt: OpaquePointer, _ col: Int32) -> String? {
    guard sqlite3_column_type(stmt, col) != SQLITE_NULL,
          let c = sqlite3_column_text(stmt, col) else {
        return nil
    }
    return String(cString: c)
}

/// The SQLite destructor sentinel used when binding transient Swift string/data memory.
private let SQLITE_TRANSIENT = unsafeBitCast(
    -1,
    to: sqlite3_destructor_type.self
)
