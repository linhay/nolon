import XCTest
import NolonResourceKit
@testable import nolon

final class ResourceCardMetaBuilderTests: XCTestCase {
    func testSkillMeta_IncludesStarsAndDownloadsOnlyWhenPresent() {
        let skill = RemoteSkill(
            slug: "s",
            displayName: "S",
            summary: nil,
            latestVersion: nil,
            updatedAt: nil,
            downloads: 12,
            stars: 3
        )
        let items = ResourceCardMetaBuilder.skillItems(skill)
        XCTAssertEqual(items, [.stars(3), .downloads(12)])
    }

    func testWorkflowMeta_IncludesUsagesBetweenStarsAndDownloads() {
        let workflow = RemoteWorkflow(
            slug: "w",
            displayName: "W",
            summary: nil,
            latestVersion: nil,
            updatedAt: nil,
            downloads: 9,
            stars: 2,
            usages: 5
        )
        let items = ResourceCardMetaBuilder.workflowItems(workflow)
        XCTAssertEqual(items, [.stars(2), .usages(5), .downloads(9)])
    }

    func testMCPMeta_IncludesCommandWhenNonEmpty() {
        let mcp = RemoteMCP(
            slug: "m",
            displayName: "M",
            summary: nil,
            latestVersion: nil,
            updatedAt: nil,
            downloads: 11,
            stars: 4,
            installs: 7,
            configuration: .init(command: "node", args: nil, env: nil)
        )
        let items = ResourceCardMetaBuilder.mcpItems(mcp)
        XCTAssertEqual(items, [.stars(4), .installs(7), .downloads(11), .command("node")])
    }

    func testMCPMeta_OmitsEmptyCommand() {
        let mcp = RemoteMCP(
            slug: "m2",
            displayName: "M2",
            summary: nil,
            latestVersion: nil,
            updatedAt: nil,
            downloads: nil,
            stars: nil,
            installs: nil,
            configuration: .init(command: "   ", args: nil, env: nil)
        )
        let items = ResourceCardMetaBuilder.mcpItems(mcp)
        XCTAssertTrue(items.isEmpty)
    }
}

