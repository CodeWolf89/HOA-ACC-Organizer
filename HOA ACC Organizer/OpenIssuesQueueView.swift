// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import SwiftUI

/// Presents the combined queue of active violations and ACC applications and navigates to the affected lot.
struct OpenIssuesQueueView: View {
    /// The shared application model used to read app state and perform workflow actions.
    @EnvironmentObject var model: AppModel
    /// The SwiftUI dismissal action for closing the current presentation.
    @Environment(\.dismiss) private var dismiss

    /// A callback invoked when on select lot occurs.
    let onSelectLot: (String) -> Void

    /// Transient view state used to track issues while this screen is active.
    @State private var issues: [OpenIssue] = []

    /// The SwiftUI view hierarchy rendered by this view.
    var body: some View {
        NavigationStack {
            Group {
                if issues.isEmpty {
                    ContentUnavailableView(
                        "No Open Issues",
                        systemImage: "checkmark.circle",
                        description: Text(
                            "There are no active violations or ACC applications."
                        )
                    )
                } else {
                    List(issues) { issue in
                        Button {
                            onSelectLot(issue.lotID)
                            dismiss()
                        } label: {
                            issueRow(issue)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Open Issues")
            .toolbar {
                ToolbarItem(
                    placement: .cancellationAction
                ) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem {
                    Button {
                        load()
                    } label: {
                        Label(
                            "Refresh",
                            systemImage: "arrow.clockwise"
                        )
                    }
                }
            }
        }
        .task {
            load()
        }
        #if os(macOS)
        .frame(
            minWidth: 650,
            minHeight: 560
        )
        #endif
    }

    /// Builds the row used to present one violation or ACC item in the Open Issues queue.
    private func issueRow(
        _ issue: OpenIssue
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(
                systemName:
                    issue.kind == .violation
                    ? "exclamationmark.triangle.fill"
                    : "doc.text.magnifyingglass"
            )
            .foregroundStyle(
                issue.kind == .violation
                    ? .orange
                    : .blue
            )
            .frame(width: 22)

            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                HStack {
                    Text("Lot \(issue.lotNumber)")
                        .font(.headline)

                    Text(issue.status)
                        .font(
                            .caption.weight(.semibold)
                        )
                        .foregroundStyle(.secondary)

                    Spacer()

                    Image(
                        systemName: "chevron.right"
                    )
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                }

                if !issue.ownerName.isEmpty {
                    Text(issue.ownerName)
                        .font(.subheadline)
                }

                Text(issue.title)
                    .font(.subheadline)
                    .lineLimit(2)

                if let date = formattedDate(
                    issue.sortDate
                ) {
                    Text(date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    /// Formats a stored ISO-8601 timestamp for user-facing display.
    private func formattedDate(
        _ value: String?
    ) -> String? {
        guard let value,
              !value.isEmpty
        else {
            return nil
        }

        let iso =
            ISO8601DateFormatter()

        if let date =
            iso.date(from: value) {
            return date.formatted(
                date: .abbreviated,
                time: .omitted
            )
        }

        return value
    }

    /// Loads  from its configured source.
    private func load() {
        do {
            issues =
                try model.store.fetchOpenIssues()
        } catch {
            model.statusMessage =
                "Unable to load open issues: \(error.localizedDescription)"
        }
    }
}
