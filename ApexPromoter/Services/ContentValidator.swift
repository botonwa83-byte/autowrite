import Foundation
struct ValidationFinding: Identifiable { let id = UUID(); let message: String; let blocking: Bool }
enum ContentValidator {
    static func validate(_ content: GeneratedContent, product: ProductSeed) -> [ValidationFinding] {
        var f: [ValidationFinding] = []
        if content.title.count > 30 { f.append(.init(message: "标题较长，建议控制在 30 字以内", blocking: false)) }
        let spam = ["加微信", "私聊", "稳赚", "100%", "最强"]
        if spam.contains(where: { content.body.localizedCaseInsensitiveContains($0) }) { f.append(.init(message: "包含高风险营销措辞，请人工修改", blocking: true)) }
        if !product.claims.contains(where: { content.body.contains($0) }) { f.append(.init(message: "正文未引用已审核产品卖点", blocking: true)) }
        if content.tags.isEmpty { f.append(.init(message: "请添加话题标签", blocking: false)) }
        return f
    }
}
