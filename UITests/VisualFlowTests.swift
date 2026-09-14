import XCTest

final class VisualFlowTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(_ screen: String = "home", fixture: String = "populated", trackingMode: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--screen", screen, "--fixture", fixture]
        if let trackingMode {
            app.launchEnvironment["MOSHIDOPA_UI_TEST_TRACKING_MODE"] = trackingMode
        }
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

    private func captureSystemScreen(name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testFourPiPStylesReachRealVideoSurface() {
        for style in ["paper", "ink", "frost", "sticker"] {
            let app = launch("counter")
            let pip = app.buttons["delivery-pip"]
            for _ in 0..<3 where !pip.isHittable { app.swipeUp() }
            XCTAssertTrue(pip.waitForExistence(timeout: 3))
            pip.tap()
            let choice = app.buttons["counter-style-\(style)"]
            for _ in 0..<8 where !choice.isHittable { app.swipeUp() }
            XCTAssertTrue(choice.isHittable)
            choice.tap()
            capture(app, name: "pip-style-preview-\(style)")
            let open = app.buttons["open-pip"]
            for _ in 0..<8 where !open.isHittable { app.swipeUp() }
            XCTAssertTrue(open.isHittable)
            open.tap()
            XCTAssertTrue(app.buttons["pip-start-session"].waitForExistence(timeout: 5))
            sleep(1)
            capture(app, name: "pip-style-real-\(style)")
        }
    }

    func testAutomationGuideResumesWithoutClaimingSystemSetup() {
        let app = launch("counter")
        let entry = app.buttons["counter-automation-setup"]
        for _ in 0..<10 where !entry.isHittable { app.swipeUp() }
        XCTAssertTrue(entry.isHittable)
        entry.tap()
        let reset = app.buttons["別のアプリを設定／最初から見直す"]
        if reset.exists {
            for _ in 0..<5 where !reset.isHittable { app.swipeUp() }
            reset.tap()
        }
        XCTAssertTrue(app.textFields["automation-target"].waitForExistence(timeout: 3))
        app.buttons["Instagram"].tap()
        app.buttons["automation-next"].tap()
        XCTAssertEqual(app.staticTexts["automation-step-title"].label, "オートメーションを作る")
        app.terminate()
        app.launch()
        let reopened = app.buttons["counter-automation-setup"]
        for _ in 0..<10 where !reopened.isHittable { app.swipeUp() }
        reopened.tap()
        XCTAssertEqual(app.staticTexts["automation-step-title"].label, "オートメーションを作る")
        for _ in 0..<6 {
            let next = app.buttons["automation-next"]
            for _ in 0..<6 where !next.isHittable { app.swipeUp() }
            XCTAssertTrue(next.isHittable)
            next.tap()
            app.swipeDown()
        }
        XCTAssertEqual(app.staticTexts["automation-step-title"].label, "実際に動くか試す")
        capture(app, name: "automation-guide-manual-verification")
        let tryIt = app.buttons["automation-try"]
        for _ in 0..<5 where !tryIt.isHittable { app.swipeUp() }
        tryIt.tap()
        XCTAssertTrue(app.buttons["pip-start-session"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["tracking-mode"].label.contains("対象アプリの開閉（Shortcuts）"))
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
        let app = launch("settings", trackingMode: "background")
        let open = app.buttons["open-pip"]
        for _ in 0..<5 where !open.isHittable { app.swipeUp() }
        open.tap()
        let start = app.buttons["pip-start-session"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["tracking-mode"].label.contains("本体の外にいる時間"))
        start.tap()
        let amount = app.staticTexts["pip-current-amount"]
        let armed = NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "待機・一時停止", "¥0.00")
        expectation(for: armed, evaluatedWith: amount)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(amount.label.contains("待機・一時停止"))
        XCTAssertTrue(amount.label.contains("¥0.00"))

        XCUIDevice.shared.press(.home)
        sleep(3)
        app.activate()

        let pausedAmount = app.staticTexts["pip-current-amount"]
        let backgroundCounted = NSPredicate(format: "label CONTAINS %@ AND NOT (label CONTAINS %@)", "待機・一時停止", "¥0.00")
        expectation(for: backgroundCounted, evaluatedWith: pausedAmount)
        waitForExpectations(timeout: 5)
        let pausedLabel = pausedAmount.label
        XCTAssertTrue(pausedLabel.contains("待機・一時停止"))
        XCTAssertFalse(pausedLabel.contains("¥0.00"))
        capture(app, name: "pip-real-background-money")

        // Returning to the foreground pauses the default background-only counter.
        sleep(2)
        XCTAssertEqual(pausedAmount.label, pausedLabel)
        app.buttons["pip-stop-session"].tap()
        for _ in 0..<5 where !app.staticTexts["保存済み"].firstMatch.exists { app.swipeUp() }
        XCTAssertTrue(app.staticTexts["保存済み"].firstMatch.waitForExistence(timeout: 5))
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "MOSHIDOPA_UI_TEST_TRACKING_MODE")
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

    func testCounterPreviewModeAndSmallAmount() {
        let app = launch("counter")
        let invest = app.buttons["preview-mode-invest"]
        for _ in 0..<4 where !invest.isHittable { app.swipeUp() }
        invest.tap()
        app.buttons["preview-amount-0"].tap()
        let paper = app.buttons["counter-style-paper"]
        for _ in 0..<3 where !paper.isHittable { app.swipeUp() }
        XCTAssertTrue(paper.label.contains("自己投資"))
        XCTAssertTrue(paper.label.contains("¥0.82"))
        capture(app, name: "counter-invest-small")
    }

    func testLiveActivitySurfacePreviews() {
        let app = launch("counter")
        let delivery = app.buttons["delivery-liveActivity"]
        for _ in 0..<3 where !delivery.isHittable { app.swipeUp() }
        delivery.tap()
        let large = app.buttons["preview-amount-2"]
        for _ in 0..<3 where !large.isHittable { app.swipeUp() }
        large.tap()
        capture(app, name: "counter-live-activity-selected-large")
        for page in 1...5 {
            app.swipeUp()
            capture(app, name: "counter-live-activity-surfaces-\(page)")
        }
        XCTAssertTrue(app.otherElements["live-preview-expanded"].exists)
    }

    func testLiveActivitySelectionOpensConfiguredDiagnostics() {
        let app = launch("counter")
        let delivery = app.buttons["delivery-liveActivity"]
        for _ in 0..<3 where !delivery.isHittable { app.swipeUp() }
        XCTAssertTrue(delivery.waitForExistence(timeout: 3))
        delivery.tap()

        let open = app.buttons["open-pip"]
        for _ in 0..<7 where !open.isHittable { app.swipeUp() }
        XCTAssertTrue(open.waitForExistence(timeout: 3))
        open.tap()

        XCTAssertTrue(app.buttons["live-start-window"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["live-authorization"].waitForExistence(timeout: 5))
    }

    func testLiveActivityStartsAndEndsWhenAuthorized() throws {
        let app = launch("counter")
        let delivery = app.buttons["delivery-liveActivity"]
        for _ in 0..<3 where !delivery.isHittable { app.swipeUp() }
        XCTAssertTrue(delivery.waitForExistence(timeout: 3))
        delivery.tap()

        let open = app.buttons["open-pip"]
        for _ in 0..<7 where !open.isHittable { app.swipeUp() }
        XCTAssertTrue(open.waitForExistence(timeout: 3))
        open.tap()

        let authorization = app.staticTexts["live-authorization"]
        XCTAssertTrue(authorization.waitForExistence(timeout: 5))
        guard authorization.label.contains("使用可能") else {
            throw XCTSkip("Live Activity is disabled on this test runtime")
        }

        app.buttons["pip-start-session"].tap()
        let start = app.buttons["live-start-window"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()

        let status = app.staticTexts["external-display-status"]
        let displayed = NSPredicate(format: "label CONTAINS %@", "開始受付済み")
        expectation(for: displayed, evaluatedWith: status)
        waitForExpectations(timeout: 8)
        XCTAssertTrue(status.label.contains("開始受付済み"))
        capture(app, name: "live-activity-started")

        XCUIDevice.shared.press(.home)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let systemMoney = springboard.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@", "更新時点の金額 ¥")
        ).firstMatch
        let moneyVisible = systemMoney.waitForExistence(timeout: 20)
        captureSystemScreen(name: "live-activity-background")
        XCTAssertTrue(moneyVisible, "ActivityKit request succeeded but no money is exposed by the OS Live Activity. This is not a display pass.")
        app.activate()

        app.buttons["pip-stop-session"].tap()
        let ended = NSPredicate(format: "label CONTAINS %@", "終了")
        expectation(for: ended, evaluatedWith: status)
        waitForExpectations(timeout: 8)
        XCTAssertTrue(status.label.contains("終了"))
        capture(app, name: "live-activity-ended")
    }
}
