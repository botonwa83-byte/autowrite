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

        XCTAssertEqual(result.productCount, 9)
        XCTAssertEqual(result.projectCount, 27)

        let brands = try container.mainContext.fetch(FetchDescriptor<BrandWorkspace>())
        let products = try container.mainContext.fetch(FetchDescriptor<CustomerProduct>())
        let insights = try container.mainContext.fetch(FetchDescriptor<AudienceInsight>())
        let goals = try container.mainContext.fetch(FetchDescriptor<PromotionGoal>())
        let plans = try container.mainContext.fetch(FetchDescriptor<PromotionPlan>())
        let projects = try container.mainContext.fetch(FetchDescriptor<PromotionProject>())

        XCTAssertEqual(brands.map(\.name), ["Apex 系列"])
        XCTAssertEqual(products.count, 9)
        XCTAssertEqual(insights.count, 18)
        XCTAssertEqual(goals.count, 9)
        XCTAssertEqual(plans.count, 9)
        XCTAssertEqual(projects.count, 27)
        XCTAssertEqual(Set(products.map(\.name)), Set(ProductCatalog.apexSeeds.map(\.name)))
        XCTAssertTrue(ProductCatalog.apexSeeds.allSatisfy(\.isReleased))
        XCTAssertTrue(products.allSatisfy { !$0.storeURL.isEmpty && !$0.websiteSourceExcerpt.isEmpty })
        XCTAssertTrue(insights.allSatisfy { $0.evidenceState == .verified && !$0.sourceURL.isEmpty })
        XCTAssertTrue(goals.allSatisfy { $0.kind == .downloadGrowth && $0.primaryAction.contains("App Store") })
        XCTAssertTrue(plans.allSatisfy { $0.generatedAt == now && $0.plannedPostCount == 3 })
        XCTAssertEqual(Set(projects.map(\.platformRaw)), Set(["小红书", "微信公众号", "抖音"]))
        XCTAssertTrue(projects.allSatisfy { project in
            project.publishStatus == .ready
                && project.scheduledAt != nil
                && project.body.contains("下一步")
                && project.body.contains("App Store")
                && !project.sourceInsightContext.isEmpty
                && project.sourcePlanID != nil
        })

        for project in projects {
            let seed = try XCTUnwrap(ProductCatalog.apexSeeds.first { $0.name == project.sourceProductName })
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
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<CustomerProduct>()), 9)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<PromotionProject>()), 27)
    }
}
