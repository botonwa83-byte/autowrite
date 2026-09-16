import XCTest
@testable import ApexPromoter

@MainActor
final class EntitlementStoreTests: XCTestCase {
    /// UI 测试用的强制状态不能被启动/前台的自动刷新覆盖。
    func testPreviewPremiumSurvivesRefresh() async {
        let store = EntitlementStore(previewState: .premium)
        await store.refresh()
        XCTAssertTrue(store.isPremium)
        XCTAssertEqual(store.state, .premium)
    }

    func testPreviewFreeSurvivesRefreshAndPurchase() async {
        let store = EntitlementStore(previewState: .free)
        await store.refresh()
        XCTAssertEqual(store.state, .free)

        // 强制状态下一律不发起真实购买，也不应留下错误提示。
        await store.purchase()
        XCTAssertEqual(store.state, .free)
        XCTAssertFalse(store.isPurchasing)
        XCTAssertNil(store.message)
    }

    func testPreviewUnavailableIsReportedAsStoreUnavailable() async {
        let store = EntitlementStore(previewState: .unavailable)
        await store.refresh()
        XCTAssertTrue(store.isStoreUnavailable)
        XCTAssertFalse(store.isPremium)
    }

    /// 商品未配置时不能伪造已购买权益，必须落到 unavailable。
    func testMissingProductIDReportsUnavailable() async {
        let store = EntitlementStore(productID: "")
        await store.refresh()
        XCTAssertEqual(store.state, .unavailable)
        XCTAssertFalse(store.isPremium)
    }
}
