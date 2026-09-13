// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import SwiftUI
import PDFKit
import UniformTypeIdentifiers

/// Shows a complete ACC application record, attachments, adjudication actions, and decision-letter tools.
struct ACCRequestDetailView: View {
    /// The shared application model used to read app state and perform workflow actions.
    @EnvironmentObject var model: AppModel
    /// The SwiftUI dismissal action for closing the current presentation.
    @Environment(\.dismiss) private var dismiss
    /// The SwiftUI environment value used for horizontal size class.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// The stable identifier of the ACC application being displayed.
    let requestID: String

    /// Transient view state used to track request while this screen is active.
    @State private var request: ACCRequestDetail?
    /// Transient view state used to track showing pdf while this screen is active.
    @State private var showingPDF = false
    /// Transient view state used to track showing edit while this screen is active.
    @State private var showingEdit = false
    /// Transient view state used to track showing adjudication while this screen is active.
    @State private var showingAdjudication = false
    /// Transient view state used to track showing audit while this screen is active.
    @State private var showingAudit = false
    /// Transient view state used to track attachments while this screen is active.
    @State private var attachments: [ACCAttachment] = []
    /// Transient view state used to track showing photo importer while this screen is active.
    @State private var showingPhotoImporter = false
    /// Transient view state used to track selected photo while this screen is active.
    @State private var selectedPhoto: ACCAttachment?
    /// Transient view state used to track selected document while this screen is active.
    @State private var selectedDocument: ACCAttachment?
    /// Transient view state used to track showing decision letter while this screen is active.
    @State private var showingDecisionLetter = false
    /// Transient view state used to track showing removal while this screen is active.
    @State private var showingRemoval = false
    /// Transient view state used to track removal completed while this screen is active.
    @State private var removalCompleted = false

    /// The SwiftUI view hierarchy rendered by this view.
    var body: some View {
        ScrollView {
            if let request {
                VStack(alignment: .leading, spacing: 20) {
                    header(request)
                    applicationCard(request)

                    if !request.neighbors.isEmpty {
                        neighborCard(request.neighbors)
                    }

                    if !homeownerPhotos.isEmpty {
                        homeownerPhotoCard
                    }

                    if !decisionLetters.isEmpty {
                        decisionLetterCard
                    }

                    committeeCard(request)

                    applicationActions(request)
                }
                .padding(
                    horizontalSizeClass == .compact
                    ? 16
                    : 24
                )
                .frame(
                    maxWidth: 900,
                    alignment: .leading
                )
                .frame(
                    maxWidth: .infinity,
                    alignment: .topLeading
                )
            } else {
                ProgressView()
                    .frame(
                        maxWidth: .infinity,
                        minHeight: 300
                    )
            }
        }
        .navigationTitle("ACC Application")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task(id: requestID) {
            load()
        }
        .sheet(isPresented: $showingPDF) {
            if let request,
               let fileName = request.pdfFileName,
               let url = try? model.store.attachmentURL(
                    fileName: fileName
               ) {
                ACCPDFViewer(
                    url: url,
                    title: request.pdfOriginalName ??
                        "Application PDF"
                )
            }
        }
        .sheet(isPresented: $showingEdit) {
            if let request {
                ACCEditApplicationView(
                    request: request
                ) {
                    load()
                    try? model.refresh()
                }
                .environmentObject(model)
            }
        }
        .sheet(isPresented: $showingAdjudication) {
            if let request {
                ACCAdjudicationView(
                    request: request
                ) {
                    load()
                    try? model.refresh()
                }
                .environmentObject(model)
            }
        }
        .sheet(isPresented: $showingAudit) {
            AuditLogView(
                entityType: "accRequest",
                entityID: requestID
            )
            .environmentObject(model)
        }
        .fileImporter(
            isPresented:
                $showingPhotoImporter,
            allowedContentTypes:
                [.image],
            allowsMultipleSelection:
                true
        ) { result in
            handlePhotoImport(
                result
            )
        }
        .sheet(item: $selectedPhoto) {
            attachment in

            if let url =
                try? model.store
                    .attachmentURL(
                        fileName:
                            attachment
                            .fileName
                    ) {
                ACCPhotoAttachmentViewer(
                    url: url,
                    title:
                        attachment
                            .originalFileName
                )
            }
        }
        .sheet(item: $selectedDocument) {
            attachment in

            if let url =
                try? model.store
                    .attachmentURL(
                        fileName:
                            attachment
                            .fileName
                    ) {
                ACCPDFViewer(
                    url: url,
                    title:
                        attachment
                            .originalFileName
                )
            }
        }
        .sheet(
            isPresented:
                $showingDecisionLetter
        ) {
            if let request,
               let lot =
                    try? model.store
                        .fetchLot(
                            request.lotID
                        ) {
                ACCDecisionLetterView(
                    request: request,
                    lot: lot
                ) {
                    load()
                    try? model.refresh()
                }
                .environmentObject(model)
            }
        }
        .sheet(
            isPresented: $showingRemoval,
            onDismiss: {
                if removalCompleted {
                    dismiss()
                }
            }
        ) {
            RemovalReasonView(
                title: "Remove ACC Application",
                itemDescription:
                    "Remove this ACC application from the active HOA record. This operation is available only to SHOA_ACC_SuperUser.",
                confirmTitle: "Remove Application"
            ) { reason in
                try removeACCApplication(
                    reason: reason
                )
            }
        }
    }

    /// Selects the administrator action layout that best fits the space actually available to the detail view.
    ///
    /// iPad size classes are intentionally not used as the only layout signal here. An iPad mini,
    /// Split View, Stage Manager window, or narrow navigation column can all report a regular size
    /// class while providing much less horizontal room than a full-screen iPad. `ViewThatFits`
    /// therefore attempts a single-row layout first and automatically falls back to a two-column
    /// action card before using the fully stacked compact layout.
    @ViewBuilder
    private func applicationActions(
        _ request: ACCRequestDetail
    ) -> some View {
        #if os(iOS)
        if horizontalSizeClass == .compact {
            compactApplicationActions(
                request
            )
        } else {
            ViewThatFits(in: .horizontal) {
                regularApplicationActions(
                    request
                )
                .fixedSize(
                    horizontal: true,
                    vertical: false
                )

                mediumApplicationActions(
                    request
                )
            }
        }
        #else
        regularApplicationActions(
            request
        )
        #endif
    }

    /// Builds the stacked administrator action controls used on compact iPhone layouts.
    private func compactApplicationActions(
        _ request: ACCRequestDetail
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            Text("Actions")
                .font(.headline)

            if model.isAdmin {
                Button {
                    showingAdjudication = true
                } label: {
                    Label(
                        "Adjudicate Application",
                        systemImage:
                            "checkmark.seal"
                    )
                    .frame(
                        maxWidth: .infinity,
                        alignment: .center
                    )
                }
                .buttonStyle(
                    .borderedProminent
                )
                .accessibilityIdentifier(
                    "acc.action.adjudicate"
                )

                VStack(
                    spacing: 10
                ) {
                    compactActionButton(
                        "Edit Application",
                        systemImage: "pencil",
                        accessibilityIdentifier:
                            "acc.action.edit"
                    ) {
                        showingEdit = true
                    }

                    compactActionButton(
                        "Audit History",
                        systemImage:
                            "clock.badge.checkmark",
                        accessibilityIdentifier:
                            "acc.action.audit"
                    ) {
                        showingAudit = true
                    }

                    compactActionButton(
                        "Add Photos",
                        systemImage:
                            "photo.badge.plus",
                        accessibilityIdentifier:
                            "acc.action.addPhotos"
                    ) {
                        showingPhotoImporter = true
                    }

                    if request.pdfFileName != nil {
                        compactActionButton(
                            "Original PDF",
                            systemImage:
                                "doc.richtext",
                            accessibilityIdentifier:
                                "acc.action.originalPDF"
                        ) {
                            showingPDF = true
                        }
                    }

                    if finalDecisionStatus(
                        request.status
                    ) {
                        compactActionButton(
                            "Decision Letter",
                            systemImage:
                                "doc.text",
                            accessibilityIdentifier:
                                "acc.action.decisionLetter"
                        ) {
                            showingDecisionLetter = true
                        }
                    }

                    if model.isSuperUser {
                        Button(
                            role: .destructive
                        ) {
                            showingRemoval = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(
                                    systemName: "trash"
                                )
                                .frame(width: 22)

                                Text(
                                    "Remove Application"
                                )

                                Spacer()
                            }
                            .font(
                                .subheadline.weight(
                                    .medium
                                )
                            )
                            .frame(
                                maxWidth: .infinity,
                                minHeight: 44,
                                alignment: .leading
                            )
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier(
                            "acc.action.remove"
                        )
                    }
                }
            } else if request.pdfFileName != nil {
                compactActionButton(
                    "Original PDF",
                    systemImage: "doc.richtext",
                    accessibilityIdentifier:
                        "acc.action.originalPDF"
                ) {
                    showingPDF = true
                }
            } else {
                Text(
                    "No application actions are available for this record."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .cardStyle()
    }

    /// Builds a two-column action card for iPad layouts whose detail column is narrower than a full-screen iPad.
    ///
    /// This layout is especially useful on iPad mini and in Split View because it prevents button
    /// labels from wrapping one character at a time while still using horizontal space efficiently.
    private func mediumApplicationActions(
        _ request: ACCRequestDetail
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            Text("Actions")
                .font(.headline)

            if model.isAdmin {
                Button {
                    showingAdjudication = true
                } label: {
                    Label(
                        "Adjudicate Application",
                        systemImage: "checkmark.seal"
                    )
                    .frame(
                        maxWidth: .infinity,
                        alignment: .center
                    )
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier(
                    "acc.action.adjudicate"
                )

                LazyVGrid(
                    columns: [
                        GridItem(
                            .flexible(),
                            spacing: 10
                        ),
                        GridItem(
                            .flexible(),
                            spacing: 10
                        )
                    ],
                    alignment: .leading,
                    spacing: 10
                ) {
                    mediumActionButton(
                        "Edit Application",
                        systemImage: "pencil",
                        accessibilityIdentifier: "acc.action.edit"
                    ) {
                        showingEdit = true
                    }

                    mediumActionButton(
                        "Audit History",
                        systemImage: "clock.badge.checkmark",
                        accessibilityIdentifier: "acc.action.audit"
                    ) {
                        showingAudit = true
                    }

                    mediumActionButton(
                        "Add Photos",
                        systemImage: "photo.badge.plus",
                        accessibilityIdentifier: "acc.action.addPhotos"
                    ) {
                        showingPhotoImporter = true
                    }

                    if request.pdfFileName != nil {
                        mediumActionButton(
                            "Original PDF",
                            systemImage: "doc.richtext",
                            accessibilityIdentifier: "acc.action.originalPDF"
                        ) {
                            showingPDF = true
                        }
                    }

                    if finalDecisionStatus(
                        request.status
                    ) {
                        mediumActionButton(
                            "Decision Letter",
                            systemImage: "doc.text",
                            accessibilityIdentifier: "acc.action.decisionLetter"
                        ) {
                            showingDecisionLetter = true
                        }
                    }

                    if model.isSuperUser {
                        Button(
                            role: .destructive
                        ) {
                            showingRemoval = true
                        } label: {
                            Label(
                                "Remove Application",
                                systemImage: "trash"
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .frame(
                                maxWidth: .infinity,
                                minHeight: 44,
                                alignment: .leading
                            )
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier(
                            "acc.action.remove"
                        )
                    }
                }
            } else if request.pdfFileName != nil {
                mediumActionButton(
                    "Original PDF",
                    systemImage: "doc.richtext",
                    accessibilityIdentifier: "acc.action.originalPDF"
                ) {
                    showingPDF = true
                }
            } else {
                Text(
                    "No application actions are available for this record."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .cardStyle()
    }

    /// Builds one secondary action button for the medium two-column iPad layout.
    private func mediumActionButton(
        _ title: String,
        systemImage: String,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(
            action: action
        ) {
            Label(
                title,
                systemImage: systemImage
            )
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .frame(
                maxWidth: .infinity,
                minHeight: 44,
                alignment: .leading
            )
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier(
            accessibilityIdentifier
        )
    }

    /// Builds the wider administrator action controls used on iPad and macOS.
    private func regularApplicationActions(
        _ request: ACCRequestDetail
    ) -> some View {
        HStack(spacing: 12) {
            if model.isAdmin {
                Button {
                    showingEdit = true
                } label: {
                    Label(
                        "Edit Application",
                        systemImage: "pencil"
                    )
                    .lineLimit(1)
                }

                Button {
                    showingAdjudication = true
                } label: {
                    Label(
                        "Adjudicate",
                        systemImage:
                            "checkmark.seal"
                    )
                    .lineLimit(1)
                }
                .buttonStyle(
                    .borderedProminent
                )

                Button {
                    showingAudit = true
                } label: {
                    Label(
                        "Audit History",
                        systemImage:
                            "clock.badge.checkmark"
                    )
                    .lineLimit(1)
                }

                Button {
                    showingPhotoImporter = true
                } label: {
                    Label(
                        "Add Photos",
                        systemImage:
                            "photo.badge.plus"
                    )
                    .lineLimit(1)
                }

                if finalDecisionStatus(
                    request.status
                ) {
                    Button {
                        showingDecisionLetter = true
                    } label: {
                        Label(
                            "Decision Letter",
                            systemImage:
                                "doc.text"
                        )
                        .lineLimit(1)
                    }
                }

                if model.isSuperUser {
                    Button(
                        role: .destructive
                    ) {
                        showingRemoval = true
                    } label: {
                        Label(
                            "Remove Application",
                            systemImage: "trash"
                        )
                        .lineLimit(1)
                    }
                    .accessibilityIdentifier(
                        "acc.action.remove"
                    )
                }
            }

            Spacer()

            if request.pdfFileName != nil {
                Button {
                    showingPDF = true
                } label: {
                    Label(
                        "Original PDF",
                        systemImage:
                            "doc.richtext"
                    )
                    .lineLimit(1)
                }
            }
        }
    }

    /// Builds a full-width ACC application action button for compact layouts.
    private func compactActionButton(
        _ title: String,
        systemImage: String,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(
            action: action
        ) {
            HStack(
                spacing: 10
            ) {
                Image(
                    systemName: systemImage
                )
                .frame(width: 22)

                Text(title)
                    .lineLimit(1)

                Spacer()
            }
            .font(.subheadline.weight(.medium))
            .frame(
                maxWidth: .infinity,
                minHeight: 44,
                alignment: .leading
            )
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier(
            accessibilityIdentifier
        )
    }

    /// The homeowner-supplied photo attachments displayed for this application.
    private var homeownerPhotos:
        [ACCAttachment] {
        attachments.filter {
            $0.kind ==
                "accHomeownerPhoto"
        }
    }

    /// The generated decision-letter attachments associated with this application.
    private var decisionLetters:
        [ACCAttachment] {
        attachments.filter {
            $0.kind ==
                "accDecisionLetter"
        }
    }

    /// The card that presents homeowner-supplied ACC photo attachments.
    private var homeownerPhotoCard:
        some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            HStack {
                Label(
                    "Homeowner Photos",
                    systemImage:
                        "photo.on.rectangle"
                )
                .font(.headline)

                Spacer()

                Text(
                    "\(homeownerPhotos.count)"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            ForEach(
                homeownerPhotos
            ) { attachment in
                Button {
                    selectedPhoto =
                        attachment
                } label: {
                    HStack {
                        Image(
                            systemName:
                                "photo"
                        )

                        VStack(
                            alignment:
                                .leading,
                            spacing: 2
                        ) {
                            Text(
                                attachment
                                    .originalFileName
                            )
                            .lineLimit(1)

                            if let date =
                                displayDate(
                                    attachment
                                        .createdAt
                                ) {
                                Text(
                                    "Added \(date)"
                                )
                                .font(.caption)
                                .foregroundStyle(
                                    .secondary
                                )
                            }
                        }

                        Spacer()

                        Image(
                            systemName:
                                "arrow.up.left.and.arrow.down.right"
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }
                }
                .buttonStyle(.plain)

                if attachment.id !=
                    homeownerPhotos
                        .last?.id {
                    Divider()
                }
            }
        }
        .padding(20)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .cardStyle()
    }

    /// The card that presents generated ACC decision-letter attachments.
    private var decisionLetterCard:
        some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            HStack {
                Label(
                    "Decision Letters",
                    systemImage:
                        "doc.text"
                )
                .font(.headline)

                Spacer()

                Text(
                    "\(decisionLetters.count)"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            ForEach(
                decisionLetters
            ) { attachment in
                Button {
                    selectedDocument =
                        attachment
                } label: {
                    HStack {
                        Image(
                            systemName:
                                "doc.richtext"
                        )

                        VStack(
                            alignment:
                                .leading,
                            spacing: 2
                        ) {
                            Text(
                                attachment
                                    .originalFileName
                            )
                            .lineLimit(1)

                            if let date =
                                displayDate(
                                    attachment
                                        .createdAt
                                ) {
                                Text(
                                    "Generated \(date)"
                                )
                                .font(.caption)
                                .foregroundStyle(
                                    .secondary
                                )
                            }
                        }

                        Spacer()

                        Image(
                            systemName:
                                "chevron.right"
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }
                }
                .buttonStyle(.plain)

                if attachment.id !=
                    decisionLetters
                        .last?.id {
                    Divider()
                }
            }
        }
        .padding(20)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .cardStyle()
    }

    /// Returns whether the ACC application status is a final decision that can produce a decision letter.
    private func finalDecisionStatus(
        _ status: String
    ) -> Bool {
        let value =
            status.lowercased()

        return
            value.contains(
                "approved"
            ) ||
            value.contains(
                "denied"
            ) ||
            value.contains(
                "rejected"
            )
    }

    /// Permanently removes this ACC application after the SuperUser supplies
    /// the mandatory audit reason. The store independently verifies the actor.
    private func removeACCApplication(
        reason: String
    ) throws {
        guard
            model.isSuperUser,
            let actor = model.currentAdmin
        else {
            throw StoreError.sql(
                "Only SHOA_ACC_SuperUser can remove ACC applications."
            )
        }

        try model.store.removeACCRequest(
            id: requestID,
            reason: reason,
            actor: actor
        )

        do {
            try model.refresh()
            model.statusMessage =
                "ACC application removed. The reason was recorded in the Audit Log."
        } catch {
            model.statusMessage =
                "ACC application removed, but the screen could not refresh immediately: \(error.localizedDescription)"
        }

        removalCompleted = true

        Task {
            await model.refreshReminders()
        }
    }

    /// Imports selected homeowner photos, stores attachment metadata, and refreshes the application detail.
    private func handlePhotoImport(
        _ result:
            Result<[URL], Error>
    ) {
        guard
            let request,
            let actor =
                model.currentAdmin
        else {
            model.statusMessage =
                "Administrator login is required."
            return
        }

        switch result {
        case .success(let urls):
            var added = 0
            var failed = 0

            for url in urls {
                do {
                    let photo =
                        try ACCPendingPhoto
                            .load(
                                from: url
                            )

                    try model.store
                        .addACCPhoto(
                            requestID:
                                request.id,
                            lotID:
                                request.lotID,
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

                    added += 1
                } catch {
                    failed += 1
                }
            }

            load()

            if failed == 0 {
                model.statusMessage =
                    "Added \(added) photo(s) to the ACC application."
            } else {
                model.statusMessage =
                    "Added \(added) photo(s); \(failed) could not be imported."
            }

        case .failure(let error):
            model.statusMessage =
                "Photo selection failed: \(error.localizedDescription)"
        }
    }

    /// Builds the header section for the currently displayed record.
    private func header(
        _ request: ACCRequestDetail
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(request.status)
                    .font(
                        .subheadline.weight(.semibold)
                    )
                    .padding(
                        .horizontal,
                        12
                    )
                    .padding(
                        .vertical,
                        7
                    )
                    .background(
                        Capsule()
                            .fill(
                                statusColor(
                                    request.status
                                )
                                .opacity(0.15)
                            )
                    )
                    .foregroundStyle(
                        statusColor(
                            request.status
                        )
                    )

                Spacer()

                if let submitted = displayDate(
                    request.submittedAt
                ) {
                    Text("Submitted \(submitted)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

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
        }
        .padding(20)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .cardStyle()
    }

    /// Builds the primary ACC application-information card.
    private func applicationCard(
        _ request: ACCRequestDetail
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Application")
                .font(.headline)

            field(
                "Applicant",
                request.applicantName
            )
            field(
                "Phone",
                request.applicantPhone
            )
            field(
                "Property",
                request.proposedChangeAddress
            )
            field(
                "Description",
                request.description
            )
            field(
                "Color",
                request.color
            )

            ViewThatFits(
                in: .horizontal
            ) {
                HStack(
                    alignment: .top,
                    spacing: 28
                ) {
                    field(
                        "Proposed Start",
                        displayDate(
                            request.proposedStartDate
                        ) ?? ""
                    )

                    field(
                        "Proposed Completion",
                        displayDate(
                            request.proposedCompletionDate
                        ) ?? ""
                    )
                }

                VStack(
                    alignment: .leading,
                    spacing: 12
                ) {
                    field(
                        "Proposed Start",
                        displayDate(
                            request.proposedStartDate
                        ) ?? ""
                    )

                    field(
                        "Proposed Completion",
                        displayDate(
                            request.proposedCompletionDate
                        ) ?? ""
                    )
                }
            }
        }
        .padding(20)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .cardStyle()
    }

    /// Builds the card that presents neighbor acknowledgement information.
    private func neighborCard(
        _ neighbors: [ACCNeighbor]
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Neighbor Acknowledgements")
                .font(.headline)

            ForEach(neighbors) { neighbor in
                HStack(alignment: .top) {
                    VStack(
                        alignment: .leading,
                        spacing: 3
                    ) {
                        Text(
                            neighbor.name.isEmpty
                                ? "Neighbor"
                                : neighbor.name
                        )
                        .font(.subheadline.weight(.medium))

                        if !neighbor.address.isEmpty {
                            Text(neighbor.address)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if !neighbor.lotNumber.isEmpty {
                        Text("Lot \(neighbor.lotNumber)")
                            .font(.caption)
                    }

                    Image(
                        systemName:
                            neighbor.signatureObserved
                            ? "checkmark.circle.fill"
                            : "circle"
                    )
                    .foregroundStyle(
                        neighbor.signatureObserved
                            ? .green
                            : .secondary
                    )
                }

                if neighbor.id != neighbors.last?.id {
                    Divider()
                }
            }
        }
        .padding(20)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .cardStyle()
    }

    /// Builds the card that presents ACC review, recommendation, and decision information.
    private func committeeCard(
        _ request: ACCRequestDetail
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ACC Review")
                .font(.headline)

            field(
                "Recommendation",
                request.accRecommendation
            )
            field(
                "Remarks",
                request.remarks
            )
            field(
                "Chairperson",
                request.chairpersonSignature
            )
            field(
                "Chairperson Date",
                displayDate(
                    request.chairpersonSignatureDate
                ) ?? ""
            )
        }
        .padding(20)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .cardStyle()
    }

    @ViewBuilder
    /// Builds a labeled value row used by a detail card.
    private func field(
        _ title: String,
        _ value: String
    ) -> some View {
        if !value.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(value)
                    .textSelection(.enabled)
            }
        }
    }

    /// Returns the semantic color associated with the current workflow status.
    private func statusColor(
        _ status: String
    ) -> Color {
        let value = status.lowercased()

        if value.contains("approved") {
            return .green
        }
        if value.contains("denied") ||
            value.contains("rejected") {
            return .red
        }
        if value.contains("review") ||
            value.contains("pending") {
            return .orange
        }

        return .blue
    }

    /// Formats a stored date for human-readable PDF output.
    private func displayDate(
        _ value: String?
    ) -> String? {
        guard let value,
              !value.trimmingCharacters(
                in: .whitespacesAndNewlines
              ).isEmpty else {
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
            request = try model.store.fetchACCRequest(
                requestID
            )
            attachments =
                try model.store
                    .fetchACCAttachments(
                        requestID:
                            requestID
                    )
        } catch {
            model.statusMessage =
                error.localizedDescription
        }
    }
}

/// Adds HOA ACC Organizer behavior to `View`.
private extension View {
    /// Applies the shared visual styling used by ACC detail cards.
    func cardStyle() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.thinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.quaternary)
            )
    }
}

/// Presents an ACC source PDF or generated PDF attachment in a dedicated viewer.
struct ACCPDFViewer: View {
    /// The SwiftUI dismissal action for closing the current presentation.
    @Environment(\.dismiss) private var dismiss
    /// The URL used for url.
    let url: URL
    /// The human-readable title displayed for this value.
    let title: String

    /// The SwiftUI view hierarchy rendered by this view.
    var body: some View {
        NavigationStack {
            PDFKitRepresentable(url: url)
                .navigationTitle(title)
                .toolbar {
                    ToolbarItem(
                        placement: .cancellationAction
                    ) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
        #if os(macOS)
        .frame(
            minWidth: 700,
            minHeight: 600
        )
        #endif
    }
}

#if os(macOS)
/// Bridges PDFKit into SwiftUI for the current Apple platform.
struct PDFKitRepresentable: NSViewRepresentable {
    /// The URL used for url.
    let url: URL

    /// Creates the AppKit-backed PDF view used by SwiftUI on macOS.
    func makeNSView(
        context: Context
    ) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.document = PDFDocument(url: url)
        return view
    }

    /// Updates nsview while preserving workflow and audit requirements.
    func updateNSView(
        _ nsView: PDFView,
        context: Context
    ) {
        if nsView.document?.documentURL != url {
            nsView.document = PDFDocument(url: url)
        }
    }
}
#elseif os(iOS)
/// Bridges PDFKit into SwiftUI for the current Apple platform.
struct PDFKitRepresentable: UIViewRepresentable {
    /// The URL used for url.
    let url: URL

    /// Creates the UIKit-backed PDF view used by SwiftUI on iOS and iPadOS.
    func makeUIView(
        context: Context
    ) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.document = PDFDocument(url: url)
        return view
    }

    /// Updates uiview while preserving workflow and audit requirements.
    func updateUIView(
        _ uiView: PDFView,
        context: Context
    ) {
        if uiView.document?.documentURL != url {
            uiView.document = PDFDocument(url: url)
        }
    }
}
#endif


#if os(macOS)
import AppKit
/// Provides a project-specific alias for `ACCPlatformImage`.
private typealias ACCPlatformImage = NSImage
#elseif os(iOS)
import UIKit
/// Provides a project-specific alias for `ACCPlatformImage`.
private typealias ACCPlatformImage = UIImage
#endif

/// Displays a stored ACC photo attachment at a readable size.
struct ACCPhotoAttachmentViewer: View {
    /// The SwiftUI dismissal action for closing the current presentation.
    @Environment(\.dismiss)
    private var dismiss

    /// The URL used for url.
    let url: URL
    /// The human-readable title displayed for this value.
    let title: String

    /// The SwiftUI view hierarchy rendered by this view.
    var body: some View {
        NavigationStack {
            ScrollView(
                [.horizontal, .vertical]
            ) {
                if let image =
                    ACCPlatformImage(
                        contentsOfFile:
                            url.path
                    ) {
                    #if os(macOS)
                    Image(
                        nsImage: image
                    )
                    .resizable()
                    .scaledToFit()
                    #elseif os(iOS)
                    Image(
                        uiImage: image
                    )
                    .resizable()
                    .scaledToFit()
                    #endif
                } else {
                    ContentUnavailableView(
                        "Unable to Load Photo",
                        systemImage:
                            "photo.badge.exclamationmark"
                    )
                }
            }
            .padding()
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(
                    placement:
                        .cancellationAction
                ) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        #if os(macOS)
        .frame(
            minWidth: 720,
            minHeight: 600
        )
        #endif
    }
}
