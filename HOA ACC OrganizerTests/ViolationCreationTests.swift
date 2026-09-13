// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import Foundation
import Testing
@testable import HOA_ACC_Organizer

/// Represents violation creation tests within HOA ACC Organizer.
struct ViolationCreationTests {
    /// Performs the correction deadline uses longest selected rule operation used by `ViolationCreationTests`.
    @Test
    func correctionDeadlineUsesLongestSelectedRule() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let observed = Date(
            timeIntervalSince1970: 1_767_225_600
        )

        let rules = [
            rule(id: "a", days: 10),
            rule(id: "b", days: 25),
            rule(id: "c", days: 16)
        ]

        let deadline =
            ViolationCreationDraft
                .correctionDeadline(
                    observedAt: observed,
                    rules: rules,
                    calendar: calendar
                )

        let expected = calendar.date(
            byAdding: .day,
            value: 25,
            to: observed
        )!

        #expect(deadline == expected)
    }

    /// Performs the correction deadline defaults to seven days when no rule is selected operation used by `ViolationCreationTests`.
    @Test
    func correctionDeadlineDefaultsToSevenDaysWhenNoRuleIsSelected() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let observed = Date(
            timeIntervalSince1970: 1_767_225_600
        )

        let deadline =
            ViolationCreationDraft
                .correctionDeadline(
                    observedAt: observed,
                    rules: [],
                    calendar: calendar
                )

        let expected = calendar.date(
            byAdding: .day,
            value: 7,
            to: observed
        )!

        #expect(deadline == expected)
    }

    /// Performs the bundled rule identity is stable for same section and title operation used by `ViolationCreationTests`.
    @Test
    func bundledRuleIdentityIsStableForSameSectionAndTitle() {
        let first =
            ViolationRuleCatalog.stableRuleID(
                section: "ARTICLE III Section 3",
                title: "No Commercial Ventures"
            )

        let second =
            ViolationRuleCatalog.stableRuleID(
                section: "ARTICLE III Section 3",
                title: "No Commercial Ventures"
            )

        #expect(first == second)
        #expect(!first.isEmpty)
    }

    /// Performs the rule operation used by `ViolationCreationTests`.
    private func rule(
        id: String,
        days: Int
    ) -> ViolationCreationRule {
        ViolationCreationRule(
            id: id,
            category: "Test",
            title: "Test Rule \(id)",
            ruleSection: "Section \(id)",
            ruleText: "Rule text",
            noticeText: "Notice",
            correctiveAction: "Correct it",
            correctionDays: days,
            isActive: true
        )
    }
}
