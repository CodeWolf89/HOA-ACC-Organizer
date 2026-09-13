// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import SwiftUI
import UniformTypeIdentifiers

#if os(iOS)
import UIKit
#endif

/// Provides the adaptive iPhone, iPad, and macOS navigation shell, global actions, search, import, and status presentation.
struct ContentView: View {
    /// The shared application model used to read app state and perform workflow actions.
    @EnvironmentObject var model: AppModel

    /// Defines the supported import target values used by the application.
    private enum ImportTarget {
        case violations
        case ownerJSON
        case ownerCSV
        case fullData
        case backup
    }

    /// Transient view state used to track import target while this screen is active.
    @State private var importTarget:
        ImportTarget?

    /// Transient view state used to track show importer while this screen is active.
    @State private var showImporter = false
    /// Transient view state used to track selection while this screen is active.
    @State private var selection: String?
    /// Transient view state used to track phone path while this screen is active.
    @State private var phonePath: [String] = []
    /// Transient view state used to track showing open issues while this screen is active.
    @State private var showingOpenIssues = false
    /// Transient view state used to track showing new violation while this screen is active.
    @State private var showingNewViolation = false
    /// Transient view state used to track showing login while this screen is active.
    @State private var showingLogin = false
    /// Transient view state used to track showing audit while this screen is active.
    @State private var showingAudit = false
    /// Transient view state used to track showing sync while this screen is active.
    @State private var showingSync = false
    /// Transient view state controlling presentation of the privacy and legal information sheet.
    @State private var showingPrivacyLegal = false

    /// Transient view state used to track var while this screen is active.
    @State private var
        showingBackupExporter = false

    /// Transient view state used to track var while this screen is active.
    @State private var
        backupDocument =
            BackupArchiveDocument()

    /// Transient view state used to track var while this screen is active.
    @State private var
        backupFileName =
            "HOA-ACC-Backup"

    /// The file types accepted by the current global import action.
    private var allowedImportTypes:
        [UTType] {
        switch importTarget {
        case .violations,
             .ownerJSON,
             .fullData:
            return [.json]

        case .ownerCSV:
            return [
                .commaSeparatedText,
                .plainText
            ]

        case .backup:
            return [.zip]

        case .none:
            return [.data]
        }
    }

    /// The SwiftUI view hierarchy rendered by this view.
    var body: some View {
        mainNavigation
            #if os(iOS)
            .sheet(
                isPresented:
                    $showingNewViolation
            ) {
                NewViolationEntryView(
                    initialLotID: selection
                ) { lotID in
                    navigateToLot(
                        lotID
                    )
                }
                .environmentObject(model)
            }
            #endif
            .sheet(
                isPresented:
                    $showingOpenIssues
            ) {
                OpenIssuesQueueView {
                    lotID in

                    navigateToLot(
                        lotID
                    )
                }
                .environmentObject(model)
            }
            .sheet(
                isPresented:
                    $showingLogin
            ) {
                AdminLoginView()
                    .environmentObject(model)
            }
            .sheet(
                isPresented:
                    $showingAudit
            ) {
                AuditLogView()
                    .environmentObject(model)
            }
            .sheet(
                isPresented:
                    $showingSync
            ) {
                SyncCenterView()
                    .environmentObject(model)
            }
            .sheet(
                isPresented:
                    $showingPrivacyLegal
            ) {
                PrivacyLegalView()
            }
            .fileImporter(
                isPresented:
                    $showImporter,
                allowedContentTypes:
                    allowedImportTypes,
                allowsMultipleSelection:
                    false
            ) { result in
                handleImportSelection(
                    result
                )
            }
            .fileExporter(
                isPresented:
                    $showingBackupExporter,
                document:
                    backupDocument,
                contentType: .zip,
                defaultFilename:
                    backupFileName
            ) { result in
                switch result {
                case .success(let url):
                    do {
                        let count =
                            try model.store
                                .allAttachmentTransferInfo()
                                .count

                        try model.store
                            .recordBackup(
                                fileName:
                                    url.lastPathComponent,
                                attachmentCount:
                                    count
                            )

                        model.statusMessage =
                            "Full backup saved."
                    } catch {
                        model.statusMessage =
                            "Backup saved, but history could not be recorded: \(error.localizedDescription)"
                    }

                case .failure(let error):
                    model.statusMessage =
                        "Backup failed: \(error.localizedDescription)"
                }
            }
            .safeAreaInset(
                edge: .bottom
            ) {
                if model.isImporting ||
                    !model.statusMessage
                        .isEmpty {
                    statusBar
                }
            }
    }

    /// The adaptive root navigation selected for the current device class.
    @ViewBuilder
    private var mainNavigation:
        some View {
        #if os(iOS)
        if UIDevice.current
            .userInterfaceIdiom == .phone {
            phoneNavigation
        } else {
            splitNavigation
        }
        #else
        splitNavigation
        #endif
    }

    /// The iPad/macOS split-navigation layout.
    private var splitNavigation:
        some View {
        NavigationSplitView {
            List(
                selection:
                    $selection
            ) {
                summarySection

                Section("Lots") {
                    ForEach(
                        model.lots
                    ) { lot in
                        LotRow(
                            lot: lot
                        )
                        .tag(lot.id)
                    }
                }
            }
            .navigationTitle(
                "HOA ACC Organizer"
            )
            .searchable(
                text:
                    $model.searchText,
                prompt:
                    "Lot, owner, address, phone, or email"
            )
            .onChange(
                of: model.searchText
            ) { _, _ in
                model.searchChanged()
            }

        } detail: {
            NavigationStack {
                if let selection {
                    LotDetailView(
                        lotID: selection
                    )
                    .id(selection)
                } else {
                    ContentUnavailableView(
                        "Select a Lot",
                        systemImage: "house"
                    )
                }
            }
            #if os(iOS)
            .toolbar {
                appToolbar
            }
            #endif
        }
        #if os(macOS)
        .toolbar {
            appToolbar
        }
        #endif
    }

    #if os(iOS)
    /// The compact single-column iPhone navigation layout.
    private var phoneNavigation:
        some View {
        NavigationStack(
            path:
                $phonePath
        ) {
            List {
                summarySection

                Section("Lots") {
                    ForEach(
                        model.lots
                    ) { lot in
                        NavigationLink(
                            value: lot.id
                        ) {
                            LotRow(
                                lot: lot
                            )
                        }
                        .accessibilityIdentifier(
                            "lot.row.\(lot.lotNumber)"
                        )
                    }
                }
            }
            .accessibilityIdentifier(
                "main.lotList"
            )
            .navigationTitle(
                "HOA ACC Organizer"
            )
            .toolbar {
                phoneToolbar
            }
            .navigationDestination(
                for: String.self
            ) { lotID in
                LotDetailView(
                    lotID: lotID
                )
                .toolbar {
                    phoneToolbar
                }
            }
            .searchable(
                text:
                    $model.searchText,
                placement:
                    .navigationBarDrawer(
                        displayMode:
                            .always
                    ),
                prompt:
                    "Lot, owner, address, phone, or email"
            )
            .onChange(
                of: model.searchText
            ) { _, _ in
                model.searchChanged()
            }
        }
        .onChange(
            of: phonePath
        ) { _, path in
            selection =
                path.last
        }
    }
    #endif

    /// The dashboard summary section displayed above the lot list.
    @ViewBuilder
    private var summarySection:
        some View {
        Section("Summary") {
            HStack(spacing: 18) {
                SummaryMetric(
                    title:
                        "Active Violations",
                    value:
                        model
                            .dashboardSummary
                            .propertiesWithActiveViolations,
                    systemImage:
                        "exclamationmark.triangle"
                )

                SummaryMetric(
                    title:
                        "Active ACC",
                    value:
                        model
                            .dashboardSummary
                            .activeACCApplications,
                    systemImage:
                        "doc.text.magnifyingglass"
                )
            }
            .padding(.vertical, 4)

            Button {
                showingSync = true
            } label: {
                HStack {
                    Image(
                        systemName:
                            "arrow.triangle.2.circlepath"
                    )

                    VStack(
                        alignment: .leading,
                        spacing: 2
                    ) {
                        Text("Last Sync")
                            .font(.caption)

                        Text(
                            lastSyncText
                        )
                        .font(.subheadline)
                        .foregroundStyle(
                            lastSyncColor
                        )
                    }

                    Spacer()

                    Image(
                        systemName:
                            "chevron.right"
                    )
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    /// The shared iPad/macOS toolbar content.
    @ToolbarContentBuilder
    private var appToolbar:
        some ToolbarContent {
        #if os(iOS)
        ToolbarItemGroup(
            placement:
                .topBarTrailing
        ) {
            primaryToolbarButtons
        }

        ToolbarItem(
            placement:
                .topBarTrailing
        ) {
            adminToolbarControl
        }
        #else
        ToolbarItemGroup {
            primaryToolbarButtons
        }

        ToolbarItem(
            placement:
                .primaryAction
        ) {
            adminToolbarControl
        }
        #endif
    }

    #if os(iOS)
    /// The compact iPhone toolbar containing New Violation, Actions, and account controls.
    @ToolbarContentBuilder
    private var phoneToolbar:
        some ToolbarContent {
        ToolbarItem(
            placement:
                .topBarTrailing
        ) {
            Button {
                showingNewViolation =
                    true
            } label: {
                Label(
                    "New Violation",
                    systemImage:
                        "plus.circle.fill"
                )
            }
            .accessibilityHint(
                "Create a new HOA violation report"
            )
            .accessibilityIdentifier(
                "toolbar.newViolation"
            )
        }

        ToolbarItem(
            placement:
                .topBarTrailing
        ) {
            Menu {
                Button {
                    showingOpenIssues =
                        true
                } label: {
                    Label(
                        "Open Issues",
                        systemImage:
                            "list.bullet.rectangle"
                    )
                }

                Button {
                    showingSync =
                        true
                } label: {
                    Label(
                        "Data Sync",
                        systemImage:
                            "arrow.triangle.2.circlepath"
                    )
                }

                Divider()

                Menu {
                    importMenuItems
                } label: {
                    Label(
                        "Import Data",
                        systemImage:
                            "square.and.arrow.down"
                    )
                }

                if model.isAdmin {
                    Button {
                        prepareBackup()
                    } label: {
                        Label(
                            "Full Backup",
                            systemImage:
                                "externaldrive.badge.plus"
                        )
                    }
                }

                Divider()

                Button {
                    showingPrivacyLegal = true
                } label: {
                    Label(
                        "Privacy & Legal",
                        systemImage: "hand.raised.circle"
                    )
                }
            } label: {
                Label(
                    "Actions",
                    systemImage:
                        "ellipsis.circle"
                )
            }
            .accessibilityIdentifier(
                "toolbar.actions"
            )
        }

        ToolbarItem(
            placement:
                .topBarTrailing
        ) {
            adminToolbarControl
        }
    }
    #endif

    /// The reusable primary action buttons shown in wide layouts.
    @ViewBuilder
    private var primaryToolbarButtons:
        some View {
        #if os(iOS)
        Button {
            showingNewViolation = true
        } label: {
            Label(
                "New Violation",
                systemImage:
                    "plus.circle.fill"
            )
        }
        .accessibilityHint(
            "Create a new HOA violation report"
        )
        .accessibilityIdentifier(
            "toolbar.newViolation"
        )
        #endif

        Button {
            showingOpenIssues = true
        } label: {
            Label(
                "Open Issues",
                systemImage:
                    "list.bullet.rectangle"
            )
        }
        .accessibilityIdentifier(
            "toolbar.openIssues"
        )

        Button {
            showingSync = true
        } label: {
            Label(
                "Sync",
                systemImage:
                    "arrow.triangle.2.circlepath"
            )
        }
        .accessibilityIdentifier(
            "toolbar.sync"
        )

        Button {
            showingPrivacyLegal = true
        } label: {
            Label(
                "Privacy & Legal",
                systemImage: "hand.raised.circle"
            )
        }
        .accessibilityIdentifier(
            "toolbar.privacyLegal"
        )

        Menu {
            importMenuItems
        } label: {
            Label(
                "Import",
                systemImage:
                    "square.and.arrow.down"
            )
        }

        if model.isAdmin {
            Button {
                prepareBackup()
            } label: {
                Label(
                    "Full Backup",
                    systemImage:
                        "externaldrive.badge.plus"
                )
            }
        }
    }

    /// The import commands available to the current authorization level.
    @ViewBuilder
    private var importMenuItems:
        some View {
        Button(
            "Import Violation JSON…"
        ) {
            importTarget =
                .violations
            showImporter = true
        }

        Button(
            "Import Full HOA ACC JSON…"
        ) {
            importTarget =
                .fullData
            showImporter = true
        }

        if model.isAdmin {
            Divider()

            Button(
                "Restore Full Backup…"
            ) {
                importTarget =
                    .backup
                showImporter = true
            }

            Divider()

            Button(
                "Import SHOA owner JSON…"
            ) {
                importTarget =
                    .ownerJSON
                showImporter = true
            }

            Button(
                "Import homeowner CSV…"
            ) {
                importTarget =
                    .ownerCSV
                showImporter = true
            }
        }
    }

    /// The account/login menu appropriate for the current authentication state.
    @ViewBuilder
    private var adminToolbarControl:
        some View {
        if let user =
            model.currentUser {
            Menu {
                Text(
                    "Signed in as \(user.displayName)"
                )

                if user.isAdministrator {
                    Button(
                        "Audit Log…"
                    ) {
                        showingAudit = true
                    }

                    Divider()
                }

                Button(
                    "Log Out"
                ) {
                    model
                        .logoutAccount()
                }
            } label: {
                Label(
                    user.isAdministrator
                    ? "Admin"
                    : "Account",
                    systemImage:
                        user.isAdministrator
                        ? "person.badge.key.fill"
                        : "person.crop.circle.badge.checkmark"
                )
            }
            .accessibilityIdentifier(
                user.isAdministrator
                ? "toolbar.admin"
                : "toolbar.account"
            )
        } else {
            Button {
                showingLogin = true
            } label: {
                Label(
                    "Login",
                    systemImage:
                        "person.badge.key"
                )
            }
            .accessibilityIdentifier(
                "toolbar.adminLogin"
            )
        }
    }

    /// The adaptive bottom status presentation for imports, sync state, and authentication.
    @ViewBuilder
    private var statusBar:
        some View {
        #if os(iOS)
        if UIDevice.current
            .userInterfaceIdiom == .phone {
            phoneStatusBar
        } else {
            regularStatusBar
        }
        #else
        regularStatusBar
        #endif
    }

    /// The iPad/macOS-style bottom status bar.
    private var regularStatusBar:
        some View {
        HStack {
            if model.isImporting {
                ProgressView()
            }

            Text(
                model.statusMessage
            )
            .font(.caption)

            Spacer()

            Text(
                model.sync
                    .syncStatus
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            if let user =
                model.currentUser {
                Text(
                    user.isAdministrator
                    ? "Admin: \(user.displayName)"
                    : "User: \(user.displayName)"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                #if os(iOS)
                Label(
                    "Standard User",
                    systemImage:
                        "person"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                #else
                Label(
                    "Read Only",
                    systemImage:
                        "eye"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                #endif
            }
        }
        .padding(8)
        .background(.bar)
    }

    #if os(iOS)
    /// The compact iPhone status bar.
    private var phoneStatusBar:
        some View {
        VStack(
            alignment: .leading,
            spacing: 3
        ) {
            HStack(
                alignment: .top,
                spacing: 8
            ) {
                if model.isImporting {
                    ProgressView()
                        .controlSize(.small)
                }

                Text(
                    model.statusMessage
                )
                .font(.caption)
                .lineLimit(2)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )

                Spacer(
                    minLength: 8
                )

                Image(
                    systemName:
                        model.isAdmin
                        ? "person.badge.key.fill"
                        : model.isSignedIn
                        ? "person.crop.circle.badge.checkmark"
                        : "person"
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
            }

            Text(
                model.sync
                    .syncStatus
            )
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .padding(
            .horizontal,
            12
        )
        .padding(
            .vertical,
            7
        )
        .background(.bar)
    }
    #endif

    /// The formatted last-successful-sync text displayed to the user.
    private var lastSyncText:
        String {
        guard
            let value =
                model.syncState
                    .lastSuccessfulSyncAt,
            let date =
                ISODateStorage.date(
                    from: value
                )
        else {
            return "Never"
        }

        return date.formatted(
            date: .abbreviated,
            time: .omitted
        )
    }

    /// The semantic color used to emphasize stale or missing sync state.
    private var lastSyncColor:
        Color {
        guard
            let value =
                model.syncState
                    .lastSuccessfulSyncAt,
            let date =
                ISODateStorage.date(
                    from: value
                )
        else {
            return .red
        }

        let days =
            Date()
                .timeIntervalSince(date)
            / (24 * 60 * 60)

        if days >= 14 {
            return .red
        }

        if days >= 7 {
            return .orange
        }

        return .primary
    }

    /// Selects the requested lot using the navigation model appropriate for the current device.
    private func navigateToLot(
        _ lotID: String
    ) {
        selection = lotID

        #if os(iOS)
        if UIDevice.current
            .userInterfaceIdiom == .phone {
            phonePath =
                [lotID]
        }
        #endif
    }

    /// Handles import selection for `ContentView`.
    private func handleImportSelection(
        _ result:
            Result<[URL], Error>
    ) {
        let target =
            importTarget

        importTarget = nil

        switch result {
        case .success(let urls):
            guard
                let url =
                    urls.first,
                let target
            else {
                model.statusMessage =
                    "No file was selected."
                return
            }

            Task {
                switch target {
                case .violations:
                    await model
                        .importViolationJSON(
                            url
                        )

                case .fullData:
                    await model
                        .importFullDataJSON(
                            url
                        )

                case .backup:
                    guard model.isAdmin else {
                        model.statusMessage =
                            "Administrator login is required to restore a full backup."
                        return
                    }

                    await model
                        .restoreBackup(
                            url
                        )

                case .ownerJSON:
                    guard model.isAdmin else {
                        model.statusMessage =
                            "Administrator login is required to import owner master data."
                        return
                    }

                    await model
                        .importOwnerJSON(
                            url
                        )

                case .ownerCSV:
                    guard model.isAdmin else {
                        model.statusMessage =
                            "Administrator login is required to import owner master data."
                        return
                    }

                    await model
                        .importHomeownerCSV(
                            url
                        )
                }
            }

        case .failure(let error):
            model.statusMessage =
                "File selection failed: \(error.localizedDescription)"
        }
    }

    /// Prepares backup for `ContentView`.
    private func prepareBackup() {
        guard model.isAdmin else {
            model.statusMessage =
                "Administrator login is required to create a full backup."
            return
        }

        do {
            let service =
                BackupService(
                    store: model.store
                )

            backupDocument =
                BackupArchiveDocument(
                    data:
                        try service
                            .createBackupData()
                )

            let formatter =
                DateFormatter()

            formatter.dateFormat =
                "yyyyMMdd-HHmmss"

            backupFileName =
                "HOA-ACC-Backup-\(formatter.string(from: Date())).zip"

            showingBackupExporter =
                true
        } catch {
            model.statusMessage =
                "Unable to prepare backup: \(error.localizedDescription)"
        }
    }
}

/// Renders a property summary row in the main lot list.
struct LotRow: View {
    /// The lot record displayed or processed by this component.
    let lot: LotSummary

    /// The SwiftUI view hierarchy rendered by this view.
    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 5
        ) {
            HStack {
                Text(
                    "Lot \(lot.lotNumber)"
                )
                .font(.headline)

                Spacer()

                if lot.openViolations > 0 {
                    Label(
                        "\(lot.openViolations)",
                        systemImage:
                            "exclamationmark.triangle.fill"
                    )
                    .font(
                        .caption.weight(.semibold)
                    )
                    .foregroundStyle(.orange)
                }

                if lot.activeACCApplications > 0 {
                    Label(
                        "\(lot.activeACCApplications)",
                        systemImage:
                            "doc.text.magnifyingglass"
                    )
                    .font(
                        .caption.weight(.semibold)
                    )
                    .foregroundStyle(.blue)
                }
            }

            if !lot.ownerName.isEmpty {
                Text(lot.ownerName)
                    .font(.subheadline)
            }

            Text(lot.primaryAddress)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Text(
                    "\(lot.previousViolations) previous violation" +
                    "\(lot.previousViolations == 1 ? "" : "s")"
                )

                if lot
                    .activeACCApplications > 0 {
                    Text(
                        "\(lot.activeACCApplications) ACC under review"
                    )
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }
}

/// Represents summary metric within HOA ACC Organizer.
private struct SummaryMetric: View {
    /// The human-readable title displayed for this value.
    let title: String
    /// The value displayed by this reusable status/summary row.
    let value: Int
    /// The SF Symbol name displayed by this summary metric.
    let systemImage: String

    /// The SwiftUI view hierarchy rendered by this view.
    var body: some View {
        HStack(spacing: 8) {
            Image(
                systemName: systemImage
            )
            .foregroundStyle(.secondary)

            VStack(
                alignment: .leading,
                spacing: 1
            ) {
                Text("\(value)")
                    .font(.headline)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
    }
}
