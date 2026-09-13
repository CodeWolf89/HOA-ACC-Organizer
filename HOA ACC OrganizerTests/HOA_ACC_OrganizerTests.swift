// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import Testing
@testable import HOA_ACC_Organizer

/// Small model-level smoke checks that verify the test bundle is linked to the application target.
struct HOA_ACC_OrganizerTests {
    /// Performs the dashboard and authentication models construct with expected values operation used by `HOA_ACC_OrganizerTests`.
    @Test
    func dashboardAndAuthenticationModelsConstructWithExpectedValues() {
        let dashboard = DashboardSummary(
            propertiesWithActiveViolations: 3,
            activeACCApplications: 2
        )
        let admin = AuthenticatedAdmin(
            id: "admin-1",
            username: "tester",
            displayName: "Test Administrator"
        )

        #expect(dashboard.propertiesWithActiveViolations == 3)
        #expect(dashboard.activeACCApplications == 2)
        #expect(admin.username == "tester")
    }
}
