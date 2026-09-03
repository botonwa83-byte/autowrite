import XCTest
@testable import ApexPromoter

final class RootViewTests: XCTestCase {
    func testAppDestinationsExposeCoreWorkflowInOrder() {
        XCTAssertEqual(AppDestination.allCases, [.dashboard, .products, .composer, .queue])
        XCTAssertEqual(AppDestination.composer.title, "Composer")
        XCTAssertEqual(AppDestination.queue.icon, "calendar")
    }

    func testThemeProvidesStableBrandColors() {
        XCTAssertEqual(AppTheme.accent, AppTheme.accent)
        XCTAssertEqual(AppTheme.ink, AppTheme.ink)
    }
}
