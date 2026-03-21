import XCTest
import NolonUIFoundation
@testable import nolon

final class ResourceCenterTabTypeMappingTests: XCTestCase {
    func testBDD_GivenResourceContentTabType_WhenMappingToFoundationID_ThenKeepsOneToOneMapping() {
        XCTAssertEqual(ResourceContentTabType.skills.foundationID, .skills)
        XCTAssertEqual(ResourceContentTabType.workflows.foundationID, .workflows)
        XCTAssertEqual(ResourceContentTabType.mcps.foundationID, .mcps)
    }

    func testBDD_GivenFoundationTabID_WhenMappingBackToResourceContentTabType_ThenKeepsOneToOneMapping() {
        XCTAssertEqual(ResourceContentTabType.fromFoundationID(.skills), .skills)
        XCTAssertEqual(ResourceContentTabType.fromFoundationID(.workflows), .workflows)
        XCTAssertEqual(ResourceContentTabType.fromFoundationID(.mcps), .mcps)
    }
}
