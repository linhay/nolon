import XCTest
import NolonResourceKit
@testable import nolon

final class GitRepositoryResourceDetectionTests: XCTestCase {
    func testDetectRepositoryResources_FindsSkillsWorkflowsAndMCP() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("git-repo-resources-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let skillFile = root.appendingPathComponent("skills/agent-browser/SKILL.md")
        let workflowFile = root.appendingPathComponent("workflows/review.md")
        let mcpFile = root.appendingPathComponent("configs/mcp_settings.json")

        try FileManager.default.createDirectory(at: skillFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: workflowFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: mcpFile.deletingLastPathComponent(), withIntermediateDirectories: true)

        try Data("---\nname: agent-browser\ndescription: Browser\n---\n".utf8).write(to: skillFile)
        try Data("# Review Workflow\n".utf8).write(to: workflowFile)
        try Data("{\"mcpServers\":{}}".utf8).write(to: mcpFile)

        let resources = GitRepository.detectRepositoryResources(at: root)

        XCTAssertTrue(resources.skillsDirectories.contains { $0.path == "skills" && $0.skillCount == 1 })
        XCTAssertTrue(resources.workflowPaths.contains("workflows/review.md"))
        XCTAssertTrue(resources.mcpPaths.contains("configs/mcp_settings.json"))
    }

    func testSyncResultSuccess_CarriesResourcePaths() {
        let result = GitRepository.SyncResult.success(
            isNewClone: true,
            detectedDirectories: [],
            workflowPaths: ["workflows/review.md"],
            mcpPaths: ["configs/mcp_settings.json"]
        )

        XCTAssertTrue(result.success)
        XCTAssertTrue(result.isNewClone)
        XCTAssertEqual(result.workflowPaths, ["workflows/review.md"])
        XCTAssertEqual(result.mcpPaths, ["configs/mcp_settings.json"])
    }
}
