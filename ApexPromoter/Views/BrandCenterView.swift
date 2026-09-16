import SwiftUI
import SwiftData

struct BrandCenterView: View {
    @EnvironmentObject private var entitlements: EntitlementStore
    @Environment(\.modelContext) private var context
    @Query(sort: \BrandWorkspace.updatedAt, order: .reverse) private var brands: [BrandWorkspace]
    @State private var showingNewBrand = false
    @State private var showingPaywall = false
    var body: some View {
        Group {
            if brands.isEmpty { ContentUnavailableView("建立你的品牌空间", systemImage: "building.2", description: Text("集中管理品牌语气、产品资料和推广约束。")) }
            else { List(brands) { brand in NavigationLink { BrandDetailView(brand: brand) } label: { VStack(alignment: .leading) { Text(brand.name).font(.headline); Text(brand.brandVoice).font(.caption).foregroundStyle(.secondary) } } } }
        }
        .navigationTitle("品牌中心")
        .toolbar { Button { if entitlements.isPremium { showingNewBrand = true } else { showingPaywall = true } } label: { Image(systemName: "plus") }.accessibilityLabel("新建品牌") }
        .sheet(isPresented: $showingNewBrand) { NewBrandView() }
        .sheet(isPresented: $showingPaywall) { NavigationStack { PaywallView() } }
    }
}

private struct NewBrandView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var name = ""
    var body: some View { NavigationStack { Form { TextField("品牌名称", text: $name) }.navigationTitle("新建品牌").toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("创建") { context.insert(BrandWorkspace(name: name)); try? context.save(); dismiss() }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty) } } } }
}

private struct BrandDetailView: View {
    @EnvironmentObject private var entitlements: EntitlementStore
    @Environment(\.modelContext) private var context
    @Bindable var brand: BrandWorkspace
    @Query private var products: [CustomerProduct]
    @State private var showingNewProduct = false
    @State private var selectedProduct: CustomerProduct?
    @State private var showingPaywall = false
    init(brand: BrandWorkspace) { self.brand = brand; let id = brand.id; _products = Query(filter: #Predicate<CustomerProduct> { $0.brandID == id }, sort: [SortDescriptor(\.updatedAt, order: .reverse)]) }
    private var isBuiltInBrand: Bool { ProductAccess.isBuiltIn(brand) }
    var body: some View { Form {
        Section("品牌规范") { TextField("品牌名称", text: $brand.name); TextField("品牌语气", text: $brand.brandVoice); TextField("禁用词，用逗号分隔", text: $brand.prohibitedWords) }
        Section {
            ForEach(products) { product in
                Button { selectedProduct = product } label: {
                    HStack { Text(product.name); Spacer(); Image(systemName: "chevron.right").foregroundStyle(.tertiary) }
                }
                .buttonStyle(.plain)
            }
            Button { if entitlements.isPremium { showingNewProduct = true } else { showingPaywall = true } } label: { Label("添加产品", systemImage: "plus") }
        } header: {
            if isBuiltInBrand { HStack { Text("产品"); Spacer(); Label("官方自研 · 免费可用", systemImage: "checkmark.seal.fill").font(.caption).foregroundStyle(.green).textCase(nil) } }
            else { Text("产品") }
        } footer: {
            if isBuiltInBrand { Text("Apex 系列是我们自研并用于自身推广的产品，免费用户可以直接使用它们生成、导出和排期内容。要推广你自己的产品，请解锁专业版。") }
        }
    }
    .navigationTitle(brand.name)
    .sheet(isPresented: $showingNewProduct) { NewProductView(brandID: brand.id) }
    .sheet(isPresented: $showingPaywall) { NavigationStack { PaywallView() } }
    .sheet(item: $selectedProduct) { product in
        NavigationStack { CustomerProductView(product: product, brand: brand) }
    }
    .onDisappear { brand.updatedAt = Date(); try? context.save() }
    }
}

private struct NewProductView: View {
    @Environment(\.dismiss) private var dismiss; @Environment(\.modelContext) private var context
    let brandID: UUID; @State private var name = ""; @State private var website = ""
    var body: some View { NavigationStack { Form { TextField("产品名称", text: $name); TextField("产品官网", text: $website).keyboardType(.URL).textInputAutocapitalization(.never) }.navigationTitle("添加产品").toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("保存") { context.insert(CustomerProduct(brandID: brandID, name: name, websiteURL: website)); try? context.save(); dismiss() }.disabled(name.isEmpty) } } } }
}

private struct CustomerProductView: View {
    @EnvironmentObject private var entitlements: EntitlementStore
    @Environment(\.modelContext) private var context; @Bindable var product: CustomerProduct; let brand: BrandWorkspace
    @Query private var insights: [AudienceInsight]
    @Query private var goals: [PromotionGoal]
    @Query private var plans: [PromotionPlan]
    @State private var createdProject: PromotionProject?
    @State private var showingNewInsight = false
    @State private var showingPaywall = false
    init(product: CustomerProduct, brand: BrandWorkspace) {
        self.product = product
        self.brand = brand
        let productID = product.id
        _insights = Query(filter: #Predicate<AudienceInsight> { $0.productID == productID }, sort: [SortDescriptor(\.createdAt, order: .reverse)])
        _goals = Query(filter: #Predicate<PromotionGoal> { $0.productID == productID }, sort: [SortDescriptor(\.deadline)])
        _plans = Query(filter: #Predicate<PromotionPlan> { $0.productID == productID }, sort: [SortDescriptor(\.createdAt, order: .reverse)])
    }
    @State private var showingNewGoal = false
    @State private var showingNewPlan = false
    @State private var planMessage = ""
    @State private var loadingWebsite = false
    @State private var websiteMessage = ""
    @State private var websiteImport: WebsiteImportResult?
    var body: some View { Form { Section("基本资料") { TextField("名称", text: $product.name); TextField("官网", text: $product.websiteURL); TextField("下载地址", text: $product.storeURL); TextField("价格说明", text: $product.priceDescription); Button { importWebsite() } label: { Label(loadingWebsite ? "正在读取官网" : "读取官网并整理资料", systemImage: "globe") }.disabled(loadingWebsite || product.websiteURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty); if !websiteMessage.isEmpty { Text(websiteMessage).font(.caption).foregroundStyle(.secondary) }; if let importedAt = product.websiteImportedAt { Text("上次确认导入：\(importedAt.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary) } }; Section("市场表达") { TextField("目标用户", text: $product.audience); TextEditor(text: $product.summary).frame(minHeight: 100); TextEditor(text: $product.keyBenefits).frame(minHeight: 120) }; Section("客户洞察") { ForEach(insights) { insight in InsightRow(insight: insight) }.onDelete(perform: deleteInsights); Button { showingNewInsight = true } label: { Label("添加客户洞察", systemImage: "person.text.rectangle") } }; Section("推广目标") { ForEach(goals) { goal in GoalRow(goal: goal) { createPromotionProject(goal: goal) } }.onDelete(perform: deleteGoals); Button { showingNewGoal = true } label: { Label("制定推广目标", systemImage: "target") } }; Section("推广计划") { ForEach(plans) { plan in PlanRow(plan: plan) { generateBatch(for: plan) } }.onDelete(perform: deletePlans); Button { showingNewPlan = true } label: { Label("制定推广计划", systemImage: "calendar.badge.plus") }; if !planMessage.isEmpty { Text(planMessage).font(.caption).foregroundStyle(.secondary) } }; Section { Button { createPromotionProject() } label: { Label("创建无目标项目", systemImage: "megaphone") } } }.navigationTitle(product.name).navigationDestination(item: $createdProject) { ProjectDetailView(project: $0) }.sheet(isPresented: $showingNewInsight) { NewInsightView(productID: product.id) }.sheet(isPresented: $showingNewGoal) { NewGoalView(productID: product.id) }.sheet(isPresented: $showingNewPlan) { NewPlanView(productID: product.id, goals: goals) }.sheet(item: $websiteImport) { result in WebsiteImportPreview(result: result) { brief in applyWebsiteImport(brief, sourceText: result.cleanedText) } }.sheet(isPresented: $showingPaywall) { NavigationStack { PaywallView() } }.onDisappear { product.updatedAt = Date(); try? context.save() } }
    private func deleteInsights(at offsets: IndexSet) { for index in offsets { context.delete(insights[index]) }; try? context.save() }
    private func deleteGoals(at offsets: IndexSet) { for index in offsets { context.delete(goals[index]) }; try? context.save() }
    private func deletePlans(at offsets: IndexSet) { for index in offsets { context.delete(plans[index]) }; try? context.save() }
    private func importWebsite() {
        loadingWebsite = true; websiteMessage = ""
        Task {
            do {
                let benefits = product.keyBenefits.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                let result = try await WebsiteSyncService.fetchPromotionBrief(urlString: product.websiteURL, fallbackAudience: product.audience, fallbackSummary: product.summary, fallbackBenefits: benefits)
                await MainActor.run { websiteImport = result; loadingWebsite = false }
            } catch {
                await MainActor.run { websiteMessage = "官网读取失败，请检查网址或稍后重试。原有资料未修改。"; loadingWebsite = false }
            }
        }
    }
    private func applyWebsiteImport(_ brief: WebsitePromotionBrief, sourceText: String) {
        if !brief.audience.isEmpty { product.audience = brief.audience }
        if !brief.positioning.isEmpty { product.summary = brief.positioning }
        if !brief.highlights.isEmpty { product.keyBenefits = brief.highlights.joined(separator: "\n") }
        product.websiteSourceExcerpt = String(sourceText.prefix(1_200)); product.websiteImportedAt = Date(); product.updatedAt = Date()
        try? context.save(); websiteMessage = "已按确认内容更新产品资料"
    }
    /// 内置的 Apex 系列产品免费可用；推广用户自己的产品需要专业版。
    private var canPromote: Bool { entitlements.isPremium || ProductAccess.isBuiltIn(brand) }
    private func createPromotionProject(goal: PromotionGoal? = nil) {
        guard canPromote else { showingPaywall = true; return }
        let project = PromotionProjectFactory.makeProject(product: product, brand: brand, goal: goal, insights: insights)
        context.insert(project); try? context.save(); createdProject = project
    }
    private func generateBatch(for plan: PromotionPlan) {
        guard canPromote else { showingPaywall = true; return }
        let goal = goals.first { $0.id == plan.goalID }
        let projects = PromotionProjectFactory.makeBatch(product: product, brand: brand, goal: goal, plan: plan, insights: insights)
        projects.forEach(context.insert)
        plan.generatedAt = Date(); try? context.save(); planMessage = "已生成 \(projects.count) 个推广项目，并加入发布队列"
    }
}

private struct PlanRow: View {
    let plan: PromotionPlan
    let generate: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack { Label("\(plan.durationDays) 天计划", systemImage: "calendar").font(.headline); Spacer(); Text("\(plan.plannedPostCount) 条").foregroundStyle(.secondary) }
            Text(plan.platforms.map(\.rawValue).joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
            Text("每周 \(plan.postsPerWeek) 条，\(plan.startDate.formatted(date: .abbreviated, time: .omitted)) 开始")
            if let generatedAt = plan.generatedAt { Label("已于 \(generatedAt.formatted(date: .abbreviated, time: .shortened)) 生成", systemImage: "checkmark.circle").font(.caption).foregroundStyle(.green) }
            Button(action: generate) { Label(plan.generatedAt == nil ? "生成整批内容" : "追加生成一批", systemImage: "square.stack.3d.up") }
        }.padding(.vertical, 4)
    }
}

private struct NewPlanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let productID: UUID
    let goals: [PromotionGoal]
    @State private var durationDays = 7
    @State private var postsPerWeek = 4
    @State private var startDate = Date().addingTimeInterval(86400)
    @State private var goalID: UUID?
    @State private var selectedPlatforms: Set<PublishPlatform> = [.xiaohongshu, .wechatMoments, .douyin]
    var body: some View {
        NavigationStack {
            Form {
                Picker("计划周期", selection: $durationDays) { Text("7 天").tag(7); Text("30 天").tag(30) }.pickerStyle(.segmented)
                Stepper("每周发布 \(postsPerWeek) 条", value: $postsPerWeek, in: 1...7)
                DatePicker("开始日期", selection: $startDate, in: Date()..., displayedComponents: .date)
                Picker("关联目标", selection: $goalID) { Text("不关联目标").tag(Optional<UUID>.none); ForEach(goals) { Text($0.kind.title).tag(Optional($0.id)) } }
                Section("发布平台") { ForEach(PublishPlatform.allCases) { platform in Toggle(platform.rawValue, isOn: Binding(get: { selectedPlatforms.contains(platform) }, set: { selected in if selected { selectedPlatforms.insert(platform) } else { selectedPlatforms.remove(platform) } })) } }
            }
            .navigationTitle("制定推广计划")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") { context.insert(PromotionPlan(productID: productID, goalID: goalID, durationDays: durationDays, postsPerWeek: postsPerWeek, startDate: startDate, platforms: PublishPlatform.allCases.filter(selectedPlatforms.contains))); try? context.save(); dismiss() }.disabled(selectedPlatforms.isEmpty) }
            }
        }
    }
}

private struct WebsiteImportPreview: View {
    @Environment(\.dismiss) private var dismiss
    let result: WebsiteImportResult
    let apply: (WebsitePromotionBrief) -> Void
    @State private var positioning: String
    @State private var audience: String
    @State private var highlightsText: String

    init(result: WebsiteImportResult, apply: @escaping (WebsitePromotionBrief) -> Void) {
        self.result = result
        self.apply = apply
        _positioning = State(initialValue: result.brief.positioning)
        _audience = State(initialValue: result.brief.audience)
        _highlightsText = State(initialValue: result.brief.highlights.joined(separator: "\n"))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("产品定位") { TextEditor(text: $positioning).frame(minHeight: 80) }
                Section("适合人群") { TextEditor(text: $audience).frame(minHeight: 70) }
                Section("核心亮点") { TextEditor(text: $highlightsText).frame(minHeight: 120); Text("每行一个亮点，应用前可删除不准确内容。") .font(.caption).foregroundStyle(.secondary) }
                Section("来源摘要") { Text(result.cleanedText).font(.caption).textSelection(.enabled); Link("打开原始官网", destination: result.sourceURL) }
            }
            .navigationTitle("确认官网资料")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("应用到产品") { let highlights = highlightsText.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }; apply(WebsitePromotionBrief(positioning: positioning.trimmingCharacters(in: .whitespacesAndNewlines), audience: audience.trimmingCharacters(in: .whitespacesAndNewlines), highlights: highlights)); dismiss() }.disabled(positioning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }
        }
    }
}

private struct GoalRow: View {
    let goal: PromotionGoal
    let createProject: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack { Label(goal.kind.title, systemImage: "target").font(.headline); Spacer(); Text(goal.deadline, style: .date).font(.caption).foregroundStyle(.secondary) }
            ProgressView(value: Double(max(goal.currentValue, 0)), total: Double(max(goal.targetValue, 1)))
            Text("\(goal.kind.metricName)：\(goal.currentValue) / \(goal.targetValue)").font(.caption).foregroundStyle(.secondary)
            Text(goal.primaryAction)
            Button(action: createProject) { Label("按此目标创建项目", systemImage: "wand.and.stars") }
        }
        .padding(.vertical, 4)
    }
}

private struct NewGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let productID: UUID
    @State private var kind: PromotionGoalKind = .downloadGrowth
    @State private var currentValue = 0
    @State private var targetValue = 100
    @State private var deadline = Date().addingTimeInterval(30 * 86400)
    @State private var primaryAction = "引导目标用户了解并下载产品"
    var body: some View {
        NavigationStack {
            Form {
                Picker("目标类型", selection: $kind) { ForEach(PromotionGoalKind.allCases) { Text($0.title).tag($0) } }
                TextField("当前\(kind.metricName)", value: $currentValue, format: .number).keyboardType(.numberPad)
                TextField("目标\(kind.metricName)", value: $targetValue, format: .number).keyboardType(.numberPad)
                DatePicker("截止日期", selection: $deadline, in: Date()..., displayedComponents: .date)
                TextField("希望用户采取的核心行动", text: $primaryAction, axis: .vertical).lineLimit(2...4)
            }
            .navigationTitle("制定推广目标")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") { context.insert(PromotionGoal(productID: productID, kind: kind, currentValue: max(currentValue, 0), targetValue: targetValue, deadline: deadline, primaryAction: primaryAction.trimmingCharacters(in: .whitespacesAndNewlines))); try? context.save(); dismiss() }.disabled(targetValue <= 0 || primaryAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }
        }
    }
}

private struct InsightRow: View {
    let insight: AudienceInsight
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack { Text(insight.category.title).font(.caption).foregroundStyle(.secondary); Spacer(); Text(insight.evidenceState.title).font(.caption).foregroundStyle(insight.evidenceState == .verified ? .green : .orange) }
            Text(insight.statement)
            if let url = URL(string: insight.sourceURL), !insight.sourceURL.isEmpty { Link("查看来源", destination: url).font(.caption) }
        }
    }
}

private struct NewInsightView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let productID: UUID
    @State private var category: InsightCategory = .painPoint
    @State private var evidenceState: EvidenceState = .assumption
    @State private var statement = ""
    @State private var sourceURL = ""
    var body: some View {
        NavigationStack {
            Form {
                Picker("洞察类型", selection: $category) { ForEach(InsightCategory.allCases) { Text($0.title).tag($0) } }
                Picker("证据状态", selection: $evidenceState) { ForEach(EvidenceState.allCases) { Text($0.title).tag($0) } }
                TextField("客户的真实需求、行为或异议", text: $statement, axis: .vertical).lineLimit(3...6)
                TextField("来源链接（可选）", text: $sourceURL).keyboardType(.URL).textInputAutocapitalization(.never)
            }
            .navigationTitle("添加客户洞察")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") { context.insert(AudienceInsight(productID: productID, category: category, statement: statement.trimmingCharacters(in: .whitespacesAndNewlines), evidenceState: evidenceState, sourceURL: sourceURL.trimmingCharacters(in: .whitespacesAndNewlines))); try? context.save(); dismiss() }.disabled(statement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }
        }
    }
}
