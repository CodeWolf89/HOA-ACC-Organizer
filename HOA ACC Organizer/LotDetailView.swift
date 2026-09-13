// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import SwiftUI
import UniformTypeIdentifiers

/// Displays owner information, violation history, ACC applications, and administrator actions for a selected lot.
struct LotDetailView: View {
    /// The shared application model used to read app state and perform workflow actions.
    @EnvironmentObject var model: AppModel
    /// The stable identifier of the lot associated with this record.
    let lotID: String

    /// Transient view state used to track lot while this screen is active.
    @State private var lot: LotDetail?
    /// Transient view state used to track violations while this screen is active.
    @State private var violations: [ViolationListItem] = []
    /// Transient view state used to track applications while this screen is active.
    @State private var applications: [ACCRequestSummary] = []

    /// Transient view state used to track showing acc importer while this screen is active.
    @State private var showingACCImporter = false
    /// Transient view state used to track prepared draft while this screen is active.
    @State private var preparedDraft: ACCApplicationDraft?
    /// Transient view state used to track manual draft while this screen is active.
    @State private var manualDraft: ACCApplicationDraft?
    /// Transient view state used to track is preparing application while this screen is active.
    @State private var isPreparingApplication = false

    /// The SwiftUI view hierarchy rendered by this view.
    var body: some View {
        Group {
            if let lot {
                List {
                    Section {
                        header(lot)
                    }

                    Section {
                        if applications.isEmpty {
                            Text("No ACC applications on file.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(applications) { request in
                                NavigationLink {
                                    ACCRequestDetailView(
                                        requestID: request.id
                                    )
                                } label: {
                                    applicationRow(request)
                                }
                            }
                        }
                    } header: {
                        HStack {
                            Text("ACC Applications")
                            Spacer()
                            if isPreparingApplication {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                    } footer: {
                        #if os(macOS)
                        if model.isAdmin {
                            HStack(
                                spacing: 12
                            ) {
                                manualApplicationButton(
                                    lot
                                )

                                importApplicationButton
                            }
                        } else {
                            Text(
                                "Administrator login is required to import or modify applications."
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        #else
                        if !model.isAdmin {
                            Text(
                                "Administrator login is required to import or modify applications."
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        #endif
                    }

                    #if os(iOS)
                    if model.isAdmin {
                        Section("ACC Actions") {
                            manualApplicationButton(
                                lot
                            )

                            importApplicationButton
                        }
                    }
                    #endif

                    Section("Violation History") {
                        if violations.isEmpty {
                            Text("No violation history.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(violations) { item in
                                NavigationLink {
                                    ViolationDetailView(
                                        violationID: item.id
                                    )
                                } label: {
                                    violationRow(item)
                                }
                            }
                        }
                    }
                }
                .navigationTitle(
                    "Lot \(lot.lotNumber)"
                )
            } else {
                ProgressView()
            }
        }
        .task(id: lotID) {
            load()
        }
        .onChange(
            of: model.contentRevision
        ) { _, _ in
            load()
        }
        .fileImporter(
            isPresented: $showingACCImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first,
                      let lot else {
                    return
                }

                isPreparingApplication = true
                model.statusMessage =
                    "Reading ACC application…"

                Task {
                    do {
                        let importer =
                            ACCApplicationImporter(
                                store: model.store
                            )
                        let draft =
                            try await importer.prepareDraft(
                                from: url,
                                lot: lot
                            )

                        preparedDraft = draft

                        model.statusMessage =
                            draft.ocrUsedOnDeviceModel
                            ? "Application recognized with on-device Apple Intelligence. Review the fields before saving."
                            : "Application OCR complete. Review the fields before saving."
                    } catch {
                        model.statusMessage =
                            "ACC PDF import failed: \(error.localizedDescription)"
                    }

                    isPreparingApplication = false
                }

            case .failure(let error):
                model.statusMessage =
                    "ACC PDF selection failed: \(error.localizedDescription)"
            }
        }
        .sheet(
            item: $preparedDraft
        ) { draft in
            ACCImportReviewView(
                draft: draft
            ) {
                load()
            }
            .environmentObject(model)
        }
        .sheet(
            item: $manualDraft
        ) { draft in
            ACCManualEntryView(
                draft: draft
            ) {
                load()
            }
            .environmentObject(model)
        }
    }

    /// Builds the lot-level action that opens a new manually entered ACC application.
    private func manualApplicationButton(
        _ lot: LotDetail
    ) -> some View {
        Button {
            manualDraft =
                makeManualDraft(
                    for: lot
                )
        } label: {
            Label(
                "Add Application Manually",
                systemImage:
                    "square.and.pencil"
            )
            #if os(iOS)
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            #endif
        }
        .accessibilityIdentifier(
            "lot.acc.addManual"
        )
        .disabled(
            isPreparingApplication
        )
    }

    /// The button that opens the ACC PDF file importer for the current lot.
    private var importApplicationButton:
        some View {
        Button {
            showingACCImporter = true
        } label: {
            Label(
                "Import Application PDF",
                systemImage:
                    "doc.badge.plus"
            )
            #if os(iOS)
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            #endif
        }
        .accessibilityIdentifier(
            "lot.acc.importPDF"
        )
        .disabled(
            isPreparingApplication
        )
    }

    /// Creates a new ACC draft prefilled with the selected lot’s owner/contact information.
    private func makeManualDraft(
        for lot: LotDetail
    ) -> ACCApplicationDraft {
        var draft =
            ACCApplicationDraft(
                lotID: lot.id
            )

        draft.applicantName =
            lot.ownerName

        draft.applicantPhone =
            lot.primaryPhone

        draft.proposedChangeAddress =
            lot.primaryAddress

        draft.submittedAt =
            Calendar.current
                .startOfDay(
                    for: Date()
                )

        draft.status =
            "Under Review"

        return draft
    }

    @ViewBuilder
    /// Builds the header section for the currently displayed record.
    private func header(
        _ lot: LotDetail
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            HStack(alignment: .top) {
                VStack(
                    alignment: .leading,
                    spacing: 4
                ) {
                    Text("Lot \(lot.lotNumber)")
                        .font(.title2.bold())

                    Text(
                        lot.ownerName.isEmpty
                            ? "Owner not loaded"
                            : lot.ownerName
                    )

                    Text(lot.primaryAddress)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if lot.isRentalUnit {
                    Label(
                        "Rental",
                        systemImage: "key"
                    )
                }
            }

            if !lot.primaryPhone.isEmpty {
                LabeledContent(
                    "Phone",
                    value: lot.primaryPhone
                )
            }

            if !lot.primaryEmail.isEmpty {
                LabeledContent(
                    "Email",
                    value: lot.primaryEmail
                )
            }
        }
        .padding(.vertical, 6)
    }

    /// Builds the summary row for one ACC application in the lot detail screen.
    private func applicationRow(
        _ request: ACCRequestSummary
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 5
        ) {
            HStack {
                Text(
                    request.applicantName.isEmpty
                        ? "ACC Application"
                        : request.applicantName
                )
                .font(.headline)

                Spacer()

                Text(request.status)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(
                        applicationStatusColor(
                            request.status
                        )
                    )
            }

            if !request.description.isEmpty {
                Text(request.description)
                    .font(.subheadline)
                    .lineLimit(2)
            }

            if let submitted =
                formatDate(request.submittedAt) {
                Text("Submitted \(submitted)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }

    /// Builds the summary row for one violation in the lot detail screen.
    private func violationRow(
        _ item: ViolationListItem
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 4
        ) {
            HStack {
                Text(
                    item.ruleTitles.isEmpty
                        ? "Violation"
                        : item.ruleTitles
                )
                .font(.headline)

                Spacer()

                Text(item.status)
                    .font(.caption)
                    .bold()
            }

            if let observed =
                formatDate(item.observedAt) {
                Text("Observed \(observed)")
                    .font(.caption)
            }

            if item.photoCount > 0 {
                Label(
                    "\(item.photoCount) photo" +
                    "\(item.photoCount == 1 ? "" : "s")",
                    systemImage: "photo"
                )
                .font(.caption2)
            }
        }
        .padding(.vertical, 2)
    }

    /// Returns the semantic color used for an ACC application status.
    private func applicationStatusColor(
        _ status: String
    ) -> Color {
        let value = status.lowercased()

        if value.contains("approved") {
            return .green
        }
        if value.contains("denied") {
            return .red
        }
        if value.contains("review") ||
            value.contains("pending") {
            return .orange
        }

        return .blue
    }

    /// Formats date for `LotDetailView`.
    private func formatDate(
        _ value: String?
    ) -> String? {
        guard let value,
              !value.isEmpty else {
            return nil
        }

        let iso = ISO8601DateFormatter()

        if let date = iso.date(from: value) {
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
            lot = try model.store.fetchLot(
                lotID
            )
            violations =
                try model.store.fetchViolations(
                    lotID: lotID
                )
            applications =
                try model.store.fetchACCRequests(
                    lotID: lotID
                )
        } catch {
            model.statusMessage =
                error.localizedDescription
        }
    }
}
