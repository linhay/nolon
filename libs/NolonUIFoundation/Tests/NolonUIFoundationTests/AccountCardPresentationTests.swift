import XCTest
@testable import NolonUIFoundation

final class AccountCardPresentationTests: XCTestCase {
    func testCodexPresentation_GivenActiveAccount_PrioritizesActiveStyle() {
        let presentation = AccountCardPresentation.codex(state: .active)

        XCTAssertEqual(presentation.selectionStyle, .active)
        XCTAssertFalse(presentation.showsSelectionBadge)
    }

    func testCodexPresentation_GivenInactiveAccount_UsesNeutralStyle() {
        let presentation = AccountCardPresentation.codex(state: .inactive)

        XCTAssertEqual(presentation.selectionStyle, .neutral)
        XCTAssertFalse(presentation.showsSelectionBadge)
    }

    func testCodexPresentation_GivenBatchSelectedAndMultiSelectable_ShowsSelectionBadge() {
        let presentation = AccountCardPresentation.codex(state: .selected)

        XCTAssertEqual(presentation.selectionStyle, .selected)
        XCTAssertTrue(presentation.showsSelectionBadge)
    }

    func testCodexPresentation_GivenTransitioningAccount_UsesTransitioningStyle() {
        let presentation = AccountCardPresentation.codex(state: .switching)

        XCTAssertEqual(presentation.selectionStyle, .transitioning)
        XCTAssertFalse(presentation.showsSelectionBadge)
    }
}
