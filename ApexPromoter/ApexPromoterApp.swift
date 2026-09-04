import SwiftUI
import SwiftData

@main
struct ApexPromoterApp: App {
    #if DEBUG
    @StateObject private var entitlements = EntitlementStore(previewState: .premium)
    #else
    @StateObject private var entitlements = EntitlementStore()
    #endif
    private let modelContainer: ModelContainer = {
        let schema = Schema([BrandWorkspace.self, CustomerProduct.self, AudienceInsight.self, PromotionGoal.self, PromotionPlan.self, Product.self, ContentDraft.self, ReviewEvent.self, Asset.self, PromotionProject.self, ProjectAsset.self, ProjectVersion.self, PublishAttempt.self])
        do {
            let applicationSupport = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            try FileManager.default.createDirectory(at: applicationSupport, withIntermediateDirectories: true)
            return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: applicationSupport.appendingPathComponent("ApexPromoter.store")))
        } catch {
            fatalError("无法初始化本地项目数据库：\(error.localizedDescription)")
        }
    }()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(entitlements)
                #if !DEBUG
                .task { await entitlements.refresh() }
                #endif
        }
        .modelContainer(modelContainer)
    }
}
