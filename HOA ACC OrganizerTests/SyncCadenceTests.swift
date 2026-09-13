// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import Testing
@testable import HOA_ACC_Organizer

/// Represents sync cadence tests within HOA ACC Organizer.
struct SyncCadenceTests {
    /// Performs the cadence intervals match labels operation used by `SyncCadenceTests`.
    @Test
    func cadenceIntervalsMatchLabels() {
        #expect(SyncCadence.daily.displayName == "Daily")
        #expect(SyncCadence.daily.interval == 86_400)
        #expect(SyncCadence.weekly.displayName == "Weekly")
        #expect(SyncCadence.weekly.interval == 604_800)
    }
}
