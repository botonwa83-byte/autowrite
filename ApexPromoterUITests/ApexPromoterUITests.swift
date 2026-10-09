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

    /// 走真实导出流程验证封面品牌水印：预置相册图片后，创作页选 ChinTop，
    /// 从照片图库导入、生成图文发布包并导出轮播页。导出的 PNG 会在测试结束后
    /// 从 App 容器取出人工目检。
    func testCarouselExportWatermarkIncludesBrandIcon() throws {
        let app = launchApp()
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

        // 切到图文模式，展开素材导入区，再从照片图库导入（测试前已用 simctl addmedia 预置）。
        app.buttons["图文"].tap()
        app.buttons["从照片图库导入截图"].tap()
        let photo = [
            app.scrollViews.otherElements.images.element(boundBy: 0),
            app.otherElements.images.element(boundBy: 0),
            app.cells.element(boundBy: 0)
        ].first { $0.waitForExistence(timeout: 8) }
        let pickerCell = try XCTUnwrap(photo, "照片选择器中应能看到预置照片")
        pickerCell.tap()
        sleep(2)
        print("L DEBUG after photo tap:\n\(app.debugDescription)")
        for label in ["添加", "Add", "完成", "Done"] {
            let button = app.buttons[label]
            if button.exists && button.isHittable { button.tap(); break }
        }
        sleep(1)
        print("L DEBUG after confirm:\n\(app.debugDescription)")

        // 导入完成后导出全部轮播页。
        XCTAssertTrue(app.staticTexts["已导入 1 张，发布前请核对每页截图和标题"].waitForExistence(timeout: 10), "应成功导入 1 张照片")
        app.buttons["导出全部轮播页"].tap()
        XCTAssertTrue(app.buttons["再次分享已导出的封面"].waitForExistence(timeout: 10), "封面应成功导出")
    }
}
