// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import SwiftUI
import PDFKit
import UniformTypeIdentifiers

/// Previews, exports, shares, and archives an ACC decision letter for an adjudicated application.
struct ACCDecisionLetterView: View {
    /// The shared application model used to read app state and perform workflow actions.
    @EnvironmentObject var model: AppModel
    /// The SwiftUI dismissal action for closing the current presentation.
    @Environment(\.dismiss)
    private var dismiss

    /// The ACC application record displayed or processed by this component.
    let request: ACCRequestDetail
    /// The lot record displayed or processed by this component.
    let lot: LotDetail
    /// A callback invoked after the record is saved successfully.
    let onSaved: () -> Void

    /// Transient view state used to track template while this screen is active.
    @State private var template =
        ACCDecisionLetterTemplate
            .sourceTemplate

    /// Transient view state used to track var while this screen is active.
    @State private var
        pdfData = Data()

    /// Transient view state used to track var while this screen is active.
    @State private var
        previewURL: URL?
    /// Transient view state used to track var while this screen is active.
    @State private var
        showingExporter = false

    /// Transient view state used to track var while this screen is active.
    @State private var
        exportDocument =
            ACCDecisionLetterPDFDocument()

    /// Transient view state used to track var while this screen is active.
    @State private var
        isSavedToRecord = false

    /// Transient view state used to track var while this screen is active.
    @State private var
        errorMessage = ""

    /// The SwiftUI view hierarchy rendered by this view.
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let previewURL {
                    PDFKitRepresentable(
                        url:
                            previewURL
                    )
                } else if !errorMessage
                    .isEmpty {
                    ContentUnavailableView(
                        "Unable to Generate Letter",
                        systemImage:
                            "doc.badge.exclamationmark",
                        description:
                            Text(errorMessage)
                    )
                } else {
                    ProgressView(
                        "Generating decision letter…"
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
                        decisionLetterStatus

                        Spacer()

                        decisionLetterActions
                    }

                    VStack(
                        alignment: .leading,
                        spacing: 10
                    ) {
                        decisionLetterStatus

                        HStack {
                            Spacer()
                            decisionLetterActions
                        }
                    }
                }
                .padding()
                .background(.bar)
            }
            .navigationTitle(
                "ACC Decision Letter"
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
        .task {
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
                ACCDecisionLetterPDFRenderer
                    .fileName(
                        request: request,
                        lot: lot
                    )
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

    /// The status text shown for generated ACC decision letters.
    @ViewBuilder
    private var decisionLetterStatus:
        some View {
        if isSavedToRecord {
            Label(
                "Saved to application record",
                systemImage:
                    "checkmark.circle.fill"
            )
            .foregroundStyle(.green)
        } else {
            Text(
                "Preview only — save it to the application record when the wording is final."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(
                horizontal: false,
                vertical: true
            )
        }
    }

    /// The controls used to preview, export, share, or save the decision letter.
    @ViewBuilder
    private var decisionLetterActions:
        some View {
        Button {
            exportDocument =
                ACCDecisionLetterPDFDocument(
                    data:
                        pdfData
                )

            showingExporter =
                true
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
                item:
                    previewURL,
                subject:
                    Text(
                        "ACC \(request.status) — Lot \(lot.lotNumber)"
                    ),
                message:
                    Text(
                        "Architectural Control Committee decision letter"
                    )
            ) {
                Label(
                    "Send / Share",
                    systemImage:
                        "paperplane"
                )
            }
        }

        Button {
            saveToRecord()
        } label: {
            Label(
                "Save to Record",
                systemImage:
                    "archivebox"
            )
        }
        .buttonStyle(
            .borderedProminent
        )
        .disabled(
            pdfData.isEmpty ||
            isSavedToRecord
        )
    }

    /// Generates the current PDF preview data and refreshes the export/share state.
    private func generate() {
        do {
            cleanupPreview()

            let data =
                try ACCDecisionLetterPDFRenderer
                    .render(
                        request:
                            request,
                        lot:
                            lot,
                        template:
                            template
                    )

            let url =
                FileManager.default
                    .temporaryDirectory
                    .appendingPathComponent(
                        UUID().uuidString +
                        ".pdf"
                    )

            try data.write(
                to: url,
                options: .atomic
            )

            pdfData = data
            previewURL = url
            errorMessage = ""
        } catch {
            pdfData = Data()
            previewURL = nil
            errorMessage =
                error.localizedDescription
        }
    }

    /// Saves to record using the current application data model.
    private func saveToRecord() {
        do {
            guard
                let actor =
                    model.currentAdmin
            else {
                model.statusMessage =
                    "Administrator login is required."
                return
            }

            let attachment =
                try model.store
                    .saveACCDecisionLetter(
                        requestID:
                            request.id,
                        lotID:
                            request.lotID,
                        decision:
                            request.status,
                        data:
                            pdfData,
                        originalFileName:
                            ACCDecisionLetterPDFRenderer
                                .fileName(
                                    request:
                                        request,
                                    lot:
                                        lot
                                ),
                        actor:
                            /// Represents actor within HOA ACC Organizer.
                            actor
                    )

            let storedURL =
                try model.store
                    .attachmentURL(
                        fileName:
                            attachment
                                .fileName
                    )

            cleanupPreview()

            previewURL =
                storedURL

            isSavedToRecord =
                true

            model.statusMessage =
                "ACC decision letter saved to the application record."

            onSaved()
        } catch {
            errorMessage =
                "Unable to save decision letter: \(error.localizedDescription)"
        }
    }

    /// Removes the temporary PDF preview file created for the current sheet.
    private func cleanupPreview() {
        guard
            let previewURL,
            previewURL
                .deletingLastPathComponent()
                == FileManager.default
                    .temporaryDirectory
        else {
            return
        }

        try? FileManager.default
            .removeItem(
                at:
                    previewURL
            )
    }
}


/// FileDocument wrapper used only for exporting an already-rendered ACC letter PDF.
/// The editable letter template itself lives in ACCDecisionLetterTemplate.sourceTemplate.
struct ACCDecisionLetterPDFDocument: FileDocument {
    /// The Uniform Type Identifiers this document type can read.
    static var readableContentTypes: [UTType] {
        [.pdf]
    }

    /// The binary or encoded data used for data.
    var data: Data

    /// Creates an instance with the supplied dependencies and initial values.
    init(data: Data = Data()) {
        self.data = data
    }

    /// Creates an instance with the supplied dependencies and initial values.
    init(configuration: ReadConfiguration) throws {
        data =
            configuration.file.regularFileContents
            ?? Data()
    }

    /// Creates the file wrapper used by SwiftUI document export.
    func fileWrapper(
        configuration: WriteConfiguration
    ) throws -> FileWrapper {
        FileWrapper(
            regularFileWithContents: data
        )
    }
}
