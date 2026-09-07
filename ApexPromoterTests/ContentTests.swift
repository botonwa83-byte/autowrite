import XCTest
@testable import ApexPromoter

final class ContentTests: XCTestCase {
    func testCustomerProductConvertsToProductSeed() {
        let product = CustomerProduct(
            brandID: UUID(),
            name: "我的产品",
            websiteURL: "https://example.com",
            storeURL: "https://apps.apple.com/app/id1",
            audience: "学生",
            summary: "帮助学习",
            keyBenefits: "亮点一\n亮点二"
        )

        let seed = ProductCatalog.seed(from: product)

        XCTAssertEqual(seed.id, product.id.uuidString)
        XCTAssertEqual(seed.name, product.name)
        XCTAssertEqual(seed.claims, ["亮点一", "亮点二"])
        XCTAssertEqual(seed.storeURL, product.storeURL)
        XCTAssertTrue(seed.isReleased)
    }

    func testBundledCatalogRemainsAvailableWithoutPremium() {
        XCTAssertFalse(ProductCatalog.seeds.isEmpty)
        XCTAssertTrue(ProductCatalog.seeds.allSatisfy { !$0.name.isEmpty && !$0.sourceURL.isEmpty })
    }

    func testUserGuideCoversCompletePromotionWorkflow() {
        XCTAssertEqual(UserGuide.steps.count, 7)
        XCTAssertEqual(UserGuide.steps.first?.destination, .brands)
        XCTAssertEqual(UserGuide.steps.last?.destination, .projects)
        XCTAssertEqual(Set(UserGuide.steps.map(\.number)), Set(1...7))
    }

    func testAudienceInsightKeepsEvidenceClassification() {
        let insight = AudienceInsight(
            productID: UUID(),
            category: .painPoint,
            statement: "用户没有固定时间持续推广",
            evidenceState: .assumption,
            sourceURL: "https://example.com/interview"
        )

        XCTAssertEqual(insight.category, .painPoint)
        XCTAssertEqual(insight.evidenceState, .assumption)
        XCTAssertEqual(insight.sourceURL, "https://example.com/interview")
    }

    func testPromotionGoalShapesGeneratedContent() {
        let deadline = Date(timeIntervalSince1970: 1_800_000_000)
        let goal = PromotionGoal(
            productID: UUID(),
            kind: .downloadGrowth,
            targetValue: 100,
            deadline: deadline,
            primaryAction: "引导用户下载试用"
        )
        let content = LocalContentGenerator().generate(
            productName: "Demo App",
            audience: "独立开发者",
            summary: "帮助用户推广产品",
            benefits: ["减少内容准备时间"],
            sourceURL: "https://example.com",
            goalAction: goal.primaryAction,
            angle: "",
            tone: "真诚"
        )

        XCTAssertTrue(goal.generationContext.contains("新增下载 100"))
        XCTAssertTrue(content.body.contains("引导用户下载试用"))
        XCTAssertFalse(content.body.contains("新增下载 100"))
    }

    func testPromotionPlanBuildsScheduledPlatformMix() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let posts = PromotionPlanBuilder.build(
            durationDays: 7,
            postsPerWeek: 4,
            startDate: start,
            platforms: [.xiaohongshu, .douyin]
        )

        XCTAssertEqual(posts.count, 4)
        XCTAssertEqual(posts.map(\.platform), [.xiaohongshu, .douyin, .xiaohongshu, .douyin])
        XCTAssertEqual(posts.first?.scheduledAt, start)
        XCTAssertLessThan(posts.last!.scheduledAt, start.addingTimeInterval(7 * 86400))
    }

    func testPerformanceReviewFindsBestPlatformAndAngle() {
        let review = PerformanceAnalyzer.review([
            PerformanceSnapshot(platform: .xiaohongshu, angle: "痛点共鸣", impressions: 1_000, likes: 40, saves: 20, comments: 5, linkClicks: 30, downloads: 12),
            PerformanceSnapshot(platform: .douyin, angle: "真实场景", impressions: 3_000, likes: 80, saves: 5, comments: 8, linkClicks: 20, downloads: 2)
        ])

        XCTAssertEqual(review.bestPlatform, .xiaohongshu)
        XCTAssertEqual(review.bestAngle, "痛点共鸣")
        XCTAssertTrue(review.recommendation.contains("小红书"))
        XCTAssertTrue(review.recommendation.contains("痛点共鸣"))
    }

    func testPerformanceReviewDoesNotInventRecommendationWithoutData() {
        let review = PerformanceAnalyzer.review([])
        XCTAssertNil(review.bestPlatform)
        XCTAssertTrue(review.recommendation.contains("先记录"))
    }

    func testGeneratorUsesProductFacts() {
        let p = ProductCatalog.seeds[0]; let c = LocalContentGenerator().generate(product: p, angle: "高效复习", tone: "真诚")
        XCTAssertTrue(c.title.contains(p.name)); XCTAssertTrue(c.body.contains(p.summary)); XCTAssertFalse(c.tags.isEmpty)
    }
    func testValidatorAcceptsGeneratedContent() { let p = ProductCatalog.seeds[0]; let c = LocalContentGenerator().generate(product: p, angle: "", tone: ""); XCTAssertFalse(ContentValidator.validate(c, product: p).contains(where: { $0.blocking })) }
    func testPlatformFormatterKeepsXiaohongshuAndCreatesPlatformSpecificCopy() {
        let content = GeneratedContent(title: "标题", body: "正文", tags: "#学习")
        XCTAssertEqual(PlatformFormatter.text(for: .xiaohongshu, content: content), "标题\n\n正文\n\n#学习")
        XCTAssertTrue(PlatformFormatter.text(for: .wechatOfficial, content: content).contains("摘要"))
        XCTAssertTrue(PlatformFormatter.text(for: .douyin, content: content).contains("口播稿"))
        XCTAssertTrue(PlatformFormatter.text(for: .zhihu, content: content).contains("回答"))
    }

    func testPlatformLimitReportsOverlongTitle() {
        let content = GeneratedContent(title: String(repeating: "长", count: 40), body: "正文", tags: "#标签")
        XCTAssertTrue(PlatformFormatter.validation(for: .xiaohongshu, content: content).contains { $0.contains("标题") })
    }

    func testProjectPublishedStateSupportsCurrentAndLegacyRecords() {
        let current = PromotionProject(title: "PhysicsApex 推广", productID: "physicsapex")
        current.publishStatus = .published
        XCTAssertTrue(current.isPublished)

        let legacy = PromotionProject(title: "旧项目", productID: "physicsapex")
        legacy.publishStatus = .shared
        legacy.publishedURL = "https://example.com/post"
        XCTAssertTrue(legacy.isPublished)

        let sharedOnly = PromotionProject(title: "仅打开过分享", productID: "physicsapex")
        sharedOnly.publishStatus = .shared
        XCTAssertFalse(sharedOnly.isPublished)
    }
}
