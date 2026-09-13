// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import Foundation

/// Represents an HOA rule available for selection while creating a new violation.
nonisolated struct ViolationCreationRule: Codable, Hashable, Identifiable {
    /// The stable identifier for this value.
    let id: String
    /// The rule or workflow category associated with this value.
    let category: String
    /// The human-readable title displayed for this value.
    let title: String
    /// The governing-document section cited by this rule.
    let ruleSection: String
    /// The complete governing-rule text stored with the violation.
    let ruleText: String
    /// The standardized notice language associated with this rule.
    let noticeText: String
    /// The standardized corrective action associated with this rule.
    let correctiveAction: String
    /// The number of days allowed for correction under this rule.
    let correctionDays: Int
    /// Indicates whether is active.
    let isActive: Bool
}

/// Represents a photo captured as part of a new violation before persistence.
nonisolated struct ViolationCreationPhoto: Codable, Identifiable {
    /// The stable identifier for this value.
    let id: String
    /// The binary or encoded data used for image data.
    let imageData: Data
    /// The ISO-8601 timestamp associated with the captured photo or observation.
    let capturedAt: Date
    /// The user-visible caption associated with the attachment or photo.
    let caption: String

    /// Creates an instance with the supplied dependencies and initial values.
    init(
        id: String = UUID().uuidString,
        imageData: Data,
        capturedAt: Date = Date(),
        caption: String = ""
    ) {
        self.id = id
        self.imageData = imageData
        self.capturedAt = capturedAt
        self.caption = caption
    }
}

/// Collects all fields required to create and persist a new violation report.
nonisolated struct ViolationCreationDraft: Codable, Identifiable {
    /// The stable identifier for this value.
    let id: String
    /// The stable identifier of the lot associated with this record.
    let lotID: String
    /// The ISO-8601 timestamp when the violation was observed.
    let observedAt: Date
    /// The ISO-8601 deadline by which the violation should be corrected.
    let correctionDeadline: Date
    /// The name of the inspector associated with the violation.
    let inspectorName: String
    /// User-entered notes associated with this record.
    let notes: String
    /// The governing-rule records associated with this value.
    let rules: [ViolationCreationRule]
    /// The photo records or attachments associated with this value.
    let photos: [ViolationCreationPhoto]

    /// Creates an instance with the supplied dependencies and initial values.
    init(
        id: String = UUID().uuidString,
        lotID: String,
        observedAt: Date,
        correctionDeadline: Date,
        inspectorName: String,
        notes: String,
        rules: [ViolationCreationRule],
        photos: [ViolationCreationPhoto]
    ) {
        self.id = id
        self.lotID = lotID
        self.observedAt = observedAt
        self.correctionDeadline = correctionDeadline
        self.inspectorName = inspectorName
        self.notes = notes
        self.rules = rules
        self.photos = photos
    }

    /// Calculates the violation correction deadline using the longest correction period among the selected rules.
    static func correctionDeadline(
        observedAt: Date,
        rules: [ViolationCreationRule],
        calendar: Calendar = .current
    ) -> Date {
        let days =
            rules
                .map(\.correctionDays)
                .max()
            ?? 7

        return calendar.date(
            byAdding: .day,
            value: days,
            to: observedAt
        ) ?? observedAt
    }
}

/// Represents bundled violation rule record within HOA ACC Organizer.
private struct BundledViolationRuleRecord: Decodable {
    /// The rule or workflow category associated with this value.
    let category: String
    /// The human-readable title displayed for this value.
    let title: String
    /// The governing-document section cited by this rule.
    let ruleSection: String
    /// The complete governing-rule text stored with the violation.
    let ruleText: String
    /// The standardized notice language associated with this rule.
    let noticeText: String
    /// The standardized corrective action associated with this rule.
    let correctiveAction: String
    /// The number of days allowed for correction under this rule.
    let correctionDays: Int
    /// Indicates whether is active.
    let isActive: Bool
}

/// Loads the bundled HOA rules and generates stable identifiers for cross-device consistency.
enum ViolationRuleCatalog {
    /// Loads the data required by this view or workflow from persistent storage.
    static func load(
        bundle: Bundle = .main
    ) throws -> [ViolationCreationRule] {
        guard
            let url = bundle.url(
                forResource: "SHOA_ACC_RULES",
                withExtension: "json"
            )
        else {
            throw StoreError.sql(
                "The bundled HOA rules could not be found."
            )
        }

        let data = try Data(contentsOf: url)
        let records = try JSONDecoder().decode(
            [BundledViolationRuleRecord].self,
            from: data
        )

        return records.map { record in
            ViolationCreationRule(
                id: stableRuleID(
                    section: record.ruleSection,
                    title: record.title
                ),
                category: record.category,
                title: record.title,
                ruleSection: record.ruleSection,
                ruleText: record.ruleText,
                noticeText: record.noticeText,
                correctiveAction: record.correctiveAction,
                correctionDays: record.correctionDays,
                isActive: record.isActive
            )
        }
        .sorted {
            let categoryCompare =
                $0.category.localizedCaseInsensitiveCompare(
                    $1.category
                )

            if categoryCompare != .orderedSame {
                return categoryCompare == .orderedAscending
            }

            return $0.title.localizedCaseInsensitiveCompare(
                $1.title
            ) == .orderedAscending
        }
    }

    /// Returns a stable rule identifier even when imported rule data does not provide one.
    static func stableRuleID(
        section: String,
        title: String
    ) -> String {
        let normalized =
            (section + "::" + title)
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .lowercased()

        return normalized
            .unicodeScalars
            .map { scalar in
                CharacterSet.alphanumerics.contains(scalar)
                ? String(scalar)
                : "-"
            }
            .joined()
            .replacingOccurrences(
                of: "--+",
                with: "-",
                options: .regularExpression
            )
            .trimmingCharacters(
                in: CharacterSet(
                    charactersIn: "-"
                )
            )
    }
}
