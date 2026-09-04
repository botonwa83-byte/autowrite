import XCTest
@testable import ApexPromoter

final class ContentTests: XCTestCase {
    func testGeneratorUsesProductFacts() {
        let p = ProductCatalog.seeds[0]; let c = LocalContentGenerator().generate(product: p, angle: "高效复习", tone: "真诚")
        XCTAssertTrue(c.title.contains(p.name)); XCTAssertTrue(c.body.contains(p.summary)); XCTAssertFalse(c.tags.isEmpty)
    }
    func testValidatorAcceptsGeneratedContent() { let p = ProductCatalog.seeds[0]; let c = LocalContentGenerator().generate(product: p, angle: "", tone: ""); XCTAssertFalse(ContentValidator.validate(c, product: p).contains(where: { $0.blocking })) }
    func testPlatformFormatterKeepsXiaohongshuAndCreatesPlatformSpecificCopy() {
        let content = GeneratedContent(title: "标题", body: "正文", tags: "#学习")
        XCTAssertEqual(PlatformFormatter.text(for: .xiaohongshu, content: content), "标题\n\n正文\n\n#学习")
        XCTAssertTrue(PlatformFormatter.text(for: .wechat, content: content).contains("摘要"))
        XCTAssertTrue(PlatformFormatter.text(for: .douyin, content: content).contains("口播稿"))
        XCTAssertTrue(PlatformFormatter.text(for: .zhihu, content: content).contains("回答"))
    }
}
