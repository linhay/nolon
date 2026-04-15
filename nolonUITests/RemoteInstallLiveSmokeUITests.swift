import Foundation
import XCTest

@MainActor
final class RemoteInstallLiveSmokeUITests: XCTestCase {
    private var app: XCUIApplication?

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        if let app, app.state != .notRunning {
            app.terminate()
        }
        app = nil
    }

    func testBDD_GivenClawdhubLearnSkill_WhenInstallingIntoClaudeCode_ThenUILeavesInstallingStateAndSkillAppearsOnDisk() throws {
        try XCTSkipIf(
            ProcessInfo.processInfo.environment["CI"] == "1",
            "CI 环境跳过真实 live smoke。"
        )

        try ResourceDeletionUITestLaunchContext.terminateExistingNolonProcesses()

        let targetPath = URL(fileURLWithPath: ("~/.claude/skills/learn" as NSString).expandingTildeInPath)
        try XCTSkipIf(
            FileManager.default.fileExists(atPath: targetPath.path),
            "目标路径已存在，当前 smoke 无法证明一次真实安装：\(targetPath.path)"
        )

        let app = XCUIApplication(bundleIdentifier: "nolon.overloaded.com")
        app.launchArguments += ["-ApplePersistenceIgnoreState", "YES"]
        app.launchEnvironment = makeLaunchEnvironment()
        app.launch()
        app.activate()
        self.app = app

        XCTAssertTrue(
            app.windows.firstMatch.waitForExistence(timeout: 20),
            "App 窗口未在预期时间内出现。"
        )

        try openResourceCenterIfNeeded(in: app)
        try focusSearch(in: app, query: "learn")

        let installButton = app.buttons.matching(NSPredicate(format: "label == %@", "Install")).firstMatch
        XCTAssertTrue(
            installButton.waitForExistence(timeout: 30),
            "未找到 Install 按钮。\nUI Tree:\n\(app.debugDescription)"
        )

        installButton.tap()

        XCTAssertTrue(
            waitUntil(timeout: 60) {
                FileManager.default.fileExists(atPath: targetPath.path)
            },
            "点击安装后，目标 skill 未落盘：\(targetPath.path)\nUI Tree:\n\(app.debugDescription)"
        )

        let installedText = app.staticTexts.matching(NSPredicate(format: "label == %@", "Installed")).firstMatch
        XCTAssertTrue(
            installedText.waitForExistence(timeout: 45),
            "安装完成后 UI 未回到 Installed。\nUI Tree:\n\(app.debugDescription)"
        )
    }

    private func makeLaunchEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["NOLON_UI_TEST_MODE"] = "1"
        environment["NOLON_UI_TEST_SKIP_ONBOARDING"] = "1"
        environment["NOLON_UI_TEST_OPEN_RESOURCE_CENTER"] = "1"
        environment["NOLON_UI_TEST_RESOURCE_REPOSITORY_NAME"] = "Waza"
        environment["NOLON_UI_TEST_RESOURCE_TAB"] = "skills"
        environment["NOLON_UI_TEST_RESOURCE_SEARCH"] = ProcessInfo.processInfo.environment["NOLON_LIVE_SMOKE_SEARCH"] ?? "learn"
        environment["NOLON_UI_TEST_SELECTED_PROVIDER_INDEX"] = ProcessInfo.processInfo.environment["NOLON_LIVE_SMOKE_PROVIDER_INDEX"] ?? "2"
        return environment
    }

    private func openResourceCenterIfNeeded(in app: XCUIApplication) throws {
        if resourceCenterWindow(in: app).waitForExistence(timeout: 20)
            || resourceCenterSearchField(in: app).waitForExistence(timeout: 20) {
            return
        }

        let resourceCenterWindow = resourceCenterWindow(in: app)
        if resourceCenterWindow.waitForExistence(timeout: 10) {
            return
        }

        let clawdhubButton = app.descendants(matching: .button).matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Clawdhub")
        ).firstMatch
        if clawdhubButton.waitForExistence(timeout: 5) {
            clawdhubButton.tap()
        }

        XCTAssertTrue(
            resourceCenterWindow.waitForExistence(timeout: 30)
                || resourceCenterSearchField(in: app).waitForExistence(timeout: 30),
            "资源中心窗口未能成功打开。\nUI Tree:\n\(app.debugDescription)"
        )
    }

    private func focusSearch(in app: XCUIApplication, query: String) throws {
        let searchField = resourceCenterSearchField(in: app)
        XCTAssertTrue(
            searchField.waitForExistence(timeout: 15),
            "未找到资源中心搜索框。\nUI Tree:\n\(app.debugDescription)"
        )

        searchField.tap()
        app.typeKey("a", modifierFlags: .command)
        app.typeKey(XCUIKeyboardKey.delete.rawValue, modifierFlags: [])
        searchField.typeText(query)
    }

    private func resourceCenterSearchField(in app: XCUIApplication) -> XCUIElement {
        app.textFields.matching(
            NSPredicate(format: "placeholderValue ==[c] %@ OR value ==[c] %@", "Search", "Search")
        ).firstMatch
    }

    private func resourceCenterWindow(in app: XCUIApplication) -> XCUIElement {
        app.windows.matching(
            NSPredicate(format: "identifier == %@ OR title CONTAINS[c] %@", "resource-center", "Resource Center")
        ).firstMatch
    }

    private func waitUntil(
        timeout: TimeInterval,
        pollInterval: TimeInterval = 0.1,
        condition: () -> Bool
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(pollInterval))
        }
        return condition()
    }
}
