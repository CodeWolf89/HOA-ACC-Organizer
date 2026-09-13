// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import Foundation

/// Describes the metadata stored inside a full HOA ACC backup archive.
struct BackupManifest: Codable {
    /// The format identifier used to validate this import, export, or backup payload.
    let format: String
    /// The schema or transfer-format version supported by this component.
    let version: Int
    /// The ISO-8601 creation timestamp for this record.
    let createdAt: String
    /// The count represented by attachment count.
    let attachmentCount: Int
}

/// Describes validation failures encountered while creating or restoring backups.
enum BackupServiceError: Error, LocalizedError {
    case invalidBackup
    case missingData

    /// A localized description of the error suitable for display to the user.
    var errorDescription: String? {
        switch self {
        case .invalidBackup:
            return "The selected file is not a valid HOA ACC backup."
        case .missingData:
            return "The backup is missing required data."
        }
    }
}

/// Creates and restores full backup archives containing structured HOA data and attachments.
final class BackupService {
    /// The format identifier used to validate this import, export, or backup payload.
    static let format =
        "HOA-ACC-BACKUP"

    /// The schema or transfer-format version supported by this component.
    static let version = 1

    /// The SQLite persistence store used by this component.
    private let store: SQLiteStore

    /// Creates an instance with the supplied dependencies and initial values.
    init(store: SQLiteStore) {
        self.store = store
    }

    /// Creates backup data and returns the resulting value when applicable.
    func createBackupData() throws -> Data {
        let package =
            try store.buildFullDataExportPackage(
                includeAttachmentData: false
            )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys,
            .withoutEscapingSlashes
        ]

        let dataJSON =
            try encoder.encode(package)

        let attachmentInfo =
            try store.allAttachmentTransferInfo()

        let manifest =
            BackupManifest(
                format: Self.format,
                version: Self.version,
                createdAt: ISODateStorage.now(),
                attachmentCount:
                    attachmentInfo.count
            )

        let manifestJSON =
            try encoder.encode(manifest)

        var entries: [SimpleZIP.Entry] = [
            .init(
                name: "manifest.json",
                data: manifestJSON
            ),
            .init(
                name: "data.json",
                data: dataJSON
            )
        ]

        for item in attachmentInfo {
            let url =
                try store.attachmentURL(
                    fileName: item.fileName
                )

            guard
                FileManager.default
                    .fileExists(
                        atPath: url.path
                    )
            else {
                continue
            }

            entries.append(
                .init(
                    name:
                        "Attachments/\(item.fileName)",
                    data:
                        try Data(
                            contentsOf: url
                        )
                )
            )
        }

        return try SimpleZIP.create(
            entries: entries
        )
    }

    /// Restores structured records and attachment files from a validated HOA ACC backup archive.
    func restoreBackup(
        from url: URL
    ) throws -> Int {
        let scoped =
            url.startAccessingSecurityScopedResource()

        defer {
            if scoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let archiveData =
            try Data(contentsOf: url)

        let entries =
            try SimpleZIP.extract(
                data: archiveData
            )

        guard
            let manifestData =
                entries["manifest.json"],
            let dataJSON =
                entries["data.json"]
        else {
            throw BackupServiceError.missingData
        }

        let decoder = JSONDecoder()

        let manifest =
            try decoder.decode(
                BackupManifest.self,
                from: manifestData
            )

        guard
            manifest.format ==
                Self.format,
            manifest.version ==
                Self.version
        else {
            throw BackupServiceError.invalidBackup
        }

        let package =
            try decoder.decode(
                FullDataExportPackage.self,
                from: dataJSON
            )

        for lot in package.lots {
            for violation in lot.violations {
                for attachment in
                    violation.attachments {
                    try restoreAttachment(
                        attachment,
                        entries: entries
                    )
                }
            }

            for application in
                lot.accApplications {
                for attachment in
                    application.attachments {
                    try restoreAttachment(
                        attachment,
                        entries: entries
                    )
                }
            }
        }

        try store.importFullDataExportPackage(
            package,
            sourceFileName:
                url.lastPathComponent
        )

        try store.recordSuccessfulSync(
            method: "backupRestore"
        )

        return package.lots.count
    }

    /// Restores one attachment file from a backup archive while preserving its metadata relationship.
    private func restoreAttachment(
        _ attachment: ExportAttachment,
        entries: [String: Data]
    ) throws {
        guard
            let data =
                entries[
                    "Attachments/\(attachment.fileName)"
                ]
        else {
            return
        }

        let destination =
            try store.attachmentURL(
                fileName: attachment.fileName
            )

        try data.write(
            to: destination,
            options: .atomic
        )
    }
}
