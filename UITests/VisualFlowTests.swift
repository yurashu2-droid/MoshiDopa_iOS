import XCTest

final class VisualFlowTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(_ screen: String = "home", fixture: String = "populated") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--screen", screen, "--fixture", fixture]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["screen-\(screen)"].waitForExistence(timeout: 10), "Missing screen \(screen)")
        return app
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testAllReferenceScreensRenderWithEmptyAndPopulatedFixtures() {
        let screens = ["home", "history", "settings", "counter", "receipt", "statement", "onboarding", "whatif", "measurement"]
        for fixture in ["empty", "populated", "large"] {
            for screen in screens {
                let app = launch(screen, fixture: fixture)
                capture(app, name: "\(screen)-\(fixture)")
                if ["history", "settings", "counter", "receipt", "statement"].contains(screen) {
                    for page in 1...3 {
                        app.swipeUp()
                        capture(app, name: "\(screen)-\(fixture)-scroll-\(page)")
                    }
                }
                app.terminate()
            }
        }
    }

    func testTabNavigationAndCounterSettings() {
        let app = launch()
        app.buttons["tab-history"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen-history"].waitForExistence(timeout: 3))
        app.buttons["tab-settings"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen-settings"].waitForExistence(timeout: 3))
        let counter = app.buttons["open-counter"]
        if !counter.isHittable { app.swipeUp() }
        counter.tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen-counter"].waitForExistence(timeout: 3))
        capture(app, name: "counter-from-settings")
        app.buttons["tab-home"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen-home"].waitForExistence(timeout: 3))
    }

    func testInvestEntryKeepsMode() {
        let app = launch()
        let invest = app.buttons["start-invest"]
        if !invest.isHittable { app.swipeUp() }
        invest.tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen-measurement"].waitForExistence(timeout: 3))
        // The INVEST-only form is evidence of mode preservation, beyond a highlighted tab.
        XCTAssertTrue(app.textFields["例：個人開発"].exists)
        capture(app, name: "measurement-invest-entry")
    }

    func testRealMeasurementIncreasesAndSurvivesRelaunch() {
        let app = launch("settings")
        let open = app.buttons["open-pip"]
        for _ in 0..<5 where !open.isHittable { app.swipeUp() }
        open.tap()
        let start = app.buttons["pip-start-session"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        let amount = app.staticTexts["pip-current-amount"]
        let increased = NSPredicate(format: "label CONTAINS %@ AND NOT (label CONTAINS %@)", "計測中", "¥0.00")
        expectation(for: increased, evaluatedWith: amount)
        waitForExpectations(timeout: 8)
        capture(app, name: "pip-real-inline-money")
        app.buttons["pip-stop-session"].tap()
        for _ in 0..<5 where !app.staticTexts["保存済み"].firstMatch.exists { app.swipeUp() }
        XCTAssertTrue(app.staticTexts["保存済み"].firstMatch.waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        let reopened = app.buttons["open-pip"]
        for _ in 0..<5 where !reopened.isHittable { app.swipeUp() }
        reopened.tap()
        for _ in 0..<5 where !app.staticTexts["保存済み"].firstMatch.exists { app.swipeUp() }
        XCTAssertTrue(app.staticTexts["保存済み"].firstMatch.waitForExistence(timeout: 5))
        capture(app, name: "pip-saved-after-relaunch")
    }

    func testOnboardingAllStepsAndFinish() {
        let app = launch("onboarding")
        for step in 1...6 {
            capture(app, name: "onboarding-step-\(step)")
            let next = app.buttons[step == 6 ? "onboarding-finish" : "onboarding-next"]
            for _ in 0..<4 where !next.isHittable { app.swipeUp() }
            next.tap()
            if step < 6 { app.swipeDown() }
        }
        XCTAssertTrue(app.descendants(matching: .any)["screen-home"].waitForExistence(timeout: 5))
    }

    func testHistoryOpensSelectedReceipt() {
        let app = launch("history")
        let row = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "history-record-", "Instagram"
        )).firstMatch
        for _ in 0..<6 where !row.isHittable { app.swipeUp() }
        XCTAssertTrue(row.exists)
        row.tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen-receipt"].waitForExistence(timeout: 5))
        let preview = app.otherElements["receipt-preview"]
        XCTAssertTrue(preview.label.contains("Instagram"), "Receipt must match the selected history row")
        capture(app, name: "receipt-selected-instagram")
    }

    func testWhatIfSkipReplayAndModeChange() {
        let app = launch("whatif")
        let story = app.descendants(matching: .any)["whatif-interview"].firstMatch
        story.tap()
        XCTAssertEqual(story.value as? String, "SPEND・全文表示")
        for page in 1...3 {
            app.swipeUp()
            capture(app, name: "whatif-completed-scroll-\(page)")
        }
        let replay = app.buttons["whatif-replay"]
        for _ in 0..<3 where !replay.isHittable { app.swipeDown() }
        replay.tap()
        XCTAssertEqual(story.value as? String, "SPEND・再生中")
        let invest = app.buttons["whatif-mode-invest"]
        for _ in 0..<5 where !invest.isHittable { app.swipeDown() }
        invest.tap()
        XCTAssertEqual(story.value as? String, "INVEST・再生中")
        story.tap()
        XCTAssertEqual(story.value as? String, "INVEST・全文表示")
        capture(app, name: "whatif-invest-completed")
    }

    func testLiveActivitySurfacePreviews() {
        let app = launch("counter")
        let delivery = app.buttons["delivery-liveActivity"]
        for _ in 0..<3 where !delivery.isHittable { app.swipeUp() }
        delivery.tap()
        capture(app, name: "counter-live-activity-selected")
        for page in 1...5 {
            app.swipeUp()
            capture(app, name: "counter-live-activity-surfaces-\(page)")
        }
        XCTAssertTrue(app.otherElements["live-preview-expanded"].exists)
    }
}
