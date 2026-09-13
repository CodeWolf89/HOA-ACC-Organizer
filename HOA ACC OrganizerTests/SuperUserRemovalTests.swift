// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import Foundation
import Testing
@testable import HOA_ACC_Organizer

/// Verifies the SuperUser-only destructive cleanup workflow, audit trail, and
/// deletion propagation used by backup/restore and nearby synchronization.
struct SuperUserRemovalTests {
    /// The super user value maintained by `SuperUserRemovalTests`.
    private let superUser =
        AuthenticatedAdmin(
            id: "superuser-test-id",
            username: "SHOA_ACC_SuperUser",
            displayName: "SHOA ACC SuperUser"
        )

    /// The ordinary admin value maintained by `SuperUserRemovalTests`.
    private let ordinaryAdmin =
        AuthenticatedAdmin(
            id: "review-test-id",
            username: "Apple_ReviewAccount",
            displayName: "Apple Review Account"
        )

    /// Performs the super user removal requires reason and writes audit entry operation used by `SuperUserRemovalTests`.
    @Test
    func superUserRemovalRequiresReasonAndWritesAuditEntry() throws {
        let sandbox = try TestStoreSandbox()

        try sandbox.store.importFullDataExportPackage(
            makeSampleFullDataPackage(),
            sourceFileName: "seed.json"
        )

        let photoURL =
            try sandbox.store.attachmentURL(
                fileName: "sample-photo.jpg"
            )

        #expect(
            FileManager.default.fileExists(
                atPath: photoURL.path
            )
        )

        #expect(throws: StoreError.self) {
            try sandbox.store.removeViolation(
                id: "violation-1",
                reason: "   ",
                actor: superUser
            )
        }

        try sandbox.store.removeViolation(
            id: "violation-1",
            reason: "Duplicate test violation entered during training.",
            actor: superUser
        )

        let removedViolation =
            try sandbox.store.fetchViolation(
                "violation-1"
            )

        #expect(removedViolation == nil)
        #expect(
            FileManager.default.fileExists(
                atPath: photoURL.path
            ) == false
        )

        let auditEntries =
            try sandbox.store.fetchAuditEntries(
                entityType: "violation",
                entityID: "violation-1"
            )

        let removal =
            try #require(
                auditEntries.first {
                    $0.action == "removeViolation"
                }
            )

        #expect(
            removal.username ==
                "SHOA_ACC_SuperUser"
        )
        #expect(
            removal.afterJSON.contains(
                "Duplicate test violation entered during training."
            )
        )

        let exported =
            try sandbox.store.buildFullDataExportPackage(
                includeAttachmentData: false
            )

        #expect(
            exported.deletions.contains {
                $0.entityType == "violation" &&
                $0.entityID == "violation-1" &&
                $0.reason.contains("Duplicate test violation")
            }
        )
    }

    /// Performs the non super user administrator cannot remove records operation used by `SuperUserRemovalTests`.
    @Test
    func nonSuperUserAdministratorCannotRemoveRecords() throws {
        let sandbox = try TestStoreSandbox()

        try sandbox.store.importFullDataExportPackage(
            makeSampleFullDataPackage(),
            sourceFileName: "seed.json"
        )

        #expect(throws: StoreError.self) {
            try sandbox.store.removeViolation(
                id: "violation-1",
                reason: "Cleanup",
                actor: ordinaryAdmin
            )
        }

        #expect(throws: StoreError.self) {
            try sandbox.store.removeACCRequest(
                id: "acc-1",
                reason: "Cleanup",
                actor: ordinaryAdmin
            )
        }

        let violation =
            try sandbox.store.fetchViolation(
                "violation-1"
            )
        let application =
            try sandbox.store.fetchACCRequest(
                "acc-1"
            )

        #expect(violation != nil)
        #expect(application != nil)
    }

    /// Performs the deletions propagate and stale transfer cannot resurrect records operation used by `SuperUserRemovalTests`.
    @Test
    func deletionsPropagateAndStaleTransferCannotResurrectRecords() throws {
        let source = try TestStoreSandbox()
        let destination = try TestStoreSandbox()
        let original = makeSampleFullDataPackage()

        try source.store.importFullDataExportPackage(
            original,
            sourceFileName: "source-seed.json"
        )
        try destination.store.importFullDataExportPackage(
            original,
            sourceFileName: "destination-seed.json"
        )

        try source.store.removeViolation(
            id: "violation-1",
            reason: "Duplicate imported violation.",
            actor: superUser
        )
        try source.store.removeACCRequest(
            id: "acc-1",
            reason: "Duplicate ACC application.",
            actor: superUser
        )

        let cleanupPackage =
            try source.store.buildFullDataExportPackage(
                includeAttachmentData: false
            )

        #expect(cleanupPackage.deletions.count == 2)

        try destination.store.importFullDataExportPackage(
            cleanupPackage,
            sourceFileName: "cleanup-sync.json"
        )

        let deletedViolation =
            try destination.store.fetchViolation(
                "violation-1"
            )
        let deletedApplication =
            try destination.store.fetchACCRequest(
                "acc-1"
            )

        #expect(deletedViolation == nil)
        #expect(deletedApplication == nil)

        let synchronizedAudit =
            try destination.store.fetchAuditEntries()

        #expect(
            synchronizedAudit.contains {
                $0.action == "removeViolation" &&
                $0.entityID == "violation-1" &&
                $0.afterJSON.contains(
                    "Duplicate imported violation."
                )
            }
        )
        #expect(
            synchronizedAudit.contains {
                $0.action == "removeACCApplication" &&
                $0.entityID == "acc-1" &&
                $0.afterJSON.contains(
                    "Duplicate ACC application."
                )
            }
        )

        // Importing an older snapshot must not recreate records protected by a
        // local deletion tombstone.
        try destination.store.importFullDataExportPackage(
            original,
            sourceFileName: "stale-snapshot.json"
        )

        let resurrectedViolation =
            try destination.store.fetchViolation(
                "violation-1"
            )
        let resurrectedApplication =
            try destination.store.fetchACCRequest(
                "acc-1"
            )

        #expect(resurrectedViolation == nil)
        #expect(resurrectedApplication == nil)
    }
    /// Performs the app model exposes cleanup only for provisioned super user operation used by `SuperUserRemovalTests`.
    @Test @MainActor
    func appModelExposesCleanupOnlyForProvisionedSuperUser() {
        let model = AppModel()

        model.currentUser =
            AuthenticatedUser(
                id: "review",
                username: "Apple_ReviewAccount",
                displayName: "Apple Review Account",
                role: "admin"
            )
        model.currentAdmin =
            AuthenticatedAdmin(
                id: "review",
                username: "Apple_ReviewAccount",
                displayName: "Apple Review Account"
            )

        #expect(model.isAdmin)
        #expect(model.isSuperUser == false)

        model.currentUser =
            AuthenticatedUser(
                id: "super",
                username: "SHOA_ACC_SuperUser",
                displayName: "SHOA ACC SuperUser",
                role: "admin"
            )
        model.currentAdmin = superUser

        #expect(model.isSuperUser)
    }

}
