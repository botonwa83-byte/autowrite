import Foundation

struct GeneratedContent { var title: String; var body: String; var tags: String }
protocol ContentGenerating { func generate(product: ProductSeed, angle: String, tone: String) -> GeneratedContent }
struct LocalContentGenerator: ContentGenerating {
    func generate(product: ProductSeed, angle: String, tone: String) -> GeneratedContent {
        let title = "\(product.name)：\(angle.isEmpty ? "把学习方法真正用起来" : angle)"
        let body = "给正在准备学习的同学分享一个思路：\n\n\(product.summary)\n\n\(product.claims.joined(separator: "；"))。适合\(product.audience)按自己的节奏使用。建议先体验一个模块，再决定是否纳入日常复习。\n\n内容基于产品公开资料，具体功能请以 App 内实际版本为准。"
        return .init(title: title, body: body, tags: "#\(product.name) #学习方法 #教育产品")
    }
}
