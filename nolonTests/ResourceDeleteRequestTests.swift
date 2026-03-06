import XCTest
import NolonResourceKit
@testable import nolon

final class ResourceDeleteRequestTests: XCTestCase {
    func testBDD_GivenRemoteSkill_WhenBuildDeleteRequest_ThenOnlyStableDeleteFieldsAreKept() {
        let skill = RemoteSkill(
            slug: "gemini",
            displayName: "Gemini CLI",
            summary: "summary",
            latestVersion: "1.0.0",
            updatedAt: Date(timeIntervalSince1970: 0),
            downloads: 1,
            stars: 2
        )

        let request = ResourceDeleteRequest(skill: skill)

        XCTAssertEqual(request.id, "skill-gemini")
        XCTAssertEqual(request.resourceSlug, "gemini")
        XCTAssertEqual(request.displayName, "Gemini CLI")
        XCTAssertEqual(request.resourceType, .skill)
        XCTAssertNil(request.localPath)
        XCTAssertNil(request.defaultTarget)
    }

    func testBDD_GivenRemoteWorkflow_WhenBuildDeleteRequest_ThenResourceTypeIsWorkflow() {
        let workflow = RemoteWorkflow(
            slug: "daily-sync",
            displayName: "Daily Sync",
            summary: nil,
            latestVersion: "1.0.0",
            updatedAt: Date(timeIntervalSince1970: 0),
            downloads: 1,
            stars: 2
        )

        let request = ResourceDeleteRequest(workflow: workflow)

        XCTAssertEqual(request.id, "workflow-daily-sync")
        XCTAssertEqual(request.resourceSlug, "daily-sync")
        XCTAssertEqual(request.displayName, "Daily Sync")
        XCTAssertEqual(request.resourceType, .workflow)
        XCTAssertNil(request.localPath)
        XCTAssertNil(request.defaultTarget)
    }

    func testBDD_GivenRemoteMCP_WhenBuildDeleteRequest_ThenResourceTypeIsMCP() {
        let mcp = RemoteMCP(
            slug: "xcode",
            displayName: "Xcode MCP",
            summary: nil,
            latestVersion: "1.0.0",
            updatedAt: Date(timeIntervalSince1970: 0),
            downloads: 1,
            stars: 2
        )

        let request = ResourceDeleteRequest(mcp: mcp)

        XCTAssertEqual(request.id, "mcp-xcode")
        XCTAssertEqual(request.resourceSlug, "xcode")
        XCTAssertEqual(request.displayName, "Xcode MCP")
        XCTAssertEqual(request.resourceType, .mcp)
        XCTAssertNil(request.localPath)
        XCTAssertNil(request.defaultTarget)
    }

    func testBDD_GivenGlobalSkillDelete_WhenBuildDeleteRequest_ThenKeepLocalPathAndDirectDeleteTarget() {
        let skill = RemoteSkill(
            slug: "gemini",
            displayName: "Gemini CLI",
            summary: "summary",
            latestVersion: "1.0.0",
            updatedAt: Date(timeIntervalSince1970: 0),
            downloads: 1,
            stars: 2,
            localPath: "/tmp/.nolon/skills/gemini"
        )

        let request = ResourceDeleteRequest(skill: skill, defaultTarget: .allProvidersAndGlobalCache)

        XCTAssertEqual(request.localPath, "/tmp/.nolon/skills/gemini")
        XCTAssertEqual(request.defaultTarget, .allProvidersAndGlobalCache)
    }
}
