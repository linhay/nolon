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

        let deleteButton = app.buttons.matching(identifier: "uitest.delete-global-skill.gemini").firstMatch
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

    private func launchEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["NOLON_HOME"] = tempRoot.path
        environment["NOLON_UI_TEST_MODE"] = "1"
        environment["NOLON_UI_TEST_SKIP_ONBOARDING"] = "1"
        environment["NOLON_UI_TEST_OPEN_RESOURCE_CENTER"] = "1"
        environment["NOLON_UI_TEST_RESOURCE_REPOSITORY"] = "globalSkills"
        environment["NOLON_UI_TEST_RESOURCE_SEARCH"] = "gemini"
        environment["NOLON_UI_TEST_FIXTURE_GLOBAL_SKILL_SLUG"] = "gemini"
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
