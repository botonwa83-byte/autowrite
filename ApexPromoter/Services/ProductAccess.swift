import Foundation

/// 产品使用权限。
///
/// Apex 系列、WordPulse 与 Top 系列都是官方自研、用于自身推广的产品，
/// 用户自己的品牌与产品同样可以免费建立和推广——本 App 已全面免费，
/// 不再有免费 / 专业版之分。这里只保留「是否官方内置」的判定，
/// 供视图展示「官方自研」标识使用。
enum ProductAccess {
    /// 内置品牌名称。用于 bootstrap 标记缺失时兜底（例如写标记前崩溃导致重复 seed）。
    static let builtInBrandName = "Apex 系列"

    /// 官方内置目录的产品 id（固定字符串，如 "physicsapex"）。
    /// 注意必须基于 `ProductCatalog.seeds` 而不是 `apexSeeds`：WordPulse 与 Top 系列（语数外）
    /// 同属这个产品家族，但不以 "apex" 结尾。
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

    /// 是否允许为该产品创建推广项目。App 已全面免费，一律允许。
    static func canPromote(productID: String) -> Bool { true }
}
