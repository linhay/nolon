import XCTest
@testable import NolonUIFoundation

final class AccountCardPresentationTests: XCTestCase {
    func testCodexPresentation_GivenActiveAccount_PrioritizesActiveStyle() {
        let presentation = AccountCardPresentation.codex(
            isActive: true,
            isPending: true,
            isBatchSelected: true,
            selectableAccountCount: 3
        )

        XCTAssertEqual(presentation.selectionStyle, .active)
        XCTAssertFalse(presentation.showsSelectionBadge)
    }

    func testCodexPresentation_GivenBatchSelectedAndMultiSelectable_ShowsSelectionBadge() {
        let presentation = AccountCardPresentation.codex(
            isActive: false,
            isPending: false,
            isBatchSelected: true,
            selectableAccountCount: 2
        )

        XCTAssertEqual(presentation.selectionStyle, .selected)
        XCTAssertTrue(presentation.showsSelectionBadge)
    }

    func testCodexPresentation_GivenSingleSelectableAccount_HidesSelectionBadge() {
        let presentation = AccountCardPresentation.codex(
            isActive: false,
            isPending: false,
            isBatchSelected: true,
            selectableAccountCount: 1
        )

        XCTAssertEqual(presentation.selectionStyle, .neutral)
        XCTAssertFalse(presentation.showsSelectionBadge)
    }
}
