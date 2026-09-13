// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import Foundation
import Testing
@testable import HOA_ACC_Organizer

/// Represents backup and transfer integration tests within HOA ACC Organizer.
struct BackupAndTransferIntegrationTests {
    /// Performs the full data service round trips between independent stores operation used by `BackupAndTransferIntegrationTests`.
    @Test
    func fullDataServiceRoundTripsBetweenIndependentStores() throws {
        let source = try TestStoreSandbox()
        let destination = try TestStoreSandbox()

        try source.store.importFullDataExportPackage(
            makeSampleFullDataPackage(),
            sourceFileName: "seed.json"
        )

        let service = FullDataTransferService(store: source.store)
        let data = try service.exportJSONData()
        let jsonURL = source.rootURL.appendingPathComponent("full-export.json")
        try data.write(to: jsonURL, options: .atomic)

        let importedCount = try FullDataTransferService(store: destination.store)
            .importJSON(from: jsonURL)

        let importedLots =
            try destination.store
                .fetchLotSummaries(
                    search: ""
                )

        let importedIssues =
            try destination.store
                .fetchOpenIssues()

        #expect(importedCount == 1)
        #expect(importedLots.count == 1)
        #expect(importedIssues.count == 2)
    }

    /// Performs the backup round trip restores structured data and files operation used by `BackupAndTransferIntegrationTests`.
    @Test
    func backupRoundTripRestoresStructuredDataAndFiles() throws {
        let source = try TestStoreSandbox()
        let destination = try TestStoreSandbox()

        try source.store.importFullDataExportPackage(
            makeSampleFullDataPackage(),
            sourceFileName: "seed.json"
        )

        let backupData = try BackupService(store: source.store).createBackupData()
        let backupURL = source.rootURL.appendingPathComponent("backup.zip")
        try backupData.write(to: backupURL, options: .atomic)

        let restoredCount = try BackupService(store: destination.store)
            .restoreBackup(from: backupURL)

        let restoredLots =
            try destination.store
                .fetchLotSummaries(
                    search: ""
                )

        let photoURL =
            try destination.store
                .attachmentURL(
                    fileName:
                        "sample-photo.jpg"
                )

        let restoredPhotoData =
            try Data(
                contentsOf:
                    photoURL
            )

        #expect(restoredCount == 1)
        #expect(restoredLots.count == 1)

        #expect(
            FileManager.default
                .fileExists(
                    atPath:
                        photoURL.path
                )
        )

        #expect(
            restoredPhotoData ==
                Data(
                    "sample-photo".utf8
                )
        )
    }
}
