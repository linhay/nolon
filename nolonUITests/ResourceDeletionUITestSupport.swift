import Foundation
import XCTest

struct ResourceDeletionUITestLaunchContext {
    let tempRoot: URL

    func makeLaunchEnvironment(
        search: String,
        selectedTab: String? = nil,
        skillSlug: String? = nil,
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

    func seedFixtureResources() throws {
        try seedGlobalSkill(slug: "gemini")
        try seedGlobalWorkflow(slug: "daily-sync")
        try seedGlobalMCP(slug: "xcode")
    }

    func waitUntil(
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

    static func terminateExistingNolonProcesses() throws {
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
}
