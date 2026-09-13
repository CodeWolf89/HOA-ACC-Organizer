// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import Foundation
import Combine
import CryptoKit
import Network

/// Describes violation JSON decoding, validation, and persistence failures.
enum ImportError: Error, LocalizedError {
    case wrongFormat(String)
    case missingProperty(String)

    /// A localized description of the error suitable for display to the user.
    var errorDescription: String? {
        switch self {
        case .wrongFormat(let v): return "Unsupported JSON format: \(v)"
        case .missingProperty(let id): return "Violation \(id) has no property/lot information."
        }
    }
}

/// Imports violation JSON exports while deduplicating reports and persisting rule/photo data.
final class ViolationImporter {
    /// The SQLite persistence store used by this component.
    private let store: SQLiteStore
    /// The JSON decoder used to parse this importer’s source format.
    private let decoder = JSONDecoder()

    /// Creates an instance with the supplied dependencies and initial values.
    init(store: SQLiteStore) { self.store = store }

    /// Imports file for `ImportError`.
    func importFile(_ url: URL) throws -> ImportResult {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: url)
        return try importData(
            data,
            sourceFileName: url.lastPathComponent
        )
    }

    /// Imports data and validates it before persistence.
    func importData(
        _ data: Data,
        sourceFileName: String
    ) throws -> ImportResult {
        let batch = try decoder.decode(ViolationBatch.self, from: data)
        guard batch.format == "ACC-HOA-VIOLATION-BATCH" else {
            throw ImportError.wrongFormat(batch.format)
        }
        let batchHash = SHA256.hash(data: data).hex
        let already = try store.scalar("SELECT id FROM import_batches WHERE content_hash=?", bindings: [batchHash])
        if already != nil {
            return ImportResult(inserted: 0, updated: 0, duplicates: batch.reports.count)
        }

        var inserted = 0, updated = 0, duplicates = 0
        try store.transaction {
            for report in batch.reports {
                guard let property = report.property else { throw ImportError.missingProperty(report.id) }

                // A SuperUser cleanup tombstone wins over a stale violation
                // export so importing the original batch cannot resurrect it.
                if try store.scalar(
                    """
                    SELECT entity_id
                    FROM deletion_tombstones
                    WHERE entity_type='violation' AND entity_id=?
                    LIMIT 1
                    """,
                    bindings: [report.id]
                ) != nil {
                    duplicates += 1
                    continue
                }

                let lotID = try store.upsertLot(property: property)
                let encoded = try JSONEncoder().encode(report)
                let hash = SHA256.hash(data: encoded).hex
                let oldHash = try store.scalar("SELECT source_hash FROM violations WHERE id=?", bindings: [report.id])

                if oldHash == hash {
                    duplicates += 1
                    continue
                }

                if oldHash == nil {
                    try store.execute("""
                    INSERT INTO violations(
                      id,lot_id,observed_at,correction_deadline,created_at,escalation_date,final_warning_date,
                      resolved_date,inspector_name,notes,status,source_hash,updated_at
                    ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)
                    """, bindings: [
                        report.id, lotID, ISODateStorage.canonical(report.observedAt), ISODateStorage.canonical(report.correctionDeadline), ISODateStorage.canonical(report.createdAt),
                        ISODateStorage.canonical(report.escalationDate), ISODateStorage.canonical(report.finalWarningDate), ISODateStorage.canonical(report.resolvedDate),
                        report.inspectorName ?? "", report.notes ?? "", report.statusRaw ?? "",
                        hash, ISODateStorage.now()
                    ])
                    inserted += 1
                } else {
                    try store.execute("""
                    UPDATE violations SET
                      lot_id=?,
                      observed_at=?,
                      correction_deadline=?,
                      created_at=?,
                      escalation_date=CASE
                        WHEN EXISTS(
                          SELECT 1 FROM violation_actions
                          WHERE violation_id=violations.id
                        ) THEN escalation_date
                        ELSE ?
                      END,
                      final_warning_date=CASE
                        WHEN EXISTS(
                          SELECT 1 FROM violation_actions
                          WHERE violation_id=violations.id
                        ) THEN final_warning_date
                        ELSE ?
                      END,
                      resolved_date=CASE
                        WHEN EXISTS(
                          SELECT 1 FROM violation_actions
                          WHERE violation_id=violations.id
                        ) THEN resolved_date
                        ELSE ?
                      END,
                      inspector_name=?,
                      notes=?,
                      status=CASE
                        WHEN EXISTS(
                          SELECT 1 FROM violation_actions
                          WHERE violation_id=violations.id
                        ) THEN status
                        ELSE ?
                      END,
                      source_hash=?,
                      updated_at=?
                    WHERE id=?
                    """, bindings: [
                        lotID,
                        ISODateStorage.canonical(report.observedAt),
                        ISODateStorage.canonical(report.correctionDeadline),
                        ISODateStorage.canonical(report.createdAt),
                        ISODateStorage.canonical(report.escalationDate),
                        ISODateStorage.canonical(report.finalWarningDate),
                        ISODateStorage.canonical(report.resolvedDate),
                        report.inspectorName ?? "",
                        report.notes ?? "",
                        report.statusRaw ?? "",
                        hash,
                        ISODateStorage.now(),
                        report.id
                    ])
                    try store.execute("DELETE FROM violation_rules WHERE violation_id=?", bindings: [report.id])
                    updated += 1
                }

                for rule in report.rules ?? [] {
                    try store.execute("""
                    INSERT OR REPLACE INTO violation_rules(
                      violation_id,rule_id,title,category,rule_section,correction_days,notice_text,corrective_action,rule_text
                    ) VALUES(?,?,?,?,?,?,?,?,?)
                    """, bindings: [
                        report.id, rule.id, rule.title ?? "", rule.category ?? "",
                        rule.ruleSection ?? "", rule.correctionDays.map(String.init), rule.noticeText ?? "", rule.correctiveAction ?? "", rule.ruleText ?? ""
                    ])
                }

                for photo in report.photos ?? [] {
                    try savePhoto(photo, lotID: lotID, violationID: report.id)
                }
                try store.journal(entityType: "violation", entityID: report.id, operation: oldHash == nil ? "insert" : "update")
            }

            try store.insertImportBatch(
                id: UUID().uuidString, type: batch.format, fileName: sourceFileName,
                exportedAt: batch.exportedAt, count: batch.reports.count, hash: batchHash
            )
        }

        return ImportResult(inserted: inserted, updated: updated, duplicates: duplicates)
    }

    /// Saves photo using the current application data model.
    private func savePhoto(_ photo: ViolationPhoto, lotID: String, violationID: String) throws {
        guard let raw = photo.imageData, let data = Data(base64Encoded: raw) else { return }
        let hash = SHA256.hash(data: data).hex
        if try store.scalar("SELECT id FROM attachments WHERE content_hash=?", bindings: [hash]) != nil { return }

        let fm = FileManager.default
        let base = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("HOAACCOrganizer/Attachments", isDirectory: true)
        try fm.createDirectory(at: base, withIntermediateDirectories: true)
        let name = "\(photo.id).jpg"
        try data.write(to: base.appendingPathComponent(name), options: .atomic)

        try store.execute("""
        INSERT INTO attachments(id,lot_id,violation_id,kind,file_name,mime_type,content_hash,captured_at,caption,created_at)
        VALUES(?,?,?,?,?,?,?,?,?,?)
        """, bindings: [
            photo.id, lotID, violationID, "violationPhoto", name, "image/jpeg", hash,
            ISODateStorage.canonical(photo.capturedAt), photo.caption ?? "", ISODateStorage.now()
        ])
    }
}

/// Adds HOA ACC Organizer behavior to `SHA256.Digest`.
private extension SHA256.Digest {
    /// The lowercase hexadecimal representation of the SHA-256 digest.
    var hex: String { map { String(format: "%02x", $0) }.joined() }
}


// MARK: - One-way intake from HOA Violations

/// Represents violation feed acknowledgement within HOA ACC Organizer.
private struct ViolationFeedAcknowledgement: Codable {
    /// The number of new records inserted by the operation.
    let inserted: Int
    /// The number of existing records updated by the operation.
    let updated: Int
    /// The number of input records skipped because they were already present or unchanged.
    let duplicates: Int
    /// The user-facing message associated with message.
    let message: String
}

/// Receives violation reports directly from the companion violation app over the local network.
final class ViolationFeedReceiverService: ObservableObject {
    /// The current workflow status.
    @Published private(set) var status = "Violation App intake stopped"
    /// Publishes last import summary so observing views can react when it changes.
    @Published private(set) var lastImportSummary: String?

    /// The importer used to process incoming data for this workflow.
    private let importer: ViolationImporter
    /// The Bonjour service type used by the nearby-sync protocol.
    private let serviceType = "_hoavfeed._tcp"
    /// The maximum companion-violation payload size accepted by the intake receiver.
    private let maxBatchBytes = 128 * 1024 * 1024

    /// The Network.framework listener that accepts incoming nearby-sync connections.
    private var listener: NWListener?
    /// The active companion-violation intake connections keyed by connection identity.
    private var connections: [UUID: NWConnection] = [:]

    /// A callback invoked when on import completed occurs.
    var onImportCompleted: ((ImportResult) -> Void)?

    /// Creates an instance with the supplied dependencies and initial values.
    init(importer: ViolationImporter) {
        self.importer = importer
    }

    /// The user-facing companion violation-feed status text.
    var displayStatus: String {
        UserFacingStatus.violationFeedStatus(
            status
        )
    }

    /// The user-facing summary of the most recent companion violation import.
    var displayLastImportSummary: String? {
        guard let lastImportSummary else {
            return nil
        }

        #if DEBUG
        return lastImportSummary
        #else
        return lastImportSummary
            .replacingOccurrences(
                of: "Violation sync received: ",
                with: "Last import: "
            )
            .replacingOccurrences(
                of: " unchanged.",
                with: " already current."
            )
        #endif
    }


    /// Starts the service and begins the associated workflow.
    func start() {
        guard listener == nil else { return }

        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        parameters.allowLocalEndpointReuse = true

        do {
            let listener = try NWListener(
                using: parameters
            )

            listener.service = NWListener.Service(
                name: "HOA ACC Organizer",
                type: serviceType
            )

            listener.newConnectionHandler = { [weak self] connection in
                DispatchQueue.main.async {
                    self?.accept(connection)
                }
            }

            listener.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    guard let self else { return }

                    switch state {
                    case .ready:
                        self.status = "Ready to receive from HOA Violations"
                    case .waiting(let error):
                        self.status = "Violation intake waiting: \(error.localizedDescription)"
                    case .failed(let error):
                        self.status = "Violation intake failed: \(error.localizedDescription)"
                        self.listener?.cancel()
                        self.listener = nil
                    case .cancelled:
                        self.status = "Violation App intake stopped"
                    default:
                        break
                    }
                }
            }

            listener.start(queue: .main)
            self.listener = listener
            status = "Starting Violation App intake…"

        } catch {
            status = "Unable to start Violation App intake: \(error.localizedDescription)"
        }
    }

    /// Stops the service and releases active resources.
    func stop() {
        listener?.cancel()
        listener = nil

        for connection in connections.values {
            connection.cancel()
        }

        connections.removeAll()
        status = "Violation App intake stopped"
    }

    /// Accepts one incoming companion violation-feed connection and begins reading its framed payload.
    private func accept(
        _ connection: NWConnection
    ) {
        let id = UUID()
        connections[id] = connection

        connection.stateUpdateHandler = { [weak self, weak connection] state in
            DispatchQueue.main.async {
                guard let self, let connection else { return }

                switch state {
                case .ready:
                    self.status = "Receiving violation reports…"
                    self.receiveLength(
                        from: connection,
                        connectionID: id
                    )

                case .failed(let error):
                    self.status = "Violation intake connection failed: \(error.localizedDescription)"
                    self.finishConnection(id)

                case .cancelled:
                    self.finishConnection(id)

                default:
                    break
                }
            }
        }

        connection.start(queue: .main)
    }

    /// Receives length for `ViolationFeedReceiverService`.
    private func receiveLength(
        from connection: NWConnection,
        connectionID: UUID
    ) {
        receiveExactly(
            4,
            from: connection
        ) { [weak self, weak connection] data in
            guard let self, let connection else { return }

            guard let data,
                  let length = Self.uint32(from: data),
                  length > 0,
                  length <= UInt32(self.maxBatchBytes)
            else {
                self.sendFailure(
                    "The incoming violation batch is invalid or too large.",
                    over: connection,
                    connectionID: connectionID
                )
                return
            }

            self.receiveExactly(
                Int(length),
                from: connection
            ) { [weak self, weak connection] payload in
                guard let self, let connection else { return }

                guard let payload else {
                    self.sendFailure(
                        "The violation transfer ended before all data was received.",
                        over: connection,
                        connectionID: connectionID
                    )
                    return
                }

                self.importPayload(
                    payload,
                    over: connection,
                    connectionID: connectionID
                )
            }
        }
    }

    /// Imports payload and validates it before persistence.
    private func importPayload(
        _ payload: Data,
        over connection: NWConnection,
        connectionID: UUID
    ) {
        do {
            let result = try importer.importData(
                payload,
                sourceFileName: "Nearby HOA Violations"
            )

            let summary =
                "Violation sync received: " +
                "\(result.inserted) new, " +
                "\(result.updated) updated, " +
                "\(result.duplicates) unchanged."

            lastImportSummary = summary
            status = "Violation App sync received"

            let acknowledgement = ViolationFeedAcknowledgement(
                inserted: result.inserted,
                updated: result.updated,
                duplicates: result.duplicates,
                message: summary
            )

            let data = try JSONEncoder().encode(
                acknowledgement
            )

            sendFramed(
                data,
                over: connection
            ) { [weak self] in
                self?.finishConnection(connectionID)
            }

            onImportCompleted?(result)

        } catch {
            sendFailure(
                "Violation import failed: \(error.localizedDescription)",
                over: connection,
                connectionID: connectionID
            )
        }
    }

    /// Sends failure for `ViolationFeedReceiverService`.
    private func sendFailure(
        _ message: String,
        over connection: NWConnection,
        connectionID: UUID
    ) {
        status = message

        let acknowledgement = ViolationFeedAcknowledgement(
            inserted: 0,
            updated: 0,
            duplicates: 0,
            message: message
        )

        if let data = try? JSONEncoder().encode(
            acknowledgement
        ) {
            sendFramed(
                data,
                over: connection
            ) { [weak self] in
                self?.finishConnection(connectionID)
            }
        } else {
            finishConnection(connectionID)
        }
    }

    /// Sends framed for `ViolationFeedReceiverService`.
    private func sendFramed(
        _ payload: Data,
        over connection: NWConnection,
        completion: @escaping () -> Void
    ) {
        var length = UInt32(payload.count).bigEndian
        var frame = Data(
            bytes: &length,
            count: MemoryLayout<UInt32>.size
        )
        frame.append(payload)

        connection.send(
            content: frame,
            completion: .contentProcessed { _ in
                DispatchQueue.main.async {
                    completion()
                }
            }
        )
    }

    /// Receives exactly for `ViolationFeedReceiverService`.
    private func receiveExactly(
        _ byteCount: Int,
        from connection: NWConnection,
        accumulated: Data = Data(),
        completion: @escaping (Data?) -> Void
    ) {
        if accumulated.count == byteCount {
            completion(accumulated)
            return
        }

        let remaining = byteCount - accumulated.count

        connection.receive(
            minimumIncompleteLength: 1,
            maximumLength: min(remaining, 256 * 1024)
        ) { [weak self] data, _, isComplete, error in
            DispatchQueue.main.async {
                guard let self else { return }

                if error != nil {
                    completion(nil)
                    return
                }

                var next = accumulated

                if let data {
                    next.append(data)
                }

                if next.count == byteCount {
                    completion(next)
                } else if isComplete || next.count > byteCount {
                    completion(nil)
                } else {
                    self.receiveExactly(
                        byteCount,
                        from: connection,
                        accumulated: next,
                        completion: completion
                    )
                }
            }
        }
    }

    /// Closes and removes a companion-feed connection after import or failure.
    private func finishConnection(
        _ id: UUID
    ) {
        connections[id]?.cancel()
        connections[id] = nil
    }

    /// Reads a 32-bit network-order integer from framed companion-feed data.
    private static func uint32(
        from data: Data
    ) -> UInt32? {
        guard data.count == 4 else { return nil }

        return data.reduce(UInt32(0)) {
            ($0 << 8) | UInt32($1)
        }
    }
}
