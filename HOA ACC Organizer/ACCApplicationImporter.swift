// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import Foundation
import PDFKit
import Vision
import CryptoKit
import CoreGraphics

/// Describes failures that can occur while importing and recognizing an ACC application PDF.
enum ACCApplicationImportError: Error, LocalizedError {
    case unreadablePDF
    case noPages

    /// A localized description of the error suitable for display to the user.
    var errorDescription: String? {
        switch self {
        case .unreadablePDF:
            return "The selected file could not be opened as a PDF."
        case .noPages:
            return "The selected PDF does not contain any pages."
        }
    }
}

/// Imports ACC application PDFs, performs local OCR, and prepares editable application drafts.
final class ACCApplicationImporter {
    /// The SQLite persistence store used by this component.
    private let store: SQLiteStore

    /// Creates a new `ACCApplicationImportError` instance with the supplied values.
    init(store: SQLiteStore) {
        self.store = store
    }

    /// Copies the original PDF into app-managed storage, performs local OCR with
    /// Apple Vision, and returns an editable draft. The original PDF is never
    /// modified.
    func prepareDraft(
        from url: URL,
        lot: LotDetail
    ) async throws -> ACCApplicationDraft {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped { url.stopAccessingSecurityScopedResource() }
        }

        let data = try Data(contentsOf: url)
        guard let document = PDFDocument(data: data) else {
            throw ACCApplicationImportError.unreadablePDF
        }
        guard document.pageCount > 0 else {
            throw ACCApplicationImportError.noPages
        }

        let requestID = UUID().uuidString
        let storedFileName = try storeACCApplicationPDF(
            data: data,
            requestID: requestID,
            originalName: url.lastPathComponent
        )

        let recognizedText = try await Task.detached(priority: .userInitiated) {
            try Self.extractText(from: document)
        }.value

        let fallbackDraft = Self.templateAwareDraft(
            from: recognizedText,
            lot: lot
        )

        let outcome =
            await ACCOnDeviceApplicationParser
                .enhance(
                    ocrText: recognizedText,
                    lot: lot,
                    fallbackDraft: fallbackDraft
                )

        var draft = outcome.draft
        draft.id = requestID
        draft.sourcePDFFileName = storedFileName
        draft.sourcePDFOriginalName = url.lastPathComponent
        draft.ocrText = recognizedText
        draft.ocrUsedOnDeviceModel =
            outcome.usedFoundationModel
        draft.ocrAssistanceMessage =
            outcome.message

        return draft
    }

    /// Copies the selected original ACC PDF into managed attachment storage and returns its metadata.
    private func storeACCApplicationPDF(
        data: Data,
        requestID: String,
        originalName: String
    ) throws -> String {
        let fm = FileManager.default
        let base = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        .appendingPathComponent("HOAACCOrganizer", isDirectory: true)
        .appendingPathComponent("Attachments", isDirectory: true)

        try fm.createDirectory(
            at: base,
            withIntermediateDirectories: true
        )

        let safeOriginal = originalName
            .replacingOccurrences(of: "/", with: "-")
        let fileName = "acc-\(requestID)-\(safeOriginal)"
        let destination = base.appendingPathComponent(fileName)

        try data.write(
            to: destination,
            options: .atomic
        )

        return fileName
    }

    /// Extracts embedded PDF text or falls back to page rendering and Vision OCR.
    nonisolated private static func extractText(
        from document: PDFDocument
    ) throws -> String {
        var pages: [String] = []

        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else {
                continue
            }

            // Prefer embedded PDF text when available.
            let embedded = page.string?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if !embedded.isEmpty {
                pages.append(embedded)
                continue
            }

            guard let image = render(page: page) else {
                continue
            }

            pages.append(
                try recognizeText(in: image)
            )
        }

        return pages.joined(
            separator: "\n\n--- PAGE ---\n\n"
        )
    }

    /// Renders the requested document into its final representation.
    nonisolated private static func render(
        page: PDFPage
    ) -> CGImage? {
        let box = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2.0

        let width = max(
            1,
            Int(box.width * scale)
        )
        let height = max(
            1,
            Int(box.height * scale)
        )

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.setFillColor(
            CGColor(
                red: 1,
                green: 1,
                blue: 1,
                alpha: 1
            )
        )
        context.fill(
            CGRect(
                x: 0,
                y: 0,
                width: width,
                height: height
            )
        )

        context.saveGState()
        context.scaleBy(
            x: scale,
            y: scale
        )
        page.draw(
            with: .mediaBox,
            to: context
        )
        context.restoreGState()

        return context.makeImage()
    }

    /// Runs Vision text recognition for one rendered PDF page image.
    nonisolated private static func recognizeText(
        in image: CGImage
    ) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US"]

        let handler = VNImageRequestHandler(
            cgImage: image,
            options: [:]
        )
        try handler.perform([request])

        let observations = request.results ?? []

        return observations
            .compactMap {
                $0.topCandidates(1).first?.string
            }
            .joined(separator: "\n")
    }

    /// First-pass extraction tuned to the two-page Smoketree application.
    /// OCR output is always shown for human review before saving.
    private static func templateAwareDraft(
        from text: String,
        lot: LotDetail
    ) -> ACCApplicationDraft {
        var draft = ACCApplicationDraft(
            lotID: lot.id
        )

        draft.proposedChangeAddress =
            lot.primaryAddress
        draft.applicantName =
            lot.ownerName
        draft.applicantPhone =
            !lot.primaryPhone.isEmpty
                ? lot.primaryPhone
                : lot.secondaryPhone

        let lines = text
            .components(separatedBy: .newlines)
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .filter { !$0.isEmpty }

        draft.applicantName =
            value(afterAnyLabel: [
                "applicant name",
                "name of applicant",
                "applicant"
            ], in: lines) ?? draft.applicantName

        draft.proposedChangeAddress =
            value(afterAnyLabel: [
                "address of proposed change",
                "proposed change address",
                "property address"
            ], in: lines) ?? draft.proposedChangeAddress

        draft.applicantPhone =
            value(afterAnyLabel: [
                "home phone",
                "phone"
            ], in: lines) ?? draft.applicantPhone

        draft.description =
            multilineValue(
                afterAnyLabel: [
                    "description of change",
                    "description"
                ],
                stoppingAt: [
                    "color",
                    "proposed start",
                    "start date",
                    "proposed completion"
                ],
                in: lines
            ) ?? ""

        draft.color =
            value(afterAnyLabel: [
                "color"
            ], in: lines) ?? ""

        draft.proposedStartDate =
            ISODateStorage.date(
                from:
                    value(
                        afterAnyLabel: [
                            "proposed start date",
                            "start date"
                        ],
                        in: lines
                    )
            )

        draft.proposedCompletionDate =
            ISODateStorage.date(
                from:
                    value(
                        afterAnyLabel: [
                            "proposed completion date",
                            "completion date"
                        ],
                        in: lines
                    )
            )

        draft.accRecommendation =
            multilineValue(
                afterAnyLabel: [
                    "acc recommendations",
                    "recommendations"
                ],
                stoppingAt: [
                    "remarks",
                    "chairperson"
                ],
                in: lines
            ) ?? ""

        draft.remarks =
            multilineValue(
                afterAnyLabel: [
                    "remarks"
                ],
                stoppingAt: [
                    "chairperson"
                ],
                in: lines
            ) ?? ""

        return draft
    }

    /// Extracts the best single-line field value associated with a recognized ACC form label.
    private static func value(
        afterAnyLabel labels: [String],
        in lines: [String]
    ) -> String? {
        for (index, line) in lines.enumerated() {
            let lower = line.lowercased()

            for label in labels {
                guard lower.contains(label) else {
                    continue
                }

                if let colon = line.firstIndex(of: ":") {
                    let value = String(
                        line[line.index(after: colon)...]
                    )
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )

                    if !value.isEmpty {
                        return value
                    }
                }

                if index + 1 < lines.count {
                    let next = lines[index + 1]
                    if !next.isEmpty {
                        return next
                    }
                }
            }
        }

        return nil
    }

    /// Extracts the multiline text associated with a recognized ACC form section.
    private static func multilineValue(
        afterAnyLabel labels: [String],
        stoppingAt stopLabels: [String],
        in lines: [String]
    ) -> String? {
        for (index, line) in lines.enumerated() {
            let lower = line.lowercased()

            guard labels.contains(
                where: { lower.contains($0) }
            ) else {
                continue
            }

            var collected: [String] = []

            if let colon = line.firstIndex(of: ":") {
                let inline = String(
                    line[line.index(after: colon)...]
                )
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

                if !inline.isEmpty {
                    collected.append(inline)
                }
            }

            var cursor = index + 1

            while cursor < lines.count {
                let candidate = lines[cursor]
                let lowerCandidate =
                    candidate.lowercased()

                if stopLabels.contains(
                    where: {
                        lowerCandidate.contains($0)
                    }
                ) {
                    break
                }

                collected.append(candidate)
                cursor += 1

                // Keep the first-pass parser conservative.
                if collected.count >= 8 {
                    break
                }
            }

            let value = collected
                .joined(separator: "\n")
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

            return value.isEmpty ? nil : value
        }

        return nil
    }
}
