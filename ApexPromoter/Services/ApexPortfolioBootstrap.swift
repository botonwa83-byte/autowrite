import Foundation
import SwiftData

struct ApexPortfolioBootstrapResult {
    let productCount: Int
    let projectCount: Int
}

enum ApexPortfolioBootstrap {
    static let markerKey = "apexPortfolioBootstrapV1"

    @discardableResult
    static func seedIfNeeded(
        in context: ModelContext,
        defaults: UserDefaults = .standard,
        now: Date = Date()
    ) throws -> ApexPortfolioBootstrapResult? {
        // 按缺失补齐，而不是见标记就整体跳过：老安装（目录扩充前已初始化过）
        // 也要能在启动后拿到 WordPulse 与 Top 系列，创作页才有得选。
        let existingProducts = try context.fetch(FetchDescriptor<CustomerProduct>())
        let existingNames = Set(existingProducts.map(\.name))
        let missingSeeds = ProductCatalog.builtInSeeds.filter { !existingNames.contains($0.name) }

        // 同步内置产品的下载地址：产品行创建时会把当时的 storeURL 冻结进库
        // （例如 Top 系列上架前存的是官网地址），上架拿到 App Store 链接后必须回写，
        // 否则产品页与生成文案的下载地址一直是旧的。只修正内置产品，不动用户自建产品。
        var storeURLUpdates = 0
        for seed in ProductCatalog.builtInSeeds where existingNames.contains(seed.name) {
            if let product = existingProducts.first(where: { $0.name == seed.name }),
               product.storeURL != seed.storeURL {
                product.storeURL = seed.storeURL
                storeURLUpdates += 1
            }
        }
        guard !missingSeeds.isEmpty || storeURLUpdates > 0 else { return nil }

        // 内置品牌：优先按 bootstrap 标记找回，其次按名称，最后才新建。
        let builtInBrandName = ProductAccess.builtInBrandName
        let brand: BrandWorkspace
        if let markerID = defaults.string(forKey: markerKey),
           let markerUUID = UUID(uuidString: markerID),
           let marked = try context.fetch(
               FetchDescriptor<BrandWorkspace>(predicate: #Predicate { $0.id == markerUUID })
           ).first {
            brand = marked
        } else if let named = try context.fetch(
            FetchDescriptor<BrandWorkspace>(predicate: #Predicate { $0.name == builtInBrandName })
        ).first {
            brand = named
        } else {
            let created = BrandWorkspace(
                name: ProductAccess.builtInBrandName,
                brandVoice: "专业、真诚、清晰，以真实产品能力和学习场景为依据",
                prohibitedWords: "保证提分、百分百、最强"
            )
            context.insert(created)
            brand = created
        }

        var projectCount = 0
        for (index, seed) in missingSeeds.enumerated() {
            projectCount += seedProduct(seed, index: index, brand: brand, in: context, now: now)
        }

        do {
            try context.save()
            defaults.set(brand.id.uuidString, forKey: markerKey)
            return ApexPortfolioBootstrapResult(
                productCount: missingSeeds.count,
                projectCount: projectCount
            )
        } catch {
            context.rollback()
            throw error
        }
    }

    /// 为一个内置产品补齐资料、洞察、目标、计划与首批推广项目，返回项目数。
    private static func seedProduct(
        _ seed: ProductSeed,
        index: Int,
        brand: BrandWorkspace,
        in context: ModelContext,
        now: Date
    ) -> Int {
        let product = CustomerProduct(
            brandID: brand.id,
            name: seed.name,
            websiteURL: seed.sourceURL,
            storeURL: seed.storeURL,
            audience: seed.audience,
            summary: seed.summary,
            keyBenefits: seed.claims.joined(separator: "\n"),
            priceDescription: "以 App Store 页面为准"
        )
        product.websiteSourceExcerpt = ([seed.summary] + seed.claims).joined(separator: "\n")
        product.websiteImportedAt = now
        context.insert(product)

        let insights = [
            AudienceInsight(
                productID: product.id,
                category: .audience,
                statement: seed.audience,
                evidenceState: .verified,
                sourceURL: seed.sourceURL
            ),
            AudienceInsight(
                productID: product.id,
                category: .scenario,
                statement: seed.claims.joined(separator: "；"),
                evidenceState: .verified,
                sourceURL: seed.sourceURL
            )
        ]
        insights.forEach(context.insert)

        let goal = PromotionGoal(
            productID: product.id,
            kind: .downloadGrowth,
            targetValue: 100,
            deadline: now.addingTimeInterval(30 * 86400),
            primaryAction: seed.isReleased ? "前往 App Store 下载并体验 \(seed.name)" : "前往官网了解 \(seed.name) 的上架进展与下载方式"
        )
        context.insert(goal)

        let plan = PromotionPlan(
            productID: product.id,
            goalID: goal.id,
            durationDays: 7,
            postsPerWeek: 3,
            startDate: now.addingTimeInterval(86400 + Double(index) * 7200),
            platforms: [.xiaohongshu, .wechatOfficial, .douyin]
        )
        context.insert(plan)

        let projects = PromotionProjectFactory.makeBatch(
            product: product,
            brand: brand,
            goal: goal,
            plan: plan,
            insights: insights
        )
        projects.forEach(context.insert)
        plan.generatedAt = now
        return projects.count
    }
}

@ModelActor
actor ApexPortfolioSeedWorker {
    func seedIfNeeded(now: Date = Date()) throws -> ApexPortfolioBootstrapResult? {
        modelContext.autosaveEnabled = false
        return try ApexPortfolioBootstrap.seedIfNeeded(in: modelContext, now: now)
    }
}
