import XCTest

final class ApexPromoterUITests: XCTestCase {
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        dismissGuideIfPresented(app)
        return app
    }

    /// 首次启动会自动弹出 7 步教程浮层，它盖住标签栏会让点击失败。
    /// 该标记在模拟器里跨用例保留，所以两种状态都要能处理。
    private func dismissGuideIfPresented(_ app: XCUIApplication) {
        for label in ["稍后再看", "完成"] {
            let button = app.buttons[label]
            if button.exists { button.tap(); return }
        }
        let later = app.buttons["稍后再看"]
        if later.waitForExistence(timeout: 5) { later.tap() }
    }

    func testRootShowsDashboard() {
        let app = launchApp()
        XCTAssertTrue(app.navigationBars["Apex 宣传台"].waitForExistence(timeout: 5))
        // 按可见标题查询标签栏：SwiftUI 的 tabItem 标识符不会稳定透传到标签栏按钮上。
        XCTAssertTrue(app.tabBars.buttons["产品"].exists)
        XCTAssertTrue(app.tabBars.buttons["创作"].exists)
        XCTAssertTrue(app.tabBars.buttons["队列"].exists)
        XCTAssertTrue(app.tabBars.buttons["更多"].exists)
    }

    /// App 已全面免费：内置产品要能直接生成内容，任何情况下都不应出现付费墙。
    func testFreeUserCanComposeForBuiltInApexProduct() {
        let app = launchApp()
        app.tabBars.buttons["创作"].tap()

        XCTAssertTrue(app.buttons["生成纯文字发布包"].waitForExistence(timeout: 5), "创作页应可直接使用")
        XCTAssertFalse(app.staticTexts["一次性解锁专业版"].exists, "不应存在付费页")

        app.buttons["生成纯文字发布包"].tap()

        XCTAssertTrue(app.staticTexts["纯文字草稿已生成。"].waitForExistence(timeout: 5), "应能直接生成草稿")
        XCTAssertFalse(app.staticTexts["一次性解锁专业版"].exists, "生成不应弹出付费页")
    }

    /// 走真实导出流程验证封面品牌水印：DEBUG 钩子预置示例截图，创作页选 ChinTop，
    /// 切图文模式后导出轮播页。导出的 PNG 会在测试结束后从 App 容器取出人工目检。
    func testCarouselExportWatermarkIncludesBrandIcon() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-import-sample"]
        app.launch()
        dismissGuideIfPresented(app)
        app.tabBars.buttons["创作"].tap()
        XCTAssertTrue(app.buttons["生成纯文字发布包"].waitForExistence(timeout: 5))

        // 选择 ChinTop 产品（Form 里的 Picker；排除标签栏上 label 恰为「产品」的 tab）。
        let productRow = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH '产品' AND label != '产品'")
        ).firstMatch
        XCTAssertTrue(productRow.waitForExistence(timeout: 5), "应能找到产品选择行")
        productRow.tap()
        let menuItem = app.buttons["ChinTop"]
        if menuItem.waitForExistence(timeout: 3) {
            menuItem.tap()
        } else {
            let listRow = app.staticTexts["ChinTop"]
            XCTAssertTrue(listRow.waitForExistence(timeout: 5), "产品列表中应有 ChinTop")
            listRow.tap()
        }

        // 切到图文模式，确认示例截图已预置，然后导出全部轮播页。
        // 注意：Form 是懒加载，屏幕外的行不进可达性层级，需先滚动。
        app.buttons["图文"].tap()
        XCTAssertTrue(app.staticTexts["产品功能亮点"].waitForExistence(timeout: 5), "UI 测试钩子应预置示例截图")
        app.swipeUp()
        app.swipeUp()
        let exportButton = app.buttons["导出全部轮播页"]
        XCTAssertTrue(exportButton.waitForExistence(timeout: 5), "应能看到导出轮播页按钮")
        exportButton.tap()
        if !app.buttons["再次分享已导出的封面"].waitForExistence(timeout: 3) {
            app.swipeUp()
        }
        XCTAssertTrue(app.buttons["再次分享已导出的封面"].waitForExistence(timeout: 10), "封面应成功导出")
    }

    /// 同步官网期间界面必须保持响应：网络等待只挂起同步任务本身（超时 10 秒），
    /// 不允许阻塞主线程。曾因 URLSession 默认 7 天资源超时表现为「死机」。
    func testWebsiteSyncKeepsUIResponsive() {
        let app = launchApp()
        XCTAssertTrue(app.buttons["查看 7 步推广教程"].waitForExistence(timeout: 5), "首页应可见")

        app.buttons["同步官网产品链接"].tap()
        app.tabBars.buttons["产品"].tap()
        XCTAssertTrue(app.navigationBars["Apex 产品"].waitForExistence(timeout: 3), "同步期间应能立即切换标签页")

        app.tabBars.buttons["首页"].tap()
        let syncButton = app.buttons["同步官网产品链接"]
        XCTAssertTrue(syncButton.waitForExistence(timeout: 20), "同步结束（成功或超时失败）后按钮应恢复可点")
    }
}
