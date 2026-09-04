import Foundation
import SwiftData

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
