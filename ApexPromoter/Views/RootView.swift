import SwiftUI
import SwiftData
import PhotosUI
import UIKit
import AVKit

struct RootView: View {
    let modelContainer: ModelContainer
    @State private var selectedTab: AppTab = .dashboard
    @State private var showingHelp = false
    @State private var bootstrapError = ""
    @State private var hasStartedBootstrap = false
    @AppStorage("hasSeenUserGuideV1") private var hasSeenUserGuide = false
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(showGuide: { showingHelp = true }).tabItem { Label("首页", systemImage: "square.grid.2x2") }.tag(AppTab.dashboard)
            ProductsView().tabItem { Label("产品", systemImage: "books.vertical") }.tag(AppTab.products).accessibilityIdentifier("tab.products")
            ComposerView().tabItem { Label("创作", systemImage: "square.and.pencil") }.tag(AppTab.composer).accessibilityIdentifier("tab.composer")
            QueueView().tabItem { Label("队列", systemImage: "calendar") }.tag(AppTab.queue).accessibilityIdentifier("tab.queue")
            MoreView().tabItem { Label("更多", systemImage: "ellipsis.circle") }.tag(AppTab.more)
        }
        .onAppear {
            if !hasStartedBootstrap {
                hasStartedBootstrap = true
                if !ProcessInfo.processInfo.arguments.contains("--ui-testing") {
                    Task {
                        // Keep database inserts away from the List-backed main context.
                        try? await Task.sleep(for: .seconds(2))
                        do {
                            let worker = ApexPortfolioSeedWorker(modelContainer: modelContainer)
                            _ = try await worker.seedIfNeeded()
                        } catch {
                            bootstrapError = "Apex 系列初始化失败：\(error.localizedDescription)"
                        }
                    }
                }
            }
            if !hasSeenUserGuide { showingHelp = true }
        }
        .alert("初始化未完成", isPresented: Binding(get: { !bootstrapError.isEmpty }, set: { if !$0 { bootstrapError = "" } })) {
            Button("好") { bootstrapError = "" }
        } message: {
            Text(bootstrapError)
        }
        .sheet(isPresented: $showingHelp, onDismiss: { hasSeenUserGuide = true }) {
            HelpView(isFirstRun: !hasSeenUserGuide, onNavigate: { destination in
                hasSeenUserGuide = true; showingHelp = false
                selectedTab = (destination == .brands || destination == .projects) ? .more : destination
            }, onClose: { hasSeenUserGuide = true; showingHelp = false })
        }
    }
}

struct DashboardView: View {
    let showGuide: () -> Void
    @Query private var drafts: [ContentDraft]
    @Query private var projects: [PromotionProject]
    @State private var syncMessage = ""
    @State private var syncing = false
    var body: some View {
        NavigationStack {
            List {
                Section("开始使用") {
                    Button(action: showGuide) { Label("查看 7 步推广教程", systemImage: "questionmark.circle") }
                }
                Section("运营概览") {
                    Label("待审核 \(drafts.filter { $0.status == .needsReview }.count) 条", systemImage: "checkmark.seal")
                    Label("推广项目已排期 \(projects.filter { $0.scheduledAt != nil && !$0.isPublished }.count) 条", systemImage: "clock")
                    Label("安全发布：人工确认后通过系统分享", systemImage: "lock.shield")
                    Button { syncWebsite() } label: {
                        if syncing { HStack { ProgressView(); Text("正在同步官网") } }
                        else { Label("同步官网产品链接", systemImage: "arrow.triangle.2.circlepath") }
                    }
                    .disabled(syncing)
                    if !syncMessage.isEmpty { Text(syncMessage).font(.caption).foregroundStyle(.secondary) }
                }
                Section("工作原则") { Text("所有内容保留产品来源，发布前必须人工审核。App 不保存小红书密码或登录凭证。") .font(.subheadline).foregroundStyle(.secondary) }
                if !drafts.isEmpty || !projects.isEmpty {
                    let published = drafts.filter { $0.status == .published }
                    Section("发布效果") {
                        HStack { MetricSummary(label: "曝光", value: published.reduce(0) { $0 + $1.impressions } + projects.reduce(0) { $0 + $1.impressions }); MetricSummary(label: "互动", value: published.reduce(0) { $0 + $1.likes + $1.saves + $1.comments } + projects.reduce(0) { $0 + $1.likes + $1.saves + $1.comments }); MetricSummary(label: "点击", value: projects.reduce(0) { $0 + $1.linkClicks }); MetricSummary(label: "下载", value: projects.reduce(0) { $0 + $1.downloads }) }
                        Text("已发布 \(published.count + projects.filter(\.isPublished).count) 条内容").font(.caption).foregroundStyle(.secondary)
                        NavigationLink { GrowthReviewView() } label: { Label("查看推广复盘", systemImage: "chart.xyaxis.line") }
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

private struct GrowthReviewView: View {
    @Query private var projects: [PromotionProject]
    private var review: PerformanceReview {
        PerformanceAnalyzer.review(projects.map {
            PerformanceSnapshot(platform: PublishPlatform(rawValue: $0.platformRaw) ?? .xiaohongshu, angle: $0.sourceAngle, impressions: $0.impressions, likes: $0.likes, saves: $0.saves, comments: $0.comments, linkClicks: $0.linkClicks, downloads: $0.downloads)
        })
    }
    private var totals: (impressions: Int, clicks: Int, downloads: Int) {
        (projects.reduce(0) { $0 + $1.impressions }, projects.reduce(0) { $0 + $1.linkClicks }, projects.reduce(0) { $0 + $1.downloads })
    }
    var body: some View {
        List {
            Section("推广漏斗") {
                HStack { MetricSummary(label: "曝光", value: totals.impressions); MetricSummary(label: "点击", value: totals.clicks); MetricSummary(label: "下载", value: totals.downloads) }
                if totals.impressions > 0 { Text("点击率 \(Double(totals.clicks) / Double(totals.impressions), format: .percent.precision(.fractionLength(1)))") }
                if totals.clicks > 0 { Text("下载转化率 \(Double(totals.downloads) / Double(totals.clicks), format: .percent.precision(.fractionLength(1)))") }
            }
            Section("下一周期建议") { Label(review.recommendation, systemImage: review.bestPlatform == nil ? "info.circle" : "lightbulb") }
            if !review.platforms.isEmpty {
                Section("平台表现") { ForEach(review.platforms) { row in VStack(alignment: .leading, spacing: 5) { Text(row.name).font(.headline); Text("曝光 \(row.impressions) · 互动 \(row.interactions) · 点击 \(row.linkClicks) · 下载 \(row.downloads)").font(.caption).foregroundStyle(.secondary) } } }
            }
            Section { Text("复盘仅使用你在项目中手工记录的数据，不连接或抓取平台账号。样本较少时建议只把结论作为下一轮验证方向。") .font(.caption).foregroundStyle(.secondary) }
        }.navigationTitle("推广复盘")
    }
}

struct ProductsView: View {
    @Query(sort: \CustomerProduct.createdAt) private var customerProducts: [CustomerProduct]
    var body: some View {
        let products = customerProducts.isEmpty ? ProductCatalog.seeds : customerProducts.map(ProductCatalog.seed(from:))
        NavigationStack { List(products, id: \.id) { p in
            VStack(alignment: .leading, spacing: 6) {
                Text(p.name).font(.headline)
                Text(p.summary)
                Text(p.audience).font(.caption).foregroundStyle(.secondary)
                Text("开发者：\(p.developer)").font(.caption)
                if p.isReleased, let url = URL(string: p.storeURL) { Link("下载 App", destination: url) }
                else { Label("上架审核中", systemImage: "hammer").font(.caption).foregroundStyle(.secondary) }
                if let url = URL(string: p.sourceURL) { Link("查看产品介绍", destination: url) }
            }
        }.navigationTitle("Apex 产品") }
    }
}

struct ComposerView: View {
    private enum ComposeMode: String, CaseIterable, Identifiable {
        case text = "纯文字", image = "图文", video = "视频"
        var id: String { rawValue }
    }
    @Environment(\.modelContext) private var context
    @Query(sort: \CustomerProduct.createdAt) private var customerProducts: [CustomerProduct]
    @Query private var brands: [BrandWorkspace]
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
    @State private var exportedScriptURL: URL?
    @State private var exportedVideoURL: URL?
    @State private var renderingVideo = false
    @State private var scheduleDate = Date().addingTimeInterval(86400)
    @State private var packageMessage = ""
    @State private var websiteBrief: WebsitePromotionBrief?
    @State private var loadingWebsite = false
    @State private var textPlatform: PublishPlatform = .xiaohongshu
    @State private var videoPlatform: PublishPlatform = .douyin
    @State private var mode: ComposeMode = .text
    private var availableProducts: [ProductSeed] { customerProducts.isEmpty ? ProductCatalog.seeds : customerProducts.map(ProductCatalog.seed(from:)) }
    var selected: ProductSeed { availableProducts.first { $0.id == selectedID } ?? availableProducts[0] }
    private var selectedIsBuiltIn: Bool {
        ProductAccess.isBuiltIn(productID: selected.id, brands: brands, products: customerProducts)
    }
    var body: some View {
        NavigationStack { Form {
            Section {
                Picker("内容类型", selection: $mode) {
                    ForEach(ComposeMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            Section("内容来源") {
                Picker("产品", selection: $selectedID) { ForEach(availableProducts, id: \.id) { Text($0.name).tag($0.id) } }
                if selectedIsBuiltIn {
                    Label("官方自研产品，免费可用", systemImage: "checkmark.seal").font(.caption).foregroundStyle(.green)
                }
                TextField("传播角度（可选）", text: $angle); TextField("语气", text: $tone)
                Button { loadWebsiteBrief() } label: { Label(loadingWebsite ? "正在读取官网资料" : "读取官网生成文案", systemImage: "globe") }.disabled(loadingWebsite)
                if websiteBrief != nil {
                    Text("官网资料预览").font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: Binding(get: { websiteBrief?.editableText ?? "" }, set: { websiteBrief?.editableText = $0 })).frame(minHeight: 120)
                }
            }
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
                    let generated = LocalContentGenerator().generate(product: selected, angle: angle, tone: tone, websiteBrief: websiteBrief)
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
                        Button { renderVideo(c) } label: { Label(renderingVideo ? "正在生成视频" : "生成竖屏视频", systemImage: "film") }.disabled(renderingVideo || importedImages.isEmpty)
                        if let exportedVideoURL {
                            VideoPlayer(player: AVPlayer(url: exportedVideoURL)).frame(height: 280).cornerRadius(8)
                            HStack {
                                ShareLink(item: exportedVideoURL) { Label("分享 MP4 视频", systemImage: "square.and.arrow.up") }
                                Button { renderVideo(c) } label: { Label("重新生成", systemImage: "arrow.clockwise") }
                            }
                        }
                        Button { exportedScriptURL = exportVideoScript(c) } label: { Label("导出视频脚本", systemImage: "doc.text") }
                        if let exportedScriptURL {
                            ShareLink(item: exportedScriptURL) { Label("分享视频脚本文件", systemImage: "square.and.arrow.up") }
                        }
                    }
                    Button {
                        let draft = ContentDraft(productID: selected.id, title: c.title, body: c.body, tags: c.tags, sourceIDs: [selected.id])
                        let project = PromotionProject(title: c.title, productID: selected.id, contentType: mode == .text ? .text : mode == .image ? .image : .video, platform: mode == .video ? videoPlatform.rawValue : textPlatform.rawValue, body: c.body, tags: c.tags)
                        project.sourceProductName = selected.name; project.sourceAudience = selected.audience; project.sourceSummary = selected.summary; project.sourceBenefits = selected.claims.joined(separator: "\n"); project.sourceURL = selected.sourceURL; project.sourceAngle = angle
                        project.scheduledAt = scheduleDate; project.publishStatus = .ready
                        context.insert(project)
                        draft.status = .scheduled
                        draft.scheduledAt = scheduleDate
                        context.insert(draft)
                        for (index, data) in importedImages.enumerated() {
                            context.insert(Asset(productID: selected.id, filename: "\(selected.id)-\(index + 1).jpg", imageData: data, sortOrder: index))
                        }
                        try? context.save()
                        Task { _ = await ReminderService.schedule(draftID: draft.id, title: draft.title, at: scheduleDate) }
                        content = c
                        findings = ContentValidator.validate(c, product: selected)
                    } label: {
                        Label("保存并加入发布计划", systemImage: "calendar.badge.plus")
                    }
                }
                if !findings.isEmpty { Section("校验提醒") { ForEach(findings) { f in Label(f.message, systemImage: f.blocking ? "exclamationmark.triangle" : "info.circle").foregroundStyle(f.blocking ? .orange : .secondary) } } }
            }
        }.navigationTitle("创作").onAppear { loadSampleImportForUITesting() } }
    }

    #if DEBUG
    /// UI 测试钩子：预置一张示例截图，绕过系统照片选择器（XCUITest 自动化不稳定）。
    /// 仅在 DEBUG 构建且显式传入启动参数时生效。
    private func loadSampleImportForUITesting() {
        guard ProcessInfo.processInfo.arguments.contains("--ui-testing-import-sample"), importedImages.isEmpty else { return }
        if let path = Bundle.main.path(forResource: "physicsapex", ofType: "png"),
           let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
            importedImages = [data]
            slideTitles = ["产品功能亮点"]
        }
    }
    #endif

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
            drawAspectFill(source, in: inset, on: ctx.cgContext)
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
                drawAspectFill(source, in: CGRect(x: 36, y: 126, width: 828, height: 920), on: ctx.cgContext)
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
        if let path = selected.iconBundlePath, let icon = UIImage(contentsOfFile: path) {
            icon.draw(in: CGRect(x: 42, y: 42, width: 64, height: 64))
        }
        let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 30), .foregroundColor: UIColor.white]
        (selected.name as NSString).draw(in: CGRect(x: 122, y: 54, width: 700, height: 44), withAttributes: attrs)
    }

    private func drawAspectFill(_ image: UIImage, in rect: CGRect, on context: CGContext) {
        guard let cgImage = image.cgImage else { return }
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let scale = max(rect.width / imageSize.width, rect.height / imageSize.height)
        let drawSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let drawRect = CGRect(x: rect.midX - drawSize.width / 2, y: rect.midY - drawSize.height / 2, width: drawSize.width, height: drawSize.height)
        // 裁剪必须限定在保存/恢复的状态内，否则后续水印与标题会被同一裁剪裁掉。
        context.saveGState()
        UIBezierPath(roundedRect: rect, cornerRadius: 0).addClip()
        image.draw(in: drawRect)
        context.restoreGState()
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

    private func exportVideoScript(_ content: GeneratedContent) -> URL? {
        let script = PlatformFormatter.text(for: videoPlatform, content: content)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(selected.id)-video-script.txt")
        do { try script.data(using: .utf8)?.write(to: url); return url } catch { return nil }
    }

    private func renderVideo(_ content: GeneratedContent) {
        renderingVideo = true
        let images = importedImages.compactMap(UIImage.init(data:))
        Task {
            let result = try? await SlideshowVideoRenderer.render(images: images, title: content.title)
            await MainActor.run { exportedVideoURL = result; renderingVideo = false; packageMessage = result == nil ? "视频生成失败，请检查图片素材" : "已生成可分享的 MP4 视频" }
        }
    }

    private func loadWebsiteBrief() {
        loadingWebsite = true
        Task {
            let brief = try? await WebsiteSyncService.fetchPromotionBrief(for: selected)
            await MainActor.run { websiteBrief = brief; loadingWebsite = false; packageMessage = brief == nil ? "官网资料读取失败，将使用本地审核资料" : "已读取官网公开资料" }
        }
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
    @Query(sort: [SortDescriptor<PromotionProject>(\.updatedAt, order: .reverse)]) private var projects: [PromotionProject]
    var body: some View { NavigationStack { List {
        let scheduledProjects = projects.filter { $0.scheduledAt != nil }
        if !scheduledProjects.isEmpty { Section("我的项目") { ForEach(scheduledProjects) { project in NavigationLink { ProjectDetailView(project: project) } label: { VStack(alignment: .leading) { Text(project.title).font(.headline); HStack { Text(project.platformRaw); if let date = project.scheduledAt { Text(date, style: .date) } }.font(.caption).foregroundStyle(.secondary) } } } } }
        if !drafts.isEmpty { Section("历史草稿") { ForEach(drafts) { d in VStack(alignment: .leading) { Text(d.title).font(.headline); HStack { Text(d.status.rawValue).font(.caption).foregroundStyle(.secondary); if let date = d.scheduledAt { Text(date, style: .date).font(.caption).foregroundStyle(.secondary) } }; if d.status == .approved || d.status == .scheduled { ShareLink(item: "\(d.title)\n\n\(d.body)\n\n\(d.tags)") { Label("复制/分享发布内容", systemImage: "square.and.arrow.up") } } } } } }
    }.navigationTitle("发布队列") } }
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
