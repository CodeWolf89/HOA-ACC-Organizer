// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

//
//  ViolationPDFReportGenerator.swift
//  HOA ACC Organizer
//
//  Adapted from PDFReportGenerator.swift supplied for ACCHOAViolationApp.
//  Required Notice: Copyright 2026 Christopher McMahon-Sutton
//  Required Notice: http://www.smoketreehoa.org
//

import Foundation
import CoreGraphics
import CoreText
import ImageIO

/// Pairs a violation attachment record with decoded image data for PDF rendering.
struct ViolationPDFPhotoData: Hashable {
    /// The user-visible caption associated with the attachment or photo.
    let caption: String
    /// The ISO-8601 timestamp associated with the captured photo or observation.
    let capturedAt: String?
    /// The URL used for file url.
    let fileURL: URL
}

/// Aggregates all lot, violation, rule, history, and photo information needed to render a violation PDF.
struct ViolationPDFReportData {
    /// The violation record displayed or processed by this component.
    let violation: ViolationListItem
    /// The lot record displayed or processed by this component.
    let lot: LotDetail
    /// The name of the inspector associated with the violation.
    let inspectorName: String
    /// The governing-rule records associated with this value.
    let rules: [ViolationRuleDetail]
    /// The recorded violation enforcement actions included in the PDF report.
    let actions: [ViolationAction]
    /// The photo records or attachments associated with this value.
    let photos: [ViolationPDFPhotoData]
}

/// Describes failures that prevent a violation PDF from being generated.
enum ViolationPDFReportGeneratorError:
    Error,
    LocalizedError {

    case unableToCreatePDF

    /// A localized description of the error suitable for display to the user.
    var errorDescription: String? {
        "Unable to create the violation PDF report."
    }
}

/// Builds printable violation notices and reports from persisted HOA data.
struct ViolationPDFReportGenerator {
    // Edit these values if the official report heading/contact information changes.
    /// The default association name printed on violation PDF reports.
    static let defaultHOAName =
        "Smoketree Homeowners Association"

    /// The default association contact text printed on violation PDF reports.
    static let defaultContactText =
        "www.smoketreehoa.org"

    /// Returns the violation report heading appropriate for the current enforcement stage.
    static func noticeTitle(
        for status: String
    ) -> String {
        let value =
            status
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .lowercased()

        if value.contains("fee") {
            return "FEE ASSESSMENT NOTICE"
        }

        if value.contains("final") {
            return "FINAL WARNING"
        }

        if value.contains("escalat") {
            return "ESCALATED NOTICE OF VIOLATION"
        }

        if value.contains("resolved") ||
            value.contains("closed") ||
            value.contains("corrected") {
            return "RESOLVED VIOLATION REPORT"
        }

        if value == "open" ||
            value.isEmpty {
            return "NOTICE OF VIOLATION"
        }

        return "VIOLATION REPORT"
    }

    /// Builds a filesystem-safe default filename for generated PDF output.
    static func fileName(
        report: ViolationPDFReportData
    ) -> String {
        fileName(
            lotNumber:
                report.lot.lotNumber,
            status:
                report.violation.status
        )
    }

    /// Builds a filesystem-safe default filename for generated PDF output.
    static func fileName(
        lotNumber: String,
        status: String
    ) -> String {
        let lot =
            safeFileComponent(
                lotNumber.isEmpty
                ? "Unknown"
                : lotNumber
            )

        let statusPart =
            safeFileComponent(
                status.isEmpty
                ? "Violation"
                : status
            )

        return
            "Violation-Lot-\(lot)-\(statusPart).pdf"
    }

    /// Renders the requested document into its final representation.
    static func render(
        report: ViolationPDFReportData,
        hoaName: String = defaultHOAName,
        contactText: String = defaultContactText
    ) throws -> Data {
        let pageWidth:
            CGFloat = 612

        let pageHeight:
            CGFloat = 792

        let margin:
            CGFloat = 54

        let contentWidth =
            pageWidth -
            (margin * 2)

        var mediaBox =
            CGRect(
                x: 0,
                y: 0,
                width: pageWidth,
                height: pageHeight
            )

        let output =
            NSMutableData()

        guard
            let consumer =
                CGDataConsumer(
                    data: output
                ),
            let context =
                CGContext(
                    consumer: consumer,
                    mediaBox: &mediaBox,
                    nil
                )
        else {
            throw
                ViolationPDFReportGeneratorError
                    .unableToCreatePDF
        }

        let displayName =
            hoaName
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .isEmpty
            ? "Homeowners Association"
            : hoaName
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        var cursorY =
            pageHeight - margin

        var pageNumber = 0
        var pageOpen = false

        func attributedText(
            _ text: String,
            size: CGFloat,
            bold: Bool
        ) -> NSAttributedString {
            let font =
                CTFontCreateWithName(
                    (
                        bold
                        ? "Helvetica-Bold"
                        : "Helvetica"
                    ) as CFString,
                    size,
                    nil
                )

            return NSAttributedString(
                string: text,
                attributes: [
                    NSAttributedString.Key(
                        kCTFontAttributeName
                            as String
                    ):
                        font,
                    NSAttributedString.Key(
                        kCTForegroundColorAttributeName
                            as String
                    ):
                        CGColor(
                            gray: 0,
                            alpha: 1
                        )
                ]
            )
        }

        func drawFooter() {
            let footer =
                "\(displayName) • Page \(pageNumber)"

            let line =
                CTLineCreateWithAttributedString(
                    attributedText(
                        footer,
                        size: 8,
                        bold: false
                    )
                )

            context.textPosition =
                CGPoint(
                    x: margin,
                    y: 25
                )

            CTLineDraw(
                line,
                context
            )
        }

        func finishPage() {
            guard pageOpen else {
                return
            }

            drawFooter()
            context.endPDFPage()
            pageOpen = false
        }

        func beginPage() {
            finishPage()

            context.beginPDFPage(
                nil
            )

            context.setFillColor(
                CGColor(
                    gray: 1,
                    alpha: 1
                )
            )

            context.fill(
                mediaBox
            )

            pageNumber += 1
            pageOpen = true
            cursorY =
                pageHeight - margin
        }

        func textHeight(
            _ text: String,
            size: CGFloat,
            bold: Bool
        ) -> CGFloat {
            let attributed =
                attributedText(
                    text,
                    size: size,
                    bold: bold
                )

            let framesetter =
                CTFramesetterCreateWithAttributedString(
                    attributed
                )

            let suggested =
                CTFramesetterSuggestFrameSizeWithConstraints(
                    framesetter,
                    CFRange(
                        location: 0,
                        length: attributed.length
                    ),
                    nil,
                    CGSize(
                        width: contentWidth,
                        height: 10_000
                    ),
                    nil
                )

            return max(
                ceil(suggested.height) + 2,
                size + 2
            )
        }

        func drawText(
            _ text: String,
            size: CGFloat,
            bold: Bool = false,
            spacing: CGFloat = 8
        ) {
            guard
                !text
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    .isEmpty
            else {
                cursorY -= spacing
                return
            }

            let height =
                textHeight(
                    text,
                    size: size,
                    bold: bold
                )

            if cursorY - height <
                margin + 22 {
                beginPage()
            }

            let attributed =
                attributedText(
                    text,
                    size: size,
                    bold: bold
                )

            let framesetter =
                CTFramesetterCreateWithAttributedString(
                    attributed
                )

            let rect =
                CGRect(
                    x: margin,
                    y:
                        cursorY - height,
                    width:
                        contentWidth,
                    height:
                        height
                )

            let path =
                CGPath(
                    rect: rect,
                    transform: nil
                )

            let frame =
                CTFramesetterCreateFrame(
                    framesetter,
                    CFRange(
                        location: 0,
                        length: attributed.length
                    ),
                    path,
                    nil
                )

            CTFrameDraw(
                frame,
                context
            )

            cursorY -=
                height + spacing
        }

        func drawDivider() {
            if cursorY - 12 <
                margin + 22 {
                beginPage()
            }

            context.setStrokeColor(
                CGColor(
                    gray: 0.7,
                    alpha: 1
                )
            )

            context.setLineWidth(
                0.75
            )

            context.move(
                to:
                    CGPoint(
                        x: margin,
                        y: cursorY - 3
                    )
            )

            context.addLine(
                to:
                    CGPoint(
                        x:
                            pageWidth - margin,
                        y: cursorY - 3
                    )
            )

            context.strokePath()
            cursorY -= 14
        }

        func drawImage(
            _ photo: ViolationPDFPhotoData,
            index: Int
        ) {
            guard
                let source =
                    CGImageSourceCreateWithURL(
                        photo.fileURL as CFURL,
                        nil
                    )
            else {
                return
            }

            let options:
                [CFString: Any] = [
                    kCGImageSourceCreateThumbnailFromImageAlways:
                        true,
                    kCGImageSourceCreateThumbnailWithTransform:
                        true,
                    kCGImageSourceThumbnailMaxPixelSize:
                        1800
                ]

            guard
                let image =
                    CGImageSourceCreateThumbnailAtIndex(
                        source,
                        0,
                        options as CFDictionary
                    )
            else {
                return
            }

            let maxHeight:
                CGFloat = 280

            let imageWidth =
                CGFloat(
                    image.width
                )

            let imageHeight =
                CGFloat(
                    image.height
                )

            guard
                imageWidth > 0,
                imageHeight > 0
            else {
                return
            }

            let scale =
                min(
                    1,
                    min(
                        contentWidth /
                            imageWidth,
                        maxHeight /
                            imageHeight
                    )
                )

            let drawWidth =
                imageWidth * scale

            let drawHeight =
                imageHeight * scale

            let captionHeight:
                CGFloat = 35

            if cursorY -
                drawHeight -
                captionHeight <
                margin + 22 {
                beginPage()
            }

            let rect =
                CGRect(
                    x: margin,
                    y:
                        cursorY -
                        drawHeight,
                    width:
                        drawWidth,
                    height:
                        drawHeight
                )

            // `kCGImageSourceCreateThumbnailWithTransform` above already applies
            // the source image's EXIF orientation. Drawing that normalized CGImage
            // directly into the PDF rect preserves the same upright orientation that
            // the user sees in the app. Applying an additional vertical flip here
            // would invert the photo in the generated PDF.
            context.draw(
                image,
                in: rect
            )

            cursorY -=
                drawHeight + 6

            var caption =
                "Photo \(index + 1)"

            if !photo.caption
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .isEmpty {
                caption +=
                    " — \(photo.caption)"
            }

            if let captured =
                formattedDate(
                    photo.capturedAt,
                    dateStyle: .abbreviated,
                    includeTime: true
                ) {
                caption +=
                    " • \(captured)"
            }

            drawText(
                caption,
                size: 9,
                spacing: 12
            )
        }

        beginPage()

        drawText(
            displayName,
            size: 20,
            bold: true,
            spacing: 4
        )

        drawText(
            noticeTitle(
                for:
                    report.violation.status
            ),
            size: 18,
            bold: true,
            spacing: 16
        )

        drawText(
            "Lot \(report.lot.lotNumber) • \(report.lot.ownerName)",
            size: 11,
            bold: true,
            spacing: 4
        )

        drawText(
            "Property: \(report.lot.primaryAddress)",
            size: 11,
            spacing: 4
        )

        drawText(
            "Status: \(report.violation.status)",
            size: 11,
            spacing: 4
        )

        if !report.inspectorName.isEmpty {
            drawText(
                "Inspector: \(report.inspectorName)",
                size: 11,
                spacing: 4
            )
        }

        if let observed =
            formattedDate(
                report.violation.observedAt,
                dateStyle: .long,
                includeTime: true
            ) {
            drawText(
                "Inspection Date: \(observed)",
                size: 11,
                spacing: 4
            )
        }

        if let deadline =
            formattedDate(
                report.violation.correctionDeadline,
                dateStyle: .long,
                includeTime: false
            ) {
            drawText(
                "Original Correction Deadline: \(deadline)",
                size: 11,
                spacing: 4
            )
        }

        if let escalation =
            formattedDate(
                report.violation.escalationDate,
                dateStyle: .long,
                includeTime: true
            ) {
            drawText(
                "Escalation Date: \(escalation)",
                size: 11,
                spacing: 4
            )
        }

        if let finalWarning =
            formattedDate(
                report.violation.finalWarningDate,
                dateStyle: .long,
                includeTime: true
            ) {
            drawText(
                "Final Warning Date: \(finalWarning)",
                size: 11,
                bold: true,
                spacing: 4
            )
        }

        if let fee =
            formattedDate(
                report.violation.feeAssessmentDate,
                dateStyle: .long,
                includeTime: true
            ) {
            drawText(
                "Fee Assessment Date: \(fee)",
                size: 11,
                bold: true,
                spacing: 4
            )
        }

        if let resolved =
            formattedDate(
                report.violation.resolvedDate,
                dateStyle: .long,
                includeTime: true
            ) {
            drawText(
                "Resolved Date: \(resolved)",
                size: 11,
                bold: true,
                spacing: 4
            )
        }

        drawDivider()

        drawText(
            "The association is responsible for administering and enforcing its governing documents in order to support the appearance, safety, and property standards of the community. The property listed above has been observed with one or more conditions that may violate those requirements. Please correct the identified issue by the date provided.",
            size: 10,
            spacing: 14
        )

        drawText(
            report.rules.count == 1
                ? "VIOLATION"
                : "VIOLATIONS",
            size: 14,
            bold: true,
            spacing: 10
        )

        if report.rules.isEmpty {
            drawText(
                report.violation.ruleTitles.isEmpty
                    ? "No rule details were stored with this violation."
                    : report.violation.ruleTitles,
                size: 10,
                spacing: 12
            )
        }

        for (
            index,
            rule
        ) in report.rules.enumerated() {
            let heading =
                "\(index + 1). " +
                (
                    rule.title.isEmpty
                    ? "HOA Rule"
                    : rule.title
                ) +
                (
                    rule.ruleSection.isEmpty
                    ? ""
                    : " — \(rule.ruleSection)"
                )

            drawText(
                heading,
                size: 10,
                bold: true,
                spacing: 4
            )

            if !rule.noticeText.isEmpty {
                drawText(
                    rule.noticeText,
                    size: 10,
                    spacing: 8
                )
            }

            if !rule.ruleText.isEmpty {
                drawText(
                    "GOVERNING DOCUMENT",
                    size: 11,
                    bold: true,
                    spacing: 4
                )

                drawText(
                    rule.ruleText,
                    size: 9.5,
                    spacing: 8
                )
            }

            if !rule.correctiveAction.isEmpty {
                drawText(
                    "Corrective Action: \(rule.correctiveAction)",
                    size: 10,
                    spacing: 12
                )
            }
        }

        if let escalation =
            formattedDate(
                report.violation.escalationDate,
                dateStyle: .long,
                includeTime: false
            ) {
            drawText(
                "ESCALATION",
                size: 12,
                bold: true,
                spacing: 4
            )

            drawText(
                "The original correction period expired without the violation being marked resolved. This matter was escalated on \(escalation).",
                size: 10,
                spacing: 12
            )
        }

        if let finalWarning =
            formattedDate(
                report.violation.finalWarningDate,
                dateStyle: .long,
                includeTime: false
            ) {
            drawText(
                "FINAL WARNING",
                size: 12,
                bold: true,
                spacing: 4
            )

            drawText(
                "The violation remained unresolved after escalation. A final warning was issued on \(finalWarning).",
                size: 10,
                spacing: 12
            )
        }

        if let fee =
            formattedDate(
                report.violation.feeAssessmentDate,
                dateStyle: .long,
                includeTime: false
            ) {
            drawText(
                "FEE ASSESSMENT",
                size: 12,
                bold: true,
                spacing: 4
            )

            drawText(
                "The violation remained unresolved after the final warning. A fee assessment was recorded on \(fee).",
                size: 10,
                spacing: 12
            )
        }

        if let resolved =
            formattedDate(
                report.violation.resolvedDate,
                dateStyle: .long,
                includeTime: false
            ) {
            drawText(
                "RESOLUTION",
                size: 12,
                bold: true,
                spacing: 4
            )

            drawText(
                "The violation was marked resolved on \(resolved) and the case has been closed.",
                size: 10,
                spacing: 12
            )
        }

        if !report.actions.isEmpty {
            drawText(
                "ENFORCEMENT HISTORY",
                size: 12,
                bold: true,
                spacing: 6
            )

            for action in
                report.actions.reversed() {
                let date =
                    formattedDate(
                        action.changedAt,
                        dateStyle: .abbreviated,
                        includeTime: true
                    )
                    ?? action.changedAt

                var line =
                    "\(date): \(action.fromStatus) → \(action.toStatus)"

                if !action.notes
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    .isEmpty {
                    line +=
                        " — \(action.notes)"
                }

                drawText(
                    line,
                    size: 9.5,
                    spacing: 6
                )
            }

            cursorY -= 4
        }

        if !report.violation.notes
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .isEmpty {
            drawText(
                "INSPECTOR NOTES",
                size: 12,
                bold: true,
                spacing: 4
            )

            drawText(
                report.violation.notes,
                size: 10,
                spacing: 12
            )
        }

        if !report.photos.isEmpty {
            drawText(
                "PHOTOGRAPHIC DOCUMENTATION",
                size: 12,
                bold: true,
                spacing: 12
            )

            for (
                index,
                photo
            ) in report.photos.enumerated() {
                drawImage(
                    photo,
                    index: index
                )
            }
        }

        drawText(
            "Please refer to the governing documents provided for your community for complete requirements.",
            size: 9.5,
            spacing: 8
        )

        let contact =
            contactText
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        if !contact.isEmpty {
            drawText(
                "Questions or concerns: \(contact)",
                size: 9.5,
                spacing: 8
            )
        }

        drawText(
            "Sincerely,",
            size: 10,
            spacing: 4
        )

        drawText(
            "\(displayName) Board / Architectural Committee",
            size: 10,
            bold: true,
            spacing: 8
        )

        finishPage()
        context.closePDF()

        return output as Data
    }

    /// Writes generated PDF data to a temporary URL for preview and sharing.
    static func generateTemporaryURL(
        report: ViolationPDFReportData,
        hoaName: String = defaultHOAName,
        contactText: String = defaultContactText
    ) throws -> URL {
        let data =
            try render(
                report: report,
                hoaName: hoaName,
                contactText: contactText
            )

        let url =
            FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    UUID().uuidString +
                    "-" +
                    fileName(
                        report: report
                    )
                )

        try data.write(
            to: url,
            options: .atomic
        )

        return url
    }

    /// Formats a stored ISO-8601 timestamp for user-facing display.
    private static func formattedDate(
        _ value: String?,
        dateStyle:
            Date.FormatStyle.DateStyle,
        includeTime: Bool
    ) -> String? {
        guard
            let value,
            !value
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .isEmpty
        else {
            return nil
        }

        guard
            let date =
                ISODateStorage.date(
                    from: value
                )
        else {
            return value
        }

        if includeTime {
            return date.formatted(
                date: dateStyle,
                time: .shortened
            )
        }

        return date.formatted(
            date: dateStyle,
            time: .omitted
        )
    }

    /// Removes or replaces characters that are unsafe in generated filenames.
    private static func safeFileComponent(
        _ value: String
    ) -> String {
        let invalid =
            CharacterSet
                .alphanumerics
                .union(
                    CharacterSet(
                        charactersIn: "-_"
                    )
                )
                .inverted

        let cleaned =
            value
                .components(
                    separatedBy: invalid
                )
                .filter {
                    !$0.isEmpty
                }
                .joined(
                    separator: "-"
                )

        return cleaned.isEmpty
            ? "Report"
            : cleaned
    }
}
