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
            ["适合", "面向", "目标人群", "目标用户"].contains { line.contains($0) }
        } ?? lines.dropFirst().first { line in
            ["用户", "团队", "商户", "开发者", "学生", "学习者"].contains { line.contains($0) }
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
    static let appStoreIDs = ["physicsapex":"6779031451", "mathapex":"6778461030", "chemapex":"6780327495", "bioapex":"6780727579", "chinapex":"6781556016", "engapex":"6784478791", "geogapex":"6783594491", "histapex":"6783254820", "polapex":"6783150236", "wordpulse":"6767762376"]
    static let releasedIDs: Set<String> = ["physicsapex", "mathapex", "chemapex", "bioapex", "polapex", "engapex", "chinapex", "histapex", "geogapex", "wordpulse"]
    var promoHook: String {
        [
            "physicsapex": "用互动模拟和解题工具训练物理思维。",
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
        return "https://apps.apple.com/cn/app/id\(Self.appStoreIDs[id] ?? "")"
    }
    var isReleased: Bool { Self.releasedIDs.contains(id) }
    var developer: String { id == "mathapex" ? "Top King" : "Kingtop Education" }
    var websiteURL: String { sourceURL }
    var iconAssetName: String { "ProductIcons/\(id)" }
}

enum ProductCatalog {
    static let seeds: [ProductSeed] = [
        .init(id: "physicsapex", name: "PhysicsApex", audience: "初高中物理学习者", summary: "用互动模拟沙盘、考点地图、错因诊断和智能复习，让物理从抽象公式回到可观察的现象。", claims: ["提供互动模拟沙盘与考点地图", "支持错因诊断和智能复习"], sourceURL: "https://botonwa83-byte.github.io/physicsapex.html"),
        .init(id: "mathapex", name: "MathApex", audience: "初高中数学学习者", summary: "用高阶思维打通初高中数学关键题，通过常规解与降维解双解对照形成可复用的方法。", claims: ["提供 595 道压轴题与双解对照", "包含 150+ 公式及错题复习"], sourceURL: "https://botonwa83-byte.github.io/mathapex.html"),
        .init(id: "chemapex", name: "ChemApex", audience: "初高中化学学习者", summary: "从元素星图、方程式剧本库到化学神探，把推断题、守恒题和实验题拆成可复用的识局方法。", claims: ["提供元素星图与方程式库", "覆盖守恒战例和化学推断训练"], sourceURL: "https://botonwa83-byte.github.io/chemapex.html"),
        .init(id: "bioapex", name: "BioApex", audience: "初高中生物学习者", summary: "通过过程剧场、考点图谱、遗传神探、稳态回路和易混辨析，帮助学生看见生命系统如何运转。", claims: ["提供过程剧场与考点图谱", "包含遗传推理、稳态回路和易混辨析"], sourceURL: "https://botonwa83-byte.github.io/bioapex.html"),
        .init(id: "polapex", name: "PolApex", audience: "初高中道法与思想政治学习者", summary: "围绕高权重记忆、主体职责、材料切片、答案工厂和选择题排雷，把知识变成可迁移的答案。", claims: ["支持材料切片与主体定位", "提供答案工厂和选择题排雷训练"], sourceURL: "https://botonwa83-byte.github.io/polapex.html"),
        .init(id: "engapex", name: "EngApex", audience: "初高中英语学习者", summary: "围绕句法解码、完形线索、阅读题型和写作框架，让英语从语感变成可操作的解题流程。", claims: ["提供句法解码和完形线索训练", "覆盖阅读题型与写作框架"], sourceURL: "https://botonwa83-byte.github.io/engapex.html"),
        .init(id: "chinapex", name: "ChinApex", audience: "初高中语文学习者", summary: "通过原文定位、文言解码、默写星图、作文工坊和阅卷人之眼，把语文变成可操作的采分点训练。", claims: ["提供采分点与阅卷视角训练", "覆盖作文、文言文和默写训练"], sourceURL: "https://botonwa83-byte.github.io/chinapex.html"),
        .init(id: "histapex", name: "HistApex", audience: "初高中历史学习者", summary: "用时间博物馆、史料相遇、历史规律、专题突破和答案模板，把背事件推进到解释变化与因果。", claims: ["提供时间线与史料题训练", "支持历史规律迁移和答案模板"], sourceURL: "https://botonwa83-byte.github.io/histapex.html"),
        .init(id: "geogapex", name: "GeogApex", audience: "初高中地理学习者", summary: "围绕空间定位、图表判读、自然过程、人文区位、区域发展和答案工厂，训练稳定的地理解题流程。", claims: ["支持图表判读与空间定位", "提供区位分析和综合题模板"], sourceURL: "https://botonwa83-byte.github.io/geogapex.html"),
        .init(id: "wordpulse", name: "WordPulse", audience: "英语词汇学习者", summary: "用短时高频复习保持词汇记忆节奏。", claims: ["支持词汇持续复习", "提供学习进度反馈"], sourceURL: "https://botonwa83-byte.github.io/wordpulse.html")
    ]

    static let websiteBaseURL = "https://botonwa83-byte.github.io"
    static var apexSeeds: [ProductSeed] { seeds.filter { $0.id.hasSuffix("apex") } }
    static func applyStoreLinks(_ links: [String: String]) {
        for (product, appID) in ProductSeed.appStoreIDs { if let link = links[appID] { UserDefaults.standard.set(link, forKey: "storeURL.\(product)") } }
        UserDefaults.standard.set(Date(), forKey: "website.lastSync")
    }
}
