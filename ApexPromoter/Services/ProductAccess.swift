import Foundation

/// 免费 / 专业版的免费额度边界。
///
/// Apex 系列（含 WordPulse）是官方自研、用于自身推广的产品，免费用户可以直接用它们
/// 走完生成、导出、排期和复盘的全流程。只有「建立并使用自己的品牌与产品」需要一次性
/// 解锁专业版。所有解锁判断都集中在这里，视图不直接判断 StoreKit 交易细节。
enum ProductAccess {
    /// 内置品牌名称。用于 bootstrap 标记缺失时兜底（例如写标记前崩溃导致重复 seed）。
    static let builtInBrandName = "Apex 系列"

    /// 官方内置目录的产品 id（固定字符串，如 "physicsapex"）。
    /// 注意必须基于 `ProductCatalog.seeds` 而不是 `apexSeeds`：WordPulse 也是官方自研产品，
    /// 但不以 "apex" 结尾。
    static let builtInCatalogIDs: Set<String> = Set(ProductCatalog.seeds.map(\.id))

    /// 品牌是否官方内置。
    static func isBuiltIn(_ brand: BrandWorkspace, in defaults: UserDefaults = .standard) -> Bool {
        if let marker = defaults.string(forKey: ApexPortfolioBootstrap.markerKey),
           brand.id.uuidString == marker { return true }
        return brand.name == builtInBrandName
    }

    /// 产品是否官方内置：命中固定目录 id，或所属品牌为内置品牌。
    ///
    /// `ProductSeed` 不携带 brandID，所以需要 `products` 反查所属品牌。
    static func isBuiltIn(
        productID: String,
        brands: [BrandWorkspace],
        products: [CustomerProduct],
        in defaults: UserDefaults = .standard
    ) -> Bool {
        if builtInCatalogIDs.contains(productID) { return true }
        guard let productUUID = UUID(uuidString: productID),
              let product = products.first(where: { $0.id == productUUID }),
              let brand = brands.first(where: { $0.id == product.brandID }) else { return false }
        return isBuiltIn(brand, in: defaults)
    }

    /// 是否允许为该产品创建推广项目。
    static func canPromote(
        productID: String,
        isPremium: Bool,
        brands: [BrandWorkspace],
        products: [CustomerProduct],
        in defaults: UserDefaults = .standard
    ) -> Bool {
        isPremium || isBuiltIn(productID: productID, brands: brands, products: products, in: defaults)
    }
}
