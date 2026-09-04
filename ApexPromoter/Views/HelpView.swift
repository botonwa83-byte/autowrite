import SwiftUI

enum AppTab: Hashable {
    case dashboard
    case products
    case brands
    case projects
    case composer
    case queue
}

struct UserGuideStep: Identifiable {
    let number: Int
    let title: String
    let summary: String
    let completion: String
    let icon: String
    let destination: AppTab
    let actionTitle: String

    var id: Int { number }
}

enum UserGuide {
    static let steps: [UserGuideStep] = [
        .init(number: 1, title: "建立品牌和产品", summary: "进入品牌中心，新建品牌并填写品牌语气。添加自己的产品名称、官网和下载地址。", completion: "完成标准：产品详情中已有名称、目标用户和产品定位。", icon: "building.2", destination: .brands, actionTitle: "去建立品牌"),
        .init(number: 2, title: "从官网整理产品资料", summary: "在产品详情点击“读取官网并整理资料”，检查自动提取的定位、人群和亮点，确认准确后再应用。", completion: "完成标准：核心亮点具体、可核实，没有代码或导航文字。", icon: "globe", destination: .brands, actionTitle: "去导入官网"),
        .init(number: 3, title: "记录真实客户洞察", summary: "添加目标人群、使用场景、痛点、异议和竞品差异。只有确有依据的内容才标记为已验证。", completion: "完成标准：至少记录一条已验证洞察，并保留来源。", icon: "person.text.rectangle", destination: .brands, actionTitle: "去记录洞察"),
        .init(number: 4, title: "制定推广目标", summary: "选择下载增长、产品发布或版本更新，填写当前值、目标值、截止日期和希望用户采取的行动。", completion: "完成标准：目标有数字、有期限、有明确行动。", icon: "target", destination: .brands, actionTitle: "去制定目标"),
        .init(number: 5, title: "生成推广计划", summary: "创建 7 天或 30 天计划，选择发布频次和平台。系统会生成不同角度的内容并自动排期。", completion: "完成标准：项目页出现一批已排期内容。", icon: "calendar.badge.plus", destination: .brands, actionTitle: "去生成计划"),
        .init(number: 6, title: "审核并发布内容", summary: "进入项目核对文案、图片或视频，修正平台限制提示。到计划时间后，通过系统分享发布。", completion: "完成标准：发布链接已回填，项目已标记发布结果。", icon: "square.and.arrow.up", destination: .queue, actionTitle: "去发布队列"),
        .init(number: 7, title: "记录效果并复盘", summary: "进入已发布项目填写曝光、互动、点击和下载，再从首页查看平台表现和下一周期建议。", completion: "完成标准：至少一条内容有点击或下载数据。", icon: "chart.xyaxis.line", destination: .projects, actionTitle: "去填写效果")
    ]
}

struct HelpView: View {
    let isFirstRun: Bool
    let onNavigate: (AppTab) -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("从产品资料到推广复盘", systemImage: "megaphone.fill").font(.headline)
                        Text("按顺序完成下面 7 步。每一步都能直接进入对应功能。").foregroundStyle(.secondary)
                    }.padding(.vertical, 4)
                }
                Section("完整流程") {
                    ForEach(UserGuide.steps) { step in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Image(systemName: step.icon).foregroundStyle(.tint).frame(width: 24)
                                Text("\(step.number). \(step.title)").font(.headline)
                            }
                            Text(step.summary)
                            Text(step.completion).font(.caption).foregroundStyle(.secondary)
                            Button { onNavigate(step.destination) } label: { Label(step.actionTitle, systemImage: "arrow.right.circle") }
                        }.padding(.vertical, 6)
                    }
                }
                Section("发布说明") {
                    Label("App 负责生成、排期、导出和复盘；发布前由你确认。", systemImage: "checkmark.shield")
                    Label("不会保存小红书、微信、抖音等平台的账号密码。", systemImage: "lock")
                }
            }
            .navigationTitle(isFirstRun ? "欢迎使用" : "使用指南")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(isFirstRun ? "稍后再看" : "完成", action: onClose) } }
        }
    }
}
