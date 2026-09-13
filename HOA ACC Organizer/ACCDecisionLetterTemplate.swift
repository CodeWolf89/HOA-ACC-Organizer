// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import Foundation

/// Source-code configuration for ACC decision letters.
///
/// To change the wording or basic PDF layout, edit the values in
/// `ACCDecisionLetterTemplate.sourceTemplate` below and rebuild the app.
///
/// This is intentionally source-controlled rather than editable in the UI so
/// administrators cannot accidentally alter official correspondence formatting.
struct ACCDecisionLetterTemplate: Codable, Hashable {
    /// The association name printed on generated ACC decision letters.
    var associationName: String
    /// The committee name printed on generated ACC decision letters.
    var committeeName: String

    /// The heading printed on approved ACC decision letters.
    var approvedHeading: String
    /// The heading printed on conditionally approved ACC decision letters.
    var conditionalHeading: String
    /// The heading printed on denied ACC decision letters.
    var deniedHeading: String

    /// The source-controlled body template for approval letters.
    var approvalBody: String
    /// The source-controlled body template for conditional-approval letters.
    var conditionalBody: String
    /// The source-controlled body template for denial letters.
    var deniedBody: String

    /// The footer printed on generated ACC decision letters.
    var footerText: String

    /// The date or timestamp associated with page format.
    var pageFormat: String
    /// The PDF page margin, measured in points.
    var pageMargin: Double

    /// The font size used for the decision heading in generated letters.
    var decisionFontSize: Double
    /// The font size used for the association/committee heading in generated letters.
    var headerFontSize: Double
    /// The font size used for body text in generated letters.
    var bodyFontSize: Double

    /// Edit this one value to change the letter template used by the app.
    static let sourceTemplate = ACCDecisionLetterTemplate(
        associationName: "Smoketree Homeowners Association",
        committeeName: "Architectural Control Committee",

        approvedHeading: "APPROVED",
        conditionalHeading: "APPROVED WITH CONDITIONS",
        deniedHeading: "DENIED",

        approvalBody: """
        {{decisionDate}}

        Dear {{applicantName}},

        The Architectural Control Committee has completed its review of the application for Lot {{lotNumber}} at {{propertyAddress}}.

        Proposed change:
        {{description}}

        Color / materials:
        {{color}}

        Proposed start:
        {{proposedStartDate}}

        Proposed completion:
        {{proposedCompletionDate}}

        The application is APPROVED as submitted.

        ACC recommendation:
        {{recommendation}}

        ACC remarks:
        {{remarks}}

        Please retain this decision letter with your property records. This approval applies only to the work described in the application.
        """,

        conditionalBody: """
        {{decisionDate}}

        Dear {{applicantName}},

        The Architectural Control Committee has completed its review of the application for Lot {{lotNumber}} at {{propertyAddress}}.

        Proposed change:
        {{description}}

        The application is APPROVED WITH CONDITIONS.

        Conditions / recommendation:
        {{recommendation}}

        ACC remarks:
        {{remarks}}

        Please retain this decision letter with your property records and ensure the approved conditions are followed.
        """,

        deniedBody: """
        {{decisionDate}}

        Dear {{applicantName}},

        The Architectural Control Committee has completed its review of the application for Lot {{lotNumber}} at {{propertyAddress}}.

        Proposed change:
        {{description}}

        The application is DENIED.

        ACC recommendation / reason:
        {{recommendation}}

        ACC remarks:
        {{remarks}}

        Please retain this decision letter with your property records. Contact the Architectural Control Committee if you would like clarification regarding this decision.
        """,

        footerText: "Smoketree Homeowners Association - Architectural Control Committee",

        // Supported by the renderer: "US Letter" or "A4"
        pageFormat: "US Letter",

        // PDF points. 72 points = 1 inch.
        pageMargin: 54,

        decisionFontSize: 24,
        headerFontSize: 13,
        bodyFontSize: 11
    )

    /// Available placeholders for use in the body strings above.
    static let placeholders: [String] = [
        "{{applicantName}}",
        "{{ownerName}}",
        "{{lotNumber}}",
        "{{propertyAddress}}",
        "{{phone}}",
        "{{email}}",
        "{{description}}",
        "{{color}}",
        "{{submittedDate}}",
        "{{proposedStartDate}}",
        "{{proposedCompletionDate}}",
        "{{decision}}",
        "{{decisionDate}}",
        "{{recommendation}}",
        "{{remarks}}",
        "{{chairperson}}"
    ]
}
