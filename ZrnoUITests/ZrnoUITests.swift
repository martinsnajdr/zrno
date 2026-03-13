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

        // EV label is a text element
        let evLabel = app.staticTexts["evLabel"]
        XCTAssertTrue(evLabel.waitForExistence(timeout: 3),
                      "EV label should appear on meter screen")
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
                      "Profile button should be visible on meter screen")
    }

    @MainActor
    func testSettingsButtonExists() throws {
        let settingsButton = app.buttons["settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5),
                      "Settings button should be visible")
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
        XCTAssertTrue(app.staticTexts["35mm Camera"].waitForExistence(timeout: 2),
                      "Default '35mm Camera' profile should be visible")

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

    // MARK: - Launch Performance

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
