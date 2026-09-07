import SwiftUI
import SwiftData

@main
struct ApexPromoterApp: App {
    #if DEBUG
    @StateObject private var entitlements = EntitlementStore(previewState: ProcessInfo.processInfo.arguments.contains("--ui-testing-premium") ? .premium : nil)
    #else
    @StateObject private var entitlements = EntitlementStore()
    #endif
    private let modelContainer: ModelContainer = {
        let schema = Schema([BrandWorkspace.self, CustomerProduct.self, AudienceInsight.self, PromotionGoal.self, PromotionPlan.self, Product.self, ContentDraft.self, ReviewEvent.self, Asset.self, PromotionProject.self, ProjectAsset.self, ProjectVersion.self, PublishAttempt.self])
        let fileManager = FileManager.default
        do {
            if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
                return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
            }
            let applicationSupport = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            try fileManager.createDirectory(at: applicationSupport, withIntermediateDirectories: true)
            let storeURL = applicationSupport.appendingPathComponent("ApexPromoter.store")
            do {
                return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: storeURL))
            } catch {
                // A failed lightweight migration must not leave the app stuck at launch.
                // Preserve the old store and let SwiftData create a clean one.
                let backupURL = applicationSupport.appendingPathComponent("ApexPromoter.store.backup.\(Int(Date().timeIntervalSince1970))")
                for suffix in ["", "-wal", "-shm"] {
                    let source = URL(fileURLWithPath: storeURL.path + suffix)
                    guard fileManager.fileExists(atPath: source.path) else { continue }
                    let destination = URL(fileURLWithPath: backupURL.path + suffix)
                    try? fileManager.moveItem(at: source, to: destination)
                }
                return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: storeURL))
            }
        } catch {
            // Keep the UI launchable even when the device cannot open the
            // persistent store. Data entered in this session remains usable;
            // the next launch retries the persistent store automatically.
            do {
                return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
            } catch {
                fatalError("无法初始化本地项目数据库：\(error.localizedDescription)")
            }
        }
    }()
    var body: some Scene {
        WindowGroup {
            RootView(modelContainer: modelContainer).environmentObject(entitlements)
                #if !DEBUG
                .task { await entitlements.refresh() }
                #endif
        }
        .modelContainer(modelContainer)
    }
}
