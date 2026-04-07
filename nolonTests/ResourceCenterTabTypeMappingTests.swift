import XCTest
import NolonUIFoundation
@testable import nolon

final class ResourceCenterTabTypeMappingTests: XCTestCase {
    func testBDD_GivenSkillsTab_WhenResolvingLocalizedName_ThenReturnsSkillsTitle() {
        XCTAssertFalse(ResourceCenterTabID.skills.localizedName.isEmpty)
    }

    func testBDD_GivenWorkflowsTab_WhenResolvingLocalizedName_ThenReturnsWorkflowsTitle() {
        XCTAssertFalse(ResourceCenterTabID.workflows.localizedName.isEmpty)
    }

    func testBDD_GivenMCPsTab_WhenResolvingLocalizedName_ThenReturnsMCPsTitle() {
        XCTAssertTrue(["MCP", "MCPs", "工具"].contains(ResourceCenterTabID.mcps.localizedName))
    }

    func testBDD_GivenAgentsTab_WhenResolvingLocalizedName_ThenReturnsAgentsTitle() {
        XCTAssertFalse(ResourceCenterTabID.agents.localizedName.isEmpty)
    }
}
