// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import Foundation

/// Imports legacy homeowner CSV data into the lot master records.
final class HomeownerCSVImporter {
    /// The SQLite persistence store used by this component.
    let store: SQLiteStore
    /// Creates a new `HomeownerCSVImporter` instance with the supplied values.
    init(store: SQLiteStore) { self.store = store }

    /// Imports file and validates it before persistence.
    func importFile(_ url: URL) throws -> HomeownerImportResult {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let text = try String(contentsOf: url, encoding: .utf8)
        let rows = CSV.parse(text)
        guard let header = rows.first else { return .init(inserted: 0, updated: 0, unmatched: 0, addressMismatches: 0) }

        func index(_ candidates: [String]) -> Int? {
            let normalized = header.map { normalize($0) }
            return candidates.compactMap { c in normalized.firstIndex(of: normalize(c)) }.first
        }
        guard let lotCol = index(["lot", "lot number", "lot #", "lot no"]) else {
            throw StoreError.sql("Could not find a Lot/Lot Number column.")
        }
        guard let ownerCol = index(["owner", "owner name", "homeowner", "homeowner name"]) else {
            throw StoreError.sql("Could not find an Owner/Owner Name column.")
        }
        let addressCol = index(["address", "property address", "primary address"])

        var updated = 0, unmatched = 0
        try store.transaction {
            for row in rows.dropFirst() where row.indices.contains(lotCol) && row.indices.contains(ownerCol) {
                let lot = row[lotCol].trimmingCharacters(in: .whitespacesAndNewlines)
                let owner = row[ownerCol].trimmingCharacters(in: .whitespacesAndNewlines)
                if lot.isEmpty || owner.isEmpty { continue }
                let address = addressCol.flatMap { row.indices.contains($0) ? row[$0] : nil }
                if try store.updateOwner(lotNumber: lot, owner: owner, address: address) { updated += 1 }
                else { unmatched += 1 }
            }
        }
        return .init(inserted: 0, updated: updated, unmatched: unmatched, addressMismatches: 0)
    }

    /// Normalizes imported text by trimming and collapsing inconsistent whitespace and source formatting.
    private func normalize(_ value: String) -> String {
        value.lowercased()
            .replacingOccurrences(of: "#", with: "number")
            .replacingOccurrences(of: ".", with: "")
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .joined(separator: " ")
    }
}

/// Provides the minimal CSV parsing helpers used by the homeowner importer.
enum CSV {
    /// Parses parse for `CSV`.
    static func parse(_ text: String) -> [[String]] {
        var rows: [[String]] = [], row: [String] = [], field = ""
        var quoted = false
        var i = text.startIndex
        while i < text.endIndex {
            let ch = text[i]
            if quoted {
                if ch == "\"" {
                    let n = text.index(after: i)
                    if n < text.endIndex && text[n] == "\"" {
                        field.append("\""); i = n
                    } else { quoted = false }
                } else { field.append(ch) }
            } else {
                switch ch {
                case "\"": quoted = true
                case ",": row.append(field); field = ""
                case "\n":
                    row.append(field); rows.append(row); row = []; field = ""
                case "\r": break
                default: field.append(ch)
                }
            }
            i = text.index(after: i)
        }
        if !field.isEmpty || !row.isEmpty { row.append(field); rows.append(row) }
        return rows
    }
}
