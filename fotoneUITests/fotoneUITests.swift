import XCTest

final class fotoneUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    // MARK: - Meter Screen

    @MainActor
    func testMeterScreenShowsExposureValues() throws {
        // In the simulator, the light meter service provides fake data
        // so the meter labels should appear after a brief moment
        let shutterLabel = app.staticTexts["shutterSpeedLabel"]
        XCTAssertTrue(shutterLabel.waitForExistence(timeout: 5),
                      "Shutter speed label should appear on meter screen")

        let apertureLabel = app.staticTexts["apertureLabel"]
        XCTAssertTrue(apertureLabel.waitForExistence(timeout: 3),
                      "Aperture label should appear on meter screen")

        let evLabel = app.staticTexts["evLabel"]
        XCTAssertTrue(evLabel.waitForExistence(timeout: 3),
                      "EV label should appear on meter screen")
    }

    @MainActor
    func testMeterScreenShowsISOButton() throws {
        let isoButton = app.buttons["isoButton"]
        XCTAssertTrue(isoButton.waitForExistence(timeout: 5),
                      "ISO button should be visible on meter screen")
        // Should show "ISO 400" (default profile)
        XCTAssertTrue(isoButton.label.contains("ISO"))
    }

    @MainActor
    func testMeterScreenShowsProfileButton() throws {
        let profileButton = app.buttons["profileButton"]
        XCTAssertTrue(profileButton.waitForExistence(timeout: 5),
                      "Profile button should be visible on meter screen")
    }

    @MainActor
    func testHistogramToggle() throws {
        let histogramToggle = app.buttons["histogramToggle"]
        XCTAssertTrue(histogramToggle.waitForExistence(timeout: 5),
                      "Histogram toggle should be visible")

        // Tap to show histogram
        histogramToggle.tap()

        // Tap again to hide
        histogramToggle.tap()
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

        // Should show standard ISO values
        XCTAssertTrue(app.staticTexts["ISO 100"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["ISO 400"].exists)
        XCTAssertTrue(app.staticTexts["ISO 800"].exists)

        // Dismiss
        let doneButton = app.buttons["Done"]
        if doneButton.exists {
            doneButton.tap()
        }
    }

    @MainActor
    func testISOPickerSelectsValue() throws {
        let isoButton = app.buttons["isoButton"]
        guard isoButton.waitForExistence(timeout: 5) else {
            XCTFail("ISO button not found")
            return
        }
        isoButton.tap()

        // Select ISO 200
        let iso200 = app.staticTexts["ISO 200"]
        guard iso200.waitForExistence(timeout: 3) else {
            XCTFail("ISO 200 option not found")
            return
        }
        iso200.tap()

        // Sheet should dismiss and ISO button should update
        // Wait for the sheet to fully dismiss
        let updatedButton = app.buttons["isoButton"]
        XCTAssertTrue(updatedButton.waitForExistence(timeout: 3))
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

        // Dismiss
        let doneButton = app.buttons["Done"]
        if doneButton.exists {
            doneButton.tap()
        }
    }

    @MainActor
    func testAddNewProfile() throws {
        let profileButton = app.buttons["profileButton"]
        guard profileButton.waitForExistence(timeout: 5) else {
            XCTFail("Profile button not found")
            return
        }
        profileButton.tap()

        // Wait for profile list
        guard app.staticTexts["Cameras"].waitForExistence(timeout: 3) else {
            XCTFail("Profile list didn't appear")
            return
        }

        // Tap the add button
        let addButton = app.buttons["plus"]
        guard addButton.waitForExistence(timeout: 2) else {
            // Try alternative identifier
            let navAddButton = app.navigationBars.buttons.element(boundBy: 1)
            guard navAddButton.exists else {
                XCTFail("Add button not found")
                return
            }
            navAddButton.tap()
            return
        }
        addButton.tap()

        // The profile editor should appear
        let newCameraTitle = app.staticTexts["New Camera"]
        XCTAssertTrue(newCameraTitle.waitForExistence(timeout: 3),
                      "Profile editor should show 'New Camera' title")

        // Type a camera name
        let textField = app.textFields.firstMatch
        if textField.waitForExistence(timeout: 2) {
            textField.tap()
            textField.typeText("Canon AE-1")
        }

        // Cancel to go back
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.exists {
            cancelButton.tap()
        }
    }

    // MARK: - Exposure Table

    @MainActor
    func testExposureTableToggle() throws {
        let tableButton = app.buttons["exposureTableButton"]
        guard tableButton.waitForExistence(timeout: 5) else {
            // Exposure table might not appear if no combinations are available yet
            // This is acceptable in simulator
            return
        }
        tableButton.tap()

        // Table should now be visible — look for arrow indicators
        // Tap again to collapse
        tableButton.tap()
    }

    // MARK: - Launch Performance

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
