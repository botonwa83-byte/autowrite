import SwiftUI
import SwiftData
import UIKit
import PhotosUI

struct ProjectDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var project: PromotionProject
    @Query private var attempts: [PublishAttempt]
    @Query private var assets: [ProjectAsset]
    @Query private var versions: [ProjectVersion]
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var angle = ""
    @State private var tone = "真诚分享"
    @State private var websiteBrief: WebsitePromotionBrief?
    @State private var loadingWebsite = false
    @State private var generationMessage = ""
    @State private var scheduleDate = Date().addingTimeInterval(86400)
    private var platform: PublishPlatform { PublishPlatform(rawValue: project.platformRaw) ?? .xiaohongshu }
    private var product: ProductSeed? { ProductCatalog.seeds.first { $0.id == project.productID } }
    private var content: GeneratedContent { GeneratedContent(title: project.title, body: project.body, tags: project.tags) }
    private var messages: [String] { PlatformFormatter.validation(for: platform, content: content) }
    init(project: PromotionProject) {
        self.project = project
        let id = project.id
        _attempts = Query(filter: #Predicate<PublishAttempt> { $0.projectID == id }, sort: [SortDescriptor(\.createdAt, order: .reverse)])
        _assets = Query(filter: #Predicate<ProjectAsset> { $0.projectID == id }, sort: [SortDescriptor(\.sortOrder)])
        _versions = Query(filter: #Predicate<ProjectVersion> { $0.projectID == id }, sort: [SortDescriptor(\.createdAt, order: .reverse)])
    }
    var body: some View {
        Form {
            Section("项目") {
                TextField("标题", text: $project.title)
                if project.sourceProductName.isEmpty { Picker("关联产品", selection: $project.productID) { ForEach(ProductCatalog.seeds, id: \.id) { Text($0.name).tag($0.id) } } }
                else { LabeledContent("关联产品", value: project.sourceProductName) }
                Picker("内容类型", selection: Binding(get: { project.contentType }, set: { project.contentType = $0 })) { Text("文字").tag(ProjectContentType.text); Text("图文").tag(ProjectContentType.image); Text("视频").tag(ProjectContentType.video) }
                Picker("目标平台", selection: $project.platformRaw) { ForEach(PublishPlatform.allCases) { Text($0.rawValue).tag($0.rawValue) } }
            }
            Section("智能生成") {
                TextField("传播角度", text: $angle)
                TextField("语气", text: $tone)
                Button { loadWebsite() } label: { Label(loadingWebsite ? "正在读取官网" : "读取官网资料", systemImage: "globe") }.disabled(loadingWebsite)
                if websiteBrief != nil { TextEditor(text: Binding(get: { websiteBrief?.editableText ?? "" }, set: { websiteBrief?.editableText = $0 })).frame(minHeight: 110) }
                Button { regenerate() } label: { Label("生成项目文案", systemImage: "wand.and.stars") }
                if !generationMessage.isEmpty { Text(generationMessage).font(.caption).foregroundStyle(.secondary) }
            }
            Section("内容") { TextEditor(text: $project.body).frame(minHeight: 180); TextField("话题标签", text: $project.tags) }
            Section("素材") {
                PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 12, matching: .images) { Label("添加图片素材", systemImage: "photo.badge.plus") }
                    .onChange(of: selectedPhotos) { _, items in importPhotos(items) }
                if !assets.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: 12) {
                            ForEach(Array(assets.enumerated()), id: \.element.id) { index, asset in
                                VStack(spacing: 6) {
                                    if let image = UIImage(data: asset.imageData) { Image(uiImage: image).resizable().scaledToFill().frame(width: 90, height: 90).clipped() }
                                    HStack(spacing: 12) {
                                        Button { move(asset, by: -1) } label: { Image(systemName: "chevron.left") }.disabled(index == 0)
                                        Button(role: .destructive) { delete(asset) } label: { Image(systemName: "trash") }
                                        Button { move(asset, by: 1) } label: { Image(systemName: "chevron.right") }.disabled(index == assets.count - 1)
                                    }.buttonStyle(.borderless)
                                }
                            }
                        }
                    }
                }
            }
            Section("平台预览") {
                Text(PlatformFormatter.text(for: platform, content: content)).textSelection(.enabled)
                Text("标题 \(project.title.count)/\(platform.titleLimit) · 正文 \(project.body.count)/\(platform.bodyLimit)").font(.caption).foregroundStyle(.secondary)
                ForEach(messages, id: \.self) { Label($0, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
                TextField("校验覆盖说明（可选）", text: $project.overrideNote)
            }
            Section("发布操作") {
                Button { copyText() } label: { Label("复制平台文案", systemImage: "doc.on.doc") }
                Button { share() } label: { Label("系统分享", systemImage: "square.and.arrow.up") }.disabled(!messages.isEmpty && project.overrideNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Section("发布计划") {
                DatePicker("发布时间", selection: $scheduleDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                Button { schedule() } label: { Label(project.scheduledAt == nil ? "加入发布队列" : "更新发布时间", systemImage: "calendar.badge.plus") }
                if let date = project.scheduledAt { Text("已排期：\(date.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary) }
            }
            Section("发布结果") {
                TextField("发布链接", text: $project.publishedURL).textInputAutocapitalization(.never).keyboardType(.URL)
                Grid(horizontalSpacing: 12, verticalSpacing: 10) {
                    GridRow { ProjectMetricField(label: "曝光", value: $project.impressions); ProjectMetricField(label: "点赞", value: $project.likes); ProjectMetricField(label: "收藏", value: $project.saves) }
                    GridRow { ProjectMetricField(label: "评论", value: $project.comments); ProjectMetricField(label: "点击", value: $project.linkClicks); ProjectMetricField(label: "下载", value: $project.downloads) }
                }
                Button { markPublished() } label: { Label("保存并标记已发布", systemImage: "checkmark.seal") }
            }
            Section("版本历史") {
                Button { saveVersion() } label: { Label("保存当前版本", systemImage: "clock.arrow.circlepath") }
                ForEach(versions) { snapshot in
                    Button { restore(snapshot) } label: { HStack { Text("v\(snapshot.version)"); Spacer(); Text(snapshot.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary) } }
                }
            }
            if !attempts.isEmpty { Section("发布记录") { ForEach(attempts) { item in VStack(alignment: .leading) { Label(item.action, systemImage: item.succeeded ? "checkmark.circle" : "xmark.circle"); Text(item.createdAt.formatted()).font(.caption).foregroundStyle(.secondary) } } } }
        }
        .navigationTitle("项目详情")
        .onAppear { if let date = project.scheduledAt { scheduleDate = date } }
        .onDisappear { project.updatedAt = Date(); try? context.save() }
    }
    private func record(_ action: String, succeeded: Bool, message: String = "") { context.insert(PublishAttempt(projectID: project.id, platform: platform.rawValue, action: action, succeeded: succeeded, message: message)); try? context.save() }
    private func copyText() { UIPasteboard.general.string = PlatformFormatter.text(for: platform, content: content); record("复制文案", succeeded: true) }
    private func share() { SharePresenter.present(items: [PlatformFormatter.text(for: platform, content: content)]); record("系统分享", succeeded: true); project.publishStatus = .shared }
    private func importPhotos(_ items: [PhotosPickerItem]) {
        Task {
            for (index, item) in items.enumerated() {
                if let data = try? await item.loadTransferable(type: Data.self) { await MainActor.run { context.insert(ProjectAsset(projectID: project.id, filename: "asset-\(project.version)-\(index).jpg", imageData: data, sortOrder: assets.count + index)); try? context.save() } }
            }
            await MainActor.run { selectedPhotos = [] }
        }
    }
    private func saveVersion() { project.version += 1; context.insert(ProjectVersion(projectID: project.id, version: project.version, title: project.title, body: project.body, tags: project.tags, platform: project.platformRaw)); project.updatedAt = Date(); try? context.save() }
    private func restore(_ snapshot: ProjectVersion) { project.title = snapshot.title; project.body = snapshot.body; project.tags = snapshot.tags; project.platformRaw = snapshot.platformRaw; project.version += 1; project.updatedAt = Date(); try? context.save() }
    private func delete(_ asset: ProjectAsset) { context.delete(asset); normalizeAssetOrder(); try? context.save() }
    private func move(_ asset: ProjectAsset, by offset: Int) {
        guard let index = assets.firstIndex(where: { $0.id == asset.id }) else { return }
        let target = index + offset
        guard assets.indices.contains(target) else { return }
        let other = assets[target]; let oldOrder = asset.sortOrder
        asset.sortOrder = other.sortOrder; other.sortOrder = oldOrder
        try? context.save()
    }
    private func normalizeAssetOrder() { for (index, asset) in assets.filter({ $0.modelContext != nil }).enumerated() { asset.sortOrder = index } }
    private func loadWebsite() {
        loadingWebsite = true
        Task {
            if let product {
                let brief = try? await WebsiteSyncService.fetchPromotionBrief(for: product)
                await MainActor.run { websiteBrief = brief; loadingWebsite = false; generationMessage = brief == nil ? "官网读取失败，可继续使用本地资料生成" : "官网资料已结构化，可编辑后生成" }
            } else {
                let result = try? await WebsiteSyncService.fetchPromotionBrief(urlString: project.sourceURL, fallbackAudience: project.sourceAudience, fallbackSummary: project.sourceSummary, fallbackBenefits: project.sourceBenefits.components(separatedBy: .newlines))
                await MainActor.run { websiteBrief = result?.brief; loadingWebsite = false; generationMessage = result == nil ? "官网读取失败，可继续使用产品档案生成" : "客户官网资料已结构化，可编辑后生成" }
            }
        }
    }
    private func regenerate() {
        context.insert(ProjectVersion(projectID: project.id, version: project.version, title: project.title, body: project.body, tags: project.tags, platform: project.platformRaw))
        let generated: GeneratedContent
        if let product { generated = LocalContentGenerator().generate(product: product, angle: angle, tone: tone, websiteBrief: websiteBrief) }
        else { generated = LocalContentGenerator().generate(productName: project.sourceProductName, audience: project.sourceAudience, summary: project.sourceSummary, benefits: project.sourceBenefits.components(separatedBy: .newlines), sourceURL: project.sourceURL, goalAction: project.sourceGoalAction, insightContext: project.sourceInsightContext, angle: angle, tone: tone.isEmpty ? project.brandVoice : tone) }
        project.title = generated.title; project.body = generated.body; project.tags = generated.tags; project.sourceAngle = angle; project.version += 1; project.updatedAt = Date()
        try? context.save(); generationMessage = "已生成 v\(project.version)，旧内容已保存到版本历史"
    }
    private func schedule() { project.scheduledAt = scheduleDate; project.publishStatus = .ready; project.updatedAt = Date(); try? context.save(); ReminderService.schedule(draftID: project.id, title: project.title, at: scheduleDate); record("加入发布队列", succeeded: true) }
    private func markPublished() { project.publishStatus = .shared; project.updatedAt = Date(); try? context.save(); record("记录发布结果", succeeded: true, message: project.publishedURL) }
}

private struct ProjectMetricField: View {
    let label: String
    @Binding var value: Int
    var body: some View { TextField(label, value: $value, format: .number).keyboardType(.numberPad).frame(minWidth: 52) }
}
