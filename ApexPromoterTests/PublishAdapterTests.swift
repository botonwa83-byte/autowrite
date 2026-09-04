import XCTest
@testable import ApexPromoter

final class PublishAdapterTests: XCTestCase {
    func testAllCommercialPlatformsAreAvailable() {
        XCTAssertEqual(PublishPlatform.allCases.count, 7)
        XCTAssertEqual(Set(PublishPlatform.allCases.map(\.rawValue)), Set(["小红书", "微信公众号", "微信朋友圈", "知乎", "视频号", "抖音", "快手"]))
    }

    func testLocalAdaptersNeverClaimDirectPublishing() {
        let content = GeneratedContent(title: "标题", body: "正文", tags: "#标签")
        for platform in PublishPlatform.allCases {
            let plan = PublishAdapterRegistry.adapter(for: platform).plan(for: content)
            XCTAssertFalse(plan.actions.contains("directPublish"))
            XCTAssertFalse(plan.formattedText.isEmpty)
        }
    }
}
