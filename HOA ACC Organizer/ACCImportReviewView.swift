// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import SwiftUI

/// Displays OCR-extracted ACC application fields for mandatory human review before saving.
struct ACCImportReviewView: View {
    /// The shared application model used to read app state and perform workflow actions.
    @EnvironmentObject var model: AppModel
    /// The SwiftUI dismissal action for closing the current presentation.
    @Environment(\.dismiss) private var dismiss

    /// Transient view state used to track draft while this screen is active.
    @State var draft: ACCApplicationDraft
    /// Transient view state used to track showing ocr while this screen is active.
    @State private var showingOCR = false
    /// Transient view state used to track is saving while this screen is active.
    @State private var isSaving = false

    /// A callback invoked after the record is saved successfully.
    let onSaved: () -> Void

    /// The SwiftUI view hierarchy rendered by this view.
    var body: some View {
        NavigationStack {
            Form {
                Section("Applicant") {
                    ACCReviewTextField(
                        title:
                            "Applicant name",
                        text:
                            $draft.applicantName
                    )

                    ACCReviewTextField(
                        title:
                            "Phone",
                        text:
                            $draft.applicantPhone
                    )

                    ACCReviewTextField(
                        title:
                            "Address of proposed change",
                        text:
                            $draft.proposedChangeAddress
                    )

                    OptionalDatePickerField(
                        title:
                            "Application / submitted date",
                        selection:
                            $draft.submittedAt
                    )
                }

                Section("Proposed Change") {
                    ACCReviewTextField(
                        title:
                            "Description",
                        text:
                            $draft.description,
                        multiline:
                            true,
                        lineLimit:
                            3...8
                    )

                    ACCReviewTextField(
                        title:
                            "Color",
                        text:
                            $draft.color
                    )

                    OptionalDatePickerField(
                        title:
                            "Proposed start date",
                        selection:
                            $draft.proposedStartDate
                    )

                    OptionalDatePickerField(
                        title:
                            "Proposed completion date",
                        selection:
                            $draft.proposedCompletionDate
                    )
                }

                Section(
                    "Neighbor Acknowledgements"
                ) {
                    ForEach(
                        draft.neighbors.indices,
                        id: \.self
                    ) { index in
                        VStack(
                            alignment: .leading,
                            spacing: 10
                        ) {
                            Text(
                                "Neighbor \(index + 1)"
                            )
                            .font(
                                .subheadline.bold()
                            )

                            ACCReviewTextField(
                                title:
                                    "Name",
                                text:
                                    $draft
                                    .neighbors[index]
                                    .name
                            )

                            ACCReviewTextField(
                                title:
                                    "Address",
                                text:
                                    $draft
                                    .neighbors[index]
                                    .address
                            )

                            ACCReviewTextField(
                                title:
                                    "Lot #",
                                text:
                                    $draft
                                    .neighbors[index]
                                    .lotNumber
                            )

                            Toggle(
                                "Signature visible on application",
                                isOn:
                                    $draft
                                    .neighbors[index]
                                    .signatureObserved
                            )
                        }
                        .padding(
                            .vertical,
                            4
                        )
                    }
                }

                Section(
                    "Applicant Signature"
                ) {
                    ACCReviewTextField(
                        title:
                            "Signature / printed name",
                        text:
                            $draft.applicantSignature
                    )

                    OptionalDatePickerField(
                        title:
                            "Date",
                        selection:
                            $draft
                            .applicantSignatureDate
                    )
                }

                Section("ACC Review") {
                    Picker(
                        "Status",
                        selection:
                            $draft.status
                    ) {
                        Text("Under Review")
                            .tag("Under Review")
                        Text("Approved")
                            .tag("Approved")
                        Text(
                            "Approved with Conditions"
                        )
                        .tag(
                            "Approved with Conditions"
                        )
                        Text("Denied")
                            .tag("Denied")
                    }

                    ACCReviewTextField(
                        title:
                            "Recommendations",
                        text:
                            $draft
                            .accRecommendation,
                        multiline:
                            true,
                        lineLimit:
                            2...6
                    )

                    ACCReviewTextField(
                        title:
                            "Remarks",
                        text:
                            $draft.remarks,
                        multiline:
                            true,
                        lineLimit:
                            2...6
                    )

                    ACCReviewTextField(
                        title:
                            "Chairperson signature / printed name",
                        text:
                            $draft
                            .chairpersonSignature
                    )

                    OptionalDatePickerField(
                        title:
                            "Chairperson date",
                        selection:
                            $draft
                            .chairpersonSignatureDate
                    )
                }

                Section {
                    Label(
                        draft.ocrUsedOnDeviceModel
                            ? "On-device Apple Intelligence used"
                            : "Vision OCR fallback used",
                        systemImage:
                            draft.ocrUsedOnDeviceModel
                            ? "sparkles"
                            : "text.viewfinder"
                    )

                    Text(
                        draft.ocrAssistanceMessage
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )

                    Button {
                        showingOCR = true
                    } label: {
                        Label(
                            "Review Raw OCR Text",
                            systemImage:
                                "text.viewfinder"
                        )
                    }
                } header: {
                    Text(
                        "Document Recognition"
                    )
                } footer: {
                    Text(
                        "Recognition is a starting point only. Review the application against the original PDF before saving."
                    )
                }
            }
            .scrollDismissesKeyboard(
                .interactively
            )
            .navigationTitle(
                "Review ACC Application"
            )
            #if os(iOS)
            .navigationBarTitleDisplayMode(
                .inline
            )
            #endif
            .toolbar {
                ToolbarItem(
                    placement:
                        .cancellationAction
                ) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(
                    placement:
                        .confirmationAction
                ) {
                    Button(
                        "Save"
                    ) {
                        save()
                    }
                    .disabled(
                        isSaving ||
                        draft.applicantName
                            .trimmingCharacters(
                                in:
                                    .whitespacesAndNewlines
                            )
                            .isEmpty
                    )
                }
            }
            .sheet(
                isPresented:
                    $showingOCR
            ) {
                NavigationStack {
                    ScrollView {
                        Text(
                            draft.ocrText.isEmpty
                                ? "No text was recognized."
                                : draft.ocrText
                        )
                        .font(
                            .system(
                                .body,
                                design:
                                    .monospaced
                            )
                        )
                        .textSelection(
                            .enabled
                        )
                        .frame(
                            maxWidth:
                                .infinity,
                            alignment:
                                .leading
                        )
                        .padding()
                    }
                    .navigationTitle(
                        "OCR Text"
                    )
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(
                        .inline
                    )
                    #endif
                    .toolbar {
                        ToolbarItem(
                            placement:
                                .cancellationAction
                        ) {
                            Button("Done") {
                                showingOCR =
                                    false
                            }
                        }
                    }
                }
                #if os(macOS)
                .frame(
                    minWidth: 650,
                    minHeight: 500
                )
                #endif
            }
        }
        #if os(macOS)
        .frame(
            minWidth: 680,
            minHeight: 650
        )
        #endif
    }

    /// Saves  using the current application data model.
    private func save() {
        isSaving = true

        do {
            guard let actor =
                model.currentAdmin
            else {
                model.statusMessage =
                    "Administrator login is required."
                isSaving = false
                return
            }

            try model.store.saveACCRequest(
                draft,
                actor: actor
            )

            model.statusMessage =
                "ACC application saved for the selected lot."

            Task {
                await model
                    .refreshReminders()
            }

            onSaved()
            dismiss()
        } catch {
            model.statusMessage =
                "ACC application save failed: \(error.localizedDescription)"
            isSaving = false
        }
    }
}

/// Represents acc review text field within HOA ACC Organizer.
private struct ACCReviewTextField: View {
    /// The human-readable title displayed for this value.
    let title: String

    /// A two-way binding to text supplied by the parent view.
    @Binding var text: String

    /// Indicates whether this field should use a multiline text editor.
    var multiline = false

    /// The permitted line-count range for this text field.
    var lineLimit:
        ClosedRange<Int>?

    /// Creates an instance with the supplied dependencies and initial values.
    init(
        title: String,
        text: Binding<String>,
        multiline: Bool = false,
        lineLimit:
            ClosedRange<Int>? = nil
    ) {
        self.title = title
        _text = text
        self.multiline = multiline
        self.lineLimit = lineLimit
    }

    /// The SwiftUI view hierarchy rendered by this view.
    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 5
        ) {
            Text(title)
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )

            Group {
                if multiline {
                    TextField(
                        title,
                        text: $text,
                        axis: .vertical
                    )
                    .lineLimit(
                        lineLimit
                        ?? 2...6
                    )
                } else {
                    TextField(
                        title,
                        text: $text
                    )
                }
            }
            .textFieldStyle(
                .roundedBorder
            )
        }
    }
}
