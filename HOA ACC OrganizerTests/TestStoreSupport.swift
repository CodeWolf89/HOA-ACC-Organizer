// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import Foundation
@testable import HOA_ACC_Organizer

/// Creates an isolated SQLite database and attachment directory for integration tests.
final class TestStoreSandbox {
    /// The URL used for root url.
    let rootURL: URL
    /// The URL used for database url.
    let databaseURL: URL
    /// The URL used for attachments url.
    let attachmentsURL: URL
    /// The SQLite persistence store used by this component.
    let store: SQLiteStore

    /// Creates a new `TestStoreSandbox` instance with the supplied values.
    init() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("HOAACCOrganizerTests-\(UUID().uuidString)", isDirectory: true)
        databaseURL = rootURL.appendingPathComponent("test.sqlite")
        attachmentsURL = rootURL.appendingPathComponent("Attachments", isDirectory: true)

        try FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true
        )

        store = SQLiteStore(
            databaseURL: databaseURL,
            attachmentsDirectoryURL: attachmentsURL
        )
        try store.open()
    }

    /// Releases resources owned by `TestStoreSandbox` when the instance is deallocated.
    deinit {
        store.close()
        try? FileManager.default.removeItem(at: rootURL)
    }
}

/// Builds a representative full-data package used by persistence and transfer tests.
func makeSampleFullDataPackage(
    lotID: String = "remote-lot-52",
    ownerName: String = "Sample Owner",
    includeAttachment: Bool = true
) -> FullDataExportPackage {
    let photoData = Data("sample-photo".utf8)
    let attachment = ExportAttachment(
        id: "attachment-1",
        kind: "violationPhoto",
        fileName: "sample-photo.jpg",
        originalFileName: "sample-photo.jpg",
        mimeType: "image/jpeg",
        contentHash: "sample-photo-hash",
        capturedAt: "2026-09-10T12:00:00Z",
        caption: "Fence condition",
        createdAt: "2026-09-10T12:00:00Z",
        base64Data: includeAttachment ? photoData.base64EncodedString() : ""
    )

    let violation = ExportViolationRecord(
        id: "violation-1",
        observedAt: "2026-09-10T12:00:00Z",
        correctionDeadline: "2026-09-20T12:00:00Z",
        createdAt: "2026-09-10T12:00:00Z",
        escalationDate: nil,
        finalWarningDate: nil,
        feeAssessmentDate: nil,
        resolvedDate: nil,
        inspectorName: "Inspector",
        notes: "Fence needs repair.",
        adminNotes: "",
        status: "Open",
        sourceHash: "source-1",
        updatedAt: "2026-09-10T12:00:00Z",
        rules: [
            ExportViolationRule(
                ruleID: "rule-1",
                title: "Exterior Maintenance",
                category: "Maintenance",
                ruleSection: "4.1",
                correctionDays: 10,
                noticeText: "Maintain exterior improvements.",
                correctiveAction: "Repair the fence.",
                ruleText: "Exterior improvements must be maintained."
            )
        ],
        attachments: includeAttachment ? [attachment] : []
    )

    let application = ExportACCRequestRecord(
        id: "acc-1",
        applicantName: "Sample Owner",
        applicantPhone: "540-555-0100",
        proposedChangeAddress: "11711 Woodland View Drive",
        description: "Replace rear deck",
        color: "Brown",
        proposedStartDate: "2026-10-01T00:00:00Z",
        proposedCompletionDate: "2026-10-15T00:00:00Z",
        submittedAt: "2026-09-11T00:00:00Z",
        importedAt: "2026-09-11T12:00:00Z",
        status: "Under Review",
        accRecommendation: "",
        remarks: "",
        applicantSignature: "Sample Owner",
        applicantSignatureDate: "2026-09-11T00:00:00Z",
        chairpersonSignature: "",
        chairpersonSignatureDate: nil,
        sourceOCRText: "OCR sample",
        createdAt: "2026-09-11T12:00:00Z",
        updatedAt: "2026-09-11T12:00:00Z",
        neighbors: [
            ACCNeighbor(
                id: "neighbor-1",
                name: "Neighbor",
                address: "Next Door",
                lotNumber: "53",
                signatureObserved: true
            )
        ],
        attachments: []
    )

    return FullDataExportPackage(
        format: FullDataTransferService.format,
        version: FullDataTransferService.version,
        exportedAt: "2026-09-12T12:00:00Z",
        lots: [
            ExportLotRecord(
                id: lotID,
                lotNumber: "52",
                ownerName: ownerName,
                primaryAddress: "11711 Woodland View Drive Fredericksburg VA 22407",
                billingAddress: "",
                primaryPhone: "540-555-0100",
                secondaryPhone: "",
                primaryEmail: "owner@example.com",
                secondaryEmail: "",
                isRentalUnit: false,
                violations: [violation],
                accApplications: [application]
            )
        ]
    )
}
