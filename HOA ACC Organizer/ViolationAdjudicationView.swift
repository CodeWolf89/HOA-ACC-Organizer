// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import SwiftUI

/// Guides an administrator through the ordered violation enforcement stages and resolution workflow.
struct ViolationAdjudicationView: View {
    /// The shared application model used to read app state and perform workflow actions.
    @EnvironmentObject var model: AppModel
    /// The SwiftUI dismissal action for closing the current presentation.
    @Environment(\.dismiss) private var dismiss

    /// The violation record displayed or processed by this component.
    let violation: ViolationListItem
    /// A callback invoked after the record is saved successfully.
    let onSaved: () -> Void

    /// User-entered notes associated with this record.
    @State private var notes = ""
    /// Transient view state used to track selected action while this screen is active.
    @State private var selectedAction: ActionChoice

    /// Defines the supported action choice values used by the application.
    private enum ActionChoice: String, CaseIterable, Identifiable {
        case advance
        case resolve

        /// The stable identifier for this value.
        var id: String { rawValue }
    }

    /// Creates an instance with the supplied dependencies and initial values.
    init(
        violation: ViolationListItem,
        onSaved: @escaping () -> Void
    ) {
        self.violation = violation
        self.onSaved = onSaved

        _selectedAction = State(
            initialValue:
                Self.nextStatus(after: violation.status) == nil
                ? .resolve
                : .advance
        )
    }

    /// The SwiftUI view hierarchy rendered by this view.
    var body: some View {
        NavigationStack {
            #if os(macOS)
            macAdjudicationContent
            #else
            mobileAdjudicationContent
            #endif
        }
        #if os(macOS)
        .frame(
            width: 620,
            height: 500
        )
        #endif
    }

    #if os(iOS)
    /// The compact-width adjudication controls used on iPhone and iPad.
    private var mobileAdjudicationContent:
        some View {
        Form {
            Section("Current Status") {
                LabeledContent(
                    "Status",
                    value:
                        currentStatus
                )
            }

            Section("Action") {
                actionPicker
            }

            Section("Adjudication Notes") {
                TextEditor(
                    text: $notes
                )
                .frame(minHeight: 120)
            }
        }
        .navigationTitle(
            "Adjudicate Violation"
        )
        .toolbar {
            adjudicationToolbar
        }
    }
    #endif

    #if os(macOS)
    /// The macOS adjudication form with desktop-appropriate spacing.
    private var macAdjudicationContent:
        some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: 18
            ) {
                GroupBox(
                    "Current Status"
                ) {
                    HStack {
                        Text("Status")
                            .foregroundStyle(
                                .secondary
                            )

                        Spacer()

                        Text(currentStatus)
                            .fontWeight(.semibold)
                    }
                    .padding(.vertical, 6)
                }

                GroupBox("Action") {
                    VStack(
                        alignment: .leading,
                        spacing: 10
                    ) {
                        actionPicker
                    }
                    .padding(.vertical, 6)
                }

                GroupBox(
                    "Adjudication Notes"
                ) {
                    TextEditor(
                        text: $notes
                    )
                    .font(.body)
                    .frame(
                        minHeight: 150,
                        maxHeight: 190
                    )
                    .padding(6)
                    .background(
                        RoundedRectangle(
                            cornerRadius: 8,
                            style: .continuous
                        )
                        .fill(
                            Color(nsColor:
                                .textBackgroundColor)
                        )
                    )
                    .overlay(
                        RoundedRectangle(
                            cornerRadius: 8,
                            style: .continuous
                        )
                        .stroke(
                            Color.secondary
                                .opacity(0.25)
                        )
                    )
                }
            }
            .padding(24)
        }
        .navigationTitle(
            "Adjudicate Violation"
        )
        .toolbar {
            adjudicationToolbar
        }
    }
    #endif

    /// The current status.
    private var currentStatus: String {
        violation.status.isEmpty
            ? "Open"
            : violation.status
    }

    /// The control used to choose between advancing or resolving a violation.
    @ViewBuilder
    private var actionPicker:
        some View {
        if let next = nextStatus {
            Picker(
                "Action",
                selection:
                    $selectedAction
            ) {
                Text(
                    "Advance to \(next)"
                )
                .tag(
                    ActionChoice.advance
                )

                Text("Mark Resolved")
                    .tag(
                        ActionChoice.resolve
                    )
            }
            #if os(macOS)
            .pickerStyle(.radioGroup)
            #else
            .pickerStyle(.segmented)
            #endif
        } else {
            Label(
                "Fee Assessment is the final escalation stage.",
                systemImage:
                    "info.circle"
            )

            Text(
                "This violation can now be marked resolved when the matter is complete."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    /// The confirmation/cancel toolbar shown in the adjudication sheet.
    @ToolbarContentBuilder
    private var adjudicationToolbar:
        some ToolbarContent {
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
            Button(saveButtonTitle) {
                save()
            }
            .buttonStyle(
                .borderedProminent
            )
        }
    }

    /// The next enforcement stage available from the violation’s current status.
    private var nextStatus: String? {
        Self.nextStatus(after: violation.status)
    }

    /// The status that will be written if the selected adjudication action succeeds.
    private var targetStatus: String {
        if selectedAction == .resolve {
            return "Resolved"
        }

        return nextStatus ?? "Resolved"
    }

    /// The label shown on the adjudication confirmation button.
    private var saveButtonTitle: String {
        targetStatus == "Resolved"
            ? "Mark Resolved"
            : "Advance"
    }

    /// Saves  using the current application data model.
    private func save() {
        do {
            guard let actor =
                model.currentAdmin
            else {
                model.statusMessage =
                    "Administrator login is required."
                return
            }

            try model.store.adjudicateViolation(
                id: violation.id,
                toStatus: targetStatus,
                notes: notes,
                actor: actor
            )

            try model.refresh()

            model.statusMessage =
                "Violation updated to \(targetStatus)."

            Task { await model.refreshReminders() }

            onSaved()
            dismiss()
        } catch {
            model.statusMessage =
                "Violation adjudication failed: \(error.localizedDescription)"
        }
    }

    /// Returns the next allowed violation-enforcement status for the current state.
    private static func nextStatus(
        after current: String
    ) -> String? {
        switch current
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() {
        case "", "open":
            return "Escalated"

        case "escalated":
            return "Final Warning"

        case "final warning", "finalwarning":
            return "Fee Assessment"

        case "fee assessment", "feeassessment":
            return nil

        default:
            return nil
        }
    }
}
