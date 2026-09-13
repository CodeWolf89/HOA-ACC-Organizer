// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

// TEST FIX VERSION: 2026-09-12-R2
// Throwing SQLite/file operations are evaluated before #require/#expect.

import Foundation
import Testing
@testable import HOA_ACC_Organizer

/// Represents violation workflow integration tests within HOA ACC Organizer.
struct ViolationWorkflowIntegrationTests {
    /// Performs the locally created violation persists rules photos and open issue operation used by `ViolationWorkflowIntegrationTests`.
    @Test
    func locallyCreatedViolationPersistsRulesPhotosAndOpenIssue() throws {
        let sandbox = try TestStoreSandbox()
        try sandbox.store.importFullDataExportPackage(
            makeSampleFullDataPackage(includeAttachment: false),
            sourceFileName: "seed.json"
        )

        let matchingLots =
            try sandbox.store
                .fetchLotSummaries(
                    search: "52"
                )

        let lot =
            try #require(
                matchingLots.first
            )
        let observed = Date(timeIntervalSince1970: 1_778_000_000)
        let rule = ViolationCreationRule(
            id: "rule-local",
            category: "Test",
            title: "Local Rule",
            ruleSection: "1.1",
            ruleText: "Full rule text",
            noticeText: "Notice text",
            correctiveAction: "Correct it",
            correctionDays: 7,
            isActive: true
        )
        let photo = ViolationCreationPhoto(
            id: "photo-local",
            imageData: Data("image-bytes".utf8),
            capturedAt: observed,
            caption: "Test photo"
        )
        let draft = ViolationCreationDraft(
            id: "local-violation",
            lotID: lot.id,
            observedAt: observed,
            correctionDeadline: ViolationCreationDraft.correctionDeadline(
                observedAt: observed,
                rules: [rule]
            ),
            inspectorName: "Standard User",
            notes: "Created on iPhone",
            rules: [rule],
            photos: [photo]
        )

        let id =
            try sandbox.store
                .createViolation(draft)

        let fetchedViolation =
            try sandbox.store
                .fetchViolation(id)

        let violation =
            try #require(
                fetchedViolation
            )
        let rules = try sandbox.store.fetchViolationRules(violationID: id)
        let photos = try sandbox.store.fetchViolationAttachments(violationID: id)
        let issues = try sandbox.store.fetchOpenIssues()

        #expect(violation.status == "Open")
        #expect(rules.count == 1)
        #expect(rules[0].ruleText == "Full rule text")
        #expect(photos.count == 1)
        #expect(issues.contains { $0.id == id })
        let photoURL =
            try sandbox.store
                .attachmentURL(
                    fileName:
                        "photo-local.jpg"
                )

        #expect(
            FileManager.default
                .fileExists(
                    atPath:
                        photoURL.path
                )
        )
    }
}
