import XCTest
@testable import ApexPromoter

final class WebsiteTextCleanerTests: XCTestCase {
    func testRemovesScriptsAndCodeWhileKeepingChineseSentences() {
        let html = "<html><script>const app = boot()</script><style>.hero{display:none}</style><h1>PhysicsApex 物理学习</h1><p>用结构化路径掌握高中物理核心考点。</p><pre>npm install apex && curl https://example.com</pre><p>支持逐步推导与错题复习。</p></html>"
        let result = WebsiteTextCleaner.clean(html)
        XCTAssertTrue(result.contains("用结构化路径掌握高中物理核心考点"))
        XCTAssertTrue(result.contains("支持逐步推导与错题复习"))
        XCTAssertFalse(result.contains("const app"))
        XCTAssertFalse(result.contains("npm install"))
        XCTAssertFalse(result.contains("display:none"))
    }

    func testParsesCustomerWebsiteIntoStructuredBrief() {
        let text = "清晰账本帮助小团队看懂每日现金流。\n适合没有专职财务的个体商户。\n支持自动分类收支。\n提供每周经营摘要。"
        let brief = WebsitePromotionBrief.parse(
            text,
            fallbackAudience: "小企业用户",
            fallbackSummary: "经营工具",
            fallbackBenefits: []
        )

        XCTAssertEqual(brief.positioning, "清晰账本帮助小团队看懂每日现金流")
        XCTAssertEqual(brief.audience, "适合没有专职财务的个体商户")
        XCTAssertEqual(brief.highlights, ["支持自动分类收支", "提供每周经营摘要"])
    }

    func testCustomerWebsiteParserKeepsProfileFallbacks() {
        let brief = WebsitePromotionBrief.parse(
            "联系我们",
            fallbackAudience: "设计师",
            fallbackSummary: "快速整理灵感",
            fallbackBenefits: ["本地保存"]
        )

        XCTAssertEqual(brief.positioning, "快速整理灵感")
        XCTAssertEqual(brief.audience, "设计师")
        XCTAssertEqual(brief.highlights, ["本地保存"])
    }
}
