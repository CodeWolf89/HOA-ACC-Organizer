// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import Testing
@testable import HOA_ACC_Organizer

/// Represents user facing status tests within HOA ACC Organizer.
struct UserFacingStatusTests {
    /// Performs the runtime checkpoints become plain language operation used by `UserFacingStatusTests`.
    @Test
    func runtimeCheckpointsBecomePlainLanguage() {
        #expect(
            UserFacingStatus
                .friendlyCheckpoint(
                    "startup.database.open"
                ) ==
                "Opening HOA records…"
        )

        #expect(
            UserFacingStatus
                .friendlyCheckpoint(
                    "network.frame.attachmentChunk"
                ) ==
                "Transferring photos and PDFs…"
        )

        #expect(
            UserFacingStatus
                .friendlyCheckpoint(
                    "network.sync.complete"
                ) ==
                "Sync complete"
        )
    }

    /// Performs the sync status preserves useful device name operation used by `UserFacingStatusTests`.
    @Test
    func syncStatusPreservesUsefulDeviceName() {
        #expect(
            UserFacingStatus
                .friendlySyncStatus(
                    "Connected: Chris’s iPad"
                ) ==
                "Connected to Chris’s iPad."
        )

        #expect(
            UserFacingStatus
                .friendlySyncStatus(
                    "Searching for nearby HOA ACC devices…"
                ) ==
                "Looking for another HOA ACC device…"
        )
    }

    /// Performs the technical sync errors become actionable operation used by `UserFacingStatusTests`.
    @Test
    func technicalSyncErrorsBecomeActionable() {
        #expect(
            UserFacingStatus
                .friendlySyncError(
                    "Nearby discovery waiting: Local network denied"
                ) ==
                "Nearby sync is waiting for local network access. Check the app's Local Network permission and try again."
        )

        #expect(
            UserFacingStatus
                .friendlySyncError(
                    "Unable to finish incoming attachment: Attachment hash verification failed."
                ) ==
                "Some photos or PDFs could not be transferred. Keep both apps open and try the sync again."
        )
    }

    /// Performs the violation feed status uses nontechnical language operation used by `UserFacingStatusTests`.
    @Test
    func violationFeedStatusUsesNontechnicalLanguage() {
        #expect(
            UserFacingStatus
                .friendlyViolationFeedStatus(
                    "Ready to receive from HOA Violations"
                ) ==
                "Ready to receive violation reports."
        )

        #expect(
            UserFacingStatus
                .friendlyViolationFeedStatus(
                    "Violation App intake stopped"
                ) ==
                "Violation intake is paused."
        )
    }
}
