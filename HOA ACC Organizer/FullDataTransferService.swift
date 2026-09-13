// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import Foundation

/// Describes errors encountered while validating a full-data JSON transfer package.
enum FullDataTransferError: Error, LocalizedError {
    case invalidFormat
    case unsupportedVersion(Int)

    /// A localized description of the error suitable for display to the user.
    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "The selected JSON file is not an HOA ACC full-data export."
        case .unsupportedVersion(let version):
            return "This HOA ACC export version (\(version)) is not supported."
        }
    }
}

/// Exports and imports the portable JSON representation used to move complete HOA records between installations.
final class FullDataTransferService {
    /// The format identifier used to validate this import, export, or backup payload.
    static let format = "HOA-ACC-FULL-EXPORT"
    /// The schema or transfer-format version supported by this component.
    static let version = 2

    /// The SQLite persistence store used by this component.
    private let store: SQLiteStore

    /// Creates an instance with the supplied dependencies and initial values.
    init(store: SQLiteStore) {
        self.store = store
    }

    /// Exports jsondata in the application transfer format.
    func exportJSONData() throws -> Data {
        let package = try store.buildFullDataExportPackage()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys,
            .withoutEscapingSlashes
        ]

        return try encoder.encode(package)
    }

    /// Imports json and validates it before persistence.
    func importJSON(from url: URL) throws -> Int {
        let scoped = url.startAccessingSecurityScopedResource()

        defer {
            if scoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url)
        let package = try JSONDecoder().decode(
            FullDataExportPackage.self,
            from: data
        )

        guard package.format == Self.format else {
            throw FullDataTransferError.invalidFormat
        }

        guard package.version == Self.version else {
            throw FullDataTransferError.unsupportedVersion(
                package.version
            )
        }

        try store.importFullDataExportPackage(
            package,
            sourceFileName: url.lastPathComponent
        )

        return package.lots.count
    }
}
