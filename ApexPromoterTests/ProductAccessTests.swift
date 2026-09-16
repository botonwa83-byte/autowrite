import SwiftData
import XCTest
@testable import ApexPromoter

final class ProductAccessTests: XCTestCase {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([BrandWorkspace.self, CustomerProduct.self])
        return try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
    }

    func testBuiltInCatalogCoversEveryBundledProduct() {
        XCTAssertEqual(ProductAccess.builtInCatalogIDs, Set(ProductCatalog.seeds.map(\.id)))
        // WordPulse 也是官方自研产品，但不以 "apex" 结尾，不能只依赖 apexSeeds。
        XCTAssertTrue(ProductAccess.builtInCatalogIDs.contains("wordpulse"))
        XCTAssertEqual(ProductAccess.builtInCatalogIDs.count, ProductCatalog.apexSeeds.count + 1)
    }

    @MainActor
    func testSeededApexProductsRemainFree() throws {
        let container = try makeContainer()
        let suiteName = "ProductAccessTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let result = try XCTUnwrap(
            ApexPortfolioBootstrap.seedIfNeeded(in: container.mainContext, defaults: defaults)
        )
        let brands = try container.mainContext.fetch(FetchDescriptor<BrandWorkspace>())
        let products = try container.mainContext.fetch(FetchDescriptor<CustomerProduct>())
        XCTAssertEqual(products.count, result.productCount)

        // 免费用户必须能直接用完 Apex 系列的全部产品。
        for product in products {
            XCTAssertTrue(
                ProductAccess.canPromote(
                    productID: product.id.uuidString,
                    isPremium: false,
                    brands: brands,
                    products: products,
                    in: defaults
                ),
                "\(product.name) 应保持免费可用"
            )
        }
    }

    @MainActor
    func testUserOwnedProductsRequirePremium() throws {
        let container = try makeContainer()
        let suiteName = "ProductAccessTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        _ = try ApexPortfolioBootstrap.seedIfNeeded(in: container.mainContext, defaults: defaults)
        let ownBrand = BrandWorkspace(name: "我的品牌")
        container.mainContext.insert(ownBrand)
        let ownProduct = CustomerProduct(brandID: ownBrand.id, name: "我的产品")
        container.mainContext.insert(ownProduct)

        let brands = try container.mainContext.fetch(FetchDescriptor<BrandWorkspace>())
        let products = try container.mainContext.fetch(FetchDescriptor<CustomerProduct>())

        XCTAssertFalse(ProductAccess.isBuiltIn(ownBrand, in: defaults))
        XCTAssertFalse(
            ProductAccess.canPromote(
                productID: ownProduct.id.uuidString,
                isPremium: false,
                brands: brands,
                products: products,
                in: defaults
            )
        )
        XCTAssertTrue(
            ProductAccess.canPromote(
                productID: ownProduct.id.uuidString,
                isPremium: true,
                brands: brands,
                products: products,
                in: defaults
            )
        )
    }

    @MainActor
    func testUnknownProductIdentifierIsNotBuiltIn() throws {
        let container = try makeContainer()
        let products = try container.mainContext.fetch(FetchDescriptor<CustomerProduct>())
        XCTAssertFalse(ProductAccess.isBuiltIn(productID: UUID().uuidString, brands: [], products: products))
        XCTAssertFalse(ProductAccess.isBuiltIn(productID: "not-a-product", brands: [], products: products))
        // 固定目录 id 走快路径，无需品牌记录也能判定为内置。
        XCTAssertTrue(ProductAccess.isBuiltIn(productID: "physicsapex", brands: [], products: []))
    }

    func testBuiltInBrandFallsBackToNameWhenMarkerIsMissing() {
        let suiteName = "ProductAccessTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertTrue(ProductAccess.isBuiltIn(BrandWorkspace(name: ProductAccess.builtInBrandName), in: defaults))
        XCTAssertFalse(ProductAccess.isBuiltIn(BrandWorkspace(name: "我的品牌"), in: defaults))

        // 标记存在时以标记为准。
        let marked = BrandWorkspace(name: "我的品牌")
        defaults.set(marked.id.uuidString, forKey: ApexPortfolioBootstrap.markerKey)
        XCTAssertTrue(ProductAccess.isBuiltIn(marked, in: defaults))
    }
}
