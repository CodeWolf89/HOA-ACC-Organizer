// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import SwiftUI
import UniformTypeIdentifiers

/// Provides a manual ACC application entry workflow when OCR is unnecessary or unreliable.
struct ACCManualEntryView: View {
    /// The shared application model used to read app state and perform workflow actions.
    @EnvironmentObject var model: AppModel
    /// The SwiftUI dismissal action for closing the current presentation.
    @Environment(\.dismiss) private var dismiss

    /// Transient view state used to track draft while this screen is active.
    @State var draft: ACCApplicationDraft
    /// Transient view state used to track is saving while this screen is active.
    @State private var isSaving = false

    /// Transient view state used to track var while this screen is active.
    @State private var
        showingPhotoImporter = false

    /// Transient view state used to track var while this screen is active.
    @State private var
        pendingPhotos:
            [ACCPendingPhoto] = []

    /// Transient view state used to track var while this screen is active.
    @State private var
        photoError = ""

    /// A callback invoked after the record is saved successfully.
    let onSaved: () -> Void

    /// The SwiftUI view hierarchy rendered by this view.
    var body: some View {
        NavigationStack {
            #if os(macOS)
            macBody
            #else
            iOSBody
            #endif
        }
        .fileImporter(
            isPresented:
                $showingPhotoImporter,
            allowedContentTypes:
                [.image],
            allowsMultipleSelection:
                true
        ) { result in
            handlePhotoSelection(
                result
            )
        }
        #if os(macOS)
        .frame(
            minWidth: 720,
            idealWidth: 800,
            minHeight: 520,
            idealHeight: 700,
            maxHeight: 820
        )
        #endif
    }

    #if os(macOS)
    /// The macOS-specific manual ACC entry form.
    private var macBody: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(
                    alignment: .leading,
                    spacing: 16
                ) {
                    GroupBox("Applicant") {
                        VStack(spacing: 10) {
                            applicantFields
                        }
                        .padding(.vertical, 6)
                    }

                    GroupBox("Proposed Change") {
                        VStack(spacing: 10) {
                            proposedChangeFields
                        }
                        .padding(.vertical, 6)
                    }

                    GroupBox(
                        "Homeowner Photos"
                    ) {
                        photoFields
                            .padding(
                                .vertical,
                                6
                            )
                    }

                    GroupBox(
                        "Neighbor Acknowledgements"
                    ) {
                        neighborFields
                            .padding(
                                .vertical,
                                6
                            )
                    }

                    GroupBox(
                        "Applicant Signature"
                    ) {
                        VStack(spacing: 10) {
                            applicantSignatureFields
                        }
                        .padding(.vertical, 6)
                    }

                    GroupBox("ACC Review") {
                        VStack(spacing: 10) {
                            reviewFields
                        }
                        .padding(.vertical, 6)
                    }

                    Label(
                        "Manual entry — no OCR or source PDF is required.",
                        systemImage: "keyboard"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(22)
                .frame(
                    maxWidth: 820,
                    alignment: .topLeading
                )
                .frame(
                    maxWidth: .infinity,
                    alignment: .top
                )
            }

            Divider()

            HStack {
                if !photoError.isEmpty {
                    Text(photoError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Spacer()

                Button("Cancel") {
                    dismiss()
                }

                Button(
                    "Save"
                ) {
                    save()
                }
                .buttonStyle(
                    .borderedProminent
                )
                .disabled(
                    saveDisabled
                )
            }
            .padding()
            .background(.bar)
        }
        .navigationTitle(
            "New ACC Application"
        )
    }
    #endif

    #if os(iOS)
    /// The iPhone/iPad-specific Data Sync layout.
    private var iOSBody: some View {
        Form {
            Section("Applicant") {
                applicantFields
            }

            Section("Proposed Change") {
                proposedChangeFields
            }

            Section("Homeowner Photos") {
                photoFields
            }

            Section(
                "Neighbor Acknowledgements"
            ) {
                neighborFields
            }

            Section(
                "Applicant Signature"
            ) {
                applicantSignatureFields
            }

            Section("ACC Review") {
                reviewFields
            }

            Section {
                Label(
                    "Manual entry — no OCR or source PDF is required.",
                    systemImage: "keyboard"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(
            "New ACC Application"
        )
        .navigationBarTitleDisplayMode(
            .inline
        )
        .scrollDismissesKeyboard(
            .interactively
        )
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
                    "Save Application"
                ) {
                    save()
                }
                .disabled(
                    saveDisabled
                )
            }
        }
    }
    #endif

    /// The reusable applicant-information fields in the manual ACC form.
    @ViewBuilder
    private var applicantFields:
        some View {
        TextField(
            "Applicant name",
            text:
                $draft
                .applicantName
        )

        TextField(
            "Phone",
            text:
                $draft
                .applicantPhone
        )

        TextField(
            "Address of proposed change",
            text:
                $draft
                .proposedChangeAddress
        )

        OptionalDatePickerField(
            title:
                "Application / submitted date",
            selection:
                $draft.submittedAt,
            allowsClear:
                false
        )
    }

    /// The reusable proposed-change fields in the manual ACC form.
    @ViewBuilder
    private var proposedChangeFields:
        some View {
        TextField(
            "Description",
            text:
                $draft.description,
            axis: .vertical
        )
        .lineLimit(3...8)

        TextField(
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

    /// The section used to stage homeowner-supplied photos for a manual ACC application.
    @ViewBuilder
    private var photoFields:
        some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            Button {
                showingPhotoImporter =
                    true
            } label: {
                Label(
                    "Add Photos…",
                    systemImage:
                        "photo.badge.plus"
                )
            }

            if pendingPhotos.isEmpty {
                Text(
                    "No homeowner photos selected."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                ForEach(
                    pendingPhotos
                ) { photo in
                    HStack {
                        Label(
                            photo
                                .originalFileName,
                            systemImage:
                                "photo"
                        )
                        .lineLimit(1)

                        Spacer()

                        Text(
                            photo
                                .byteCountText
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        Button(
                            role: .destructive
                        ) {
                            pendingPhotos
                                .removeAll {
                                    $0.id ==
                                    photo.id
                                }
                        } label: {
                            Image(
                                systemName:
                                    "trash"
                            )
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }

            if !photoError.isEmpty {
                Text(photoError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    /// The fields used to capture neighbor acknowledgements.
    @ViewBuilder
    private var neighborFields:
        some View {
        ForEach(
            draft.neighbors.indices,
            id: \.self
        ) { index in
            VStack(
                alignment: .leading,
                spacing: 8
            ) {
                Text(
                    "Neighbor \(index + 1)"
                )
                .font(
                    .subheadline.bold()
                )

                TextField(
                    "Name",
                    text:
                        $draft
                        .neighbors[index]
                        .name
                )

                TextField(
                    "Address",
                    text:
                        $draft
                        .neighbors[index]
                        .address
                )

                TextField(
                    "Lot #",
                    text:
                        $draft
                        .neighbors[index]
                        .lotNumber
                )

                Toggle(
                    "Signature present on paper application",
                    isOn:
                        $draft
                        .neighbors[index]
                        .signatureObserved
                )
            }
            .padding(.vertical, 4)

            if index <
                draft.neighbors.count -
                1 {
                Divider()
            }
        }
    }

    /// The applicant signature and date fields.
    @ViewBuilder
    private var applicantSignatureFields:
        some View {
        TextField(
            "Signature / printed name",
            text:
                $draft
                .applicantSignature
        )

        OptionalDatePickerField(
            title:
                "Date",
            selection:
                $draft.applicantSignatureDate
        )
    }

    /// The optional ACC recommendation, remarks, and chairperson fields.
    @ViewBuilder
    private var reviewFields:
        some View {
        Picker(
            "Status",
            selection:
                $draft.status
        ) {
            Text("Under Review")
                .tag("Under Review")
            Text(
                "Approved"
            )
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

        TextField(
            "Recommendations",
            text:
                $draft
                .accRecommendation,
            axis: .vertical
        )
        .lineLimit(2...6)

        TextField(
            "Remarks / notes",
            text:
                $draft.remarks,
            axis: .vertical
        )
        .lineLimit(2...6)

        TextField(
            "Chairperson signature / printed name",
            text:
                $draft
                .chairpersonSignature
        )

        OptionalDatePickerField(
            title:
                "Chairperson date",
            selection:
                $draft.chairpersonSignatureDate
        )
    }

    /// Indicates whether required fields or an in-progress save should disable the Save button.
    private var saveDisabled: Bool {
        isSaving ||
        draft.applicantName
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
            .isEmpty ||
        draft.description
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
            .isEmpty
    }

    /// Handles photo selection for `ACCManualEntryView`.
    private func handlePhotoSelection(
        _ result:
            Result<[URL], Error>
    ) {
        switch result {
        case .success(let urls):
            do {
                let loaded =
                    try urls.map {
                        try ACCPendingPhoto
                            .load(
                                from: $0
                            )
                    }

                pendingPhotos
                    .append(
                        contentsOf:
                            loaded
                    )

                photoError = ""
            } catch {
                photoError =
                    "Photo import failed: \(error.localizedDescription)"
            }

        case .failure(let error):
            photoError =
                "Photo selection failed: \(error.localizedDescription)"
        }
    }

    /// Saves  using the current application data model.
    private func save() {
        isSaving = true

        do {
            guard
                let actor =
                    model.currentAdmin
            else {
                model.statusMessage =
                    "Administrator login is required."
                isSaving = false
                return
            }

            draft.ocrText = ""
            draft.sourcePDFFileName =
                nil
            draft.sourcePDFOriginalName =
                nil

            try model.store
                .saveACCRequest(
                    draft,
                    actor: actor
                )

            var failedPhotos:
                [String] = []

            for photo in pendingPhotos {
                do {
                    try model.store
                        .addACCPhoto(
                            requestID:
                                draft.id,
                            lotID:
                                draft.lotID,
                            data:
                                photo.data,
                            originalFileName:
                                photo
                                .originalFileName,
                            mimeType:
                                photo.mimeType,
                            fileExtension:
                                photo
                                .fileExtension,
                            actor:
                                /// Represents actor within HOA ACC Organizer.
                                actor
                        )
                } catch {
                    failedPhotos.append(
                        photo
                            .originalFileName
                    )
                }
            }

            if failedPhotos.isEmpty {
                model.statusMessage =
                    pendingPhotos.isEmpty
                    ? "Manual ACC application saved for the selected lot."
                    : "Manual ACC application and \(pendingPhotos.count) homeowner photo(s) saved."
            } else {
                model.statusMessage =
                    "Application saved, but \(failedPhotos.count) photo(s) could not be attached."
            }

            try? model.refresh()

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
