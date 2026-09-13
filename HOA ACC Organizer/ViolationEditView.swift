// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import SwiftUI

/// Allows administrators to correct persisted violation dates, notes, and other editable details.
struct ViolationEditView: View {
    /// The shared application model used to read app state and perform workflow actions.
    @EnvironmentObject var model: AppModel
    /// The SwiftUI dismissal action for closing the current presentation.
    @Environment(\.dismiss) private var dismiss

    /// The violation record displayed or processed by this component.
    let violation: ViolationListItem
    /// A callback invoked after the record is saved successfully.
    let onSaved: () -> Void

    /// User-entered notes associated with this record.
    @State private var notes: String
    /// Administrator-only notes associated with this record.
    @State private var adminNotes: String
    /// The ISO-8601 timestamp when the violation was observed.
    @State private var observedAt: Date?
    /// The ISO-8601 deadline by which the violation should be corrected.
    @State private var correctionDeadline: Date?
    /// Transient view state used to track error message while this screen is active.
    @State private var errorMessage = ""

    /// Creates an instance with the supplied dependencies and initial values.
    init(
        violation: ViolationListItem,
        onSaved: @escaping () -> Void
    ) {
        self.violation = violation
        self.onSaved = onSaved

        _notes =
            State(
                initialValue: violation.notes
            )

        _adminNotes =
            State(
                initialValue: violation.adminNotes
            )

        _observedAt =
            State(
                initialValue:
                    ISODateStorage.date(
                        from:
                            violation
                                .observedAt
                    )
            )

        _correctionDeadline =
            State(
                initialValue:
                    ISODateStorage.date(
                        from:
                            violation
                                .correctionDeadline
                    )
            )
    }

    /// The SwiftUI view hierarchy rendered by this view.
    var body: some View {
        NavigationStack {
            Form {
                Section("Imported Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 120)

                    Text(
                        "Changes to imported notes are recorded in the audit log."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Section("Administrator Notes") {
                    TextEditor(
                        text: $adminNotes
                    )
                    .frame(minHeight: 140)

                    Text(
                        "Use this area for supplemental notes without replacing the original inspection record."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Section("Violation Dates") {
                    OptionalDatePickerField(
                        title:
                            "Observed date",
                        selection:
                            $observedAt
                    )

                    OptionalDatePickerField(
                        title:
                            "Correction deadline",
                        selection:
                            $correctionDeadline
                    )
                }

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Edit Violation")
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
            minWidth: 620,
            minHeight: 540
        )
        #endif
    }

    /// Saves  using the current application data model.
    private func save() {
        guard let actor =
            model.currentAdmin
        else {
            errorMessage =
                "Administrator login is required."
            return
        }

        do {
            try model.store.updateViolationDetails(
                id: violation.id,
                notes: notes,
                adminNotes: adminNotes,
                observedAt:
                    observedAt,
                correctionDeadline:
                    correctionDeadline,
                actor: actor
            )

            try model.refresh()
            Task { await model.refreshReminders() }

            onSaved()
            dismiss()
        } catch {
            errorMessage =
                error.localizedDescription
        }
    }
}
