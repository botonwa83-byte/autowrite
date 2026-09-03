import SwiftUI
import SwiftData

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
    var body: some View {
        NavigationStack {
            List {
                Section("运营概览") {
                    Label("待审核 (drafts.filter { $0.status == .needsReview }.count) 条", systemImage: "checkmark.seal")
                    Label("已排期 (drafts.filter { $0.status == .scheduled }.count) 条", systemImage: "clock")
                    Label("安全发布：人工确认后通过系统分享", systemImage: "lock.shield")
                }
                Section("工作原则") { Text("所有内容保留产品来源，发布前必须人工审核。App 不保存小红书密码或登录凭证。") .font(.subheadline).foregroundStyle(.secondary) }
            }.navigationTitle("Apex 宣传台")
        }
    }
}

struct ProductsView: View {
    var body: some View {
        NavigationStack { List(ProductCatalog.seeds, id: \.id) { p in
            VStack(alignment: .leading, spacing: 6) { Text(p.name).font(.headline); Text(p.summary); Text(p.audience).font(.caption).foregroundStyle(.secondary) }
        }.navigationTitle("Apex 产品") }
    }
}

struct ComposerView: View {
    @Environment(\.modelContext) private var context
    @State private var selectedID = ProductCatalog.seeds[0].id
    @State private var angle = ""
    @State private var tone = "真诚分享"
    @State private var content: GeneratedContent?
    @State private var findings: [ValidationFinding] = []
    var selected: ProductSeed { ProductCatalog.seeds.first { $0.id == selectedID } ?? ProductCatalog.seeds[0] }
    var body: some View {
        NavigationStack { Form {
            Section("内容来源") { Picker("产品", selection: $selectedID) { ForEach(ProductCatalog.seeds, id: \.id) { Text($0.name).tag($0.id) } }; TextField("传播角度（可选）", text: $angle); TextField("语气", text: $tone) }
            Section { Button { let g = LocalContentGenerator().generate(product: selected, angle: angle, tone: tone); content = g; findings = ContentValidator.validate(g, product: selected) } label: { Label("生成小红书草稿", systemImage: "wand.and.stars") } }
            if var c = content {
                Section("草稿") { TextField("标题", text: Binding(get: { c.title }, set: { c.title = $0 })); TextEditor(text: Binding(get: { c.body }, set: { c.body = $0 })).frame(minHeight: 180); TextField("标签", text: Binding(get: { c.tags }, set: { c.tags = $0 }))
                    Button { let d = ContentDraft(productID: selected.id, title: c.title, body: c.body, tags: c.tags, sourceIDs: [selected.id]); d.status = .needsReview; context.insert(d); try? context.save(); content = c; findings = ContentValidator.validate(c, product: selected) } label: { Label("保存并提交审核", systemImage: "checkmark.circle") }
                }
                if !findings.isEmpty { Section("校验提醒") { ForEach(findings) { f in Label(f.message, systemImage: f.blocking ? "exclamationmark.triangle" : "info.circle").foregroundStyle(f.blocking ? .orange : .secondary) } } }
            }
        }.navigationTitle("创作") }
    }
}

struct QueueView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \.createdAt, order: .reverse) private var drafts: [ContentDraft]
    var body: some View { NavigationStack { List { ForEach(drafts) { d in VStack(alignment: .leading) { Text(d.title).font(.headline); Text(d.status.rawValue).font(.caption).foregroundStyle(.secondary); if d.status == .needsReview { Button("批准") { d.status = .approved; try? context.save() } } else if d.status == .approved { ShareLink(item: "\(d.title)\n\n\(d.body)\n\n\(d.tags)") { Label("复制/分享发布内容", systemImage: "square.and.arrow.up") } } } } }.navigationTitle("发布队列") } }
}
