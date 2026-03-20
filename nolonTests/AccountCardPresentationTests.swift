import XCTest
import SwiftUI
@testable import nolon

@MainActor
final class AccountCardPresentationTests: XCTestCase {
    func testBDD_GivenCodexActiveAccount_WhenBuildingPresentation_ThenUsesActiveHighlightWithoutSelectionBadge() {
        let presentation = AccountCardPresentation.codex(
            isActive: true,
            isPending: false,
            isBatchSelected: false,
            selectableAccountCount: 1
        )

        XCTAssertEqual(presentation.selectionStyle, .active)
        XCTAssertFalse(presentation.showsSelectionBadge)
    }

    func testBDD_GivenCodexPendingActivation_WhenBuildingPresentation_ThenUsesPendingBorder() {
        let presentation = AccountCardPresentation.codex(
            isActive: false,
            isPending: true,
            isBatchSelected: false,
            selectableAccountCount: 1
        )

        XCTAssertEqual(presentation.selectionStyle, .pending)
        XCTAssertFalse(presentation.showsSelectionBadge)
    }

    func testBDD_GivenCodexMultiSelection_WhenBuildingPresentation_ThenShowsSelectionBadge() {
        let presentation = AccountCardPresentation.codex(
            isActive: false,
            isPending: false,
            isBatchSelected: true,
            selectableAccountCount: 2
        )

        XCTAssertEqual(presentation.selectionStyle, .selected)
        XCTAssertTrue(presentation.showsSelectionBadge)
    }

    func testBDD_GivenSingleCodexAccount_WhenBuildingPresentation_ThenIgnoresBatchSelectionState() {
        let presentation = AccountCardPresentation.codex(
            isActive: false,
            isPending: false,
            isBatchSelected: true,
            selectableAccountCount: 1
        )

        XCTAssertEqual(presentation.selectionStyle, .neutral)
        XCTAssertFalse(presentation.showsSelectionBadge)
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
        
        let pendingDash = AccountSummaryCard<EmptyView>.borderDash(for: .pending)
        XCTAssertFalse(pendingDash.isEmpty)
    }
}
