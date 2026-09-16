import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var entitlements: EntitlementStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles.rectangle.stack").font(.system(size: 48)).foregroundStyle(.tint)
            Text("一次性解锁专业版").font(.title2.bold())
            Text("Apex 系列产品可以直接免费使用；专业版用于建立并推广你自己的品牌和产品。")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) {
                Label("新建自己的品牌与产品", systemImage: "building.2")
                Label("用自有产品生成、导出和排期内容", systemImage: "square.and.arrow.up")
                Label("保留 Apex 系列的完整免费使用权", systemImage: "checkmark.seal")
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                Task { await entitlements.purchase() }
            } label: {
                if entitlements.isPurchasing {
                    HStack { ProgressView(); Text("正在处理购买") }
                } else {
                    Label("一次性购买专业版", systemImage: "cart")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(entitlements.isPurchasing || entitlements.isStoreUnavailable)
            .accessibilityIdentifier("paywall.purchase")
            Button("恢复购买") { Task { await entitlements.restore() } }
                .disabled(entitlements.isPurchasing)
                .accessibilityIdentifier("paywall.restore")
            if let message = entitlements.message {
                Text(message)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(entitlements.isPremium ? .green : .secondary)
                    .accessibilityIdentifier("paywall.message")
            } else if entitlements.isStoreUnavailable {
                Text("暂时无法连接 App Store，请稍后重试。").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(28)
        .navigationTitle("专业版")
        .task { await entitlements.refresh() }
        .onChange(of: entitlements.state) { _, state in
            // 购买成功后自动关闭，让「已解锁」这件事看得见。
            if state == .premium { dismiss() }
        }
    }
}
