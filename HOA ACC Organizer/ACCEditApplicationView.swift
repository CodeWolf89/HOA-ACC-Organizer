// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import SwiftUI

/// Allows an administrator to correct or supplement a previously saved ACC application.
struct ACCEditApplicationView: View {
    /// The shared application model used to read app state and perform workflow actions.
    @EnvironmentObject var model: AppModel
    /// The SwiftUI dismissal action for closing the current presentation.
    @Environment(\.dismiss) private var dismiss

    /// The ACC application record displayed or processed by this component.
    let request: ACCRequestDetail
    /// A callback invoked after the record is saved successfully.
    let onSaved: () -> Void

    /// The applicant name recorded on the ACC application.
    @State private var applicantName: String
    /// The applicant phone number recorded on the ACC application.
    @State private var applicantPhone: String
    /// The property address associated with the proposed ACC change.
    @State private var proposedChangeAddress: String
    /// The applicant’s description of the proposed property change.
    @State private var description: String
    /// The color or material information recorded for the proposed change.
    @State private var color: String
    /// The proposed start date for the ACC project.
    @State private var proposedStartDate: Date?
    /// The proposed completion date for the ACC project.
    @State private var proposedCompletionDate: Date?
    /// The ISO-8601 timestamp when the ACC application was submitted or received.
    @State private var submittedAt: Date?
    /// The applicant signature or printed-name text recorded on the application.
    @State private var applicantSignature: String
    /// The date associated with the applicant signature.
    @State private var applicantSignatureDate: Date?
    /// The ACC chairperson signature or printed-name text recorded for the decision.
    @State private var chairpersonSignature: String
    /// The date associated with the ACC chairperson decision signature.
    @State private var chairpersonSignatureDate: Date?
    /// Transient view state used to track recommendation while this screen is active.
    @State private var recommendation: String
    /// Additional ACC remarks recorded for the application.
    @State private var remarks: String

    /// Creates an editor populated with the values stored in an ACC request.
    init(
        request: ACCRequestDetail,
        onSaved: @escaping () -> Void
    ) {
        self.request = request
        self.onSaved = onSaved

        _applicantName = State(initialValue: request.applicantName)
        _applicantPhone = State(initialValue: request.applicantPhone)
        _proposedChangeAddress = State(initialValue: request.proposedChangeAddress)
        _description = State(initialValue: request.description)
        _color = State(initialValue: request.color)
        _proposedStartDate = State(
            initialValue:
                ISODateStorage.date(
                    from:
                        request
                            .proposedStartDate
                )
        )
        _proposedCompletionDate = State(
            initialValue:
                ISODateStorage.date(
                    from:
                        request
                            .proposedCompletionDate
                )
        )
        _submittedAt = State(
            initialValue:
                ISODateStorage.date(
                    from:
                        request
                            .submittedAt
                )
        )
        _applicantSignature =
            State(
                initialValue:
                    request
                        .applicantSignature
            )
        _applicantSignatureDate =
            State(
                initialValue:
                    ISODateStorage.date(
                        from:
                            request
                                .applicantSignatureDate
                    )
            )
        _chairpersonSignature =
            State(
                initialValue:
                    request
                        .chairpersonSignature
            )
        _chairpersonSignatureDate =
            State(
                initialValue:
                    ISODateStorage.date(
                        from:
                            request
                                .chairpersonSignatureDate
                    )
            )
        _recommendation = State(initialValue: request.accRecommendation)
        _remarks = State(initialValue: request.remarks)
    }

    /// The SwiftUI view hierarchy rendered by this view.
    var body: some View {
        NavigationStack {
            Group {
                #if os(macOS)
                macEditorContent
                #else
                mobileEditorContent
                #endif
            }
            .navigationTitle("Edit ACC Application")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(
                    placement: .cancellationAction
                ) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(
                    placement: .confirmationAction
                ) {
                    Button("Save Changes") {
                        save()
                    }
                }
            }
        }
        #if os(macOS)
        .frame(
            width: 860,
            height: 760
        )
        #endif
    }

    #if os(iOS)
    /// Native iOS form presentation used on iPhone and iPad.
    private var mobileEditorContent: some View {
        Form {
            Section("Applicant") {
                TextField(
                    "Applicant name",
                    text:
                        $applicantName
                )

                TextField(
                    "Phone",
                    text:
                        $applicantPhone
                )

                TextField(
                    "Property address",
                    text:
                        $proposedChangeAddress
                )

                OptionalDatePickerField(
                    title:
                        "Application / submitted date",
                    selection:
                        $submittedAt
                )
            }

            Section("Application") {
                TextField(
                    "Description",
                    text: $description,
                    axis: .vertical
                )
                .lineLimit(3...8)

                TextField(
                    "Color",
                    text: $color
                )

                OptionalDatePickerField(
                    title:
                        "Proposed start date",
                    selection:
                        $proposedStartDate
                )

                OptionalDatePickerField(
                    title:
                        "Proposed completion date",
                    selection:
                        $proposedCompletionDate
                )
            }

            Section("Signatures") {
                TextField(
                    "Applicant signature / printed name",
                    text:
                        $applicantSignature
                )

                OptionalDatePickerField(
                    title:
                        "Applicant signature date",
                    selection:
                        $applicantSignatureDate
                )

                TextField(
                    "Chairperson signature / printed name",
                    text:
                        $chairpersonSignature
                )

                OptionalDatePickerField(
                    title:
                        "Chairperson / decision date",
                    selection:
                        $chairpersonSignatureDate
                )
            }

            Section("Additional Notes") {
                TextField(
                    "ACC recommendation",
                    text: $recommendation,
                    axis: .vertical
                )
                .lineLimit(2...6)

                TextField(
                    "Remarks",
                    text: $remarks,
                    axis: .vertical
                )
                .lineLimit(2...8)
            }
        }
        .scrollDismissesKeyboard(
            .interactively
        )
    }
    #endif

    #if os(macOS)
    /// Scrollable macOS editor with explicit label widths so long labels do not collide with controls.
    private var macEditorContent: some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: 18
            ) {
                GroupBox("Applicant") {
                    VStack(spacing: 12) {
                        macTextRow(
                            title: "Applicant name",
                            text: $applicantName
                        )

                        macTextRow(
                            title: "Phone",
                            text: $applicantPhone
                        )

                        macTextRow(
                            title: "Property address",
                            text: $proposedChangeAddress
                        )

                        macDateRow(
                            title: "Application / submitted date",
                            selection: $submittedAt
                        )
                    }
                    .padding(.vertical, 6)
                }

                GroupBox("Application") {
                    VStack(spacing: 12) {
                        macMultilineField(
                            title: "Description",
                            text: $description,
                            minHeight: 100
                        )

                        macTextRow(
                            title: "Color",
                            text: $color
                        )

                        macDateRow(
                            title: "Proposed start date",
                            selection: $proposedStartDate
                        )

                        macDateRow(
                            title: "Proposed completion date",
                            selection: $proposedCompletionDate
                        )
                    }
                    .padding(.vertical, 6)
                }

                GroupBox("Signatures") {
                    VStack(spacing: 12) {
                        macTextRow(
                            title: "Applicant signature / printed name",
                            text: $applicantSignature
                        )

                        macDateRow(
                            title: "Applicant signature date",
                            selection: $applicantSignatureDate
                        )

                        macTextRow(
                            title: "Chairperson signature / printed name",
                            text: $chairpersonSignature
                        )

                        macDateRow(
                            title: "Chairperson / decision date",
                            selection: $chairpersonSignatureDate
                        )
                    }
                    .padding(.vertical, 6)
                }

                GroupBox("Additional Notes") {
                    VStack(spacing: 14) {
                        macMultilineField(
                            title: "ACC recommendation",
                            text: $recommendation,
                            minHeight: 90
                        )

                        macMultilineField(
                            title: "Remarks",
                            text: $remarks,
                            minHeight: 90
                        )
                    }
                    .padding(.vertical, 6)
                }
            }
            .padding(24)
            .frame(
                maxWidth: 800,
                alignment: .leading
            )
            .frame(
                maxWidth: .infinity,
                alignment: .top
            )
        }
    }

    /// A macOS single-line editor row with a stable label column.
    private func macTextRow(
        title: String,
        text: Binding<String>
    ) -> some View {
        HStack(
            alignment: .firstTextBaseline,
            spacing: 16
        ) {
            macRowLabel(title)

            TextField(
                title,
                text: text
            )
            .labelsHidden()
            .textFieldStyle(.roundedBorder)
            .frame(
                maxWidth: .infinity
            )
        }
    }

    /// A macOS date row that keeps the date control compact and readable.
    @ViewBuilder
    private func macDateRow(
        title: String,
        selection: Binding<Date?>
    ) -> some View {
        HStack(
            alignment: .center,
            spacing: 16
        ) {
            macRowLabel(title)

            if selection.wrappedValue != nil {
                DatePicker(
                    "",
                    selection:
                        nonOptionalDateBinding(
                            selection
                        ),
                    displayedComponents:
                        [.date]
                )
                .labelsHidden()
                .datePickerStyle(.field)
                .frame(width: 150)

                Button {
                    selection.wrappedValue = nil
                } label: {
                    Image(
                        systemName:
                            "xmark.circle.fill"
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
                .buttonStyle(.borderless)
                .help("Clear \(title)")
            } else {
                Button("Set Date") {
                    selection.wrappedValue =
                        Calendar.current
                            .startOfDay(
                                for: Date()
                            )
                }
            }

            Spacer()
        }
    }

    /// A macOS multiline field that keeps its label above the editable region.
    private func macMultilineField(
        title: String,
        text: Binding<String>,
        minHeight: CGFloat
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 6
        ) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(
                text: text
            )
            .font(.body)
            .frame(
                minHeight: minHeight
            )
            .padding(6)
            .overlay(
                RoundedRectangle(
                    cornerRadius: 7,
                    style: .continuous
                )
                .stroke(
                    Color.secondary
                        .opacity(0.28)
                )
            )
        }
    }

    /// Standard label column used by macOS editor rows.
    private func macRowLabel(
        _ title: String
    ) -> some View {
        Text(title)
            .frame(
                width: 225,
                alignment: .trailing
            )
            .foregroundStyle(.secondary)
    }

    /// Converts an optional date binding into the non-optional binding DatePicker requires.
    private func nonOptionalDateBinding(
        _ selection: Binding<Date?>
    ) -> Binding<Date> {
        Binding(
            get: {
                selection.wrappedValue
                    ?? Calendar.current
                        .startOfDay(
                            for: Date()
                        )
            },
            set: { value in
                selection.wrappedValue =
                    Calendar.current
                        .startOfDay(
                            for: value
                        )
            }
        )
    }
    #endif

    /// Persists the administrator's edits and records the audit event.
    private func save() {
        do {
            guard let actor =
                model.currentAdmin
            else {
                model.statusMessage =
                    "Administrator login is required."
                return
            }

            try model.store.updateACCRequest(
                id: request.id,
                actor: actor,
                applicantName: applicantName,
                applicantPhone: applicantPhone,
                proposedChangeAddress: proposedChangeAddress,
                description: description,
                color: color,
                proposedStartDate:
                    proposedStartDate,
                proposedCompletionDate:
                    proposedCompletionDate,
                submittedAt:
                    submittedAt,
                applicantSignature:
                    applicantSignature,
                applicantSignatureDate:
                    applicantSignatureDate,
                chairpersonSignature:
                    chairpersonSignature,
                chairpersonSignatureDate:
                    chairpersonSignatureDate,
                accRecommendation:
                    recommendation,
                remarks:
                    remarks
            )

            model.statusMessage =
                "ACC application updated."
            onSaved()
            dismiss()
        } catch {
            model.statusMessage =
                "ACC application update failed: \(error.localizedDescription)"
        }
    }
}
