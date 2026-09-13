// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import Foundation
import PDFKit
import Testing
@testable import HOA_ACC_Organizer

/// Represents acc decision letter pdf renderer tests within HOA ACC Organizer.
struct ACCDecisionLetterPDFRendererTests {
    /// Performs the approved application produces readable decision pdf operation used by `ACCDecisionLetterPDFRendererTests`.
    @Test
    func approvedApplicationProducesReadableDecisionPDF() throws {
        let request = ACCRequestDetail(
            id: "acc-1",
            lotID: "lot-52",
            applicantName: "Sample Owner",
            applicantPhone: "540-555-0100",
            proposedChangeAddress: "11711 Woodland View Drive",
            description: "Replace rear deck",
            color: "Brown",
            proposedStartDate: "2026-10-01T00:00:00Z",
            proposedCompletionDate: "2026-10-15T00:00:00Z",
            submittedAt: "2026-09-11T00:00:00Z",
            importedAt: "2026-09-11T12:00:00Z",
            status: "Approved",
            applicantSignature: "Sample Owner",
            applicantSignatureDate: "2026-09-11T00:00:00Z",
            accRecommendation: "Approved as submitted.",
            remarks: "",
            chairpersonSignature: "ACC Chair",
            chairpersonSignatureDate: "2026-09-12T00:00:00Z",
            createdAt: "2026-09-11T12:00:00Z",
            updatedAt: "2026-09-12T12:00:00Z",
            neighbors: [],
            pdfFileName: nil,
            pdfOriginalName: nil
        )

        let lot = LotDetail(
            id: "lot-52",
            lotNumber: "52",
            ownerName: "Sample Owner",
            primaryAddress: "11711 Woodland View Drive Fredericksburg VA 22407",
            billingAddress: "",
            primaryPhone: "540-555-0100",
            secondaryPhone: "",
            primaryEmail: "owner@example.com",
            secondaryEmail: "",
            isRentalUnit: false
        )

        let data = try ACCDecisionLetterPDFRenderer.render(
            request: request,
            lot: lot,
            template: .sourceTemplate
        )

        #expect(String(decoding: data.prefix(4), as: UTF8.self) == "%PDF")
        let document = PDFDocument(data: data)
        #expect(document != nil)
        let text = document?.string ?? ""
        #expect(text.contains("APPROVED"))
        #expect(text.contains("Lot 52"))
        #expect(text.contains("Replace rear deck"))
    }
}
