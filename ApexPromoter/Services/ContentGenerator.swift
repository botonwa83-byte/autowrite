import Foundation

struct GeneratedContent { var title: String; var body: String; var tags: String }
protocol ContentGenerating { func generate(product: ProductSeed, angle: String, tone: String) -> GeneratedContent }
struct LocalContentGenerator: ContentGenerating {
    func generate(product: ProductSeed, angle: String, tone: String) -> GeneratedContent {
        let hook = product.promoHook
        let title = "\(product.name)｜\(angle.isEmpty ? "把学习方法真正用起来" : angle)"
        let body = "\(hook)\n\n我会这样用：\n1. 先选一个正在卡住的模块；\n2. 跟着产品里的结构化路径走一遍；\n3. 把没掌握的地方留下标记，下一次复习直接回到现场。\n\n这套产品目前提供：\n· \(product.claims.joined(separator: "\n· "))\n\n它更适合\(product.audience)做长期、低压力的日常学习。先用一个模块感受是否适合自己的节奏，再决定是否购买完整功能。\n\n开发者：\(product.developer)\n下载地址：\(product.storeURL)\n产品介绍：\(product.sourceURL)\n\n*文中信息来自产品公开资料，具体功能和价格请以 App Store 页面为准。*"
        return .init(title: title, body: body, tags: "#\(product.name) #学习方法 #自律学习 #教育App #学习打卡")
    }
}
