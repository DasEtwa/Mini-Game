import XCTest

final class GameplayUITests: XCTestCase {
    @MainActor func launch(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"] + arguments
        app.launch()
        XCTAssertTrue(app.buttons["laptop"].waitForExistence(timeout: 20))
        return app
    }
    @MainActor func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<10 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable, "Action must be reachable without a bottom overlay")
    }
    @MainActor func close(_ app: XCUIApplication) {
        let close = app.buttons["dismiss-management"]
        XCTAssertTrue(close.isHittable)
        close.tap()
        XCTAssertTrue(app.buttons["laptop"].waitForExistence(timeout: 5))
    }
    @MainActor func testFirstCustomerHardwareAndRelaunch() throws {
        let app = launch()
        XCTAssertEqual(app.scrollViews.count, 0, "The room must never be a scroll feed")
        for id in ["laptop", "rack-0", "door", "free-rack-1"] { XCTAssertTrue(app.buttons[id].isHittable) }
        let initialCash = app.staticTexts["cash-hud"].label
        snapshot("01-bedroom")
        app.buttons["laptop"].tap()
        app.buttons["Kunden"].tap()
        let accept = app.buttons["accept-BlockBuilder21"]
        reveal(accept, in: app); accept.tap()
        snapshot("02-first-customer")
        close(app)
        XCTAssertTrue(app.staticTexts["1 Kunden"].exists)
        app.buttons["rack-0"].tap()
        XCTAssertTrue(app.staticTexts["Home Rack"].exists)
        snapshot("03-rack")
        let server = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'server-'")).firstMatch
        reveal(server, in: app); server.tap()
        let components = app.buttons["open-components"]
        reveal(components, in: app); components.tap()
        let cpu = app.buttons["buy-cpu-home"]
        reveal(cpu, in: app); cpu.tap()
        XCTAssertFalse(app.alerts["Rack & Rich"].exists)
        snapshot("04-hardware-purchase")
        close(app)
        XCTAssertNotEqual(app.staticTexts["cash-hud"].label, initialCash)
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.staticTexts["1 Kunden"].waitForExistence(timeout: 20))
        app.buttons["door"].tap()
        reveal(app.staticTexts["Garagenschlüssel verdienen"], in: app)
        snapshot("05-garage-goal")
        close(app)
        app.buttons["laptop"].tap(); app.buttons["Strom"].tap()
        XCTAssertTrue(app.staticTexts["Familienstrom"].firstMatch.exists)
        close(app)
    }
    @MainActor func testGarageFourRacksAndUpgradeButton() throws {
        let app = launch(["--garage-ui-testing"])
        XCTAssertTrue(app.buttons["rack-3"].isHittable)
        snapshot("06-garage-four-racks")
        app.buttons["rack-0"].tap()
        let upgrade = app.buttons["upgrade-rack-medium"]
        reveal(upgrade, in: app); upgrade.tap()
        XCTAssertTrue(app.staticTexts["Studio Rack"].exists)
        snapshot("07-rack-upgraded")
        close(app)
        app.buttons["rack-3"].tap()
        XCTAssertTrue(app.staticTexts["Garage Rack"].waitForExistence(timeout: 5))
        close(app)
        app.buttons["laptop"].tap(); app.buttons["Dashboard"].tap()
        reveal(app.staticTexts["Live-Ressourcen"], in: app)
        snapshot("08-dashboard")
        close(app)
    }
    @MainActor func testGarageUnlockThroughDoor() throws {
        let app = launch(["--unlock-ui-testing"])
        app.buttons["door"].tap()
        let unlock = app.buttons["unlock-garage"]
        reveal(unlock, in: app)
        XCTAssertTrue(unlock.isEnabled); unlock.tap()
        close(app)
        XCTAssertTrue(app.buttons["free-rack-3"].exists)
        app.buttons["free-rack-3"].tap()
        reveal(app.staticTexts["Garage Rack"], in: app)
        XCTAssertFalse(app.staticTexts["Benötigt: Garage"].exists)
        snapshot("09-garage-shop")
    }
    @MainActor private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIApplication().screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    @MainActor func testOperationsScreensAndStockPurchase() throws {
        let app = launch(["--garage-ui-testing"])
        app.buttons["laptop"].tap()
        reveal(app.buttons["Lager"], in: app); app.buttons["Lager"].tap()
        let buy = app.buttons["stock-buy-cpu-old"]
        reveal(buy, in: app); buy.tap()
        XCTAssertFalse(app.alerts["Rack & Rich"].exists)
        XCTAssertTrue(app.staticTexts["1 Stück"].exists)
        snapshot("10-stock")
        close(app)
        app.buttons["laptop"].tap()
        reveal(app.buttons["Talente"], in: app); app.buttons["Talente"].tap()
        XCTAssertTrue(app.staticTexts["Bekanntheit"].exists)
        snapshot("11-talents")
        close(app)
        app.buttons["laptop"].tap()
        reveal(app.buttons["Aufträge"], in: app); app.buttons["Aufträge"].tap()
        XCTAssertTrue(app.staticTexts["Ein bisschen mehr Leistung, bitte."].exists)
        snapshot("12-jobs")
        close(app)
        app.buttons["laptop"].tap()
        reveal(app.buttons["Mitarbeiter"], in: app); app.buttons["Mitarbeiter"].tap()
        let hire = app.buttons["hire-maintenance"]
        reveal(hire, in: app); hire.tap()
        XCTAssertTrue(app.staticTexts["Mitarbeiter im Dienst"].exists)
        snapshot("13-staff")
        close(app)
    }
    @MainActor func testTutorialCanBeShownAfterAutomaticTimeout() throws {
        let app = launch()
        let dismiss = app.buttons["Tutorial ausblenden"]
        XCTAssertTrue(dismiss.waitForExistence(timeout: 5))
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: dismiss)
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 25), .completed)
        app.buttons["Einstellungen"].tap()
        let show = app.buttons["show-tutorial"]
        reveal(show, in: app); show.tap(); close(app)
        XCTAssertTrue(dismiss.waitForExistence(timeout: 5))
        snapshot("14-tutorial-reopened")
    }
    @MainActor func testRepairTalentJobAndRackPayment() throws {
        let app = launch(["--operations-ui-testing"])
        app.buttons["rack-0"].tap()
        let server = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'server-'")).firstMatch
        reveal(server, in: app); server.tap()
        let repair = app.buttons["repair-from-stock"]
        reveal(repair, in: app); repair.tap()
        XCTAssertFalse(app.alerts["Rack & Rich"].exists)
        XCTAssertFalse(repair.exists)
        close(app)
        app.buttons["laptop"].tap()
        reveal(app.buttons["Talente"], in: app); app.buttons["Talente"].tap()
        let talent = app.buttons["talent-revenue"]
        reveal(talent, in: app); talent.tap()
        XCTAssertTrue(app.staticTexts["1 / 5"].exists)
        snapshot("15-talent-upgraded")
        close(app)
        app.buttons["laptop"].tap()
        reveal(app.buttons["Aufträge"], in: app); app.buttons["Aufträge"].tap()
        let accept = app.buttons["job-accept"]
        reveal(accept, in: app); accept.tap()
        XCTAssertFalse(app.alerts["Rack & Rich"].exists)
        XCTAssertFalse(accept.exists)
        snapshot("16-active-job")
        close(app)
        app.buttons["Simulation fortsetzen"].tap()
        let receipt = app.otherElements["rack-cash-receipt"].firstMatch
        let textReceipt = app.staticTexts["rack-cash-receipt"].firstMatch
        // SwiftUI exposes a Label as either a combined element or static text across OS versions.
        let shown = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in receipt.exists || textReceipt.exists }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [shown], timeout: 5), .completed)
        snapshot("17-rack-payment")
    }
}
