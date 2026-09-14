import XCTest

final class GameplayUITests: XCTestCase {
    @MainActor func testFirstCustomerRackAndRelaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["laptop"].waitForExistence(timeout:15))
        snapshot("01-bedroom")
        app.buttons["laptop"].tap()
        app.buttons["Kunden"].tap()
        let accept = app.buttons["accept-BlockBuilder21"]
        if !accept.isHittable { app.swipeUp() }
        XCTAssertTrue(accept.waitForExistence(timeout:5))
        accept.tap()
        snapshot("02-first-customer")
        app.buttons["close-sheet"].tap()
        XCTAssertTrue(app.staticTexts["1 Kunden"].exists)
        app.buttons["rack-0"].tap()
        snapshot("03-rack")
        XCTAssertTrue(app.staticTexts["Home Rack"].exists)
        app.buttons["close-sheet"].tap()
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.staticTexts["1 Kunden"].waitForExistence(timeout:15))
        app.buttons["door"].tap()
        snapshot("04-garage-goal")
        XCTAssertTrue(app.staticTexts["Garagenschlüssel verdienen"].exists)
    }
    @MainActor private func snapshot(_ name:String) {
        let attachment = XCTAttachment(screenshot:XCUIApplication().screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
