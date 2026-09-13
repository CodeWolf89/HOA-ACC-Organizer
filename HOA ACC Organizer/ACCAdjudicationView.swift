// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import SwiftUI

/// Presents the administrator workflow for approving, conditionally approving, or denying an ACC application.
struct ACCAdjudicationView: View {
    /// The shared application model used to read app state and perform workflow actions.
    @EnvironmentObject var model: AppModel
    /// The SwiftUI dismissal action for closing the current presentation.
    @Environment(\.dismiss) private var dismiss

    /// The ACC application record displayed or processed by this component.
    let request: ACCRequestDetail
    /// A callback invoked after the record is saved successfully.
    let onSaved: () -> Void

    /// The current workflow status.
    @State private var status: String
    /// Transient view state used to track recommendation while this screen is active.
    @State private var recommendation: String
    /// Additional ACC remarks recorded for the application.
    @State private var remarks: String
    /// The ACC chairperson signature or printed-name text recorded for the decision.
    @State private var chairpersonSignature: String
    /// Transient view state used to track chairperson date while this screen is active.
    @State private var chairpersonDate: Date?

    /// Creates an instance with the supplied dependencies and initial values.
    init(
        request: ACCRequestDetail,
        onSaved: @escaping () -> Void
    ) {
        self.request = request
        self.onSaved = onSaved

        _status = State(
            initialValue:
                request.status.isEmpty
                ? "Under Review"
                : request.status
        )
        _recommendation = State(initialValue: request.accRecommendation)
        _remarks = State(initialValue: request.remarks)
        _chairpersonSignature = State(initialValue: request.chairpersonSignature)
        _chairpersonDate = State(
            initialValue:
                ISODateStorage.date(
                    from:
                        request
                            .chairpersonSignatureDate
                )
        )
    }

    /// The SwiftUI view hierarchy rendered by this view.
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(
                            request.applicantName.isEmpty
                                ? "ACC Application"
                                : request.applicantName
                        )
                        .font(.title2.bold())

                        if !request.description.isEmpty {
                            Text(request.description)
                                .foregroundStyle(.secondary)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Decision")
                                .font(.headline)

                            Picker("Status", selection: $status) {
                                Text("Under Review").tag("Under Review")
                                Text("Needs Information").tag("Needs Information")
                                Text("Approved").tag("Approved")
                                Text("Approved with Conditions").tag("Approved with Conditions")
                                Text("Denied").tag("Denied")
                            }
                            .pickerStyle(.menu)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recommendation")
                                .font(.headline)

                            TextEditor(text: $recommendation)
                                .frame(minHeight: 100)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Remarks")
                                .font(.headline)

                            TextEditor(text: $remarks)
                                .frame(minHeight: 120)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Chairperson")
                                .font(.headline)

                            TextField(
                                "Signature / printed name",
                                text: $chairpersonSignature
                            )
                            .textFieldStyle(.roundedBorder)

                            OptionalDatePickerField(
                                title:
                                    "Decision date",
                                selection:
                                    $chairpersonDate
                            )
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity, alignment: .top)
                }

                Divider()

                ViewThatFits(
                    in: .horizontal
                ) {
                    HStack {
                        decisionStatusText

                        Spacer()

                        decisionButtons
                    }

                    VStack(
                        alignment: .leading,
                        spacing: 10
                    ) {
                        decisionStatusText

                        HStack {
                            Spacer()
                            decisionButtons
                        }
                    }
                }
                .padding()
                .background(.bar)
            }
            .navigationTitle("Adjudicate ACC Application")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onChange(of: status) {
                if finalDecision &&
                    chairpersonDate == nil {
                    chairpersonDate =
                        Calendar.current
                            .startOfDay(
                                for: Date()
                            )
                }
            }
        }
        #if os(macOS)
        .frame(
            minWidth: 700,
            minHeight: 620
        )
        #endif
    }

    /// The human-readable ACC decision status shown in the interface.
    private var decisionStatusText:
        some View {
        Text(
            finalDecision
                ? "This decision will remove the application from the active-review count."
                : "This application will remain active."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(
            horizontal: false,
            vertical: true
        )
    }

    /// The adjudication buttons appropriate for the current ACC application state.
    private var decisionButtons:
        some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }

            Button("Save Decision") {
                save()
            }
            .buttonStyle(
                .borderedProminent
            )
        }
    }

    /// Indicates whether the current ACC status represents a final decision.
    private var finalDecision: Bool {
        let value = status.lowercased()
        return value.contains("approved") ||
            value.contains("denied")
    }

    /// Saves  using the current application data model.
    private func save() {
        do {
            guard let actor =
                model.currentAdmin
            else {
                model.statusMessage =
                    "Administrator login is required."
                return // We should make this say something like BOD Login Required.
            }

            try model.store.adjudicateACCRequest(
                id: request.id,
                adjudication: ACCAdjudication(
                    status: status,
                    recommendation: recommendation,
                    remarks: remarks,
                    chairpersonSignature: chairpersonSignature,
                    chairpersonDate: chairpersonDate
                ),
                actor: actor
            )

            model.statusMessage =
                "ACC application adjudication saved."

            Task { await model.refreshReminders() }

            onSaved()
            dismiss()
        } catch {
            model.statusMessage =
                "ACC adjudication failed: \(error.localizedDescription)"
        }
    }
}
