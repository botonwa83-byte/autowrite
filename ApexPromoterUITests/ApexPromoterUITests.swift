import XCTest

final class ApexPromoterUITests: XCTestCase {
    func testRootShowsDashboard() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Apex 宣传台"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["tab.products"].exists)
        XCTAssertTrue(app.tabBars.buttons["tab.composer"].exists)
        XCTAssertTrue(app.tabBars.buttons["tab.queue"].exists)
    }
}
