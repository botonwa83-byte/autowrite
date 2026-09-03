import XCTest
import SwiftData
@testable import ApexPromoter

final class ProductCatalogTests: XCTestCase {
    func testBundledFixturesDecodeWithRequiredReviewedFields() throws {
        let fixtures = try ProductCatalog.loadFixtures(from: Bundle(for: ProductCatalogTests.self))

        XCTAssertGreaterThanOrEqual(fixtures.count, 10)
        XCTAssertEqual(Set(fixtures.map(\.id)).count, fixtures.count)
        for fixture in fixtures {
            XCTAssertFalse(fixture.id.isEmpty)
            XCTAssertFalse(fixture.name.isEmpty)
            XCTAssertFalse(fixture.audience.isEmpty)
            XCTAssertFalse(fixture.claims.isEmpty)
            XCTAssertNotNil(URL(string: fixture.siteURL))
            XCTAssertNotNil(URL(string: fixture.storeURL))
            XCTAssertNotNil(URL(string: fixture.sourceURL))
            XCTAssertTrue(fixture.reviewed)
        }
    }

    func testSeedingIsIdempotentAndUpdatesExistingFixture() throws {
        let container = try ModelContainer(
            for: Product.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let fixture = ProductFixture(
            id: "test-apex",
            name: "TestApex",
            tagline: "测试产品",
            audience: ["学生"],
            claims: ["提供练习"],
            storeURL: "https://apps.apple.com/cn/app/id1",
            siteURL: "https://example.com/product",
            sourceURL: "https://example.com/source",
            reviewed: true
        )

        _ = try ProductCatalog.seed([fixture], into: context)
        _ = try ProductCatalog.seed([fixture], into: context)

        let products = try context.fetch(FetchDescriptor<Product>())
        XCTAssertEqual(products.count, 1)
        XCTAssertEqual(products.first?.id, fixture.id)
    }

    func testSeedingExistingFixtureRefreshesReviewedFacts() throws {
        let container = try ModelContainer(
            for: Product.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let original = ProductFixture(
            id: "test-apex",
            name: "TestApex",
            tagline: "旧文案",
            audience: ["学生"],
            claims: ["旧卖点"],
            storeURL: "https://apps.apple.com/cn/app/id1",
            siteURL: "https://example.com/product",
            sourceURL: "https://example.com/source",
            reviewed: true
        )
        let revised = ProductFixture(
            id: original.id,
            name: original.name,
            tagline: "新文案",
            audience: original.audience,
            claims: ["新卖点"],
            storeURL: original.storeURL,
            siteURL: original.siteURL,
            sourceURL: original.sourceURL,
            reviewed: true
        )

        _ = try ProductCatalog.seed([original], into: context)
        _ = try ProductCatalog.seed([revised], into: context)

        let product = try XCTUnwrap(context.fetch(FetchDescriptor<Product>()).first)
        XCTAssertEqual(product.tagline, revised.tagline)
        XCTAssertEqual(product.claims, revised.claims)
    }
}
