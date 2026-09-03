import XCTest
@testable import ApexPromoter

final class ContentTests: XCTestCase {
    func testGeneratorUsesProductFacts() {
        let p = ProductCatalog.seeds[0]; let c = LocalContentGenerator().generate(product: p, angle: "高效复习", tone: "真诚")
        XCTAssertTrue(c.title.contains(p.name)); XCTAssertTrue(c.body.contains(p.summary)); XCTAssertFalse(c.tags.isEmpty)
    }
    func testValidatorAcceptsGeneratedContent() { let p = ProductCatalog.seeds[0]; let c = LocalContentGenerator().generate(product: p, angle: "", tone: ""); XCTAssertFalse(ContentValidator.validate(c, product: p).contains(where: { $0.blocking })) }
}
