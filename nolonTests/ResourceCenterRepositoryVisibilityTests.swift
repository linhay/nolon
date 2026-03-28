import XCTest
import NolonResourceKit
@testable import nolon

final class ResourceCenterRepositoryVisibilityTests: XCTestCase {
    func testBDD_GivenBuiltInGlobalAndClawdhub_WhenResolveVisibleRepositories_ThenGlobalIsHidden() {
        let visible = resourceCenterVisibleRepositories([.globalSkills, .clawdhub])

        XCTAssertEqual(visible.map(\.templateType), [.clawdhub])
    }
}
