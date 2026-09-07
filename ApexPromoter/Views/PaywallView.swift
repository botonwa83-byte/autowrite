import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var entitlements: EntitlementStore
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles.rectangle.stack").font(.system(size: 48)).foregroundStyle(.tint)
            Text("一次性解锁专业版").font(.title2.bold())
            Text("创建自己的推广项目，保存素材，并导出到七大公众平台。")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button { Task { await entitlements.purchase() } } label: { Label("一次性购买专业版", systemImage: "cart") }.buttonStyle(.borderedProminent).accessibilityIdentifier("paywall.purchase")
            Button("恢复购买") { Task { await entitlements.restore() } }.accessibilityIdentifier("paywall.restore")
            if entitlements.state == .unavailable { Text("暂时无法连接 App Store，请稍后重试。").font(.caption).foregroundStyle(.secondary) }
        }.padding(28).navigationTitle("专业版")
    }
}
