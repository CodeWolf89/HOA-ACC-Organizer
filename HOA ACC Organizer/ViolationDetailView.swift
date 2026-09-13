// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import SwiftUI

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// Shows a violation record, governing rule text, history, attachments, editing, adjudication, and PDF-report tools.
struct ViolationDetailView: View {
    /// The shared application model used to read app state and perform workflow actions.
    @EnvironmentObject var model: AppModel
    /// The SwiftUI dismissal action for closing the current presentation.
    @Environment(\.dismiss) private var dismiss
    /// The SwiftUI environment value used for horizontal size class.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// The stable identifier of the violation being displayed or exported.
    let violationID: String

    /// Transient view state used to track item while this screen is active.
    @State private var item: ViolationListItem?
    /// Transient view state used to track attachments while this screen is active.
    @State private var attachments: [ViolationAttachment] = []
    /// Transient view state used to track rules while this screen is active.
    @State private var rules: [ViolationRuleDetail] = []
    /// Transient view state used to track actions while this screen is active.
    @State private var actions: [ViolationAction] = []
    /// Transient view state used to track selected photo while this screen is active.
    @State private var selectedPhoto: ViolationAttachment?
    /// Transient view state used to track showing adjudication while this screen is active.
    @State private var showingAdjudication = false
    /// Transient view state used to track showing edit while this screen is active.
    @State private var showingEdit = false
    /// Transient view state used to track showing audit while this screen is active.
    @State private var showingAudit = false
    /// Transient view state used to track showing pdf report while this screen is active.
    @State private var showingPDFReport = false
    /// Transient view state used to track showing removal while this screen is active.
    @State private var showingRemoval = false
    /// Transient view state used to track removal completed while this screen is active.
    @State private var removalCompleted = false

    /// The SwiftUI view hierarchy rendered by this view.
    var body: some View {
        ScrollView {
            if let item {
                VStack(alignment: .leading, spacing: 20) {
                    summaryCard(item)
                    ruleSection
                    detailsCard(item)

                    violationActions

                    photosSection

                    if !actions.isEmpty {
                        historySection
                    }
                }
                .padding(24)
                .frame(maxWidth: 900, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 300)
            }
        }
        .navigationTitle("Violation")
        .toolbar {
            if let item,
               model.isAdmin,
               !isResolved(item.status) {
                ToolbarItem {
                    Button {
                        showingAdjudication = true
                    } label: {
                        Label(
                            "Adjudicate",
                            systemImage: "checkmark.seal"
                        )
                    }
                }
            }
        }
        .task(id: violationID) {
            load()
        }
        .sheet(item: $selectedPhoto) { attachment in
            PhotoViewer(
                attachment: attachment,
                store: model.store
            )
        }
        .sheet(isPresented: $showingAdjudication) {
            if let item {
                ViolationAdjudicationView(
                    violation: item
                ) {
                    load()
                }
                .environmentObject(model)
            }
        }
        .sheet(isPresented: $showingEdit) {
            if let item {
                ViolationEditView(
                    violation: item
                ) {
                    load()
                }
                .environmentObject(model)
            }
        }
        .sheet(isPresented: $showingAudit) {
            AuditLogView(
                entityType: "violation",
                entityID: violationID
            )
            .environmentObject(model)
        }
        .sheet(
            isPresented:
                $showingPDFReport
        ) {
            ViolationPDFReportView(
                violationID:
                    violationID
            )
            .environmentObject(model)
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
                title: "Remove Violation",
                itemDescription:
                    "Remove this violation from the active HOA record. This operation is available only to SHOA_ACC_SuperUser.",
                confirmTitle: "Remove Violation"
            ) { reason in
                try removeViolation(
                    reason: reason
                )
            }
        }
    }

    /// The administrator actions displayed for the current violation.
    ///
    /// The layout adapts to the width actually available to this view instead of assuming that
    /// every regular-width iPad can fit a single horizontal action row. This matters on iPad mini,
    /// Split View, Stage Manager, and narrow detail columns.
    @ViewBuilder
    private var violationActions:
        some View {
        #if os(iOS)
        if horizontalSizeClass == .compact {
            compactViolationActions
        } else {
            ViewThatFits(in: .horizontal) {
                regularViolationActions
                    .fixedSize(
                        horizontal: true,
                        vertical: false
                    )

                mediumViolationActions
            }
        }
        #else
        regularViolationActions
        #endif
    }

    /// Builds the vertically stacked violation actions used on compact iPhone layouts.
    private var compactViolationActions:
        some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            Text("Actions")
                .font(.headline)

            compactViolationActionButton(
                title: "Create PDF Report",
                systemImage: "doc.richtext"
            ) {
                showingPDFReport = true
            }

            if model.isAdmin {
                compactViolationActionButton(
                    title: "Edit Violation",
                    systemImage: "pencil"
                ) {
                    showingEdit = true
                }

                compactViolationActionButton(
                    title: "Audit History",
                    systemImage: "clock.badge.checkmark"
                ) {
                    showingAudit = true
                }

                if model.isSuperUser {
                    Button(
                        role: .destructive
                    ) {
                        showingRemoval = true
                    } label: {
                        Label(
                            "Remove Violation",
                            systemImage: "trash"
                        )
                        .lineLimit(1)
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityIdentifier(
                        "violation.action.remove"
                    )
                }
            }
        }
        .padding(16)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .background(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .fill(
                Color.secondary
                    .opacity(0.08)
            )
        )
    }

    /// Builds a two-column violation action card for narrow regular-width iPad layouts.
    private var mediumViolationActions:
        some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            Text("Actions")
                .font(.headline)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                alignment: .leading,
                spacing: 10
            ) {
                mediumViolationActionButton(
                    title: "Create PDF Report",
                    systemImage: "doc.richtext"
                ) {
                    showingPDFReport = true
                }

                if model.isAdmin {
                    mediumViolationActionButton(
                        title: "Edit Violation",
                        systemImage: "pencil"
                    ) {
                        showingEdit = true
                    }

                    mediumViolationActionButton(
                        title: "Audit History",
                        systemImage: "clock.badge.checkmark"
                    ) {
                        showingAudit = true
                    }

                    if model.isSuperUser {
                        Button(
                            role: .destructive
                        ) {
                            showingRemoval = true
                        } label: {
                            Label(
                                "Remove Violation",
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
                            "violation.action.remove"
                        )
                    }
                }
            }
        }
        .padding(16)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .background(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .fill(
                Color.secondary
                    .opacity(0.08)
            )
        )
    }

    /// Builds one secondary violation action button for the medium two-column iPad layout.
    private func mediumViolationActionButton(
        title: String,
        systemImage: String,
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
    }

    /// The non-destructive violation actions available to an administrator.
    private var regularViolationActions:
        some View {
        HStack(spacing: 12) {
            Button {
                showingPDFReport = true
            } label: {
                Label(
                    "Create PDF Report",
                    systemImage:
                        "doc.richtext"
                )
                .lineLimit(1)
            }

            if model.isAdmin {
                Button {
                    showingEdit = true
                } label: {
                    Label(
                        "Edit Violation",
                        systemImage: "pencil"
                    )
                    .lineLimit(1)
                }

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

                if model.isSuperUser {
                    Button(
                        role: .destructive
                    ) {
                        showingRemoval = true
                    } label: {
                        Label(
                            "Remove Violation",
                            systemImage: "trash"
                        )
                        .lineLimit(1)
                    }
                    .accessibilityIdentifier(
                        "violation.action.remove"
                    )
                }
            }
        }
    }

    /// Builds a full-width violation action button suitable for compact layouts.
    private func compactViolationActionButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(
            action: action
        ) {
            Label(
                title,
                systemImage:
                    systemImage
            )
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    /// Builds the summary card shown near the top of the violation detail screen.
    private func summaryCard(
        _ item: ViolationListItem
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                statusBadge(item.status)

                Spacer()

                if model.isAdmin &&
                    !isResolved(item.status) {
                    Button {
                        showingAdjudication = true
                    } label: {
                        Label(
                            adjudicationButtonTitle(item.status),
                            systemImage: "arrow.right.circle.fill"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            Text(
                item.ruleTitles.isEmpty
                    ? "Violation"
                    : item.ruleTitles
            )
            .font(.title2.weight(.semibold))
            .textSelection(.enabled)

            HStack(alignment: .top, spacing: 28) {
                if let observed = formattedDate(item.observedAt) {
                    infoBlock(
                        title: "Observed",
                        value: observed,
                        systemImage: "eye"
                    )
                }

                if let deadline = formattedDate(item.correctionDeadline) {
                    infoBlock(
                        title: "Correction Due",
                        value: deadline,
                        systemImage: "calendar.badge.exclamationmark"
                    )
                }

                if let escalation = formattedDate(item.escalationDate) {
                    infoBlock(
                        title: "Escalated",
                        value: escalation,
                        systemImage: "arrow.up.circle"
                    )
                }

                if let finalWarning = formattedDate(item.finalWarningDate) {
                    infoBlock(
                        title: "Final Warning",
                        value: finalWarning,
                        systemImage: "exclamationmark.octagon"
                    )
                }

                if let fee = formattedDate(item.feeAssessmentDate) {
                    infoBlock(
                        title: "Fee Assessment",
                        value: fee,
                        systemImage: "dollarsign.circle"
                    )
                }

                if let resolved = formattedDate(item.resolvedDate) {
                    infoBlock(
                        title: "Resolved",
                        value: resolved,
                        systemImage: "checkmark.circle"
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.quaternary)
        )
    }

    /// The governing-document section cited by this rule.
    private var ruleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(
                    "Applicable Rules",
                    systemImage: "books.vertical"
                )
                .font(.headline)

                Spacer()

                Text("\(rules.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if rules.isEmpty {
                Text("No rule text was stored with this violation.")
                    .foregroundStyle(.secondary)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardBackground()
            } else {
                ForEach(rules) { rule in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(
                                    rule.title.isEmpty
                                        ? "HOA Rule"
                                        : rule.title
                                )
                                .font(.headline)

                                if !rule.ruleSection.isEmpty {
                                    Text(rule.ruleSection)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            if !rule.category.isEmpty {
                                Text(rule.category)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(.quaternary)
                                    )
                            }
                        }

                        if !rule.ruleText.isEmpty {
                            ruleField(
                                "Full Rule Text",
                                rule.ruleText
                            )
                        }

                        if !rule.noticeText.isEmpty {
                            ruleField(
                                "Notice Text",
                                rule.noticeText
                            )
                        }

                        if !rule.correctiveAction.isEmpty {
                            ruleField(
                                "Corrective Action",
                                rule.correctiveAction
                            )
                        }
                    }
                    .padding(20)
                    .cardBackground()
                }
            }
        }
    }

    /// Builds the violation details card containing dates, status, and related metadata.
    private func detailsCard(
        _ item: ViolationListItem
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(
                "Inspector Notes",
                systemImage: "note.text"
            )
            .font(.headline)

            Text(
                item.notes.isEmpty
                    ? "No notes."
                    : item.notes
            )
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)

            if !item.adminNotes.isEmpty {
                Divider()

                Label(
                    "Administrator Notes",
                    systemImage: "person.badge.key"
                )
                .font(.headline)

                Text(item.adminNotes)
                    .textSelection(.enabled)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
            }
        }
        .padding(20)
        .cardBackground()
    }

    /// The view section that presents historical workflow actions.
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(
                "Adjudication History",
                systemImage: "clock.arrow.circlepath"
            )
            .font(.headline)

            ForEach(actions) { action in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(
                            "\(action.fromStatus.isEmpty ? "Open" : action.fromStatus) → \(action.toStatus)"
                        )
                        .font(.subheadline.weight(.semibold))

                        Spacer()

                        if let date = formattedDate(action.changedAt) {
                            Text(date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !action.notes.isEmpty {
                        Text(action.notes)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if action.id != actions.last?.id {
                    Divider()
                }
            }
        }
        .padding(20)
        .cardBackground()
    }

    /// The view section that presents photo attachments.
    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Photos")
                    .font(.headline)

                Spacer()

                if !attachments.isEmpty {
                    Text(
                        "\(attachments.count) photo" +
                        "\(attachments.count == 1 ? "" : "s")"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }

            if attachments.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.secondary)

                    Text("No imported photos")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.quaternary.opacity(0.35))
                )
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(
                            .adaptive(
                                minimum: 180,
                                maximum: 260
                            ),
                            spacing: 16
                        )
                    ],
                    alignment: .leading,
                    spacing: 16
                ) {
                    ForEach(attachments) { attachment in
                        PhotoCard(
                            attachment: attachment,
                            store: model.store
                        ) {
                            selectedPhoto = attachment
                        }
                    }
                }
            }
        }
    }

    /// Builds one labeled rule-information field for the violation detail screen.
    private func ruleField(
        _ title: String,
        _ value: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Builds the compact visual badge for a violation workflow status.
    private func statusBadge(
        _ status: String
    ) -> some View {
        Text(status.isEmpty ? "Open" : status)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(statusColor(status).opacity(0.16))
            )
            .foregroundStyle(statusColor(status))
    }

    /// Builds a labeled text block used by the violation detail cards.
    private func infoBlock(
        title: String,
        value: String,
        systemImage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline)
        }
    }

    /// Returns the semantic color associated with the current workflow status.
    private func statusColor(
        _ status: String
    ) -> Color {
        let normalized = status.lowercased()

        if normalized.contains("fee") {
            return .purple
        }

        if normalized.contains("final") {
            return .red
        }

        if normalized.contains("escalat") {
            return .orange
        }

        if normalized.contains("resolved") ||
            normalized.contains("closed") {
            return .green
        }

        return .blue
    }

    /// Returns the title for the violation adjudication action available at the current stage.
    private func adjudicationButtonTitle(
        _ status: String
    ) -> String {
        switch status.lowercased() {
        case "", "open":
            return "Advance to Escalated"
        case "escalated":
            return "Advance to Final Warning"
        case "final warning", "finalwarning":
            return "Advance to Fee Assessment"
        default:
            return "Adjudicate"
        }
    }

    /// Returns whether the supplied violation status represents a resolved record.
    private func isResolved(
        _ status: String
    ) -> Bool {
        let value = status.lowercased()
        return value == "resolved" ||
            value == "closed"
    }

    /// Formats a stored ISO-8601 timestamp for user-facing display.
    private func formattedDate(
        _ value: String?
    ) -> String? {
        guard let value,
              !value.trimmingCharacters(
                in: .whitespacesAndNewlines
              ).isEmpty
        else {
            return nil
        }

        let iso = ISO8601DateFormatter()

        if let date = iso.date(from: value) {
            return date.formatted(
                date: .abbreviated,
                time: .shortened
            )
        }

        return value
    }

    /// Permanently removes this violation after the SuperUser supplies the
    /// mandatory audit reason. Store-level authorization provides a second
    /// enforcement boundary in addition to the UI visibility check.
    private func removeViolation(
        reason: String
    ) throws {
        guard
            model.isSuperUser,
            let actor = model.currentAdmin
        else {
            throw StoreError.sql(
                "Only SHOA_ACC_SuperUser can remove violations."
            )
        }

        try model.store.removeViolation(
            id: violationID,
            reason: reason,
            actor: actor
        )

        do {
            try model.refresh()
            model.statusMessage =
                "Violation removed. The reason was recorded in the Audit Log."
        } catch {
            model.statusMessage =
                "Violation removed, but the screen could not refresh immediately: \(error.localizedDescription)"
        }

        removalCompleted = true

        Task {
            await model.refreshReminders()
        }
    }

    /// Loads  from its configured source.
    private func load() {
        do {
            item = try model.store.fetchViolation(
                violationID
            )

            attachments =
                try model.store.fetchViolationAttachments(
                    violationID: violationID
                )

            rules =
                try model.store.fetchViolationRules(
                    violationID: violationID
                )

            actions =
                try model.store.fetchViolationActions(
                    violationID: violationID
                )
        } catch {
            model.statusMessage =
                error.localizedDescription
        }
    }
}

/// Adds HOA ACC Organizer behavior to `View`.
private extension View {
    /// Returns the platform-appropriate background used by detail cards.
    func cardBackground() -> some View {
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

// MARK: - Photo Card

/// Represents photo card within HOA ACC Organizer.
private struct PhotoCard: View {
    /// The attachment record displayed or processed by this component.
    let attachment: ViolationAttachment
    /// The SQLite persistence store used by this component.
    let store: SQLiteStore
    /// The audit or workflow action recorded for this entry.
    let action: () -> Void

    /// The SwiftUI view hierarchy rendered by this view.
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                PhotoThumbnail(
                    attachment: attachment,
                    store: store
                )
                .frame(height: 150)
                .frame(maxWidth: .infinity)
                .clipShape(
                    RoundedRectangle(cornerRadius: 12)
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(
                        attachment.caption.isEmpty
                            ? "Violation photo"
                            : attachment.caption
                    )
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                    if let captured = formatCapturedDate(
                        attachment.capturedAt
                    ) {
                        Text(captured)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.thinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.quaternary)
            )
        }
        .buttonStyle(.plain)
    }

    /// Formats a photo capture timestamp for display under the attachment.
    private func formatCapturedDate(
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
                time: .shortened
            )
        }

        return value
    }
}

// MARK: - Thumbnail

/// Represents photo thumbnail within HOA ACC Organizer.
private struct PhotoThumbnail: View {
    /// The attachment record displayed or processed by this component.
    let attachment: ViolationAttachment
    /// The SQLite persistence store used by this component.
    let store: SQLiteStore

    /// The SwiftUI view hierarchy rendered by this view.
    var body: some View {
        Group {
            if let image = loadPlatformImage() {
                swiftUIImage(image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Rectangle()
                        .fill(.quaternary)

                    Image(
                        systemName: "photo.badge.exclamationmark"
                    )
                    .font(.title2)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .clipped()
    }

    /// Loads platform image from its configured source.
    private func loadPlatformImage() -> PlatformImage? {
        guard let url = try? store.attachmentURL(
            fileName: attachment.fileName
        ) else {
            return nil
        }

        return PlatformImage(
            contentsOfFile: url.path
        )
    }

    /// Converts the stored platform image into a SwiftUI `Image` for display.
    private func swiftUIImage(
        _ image: PlatformImage
    ) -> Image {
        #if os(macOS)
        return Image(nsImage: image)
        #elseif os(iOS)
        return Image(uiImage: image)
        #endif
    }
}

// MARK: - Full Photo Viewer

/// Represents photo viewer within HOA ACC Organizer.
private struct PhotoViewer: View {
    /// The SwiftUI dismissal action for closing the current presentation.
    @Environment(\.dismiss) private var dismiss

    /// The attachment record displayed or processed by this component.
    let attachment: ViolationAttachment
    /// The SQLite persistence store used by this component.
    let store: SQLiteStore

    /// The SwiftUI view hierarchy rendered by this view.
    var body: some View {
        NavigationStack {
            Group {
                if let image = loadPlatformImage() {
                    swiftUIImage(image)
                        .resizable()
                        .scaledToFit()
                        .padding()
                } else {
                    ContentUnavailableView(
                        "Photo File Not Found",
                        systemImage: "photo.badge.exclamationmark",
                        description: Text(
                            "The database contains this attachment, but the image file could not be opened."
                        )
                    )
                }
            }
            .navigationTitle(
                attachment.caption.isEmpty
                    ? "Violation Photo"
                    : attachment.caption
            )
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
            minWidth: 600,
            minHeight: 450
        )
        #endif
    }

    /// Loads platform image from its configured source.
    private func loadPlatformImage() -> PlatformImage? {
        guard let url = try? store.attachmentURL(
            fileName: attachment.fileName
        ) else {
            return nil
        }

        return PlatformImage(
            contentsOfFile: url.path
        )
    }

    /// Converts the stored platform image into a SwiftUI `Image` for display.
    private func swiftUIImage(
        _ image: PlatformImage
    ) -> Image {
        #if os(macOS)
        return Image(nsImage: image)
        #elseif os(iOS)
        return Image(uiImage: image)
        #endif
    }
}

#if os(macOS)
/// Provides a project-specific alias for `PlatformImage`.
private typealias PlatformImage = NSImage
#elseif os(iOS)
/// Provides a project-specific alias for `PlatformImage`.
private typealias PlatformImage = UIImage
#endif
