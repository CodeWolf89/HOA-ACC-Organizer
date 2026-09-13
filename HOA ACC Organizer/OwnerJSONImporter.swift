// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import Foundation
import CryptoKit

/// Supports the current SHOA homeowner JSON format:
///
/// {
///   "SHOA_ACC_SORTABLE": [
///      { "Lot Number": 1, ... }
///   ]
/// }
///
/// It also remains backward-compatible with the older plain-array format.
final class OwnerJSONImporter {
    /// The SQLite persistence store used by this component.
    private let store: SQLiteStore
    /// The JSON decoder used to parse this importer’s source format.
    private let decoder = JSONDecoder()

    /// Represents wrapped owner data within HOA ACC Organizer.
    private struct WrappedOwnerData: Codable {
        /// The owner-master records decoded from the wrapped JSON payload.
        let records: [OwnerMasterRecord]

        /// Defines the supported coding keys values used by the application.
        enum CodingKeys: String, CodingKey {
            case records = "SHOA_ACC_SORTABLE"
        }
    }

    /// Creates an instance with the supplied dependencies and initial values.
    init(store: SQLiteStore) {
        self.store = store
    }

    /// Imports bundled owner data if available and validates it before persistence.
    func importBundledOwnerDataIfAvailable() throws -> HomeownerImportResult? {
        // Support both filenames so an existing project does not have to
        // rename a resource just to use the newer file.
        let supportedNames = [
            "SHOA_HOMEOWNER_DATA",
            "SHOA_OWNER_DATA"
        ]

        for name in supportedNames {
            if let url = Bundle.main.url(
                forResource: name,
                withExtension: "json"
            ) {
                return try importFile(
                    url,
                    securityScoped: false
                )
            }
        }

        return nil
    }

    /// Imports file and validates it before persistence.
    func importFile(
        _ url: URL,
        securityScoped: Bool = true
    ) throws -> HomeownerImportResult {
        let scoped = securityScoped
            ? url.startAccessingSecurityScopedResource()
            : false

        defer {
            if scoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url)
        let records = try decodeRecords(from: data)

        guard !records.isEmpty else {
            throw OwnerImportError.noRecords
        }

        let hash = SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()

        var inserted = 0
        var updated = 0
        var addressMismatches = 0

        try store.transaction {
            for record in records {
                let result = try store.upsertOwnerMaster(record)

                if result.inserted {
                    inserted += 1
                } else {
                    updated += 1
                }

                if result.addressMismatch {
                    addressMismatches += 1
                }
            }

            try store.insertImportBatch(
                id: UUID().uuidString,
                type: "SHOA-HOMEOWNER-DATA",
                fileName: url.lastPathComponent,
                exportedAt: nil,
                count: records.count,
                hash: hash
            )
        }

        return HomeownerImportResult(
            inserted: inserted,
            updated: updated,
            unmatched: 0,
            addressMismatches: addressMismatches
        )
    }

    /// Decodes records for `OwnerJSONImporter`.
    private func decodeRecords(
        from data: Data
    ) throws -> [OwnerMasterRecord] {
        // Current format: object containing SHOA_ACC_SORTABLE.
        if let wrapped = try? decoder.decode(
            WrappedOwnerData.self,
            from: data
        ) {
            return wrapped.records
        }

        // Backward compatibility: previous version accepted a raw array.
        if let array = try? decoder.decode(
            [OwnerMasterRecord].self,
            from: data
        ) {
            return array
        }

        throw OwnerImportError.unsupportedFormat
    }
}

/// Describes owner-master JSON decoding and format validation failures.
enum OwnerImportError: Error, LocalizedError {
    case unsupportedFormat
    case noRecords

    /// A localized description of the error suitable for display to the user.
    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return """
            Homeowner JSON is not in a supported format. Expected a top-level \
            "SHOA_ACC_SORTABLE" array containing homeowner records.
            """

        case .noRecords:
            return """
            The homeowner JSON was recognized, but the SHOA_ACC_SORTABLE array \
            did not contain any homeowner records.
            """
        }
    }
}
