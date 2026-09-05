import Foundation
import SwiftData

@Model final class BrandWorkspace {
    var id: UUID = UUID()
    var name: String
    var brandVoice: String
    var prohibitedWords: String
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    init(name: String, brandVoice: String = "专业、真诚、清晰", prohibitedWords: String = "") { self.name = name; self.brandVoice = brandVoice; self.prohibitedWords = prohibitedWords }
}

@Model final class CustomerProduct {
    var id: UUID = UUID()
    var brandID: UUID
    var name: String
    var websiteURL: String
    var storeURL: String
    var audience: String
    var summary: String
    var keyBenefits: String
    var priceDescription: String
    var websiteSourceExcerpt: String = ""
    var websiteImportedAt: Date?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    init(brandID: UUID, name: String, websiteURL: String = "", storeURL: String = "", audience: String = "", summary: String = "", keyBenefits: String = "", priceDescription: String = "") { self.brandID = brandID; self.name = name; self.websiteURL = websiteURL; self.storeURL = storeURL; self.audience = audience; self.summary = summary; self.keyBenefits = keyBenefits; self.priceDescription = priceDescription }
}

enum InsightCategory: String, Codable, CaseIterable, Identifiable {
    case audience
    case scenario
    case painPoint
    case objection
    case competitor

    var id: String { rawValue }
    var title: String {
        switch self {
        case .audience: "目标人群"
        case .scenario: "使用场景"
        case .painPoint: "用户痛点"
        case .objection: "购买异议"
        case .competitor: "竞品差异"
        }
    }
}

enum EvidenceState: String, Codable, CaseIterable, Identifiable {
    case verified
    case assumption

    var id: String { rawValue }
    var title: String { self == .verified ? "已验证" : "待验证假设" }
}

@Model final class AudienceInsight {
    var id: UUID = UUID()
    var productID: UUID
    var categoryRaw: String
    var statement: String
    var evidenceStateRaw: String
    var sourceURL: String
    var createdAt: Date = Date()

    init(productID: UUID, category: InsightCategory, statement: String, evidenceState: EvidenceState, sourceURL: String = "") {
        self.productID = productID
        self.categoryRaw = category.rawValue
        self.statement = statement
        self.evidenceStateRaw = evidenceState.rawValue
        self.sourceURL = sourceURL
    }

    var category: InsightCategory {
        get { InsightCategory(rawValue: categoryRaw) ?? .audience }
        set { categoryRaw = newValue.rawValue }
    }

    var evidenceState: EvidenceState {
        get { EvidenceState(rawValue: evidenceStateRaw) ?? .assumption }
        set { evidenceStateRaw = newValue.rawValue }
    }
}

enum PromotionGoalKind: String, Codable, CaseIterable, Identifiable {
    case downloadGrowth
    case productLaunch
    case versionUpdate

    var id: String { rawValue }
    var title: String {
        switch self {
        case .downloadGrowth: "下载增长"
        case .productLaunch: "产品发布"
        case .versionUpdate: "版本更新"
        }
    }

    var metricName: String {
        switch self {
        case .downloadGrowth: "新增下载"
        case .productLaunch: "首批用户"
        case .versionUpdate: "更新用户"
        }
    }
}

@Model final class PromotionGoal {
    var id: UUID = UUID()
    var productID: UUID
    var kindRaw: String
    var currentValue: Int
    var targetValue: Int
    var deadline: Date
    var primaryAction: String
    var createdAt: Date = Date()

    init(productID: UUID, kind: PromotionGoalKind, currentValue: Int = 0, targetValue: Int, deadline: Date, primaryAction: String) {
        self.productID = productID
        self.kindRaw = kind.rawValue
        self.currentValue = currentValue
        self.targetValue = targetValue
        self.deadline = deadline
        self.primaryAction = primaryAction
    }

    var kind: PromotionGoalKind {
        get { PromotionGoalKind(rawValue: kindRaw) ?? .downloadGrowth }
        set { kindRaw = newValue.rawValue }
    }

    var generationContext: String {
        "\(kind.title)：从 \(currentValue) 提升到 \(kind.metricName) \(targetValue)，截止 \(deadline.formatted(date: .numeric, time: .omitted))。核心行动：\(primaryAction)"
    }
}

@Model final class PromotionPlan {
    var id: UUID = UUID()
    var productID: UUID
    var goalID: UUID?
    var durationDays: Int
    var postsPerWeek: Int
    var startDate: Date
    var platformRaws: [String]
    var generatedAt: Date?
    var createdAt: Date = Date()

    init(productID: UUID, goalID: UUID? = nil, durationDays: Int, postsPerWeek: Int, startDate: Date, platforms: [PublishPlatform]) {
        self.productID = productID
        self.goalID = goalID
        self.durationDays = durationDays
        self.postsPerWeek = postsPerWeek
        self.startDate = startDate
        self.platformRaws = platforms.map(\.rawValue)
    }

    var platforms: [PublishPlatform] { platformRaws.compactMap(PublishPlatform.init(rawValue:)) }
    var plannedPostCount: Int { PromotionPlanBuilder.build(durationDays: durationDays, postsPerWeek: postsPerWeek, startDate: startDate, platforms: platforms).count }
}

@Model final class Asset {
    var id: UUID = UUID()
    var productID: String
    var filename: String
    var imageData: Data
    var caption: String
    var sortOrder: Int
    init(productID: String, filename: String, imageData: Data, caption: String = "", sortOrder: Int = 0) { self.productID = productID; self.filename = filename; self.imageData = imageData; self.caption = caption; self.sortOrder = sortOrder }
}

@Model final class Product {
    var id: String
    var name: String
    var audience: String
    var summary: String
    var claims: [String]
    var sourceURL: String
    init(id: String, name: String, audience: String, summary: String, claims: [String], sourceURL: String) {
        self.id = id; self.name = name; self.audience = audience; self.summary = summary; self.claims = claims; self.sourceURL = sourceURL
    }
}

enum DraftStatus: String, Codable, CaseIterable { case draft, needsReview, approved, scheduled, published }

enum ProjectContentType: String, Codable, CaseIterable { case text, image, video }
enum ProjectPublishStatus: String, Codable, CaseIterable { case draft, ready, shared, published, failed }

@Model final class PromotionProject {
    var id: UUID = UUID()
    var title: String
    var productID: String
    var sourceProductName: String = ""
    var sourceAudience: String = ""
    var sourceSummary: String = ""
    var sourceBenefits: String = ""
    var sourceURL: String = ""
    var brandVoice: String = ""
    var sourceGoalContext: String = ""
    var sourceGoalAction: String = ""
    var sourceGoalID: UUID?
    var sourceInsightContext: String = ""
    var sourcePlanID: UUID?
    var sourceAngle: String = ""
    var contentTypeRaw: String
    var platformRaw: String
    var body: String
    var tags: String
    var overrideNote: String = ""
    var version: Int = 1
    var statusRaw: String = ProjectPublishStatus.draft.rawValue
    var scheduledAt: Date?
    var publishedURL: String = ""
    var impressions: Int = 0
    var likes: Int = 0
    var saves: Int = 0
    var comments: Int = 0
    var linkClicks: Int = 0
    var downloads: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    init(title: String, productID: String, contentType: ProjectContentType = .text, platform: String = "小红书", body: String = "", tags: String = "") {
        self.title = title; self.productID = productID; self.contentTypeRaw = contentType.rawValue; self.platformRaw = platform; self.body = body; self.tags = tags
    }
    var contentType: ProjectContentType { get { ProjectContentType(rawValue: contentTypeRaw) ?? .text } set { contentTypeRaw = newValue.rawValue } }
    var publishStatus: ProjectPublishStatus { get { ProjectPublishStatus(rawValue: statusRaw) ?? .draft } set { statusRaw = newValue.rawValue } }
    var isPublished: Bool { publishStatus == .published || !publishedURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

@Model final class ProjectAsset {
    var id: UUID = UUID(); var projectID: UUID; var filename: String; var imageData: Data; var sortOrder: Int
    init(projectID: UUID, filename: String, imageData: Data, sortOrder: Int = 0) { self.projectID = projectID; self.filename = filename; self.imageData = imageData; self.sortOrder = sortOrder }
}

@Model final class ProjectVersion {
    var id: UUID = UUID()
    var projectID: UUID
    var version: Int
    var title: String
    var body: String
    var tags: String
    var platformRaw: String
    var createdAt: Date = Date()
    init(projectID: UUID, version: Int, title: String, body: String, tags: String, platform: String) { self.projectID = projectID; self.version = version; self.title = title; self.body = body; self.tags = tags; self.platformRaw = platform }
}

@Model final class PublishAttempt {
    var id: UUID = UUID(); var projectID: UUID; var platform: String; var action: String; var succeeded: Bool; var message: String; var createdAt: Date = Date()
    init(projectID: UUID, platform: String, action: String, succeeded: Bool, message: String = "") { self.projectID = projectID; self.platform = platform; self.action = action; self.succeeded = succeeded; self.message = message }
}

@Model final class ContentDraft {
    var id: UUID = UUID()
    var productID: String
    var title: String
    var body: String
    var tags: String
    var statusRaw: String = DraftStatus.draft.rawValue
    var scheduledAt: Date?
    var sourceIDs: [String]
    var overrideNote: String = ""
    var publishedURL: String = ""
    var impressions: Int = 0
    var likes: Int = 0
    var saves: Int = 0
    var comments: Int = 0
    var createdAt: Date = Date()
    var status: DraftStatus { get { DraftStatus(rawValue: statusRaw) ?? .draft } set { statusRaw = newValue.rawValue } }
    init(productID: String, title: String, body: String, tags: String, sourceIDs: [String]) { self.productID = productID; self.title = title; self.body = body; self.tags = tags; self.sourceIDs = sourceIDs }
}

@Model final class ReviewEvent {
    var id: UUID = UUID(); var draftID: UUID; var status: String; var note: String; var createdAt: Date = Date()
    init(draftID: UUID, status: String, note: String = "") { self.draftID = draftID; self.status = status; self.note = note }
}
