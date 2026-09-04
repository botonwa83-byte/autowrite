import Foundation
import StoreKit

@MainActor
final class EntitlementStore: ObservableObject {
    enum State: Equatable { case free, premium, loading, unavailable }
    @Published private(set) var state: State = .loading
    let productID: String
    private var product: StoreKit.Product?
    init(productID: String = "com.kingtop.apexpromoter.premium", previewState: State? = nil) { self.productID = productID; if let previewState { state = previewState } }
    var isPremium: Bool { state == .premium }
    func refresh() async {
        guard productID.isEmpty == false else { state = .unavailable; return }
        do { product = try await StoreKit.Product.products(for: [productID]).first; guard product != nil else { state = .unavailable; return }; state = await hasEntitlement() ? .premium : .free }
        catch { state = .unavailable }
    }
    func purchase() async {
        guard let product else { await refresh(); return }
        do { if case .success(let verification) = try await product.purchase(), case .verified(let transaction) = verification { await transaction.finish(); state = .premium } }
        catch { }
    }
    func restore() async { await refresh() }
    private func hasEntitlement() async -> Bool {
        for await result in Transaction.currentEntitlements { if case .verified(let transaction) = result, transaction.productID == productID { return true } }
        return false
    }
}
