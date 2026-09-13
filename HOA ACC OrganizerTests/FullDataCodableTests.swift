// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import Foundation
import Testing
@testable import HOA_ACC_Organizer

/// Represents full data codable tests within HOA ACC Organizer.
struct FullDataCodableTests {
    /// Performs the package round trip preserves nested workflow records operation used by `FullDataCodableTests`.
    @Test
    func packageRoundTripPreservesNestedWorkflowRecords() throws {
        let package = makeSampleFullDataPackage()
        let data = try JSONEncoder().encode(package)
        let decoded = try JSONDecoder().decode(FullDataExportPackage.self, from: data)

        #expect(decoded.format == FullDataTransferService.format)
        #expect(decoded.version == FullDataTransferService.version)
        #expect(decoded.lots.count == 1)
        #expect(decoded.lots[0].violations.first?.status == "Open")
        #expect(decoded.lots[0].accApplications.first?.status == "Under Review")
        #expect(decoded.lots[0].violations.first?.attachments.count == 1)
    }
    /// Performs the package without deletion field decodes as empty tombstone list operation used by `FullDataCodableTests`.
    @Test
    func packageWithoutDeletionFieldDecodesAsEmptyTombstoneList() throws {
        let package = makeSampleFullDataPackage()
        let encoded = try JSONEncoder().encode(package)

        let decodedObject =
            try JSONSerialization.jsonObject(
                with: encoded
            )

        var object =
            try #require(
                decodedObject as? [String: Any]
            )

        object.removeValue(
            forKey: "deletions"
        )

        let legacyData =
            try JSONSerialization.data(
                withJSONObject: object
            )

        let decoded =
            try JSONDecoder().decode(
                FullDataExportPackage.self,
                from: legacyData
            )

        #expect(decoded.deletions.isEmpty)
    }

}
