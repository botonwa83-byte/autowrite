import Foundation
import StoreKit

@MainActor
final class EntitlementStore: ObservableObject {
    enum State: Equatable { case free, premium, loading, unavailable }
    @Published private(set) var state: State = .loading
    /// 面向用户的购买/恢复结果说明。购买失败必须说出来，不能静默吞掉。
    @Published private(set) var message: String?
    @Published private(set) var isPurchasing = false
    let productID: String
    /// UI 测试用的强制状态。一旦设置，StoreKit 查询和购买都不再执行。
    private let previewState: State?
    private var product: StoreKit.Product?
    private var updatesTask: Task<Void, Never>? = nil

    init(productID: String = "com.kingtop.apexpromoter.premium", previewState: State? = nil) {
        self.productID = productID
        self.previewState = previewState
        if let previewState { state = previewState }
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result, transaction.productID == productID else { continue }
                await transaction.finish()
                await self?.refresh()
            }
        }
    }

    deinit { updatesTask?.cancel() }

    var isPremium: Bool { state == .premium }

    /// 无法连接 App Store 或商品未配置时为真。此时应禁用购买，只保留恢复购买。
    var isStoreUnavailable: Bool { state == .unavailable }

    func refresh() async {
        if let previewState { state = previewState; return }
        guard productID.isEmpty == false else { state = .unavailable; return }
        guard await loadProduct() else { state = .unavailable; return }
        state = (await hasEntitlement()) ? .premium : .free
    }

    func purchase() async {
        if let previewState { state = previewState; return }
        guard isPurchasing == false else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        message = nil

        // 启动时可能还没加载完商品（或加载失败），这里懒加载后继续购买，
        // 而不是直接返回让用户以为按钮坏了。
        if product == nil, await loadProduct() == false {
            state = .unavailable
            message = "暂时无法连接 App Store，请稍后重试。"
            return
        }
        guard let product else {
            state = .unavailable
            message = "暂时无法连接 App Store，请稍后重试。"
            return
        }

        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    message = "购买校验未通过，请重试或使用「恢复购买」。"
                    await refresh()
                    return
                }
                await transaction.finish()
                // 以交易记录为准，不盲信回调结果。
                state = (await hasEntitlement()) ? .premium : .free
                if state == .premium { message = nil }
                else { message = "购买已提交，但权益尚未生效，请稍后点击「恢复购买」。" }
            case .userCancelled:
                break
            case .pending:
                message = "购买待确认，完成后会自动解锁。"
            @unknown default:
                break
            }
        } catch {
            message = "购买未完成：\(error.localizedDescription)"
        }
    }

    func restore() async {
        if let previewState { state = previewState; return }
        message = nil
        await refresh()
        if state == .premium { message = "已恢复专业版权益。" }
        else if state == .free { message = "没有找到可恢复的专业版购买记录。" }
    }

    @discardableResult
    private func loadProduct() async -> Bool {
        guard productID.isEmpty == false else { return false }
        do {
            product = try await StoreKit.Product.products(for: [productID]).first
            return product != nil
        } catch {
            product = nil
            return false
        }
    }

    /// 只认未撤销的已验证交易，退款/撤销后应回到免费。
    private func hasEntitlement() async -> Bool {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.productID == productID,
                  transaction.revocationDate == nil else { continue }
            return true
        }
        return false
    }
}
