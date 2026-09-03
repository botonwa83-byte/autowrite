import Foundation

struct ProductSeed: Codable { let id, name, audience, summary: String; let claims: [String]; let sourceURL: String }

enum ProductCatalog {
    static let seeds: [ProductSeed] = [
        .init(id: "physicsapex", name: "PhysicsApex", audience: "高中物理学习者", summary: "用降维推导建立物理模型，覆盖核心考点。", claims: ["覆盖高中物理核心考点", "提供逐步推导与错题复习"], sourceURL: "https://kingtop-education-site.example/physicsapex.html"),
        .init(id: "mathapex", name: "MathApex", audience: "中学数学学习者", summary: "把复杂题型拆成可复用的方法与路径。", claims: ["按知识结构组织训练", "支持错题复习"], sourceURL: "https://kingtop-education-site.example/mathapex.html"),
        .init(id: "chemapex", name: "ChemApex", audience: "高中化学学习者", summary: "识局、记忆、巧算，形成化学解题闭环。", claims: ["覆盖重点知识模块", "提供方法讲解与练习"], sourceURL: "https://kingtop-education-site.example/chemapex.html"),
        .init(id: "bioapex", name: "BioApex", audience: "高中生物学习者", summary: "看见过程与机制，建立考点掌握闭环。", claims: ["围绕机制理解知识", "支持高频易混点复习"], sourceURL: "https://kingtop-education-site.example/bioapex.html")
    ]
}
