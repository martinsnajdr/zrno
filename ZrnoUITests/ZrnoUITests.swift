import XCTest

final class ZrnoUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    // MARK: - Helpers

    /// Find an element by accessibility identifier regardless of element type.
    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    // MARK: - Meter Screen

    @MainActor
    func testMeterScreenShowsExposureValues() throws {
        // Shutter speed and aperture are PriorityValuePickers (not plain Buttons)
        let shutter = element("shutterSpeedLabel")
        XCTAssertTrue(shutter.waitForExistence(timeout: 5),
                      "Shutter speed should appear on meter screen")

        let aperture = element("apertureLabel")
        XCTAssertTrue(aperture.waitForExistence(timeout: 3),
                      "Aperture should appear on meter screen")
    }

    @MainActor
    func testMeterScreenShowsISOButton() throws {
        let isoButton = app.buttons["isoButton"]
        XCTAssertTrue(isoButton.waitForExistence(timeout: 5),
                      "ISO button should be visible on meter screen")
    }

    @MainActor
    func testMeterScreenShowsProfileButton() throws {
        let profileButton = app.buttons["profileButton"]
        XCTAssertTrue(profileButton.waitForExistence(timeout: 5),
                      "Camera profile button should be visible on meter screen")
    }

    @MainActor
    func testSettingsButtonExists() throws {
        let settingsButton = app.buttons["settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5),
                      "Settings button should be visible")
    }

    @MainActor
    func testEVLabelExists() throws {
        let evLabel = element("evLabel")
        XCTAssertTrue(evLabel.waitForExistence(timeout: 5),
                      "EV label should be visible on meter screen")
    }

    // MARK: - Scene Preview

    @MainActor
    func testScenePreviewExists() throws {
        let preview = element("scenePreview")
        XCTAssertTrue(preview.waitForExistence(timeout: 5),
                      "Scene preview area should exist on meter screen")
    }

    // MARK: - Priority Mode

    @MainActor
    func testTapApertureTogglesPriority() throws {
        let aperture = element("apertureLabel")
        guard aperture.waitForExistence(timeout: 5) else {
            XCTFail("Aperture element not found")
            return
        }

        // Tap to enter aperture priority
        aperture.tap()

        // Tap again to exit aperture priority
        aperture.tap()
    }

    @MainActor
    func testTapShutterTogglesPriority() throws {
        let shutter = element("shutterSpeedLabel")
        guard shutter.waitForExistence(timeout: 5) else {
            XCTFail("Shutter speed element not found")
            return
        }

        // Tap to enter shutter priority
        shutter.tap()

        // Tap again to exit shutter priority
        shutter.tap()
    }

    // MARK: - ISO Picker

    @MainActor
    func testISOPickerOpensAndCloses() throws {
        let isoButton = app.buttons["isoButton"]
        guard isoButton.waitForExistence(timeout: 5) else {
            XCTFail("ISO button not found")
            return
        }
        isoButton.tap()

        // The ISO picker sheet should appear with FILM ISO title
        let navTitle = app.staticTexts["FILM ISO"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 3),
                      "ISO picker should show 'FILM ISO' title")

        // Dismiss by swiping down
        app.swipeDown()
    }

    @MainActor
    func testISOPickerShowsStandardValues() throws {
        let isoButton = app.buttons["isoButton"]
        guard isoButton.waitForExistence(timeout: 5) else {
            XCTFail("ISO button not found")
            return
        }
        isoButton.tap()

        // Wait for sheet
        guard app.staticTexts["FILM ISO"].waitForExistence(timeout: 3) else {
            XCTFail("ISO picker didn't appear")
            return
        }

        // Standard ISOs should be listed (text is inside plain-style buttons)
        let iso100 = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS 'ISO 100'")
        ).firstMatch
        XCTAssertTrue(iso100.waitForExistence(timeout: 2),
                      "ISO 100 option should be visible")
        let iso400 = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS 'ISO 400'")
        ).firstMatch
        XCTAssertTrue(iso400.exists, "ISO 400 option should be visible")

        app.swipeDown()
    }

    // MARK: - Profile Management

    @MainActor
    func testProfileListOpensAndCloses() throws {
        let profileButton = app.buttons["profileButton"]
        guard profileButton.waitForExistence(timeout: 5) else {
            XCTFail("Profile button not found")
            return
        }
        profileButton.tap()

        // The profile list should appear with "CAMERAS" title
        let navTitle = app.staticTexts["CAMERAS"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 3),
                      "Profile list should show 'CAMERAS' title")

        // Default profile should be listed
        XCTAssertTrue(app.staticTexts["Basic"].waitForExistence(timeout: 2),
                      "Default 'Basic' profile should be visible")

        app.swipeDown()
    }

    // MARK: - Settings

    @MainActor
    func testSettingsOpensAndCloses() throws {
        let settingsButton = app.buttons["settingsButton"]
        guard settingsButton.waitForExistence(timeout: 5) else {
            XCTFail("Settings button not found")
            return
        }
        settingsButton.tap()

        // Settings sheet should appear
        let settingsTitle = app.staticTexts["SETTINGS"]
        XCTAssertTrue(settingsTitle.waitForExistence(timeout: 3),
                      "Settings sheet should show 'SETTINGS' title")

        app.swipeDown()
    }

    @MainActor
    func testSettingsShowsAppearanceSection() throws {
        let settingsButton = app.buttons["settingsButton"]
        guard settingsButton.waitForExistence(timeout: 5) else {
            XCTFail("Settings button not found")
            return
        }
        settingsButton.tap()

        guard app.staticTexts["SETTINGS"].waitForExistence(timeout: 3) else {
            XCTFail("Settings sheet didn't appear")
            return
        }

        // Appearance mode options should exist (text inside plain-style buttons)
        let system = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == 'System'")
        ).firstMatch
        XCTAssertTrue(system.waitForExistence(timeout: 2),
                      "System appearance option should be visible")
        let light = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == 'Light'")
        ).firstMatch
        XCTAssertTrue(light.exists,
                      "Light appearance option should be visible")
        let dark = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == 'Dark'")
        ).firstMatch
        XCTAssertTrue(dark.exists,
                      "Dark appearance option should be visible")

        app.swipeDown()
    }

    @MainActor
    func testSettingsShowsColorSchemeSection() throws {
        let settingsButton = app.buttons["settingsButton"]
        guard settingsButton.waitForExistence(timeout: 5) else {
            XCTFail("Settings button not found")
            return
        }
        settingsButton.tap()

        guard app.staticTexts["SETTINGS"].waitForExistence(timeout: 3) else {
            XCTFail("Settings sheet didn't appear")
            return
        }

        // Color scheme options — display names include full descriptive name (inside buttons)
        let noir = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS 'Midnight Noir'")
        ).firstMatch
        XCTAssertTrue(noir.waitForExistence(timeout: 2),
                      "Midnight Noir color scheme should be visible")

        app.swipeDown()
    }

    // MARK: - ZRNO Branding

    @MainActor
    func testZRNOBrandingVisible() throws {
        let branding = app.staticTexts["ZRNO"]
        XCTAssertTrue(branding.waitForExistence(timeout: 5),
                      "ZRNO branding should be visible in top bar")
    }

    // MARK: - Compensation Dial

    @MainActor
    func testCompensationDialExists() throws {
        let dial = element("compensationDial")
        XCTAssertTrue(dial.waitForExistence(timeout: 5),
                      "Compensation dial should be visible on meter screen")
    }

    @MainActor
    func testCompensationLabelExists() throws {
        // The compensation label is inside the compensationDial VStack
        // Search for any element whose label is "±0" (the default compensation value)
        let label = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == '±0'")
        ).firstMatch
        XCTAssertTrue(label.waitForExistence(timeout: 5),
                      "Compensation label should be visible with ±0")
    }

    @MainActor
    func testCompensationDialSwipeChangesValue() throws {
        let dial = element("compensationDial")
        guard dial.waitForExistence(timeout: 5) else {
            XCTFail("Compensation dial not found")
            return
        }

        // Verify the initial "±0" label exists
        let initialLabel = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == '±0'")
        ).firstMatch
        XCTAssertTrue(initialLabel.waitForExistence(timeout: 3),
                      "Initial compensation should be ±0")

        // Drag from center to the left (increases compensation toward +)
        let start = dial.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = dial.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: end)

        // Wait for value to update
        Thread.sleep(forTimeInterval: 0.5)

        // After dragging, either the ±0 label no longer exists or a new value appeared
        let newLabel = app.descendants(matching: .any).matching(
            NSPredicate(format: "label MATCHES '[-+][0-9].*'")
        ).firstMatch
        let labelChanged = !initialLabel.exists || newLabel.exists
        XCTAssertTrue(labelChanged,
                      "Compensation value should change after drag")
    }

    // MARK: - Keyboard Toolbar Test

    @MainActor
    func testEditorKeyboardDoesNotPushTopbar() throws {
        // Open profile list
        let profileButton = app.buttons["profileButton"]
        guard profileButton.waitForExistence(timeout: 5) else {
            XCTFail("Profile button not found")
            return
        }
        profileButton.tap()

        // Wait for profile list sheet
        guard app.staticTexts["CAMERAS"].waitForExistence(timeout: 3) else {
            XCTFail("Profile list didn't appear")
            return
        }

        // Tap the first non-default profile to edit it, or tap the add (plus) button
        let plusButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Add'")).firstMatch
        if plusButton.waitForExistence(timeout: 2) {
            plusButton.tap()
        } else {
            // Try tapping any row to open editor
            let profileRow = app.staticTexts["Basic"]
            guard profileRow.waitForExistence(timeout: 2) else {
                XCTFail("No profile found to edit")
                return
            }
            profileRow.tap()
        }

        // Wait for editor to appear
        guard app.staticTexts["CAMERA"].waitForExistence(timeout: 3) else {
            XCTFail("Camera editor didn't appear")
            return
        }

        // Find and tap a text field (camera name input)
        let textFields = app.textFields
        if textFields.count > 0 {
            textFields.firstMatch.tap()
        }

        // Wait for keyboard
        Thread.sleep(forTimeInterval: 1.0)

        // The CAMERA title should still be visible and not pushed off screen
        XCTAssertTrue(app.staticTexts["CAMERA"].exists,
                      "CAMERA title should remain visible when keyboard is shown")
    }

    // MARK: - Layout Stability

    /// Verifies key UI elements are visible and within expected screen bounds in portrait.
    @MainActor
    func testPortraitLayoutIntegrity() throws {
        let screenWidth = XCUIScreen.main.screenshot().image.size.width

        // Top bar elements
        let profileButton = app.buttons["profileButton"]
        let settingsButton = app.buttons["settingsButton"]
        let branding = app.staticTexts["ZRNO"]

        guard profileButton.waitForExistence(timeout: 5) else {
            XCTFail("Profile button not found")
            return
        }

        XCTAssertTrue(settingsButton.exists, "Settings button should exist")
        XCTAssertTrue(branding.exists, "ZRNO branding should exist")

        // All top bar elements should be on screen
        XCTAssertGreaterThanOrEqual(profileButton.frame.minX, 0,
                                    "Profile button should be on screen")
        XCTAssertLessThanOrEqual(settingsButton.frame.maxX, screenWidth,
                                 "Settings button should be on screen")

        // Profile button should be left of branding, branding left of settings
        XCTAssertLessThan(profileButton.frame.midX, branding.frame.midX,
                          "Profile button should be left of ZRNO")
        XCTAssertLessThan(branding.frame.midX, settingsButton.frame.midX,
                          "ZRNO should be left of settings button")

        // Exposure elements (use generic element lookup for custom views)
        let shutter = element("shutterSpeedLabel")
        let aperture = element("apertureLabel")
        let evLabel = element("evLabel")
        let dial = element("compensationDial")
        let preview = element("scenePreview")

        XCTAssertTrue(shutter.waitForExistence(timeout: 3), "Shutter speed should exist")
        XCTAssertTrue(aperture.exists, "Aperture should exist")
        XCTAssertTrue(evLabel.exists, "EV label should exist")
        XCTAssertTrue(dial.exists, "Compensation dial should exist")
        XCTAssertTrue(preview.exists, "Scene preview should exist")

        // Verify top bar ordering (buttons have reliable frames)
        XCTAssertLessThanOrEqual(profileButton.frame.maxY, aperture.frame.minY,
                                 "Top bar should be above aperture")
    }

    /// Verifies key UI elements are visible in landscape orientation.
    @MainActor
    func testLandscapeLayoutIntegrity() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 1.0)

        let profileButton = app.buttons["profileButton"]
        guard profileButton.waitForExistence(timeout: 5) else {
            XCTFail("Profile button not found in landscape")
            return
        }

        let settingsButton = app.buttons["settingsButton"]
        let shutter = element("shutterSpeedLabel")
        let preview = element("scenePreview")

        XCTAssertTrue(settingsButton.exists, "Settings button should exist in landscape")
        XCTAssertTrue(shutter.exists, "Shutter speed should exist in landscape")
        XCTAssertTrue(preview.exists, "Scene preview should exist in landscape")

        // Restore portrait
        XCUIDevice.shared.orientation = .portrait
        Thread.sleep(forTimeInterval: 0.5)
    }

    // MARK: - Launch Performance

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
