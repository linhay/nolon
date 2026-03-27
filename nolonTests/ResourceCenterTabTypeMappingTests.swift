import XCTest
import NolonUIFoundation
@testable import nolon

final class ResourceCenterTabTypeMappingTests: XCTestCase {
    func testBDD_GivenSkillsTab_WhenResolvingLocalizedName_ThenReturnsSkillsTitle() {
        XCTAssertEqual(ResourceCenterTabID.skills.localizedName, "Skills")
    }

    func testBDD_GivenWorkflowsTab_WhenResolvingLocalizedName_ThenReturnsWorkflowsTitle() {
        XCTAssertEqual(ResourceCenterTabID.workflows.localizedName, "Workflows")
    }

    func testBDD_GivenMCPsTab_WhenResolvingLocalizedName_ThenReturnsMCPsTitle() {
        XCTAssertEqual(ResourceCenterTabID.mcps.localizedName, "MCPs")
    }
}
