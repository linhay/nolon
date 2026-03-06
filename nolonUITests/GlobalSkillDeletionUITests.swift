import Foundation
import XCTest

@MainActor
final class GlobalSkillDeletionUITests: XCTestCase {
    private var tempRoot: URL!
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        try terminateExistingNolonProcesses()
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("nolon-uitests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        try seedGlobalSkill(slug: "gemini")
        try seedGlobalWorkflow(slug: "daily-sync")
        try seedGlobalMCP(slug: "xcode")
    }

    override func tearDownWithError() throws {
        if let app, app.state != .notRunning {
            app.terminate()
        }
        app = nil

        if let tempRoot {
            try? FileManager.default.removeItem(at: tempRoot)
        }
        tempRoot = nil
    }

    func testBDD_GivenGlobalSkill_WhenDeleteThroughResourceCenter_ThenGlobalCacheFolderIsRemoved() throws {
        let app = XCUIApplication(bundleIdentifier: "nolon.overloaded.com")
        app.launchEnvironment = launchEnvironment()
        app.launch()
        self.app = app

        XCTAssertTrue(
            app.windows.firstMatch.waitForExistence(timeout: 20),
            "App 窗口未在预期时间内出现。"
        )

        let deleteButton = app.buttons["uitest.delete-global-skill.gemini"]
        let deleteButtonExists = deleteButton.waitForExistence(timeout: 20)
        if !deleteButtonExists {
            XCTFail("未找到 global gemini delete button。\nUI Tree:\n\(app.debugDescription)")
            return
        }

        deleteButton.tap()

        let skillPath = tempRoot.appendingPathComponent("skills/gemini")
        let removed = try waitUntil(timeout: 20) {
            !FileManager.default.fileExists(atPath: skillPath.path)
        }
        XCTAssertTrue(removed, "点击删除后，\(skillPath.path) 仍然存在。")
    }

    func testBDD_GivenGlobalWorkflow_WhenDeleteThroughResourceCenter_ThenGlobalCacheFileIsRemoved() throws {
        let app = XCUIApplication(bundleIdentifier: "nolon.overloaded.com")
        app.launchEnvironment = launchEnvironment(
            search: "daily-sync",
            selectedTab: "workflows",
            workflowSlug: "daily-sync"
        )
        app.launch()
        self.app = app

        XCTAssertTrue(
            app.windows.firstMatch.waitForExistence(timeout: 20),
            "App 窗口未在预期时间内出现。"
        )

        let deleteButton = app.buttons["uitest.delete-global-workflow.daily-sync"]
        let deleteButtonExists = deleteButton.waitForExistence(timeout: 20)
        if !deleteButtonExists {
            XCTFail("未找到 global daily-sync workflow delete button。\nUI Tree:\n\(app.debugDescription)")
            return
        }

        deleteButton.tap()

        let workflowPath = tempRoot.appendingPathComponent("workflows/daily-sync.md")
        let removed = try waitUntil(timeout: 20) {
            !FileManager.default.fileExists(atPath: workflowPath.path)
        }
        XCTAssertTrue(removed, "点击删除后，\(workflowPath.path) 仍然存在。")
    }

    func testBDD_GivenGlobalMCP_WhenDeleteThroughResourceCenter_ThenGlobalCacheFileIsRemoved() throws {
        let app = XCUIApplication(bundleIdentifier: "nolon.overloaded.com")
        app.launchEnvironment = launchEnvironment(
            search: "xcode",
            selectedTab: "mcps",
            mcpSlug: "xcode"
        )
        app.launch()
        self.app = app

        XCTAssertTrue(
            app.windows.firstMatch.waitForExistence(timeout: 20),
            "App 窗口未在预期时间内出现。"
        )

        let deleteButton = app.buttons["uitest.delete-global-mcp.xcode"]
        let deleteButtonExists = deleteButton.waitForExistence(timeout: 20)
        if !deleteButtonExists {
            XCTFail("未找到 global xcode MCP delete button。\nUI Tree:\n\(app.debugDescription)")
            return
        }

        deleteButton.tap()

        let mcpPath = tempRoot.appendingPathComponent("mcps/xcode.json")
        let removed = try waitUntil(timeout: 20) {
            !FileManager.default.fileExists(atPath: mcpPath.path)
        }
        XCTAssertTrue(removed, "点击删除后，\(mcpPath.path) 仍然存在。")
    }

    private func launchEnvironment(
        search: String = "gemini",
        selectedTab: String? = nil,
        skillSlug: String? = "gemini",
        workflowSlug: String? = nil,
        mcpSlug: String? = nil
    ) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["NOLON_HOME"] = tempRoot.path
        environment["NOLON_UI_TEST_MODE"] = "1"
        environment["NOLON_UI_TEST_SKIP_ONBOARDING"] = "1"
        environment["NOLON_UI_TEST_OPEN_RESOURCE_CENTER"] = "1"
        environment["NOLON_UI_TEST_RESOURCE_REPOSITORY"] = "globalSkills"
        environment["NOLON_UI_TEST_RESOURCE_SEARCH"] = search
        if let selectedTab {
            environment["NOLON_UI_TEST_RESOURCE_TAB"] = selectedTab
        }
        if let skillSlug {
            environment["NOLON_UI_TEST_FIXTURE_GLOBAL_SKILL_SLUG"] = skillSlug
        }
        if let workflowSlug {
            environment["NOLON_UI_TEST_FIXTURE_GLOBAL_WORKFLOW_SLUG"] = workflowSlug
        }
        if let mcpSlug {
            environment["NOLON_UI_TEST_FIXTURE_GLOBAL_MCP_SLUG"] = mcpSlug
        }
        environment["NOLON_UI_TEST_DIRECT_DELETE"] = "1"
        environment["NOLON_UI_TEST_AUTO_CONFIRM_DELETE"] = "1"
        return environment
    }

    private func waitUntil(
        timeout: TimeInterval,
        pollInterval: TimeInterval = 0.1,
        condition: () -> Bool
    ) throws -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(pollInterval))
        }
        return condition()
    }

    private func seedGlobalSkill(slug: String) throws {
        let skillDirectory = tempRoot.appendingPathComponent("skills/\(slug)", isDirectory: true)
        try FileManager.default.createDirectory(at: skillDirectory, withIntermediateDirectories: true)

        let skillMarkdown = """
        ---
        name: Gemini
        description: UI test fixture
        ---

        # Gemini

        UI test fixture
        """
        try skillMarkdown.write(to: skillDirectory.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
    }

    private func seedGlobalWorkflow(slug: String) throws {
        let workflowsDirectory = tempRoot.appendingPathComponent("workflows", isDirectory: true)
        try FileManager.default.createDirectory(at: workflowsDirectory, withIntermediateDirectories: true)
        try "# Daily Sync\n".write(
            to: workflowsDirectory.appendingPathComponent("\(slug).md"),
            atomically: true,
            encoding: .utf8
        )
    }

    private func seedGlobalMCP(slug: String) throws {
        let mcpsDirectory = tempRoot.appendingPathComponent("mcps", isDirectory: true)
        try FileManager.default.createDirectory(at: mcpsDirectory, withIntermediateDirectories: true)
        try "{}".write(
            to: mcpsDirectory.appendingPathComponent("\(slug).json"),
            atomically: true,
            encoding: .utf8
        )
    }

    private func terminateExistingNolonProcesses() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        process.arguments = ["-x", "nolon"]

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw XCTSkip("无法在 UI 测启动前清理残留 nolon 进程：\(error.localizedDescription)")
        }
    }
}
