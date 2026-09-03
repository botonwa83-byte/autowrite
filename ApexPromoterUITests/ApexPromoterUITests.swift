import XCTest

final class ApexPromoterUITests: XCTestCase {
    func testRootShowsDashboard() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.navigationBars["Dashboard"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Products"].exists)
        XCTAssertTrue(app.tabBars.buttons["Composer"].exists)
        XCTAssertTrue(app.tabBars.buttons["Queue"].exists)
    }
}
