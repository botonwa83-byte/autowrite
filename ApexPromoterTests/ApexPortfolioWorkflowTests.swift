import SwiftData
import XCTest
@testable import ApexPromoter

final class ApexPortfolioWorkflowTests: XCTestCase {
    @MainActor
    func testAllApexProductsRunThroughPromotionWorkflow() throws {
        let schema = Schema([
            BrandWorkspace.self,
            CustomerProduct.self,
            AudienceInsight.self,
            PromotionGoal.self,
            PromotionPlan.self,
            PromotionProject.self
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
        let suiteName = "ApexPortfolioWorkflowTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        let result = try XCTUnwrap(
            ApexPortfolioBootstrap.seedIfNeeded(
                in: container.mainContext,
                defaults: defaults,
                now: now
            )
        )

        XCTAssertEqual(result.productCount, 13)
        XCTAssertEqual(result.projectCount, 39)

        let brands = try container.mainContext.fetch(FetchDescriptor<BrandWorkspace>())
        let products = try container.mainContext.fetch(FetchDescriptor<CustomerProduct>())
        let insights = try container.mainContext.fetch(FetchDescriptor<AudienceInsight>())
        let goals = try container.mainContext.fetch(FetchDescriptor<PromotionGoal>())
        let plans = try container.mainContext.fetch(FetchDescriptor<PromotionPlan>())
        let projects = try container.mainContext.fetch(FetchDescriptor<PromotionProject>())

        XCTAssertEqual(brands.map(\.name), ["Apex 系列"])
        XCTAssertEqual(products.count, 13)
        XCTAssertEqual(insights.count, 26)
        XCTAssertEqual(goals.count, 13)
        XCTAssertEqual(plans.count, 13)
        XCTAssertEqual(projects.count, 39)
        XCTAssertEqual(Set(products.map(\.name)), Set(ProductCatalog.builtInSeeds.map(\.name)))
        XCTAssertTrue(ProductCatalog.apexSeeds.allSatisfy(\.isReleased))
        XCTAssertTrue(products.allSatisfy { !$0.storeURL.isEmpty && !$0.websiteSourceExcerpt.isEmpty })
        XCTAssertTrue(insights.allSatisfy { $0.evidenceState == .verified && !$0.sourceURL.isEmpty })
        XCTAssertTrue(goals.allSatisfy { $0.kind == .downloadGrowth && $0.primaryAction.contains("下载") })
        XCTAssertTrue(plans.allSatisfy { $0.generatedAt == now && $0.plannedPostCount == 3 })
        XCTAssertEqual(Set(projects.map(\.platformRaw)), Set(["小红书", "微信公众号", "抖音"]))
        XCTAssertTrue(projects.allSatisfy { project in
            project.publishStatus == .ready
                && project.scheduledAt != nil
                && project.body.contains("下一步")
                && project.body.contains("官网")
                && project.body.contains("下载地址")
                && !project.sourceInsightContext.isEmpty
                && project.sourcePlanID != nil
        })

        for project in projects {
            let seed = try XCTUnwrap(ProductCatalog.builtInSeeds.first { $0.name == project.sourceProductName })
            let content = GeneratedContent(title: project.title, body: project.body, tags: project.tags)
            XCTAssertFalse(ContentValidator.validate(content, product: seed).contains(where: \.blocking))
            XCTAssertFalse(PublishAdapterRegistry.adapter(for: PublishPlatform(rawValue: project.platformRaw)!).plan(for: content).formattedText.isEmpty)
        }

        let published = try XCTUnwrap(projects.first)
        published.publishStatus = .published
        published.publishedURL = "https://example.com/apex-post"
        published.impressions = 1_000
        published.linkClicks = 50
        published.downloads = 10
        XCTAssertTrue(published.isPublished)

        let review = PerformanceAnalyzer.review([
            PerformanceSnapshot(
                platform: PublishPlatform(rawValue: published.platformRaw)!,
                angle: published.sourceAngle,
                impressions: published.impressions,
                likes: published.likes,
                saves: published.saves,
                comments: published.comments,
                linkClicks: published.linkClicks,
                downloads: published.downloads
            )
        ])
        XCTAssertEqual(review.bestPlatform?.rawValue, published.platformRaw)
        XCTAssertEqual(review.bestAngle, published.sourceAngle)

        XCTAssertNil(try ApexPortfolioBootstrap.seedIfNeeded(in: container.mainContext, defaults: defaults, now: now))
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<CustomerProduct>()), 13)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<PromotionProject>()), 39)
    }

    /// 目录扩充前的老安装只有 Apex 系列；再次启动必须补齐 WordPulse 与 Top 系列，
    /// 否则创作页的产品选择器里看不到新家族产品。
    @MainActor
    func testExistingInstallTopsUpMissingFamilyProducts() throws {
        let schema = Schema([
            BrandWorkspace.self,
            CustomerProduct.self,
            AudienceInsight.self,
            PromotionGoal.self,
            PromotionPlan.self,
            PromotionProject.self
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
        let suiteName = "ApexPortfolioWorkflowTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        // 模拟老安装：标记已写入，内置品牌下只有 9 个 Apex 产品，且没有子记录。
        let brand = BrandWorkspace(name: "Apex 系列")
        container.mainContext.insert(brand)
        for seed in ProductCatalog.apexSeeds {
            container.mainContext.insert(CustomerProduct(
                brandID: brand.id,
                name: seed.name,
                websiteURL: seed.sourceURL
            ))
        }
        try container.mainContext.save()
        defaults.set(brand.id.uuidString, forKey: ApexPortfolioBootstrap.markerKey)

        let result = try XCTUnwrap(
            ApexPortfolioBootstrap.seedIfNeeded(in: container.mainContext, defaults: defaults, now: now)
        )

        let products = try container.mainContext.fetch(FetchDescriptor<CustomerProduct>())
        XCTAssertEqual(result.productCount, 4, "应补齐 WordPulse 与 Top 系列共 4 个产品")
        XCTAssertEqual(result.projectCount, 12)
        XCTAssertEqual(products.count, 13)
        XCTAssertEqual(Set(products.map(\.name)), Set(ProductCatalog.builtInSeeds.map(\.name)))

        let topProducts = products.filter { ["ChinTop", "MathTop", "EngTop", "WordPulse"].contains($0.name) }
        XCTAssertEqual(Set(topProducts.map(\.brandID)), Set([brand.id]), "补齐产品应挂在内置品牌下")
        for product in topProducts {
            let id = product.id
            XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<AudienceInsight>(predicate: #Predicate { $0.productID == id })), 2)
            XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<PromotionGoal>(predicate: #Predicate { $0.productID == id })), 1)
            XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<PromotionPlan>(predicate: #Predicate { $0.productID == id })), 1)
            XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<PromotionProject>(predicate: #Predicate { $0.productID == id.uuidString })), 3)
        }

        // 再跑一次应无事可做。
        XCTAssertNil(try ApexPortfolioBootstrap.seedIfNeeded(in: container.mainContext, defaults: defaults, now: now))
    }

    /// 产品上架状态变化后，老库冻结的下载地址要能同步：ChinTop/EngTop 已上架
    /// 应回写 App Store 链接；MathTop 仍在审核，保持官网地址。
    @MainActor
    func testExistingBuiltInProductsSyncStoreURLAfterRelease() throws {
        let schema = Schema([
            BrandWorkspace.self,
            CustomerProduct.self,
            AudienceInsight.self,
            PromotionGoal.self,
            PromotionPlan.self,
            PromotionProject.self
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
        let suiteName = "ApexPortfolioWorkflowTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        // 模拟旧库：全部产品都在，但 storeURL 全是当时冻结的官网地址。
        let brand = BrandWorkspace(name: "Apex 系列")
        container.mainContext.insert(brand)
        for seed in ProductCatalog.builtInSeeds {
            let product = CustomerProduct(brandID: brand.id, name: seed.name, websiteURL: seed.sourceURL)
            product.storeURL = seed.sourceURL
            container.mainContext.insert(product)
        }
        try container.mainContext.save()
        defaults.set(brand.id.uuidString, forKey: ApexPortfolioBootstrap.markerKey)

        let result = try XCTUnwrap(
            ApexPortfolioBootstrap.seedIfNeeded(in: container.mainContext, defaults: defaults, now: now)
        )
        XCTAssertEqual(result.productCount, 0, "没有缺失产品，只做地址同步")
        XCTAssertEqual(result.projectCount, 0)

        let products = try container.mainContext.fetch(FetchDescriptor<CustomerProduct>())
        XCTAssertEqual(products.count, 13)
        for product in products {
            let seed = try XCTUnwrap(ProductCatalog.builtInSeeds.first { $0.name == product.name })
            XCTAssertEqual(product.storeURL, seed.storeURL, "\(product.name) 的下载地址应与目录同步")
        }
        for name in ["ChinTop", "EngTop"] {
            let product = try XCTUnwrap(products.first { $0.name == name })
            XCTAssertTrue(product.storeURL.contains("apps.apple.com"), "\(name) 已上架，下载地址应为 App Store 链接")
        }
        let mathTop = try XCTUnwrap(products.first { $0.name == "MathTop" })
        XCTAssertFalse(mathTop.storeURL.contains("apps.apple.com"), "MathTop 审核中，下载地址应保持官网")

        // 地址已同步，再跑一次应无事可做。
        XCTAssertNil(try ApexPortfolioBootstrap.seedIfNeeded(in: container.mainContext, defaults: defaults, now: now))
    }
}
