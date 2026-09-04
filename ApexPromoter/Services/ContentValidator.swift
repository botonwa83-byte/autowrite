import Foundation
import UserNotifications

enum PublishPlatform: String, CaseIterable, Identifiable {
    case xiaohongshu = "小红书", wechat = "微信公众号", douyin = "抖音", kuaishou = "快手", zhihu = "知乎"
    var id: String { rawValue }
    var isVideo: Bool { self == .douyin || self == .kuaishou }
}

enum PlatformFormatter {
    static func text(for platform: PublishPlatform, content: GeneratedContent) -> String {
        switch platform {
        case .xiaohongshu: return "\(content.title)\n\n\(content.body)\n\n\(content.tags)"
        case .wechat: return "标题：\(content.title)\n\n摘要：\(content.body.prefix(80))…\n\n正文：\n\(content.body)"
        case .douyin, .kuaishou: return "视频标题：\(content.title)\n\n口播稿：\n大家好，今天分享一个学习方法。\(content.body.prefix(180))…\n\n结尾引导：想了解完整功能，请查看主页官方链接。\n\n话题：\(content.tags)"
        case .zhihu: return "问题标题：\(content.title)\n\n回答：\n\(content.body)\n\n相关话题：\(content.tags)"
        }
    }
}
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

enum ReminderService {
    static func schedule(draftID: UUID, title: String, at date: Date) {
        guard date > Date() else { return }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Apex 发布提醒"
            content.body = "\(title) 已到计划时间，请打开队列确认并分享。"
            content.sound = .default
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let request = UNNotificationRequest(identifier: draftID.uuidString, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
            center.add(request)
        }
    }
}
