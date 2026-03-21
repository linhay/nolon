import XCTest
@testable import NolonUIFoundation

final class ResourceCenterSidebarModelsTests: XCTestCase {
    func testDefaultItems_IncludeSkillsWorkflowsMcpsInStableOrder() {
        let items = ResourceCenterTabItem.defaults()

        XCTAssertEqual(items.map(\.id), [.skills, .workflows, .mcps])
        XCTAssertEqual(items[0].iconName, "square.grid.2x2")
        XCTAssertEqual(items[1].iconName, "arrow.triangle.branch")
        XCTAssertEqual(items[2].iconName, "server.rack")
    }
}
