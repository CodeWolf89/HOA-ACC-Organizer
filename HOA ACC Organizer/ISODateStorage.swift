// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import Foundation

/// Centralizes canonical ISO-8601 serialization and tolerant parsing of user- or OCR-supplied dates.
enum ISODateStorage {
    /// Indicates whether iso with fractional.
    private static let isoWithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    /// Indicates whether iso standard.
    private static let isoStandard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime
        ]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    /// Returns the current date/time encoded as the app’s canonical ISO-8601 string.
    static func now() -> String {
        isoStandard.string(from: Date())
    }

    /// Encodes a `Date` as canonical ISO-8601 text for persistence.
    static func string(from date: Date) -> String {
        isoStandard.string(from: date)
    }

    /// Encodes an optional date as canonical ISO-8601 text or `nil`.
    static func optionalString(
        from date: Date?
    ) -> String? {
        guard let date else {
            return nil
        }

        return isoStandard.string(
            from: date
        )
    }

    /// Parses supported ISO-8601 and legacy date text into a `Date`.
    static func date(from value: String?) -> Date? {
        guard let raw = value?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }

        if let date = isoWithFractional.date(from: raw) {
            return date
        }

        if let date = isoStandard.date(from: raw) {
            return date
        }

        let formats = [
            "yyyy-MM-dd",
            "MM/dd/yyyy",
            "M/d/yyyy",
            "MM-dd-yyyy",
            "M-d-yyyy",
            "MMMM d, yyyy",
            "MMM d, yyyy",
            "MM/dd/yyyy HH:mm",
            "M/d/yyyy HH:mm"
        ]

        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.timeZone = .current
            formatter.dateFormat = format

            if let date = formatter.date(from: raw) {
                return date
            }
        }

        return nil
    }

    /// Converts supported date text to canonical ISO-8601 representation.
    static func canonical(_ value: String?) -> String? {
        guard let date = date(from: value) else {
            return nil
        }
        return isoStandard.string(
            from: date
        )
    }
}
