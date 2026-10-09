import SwiftUI
import SwiftData

struct ProjectsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PromotionProject.updatedAt, order: .reverse) private var projects: [PromotionProject]
    @State private var searchText = ""
    @State private var selectedPlatform = "全部平台"
    @State private var selectedStatus = "全部状态"
    private var filteredProjects: [PromotionProject] {
        projects.filter { project in
            let matchesText = searchText.isEmpty || project.title.localizedCaseInsensitiveContains(searchText) || project.body.localizedCaseInsensitiveContains(searchText)
            let matchesPlatform = selectedPlatform == "全部平台" || project.platformRaw == selectedPlatform
            let statusLabel = project.isPublished ? "已发布" : (project.scheduledAt == nil ? "草稿" : "已排期")
            let matchesStatus = selectedStatus == "全部状态" || selectedStatus == statusLabel
            return matchesText && matchesPlatform && matchesStatus
        }
    }
    var body: some View {
        Group {
            if projects.isEmpty {
                ContentUnavailableView("还没有项目", systemImage: "folder", description: Text("创建后，内容和发布记录会保存在这里。"))
            } else {
                List {
                    Section {
                        Picker("平台", selection: $selectedPlatform) { Text("全部平台").tag("全部平台"); ForEach(PublishPlatform.allCases) { Text($0.rawValue).tag($0.rawValue) } }
                        Picker("状态", selection: $selectedStatus) { ForEach(["全部状态", "草稿", "已排期", "已发布"], id: \.self) { Text($0).tag($0) } }
                    }
                    Section("项目 · \(filteredProjects.count)") { ForEach(filteredProjects) { project in NavigationLink { ProjectDetailView(project: project) } label: { VStack(alignment: .leading) { Text(project.title).font(.headline); Text("\(project.platformRaw) · v\(project.version) · \(project.updatedAt.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary) } }.contextMenu { Button { duplicate(project) } label: { Label("复制项目", systemImage: "plus.square.on.square") } } }.onDelete(perform: deleteFiltered) }
                }
            }
        }
        .navigationTitle("我的项目")
            .searchable(text: $searchText, prompt: "搜索标题或正文")
            .toolbar {
                // 新建项目默认挂在官方自研的 Apex 产品上，免费可用。
                ToolbarItem(placement: .topBarTrailing) { Button { createProject() } label: { Image(systemName: "plus") }.accessibilityLabel("创建项目") }
            }
    }
    private func createProject() { context.insert(PromotionProject(title: "未命名推广项目", productID: ProductCatalog.seeds.first?.id ?? "")); try? context.save() }
    private func duplicate(_ source: PromotionProject) {
        let copy = PromotionProject(title: source.title + " 副本", productID: source.productID, contentType: source.contentType, platform: source.platformRaw, body: source.body, tags: source.tags)
        copy.overrideNote = source.overrideNote
        copy.sourceProductName = source.sourceProductName; copy.sourceAudience = source.sourceAudience; copy.sourceSummary = source.sourceSummary; copy.sourceBenefits = source.sourceBenefits; copy.sourceURL = source.sourceURL; copy.brandVoice = source.brandVoice
        copy.sourceGoalContext = source.sourceGoalContext; copy.sourceGoalAction = source.sourceGoalAction; copy.sourceGoalID = source.sourceGoalID; copy.sourceInsightContext = source.sourceInsightContext; copy.sourceAngle = source.sourceAngle
        context.insert(copy)
        let sourceID = source.id
        if let sourceAssets = try? context.fetch(FetchDescriptor<ProjectAsset>(predicate: #Predicate { $0.projectID == sourceID })) {
            for asset in sourceAssets {
                context.insert(ProjectAsset(projectID: copy.id, filename: asset.filename, imageData: asset.imageData, sortOrder: asset.sortOrder))
            }
        }
        try? context.save()
    }
    private func delete(at offsets: IndexSet) {
        for project in offsets.map({ projects[$0] }) {
            let projectID = project.id
            if let assets = try? context.fetch(FetchDescriptor<ProjectAsset>(predicate: #Predicate { $0.projectID == projectID })) { assets.forEach(context.delete) }
            if let attempts = try? context.fetch(FetchDescriptor<PublishAttempt>(predicate: #Predicate { $0.projectID == projectID })) { attempts.forEach(context.delete) }
            context.delete(project)
        }
        try? context.save()
    }
    private func deleteFiltered(at offsets: IndexSet) { deleteProjects(offsets.map { filteredProjects[$0] }) }
    private func deleteProjects(_ targets: [PromotionProject]) {
        for project in targets {
            let projectID = project.id
            if let assets = try? context.fetch(FetchDescriptor<ProjectAsset>(predicate: #Predicate { $0.projectID == projectID })) { assets.forEach(context.delete) }
            if let attempts = try? context.fetch(FetchDescriptor<PublishAttempt>(predicate: #Predicate { $0.projectID == projectID })) { attempts.forEach(context.delete) }
            context.delete(project)
        }
        try? context.save()
    }
}
