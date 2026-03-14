import XCTest

final class ZrnoUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    // MARK: - Meter Screen

    @MainActor
    func testMeterScreenShowsExposureValues() throws {
        // Shutter speed and aperture are Buttons (tappable for priority mode)
        let shutterButton = app.buttons["shutterSpeedLabel"]
        XCTAssertTrue(shutterButton.waitForExistence(timeout: 5),
                      "Shutter speed button should appear on meter screen")

        let apertureButton = app.buttons["apertureLabel"]
        XCTAssertTrue(apertureButton.waitForExistence(timeout: 3),
                      "Aperture button should appear on meter screen")
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
        let evLabel = app.staticTexts["evLabel"]
        XCTAssertTrue(evLabel.waitForExistence(timeout: 5),
                      "EV label should be visible on meter screen")
    }

    // MARK: - Scene Preview

    @MainActor
    func testScenePreviewExists() throws {
        let preview = app.otherElements["scenePreview"]
        XCTAssertTrue(preview.waitForExistence(timeout: 5),
                      "Scene preview area should exist on meter screen")
    }

    // MARK: - Priority Mode

    @MainActor
    func testTapApertureTogglesPriority() throws {
        let apertureButton = app.buttons["apertureLabel"]
        guard apertureButton.waitForExistence(timeout: 5) else {
            XCTFail("Aperture button not found")
            return
        }

        // Tap to enter aperture priority
        apertureButton.tap()

        // Tap again to exit aperture priority
        apertureButton.tap()
    }

    @MainActor
    func testTapShutterTogglesPriority() throws {
        let shutterButton = app.buttons["shutterSpeedLabel"]
        guard shutterButton.waitForExistence(timeout: 5) else {
            XCTFail("Shutter speed button not found")
            return
        }

        // Tap to enter shutter priority
        shutterButton.tap()

        // Tap again to exit shutter priority
        shutterButton.tap()
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

        // The ISO picker sheet should appear with Film ISO title
        let navTitle = app.staticTexts["Film ISO"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 3),
                      "ISO picker should show 'Film ISO' title")

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
        guard app.staticTexts["Film ISO"].waitForExistence(timeout: 3) else {
            XCTFail("ISO picker didn't appear")
            return
        }

        // Standard ISOs should be listed
        XCTAssertTrue(app.staticTexts["ISO 100"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["ISO 400"].exists)

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

        // The profile list should appear with "Cameras" title
        let navTitle = app.staticTexts["Cameras"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 3),
                      "Profile list should show 'Cameras' title")

        // Default profile should be listed
        XCTAssertTrue(app.staticTexts["Mamiya 7"].waitForExistence(timeout: 2),
                      "Default 'Mamiya 7' profile should be visible")

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
        let settingsTitle = app.staticTexts["Settings"]
        XCTAssertTrue(settingsTitle.waitForExistence(timeout: 3),
                      "Settings sheet should show 'Settings' title")

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

        guard app.staticTexts["Settings"].waitForExistence(timeout: 3) else {
            XCTFail("Settings sheet didn't appear")
            return
        }

        // Appearance mode options should exist
        XCTAssertTrue(app.staticTexts["System"].waitForExistence(timeout: 2),
                      "System appearance option should be visible")
        XCTAssertTrue(app.staticTexts["Light"].exists,
                      "Light appearance option should be visible")
        XCTAssertTrue(app.staticTexts["Dark"].exists,
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

        guard app.staticTexts["Settings"].waitForExistence(timeout: 3) else {
            XCTFail("Settings sheet didn't appear")
            return
        }

        // Color scheme options
        XCTAssertTrue(app.staticTexts["Noir"].waitForExistence(timeout: 2),
                      "Noir color scheme should be visible")

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
        let dial = app.otherElements["compensationDial"]
        XCTAssertTrue(dial.waitForExistence(timeout: 5),
                      "Compensation dial should be visible on meter screen")
    }

    @MainActor
    func testCompensationLabelExists() throws {
        let label = app.staticTexts["compensationLabel"]
        XCTAssertTrue(label.waitForExistence(timeout: 5),
                      "Compensation label should be visible")
        XCTAssertEqual(label.label, "±0",
                       "Initial compensation should be ±0")
    }

    @MainActor
    func testCompensationDialSwipeChangesValue() throws {
        let dial = app.otherElements["compensationDial"]
        guard dial.waitForExistence(timeout: 5) else {
            XCTFail("Compensation dial not found")
            return
        }

        let label = app.staticTexts["compensationLabel"]
        guard label.waitForExistence(timeout: 3) else {
            XCTFail("Compensation label not found")
            return
        }

        let initialValue = label.label

        // Drag from center to the left (increases compensation toward +)
        let start = dial.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = dial.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)

        // Wait for value to update
        Thread.sleep(forTimeInterval: 0.5)

        XCTAssertNotEqual(label.label, initialValue,
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
        guard app.staticTexts["Cameras"].waitForExistence(timeout: 3) else {
            XCTFail("Profile list didn't appear")
            return
        }

        // Look for any edit button (pencil icon) to open profile editor
        // First look for a non-default profile edit button, or the add button
        let addButton = app.buttons["addProfileButton"]
        if addButton.waitForExistence(timeout: 2) {
            addButton.tap()
        } else {
            // Try tapping the first edit button
            let editButtons = app.buttons.matching(identifier: "editProfileButton")
            if editButtons.count > 0 {
                editButtons.firstMatch.tap()
            } else {
                XCTFail("No edit or add button found")
                return
            }
        }

        // Wait for editor to appear
        guard app.staticTexts["CAMERA"].waitForExistence(timeout: 3) else {
            XCTFail("Camera editor didn't appear")
            return
        }

        // Take screenshot before keyboard
        let beforeScreenshot = XCUIScreen.main.screenshot()
        let beforeAttachment = XCTAttachment(screenshot: beforeScreenshot)
        beforeAttachment.name = "Before Keyboard"
        beforeAttachment.lifetime = .keepAlways
        add(beforeAttachment)

        // Find and tap a text field (camera name input)
        let textFields = app.textFields
        if textFields.count > 0 {
            textFields.firstMatch.tap()
        }

        // Wait for keyboard
        Thread.sleep(forTimeInterval: 1.0)

        // Take screenshot with keyboard visible
        let afterScreenshot = XCUIScreen.main.screenshot()
        let afterAttachment = XCTAttachment(screenshot: afterScreenshot)
        afterAttachment.name = "After Keyboard"
        afterAttachment.lifetime = .keepAlways
        add(afterAttachment)

        // The CAMERA title should still be visible and not pushed off screen
        XCTAssertTrue(app.staticTexts["CAMERA"].exists,
                      "CAMERA topbar title should remain visible when keyboard is shown")
    }

    // MARK: - Launch Performance

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
