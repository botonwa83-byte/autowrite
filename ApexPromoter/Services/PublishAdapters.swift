import Foundation

struct PublishPlan { let platform: PublishPlatform; let formattedText: String; let actions: [String]; let warning: String? }
protocol PublishAdapter { var platform: PublishPlatform { get }; func plan(for content: GeneratedContent) -> PublishPlan }
struct LocalPublishAdapter: PublishAdapter {
    let platform: PublishPlatform
    func plan(for content: GeneratedContent) -> PublishPlan {
        let text = PlatformFormatter.text(for: platform, content: content)
        return PublishPlan(platform: platform, formattedText: text, actions: ["copy", "export", "share"], warning: "正式直发需要平台官方授权，当前使用系统分享")
    }
}
enum PublishAdapterRegistry { static func adapter(for platform: PublishPlatform) -> any PublishAdapter { LocalPublishAdapter(platform: platform) } }
