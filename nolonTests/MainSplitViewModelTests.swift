import XCTest
@testable import nolon

final class MainSplitViewModelTests: XCTestCase {
    func testResourceCenterOverlayOuterInset_IsForty() {
        XCTAssertEqual(ResourceCenterOverlayLayout.outerInset, 40)
    }
}
