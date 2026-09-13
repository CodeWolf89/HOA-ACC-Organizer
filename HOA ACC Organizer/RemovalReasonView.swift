// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import SwiftUI

/// Collects the mandatory reason required before the SuperUser permanently
/// removes a violation or ACC application.
struct RemovalReasonView: View {
    /// The SwiftUI dismissal action for closing the current presentation.
    @Environment(\.dismiss) private var dismiss

    /// The human-readable title displayed for this value.
    let title: String
    /// The human-readable record description shown in the destructive removal confirmation.
    let itemDescription: String
    /// The title of the destructive confirmation button.
    let confirmTitle: String
    /// A callback invoked when on confirm occurs.
    let onConfirm: (String) throws -> Void

    /// Transient view state used to track reason while this screen is active.
    @State private var reason = ""
    /// Transient view state used to track error message while this screen is active.
    @State private var errorMessage = ""
    /// Transient view state used to track is working while this screen is active.
    @State private var isWorking = false

    /// The trimmed removal reason that will be submitted to the store.
    private var cleanReason: String {
        reason.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    /// The SwiftUI view hierarchy rendered by this view.
    var body: some View {
        NavigationStack {
            VStack(
                alignment: .leading,
                spacing: 18
            ) {
                Label(
                    "Permanent Removal",
                    systemImage: "trash.fill"
                )
                .font(.title3.weight(.semibold))
                .foregroundStyle(.red)

                Text(itemDescription)
                    .foregroundStyle(.secondary)

                VStack(
                    alignment: .leading,
                    spacing: 8
                ) {
                    Text("Reason for removal")
                        .font(.headline)

                    TextEditor(
                        text: $reason
                    )
                    .frame(
                        minHeight: 120,
                        maxHeight: 180
                    )
                    .padding(6)
                    .background(
                        RoundedRectangle(
                            cornerRadius: 10,
                            style: .continuous
                        )
                        .fill(
                            Color.secondary
                                .opacity(0.08)
                        )
                    )
                    .overlay(
                        RoundedRectangle(
                            cornerRadius: 10,
                            style: .continuous
                        )
                        .stroke(
                            Color.secondary
                                .opacity(0.18)
                        )
                    )
                    .accessibilityIdentifier(
                        "removal.reason"
                    )
                }

                Text(
                    "This removes the record and its associated attachments from the active database. The action, original record snapshot, and reason remain in the Audit Log."
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(
                    placement: .cancellationAction
                ) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isWorking)
                }

                ToolbarItem(
                    placement: .confirmationAction
                ) {
                    Button(
                        confirmTitle,
                        role: .destructive
                    ) {
                        confirm()
                    }
                    .disabled(
                        cleanReason.isEmpty ||
                        isWorking
                    )
                    .accessibilityIdentifier(
                        "removal.confirm"
                    )
                }
            }
        }
        #if os(macOS)
        .frame(
            width: 560,
            height: 400
        )
        #endif
    }

    /// Validates the reason, invokes the destructive operation, and dismisses
    /// the sheet only after persistence succeeds.
    private func confirm() {
        guard !cleanReason.isEmpty else {
            return
        }

        isWorking = true
        errorMessage = ""

        do {
            try onConfirm(
                cleanReason
            )
            dismiss()
        } catch {
            errorMessage =
                error.localizedDescription
            isWorking = false
        }
    }
}
