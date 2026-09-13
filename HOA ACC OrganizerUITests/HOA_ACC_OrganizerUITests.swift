// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import XCTest

/// End-to-end smoke tests for the primary navigation and modal entry points.
final class HOA_ACC_OrganizerUITests: XCTestCase {
    /// Performs the set up with error operation used by `HOA_ACC_OrganizerUITests`.
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Performs the test launch shows primary content operation used by `HOA_ACC_OrganizerUITests`.
    @MainActor
    func testLaunchShowsPrimaryContent() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(
            app.wait(
                for: .runningForeground,
                timeout: 10
            )
        )

        XCTAssertTrue(
            app.staticTexts["Summary"]
                .waitForExistence(timeout: 10)
        )
        XCTAssertTrue(app.staticTexts["Lots"].exists)
    }

    /// Performs the test search field is available operation used by `HOA_ACC_OrganizerUITests`.
    @MainActor
    func testSearchFieldIsAvailable() throws {
        let app = XCUIApplication()
        app.launch()

        let search = app.searchFields.firstMatch
        XCTAssertTrue(
            search.waitForExistence(timeout: 10),
            "The property search field should be visible on the primary lot screen."
        )
    }

    /// Performs the test administrator login can be opened and cancelled operation used by `HOA_ACC_OrganizerUITests`.
    @MainActor
    func testAdministratorLoginCanBeOpenedAndCancelled() throws {
        let app = XCUIApplication()
        app.launch()

        let login = app.buttons["toolbar.adminLogin"]
        guard login.waitForExistence(timeout: 5) else {
            // A retained authenticated session can legitimately show the Admin menu instead.
            XCTAssertTrue(
                app.buttons["toolbar.admin"].exists ||
                app.buttons["Admin"].exists
            )
            return
        }

        login.tap()
        XCTAssertTrue(
            app.navigationBars["Account Login"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.textFields["admin.username"].exists)
        XCTAssertTrue(app.secureTextFields["admin.password"].exists)

        app.buttons["admin.cancel"].tap()
        XCTAssertFalse(
            app.navigationBars["Account Login"]
                .exists
        )
    }

    #if os(iOS)
    /// Performs the test new violation workflow can be opened by standard user operation used by `HOA_ACC_OrganizerUITests`.
    @MainActor
    func testNewViolationWorkflowCanBeOpenedByStandardUser() throws {
        let app = XCUIApplication()
        app.launch()

        let identifiedButton =
            app.buttons[
                "toolbar.newViolation"
            ]

        let titledButton =
            app.buttons[
                "New Violation"
            ]

        let button:
            XCUIElement

        if identifiedButton
            .waitForExistence(
                timeout: 5
            ) {
            button =
                identifiedButton
        } else {
            XCTAssertTrue(
                titledButton
                    .waitForExistence(
                        timeout: 5
                    ),
                "The New Violation action should be available to a standard iOS/iPadOS user before selecting a lot."
            )

            button =
                titledButton
        }

        button.tap()

        XCTAssertTrue(
            app.navigationBars["New Violation"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.staticTexts["Property"].exists)
        XCTAssertTrue(app.staticTexts["Violations"].exists)

        app.buttons["Cancel"].tap()
    }

    /// Performs the test phone lot navigation keeps global actions visible operation used by `HOA_ACC_OrganizerUITests`.
    @MainActor
    func testPhoneLotNavigationKeepsGlobalActionsVisible() throws {
        let app = XCUIApplication()
        app.launch()

        // This assertion is specific to the compact iPhone toolbar. iPad
        // exposes the actions directly rather than through the Actions menu.
        let actions =
            app.buttons[
                "toolbar.actions"
            ]

        guard actions.waitForExistence(
            timeout: 5
        ) else {
            return
        }

        let firstLot =
            app.buttons[
                "lot.row.1"
            ]

        XCTAssertTrue(
            firstLot.waitForExistence(
                timeout: 10
            ),
            "Lot 1 should be reachable from the compact iPhone lot list."
        )

        firstLot.tap()

        XCTAssertTrue(
            app.navigationBars[
                "Lot 1"
            ]
            .waitForExistence(
                timeout: 5
            )
        )

        XCTAssertTrue(
            app.buttons[
                "toolbar.newViolation"
            ]
            .waitForExistence(
                timeout: 5
            ),
            "New Violation should remain available after opening a lot on iPhone."
        )

        XCTAssertTrue(
            app.buttons[
                "toolbar.actions"
            ]
            .exists,
            "Actions should remain available after opening a lot on iPhone."
        )

        XCTAssertTrue(
            app.buttons[
                "toolbar.admin"
            ]
            .exists ||
            app.buttons[
                "toolbar.adminLogin"
            ]
            .exists,
            "The administrator control should remain available after opening a lot on iPhone."
        )
    }

    /// Performs the test administrator can reach acc creation actions from lot operation used by `HOA_ACC_OrganizerUITests`.
    @MainActor
    func testAdministratorCanReachACCCreationActionsFromLot() throws {
        let app = XCUIApplication()
        app.launchArguments.append(
            "--uitest-admin"
        )
        app.launch()

        let firstLot =
            app.buttons[
                "lot.row.1"
            ]

        XCTAssertTrue(
            firstLot.waitForExistence(
                timeout: 10
            )
        )
        firstLot.tap()

        XCTAssertTrue(
            app.buttons[
                "lot.acc.addManual"
            ]
            .waitForExistence(
                timeout: 5
            ),
            "An administrator should be able to reach manual ACC application entry from a lot."
        )

        XCTAssertTrue(
            app.buttons[
                "lot.acc.importPDF"
            ]
            .waitForExistence(
                timeout: 5
            ),
            "An administrator should be able to reach ACC PDF import from a lot."
        )
    }

    /// Performs the test phone actions menu exposes sync operation used by `HOA_ACC_OrganizerUITests`.
    @MainActor
    func testPhoneActionsMenuExposesSync() throws {
        let app = XCUIApplication()
        app.launch()

        let actions = app.buttons["toolbar.actions"]
        guard actions.waitForExistence(timeout: 3) else {
            return // iPad presents the actions directly in the toolbar.
        }

        actions.tap()
        XCTAssertTrue(app.buttons["Data Sync"].waitForExistence(timeout: 3))
        app.buttons["Data Sync"].tap()
        XCTAssertTrue(
            app.navigationBars["Data Sync"]
                .waitForExistence(timeout: 5)
        )
    }
    #endif
}
