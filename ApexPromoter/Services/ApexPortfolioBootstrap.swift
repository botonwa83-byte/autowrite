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
        guard defaults.string(forKey: markerKey) == nil else { return nil }

        let brand = BrandWorkspace(
            name: "Apex 系列",
            brandVoice: "专业、真诚、清晰，以真实产品能力和学习场景为依据",
            prohibitedWords: "保证提分、百分百、最强"
        )
        context.insert(brand)

        var projectCount = 0
        for (index, seed) in ProductCatalog.builtInSeeds.enumerated() {
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
            projectCount += projects.count
            plan.generatedAt = now
        }

        do {
            try context.save()
            defaults.set(brand.id.uuidString, forKey: markerKey)
            return ApexPortfolioBootstrapResult(
                productCount: ProductCatalog.builtInSeeds.count,
                projectCount: projectCount
            )
        } catch {
            context.rollback()
            throw error
        }
    }
}

@ModelActor
actor ApexPortfolioSeedWorker {
    func seedIfNeeded(now: Date = Date()) throws -> ApexPortfolioBootstrapResult? {
        modelContext.autosaveEnabled = false
        return try ApexPortfolioBootstrap.seedIfNeeded(in: modelContext, now: now)
    }
}
