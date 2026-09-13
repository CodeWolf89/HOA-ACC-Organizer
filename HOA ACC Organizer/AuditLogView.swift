// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import Foundation
import SwiftUI

/// Displays immutable administrator audit events recorded for protected edits and adjudications.
struct AuditLogView: View {
    /// The shared application model used to read app state and perform workflow actions.
    @EnvironmentObject var model: AppModel
    /// The SwiftUI dismissal action for closing the current presentation.
    @Environment(\.dismiss) private var dismiss

    /// The logical record type affected by this audit, sync, or deletion entry.
    let entityType: String?
    /// The stable identifier of the affected record.
    let entityID: String?

    /// Transient view state used to track entries while this screen is active.
    @State private var entries: [AuditEntry] = []
    /// Transient view state used to track error message while this screen is active.
    @State private var errorMessage = ""

    /// Creates an instance with the supplied dependencies and initial values.
    init(
        entityType: String? = nil,
        entityID: String? = nil
    ) {
        self.entityType = entityType
        self.entityID = entityID
    }

    /// The SwiftUI view hierarchy rendered by this view.
    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty &&
                    errorMessage.isEmpty {
                    ContentUnavailableView(
                        "No Audit Entries",
                        systemImage: "clock.badge.checkmark"
                    )
                } else {
                    List(entries) { entry in
                        VStack(
                            alignment: .leading,
                            spacing: 6
                        ) {
                            HStack {
                                Text(
                                    actionTitle(
                                        entry.action
                                    )
                                )
                                .font(.headline)

                                Spacer()

                                Text(
                                    formatDate(
                                        entry.changedAt
                                    )
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }

                            Text(
                                "\(entry.username) • \(entry.entityType)"
                            )
                            .font(.subheadline)

                            if let reason =
                                removalReason(
                                    entry
                                ) {
                                Label(
                                    "Removal reason",
                                    systemImage: "text.quote"
                                )
                                .font(
                                    .caption.weight(
                                        .semibold
                                    )
                                )
                                .foregroundStyle(.secondary)

                                Text(reason)
                                    .font(.subheadline)
                                    .textSelection(.enabled)
                            }

                            if !entry.beforeJSON.isEmpty &&
                                entry.beforeJSON != "{}" {
                                DisclosureGroup(
                                    "Before"
                                ) {
                                    Text(entry.beforeJSON)
                                        .font(
                                            .system(
                                                .caption,
                                                design: .monospaced
                                            )
                                        )
                                        .textSelection(.enabled)
                                }
                            }

                            if !entry.afterJSON.isEmpty &&
                                entry.afterJSON != "{}" {
                                DisclosureGroup(
                                    "After"
                                ) {
                                    Text(entry.afterJSON)
                                        .font(
                                            .system(
                                                .caption,
                                                design: .monospaced
                                            )
                                        )
                                        .textSelection(.enabled)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        #if os(macOS)
                        .listRowInsets(
                            EdgeInsets(
                                top: 8,
                                leading: 16,
                                bottom: 8,
                                trailing: 16
                            )
                        )
                        #endif
                    }
                    #if os(macOS)
                    .listStyle(.inset)
                    #endif
                }
            }
            .navigationTitle("Audit Log")
            .toolbar {
                ToolbarItem(
                    placement: .cancellationAction
                ) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(8)
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )
                        .background(.bar)
                }
            }
            .task {
                load()
            }
        }
        #if os(macOS)
        .frame(
            width: 760,
            height: 560
        )
        #endif
    }

    /// Converts internal audit action identifiers into readable labels.
    private func actionTitle(
        _ action: String
    ) -> String {
        switch action {
        case "removeViolation":
            return "Violation Removed"
        case "removeACCApplication":
            return "ACC Application Removed"
        case "adjudicateViolation":
            return "Violation Adjudicated"
        case "adjudicateACCApplication":
            return "ACC Application Adjudicated"
        case "editViolation":
            return "Violation Edited"
        case "editACCApplication":
            return "ACC Application Edited"
        default:
            return action
        }
    }

    /// Extracts the mandatory cleanup reason from removal audit metadata.
    private func removalReason(
        _ entry: AuditEntry
    ) -> String? {
        guard
            entry.action == "removeViolation" ||
            entry.action == "removeACCApplication",
            let data = entry.afterJSON.data(
                using: .utf8
            ),
            let object = try? JSONSerialization
                .jsonObject(with: data)
                as? [String: Any],
            let reason = object["reason"] as? String,
            !reason.isEmpty
        else {
            return nil
        }

        return reason
    }

    /// Loads  from its configured source.
    private func load() {
        do {
            entries =
                try model.store.fetchAuditEntries(
                    entityType: entityType,
                    entityID: entityID
                )
        } catch {
            errorMessage =
                error.localizedDescription
        }
    }

    /// Formats date for `AuditLogView`.
    private func formatDate(
        _ value: String
    ) -> String {
        let iso = ISO8601DateFormatter()

        guard let date =
            iso.date(from: value)
        else {
            return value
        }

        return date.formatted(
            date: .abbreviated,
            time: .shortened
        )
    }
}
