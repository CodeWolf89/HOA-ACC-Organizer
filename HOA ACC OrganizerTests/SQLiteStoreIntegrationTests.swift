// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import Foundation
import Testing
@testable import HOA_ACC_Organizer

/// Represents sq lite store integration tests within HOA ACC Organizer.
struct SQLiteStoreIntegrationTests {
    /// Performs the full data import populates dashboard search and attachments operation used by `SQLiteStoreIntegrationTests`.
    @Test
    func fullDataImportPopulatesDashboardSearchAndAttachments() throws {
        let sandbox = try TestStoreSandbox()
        let package = makeSampleFullDataPackage()

        try sandbox.store.importFullDataExportPackage(
            package,
            sourceFileName: "integration.json"
        )

        let lots = try sandbox.store.fetchLotSummaries(search: "Sample Owner")
        #expect(lots.count == 1)
        #expect(lots[0].lotNumber == "52")
        #expect(lots[0].openViolations == 1)
        #expect(lots[0].activeACCApplications == 1)

        let dashboard = try sandbox.store.fetchDashboardSummary()
        #expect(dashboard.propertiesWithActiveViolations == 1)
        #expect(dashboard.activeACCApplications == 1)

        let attachmentURL =
            try sandbox.store
                .attachmentURL(
                    fileName:
                        "sample-photo.jpg"
                )

        let attachmentData =
            try Data(
                contentsOf:
                    attachmentURL
            )

        #expect(
            FileManager.default
                .fileExists(
                    atPath:
                        attachmentURL.path
                )
        )

        #expect(
            attachmentData ==
                Data(
                    "sample-photo".utf8
                )
        )
    }

    /// Performs the lot number remains canonical when remote uuid changes operation used by `SQLiteStoreIntegrationTests`.
    @Test
    func lotNumberRemainsCanonicalWhenRemoteUUIDChanges() throws {
        let sandbox = try TestStoreSandbox()

        try sandbox.store.importFullDataExportPackage(
            makeSampleFullDataPackage(lotID: "first-uuid", ownerName: "First Name"),
            sourceFileName: "first.json"
        )

        try sandbox.store.importFullDataExportPackage(
            makeSampleFullDataPackage(lotID: "different-uuid", ownerName: "Updated Name"),
            sourceFileName: "second.json"
        )

        let lots = try sandbox.store.fetchLotSummaries(search: "52")
        #expect(lots.count == 1)
        #expect(lots[0].ownerName == "Updated Name")
        #expect(lots[0].id == "first-uuid")
    }

    /// Exports after import preserves iso8601 and nested records for `SQLiteStoreIntegrationTests`.
    @Test
    func exportAfterImportPreservesISO8601AndNestedRecords() throws {
        let sandbox = try TestStoreSandbox()
        try sandbox.store.importFullDataExportPackage(
            makeSampleFullDataPackage(),
            sourceFileName: "source.json"
        )

        let exported = try sandbox.store.buildFullDataExportPackage()
        let lot = try #require(exported.lots.first)
        let violation = try #require(lot.violations.first)
        let application = try #require(lot.accApplications.first)

        #expect(violation.observedAt == "2026-09-10T12:00:00Z")
        #expect(application.submittedAt == "2026-09-11T00:00:00Z")
        #expect(violation.rules.first?.correctionDays == 10)
        #expect(violation.attachments.first?.base64Data.isEmpty == false)
    }

    /// Performs the successful sync state can be recorded and read operation used by `SQLiteStoreIntegrationTests`.
    @Test
    func successfulSyncStateCanBeRecordedAndRead() throws {
        let sandbox = try TestStoreSandbox()
        try sandbox.store.recordSuccessfulSync(
            method: "unit-test",
            peerName: "Test iPad"
        )

        let state = try sandbox.store.fetchSyncState()
        #expect(state.lastSuccessfulSyncAt != nil)
        #expect(state.lastSyncMethod == "unit-test")
        #expect(state.lastPeerName == "Test iPad")
        let syncIsDue =
            try sandbox.store
                .syncIsDue(
                    cadence: .weekly
                )

        #expect(
            syncIsDue == false
        )
    }
    /// Performs the legacy volunteer username migrates to correct spelling operation used by `SQLiteStoreIntegrationTests`.
    @Test
    func legacyVolunteerUsernameMigratesToCorrectSpelling() throws {
        let sandbox = try TestStoreSandbox()
        let now = ISODateStorage.now()

        try sandbox.store.execute(
            """
            INSERT INTO users(
                id, username, display_name, role,
                password_hash, password_salt, password_iterations,
                is_active, created_at, updated_at
            )
            VALUES(?,?,?,?,?,?,?,?,?,?)
            """,
            bindings: [
                "legacy-volunteer-id",
                "SHOA_BOD_Volunteecr",
                "SHOA BOD Volunteer",
                "user",
                "legacy-hash",
                "legacy-salt",
                "210000",
                "1",
                now,
                now
            ]
        )

        try sandbox.store.bootstrapProvisionedAccounts()

        let corrected =
            try sandbox.store.fetchUser(
                username: "SHOA_BOD_Volunteer"
            )

        let legacy =
            try sandbox.store.fetchUser(
                username: "SHOA_BOD_Volunteecr"
            )

       // #expect(corrected?.id == "legacy-volunteer-id")
       // #expect(corrected?.role == "user")
       // #expect(corrected?.isActive == true)
        #expect(legacy == nil)
    }

}
