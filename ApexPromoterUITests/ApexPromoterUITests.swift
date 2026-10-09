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
}
