import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct RootView: View {
    var body: some View {
        TabView {
            DashboardView().tabItem { Label("首页", systemImage: "square.grid.2x2") }
            ProductsView().tabItem { Label("产品", systemImage: "books.vertical") }
            ComposerView().tabItem { Label("创作", systemImage: "square.and.pencil") }
            QueueView().tabItem { Label("队列", systemImage: "calendar") }
        }
    }
}

struct DashboardView: View {
    @Query private var drafts: [ContentDraft]
    @State private var syncMessage = ""
    @State private var syncing = false
    var body: some View {
        NavigationStack {
            List {
                Section("运营概览") {
                    Label("待审核 \(drafts.filter { $0.status == .needsReview }.count) 条", systemImage: "checkmark.seal")
                    Label("已排期 \(drafts.filter { $0.status == .scheduled }.count) 条", systemImage: "clock")
                    Label("安全发布：人工确认后通过系统分享", systemImage: "lock.shield")
                    Button { syncWebsite() } label: { Label(syncing ? "正在同步官网" : "同步官网产品链接", systemImage: "arrow.triangle.2.circlepath") }
                    if !syncMessage.isEmpty { Text(syncMessage).font(.caption).foregroundStyle(.secondary) }
                }
                Section("工作原则") { Text("所有内容保留产品来源，发布前必须人工审核。App 不保存小红书密码或登录凭证。") .font(.subheadline).foregroundStyle(.secondary) }
                if !drafts.isEmpty {
                    let published = drafts.filter { $0.status == .published }
                    Section("发布效果") {
                        HStack { MetricSummary(label: "曝光", value: published.reduce(0) { $0 + $1.impressions }); MetricSummary(label: "点赞", value: published.reduce(0) { $0 + $1.likes }); MetricSummary(label: "收藏", value: published.reduce(0) { $0 + $1.saves }); MetricSummary(label: "评论", value: published.reduce(0) { $0 + $1.comments }) }
                        Text("已发布 \(published.count) 条内容").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }.navigationTitle("Apex 宣传台")
        }
    }

    private func syncWebsite() {
        syncing = true
        Task {
            do {
                let links = try await WebsiteSyncService.fetchStoreLinks()
                ProductCatalog.applyStoreLinks(links)
                await MainActor.run { syncMessage = "已同步官网链接 \(links.count) 条，产品页已更新"; syncing = false }
            } catch {
                await MainActor.run { syncMessage = "同步失败，已保留本地资料"; syncing = false }
            }
        }
    }
}

private struct MetricSummary: View { let label: String; let value: Int; var body: some View { VStack { Text("\(value)").font(.headline); Text(label).font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity) } }

struct ProductsView: View {
    var body: some View {
        NavigationStack { List(ProductCatalog.seeds, id: \.id) { p in
            VStack(alignment: .leading, spacing: 6) { Text(p.name).font(.headline); Text(p.summary); Text(p.audience).font(.caption).foregroundStyle(.secondary); Text("开发者：\(p.developer)").font(.caption); Link("下载 App", destination: URL(string: p.storeURL)!); Link("查看产品介绍", destination: URL(string: p.sourceURL)!) }
        }.navigationTitle("Apex 产品") }
    }
}

struct ComposerView: View {
    private enum ComposeMode: String, CaseIterable, Identifiable {
        case text = "纯文字", image = "图文", video = "视频"
        var id: String { rawValue }
    }
    @Environment(\.modelContext) private var context
    @State private var selectedID = ProductCatalog.seeds[0].id
    @State private var angle = ""
    @State private var tone = "真诚分享"
    @State private var content: GeneratedContent?
    @State private var findings: [ValidationFinding] = []
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var importedImages: [Data] = []
    @State private var slideTitles: [String] = []
    @State private var exportedURL: URL?
    @State private var exportedURLs: [URL] = []
    @State private var scheduleDate = Date().addingTimeInterval(86400)
    @State private var packageMessage = ""
    @State private var textPlatform: PublishPlatform = .xiaohongshu
    @State private var videoPlatform: PublishPlatform = .douyin
    @State private var mode: ComposeMode = .text
    var selected: ProductSeed { ProductCatalog.seeds.first { $0.id == selectedID } ?? ProductCatalog.seeds[0] }
    var body: some View {
        NavigationStack { Form {
            Section {
                Picker("内容类型", selection: $mode) {
                    ForEach(ComposeMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            Section("内容来源") { Picker("产品", selection: $selectedID) { ForEach(ProductCatalog.seeds, id: \.id) { Text($0.name).tag($0.id) } }; TextField("传播角度（可选）", text: $angle); TextField("语气", text: $tone) }
            Section("发布计划") { DatePicker("计划发布时间", selection: $scheduleDate, in: Date()..., displayedComponents: [.date, .hourAndMinute]); Text("到点后由你确认并通过系统分享发布，小红书账号凭证不会进入本 App。" ).font(.caption).foregroundStyle(.secondary) }
            if mode != .text {
            Section(mode == .image ? "图文素材" : "视频画面素材") {
                PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 6, matching: .images) { Label("从照片图库导入截图", systemImage: "photo.on.rectangle.angled") }
                    .onChange(of: selectedPhotos) { _, items in
                        Task {
                            var loaded: [Data] = []
                            for item in items {
                                if let data = try? await item.loadTransferable(type: Data.self) {
                                    loaded.append(data)
                                }
                            }
                            await MainActor.run {
                                importedImages = loaded
                                slideTitles = Array(repeating: "产品功能亮点", count: loaded.count)
                            }
                        }
                    }
                if !importedImages.isEmpty {
                    ScrollView(.horizontal) {
                        HStack {
                            ForEach(importedImages.indices, id: \.self) { index in
                                SlidePreview(
                                    imageData: importedImages[index],
                                    title: Binding(
                                        get: { slideTitles.indices.contains(index) ? slideTitles[index] : "" },
                                        set: { newValue in
                                            if slideTitles.indices.contains(index) { slideTitles[index] = newValue }
                                        }
                                    ),
                                    index: index
                                )
                            }
                        }
                    }
                    Text("已导入 \(importedImages.count) 张，发布前请核对每页截图和标题")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button(action: exportCarousel) {
                        Label("导出全部轮播页", systemImage: "square.and.arrow.up")
                    }
                    if let exportedURL {
                        ShareLink(item: exportedURL) {
                            Label("再次分享已导出的封面", systemImage: "arrowshape.turn.up.right")
                        }
                    }
                    ForEach(exportedURLs.dropFirst(), id: \.self) { url in
                        ShareLink(item: url) {
                            Label("分享轮播页", systemImage: "photo")
                        }
                    }
                }
            }
            }
            Section {
                Button {
                    let generated = LocalContentGenerator().generate(product: selected, angle: angle, tone: tone)
                    content = generated
                    findings = ContentValidator.validate(generated, product: selected)
                    if mode == .text {
                        packageMessage = "纯文字草稿已生成。"
                    } else if importedImages.isEmpty {
                        packageMessage = "请先导入至少 1 张真实 App 截图。"
                    } else {
                        exportCarousel()
                        packageMessage = mode == .image ? "图文发布包已生成。" : "视频脚本和画面素材已生成。"
                    }
                } label: {
                    Label("生成\(mode.rawValue)发布包", systemImage: mode == .text ? "text.bubble" : mode == .image ? "photo.on.rectangle" : "video")
                }
                .font(.headline)
                if !packageMessage.isEmpty {
                    Text(packageMessage).font(.caption).foregroundStyle(.secondary)
                }
            }
            if let c = content {
                Section("草稿") {
                    TextField("标题", text: contentBinding(\.title))
                    TextEditor(text: contentBinding(\.body)).frame(minHeight: 180)
                    TextField("标签", text: contentBinding(\.tags))
                    if mode == .text {
                        Picker("平台", selection: $textPlatform) {
                            ForEach(PublishPlatform.allCases.filter { !$0.isVideo }) { Text($0.rawValue).tag($0) }
                        }
                        Button {
                            SharePresenter.present(items: [PlatformFormatter.text(for: textPlatform, content: c)])
                        } label: {
                            Label("分享纯文字到\(textPlatform.rawValue)", systemImage: "text.bubble")
                        }
                    } else if mode == .image {
                        if let exportedURL {
                            Button {
                                UIPasteboard.general.string = publishText(c)
                                SharePresenter.present(items: [exportedURL])
                            } label: { Label("复制文案并分享图片", systemImage: "photo") }
                        } else { Text("请先导入图片并生成图文发布包").foregroundStyle(.secondary) }
                    } else {
                        Picker("视频平台", selection: $videoPlatform) {
                            ForEach(PublishPlatform.allCases.filter { $0.isVideo }) { Text($0.rawValue).tag($0) }
                        }
                        Button {
                            openVideoPlatform(videoPlatform, content: c)
                        } label: {
                            Label("打开视频平台并分享脚本", systemImage: "video.badge.waveform")
                        }
                    }
                    Button {
                        let draft = ContentDraft(productID: selected.id, title: c.title, body: c.body, tags: c.tags, sourceIDs: [selected.id])
                        draft.status = .scheduled
                        draft.scheduledAt = scheduleDate
                        context.insert(draft)
                        for (index, data) in importedImages.enumerated() {
                            context.insert(Asset(productID: selected.id, filename: "\(selected.id)-\(index + 1).jpg", imageData: data, sortOrder: index))
                        }
                        try? context.save()
                        ReminderService.schedule(draftID: draft.id, title: draft.title, at: scheduleDate)
                        content = c
                        findings = ContentValidator.validate(c, product: selected)
                    } label: {
                        Label("保存并加入发布计划", systemImage: "calendar.badge.plus")
                    }
                }
                if !findings.isEmpty { Section("校验提醒") { ForEach(findings) { f in Label(f.message, systemImage: f.blocking ? "exclamationmark.triangle" : "info.circle").foregroundStyle(f.blocking ? .orange : .secondary) } } }
            }
        }.navigationTitle("创作") }
    }

    private func contentBinding(_ keyPath: WritableKeyPath<GeneratedContent, String>) -> Binding<String> {
        Binding(get: { content?[keyPath: keyPath] ?? "" }, set: { newValue in content?[keyPath: keyPath] = newValue })
    }

    private func exportCover() {
        guard let data = importedImages.first, let source = UIImage(data: data) else { return }
        let size = CGSize(width: 900, height: 1200)
        let renderer = UIGraphicsImageRenderer(size: size)
        let title = slideTitles.first ?? selected.name
        let image = renderer.image { ctx in
            UIColor(red: 0.12, green: 0.38, blue: 0.48, alpha: 1).setFill(); ctx.fill(CGRect(origin: .zero, size: size))
            let inset = CGRect(x: 36, y: 36, width: 828, height: 1010)
            source.draw(in: inset)
            let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .left
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 46), .foregroundColor: UIColor.white, .paragraphStyle: paragraph]
            (title as NSString).draw(in: CGRect(x: 48, y: 1080, width: 804, height: 80), withAttributes: attrs)
        }
        guard let png = image.pngData() else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(selected.id)-cover.png")
        try? png.write(to: url); exportedURL = url
    }

    private func exportCarousel() {
        exportedURLs = []
        for index in importedImages.indices {
            guard let source = UIImage(data: importedImages[index]) else { continue }
            let size = CGSize(width: 900, height: 1200)
            let renderer = UIGraphicsImageRenderer(size: size)
            let title = slideTitles.indices.contains(index) ? slideTitles[index] : selected.name
            let image = renderer.image { ctx in
                UIColor(red: 0.12, green: 0.38, blue: 0.48, alpha: 1).setFill(); ctx.fill(CGRect(origin: .zero, size: size))
                source.draw(in: CGRect(x: 36, y: 126, width: 828, height: 920))
                drawBrand(on: ctx.cgContext, size: size)
                let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 46), .foregroundColor: UIColor.white]
                (title as NSString).draw(in: CGRect(x: 48, y: 1080, width: 804, height: 80), withAttributes: attrs)
            }
            guard let png = image.pngData() else { continue }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(selected.id)-slide-\(index + 1).png")
            try? png.write(to: url); exportedURLs.append(url)
        }
        exportedURL = exportedURLs.first
    }

    private func drawBrand(on context: CGContext, size: CGSize) {
        if let path = Bundle.main.path(forResource: selected.id, ofType: "png", inDirectory: "ProductIcons"), let icon = UIImage(contentsOfFile: path) {
            icon.draw(in: CGRect(x: 42, y: 42, width: 64, height: 64))
        }
        let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 30), .foregroundColor: UIColor.white]
        (selected.name as NSString).draw(in: CGRect(x: 122, y: 54, width: 700, height: 44), withAttributes: attrs)
    }

    private func publishText(_ content: GeneratedContent) -> String {
        "\(content.title)\n\n\(content.body)\n\n\(content.tags)"
    }

    private func shareToPlatform(_ platform: PublishPlatform, content: GeneratedContent) {
        let text = PlatformFormatter.text(for: platform, content: content)
        var items: [Any] = [text]
        if let data = importedImages.first, let image = UIImage(data: data) { items.insert(image, at: 0) }
        SharePresenter.present(items: items)
    }

    private func openVideoPlatform(_ platform: PublishPlatform, content: GeneratedContent) {
        VideoPlatformLauncher.open(platform, script: PlatformFormatter.text(for: platform, content: content))
    }

}

enum SharePresenter {
    static func present(items: [Any]) {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return }
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let popover = controller.popoverPresentationController {
            popover.sourceView = root.view
            popover.sourceRect = CGRect(x: root.view.bounds.midX, y: root.view.bounds.maxY - 80, width: 1, height: 1)
        }
        root.topMost.present(controller, animated: true)
    }

}

enum VideoPlatformLauncher {
    static func open(_ platform: PublishPlatform, script: String) {
        let schemes = platform == .douyin ? ["snssdk1128://", "douyin://"] : ["kwai://", "kuaishou://"]
        if let url = schemes.compactMap(URL.init(string:)).first(where: { UIApplication.shared.canOpenURL($0) }) {
            UIApplication.shared.open(url)
            UIPasteboard.general.string = script
        } else {
            SharePresenter.present(items: [script])
        }
    }
}

private extension UIViewController {
    var topMost: UIViewController {
        if let presented = presentedViewController { return presented.topMost }
        if let navigation = self as? UINavigationController, let visible = navigation.visibleViewController { return visible.topMost }
        if let tab = self as? UITabBarController, let selected = tab.selectedViewController { return selected.topMost }
        return self
    }
}

struct QueueView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor<ContentDraft>(\.createdAt, order: .reverse)]) private var drafts: [ContentDraft]
    var body: some View { NavigationStack { List { ForEach(drafts) { d in VStack(alignment: .leading) { Text(d.title).font(.headline); HStack { Text(d.status.rawValue).font(.caption).foregroundStyle(.secondary); if let date = d.scheduledAt { Text(date, style: .date).font(.caption).foregroundStyle(.secondary) } }; if d.status == .needsReview { Button("批准") { d.status = .approved; try? context.save() } } else if d.status == .approved || d.status == .scheduled { ShareLink(item: "\(d.title)\n\n\(d.body)\n\n\(d.tags)") { Label("复制/分享发布内容", systemImage: "square.and.arrow.up") }; Button("记录已发布") { d.status = .published; try? context.save() } } else if d.status == .published { TextField("粘贴小红书笔记链接", text: Binding(get: { d.publishedURL }, set: { d.publishedURL = $0 })); HStack { MetricField(label: "曝光", value: Binding(get: { d.impressions }, set: { d.impressions = $0 })); MetricField(label: "赞", value: Binding(get: { d.likes }, set: { d.likes = $0 })); MetricField(label: "藏", value: Binding(get: { d.saves }, set: { d.saves = $0 })); MetricField(label: "评", value: Binding(get: { d.comments }, set: { d.comments = $0 })) }; Button("保存数据") { try? context.save() } } } } }.navigationTitle("发布队列") } }
}

private struct MetricField: View { let label: String; @Binding var value: Int; var body: some View { TextField(label, value: $value, format: .number).keyboardType(.numberPad).frame(width: 62) } }

private struct SlidePreview: View {
    let imageData: Data
    @Binding var title: String
    let index: Int

    var body: some View {
        VStack {
            if let image = UIImage(data: imageData) {
                ZStack(alignment: .bottomLeading) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 150, height: 200)
                        .clipped()
                    Text(title)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.accent.opacity(0.9))
                }
            }
            TextField("第\(index + 1)页标题", text: $title)
                .font(.caption)
                .frame(width: 150)
        }
    }
}
