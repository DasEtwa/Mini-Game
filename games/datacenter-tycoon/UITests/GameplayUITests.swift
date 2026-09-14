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
}
