import Foundation
import XCTest

@MainActor
final class ResourceDeletionUITests: XCTestCase {
    private var tempRoot: URL!
    private var launchContext: ResourceDeletionUITestLaunchContext!
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        try ResourceDeletionUITestLaunchContext.terminateExistingNolonProcesses()
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("nolon-uitests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        launchContext = ResourceDeletionUITestLaunchContext(tempRoot: tempRoot)
        try launchContext.seedFixtureResources()
    }

    override func tearDownWithError() throws {
        if let app, app.state != .notRunning {
            app.terminate()
        }
        app = nil
        launchContext = nil

        if let tempRoot {
            try? FileManager.default.removeItem(at: tempRoot)
        }
        tempRoot = nil
    }

    func testBDD_GivenGlobalSkill_WhenDeleteThroughResourceCenter_ThenGlobalCacheFolderIsRemoved() throws {
        let deleted = try runDeletionScenario(
            search: "gemini",
            buttonIdentifier: "uitest.delete-global-skill.gemini",
            removedPath: tempRoot.appendingPathComponent("skills/gemini"),
            skillSlug: "gemini"
        )
        XCTAssertTrue(deleted, "点击删除后，技能目录仍然存在。")
    }

    func testBDD_GivenGlobalWorkflow_WhenDeleteThroughResourceCenter_ThenGlobalCacheFileIsRemoved() throws {
        let deleted = try runDeletionScenario(
            search: "daily-sync",
            selectedTab: "workflows",
            buttonIdentifier: "uitest.delete-global-workflow.daily-sync",
            removedPath: tempRoot.appendingPathComponent("workflows/daily-sync.md"),
            workflowSlug: "daily-sync"
        )
        XCTAssertTrue(deleted, "点击删除后，workflow 文件仍然存在。")
    }

    func testBDD_GivenGlobalMCP_WhenDeleteThroughResourceCenter_ThenGlobalCacheFileIsRemoved() throws {
        let deleted = try runDeletionScenario(
            search: "xcode",
            selectedTab: "mcps",
            buttonIdentifier: "uitest.delete-global-mcp.xcode",
            removedPath: tempRoot.appendingPathComponent("mcps/xcode.json"),
            mcpSlug: "xcode"
        )
        XCTAssertTrue(deleted, "点击删除后，MCP 文件仍然存在。")
    }

    private func runDeletionScenario(
        search: String,
        selectedTab: String? = nil,
        buttonIdentifier: String,
        removedPath: URL,
        skillSlug: String? = nil,
        workflowSlug: String? = nil,
        mcpSlug: String? = nil
    ) throws -> Bool {
        let app = XCUIApplication(bundleIdentifier: "nolon.overloaded.com")
        app.launchEnvironment = launchContext.makeLaunchEnvironment(
            search: search,
            selectedTab: selectedTab,
            skillSlug: skillSlug,
            workflowSlug: workflowSlug,
            mcpSlug: mcpSlug
        )
        app.launch()
        self.app = app

        XCTAssertTrue(
            app.windows.firstMatch.waitForExistence(timeout: 20),
            "App 窗口未在预期时间内出现。"
        )

        let deleteButton = app.buttons[buttonIdentifier]
        guard deleteButton.waitForExistence(timeout: 20) else {
            XCTFail("未找到删除按钮 \(buttonIdentifier)。\nUI Tree:\n\(app.debugDescription)")
            return false
        }

        deleteButton.tap()

        return launchContext.waitUntil(timeout: 20) {
            !FileManager.default.fileExists(atPath: removedPath.path)
        }
    }
}
