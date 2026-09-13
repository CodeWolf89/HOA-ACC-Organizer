// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

#if os(iOS)
import SwiftUI
import UIKit

/// Lets any iOS user create a violation, select governing rules, capture photos, and calculate a correction deadline.
struct NewViolationEntryView: View {
    /// The shared application model used to read app state and perform workflow actions.
    @EnvironmentObject private var model: AppModel
    /// The SwiftUI dismissal action for closing the current presentation.
    @Environment(\.dismiss) private var dismiss

    /// The lot initially selected when the new-violation workflow opens.
    let initialLotID: String?
    /// A callback invoked after the record is saved successfully.
    let onSaved: (String) -> Void

    /// Transient view state used to track selected lot id while this screen is active.
    @State private var selectedLotID: String?
    /// Transient view state used to track selected rule i ds while this screen is active.
    @State private var selectedRuleIDs = Set<String>()
    /// Transient view state used to track rules while this screen is active.
    @State private var rules: [ViolationCreationRule] = []
    /// The ISO-8601 timestamp when the violation was observed.
    @State private var observedAt = Date()
    /// Transient view state used to track inspector name while this screen is active.
    @State private var inspectorName = ""
    /// User-entered notes associated with this record.
    @State private var notes = ""
    /// Transient view state used to track photos while this screen is active.
    @State private var photos: [ViolationCreationPhoto] = []
    /// Transient view state used to track rule search text while this screen is active.
    @State private var ruleSearchText = ""

    /// Transient view state used to track showing lot search while this screen is active.
    @State private var showingLotSearch = false
    /// Transient view state used to track showing camera while this screen is active.
    @State private var showingCamera = false
    /// Transient view state used to track photo being retaken id while this screen is active.
    @State private var photoBeingRetakenID: String?
    /// Transient view state used to track is saving while this screen is active.
    @State private var isSaving = false
    /// Transient view state used to track error message while this screen is active.
    @State private var errorMessage = ""

    /// Creates an instance with the supplied dependencies and initial values.
    init(
        initialLotID: String?,
        onSaved: @escaping (String) -> Void
    ) {
        self.initialLotID = initialLotID
        self.onSaved = onSaved
        _selectedLotID = State(
            initialValue: initialLotID
        )
    }

    /// The currently selected lot.
    private var selectedLot: LotSummary? {
        guard let selectedLotID else {
            return nil
        }

        return model.lots.first {
            $0.id == selectedLotID
        }
    }

    /// The currently selected rules.
    private var selectedRules: [ViolationCreationRule] {
        rules.filter {
            selectedRuleIDs.contains(
                $0.id
            )
        }
    }

    /// The active rules matching the current rule search text.
    private var filteredRules: [ViolationCreationRule] {
        let active = rules.filter(\.isActive)
        let query =
            ruleSearchText
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        guard !query.isEmpty else {
            return active
        }

        return active.filter { rule in
            rule.title.localizedCaseInsensitiveContains(
                query
            ) ||
            rule.category.localizedCaseInsensitiveContains(
                query
            ) ||
            rule.ruleSection.localizedCaseInsensitiveContains(
                query
            ) ||
            rule.ruleText.localizedCaseInsensitiveContains(
                query
            )
        }
    }

    /// The ISO-8601 deadline by which the violation should be corrected.
    private var correctionDeadline: Date {
        ViolationCreationDraft.correctionDeadline(
            observedAt: observedAt,
            rules: selectedRules
        )
    }

    /// Indicates whether can save.
    private var canSave: Bool {
        selectedLotID != nil &&
        !selectedRules.isEmpty &&
        !isSaving
    }

    /// The SwiftUI view hierarchy rendered by this view.
    var body: some View {
        NavigationStack {
            Form {
                Section("Property") {
                    Button {
                        showingLotSearch = true
                    } label: {
                        HStack {
                            VStack(
                                alignment: .leading,
                                spacing: 4
                            ) {
                                Text("Property")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                if let selectedLot {
                                    Text(
                                        "Lot \(selectedLot.lotNumber)"
                                    )
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                    Text(
                                        selectedLot.primaryAddress
                                    )
                                    .foregroundStyle(.primary)

                                    if !selectedLot.ownerName.isEmpty {
                                        Text(
                                            selectedLot.ownerName
                                        )
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    }
                                } else {
                                    Text("Select Property")
                                        .foregroundStyle(.primary)
                                }
                            }

                            Spacer()

                            Image(
                                systemName: "chevron.right"
                            )
                            .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Section("Violations") {
                    if rules.isEmpty {
                        ContentUnavailableView(
                            "No Rules Available",
                            systemImage: "books.vertical",
                            description: Text(
                                "The bundled HOA rules could not be loaded."
                            )
                        )
                    } else {
                        TextField(
                            "Search rules",
                            text: $ruleSearchText
                        )
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                        ForEach(filteredRules) { rule in
                            Button {
                                toggleRule(rule)
                            } label: {
                                HStack(
                                    alignment: .top,
                                    spacing: 12
                                ) {
                                    VStack(
                                        alignment: .leading,
                                        spacing: 4
                                    ) {
                                        Text(rule.title)
                                            .foregroundStyle(.primary)

                                        Text(rule.ruleSection)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        if !rule.category.isEmpty {
                                            Text(rule.category)
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                        }
                                    }

                                    Spacer()

                                    Image(
                                        systemName:
                                            selectedRuleIDs.contains(
                                                rule.id
                                            )
                                            ? "checkmark.circle.fill"
                                            : "circle"
                                    )
                                    .foregroundStyle(
                                        selectedRuleIDs.contains(
                                            rule.id
                                        )
                                        ? .blue
                                        : .secondary
                                    )
                                }
                            }
                            .buttonStyle(.plain)
                        }

                        if selectedRules.count > 1 {
                            Text(
                                "Multiple violations selected. The correction deadline uses the longest correction period among the selected rules."
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Inspection") {
                    DatePicker(
                        "Observed",
                        selection: $observedAt,
                        displayedComponents: [
                            .date,
                            .hourAndMinute
                        ]
                    )

                    TextField(
                        "Inspector name",
                        text: $inspectorName
                    )
                    .textContentType(.name)

                    LabeledContent(
                        "Correction Deadline",
                        value:
                            correctionDeadline.formatted(
                                date: .abbreviated,
                                time: .omitted
                            )
                    )
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }

                Section("Photos") {
                    Button {
                        photoBeingRetakenID = nil
                        showingCamera = true
                    } label: {
                        Label(
                            "Take Photo",
                            systemImage: "camera"
                        )
                    }

                    if photos.isEmpty {
                        Text("No photos added yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(photos) { photo in
                        VStack(
                            alignment: .leading,
                            spacing: 8
                        ) {
                            if let image =
                                UIImage(
                                    data: photo.imageData
                                ) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .clipShape(
                                        RoundedRectangle(
                                            cornerRadius: 8
                                        )
                                    )
                            }

                            HStack {
                                Button {
                                    photoBeingRetakenID =
                                        photo.id
                                    showingCamera = true
                                } label: {
                                    Label(
                                        "Retake",
                                        systemImage:
                                            "camera.rotate"
                                    )
                                }

                                Spacer()

                                Button(
                                    role: .destructive
                                ) {
                                    removePhoto(photo)
                                } label: {
                                    Label(
                                        "Remove",
                                        systemImage: "trash"
                                    )
                                }
                            }
                            .font(.subheadline)
                        }
                        .padding(.vertical, 4)
                    }
                }

                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Violation")
            .accessibilityIdentifier(
                "violation.new.form"
            )
            .navigationBarTitleDisplayMode(.inline)
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
                    Button(
                        isSaving
                        ? "Saving…"
                        : "Save"
                    ) {
                        saveViolation()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .task {
            loadRules()
        }
        .sheet(
            isPresented: $showingLotSearch
        ) {
            ViolationLotSearchView(
                lots: model.lots,
                selectedLotID:
                    $selectedLotID
            )
        }
        .sheet(
            isPresented: $showingCamera,
            onDismiss: {
                photoBeingRetakenID = nil
            }
        ) {
            OrganizerViolationCameraPicker { image in
                acceptCapturedImage(image)
            }
            .ignoresSafeArea()
        }
    }

    /// Loads rules from its configured source.
    private func loadRules() {
        guard rules.isEmpty else {
            return
        }

        do {
            rules = try ViolationRuleCatalog.load()
            errorMessage = ""
        } catch {
            errorMessage =
                "Unable to load HOA rules: \(error.localizedDescription)"
        }
    }

    /// Adds or removes a rule from the current new-violation selection.
    private func toggleRule(
        _ rule: ViolationCreationRule
    ) {
        if selectedRuleIDs.contains(rule.id) {
            selectedRuleIDs.remove(rule.id)
        } else {
            selectedRuleIDs.insert(rule.id)
        }
    }

    /// Normalizes and stores a newly captured violation photo in the draft.
    private func acceptCapturedImage(
        _ image: UIImage
    ) {
        guard
            let data = image.jpegData(
                compressionQuality: 0.85
            )
        else {
            return
        }

        if let retakeID = photoBeingRetakenID,
           let index = photos.firstIndex(
            where: {
                $0.id == retakeID
            }
           ) {
            let oldPhoto = photos[index]

            photos[index] =
                ViolationCreationPhoto(
                    id: oldPhoto.id,
                    imageData: data,
                    capturedAt: Date(),
                    caption:
                        oldPhoto.caption
                )
        } else {
            photos.append(
                ViolationCreationPhoto(
                    imageData: data
                )
            )
        }

        photoBeingRetakenID = nil
    }

    /// Removes a selected draft photo before the violation is saved.
    private func removePhoto(
        _ photo: ViolationCreationPhoto
    ) {
        photos.removeAll {
            $0.id == photo.id
        }
    }

    /// Saves violation using the current application data model.
    private func saveViolation() {
        guard
            let lotID = selectedLotID,
            !selectedRules.isEmpty
        else {
            return
        }

        isSaving = true
        errorMessage = ""

        let draft =
            ViolationCreationDraft(
                lotID: lotID,
                observedAt: observedAt,
                correctionDeadline:
                    correctionDeadline,
                inspectorName:
                    inspectorName
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        ),
                notes: notes,
                rules: selectedRules,
                photos: photos
            )

        Task {
            do {
                try await model.createViolation(
                    draft
                )

                onSaved(lotID)
                dismiss()
            } catch {
                errorMessage =
                    "Unable to save violation: \(error.localizedDescription)"
                isSaving = false
            }
        }
    }
}

/// Presents the violation lot search interface in SwiftUI.
private struct ViolationLotSearchView: View {
    /// The SwiftUI dismissal action for closing the current presentation.
    @Environment(\.dismiss) private var dismiss

    /// The lot records included in this view, transfer, or result.
    let lots: [LotSummary]
    /// A two-way binding to selected lot id supplied by the parent view.
    @Binding var selectedLotID: String?

    /// Transient view state used to track search text while this screen is active.
    @State private var searchText = ""

    /// The lots matching the current property-search text.
    private var filteredLots: [LotSummary] {
        let sorted = lots.sorted {
            (Int($0.lotNumber) ?? 0) <
            (Int($1.lotNumber) ?? 0)
        }

        let query =
            searchText
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        guard !query.isEmpty else {
            return sorted
        }

        return sorted.filter { lot in
            lot.lotNumber.localizedCaseInsensitiveContains(
                query
            ) ||
            lot.primaryAddress.localizedCaseInsensitiveContains(
                query
            ) ||
            lot.ownerName.localizedCaseInsensitiveContains(
                query
            )
        }
    }

    /// The SwiftUI view hierarchy rendered by this view.
    var body: some View {
        NavigationStack {
            List(filteredLots) { lot in
                Button {
                    selectedLotID = lot.id
                    dismiss()
                } label: {
                    VStack(
                        alignment: .leading,
                        spacing: 4
                    ) {
                        Text("Lot \(lot.lotNumber)")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text(lot.primaryAddress)
                            .foregroundStyle(.primary)

                        if !lot.ownerName.isEmpty {
                            Text(lot.ownerName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Select Property")
            .searchable(
                text: $searchText,
                prompt:
                    "Lot, owner, or address"
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
            }
        }
    }
}

/// Represents organizer violation camera picker within HOA ACC Organizer.
private struct OrganizerViolationCameraPicker:
    UIViewControllerRepresentable {

    /// The SwiftUI dismissal action for closing the current presentation.
    @Environment(\.dismiss)
    private var dismiss

    /// A callback invoked when on image occurs.
    let onImage: (UIImage) -> Void

    /// Creates the UIKit coordinator that receives callbacks from the system image picker.
    func makeCoordinator()
        -> Coordinator {
        Coordinator(parent: self)
    }

    /// Creates the UIKit image-picker controller used for camera/photo selection.
    func makeUIViewController(
        context: Context
    ) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = false

        picker.sourceType =
            UIImagePickerController
                .isSourceTypeAvailable(
                    .camera
                )
            ? .camera
            : .photoLibrary

        return picker
    }

    /// Updates uiview controller while preserving workflow and audit requirements.
    func updateUIViewController(
        _ uiViewController:
            UIImagePickerController,
        context: Context
    ) {}

    /// Represents coordinator within HOA ACC Organizer.
    final class Coordinator:
        NSObject,
        UINavigationControllerDelegate,
        UIImagePickerControllerDelegate {

        /// The parent camera/photo-picker coordinator that receives UIKit callbacks.
        let parent:
            OrganizerViolationCameraPicker

        /// Creates a new `Coordinator` instance with the supplied values.
        init(
            parent:
                OrganizerViolationCameraPicker
        ) {
            self.parent = parent
        }

        /// Receives the image selected or captured by the system image picker and forwards it to the draft.
        func imagePickerController(
            _ picker:
                UIImagePickerController,
            didFinishPickingMediaWithInfo info:
                [UIImagePickerController.InfoKey: Any]
        ) {
            if let image =
                info[.originalImage]
                    as? UIImage {
                parent.onImage(image)
            }

            parent.dismiss()
        }

        /// Handles cancellation of the system image picker without modifying the draft.
        func imagePickerControllerDidCancel(
            _ picker:
                UIImagePickerController
        ) {
            parent.dismiss()
        }
    }
}
#endif
