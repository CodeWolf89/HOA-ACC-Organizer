// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import Foundation
import SwiftUI
import Combine
import LocalAuthentication

/// Coordinates persistent storage, imports, authentication, reminders, nearby sync, and view-facing application state.
@MainActor
final class AppModel: ObservableObject {
    /// Publishes lots so observing views can react when it changes.
    @Published var lots: [LotSummary] = []
    /// Publishes selected lot id so observing views can react when it changes.
    @Published var selectedLotID: String?
    /// Publishes search text so observing views can react when it changes.
    @Published var searchText = ""
    /// Publishes is importing so observing views can react when it changes.
    @Published var isImporting = false
    /// Publishes status message so observing views can react when it changes.
    @Published var statusMessage = ""
    /// Publishes import batches so observing views can react when it changes.
    @Published var importBatches: [ImportBatchSummary] = []
    /// Publishes dashboard summary so observing views can react when it changes.
    @Published var dashboardSummary = DashboardSummary(
        propertiesWithActiveViolations: 0,
        activeACCApplications: 0
    )

    /// Increments whenever persistent HOA content is refreshed.
    ///
    /// Detail screens observe this value so they can reload local view state
    /// after a save, import, or nearby sync changes the underlying database.
    @Published private(set) var contentRevision: UInt64 = 0
    /// Publishes current user so observing views can react when it changes.
    @Published var currentUser: AuthenticatedUser?
    /// Publishes current admin so observing views can react when it changes.
    @Published var currentAdmin: AuthenticatedAdmin?
    /// Publishes has administrator users so observing views can react when it changes.
    @Published var hasAdministratorUsers = false
    /// Publishes biometric login available so observing views can react when it changes.
    @Published var biometricLoginAvailable = false
    /// Publishes sync state so observing views can react when it changes.
    @Published var syncState =
        SyncStateSnapshot(
            lastSuccessfulSyncAt: nil,
            lastSyncMethod: "",
            lastPeerName: ""
        )
    /// Publishes automatic sync enabled so observing views can react when it changes.
    @Published var automaticSyncEnabled =
        UserDefaults.standard.object(
            forKey:
                "hoaacc.automaticSyncEnabled"
        ) as? Bool
        ?? true
    /// Publishes sync cadence so observing views can react when it changes.
    @Published var syncCadence =
        SyncCadence(
            rawValue:
                UserDefaults.standard.string(
                    forKey:
                        "hoaacc.syncCadence"
                )
                ?? ""
        )
        ?? .weekly

    /// Indicates whether is admin.
    var isAdmin: Bool {
        currentUser?.isAdministrator == true ||
        currentAdmin != nil
    }

    /// Returns whether any provisioned account is currently authenticated.
    var isSignedIn: Bool {
        currentUser != nil
    }

    /// Returns whether the currently authenticated administrator is the one
    /// provisioned SuperUser account authorized to permanently remove records.
    var isSuperUser: Bool {
        let username =
            currentUser?.username ??
            currentAdmin?.username

        return username?
            .caseInsensitiveCompare(
                "SHOA_ACC_SuperUser"
            ) == .orderedSame
    }

    /// The SQLite persistence store used by this component.
    let store = SQLiteStore()
    /// The importer used to process incoming data for this workflow.
    lazy var importer = ViolationImporter(store: store)
    /// The CSV owner-data importer sharing the application’s persistent store.
    lazy var homeownerImporter = HomeownerCSVImporter(store: store)
    /// The JSON owner-master importer sharing the application’s persistent store.
    lazy var ownerJSONImporter = OwnerJSONImporter(store: store)
    /// The nearby Network.framework synchronization service owned by the application model.
    lazy var sync = NetworkSyncService(store: store)
    /// The receiver for compatible companion violation-feed transfers.
    lazy var violationFeedReceiver = ViolationFeedReceiverService(importer: importer)
    /// The local-notification scheduler for violation, ACC, and sync-staleness reminders.
    lazy var reminders = ReminderScheduler(store: store)

    /// Indicates that application startup is currently executing and duplicate startup calls should be ignored.
    private var startupInProgress = false
    /// Indicates whether has started.
    private var hasStarted = false

    /// Starts the service and begins the associated workflow.
    func start() async {
        guard
            !hasStarted,
            !startupInProgress
        else {
            return
        }

        startupInProgress = true
        #if DEBUG
        RuntimeDiagnostics.checkpoint(
            "startup.begin"
        )
        #else
        RuntimeDiagnostics.checkpoint(
            "Network Started"
        )
        #endif

        defer {
            startupInProgress = false
        }

        do {
            #if DEBUG
            RuntimeDiagnostics.checkpoint(
                "startup.database.open"
            )
            #else
            RuntimeDiagnostics.checkpoint(
                "Database Initializing"
            )
            #endif
            try store.open()
            #if DEBUG
            RuntimeDiagnostics.checkpoint(
                "startup.owner.bootstrap"
            )
            #else
            RuntimeDiagnostics.checkpoint(
                "Database Online"
            )
            #endif
            if let result =
                try ownerJSONImporter
                    .importBundledOwnerDataIfAvailable() {
                statusMessage =
                    "Owner data loaded: \(result.inserted) new lot(s), " +
                    "\(result.updated) updated."

                if result.addressMismatches > 0 {
                    statusMessage +=
                        " \(result.addressMismatches) address difference(s) should be reviewed."
                }
            }
            
            #if DEBUG

            RuntimeDiagnostics.checkpoint(
                "startup.refresh"
            )
            #else
            RuntimeDiagnostics.checkpoint(
                ""
            )
            #endif
            try refresh()
            #if DEBUG
            RuntimeDiagnostics.checkpoint(
                "startup.admin.bootstrap"
            )
            #else
            RuntimeDiagnostics.checkpoint(
                "Refreshing Database... Please Wait"
            )
            #endif
            try store
                .bootstrapProvisionedAccounts()

            #if DEBUG
            try configureUITestAuthenticationIfRequested()
            #endif

            hasAdministratorUsers =
                try store
                    .hasActiveAdministrators()

            biometricLoginAvailable =
                canUseBiometrics()

            sync.configureAutomaticSync(
                enabled:
                    automaticSyncEnabled,
                cadence:
                    syncCadence
            )

            sync.onSyncCompleted = {
                [weak self] in

                Task { @MainActor in
                    guard let self else {
                        return
                    }

                    try? self.refresh()
                    try? self.refreshSyncState()

                    await self.reminders
                        .rescheduleAll()

                    await self.reminders
                        .rescheduleSyncStalenessReminder(
                            lastSuccessfulSyncAt:
                                self.syncState
                                    .lastSuccessfulSyncAt
                        )
                }
            }

            violationFeedReceiver.onImportCompleted = {
                [weak self] result in

                Task { @MainActor in
                    guard let self else {
                        return
                    }

                    self.statusMessage =
                        "Violation App sync: \(result.inserted) new, " +
                        "\(result.updated) updated, " +
                        "\(result.duplicates) unchanged."

                    // Keep Violation-app intake separate from the existing
                    // Organizer-to-Organizer sync timestamp/cadence.
                    try? self.refresh()

                    await self.reminders.rescheduleAll()
                }
            }

            RuntimeDiagnostics.checkpoint(
                "startup.sync.state"
            )
            try refreshSyncState()

            // Complete the local-data startup path before opening network
            // listeners. This prevents an immediately discovered peer from
            // starting database/JSON work during the critical launch path.
            RuntimeDiagnostics.checkpoint(
                "startup.reminders"
            )
            await reminders.requestAuthorization()
            await reminders.rescheduleAll()
            await reminders
                .rescheduleSyncStalenessReminder(
                    lastSuccessfulSyncAt:
                        syncState
                            .lastSuccessfulSyncAt
                )

            hasStarted = true

            RuntimeDiagnostics.checkpoint(
                "startup.network.start"
            )
            sync.start()
            violationFeedReceiver.start()
            
            RuntimeDiagnostics.checkpoint(
                "startup.complete"
            )
        } catch {
            #if DEBUG
            RuntimeDiagnostics.checkpoint(
                "startup.error"
            )
            #endif
            statusMessage =
                "Database error: \(error.localizedDescription)"
        }
    }

    /// Handles foreground activation by refreshing data and restarting time-sensitive services as needed.
    func appDidBecomeActive() {
        guard hasStarted else {
            return
        }

        RuntimeDiagnostics.checkpoint(
            "scene.active"
        )
        sync.start()
        violationFeedReceiver.start()
    }

    /// Handles background transition by persisting or suspending services that should not continue actively.
    func appDidEnterBackground() {
        guard hasStarted else {
            return
        }
        #if DEBUG
        RuntimeDiagnostics.checkpoint(
            "scene.background"
        )
        #else
        RuntimeDiagnostics.checkpoint("App is in Background")
        #endif
        sync.stop()
        violationFeedReceiver.stop()
    }

    #if DEBUG
    /// Authenticates a provisioned administrator when UI tests request a deterministic session.
    ///
    /// The hook exists only in Debug builds and does not contain or bypass a password.
    /// `--uitest-admin` uses the Apple review administrator, while
    /// `--uitest-superuser` uses the SuperUser for destructive-cleanup UI tests.
    private func configureUITestAuthenticationIfRequested() throws {
        let arguments =
            ProcessInfo.processInfo.arguments

        let requestedUsername: String

        if arguments.contains(
            "--uitest-superuser"
        ) {
            requestedUsername =
                "SHOA_ACC_SuperUser"
        } else if arguments.contains(
            "--uitest-admin"
        ) {
            requestedUsername =
                "Apple_ReviewAccount"
        } else {
            return
        }

        guard let account =
            try store.fetchUser(
                username:
                    requestedUsername
            ),
            account.account.isActive
        else {
            return
        }

        let authenticated =
            AuthenticatedUser(
                id:
                    account.account.id,
                username:
                    account.account.username,
                displayName:
                    account.account.displayName,
                role:
                    account.account.role
            )

        currentUser =
            authenticated

        if authenticated.isAdministrator {
            currentAdmin =
                AuthenticatedAdmin(
                    id:
                        authenticated.id,
                    username:
                        authenticated.username,
                    displayName:
                        authenticated.displayName
                )
        }
    }
    #endif

    /// Refreshes application state from persistent data.
    func refresh() throws {
        lots = try store.fetchLotSummaries(search: searchText)
        importBatches = try store.fetchImportBatches()
        dashboardSummary = try store.fetchDashboardSummary()

        // Signal any currently visible detail screen to re-read its local
        // database-backed state. This is especially important on iPad where
        // the selected lot remains visible behind modal creation workflows.
        contentRevision &+= 1
    }

    /// Refreshes reminders from persistent data.
    func refreshReminders() async {
        await reminders.rescheduleAll()
    }

    /// Refreshes the lot list using the current search text.
    func searchChanged() {
        do {
            try refresh()
        } catch {
            statusMessage = error.localizedDescription
        }
    }


    /// Refreshes sync state from persistent data.
    func refreshSyncState() throws {
        syncState =
            try store.fetchSyncState()
    }

    /// Starts an immediate nearby synchronization attempt with an available peer.
    func syncNow() {
        sync.syncNow()
    }

    /// Persists the automatic-sync preference and applies it to the sync service.
    func setAutomaticSyncEnabled(
        _ enabled: Bool
    ) {
        automaticSyncEnabled =
            enabled

        UserDefaults.standard.set(
            enabled,
            forKey:
                "hoaacc.automaticSyncEnabled"
        )

        sync.configureAutomaticSync(
            enabled: enabled,
            cadence: syncCadence
        )
    }

    /// Persists the selected sync cadence and applies it to the sync service.
    func setSyncCadence(
        _ cadence: SyncCadence
    ) {
        syncCadence =
            cadence

        UserDefaults.standard.set(
            cadence.rawValue,
            forKey:
                "hoaacc.syncCadence"
        )

        sync.configureAutomaticSync(
            enabled:
                automaticSyncEnabled,
            cadence:
                cadence
        )
    }

    /// Creates violation and returns the resulting value when applicable.
    @discardableResult
    func createViolation(
        _ draft: ViolationCreationDraft
    ) async throws -> String {
        let violationID =
            try store.createViolation(
                draft
            )

        try refresh()
        await reminders.rescheduleAll()

        statusMessage =
            "Violation saved for the selected property."

        return violationID
    }

    /// Restores structured records and attachment files from a validated HOA ACC backup archive.
    func restoreBackup(
        _ url: URL
    ) async {
        isImporting = true
        statusMessage =
            "Restoring HOA ACC backup…"

        defer {
            isImporting = false
        }

        do {
            let service =
                BackupService(
                    store: store
                )

            let count =
                try service
                    .restoreBackup(
                        from: url
                    )

            try refresh()
            try refreshSyncState()

            await reminders
                .rescheduleAll()

            await reminders
                .rescheduleSyncStalenessReminder(
                    lastSuccessfulSyncAt:
                        syncState
                            .lastSuccessfulSyncAt
                )

            statusMessage =
                "Backup restored for \(count) properties."
        } catch {
            #if DEBUG
            statusMessage = "Backup restore failed: \(error.localizedDescription)"
            #else
            statusMessage = "Restore from Backup Failed."
            #endif
        }
    }

    /// Authenticates any provisioned application account and applies its role.
    func loginAccount(
        username: String,
        password: String
    ) throws {
        let cleanUsername =
            username.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard
            let credential =
                ProvisionedAccounts
                    .authenticate(
                        username:
                            cleanUsername,
                        password:
                            password
                    )
        else {
            throw StoreError.sql(
                "Invalid username or password."
            )
        }

        // The compiled provisioned verifier is the authentication source of
        // truth. SQLite is repaired only after successful authentication.
        try store
            .repairProvisionedAccount(
                credential
            )

        guard
            let record =
                try store.fetchUser(
                    username:
                        credential.username
                ),
            record.account.isActive
        else {
            throw StoreError.sql(
                "Authentication succeeded, but the local account could not be accessed."
            )
        }

        let user =
            AuthenticatedUser(
                id:
                    record.account.id,
                username:
                    record.account.username,
                displayName:
                    record.account.displayName,
                role:
                    record.account.role
            )

        currentUser =
            user

        if user.isAdministrator {
            currentAdmin =
                AuthenticatedAdmin(
                    id:
                        user.id,
                    username:
                        user.username,
                    displayName:
                        user.displayName
                )
        } else {
            currentAdmin =
                nil
        }

        try store.markLogin(
            userID: user.id
        )

        if biometricLoginAvailable {
            try? BiometricKeychain
                .saveUserID(
                    user.id
                )
        }

        statusMessage =
            user.isAdministrator
            ? "Administrator signed in."
            : "Signed in as \(user.displayName)."
    }

    /// Authenticates a provisioned administrator.
    ///
    /// This compatibility API remains available for existing tests and call
    /// sites that explicitly require administrator privileges.
    func loginAdministrator(
        username: String,
        password: String
    ) throws {
        try loginAccount(
            username: username,
            password: password
        )

        guard isAdmin else {
            logoutAccount()

            throw StoreError.sql(
                "This account does not have administrator access."
            )
        }
    }

    /// Unlocks the previously authenticated account with Face ID or Touch ID.
    func loginWithBiometrics() async throws {
        let context = LAContext()

        var error: NSError?

        guard context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        ) else {
            throw error ??
                StoreError.sql(
                    "Biometric authentication is not available."
                )
        }

        let success =
            try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason:
                    "Unlock your HOA ACC Organizer account."
            )

        guard success else {
            return
        }

        guard
            let userID =
                try BiometricKeychain.readUserID(
                    context: context
                ),
            let account =
                try store.fetchUser(
                    id: userID
                ),
            account.isActive
        else {
            BiometricKeychain.delete()

            throw StoreError.sql(
                "The saved biometric account is no longer active. Please sign in using the username and password."
            )
        }

        let user =
            AuthenticatedUser(
                id:
                    account.id,
                username:
                    account.username,
                displayName:
                    account.displayName,
                role:
                    account.role
            )

        currentUser =
            user

        if user.isAdministrator {
            currentAdmin =
                AuthenticatedAdmin(
                    id:
                        user.id,
                    username:
                        user.username,
                    displayName:
                        user.displayName
                )
        } else {
            currentAdmin =
                nil
        }

        try store.markLogin(
            userID: account.id
        )
    }

    /// Ends the current authenticated account session.
    func logoutAccount() {
        currentUser = nil
        currentAdmin = nil
    }

    /// Backward-compatible administrator logout API.
    func logoutAdministrator() {
        logoutAccount()
    }

    /// Replaces the persisted password verifier for an existing administrator account.
    func resetAdministratorPassword(
        userID: String,
        password: String
    ) throws {
        guard let actor = currentAdmin else {
            throw StoreError.sql(
                "Administrator login is required."
            )
        }

        let verifier =
            try PasswordHasher.makeVerifier(
                password: password
            )

        try store.resetAdministratorPassword(
            userID: userID,
            passwordHash: verifier.hash,
            passwordSalt: verifier.salt,
            iterations: verifier.iterations,
            actor: actor
        )
    }

    /// Activates or deactivates an administrator account in the local database.
    func setAdministratorActive(
        userID: String,
        isActive: Bool
    ) throws {
        guard let actor = currentAdmin else {
            throw StoreError.sql(
                "Administrator login is required."
            )
        }

        if userID == actor.id && !isActive {
            throw StoreError.sql(
                "You cannot deactivate the administrator account currently in use."
            )
        }

        try store.setAdministratorActive(
            userID: userID,
            isActive: isActive,
            actor: actor
        )
    }

    /// Returns whether Face ID or Touch ID is currently available for account unlock.
    private func canUseBiometrics() -> Bool {
        let context = LAContext()
        var error: NSError?

        return context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        )
    }

    /// Imports violation json and validates it before persistence.
    func importViolationJSON(_ url: URL) async {

        isImporting = true
        defer { isImporting = false }

        do {
            let result = try importer.importFile(url)
            statusMessage =
                "Imported \(result.inserted) new violation(s); " +
                "\(result.updated) updated; \(result.duplicates) unchanged."
            try store.recordSuccessfulSync(
                method: "violationImport"
            )

            try refresh()
            try refreshSyncState()

            await reminders.rescheduleAll()
            await reminders
                .rescheduleSyncStalenessReminder(
                    lastSuccessfulSyncAt:
                        syncState
                            .lastSuccessfulSyncAt
                )
        } catch {
            statusMessage =
                "Violation import failed: \(error.localizedDescription)"
        }
    }


    /// Imports full data json and validates it before persistence.
    func importFullDataJSON(
        _ url: URL
    ) async {
        isImporting = true
        statusMessage =
            "Importing HOA ACC full-data export…"

        defer {
            isImporting = false
        }

        do {
            let service =
                FullDataTransferService(
                    store: store
                )

            let count =
                try service.importJSON(
                    from: url
                )

            try store.recordSuccessfulSync(
                method: "fullDataImport"
            )

            try refresh()
            try refreshSyncState()

            await reminders.rescheduleAll()
            await reminders
                .rescheduleSyncStalenessReminder(
                    lastSuccessfulSyncAt:
                        syncState
                            .lastSuccessfulSyncAt
                )

            statusMessage =
                "Imported full HOA ACC data for \(count) properties."
        } catch {
            statusMessage =
                "Full-data import failed: \(error.localizedDescription)"
        }
    }

    /// Imports owner json and validates it before persistence.
    func importOwnerJSON(_ url: URL) async {
        guard isAdmin else {
            statusMessage =
                "Administrator login is required to import or change records."
            return
        }

        isImporting = true
        defer { isImporting = false }

        do {
            let result = try ownerJSONImporter.importFile(url)
            statusMessage =
                "Owner data: \(result.inserted) new lot(s), " +
                "\(result.updated) updated."

            if result.addressMismatches > 0 {
                statusMessage +=
                    " Review \(result.addressMismatches) address difference(s)."
            }

            try refresh()
        } catch {
            statusMessage =
                "Owner JSON import failed: \(error.localizedDescription)"
        }
    }

    /// Imports homeowner csv and validates it before persistence.
    func importHomeownerCSV(_ url: URL) async {
        guard isAdmin else {
            statusMessage =
                "Administrator login is required to import or change records."
            return
        }

        isImporting = true
        defer { isImporting = false }

        do {
            let result = try homeownerImporter.importFile(url)
            statusMessage =
                "Owners updated for \(result.updated) lot(s); " +
                "\(result.unmatched) row(s) unmatched."
            try refresh()
        } catch {
            statusMessage =
                "Owner CSV import failed: \(error.localizedDescription)"
        }
    }
}
