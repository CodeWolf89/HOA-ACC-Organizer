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

/// Represents violation pdf report generator tests within HOA ACC Organizer.
@MainActor
struct ViolationPDFReportGeneratorTests {
    /// Performs the notice titles cover enforcement stages operation used by `ViolationPDFReportGeneratorTests`.
    @Test
    func noticeTitlesCoverEnforcementStages() {
        #expect(
            ViolationPDFReportGenerator
                .noticeTitle(
                    for: "Open"
                ) ==
                "NOTICE OF VIOLATION"
        )

        #expect(
            ViolationPDFReportGenerator
                .noticeTitle(
                    for: "Escalated"
                ) ==
                "ESCALATED NOTICE OF VIOLATION"
        )

        #expect(
            ViolationPDFReportGenerator
                .noticeTitle(
                    for: "Final Warning"
                ) ==
                "FINAL WARNING"
        )

        #expect(
            ViolationPDFReportGenerator
                .noticeTitle(
                    for: "Fee Assessment"
                ) ==
                "FEE ASSESSMENT NOTICE"
        )

        #expect(
            ViolationPDFReportGenerator
                .noticeTitle(
                    for: "Resolved"
                ) ==
                "RESOLVED VIOLATION REPORT"
        )
    }

    /// Performs the file name is safe for export operation used by `ViolationPDFReportGeneratorTests`.
    @Test
    func fileNameIsSafeForExport() {
        let name =
            ViolationPDFReportGenerator
                .fileName(
                    lotNumber: "52/A",
                    status:
                        "Final Warning"
                )

        #expect(
            name ==
                "Violation-Lot-52-A-Final-Warning.pdf"
        )
    }

    /// Renders er produces readable pdf for `ViolationPDFReportGeneratorTests`.
    @Test
    func rendererProducesReadablePDF() throws {
        let report =
            sampleReport(
                status: "Open"
            )

        let data =
            try ViolationPDFReportGenerator
                .render(
                    report: report,
                    hoaName:
                        "Test Homeowners Association",
                    contactText:
                        "hoa.example.test"
                )

        #expect(data.count > 1_000)

        let signature =
            String(
                decoding:
                    data.prefix(4),
                as: UTF8.self
            )

        #expect(signature == "%PDF")

        let document =
            PDFDocument(
                data: data
            )

        #expect(document != nil)
        #expect(
            (document?.pageCount ?? 0) >= 1
        )

        let text =
            document?.string
            ?? ""

        #expect(
            text.contains(
                "NOTICE OF VIOLATION"
            )
        )

        #expect(
            text.contains(
                "Lot 52"
            )
        )

        #expect(
            text.contains(
                "Corrective Action"
            )
        )
    }

    /// Performs the sample report operation used by `ViolationPDFReportGeneratorTests`.
    private func sampleReport(
        status: String
    ) -> ViolationPDFReportData {
        ViolationPDFReportData(
            violation:
                ViolationListItem(
                    id: "violation-1",
                    status: status,
                    observedAt:
                        "2026-09-01T14:00:00Z",
                    correctionDeadline:
                        "2026-09-15T14:00:00Z",
                    escalationDate: nil,
                    finalWarningDate: nil,
                    feeAssessmentDate: nil,
                    resolvedDate: nil,
                    notes:
                        "Fence requires maintenance.",
                    adminNotes: "",
                    ruleTitles:
                        "Exterior Maintenance",
                    photoCount: 0
                ),
            lot:
                LotDetail(
                    id: "lot-52",
                    lotNumber: "52",
                    ownerName:
                        "Sample Homeowner",
                    primaryAddress:
                        "11711 Woodland View Drive Fredericksburg VA 22407",
                    billingAddress: "",
                    primaryPhone: "",
                    secondaryPhone: "",
                    primaryEmail: "",
                    secondaryEmail: "",
                    isRentalUnit: false
                ),
            inspectorName:
                "ACC Inspector",
            rules: [
                ViolationRuleDetail(
                    id: "rule-1",
                    title:
                        "Exterior Maintenance",
                    category:
                        "Property Maintenance",
                    ruleSection: "4.1",
                    noticeText:
                        "Exterior surfaces must be maintained.",
                    correctiveAction:
                        "Repair and repaint the affected area.",
                    ruleText:
                        "Owners shall maintain exterior improvements in good condition."
                )
            ],
            actions: [],
            photos: []
        )
    }
}
