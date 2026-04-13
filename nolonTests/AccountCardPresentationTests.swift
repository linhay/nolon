import XCTest
import SwiftUI
import NolonUIFoundation
import NolonUI
@testable import nolon

@MainActor
final class AccountCardPresentationTests: XCTestCase {
    func testBDD_GivenCodexActiveAccount_WhenBuildingPresentation_ThenUsesActiveHighlightWithoutSelectionBadge() {
        let presentation = AccountCardPresentation.codex(state: .active)

        XCTAssertEqual(presentation.selectionStyle, .active)
        XCTAssertFalse(presentation.showsSelectionBadge)
    }

    func testBDD_GivenCodexAwaitingConfirmation_WhenBuildingPresentation_ThenRemainsNeutral() {
        let presentation = AccountCardPresentation.codex(state: .inactive)

        XCTAssertEqual(presentation.selectionStyle, .neutral)
        XCTAssertFalse(presentation.showsSelectionBadge)
    }

    func testBDD_GivenCodexTransitioningActivation_WhenBuildingPresentation_ThenUsesTransitioningStyle() {
        let presentation = AccountCardPresentation.codex(state: .switching)

        XCTAssertEqual(presentation.selectionStyle, .transitioning)
        XCTAssertFalse(presentation.showsSelectionBadge)
    }

    func testBDD_GivenCodexMultiSelection_WhenBuildingPresentation_ThenShowsSelectionBadge() {
        let presentation = AccountCardPresentation.codex(state: .selected)

        XCTAssertEqual(presentation.selectionStyle, .selected)
        XCTAssertTrue(presentation.showsSelectionBadge)
    }

    func testBDD_GivenClaudeActiveAccount_WhenBuildingPresentation_ThenUsesActiveStyle() {
        let presentation = AccountCardPresentation.claude(isActive: true)

        XCTAssertEqual(presentation.selectionStyle, .active)
        XCTAssertFalse(presentation.showsSelectionBadge)
    }

    func testBDD_GivenActiveAndBatchSelectedStyles_WhenResolvingCardChrome_ThenVisualTokensAreDifferent() {
        let activeOpacity = AccountSummaryCard<EmptyView>.backgroundOpacity(for: .active)
        let selectedOpacity = AccountSummaryCard<EmptyView>.backgroundOpacity(for: .selected)
        XCTAssertNotEqual(activeOpacity, selectedOpacity)

        let activeLineWidth = AccountSummaryCard<EmptyView>.borderLineWidth(for: .active)
        let selectedLineWidth = AccountSummaryCard<EmptyView>.borderLineWidth(for: .selected)
        XCTAssertNotEqual(activeLineWidth, selectedLineWidth)

        // Note: New design uses solid borders for both Active and Selected states
        // while using dashed borders only for Pending states.
        let activeDash = AccountSummaryCard<EmptyView>.borderDash(for: .active)
        let selectedDash = AccountSummaryCard<EmptyView>.borderDash(for: .selected)
        XCTAssertEqual(activeDash, [])
        XCTAssertEqual(selectedDash, [])

        let transitioningDash = AccountSummaryCard<EmptyView>.borderDash(for: .transitioning)
        XCTAssertEqual(transitioningDash, [])
    }
}
