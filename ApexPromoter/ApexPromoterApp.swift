import SwiftUI
import SwiftData

@main
struct ApexPromoterApp: App {
    var body: some Scene {
        WindowGroup { RootView() }
            .modelContainer(for: [Product.self, ContentDraft.self, ReviewEvent.self, Asset.self])
    }
}
