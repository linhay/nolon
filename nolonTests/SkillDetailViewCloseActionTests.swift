import XCTest
@testable import nolon

final class SkillDetailViewCloseActionTests: XCTestCase {
    func testBDD_GivenCustomCloseAction_WhenHandlingClose_ThenUsesCustomActionInsteadOfDismiss() {
        var customCloseCount = 0
        var dismissCount = 0

        SkillDetailView.handleClose(
            onClose: {
                customCloseCount += 1
            },
            dismiss: {
                dismissCount += 1
            }
        )

        XCTAssertEqual(customCloseCount, 1)
        XCTAssertEqual(dismissCount, 0)
    }

    func testBDD_GivenNoCustomCloseAction_WhenHandlingClose_ThenFallsBackToDismiss() {
        var dismissCount = 0

        SkillDetailView.handleClose(
            onClose: nil,
            dismiss: {
                dismissCount += 1
            }
        )

        XCTAssertEqual(dismissCount, 1)
    }
}
