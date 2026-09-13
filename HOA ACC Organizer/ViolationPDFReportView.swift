// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import SwiftUI
import PDFKit
import UniformTypeIdentifiers

/// Previews, saves, and shares a generated violation PDF report.
struct ViolationPDFReportView: View {
    /// The shared application model used to read app state and perform workflow actions.
    @EnvironmentObject var model: AppModel
    /// The SwiftUI dismissal action for closing the current presentation.
    @Environment(\.dismiss)
    private var dismiss

    /// The stable identifier of the violation being displayed or exported.
    let violationID: String

    /// Transient view state used to track report while this screen is active.
    @State private var report:
        ViolationPDFReportData?

    /// Transient view state used to track pdf data while this screen is active.
    @State private var pdfData =
        Data()

    /// Transient view state used to track preview url while this screen is active.
    @State private var previewURL:
        URL?

    /// Transient view state used to track showing exporter while this screen is active.
    @State private var showingExporter =
        false

    /// Transient view state used to track export document while this screen is active.
    @State private var exportDocument =
        ViolationPDFDocument()

    /// Transient view state used to track error message while this screen is active.
    @State private var errorMessage =
        ""

    /// The SwiftUI view hierarchy rendered by this view.
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let previewURL {
                    ViolationPDFPreview(
                        url: previewURL
                    )
                } else if !errorMessage
                    .isEmpty {
                    ContentUnavailableView(
                        "Unable to Generate Report",
                        systemImage:
                            "doc.badge.exclamationmark",
                        description:
                            Text(errorMessage)
                    )
                } else {
                    ProgressView(
                        "Generating violation report…"
                    )
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )
                }

                Divider()

                ViewThatFits(
                    in: .horizontal
                ) {
                    HStack(
                        spacing: 12
                    ) {
                        reportPreviewMessage

                        Spacer()

                        reportActions
                    }

                    VStack(
                        alignment: .leading,
                        spacing: 10
                    ) {
                        reportPreviewMessage

                        HStack {
                            Spacer()
                            reportActions
                        }
                    }
                }
                .padding()
                .background(.bar)
            }
            .navigationTitle(
                "Violation PDF Report"
            )
            .toolbar {
                ToolbarItem(
                    placement:
                        .cancellationAction
                ) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task(id: violationID) {
            generate()
        }
        .fileExporter(
            isPresented:
                $showingExporter,
            document:
                exportDocument,
            contentType:
                .pdf,
            defaultFilename:
                defaultFileName
        ) { result in
            if case .failure(let error) =
                result {
                errorMessage =
                    "PDF export failed: \(error.localizedDescription)"
            }
        }
        #if os(macOS)
        .frame(
            minWidth: 820,
            idealWidth: 900,
            minHeight: 650,
            idealHeight: 760
        )
        #endif
    }

    /// The user-facing message associated with report preview message.
    private var reportPreviewMessage:
        some View {
        Text(
            "Preview the report before saving or sharing it."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(
            horizontal: false,
            vertical: true
        )
    }

    /// The Save PDF and Share controls displayed beneath the violation PDF preview.
    @ViewBuilder
    private var reportActions:
        some View {
        Button {
            exportDocument =
                ViolationPDFDocument(
                    data: pdfData
                )

            showingExporter = true
        } label: {
            Label(
                "Save PDF…",
                systemImage:
                    "square.and.arrow.down"
            )
        }
        .disabled(
            pdfData.isEmpty
        )

        if let previewURL {
            ShareLink(
                item: previewURL,
                subject:
                    Text(
                        reportSubject
                    ),
                message:
                    Text(
                        "HOA violation report"
                    )
            ) {
                Label(
                    "Send / Share",
                    systemImage:
                        "paperplane"
                )
            }
        }
    }

    /// The default filename proposed when exporting the generated violation PDF.
    private var defaultFileName:
        String {
        guard let report else {
            return "Violation-Report.pdf"
        }

        return
            ViolationPDFReportGenerator
                .fileName(
                    report: report
                )
    }

    /// The share-sheet subject used for the generated violation report.
    private var reportSubject:
        String {
        guard let report else {
            return "HOA Violation Report"
        }

        return
            "Violation — Lot \(report.lot.lotNumber)"
    }

    /// Generates the current PDF preview data and refreshes the export/share state.
    private func generate() {
        do {
            cleanupPreview()

            guard
                let report =
                    try model.store
                        .fetchViolationPDFReportData(
                            violationID:
                                violationID
                        )
            else {
                throw CocoaError(
                    .fileNoSuchFile
                )
            }

            let data =
                try ViolationPDFReportGenerator
                    .render(
                        report: report
                    )

            let url =
                FileManager.default
                    .temporaryDirectory
                    .appendingPathComponent(
                        UUID().uuidString +
                        "-" +
                        ViolationPDFReportGenerator
                            .fileName(
                                report: report
                            )
                    )

            try data.write(
                to: url,
                options: .atomic
            )

            self.report = report
            pdfData = data
            previewURL = url
            errorMessage = ""
        } catch {
            report = nil
            pdfData = Data()
            previewURL = nil
            errorMessage =
                "The violation report could not be created. \(error.localizedDescription)"
        }
    }

    /// Removes the temporary PDF preview file created for the current sheet.
    private func cleanupPreview() {
        guard
            let previewURL,
            previewURL
                .deletingLastPathComponent() ==
                FileManager.default
                    .temporaryDirectory
        else {
            return
        }

        try? FileManager.default
            .removeItem(
                at: previewURL
            )
    }
}

/// Wraps rendered violation PDF data for SwiftUI file export.
struct ViolationPDFDocument:
    FileDocument {

    /// The Uniform Type Identifiers this document type can read.
    static var readableContentTypes:
        [UTType] {
        [.pdf]
    }

    /// The binary or encoded data used for data.
    var data: Data

    /// Creates an instance with the supplied dependencies and initial values.
    init(
        data: Data = Data()
    ) {
        self.data = data
    }

    /// Creates an instance with the supplied dependencies and initial values.
    init(
        configuration:
            ReadConfiguration
    ) throws {
        data =
            configuration
                .file
                .regularFileContents
            ?? Data()
    }

    /// Creates the file wrapper used by SwiftUI document export.
    func fileWrapper(
        configuration:
            WriteConfiguration
    ) throws -> FileWrapper {
        FileWrapper(
            regularFileWithContents:
                data
        )
    }
}

#if os(macOS)
/// Represents violation pdf preview within HOA ACC Organizer.
private struct ViolationPDFPreview:
    NSViewRepresentable {

    /// The URL used for url.
    let url: URL

    /// Creates the AppKit-backed PDF view used by SwiftUI on macOS.
    func makeNSView(
        context: Context
    ) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode =
            .singlePageContinuous
        view.document =
            PDFDocument(
                url: url
            )
        return view
    }

    /// Updates nsview while preserving workflow and audit requirements.
    func updateNSView(
        _ nsView: PDFView,
        context: Context
    ) {
        nsView.document =
            PDFDocument(
                url: url
            )
    }
}
#elseif os(iOS)
/// Represents violation pdf preview within HOA ACC Organizer.
private struct ViolationPDFPreview:
    UIViewRepresentable {

    /// The URL used for url.
    let url: URL

    /// Creates the UIKit-backed PDF view used by SwiftUI on iOS and iPadOS.
    func makeUIView(
        context: Context
    ) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode =
            .singlePageContinuous
        view.document =
            PDFDocument(
                url: url
            )
        return view
    }

    /// Updates uiview while preserving workflow and audit requirements.
    func updateUIView(
        _ uiView: PDFView,
        context: Context
    ) {
        uiView.document =
            PDFDocument(
                url: url
            )
    }
}
#endif
