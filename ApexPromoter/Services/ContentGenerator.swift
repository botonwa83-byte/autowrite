import Foundation

struct GeneratedContent { var title: String; var body: String; var tags: String }

struct PlannedPost {
    let scheduledAt: Date
    let platform: PublishPlatform
    let angle: String
}

struct PerformanceSnapshot {
    let platform: PublishPlatform
    let angle: String
    let impressions: Int
    let likes: Int
    let saves: Int
    let comments: Int
    let linkClicks: Int
    let downloads: Int
}

struct PerformanceBreakdown: Identifiable {
    let name: String
    let impressions: Int
    let interactions: Int
    let linkClicks: Int
    let downloads: Int
    let score: Double
    var id: String { name }
}

struct PerformanceReview {
    let bestPlatform: PublishPlatform?
    let bestAngle: String?
    let recommendation: String
    let platforms: [PerformanceBreakdown]
}

enum PerformanceAnalyzer {
    static func review(_ snapshots: [PerformanceSnapshot]) -> PerformanceReview {
        let recorded = snapshots.filter { $0.impressions + $0.likes + $0.saves + $0.comments + $0.linkClicks + $0.downloads > 0 }
        guard !recorded.isEmpty else {
            return PerformanceReview(bestPlatform: nil, bestAngle: nil, recommendation: "先记录已发布内容的曝光、互动、点击和下载，再生成下一周期建议。", platforms: [])
        }

        let platformRows = Dictionary(grouping: recorded, by: \.platform).map { platform, rows in
            breakdown(name: platform.rawValue, rows: rows)
        }.sorted { $0.score > $1.score }
        let angleRows = Dictionary(grouping: recorded.filter { !$0.angle.isEmpty }, by: \.angle).map { angle, rows in
            breakdown(name: angle, rows: rows)
        }.sorted { $0.score > $1.score }
        let bestPlatform = platformRows.first.flatMap { row in PublishPlatform(rawValue: row.name) }
        let bestAngle = angleRows.first?.name
        let platformText = bestPlatform?.rawValue ?? "已有平台"
        let angleText = bestAngle.map { "「\($0)」" } ?? "已有内容方向"
        return PerformanceReview(bestPlatform: bestPlatform, bestAngle: bestAngle, recommendation: "下一周期优先继续验证\(platformText)和\(angleText)，同时保留其他平台作为对照。结论基于当前手工记录，新增数据后会自动更新。", platforms: platformRows)
    }

    private static func breakdown(name: String, rows: [PerformanceSnapshot]) -> PerformanceBreakdown {
        let impressions = rows.reduce(0) { $0 + max($1.impressions, 0) }
        let interactions = rows.reduce(0) { $0 + max($1.likes, 0) + max($1.saves, 0) + max($1.comments, 0) }
        let clicks = rows.reduce(0) { $0 + max($1.linkClicks, 0) }
        let downloads = rows.reduce(0) { $0 + max($1.downloads, 0) }
        let reach = Double(max(impressions, 1))
        let score = Double(downloads) * 1_000 + Double(clicks) * 10 + Double(interactions) / reach * 100
        return PerformanceBreakdown(name: name, impressions: impressions, interactions: interactions, linkClicks: clicks, downloads: downloads, score: score)
    }
}

enum PromotionPlanBuilder {
    private static let angles = ["痛点共鸣", "真实场景", "核心价值", "使用方法", "常见异议", "产品差异", "行动邀请"]

    static func build(durationDays: Int, postsPerWeek: Int, startDate: Date, platforms: [PublishPlatform]) -> [PlannedPost] {
        guard durationDays > 0, postsPerWeek > 0, !platforms.isEmpty else { return [] }
        let count = max(1, Int(ceil(Double(durationDays * postsPerWeek) / 7.0)))
        let interval = Double(durationDays * 86400) / Double(count)
        return (0..<count).map { index in
            PlannedPost(
                scheduledAt: startDate.addingTimeInterval(Double(index) * interval),
                platform: platforms[index % platforms.count],
                angle: angles[index % angles.count]
            )
        }
    }
}

enum PromotionProjectFactory {
    static func makeProject(
        product: CustomerProduct,
        brand: BrandWorkspace,
        goal: PromotionGoal? = nil,
        insights: [AudienceInsight],
        angle: String? = nil,
        platform: PublishPlatform = .xiaohongshu,
        scheduledAt: Date? = nil,
        planID: UUID? = nil
    ) -> PromotionProject {
        let benefits = product.keyBenefits.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let insightContext = insights.filter { $0.evidenceState == .verified }
            .map { "\($0.category.title)：\($0.statement)" }
            .joined(separator: "\n")
        let resolvedAngle = angle ?? goal?.kind.title ?? ""
        let sourceURL = product.websiteURL.isEmpty ? product.storeURL : product.websiteURL
        let generated = LocalContentGenerator().generate(
            productName: product.name,
            audience: product.audience,
            summary: product.summary,
            benefits: benefits,
            sourceURL: sourceURL,
            goalAction: goal?.primaryAction ?? "",
            insightContext: insightContext,
            angle: resolvedAngle,
            tone: brand.brandVoice
        )
        let project = PromotionProject(
            title: generated.title,
            productID: product.id.uuidString,
            contentType: platform.isVideo ? .video : .text,
            platform: platform.rawValue,
            body: generated.body,
            tags: generated.tags
        )
        project.sourceProductName = product.name
        project.sourceAudience = product.audience
        project.sourceSummary = product.summary
        project.sourceBenefits = product.keyBenefits
        project.sourceURL = sourceURL
        project.brandVoice = brand.brandVoice
        project.sourceGoalContext = goal?.generationContext ?? ""
        project.sourceGoalAction = goal?.primaryAction ?? ""
        project.sourceGoalID = goal?.id
        project.sourceInsightContext = insightContext
        project.sourcePlanID = planID
        project.sourceAngle = resolvedAngle
        project.scheduledAt = scheduledAt
        if scheduledAt != nil { project.publishStatus = .ready }
        return project
    }

    static func makeBatch(
        product: CustomerProduct,
        brand: BrandWorkspace,
        goal: PromotionGoal?,
        plan: PromotionPlan,
        insights: [AudienceInsight]
    ) -> [PromotionProject] {
        PromotionPlanBuilder.build(
            durationDays: plan.durationDays,
            postsPerWeek: plan.postsPerWeek,
            startDate: plan.startDate,
            platforms: plan.platforms
        ).map { post in
            makeProject(
                product: product,
                brand: brand,
                goal: goal,
                insights: insights,
                angle: post.angle,
                platform: post.platform,
                scheduledAt: post.scheduledAt,
                planID: plan.id
            )
        }
    }
}

protocol ContentGenerating { func generate(product: ProductSeed, angle: String, tone: String) -> GeneratedContent }
struct LocalContentGenerator: ContentGenerating {
    func generate(productName: String, audience: String, summary: String, benefits: [String], sourceURL: String, goalAction: String = "", insightContext: String = "", angle: String, tone: String) -> GeneratedContent {
        let focus = angle.isEmpty ? "产品如何解决真实问题" : angle
        let points = benefits.isEmpty ? [summary] : benefits
        let title = "\(productName)｜\(focus)"
        let actionSection = goalAction.isEmpty ? "" : "\n\n下一步\n\(goalAction)"
        let insightSection = insightContext.isEmpty ? "" : "\n\n客户洞察\n\(insightContext)"
        let body = "如果你正在寻找适合\(audience)的解决方案，可以先了解 \(productName)。\n\n产品定位\n\(summary)\n\n核心价值\n" + points.filter { !$0.isEmpty }.map { "· \($0)" }.joined(separator: "\n") + insightSection + actionSection + "\n\n建议先从一个真实使用场景开始体验，再判断它是否适合自己的需求。\n\n了解更多\n\(sourceURL)"
        return GeneratedContent(title: title, body: body, tags: "#\(productName) #产品体验 #效率工具 #独立开发")
    }
    func generate(product: ProductSeed, angle: String, tone: String, websiteBrief: WebsitePromotionBrief? = nil) -> GeneratedContent {
        var generated = generate(product: product, angle: angle, tone: tone)
        if let brief = websiteBrief {
            let points = brief.highlights.isEmpty ? product.claims : brief.highlights
            generated.body = "\(product.promoHook)\n\n产品定位\n\(brief.positioning)\n\n适合人群\n\(brief.audience)\n\n核心亮点\n" + points.map { "· \($0)" }.joined(separator: "\n") + "\n\n了解更多\n\(product.sourceURL)"
        }
        return generated
    }
    func generate(product: ProductSeed, angle: String, tone: String) -> GeneratedContent {
        let hook = product.promoHook
        let title = "\(product.name)｜\(angle.isEmpty ? "把学习方法真正用起来" : angle)"
        let availability = product.isReleased ? "下载地址：\(product.storeURL)" : "产品状态：上架准备中，可关注首批体验进展"
        let body = "\(hook)\n\n产品定位\n\(product.summary)\n\n我会这样用：\n1. 先选一个正在卡住的模块；\n2. 跟着产品里的结构化路径走一遍；\n3. 把没掌握的地方留下标记，下一次复习直接回到现场。\n\n这套产品目前提供：\n· \(product.claims.joined(separator: "\n· "))\n\n它更适合\(product.audience)做长期、低压力的日常学习。先用一个模块感受是否适合自己的节奏，再决定是否购买完整功能。\n\n开发者：\(product.developer)\n\(availability)\n产品介绍：\(product.sourceURL)\n\n*文中信息来自产品公开资料，具体功能和价格请以 App Store 页面为准。*"
        return .init(title: title, body: body, tags: "#\(product.name) #学习方法 #自律学习 #教育App #学习打卡")
    }
}
