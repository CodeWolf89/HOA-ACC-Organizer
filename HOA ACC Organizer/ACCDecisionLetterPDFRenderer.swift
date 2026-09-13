// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import Foundation
import CoreGraphics
import CoreText

/// Describes failures encountered while creating an ACC decision-letter PDF.
enum ACCDecisionLetterRendererError:
    Error,
    LocalizedError {

    case unableToCreatePDF

    /// A localized description of the error suitable for display to the user.
    var errorDescription: String? {
        "Unable to create the ACC decision-letter PDF."
    }
}

/// Renders source-controlled ACC approval and denial templates into portable PDF documents.
enum ACCDecisionLetterPDFRenderer {
    /// Renders render for `ACCDecisionLetterPDFRenderer`.
    static func render(
        request: ACCRequestDetail,
        lot: LotDetail,
        template:
            ACCDecisionLetterTemplate
    ) throws -> Data {
        let pageSize =
            pdfPageSize(
                template.pageFormat
            )

        var mediaBox =
            CGRect(
                origin: .zero,
                size: pageSize
            )

        let output =
            NSMutableData()

        guard
            let consumer =
                CGDataConsumer(
                    data:
                        output
                ),
            let context =
                CGContext(
                    consumer:
                        consumer,
                    mediaBox:
                        &mediaBox,
                    nil
                )
        else {
            throw
                ACCDecisionLetterRendererError
                    .unableToCreatePDF
        }

        let margin =
            min(
                max(
                    template.pageMargin,
                    30
                ),
                100
            )

        let decision =
            decisionHeading(
                status:
                    request.status,
                template:
                    template
            )

        let bodyTemplate =
            decisionBody(
                status:
                    request.status,
                template:
                    template
            )

        let replacements =
            placeholderValues(
                request:
                    request,
                lot:
                    lot,
                decision:
                    decision
            )

        let bodyText =
            replacingPlaceholders(
                bodyTemplate,
                values:
                    replacements
            )

        let footerText =
            replacingPlaceholders(
                template.footerText,
                values:
                    replacements
            )

        let body =
            attributed(
                bodyText,
                size:
                    min(
                        max(
                            template.bodyFontSize,
                            8
                        ),
                        18
                    ),
                bold: false
            )

        let framesetter =
            CTFramesetterCreateWithAttributedString(
                body as CFAttributedString
            )

        var bodyLocation = 0
        var pageIndex = 0

        repeat {
            context.beginPDFPage(
                nil
            )

            context.textMatrix =
                .identity

            let bodyTop:
                CGFloat

            if pageIndex == 0 {
                var y =
                    pageSize.height -
                    margin -
                    CGFloat(
                        template
                            .decisionFontSize
                    )

                drawCenteredLine(
                    decision,
                    y: y,
                    size:
                        min(
                            max(
                                template
                                    .decisionFontSize,
                                16
                            ),
                            36
                        ),
                    bold: true,
                    context:
                        context,
                    pageWidth:
                        pageSize.width
                )

                y -= 38

                drawCenteredLine(
                    template
                        .associationName,
                    y: y,
                    size:
                        min(
                            max(
                                template
                                    .headerFontSize,
                                10
                            ),
                            22
                        ),
                    bold: true,
                    context:
                        context,
                    pageWidth:
                        pageSize.width
                )

                y -= 21

                drawCenteredLine(
                    template
                        .committeeName,
                    y: y,
                    size:
                        max(
                            9,
                            template
                                .headerFontSize -
                            1
                        ),
                    bold: false,
                    context:
                        context,
                    pageWidth:
                        pageSize.width
                )

                y -= 22

                context.setStrokeColor(
                    CGColor(
                        gray: 0.45,
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
                            y: y
                        )
                )

                context.addLine(
                    to:
                        CGPoint(
                            x:
                                pageSize.width -
                                margin,
                            y: y
                        )
                )

                context.strokePath()

                bodyTop =
                    y - 22
            } else {
                bodyTop =
                    pageSize.height -
                    margin
            }

            let footerReserve:
                CGFloat =
                32

            let bodyBottom =
                margin +
                footerReserve

            let bodyRect =
                CGRect(
                    x: margin,
                    y: bodyBottom,
                    width:
                        pageSize.width -
                        (margin * 2),
                    height:
                        max(
                            80,
                            bodyTop -
                            bodyBottom
                        )
                )

            let path =
                CGPath(
                    rect:
                        bodyRect,
                    transform: nil
                )

            let frame =
                CTFramesetterCreateFrame(
                    framesetter,
                    CFRange(
                        location:
                            bodyLocation,
                        length: 0
                    ),
                    path,
                    nil
                )

            CTFrameDraw(
                frame,
                context
            )

            let visible =
                CTFrameGetVisibleStringRange(
                    frame
                )

            drawFooter(
                footerText,
                pageNumber:
                    pageIndex + 1,
                margin:
                    margin,
                pageSize:
                    pageSize,
                context:
                    context
            )

            context.endPDFPage()

            guard
                visible.length > 0
            else {
                break
            }

            bodyLocation +=
                visible.length

            pageIndex += 1

        } while bodyLocation <
            body.length

        context.closePDF()

        return output as Data
    }

    /// Builds a filesystem-safe default filename for generated PDF output.
    static func fileName(
        request: ACCRequestDetail,
        lot: LotDetail
    ) -> String {
        let decision =
            request.status
                .replacingOccurrences(
                    of: " ",
                    with: "-"
                )
                .replacingOccurrences(
                    of: "/",
                    with: "-"
                )

        return
            "ACC-\(decision)-Lot-\(lot.lotNumber).pdf"
    }

    /// Returns the page dimensions selected by the decision-letter source template.
    private static func pdfPageSize(
        _ format: String
    ) -> CGSize {
        if format
            .lowercased()
            .contains("a4") {
            return CGSize(
                width: 595.28,
                height: 841.89
            )
        }

        return CGSize(
            width: 612,
            height: 792
        )
    }

    /// Returns the heading text corresponding to the ACC application’s decision status.
    private static func decisionHeading(
        status: String,
        template:
            ACCDecisionLetterTemplate
    ) -> String {
        let value =
            status.lowercased()

        if value.contains(
            "condition"
        ) {
            return template
                .conditionalHeading
        }

        if value.contains(
            "approved"
        ) {
            return template
                .approvedHeading
        }

        if value.contains("denied") ||
            value.contains("rejected") {
            return template
                .deniedHeading
        }

        return status.uppercased()
    }

    /// Returns the body template corresponding to the ACC application’s decision status.
    private static func decisionBody(
        status: String,
        template:
            ACCDecisionLetterTemplate
    ) -> String {
        let value =
            status.lowercased()

        if value.contains(
            "condition"
        ) {
            return template
                .conditionalBody
        }

        if value.contains(
            "approved"
        ) {
            return template
                .approvalBody
        }

        return template
            .deniedBody
    }

    /// Builds the placeholder-to-value dictionary used when rendering an ACC decision letter.
    private static func placeholderValues(
        request: ACCRequestDetail,
        lot: LotDetail,
        decision: String
    ) -> [String: String] {
        [
            "{{applicantName}}":
                request.applicantName,
            "{{ownerName}}":
                lot.ownerName,
            "{{lotNumber}}":
                lot.lotNumber,
            "{{propertyAddress}}":
                lot.primaryAddress,
            "{{phone}}":
                request
                    .applicantPhone
                    .isEmpty
                ? lot.primaryPhone
                : request.applicantPhone,
            "{{email}}":
                lot.primaryEmail,
            "{{description}}":
                request.description,
            "{{color}}":
                request.color,
            "{{submittedDate}}":
                displayDate(
                    request.submittedAt
                ),
            "{{proposedStartDate}}":
                displayDate(
                    request
                        .proposedStartDate
                ),
            "{{proposedCompletionDate}}":
                displayDate(
                    request
                        .proposedCompletionDate
                ),
            "{{decision}}":
                decision,
            "{{decisionDate}}":
                displayDate(
                    request
                        .chairpersonSignatureDate
                    ?? request.updatedAt
                ),
            "{{recommendation}}":
                request.accRecommendation,
            "{{remarks}}":
                request.remarks,
            "{{chairperson}}":
                request
                    .chairpersonSignature
        ]
    }

    /// Replaces supported decision-letter template placeholders with application values.
    private static func replacingPlaceholders(
        _ text: String,
        values: [String: String]
    ) -> String {
        values.reduce(
            text
        ) {
            partial,
            entry in

            partial
                .replacingOccurrences(
                    of: entry.key,
                    with: entry.value
                )
        }
    }

    /// Formats a stored date for human-readable PDF output.
    private static func displayDate(
        _ value: String?
    ) -> String {
        guard
            let value,
            !value.isEmpty
        else {
            return ""
        }

        if let date =
            ISODateStorage.date(
                from: value
            ) {
            return date.formatted(
                date: .long,
                time: .omitted
            )
        }

        return value
    }

    /// Creates attributed text with the requested PDF font and paragraph settings.
    private static func attributed(
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

    /// Draws one centered line into the current PDF graphics context.
    private static func drawCenteredLine(
        _ text: String,
        y: CGFloat,
        size: CGFloat,
        bold: Bool,
        context: CGContext,
        pageWidth: CGFloat
    ) {
        guard !text.isEmpty else {
            return
        }

        let line =
            CTLineCreateWithAttributedString(
                attributed(
                    text,
                    size: size,
                    bold: bold
                )
            )

        let width =
            CGFloat(
                CTLineGetTypographicBounds(
                    line,
                    nil,
                    nil,
                    nil
                )
            )

        context.textPosition =
            CGPoint(
                x:
                    max(
                        0,
                        (pageWidth - width) /
                        2
                    ),
                y: y
            )

        CTLineDraw(
            line,
            context
        )
    }

    /// Draws the association footer and page number on a generated PDF page.
    private static func drawFooter(
        _ footerText: String,
        pageNumber: Int,
        margin: CGFloat,
        pageSize: CGSize,
        context: CGContext
    ) {
        let value =
            footerText +
            "  •  Page \(pageNumber)"

        let line =
            CTLineCreateWithAttributedString(
                attributed(
                    value,
                    size: 8,
                    bold: false
                )
            )

        context.textPosition =
            CGPoint(
                x: margin,
                y:
                    max(
                        14,
                        margin - 18
                    )
            )

        CTLineDraw(
            line,
            context
        )
    }
}
