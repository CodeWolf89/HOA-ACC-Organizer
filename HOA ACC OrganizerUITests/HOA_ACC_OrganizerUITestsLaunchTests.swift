// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import XCTest

/// Represents hoa acc organizer ui tests launch tests within HOA ACC Organizer.
final class HOA_ACC_OrganizerUITestsLaunchTests: XCTestCase {
    /// The runs for each target application ui configuration value maintained by `HOA_ACC_OrganizerUITestsLaunchTests`.
    override class var runsForEachTargetApplicationUIConfiguration: Bool { true }

    /// Performs the set up with error operation used by `HOA_ACC_OrganizerUITestsLaunchTests`.
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Performs the test launch operation used by `HOA_ACC_OrganizerUITestsLaunchTests`.
    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
