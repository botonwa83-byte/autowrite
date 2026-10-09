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

    func testGeneratedCopyCarriesOfficialSiteAndDownloadAddress() {
        for seed in ProductCatalog.seeds {
            let content = LocalContentGenerator().generate(product: seed, angle: "高效复习", tone: "真诚")
            XCTAssertTrue(content.body.contains(seed.officialSiteURL), seed.name)
            XCTAssertTrue(content.body.contains("下载地址"), seed.name)
            XCTAssertTrue(content.body.contains(seed.downloadURL), seed.name)
        }
    }

    func testWebsiteBriefCopyKeepsOfficialSiteAndDownloadAddress() {
        let seed = ProductCatalog.seeds[0]
        let brief = WebsitePromotionBrief(positioning: "定位说明", audience: "目标人群", highlights: ["亮点一", "亮点二"])
        let content = LocalContentGenerator().generate(product: seed, angle: "", tone: "", websiteBrief: brief)
        XCTAssertTrue(content.body.contains(seed.officialSiteURL))
        XCTAssertTrue(content.body.contains("下载地址"))
    }

    func testTopSeriesIsBundledAndFreeToPromote() {
        let topIDs: Set<String> = ["chintop", "mathtop", "engtop"]
        XCTAssertTrue(topIDs.isSubset(of: Set(ProductCatalog.seeds.map(\.id))))
        for id in topIDs {
            XCTAssertTrue(ProductAccess.canPromote(productID: id), id)
        }
    }

    func testBundledCatalogRemainsAvailableWithoutPremium() {
        XCTAssertFalse(ProductCatalog.seeds.isEmpty)
        XCTAssertTrue(ProductCatalog.seeds.allSatisfy { !$0.name.isEmpty && !$0.sourceURL.isEmpty })
    }

    /// 导出封面/轮播的品牌水印按 `ProductSeed.iconBundlePath` 取图。
    /// 完整复刻 exportCarousel 的绘制顺序：背景 → 截图（带裁剪）→ 图标水印 → 产品名 → 标题。
    /// 曾回归过两次：① 图标按 "ProductIcons" 子目录查找在拍平的 bundle 里永远找不到；
    /// ② drawAspectFill 的 addClip 未恢复状态，把裁剪区之外的水印和标题全部裁掉。
    /// 这里用白色像素按区域断言，两类回归都会被拦下。
    func testExportCoverWatermarkRendersBrandIconForEveryCatalogProduct() throws {
        let size = CGSize(width: 900, height: 1200)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let teal = UIColor(red: 0.12, green: 0.38, blue: 0.48, alpha: 1)
        let outputDir = FileManager.default.temporaryDirectory.appendingPathComponent("cover-icons", isDirectory: true)
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        for seed in ProductCatalog.seeds {
            let path = try XCTUnwrap(seed.iconBundlePath, "\(seed.name) 缺少产品图标文件")
            let icon = try XCTUnwrap(UIImage(contentsOfFile: path), "\(seed.name) 图标无法解码")

            let cover = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
                teal.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
                // 复刻 drawAspectFill：saveGState → addClip → draw → restoreGState
                ctx.cgContext.saveGState()
                UIBezierPath(roundedRect: CGRect(x: 36, y: 126, width: 828, height: 920), cornerRadius: 0).addClip()
                icon.draw(in: CGRect(x: 36, y: 126, width: 828, height: 920))
                ctx.cgContext.restoreGState()
                // 复刻 drawBrand 与标题
                icon.draw(in: CGRect(x: 42, y: 42, width: 64, height: 64))
                let brandAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 30), .foregroundColor: UIColor.white]
                (seed.name as NSString).draw(in: CGRect(x: 122, y: 54, width: 700, height: 44), withAttributes: brandAttrs)
                let titleAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 46), .foregroundColor: UIColor.white]
                ("产品功能亮点" as NSString).draw(in: CGRect(x: 48, y: 1080, width: 804, height: 80), withAttributes: titleAttrs)
            }

            let iconWhites = whitePixels(in: cover, region: CGRect(x: 0, y: 0, width: 500, height: 130))
            let nameWhites = whitePixels(in: cover, region: CGRect(x: 100, y: 40, width: 750, height: 70))
            let titleWhites = whitePixels(in: cover, region: CGRect(x: 40, y: 1070, width: 820, height: 100))
            let detail = "icon=\(iconWhites) name=\(nameWhites) title=\(titleWhites)"
            XCTAssertTrue(iconWhites > 50, "\(seed.name) 品牌图标未绘制（\(detail)）")
            XCTAssertTrue(nameWhites > 50, "\(seed.name) 品牌名未绘制（\(detail)）")
            XCTAssertTrue(titleWhites > 50, "\(seed.name) 封面标题未绘制（\(detail)）")
            try? cover.pngData()?.write(to: outputDir.appendingPathComponent("\(seed.id).png"))
        }
    }

    /// 统计指定区域内接近纯白的像素数（白色文字/图标）。
    /// 显式重绘到 RGBA8 位图再扫描，避免源图 bitmap 字节序/位深差异导致误判。
    private func whitePixels(in image: UIImage, region: CGRect) -> Int {
        guard let cg = image.cgImage else { return 0 }
        let width = Int(region.width), height = Int(region.height)
        guard width > 0, height > 0 else { return 0 }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let ok = pixels.withUnsafeMutableBytes { ptr -> Bool in
            guard let base = ptr.baseAddress,
                  let ctx = CGContext(data: base, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(cg, in: CGRect(x: -region.minX, y: -region.minY, width: CGFloat(cg.width), height: CGFloat(cg.height)))
            return true
        }
        guard ok else { return 0 }
        var count = 0
        var offset = 0
        while offset < pixels.count {
            if pixels[offset] > 235, pixels[offset + 1] > 235, pixels[offset + 2] > 235 { count += 1 }
            offset += 4
        }
        return count
    }

    /// 官网会在多个版块重复放置同一条 App Store 链接，解析必须去重容错——
    /// 曾因 `Dictionary(uniqueKeysWithValues:)` 遇到重复 key 直接崩溃（SIGTRAP，表现为点同步官网死机）。
    func testStoreLinkParsingToleratesDuplicateLinks() {
        let html = """
        <a href="https://apps.apple.com/cn/app/chinapex/id6781556016">ChinApex</a>
        <a href="https://apps.apple.com/cn/app/chinapex/id6781556016">ChinApex 重复</a>
        <a href="https://apps.apple.com/cn/app/engtop/id6815115946?uo=4">EngTop</a>
        <p>没有链接的段落</p>
        """
        let links = WebsiteSyncService.parseStoreLinks(from: html)
        XCTAssertEqual(links["id6781556016"], "https://apps.apple.com/cn/app/chinapex/id6781556016")
        XCTAssertEqual(links["id6815115946?uo=4"], "https://apps.apple.com/cn/app/engtop/id6815115946?uo=4")
        XCTAssertEqual(links.count, 2)
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
