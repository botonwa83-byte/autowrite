import Foundation

enum WebsiteTextCleaner {
    static func clean(_ html: String) -> String {
        var text = html
        text = text.replacingOccurrences(of: #"(?is)<(script|style|noscript|svg|pre|code)[^>]*>.*?</\1>"#, with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: #"(?is)<[^>]+>"#, with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "&nbsp;", with: " ").replacingOccurrences(of: "&amp;", with: "&").replacingOccurrences(of: "&lt;", with: "<").replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: #"https?://[^\s]+|\b[a-zA-Z_$][a-zA-Z0-9_$./:-]{2,}\b"#, with: " ", options: .regularExpression)
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let meaningful = lines.filter { line in
            guard !line.isEmpty else { return false }
            let chinese = line.unicodeScalars.filter { (0x4E00...0x9FFF).contains($0.value) }.count
            let letters = line.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
            return chinese >= 4 || (chinese >= 2 && letters <= chinese * 2)
        }
        var result = meaningful.joined(separator: "\n")
        result = result.replacingOccurrences(of: #"[ \t]+"#, with: " ", options: .regularExpression)
        result = result.replacingOccurrences(of: #"\n{2,}"#, with: "\n", options: .regularExpression)
        return String(result.prefix(1_200)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct WebsitePromotionBrief {
    var positioning: String
    var audience: String
    var highlights: [String]

    var editableText: String {
        get { ([positioning, audience] + highlights).filter { !$0.isEmpty }.joined(separator: "\n") }
        set {
            let lines = newValue.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            positioning = lines.first ?? ""
            audience = lines.dropFirst().first ?? ""
            highlights = Array(lines.dropFirst(2).prefix(6))
        }
    }

    static func parse(_ text: String, product: ProductSeed) -> WebsitePromotionBrief {
        parse(text, fallbackAudience: product.audience, fallbackSummary: product.summary, fallbackBenefits: product.claims)
    }

    static func parse(_ text: String, fallbackAudience: String, fallbackSummary: String, fallbackBenefits: [String]) -> WebsitePromotionBrief {
        var seen = Set<String>()
        let lines = text.components(separatedBy: CharacterSet(charactersIn: "。！？\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 6 && seen.insert($0).inserted }
        let audience = lines.first { line in
            ["适合", "面向", "用户", "团队", "商户", "开发者", "学生", "学习者"].contains { line.contains($0) }
        }
        let highlights = lines.filter { line in
            ["支持", "提供", "帮助", "可以", "能够", "功能", "优势"].contains { line.contains($0) }
                && line != audience
                && line != lines.first
        }
        return WebsitePromotionBrief(
            positioning: lines.first ?? fallbackSummary,
            audience: audience ?? fallbackAudience,
            highlights: Array((highlights.isEmpty ? fallbackBenefits : highlights).prefix(6))
        )
    }
}

struct WebsiteImportResult: Identifiable {
    let sourceURL: URL
    let cleanedText: String
    var brief: WebsitePromotionBrief
    var id: String { sourceURL.absoluteString }
}

enum WebsiteSyncService {
    static func fetchPromotionBrief(for product: ProductSeed) async throws -> WebsitePromotionBrief {
        let url = URL(string: product.websiteURL)!
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw URLError(.badServerResponse) }
        let html = String(decoding: data, as: UTF8.self)
        return WebsitePromotionBrief.parse(WebsiteTextCleaner.clean(html), product: product)
    }
    static func fetchPromotionBrief(urlString: String, fallbackAudience: String, fallbackSummary: String, fallbackBenefits: [String]) async throws -> WebsiteImportResult {
        guard let url = URL(string: urlString), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme), url.host != nil else { throw URLError(.badURL) }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw URLError(.badServerResponse) }
        let cleaned = WebsiteTextCleaner.clean(String(decoding: data, as: UTF8.self))
        guard !cleaned.isEmpty else { throw URLError(.cannotDecodeContentData) }
        return WebsiteImportResult(sourceURL: url, cleanedText: cleaned, brief: WebsitePromotionBrief.parse(cleaned, fallbackAudience: fallbackAudience, fallbackSummary: fallbackSummary, fallbackBenefits: fallbackBenefits))
    }
    static func fetchStoreLinks() async throws -> [String: String] {
        let url = URL(string: "https://botonwa83-byte.github.io/")!
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw URLError(.badServerResponse) }
        let html = String(decoding: data, as: UTF8.self)
        let pattern = #"https://apps\.apple\.com/[^\"'<> ]+"#
        let matches = try NSRegularExpression(pattern: pattern).matches(in: html, range: NSRange(html.startIndex..., in: html))
        let links = matches.compactMap { Range($0.range, in: html).map { String(html[$0]) } }
        return Dictionary(uniqueKeysWithValues: links.compactMap { link in link.split(separator: "/").last.map { (String($0), link) } })
    }
}

struct ProductSeed: Codable { let id, name, audience, summary: String; let claims: [String]; let sourceURL: String
    var promoHook: String {
        [
            "physicsapex": "用守恒、对称、等效俯瞰高考压轴：看到压轴题，一招降维就能秒。",
            "mathapex": "装上 APEX，解锁「降维秒杀」超能力：用大学思维碾压高考压轴。每道题都有常规解法与降维秒杀双解对照。",
            "chemapex": "从初中的瓶瓶罐罐，到高考的守恒推断，看见反应背后的棋局，一招降维就能秒。",
            "bioapex": "不刷题海，只把每个考点教懂、验会、记牢：过程剧场、考点地图、遗传神探，让复杂机制看得见。",
            "geogapex": "从经纬定位到区域综合题，看穿材料背后的得分点，一套读图武器就能稳。",
            "histapex": "从朝代脉络到史料分析题，看穿材料背后的得分点，一套时空武器就能稳。",
            "polapex": "从死记硬背的口号，到材料分析与答案输出，看清材料主体与考点，一步步写出像答案的答案。",
            "chinapex": "从字词默写到阅读文言与高考作文，看见答案背后的采分点，把语文从玄学变成可操作。",
            "engapex": "高考英语 150 分拆开建模，用算法导航，按提分性价比走最短路径。",
            "wordpulse": "用短时高频复习保持词汇节奏，把今天背过的词真正带到下一次复习。"
        ][id] ?? summary
    }
    var storeURL: String {
        if let cached = UserDefaults.standard.string(forKey: "storeURL.\(id)"), !cached.isEmpty { return cached }
        let ids = ["physicsapex":"6779031451", "mathapex":"6778461030", "chemapex":"6780327495", "bioapex":"6780727579", "chinapex":"6781556016", "engapex":"6784478791", "geogapex":"6783594491", "histapex":"6783254820", "polapex":"6783150236", "wordpulse":"6767762376"]
        return "https://apps.apple.com/cn/app/id\(ids[id] ?? "")"
    }
    var developer: String { id == "mathapex" ? "Top King" : "Kingtop Education" }
    var websiteURL: String { "https://botonwa83-byte.github.io/\(id).html" }
    var iconAssetName: String { "ProductIcons/\(id)" }
}

enum ProductCatalog {
    static let seeds: [ProductSeed] = [
        .init(id: "physicsapex", name: "PhysicsApex", audience: "高中物理学习者", summary: "用降维推导建立物理模型，覆盖核心考点。", claims: ["覆盖高中物理核心考点", "提供逐步推导与错题复习"], sourceURL: "https://botonwa83-byte.github.io/physicsapex.html"),
        .init(id: "mathapex", name: "MathApex", audience: "中学数学学习者", summary: "把复杂题型拆成可复用的方法与路径。", claims: ["按知识结构组织训练", "支持错题复习"], sourceURL: "https://botonwa83-byte.github.io/mathapex.html"),
        .init(id: "chemapex", name: "ChemApex", audience: "高中化学学习者", summary: "识局、记忆、巧算，形成化学解题闭环。", claims: ["覆盖重点知识模块", "提供方法讲解与练习"], sourceURL: "https://botonwa83-byte.github.io/chemapex.html"),
        .init(id: "bioapex", name: "BioApex", audience: "高中生物学习者", summary: "看见过程与机制，建立考点掌握闭环。", claims: ["围绕机制理解知识", "支持高频易混点复习"], sourceURL: "https://botonwa83-byte.github.io/bioapex.html")
        , .init(id: "polapex", name: "PolApex", audience: "政治学习者", summary: "用结构化方法梳理概念、时事与答题路径。", claims: ["覆盖核心知识结构", "提供答题方法训练"], sourceURL: "https://botonwa83-byte.github.io/polapex.html")
        , .init(id: "engapex", name: "EngApex", audience: "英语学习者", summary: "围绕词汇、语法和阅读建立持续学习路径。", claims: ["支持词汇与语法复习", "提供阅读方法训练"], sourceURL: "https://botonwa83-byte.github.io/engapex.html")
        , .init(id: "chinapex", name: "ChinaApex", audience: "语文学习者", summary: "把阅读、表达与积累变成可执行的学习步骤。", claims: ["覆盖语文重点能力", "支持积累与复习"], sourceURL: "https://botonwa83-byte.github.io/chinapex.html")
        , .init(id: "histapex", name: "HistApex", audience: "历史学习者", summary: "用时间线和因果关系建立历史知识网络。", claims: ["按时空结构组织知识", "提供重点复习路径"], sourceURL: "https://botonwa83-byte.github.io/histapex.html")
        , .init(id: "geogapex", name: "GeogApex", audience: "地理学习者", summary: "从地图、过程和区域联系理解地理问题。", claims: ["支持地图与区域分析", "提供考点复习"], sourceURL: "https://botonwa83-byte.github.io/geogapex.html")
        , .init(id: "wordpulse", name: "WordPulse", audience: "英语词汇学习者", summary: "用短时高频复习保持词汇记忆节奏。", claims: ["支持词汇持续复习", "提供学习进度反馈"], sourceURL: "https://botonwa83-byte.github.io/wordpulse.html")
    ]

    static let websiteBaseURL = "https://botonwa83-byte.github.io"
    static func applyStoreLinks(_ links: [String: String]) {
        let ids = ["physicsapex":"6779031451", "mathapex":"6778461030", "chemapex":"6780327495", "bioapex":"6780727579", "chinapex":"6781556016", "engapex":"6784478791", "geogapex":"6783594491", "histapex":"6783254820", "polapex":"6767762376", "wordpulse":"6778461030"]
        for (product, appID) in ids { if let link = links[appID] { UserDefaults.standard.set(link, forKey: "storeURL.\(product)") } }
        UserDefaults.standard.set(Date(), forKey: "website.lastSync")
    }
}
