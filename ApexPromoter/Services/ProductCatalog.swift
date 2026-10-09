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
    /// 官网抓取专用短超时会话：GitHub Pages 在部分网络下会长时间停滞，
    /// URLSession 默认请求超时 60 秒、资源超时 7 天，表现为界面一直卡在「正在同步」。
    private static let syncSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 20
        return URLSession(configuration: configuration)
    }()

    static func fetchPromotionBrief(for product: ProductSeed) async throws -> WebsitePromotionBrief {
        let url = URL(string: product.websiteURL)!
        let (data, response) = try await syncSession.data(from: url)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw URLError(.badServerResponse) }
        let html = String(decoding: data, as: UTF8.self)
        return WebsitePromotionBrief.parse(WebsiteTextCleaner.clean(html), product: product)
    }
    static func fetchPromotionBrief(urlString: String, fallbackAudience: String, fallbackSummary: String, fallbackBenefits: [String]) async throws -> WebsiteImportResult {
        guard let url = URL(string: urlString), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme), url.host != nil else { throw URLError(.badURL) }
        let (data, response) = try await syncSession.data(from: url)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw URLError(.badServerResponse) }
        let cleaned = WebsiteTextCleaner.clean(String(decoding: data, as: UTF8.self))
        guard !cleaned.isEmpty else { throw URLError(.cannotDecodeContentData) }
        return WebsiteImportResult(sourceURL: url, cleanedText: cleaned, brief: WebsitePromotionBrief.parse(cleaned, fallbackAudience: fallbackAudience, fallbackSummary: fallbackSummary, fallbackBenefits: fallbackBenefits))
    }
    static func fetchStoreLinks() async throws -> [String: String] {
        let url = URL(string: "https://botonwa83-byte.github.io/")!
        let (data, response) = try await syncSession.data(from: url)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw URLError(.badServerResponse) }
        return parseStoreLinks(from: String(decoding: data, as: UTF8.self))
    }

    /// 从官网 HTML 提取 App Store 链接，key 为链接末段（App ID）。
    /// 官网页面会在多个版块重复放置同一链接，必须去重容错——
    /// 曾因 `Dictionary(uniqueKeysWithValues:)` 遇到重复 key 直接崩溃（SIGTRAP）。
    static func parseStoreLinks(from html: String) -> [String: String] {
        let pattern = #"https://apps\.apple\.com/[^\"'<> ]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [:] }
        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
        let links = matches.compactMap { Range($0.range, in: html).map { String(html[$0]) } }
        var result: [String: String] = [:]
        for link in links {
            guard let last = link.split(separator: "/").last else { continue }
            if result[String(last)] == nil { result[String(last)] = link }
        }
        return result
    }
}

struct ProductSeed: Codable { let id, name, audience, summary: String; let claims: [String]; let sourceURL: String
    var storeURLOverride: String? = nil
    static let appStoreIDs = ["physicsapex":"6779031451", "mathapex":"6778461030", "chemapex":"6780327495", "bioapex":"6780727579", "chinapex":"6781556016", "engapex":"6784478791", "geogapex":"6783594491", "histapex":"6783254820", "polapex":"6783150236", "wordpulse":"6767762376", "chintop":"6815168238", "engtop":"6815115946"]
    static let releasedIDs: Set<String> = ["physicsapex", "mathapex", "chemapex", "bioapex", "polapex", "engapex", "chinapex", "histapex", "geogapex", "wordpulse", "chintop", "engtop"]
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
            "wordpulse": "用短时高频复习保持词汇节奏，把今天背过的词真正带到下一次复习。",
            "chintop": "语文不是凭感觉：现代文、文言文、古诗词、作文、综合学习五大专题，逐题解析加错因定位加能力地图。官方自研，永久免费。",
            "mathtop": "数学不是刷题量：88 个知识点各 10 道固定题组，答完就出解析；错题自动进变身器重做。官方自研，永久免费。",
            "engtop": "英语提分不靠刷题量：提分雷达告诉你先打哪一关，错因诊断告诉你分丢在哪。主线七关加两个写作工坊，官方自研，永久免费。"
        ][id] ?? summary
    }
    /// 下载地址：内置 App Store 链接是权威来源，不依赖网络同步。
    /// 优先级：用户产品的覆盖值 → 代码内置 App Store ID → 可选同步的官网缓存 → 官网。
    var storeURL: String {
        if let storeURLOverride, !storeURLOverride.isEmpty { return storeURLOverride }
        if let appID = Self.appStoreIDs[id], !appID.isEmpty { return "https://apps.apple.com/cn/app/id\(appID)" }
        if let cached = UserDefaults.standard.string(forKey: "storeURL.\(id)"), !cached.isEmpty { return cached }
        return sourceURL
    }
    var isReleased: Bool {
        if let storeURLOverride, !storeURLOverride.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        return Self.releasedIDs.contains(id)
    }
    /// 官网地址：始终指向官方产品页，也是未上架产品的下载地址入口。
    var officialSiteURL: String { sourceURL }
    /// 下载地址：已上架取 App Store 链接，未上架回退到官网。
    var downloadURL: String { isReleased ? storeURL : officialSiteURL }
    /// 文案末尾的下载与官网信息，保证每条生成内容都带官网和下载地址。
    var availabilityLine: String {
        isReleased ? "下载地址（App Store）：\(storeURL)" : "下载地址（官网，上架审核中）：\(officialSiteURL)"
    }
    var linkSection: String {
        let lines = ["开发者：\(developer)", availabilityLine]
        return isReleased ? (lines + ["官网：\(officialSiteURL)"]).joined(separator: "\n") : lines.joined(separator: "\n")
    }
    var developer: String { id == "mathapex" ? "Top King" : "Kingtop Education" }
    var websiteURL: String { sourceURL }
    /// 产品图标在 App bundle 内的路径。xcodegen 会把 Resources 下的图片拍平放进
    /// bundle 根目录，所以按文件名直接查找；带目录查找仅作打包方式变化的兜底。
    var iconBundlePath: String? {
        Bundle.main.path(forResource: id, ofType: "png")
            ?? Bundle.main.path(forResource: id, ofType: "png", inDirectory: "ProductIcons")
    }
}

enum ProductCatalog {
    static func seed(from product: CustomerProduct) -> ProductSeed {
        ProductSeed(id: product.id.uuidString, name: product.name, audience: product.audience, summary: product.summary, claims: product.keyBenefits.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }, sourceURL: product.websiteURL, storeURLOverride: product.storeURL)
    }
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
        .init(id: "wordpulse", name: "WordPulse", audience: "英语词汇学习者", summary: "用短时高频复习保持词汇记忆节奏。", claims: ["支持词汇持续复习", "提供学习进度反馈"], sourceURL: "https://botonwa83-byte.github.io/wordpulse.html"),
        .init(id: "chintop", name: "ChinTop", audience: "小升初到初中语文学习者", summary: "把语文拆成现代文阅读、文言文解码、古诗词鉴赏、考场作文升格和综合性学习五个能练的专题，每题带逐条解析和错因定位，练完就知道分丢在哪。", claims: ["五个专题共 307 道题，每题带逐条解析", "能力地图量化证据提取、结构推理、规范表达、创意写作与复盘迁移", "12 张方法卡加每日短任务，练方法而不是背答案", "五大专题全部免费开放，官方自研永久免费"], sourceURL: "https://botonwa83-byte.github.io/ChinTop/"),
        .init(id: "mathtop", name: "MathTop", audience: "小学高年级到初中数学学习者", summary: "把初中到小学高年级的数学拆成 88 个能练的知识点，每个知识点一组 10 道题，从基础到变式再到应用，答完立刻出解析，错题自动进「错题变身器」。", claims: ["88 个知识点各 10 道固定题组，答完出解析并定位错因", "错题变身器：错题重做加变式，直到真正过掉", "能力地图量化数感、空间、推理、建模、数据五项能力", "全部知识点与仿真题组免费开放，官方自研永久免费"], sourceURL: "https://botonwa83-byte.github.io/MathTop/"),
        .init(id: "engtop", name: "EngTop", audience: "中考到高考英语学习者", summary: "不只告诉你错了，还告诉你分丢在哪、下一步先打哪一关：主线七关配套题与即时诊断，配合提分雷达和错因诊断安排练习顺序。", claims: ["主线七关覆盖语法填空、完形、七选五、阅读、应用文、读后续写与听力", "提分雷达按「规则强度 × 你的失分」推荐先打哪一关", "错因诊断把错误归到四类根因并给出对应建议", "主线七关与提分雷达、考点图谱全部免费，官方自研永久免费"], sourceURL: "https://botonwa83-byte.github.io/EngTop/")
    ]

    static let websiteBaseURL = "https://botonwa83-byte.github.io"
    /// 官方内置目录：Apex 系列、WordPulse 与 Top 系列（语数外）同属一个产品家族，免费用户均可推广。
    static var builtInSeeds: [ProductSeed] { seeds }
    static var apexSeeds: [ProductSeed] { seeds.filter { $0.id.hasSuffix("apex") } }
    static func applyStoreLinks(_ links: [String: String]) {
        for (product, appID) in ProductSeed.appStoreIDs { if let link = links[appID] { UserDefaults.standard.set(link, forKey: "storeURL.\(product)") } }
        UserDefaults.standard.set(Date(), forKey: "website.lastSync")
    }
}
