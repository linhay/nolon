import XCTest
import ProviderUsage
@testable import nolon

final class CodexAccountPresentationSupportTests: XCTestCase {
    func testBDD_GivenLiveAuthFailure_WhenBuildingFailurePresentation_ThenReturnsAuthExpiredSummary() {
        let presentation = CodexAccountFailurePresentationBuilder.build(
            liveFailureError: UsageViewModelTestError(message: "401 Unauthorized"),
            persistedFailureMessage: nil,
            canRelogin: true
        )

        XCTAssertTrue(presentation.hasFailure)
        XCTAssertTrue(presentation.isAuthFailure)
        XCTAssertEqual(
            presentation.summary,
            NSLocalizedString(
                "codex.accounts.error.auth_expired",
                value: "Authentication expired. Please sign in again.",
                comment: "Codex auth expired summary"
            )
        )
    }

    func testBDD_GivenCodexSnapshotMenuFactory_WhenResolvingActions_ThenIDsStayStable() {
        let actions = [
            CodexAccountActionFactory.menuCopyAccountIDAction(),
            CodexAccountActionFactory.menuCopyAuthPathAction(),
            CodexAccountActionFactory.menuCopyAuthJSONAction(),
            CodexAccountActionFactory.menuEditAuthJSONAction(),
            CodexAccountActionFactory.menuRefreshAction(isEnabled: true),
            CodexAccountActionFactory.menuReloginAction(isEnabled: true),
            CodexAccountActionFactory.menuActivateAction(),
            CodexAccountActionFactory.menuRevealInFinderAction(),
            CodexAccountActionFactory.menuDeleteAction(),
        ]

        XCTAssertEqual(
            actions.map(\.actionID),
            [.copyAccountID, .copyAuthPath, .copyAuthJSON, .editAuthJSON, .refresh, .relogin, .activate, .revealInFinder, .delete]
        )
    }

    func testBDD_GivenSharedAccountCardActionFactory_WhenResolvingCommonActions_ThenIDsStayStable() {
        let primary = AccountCardActionFactory.primaryActivateAction(title: "Activate")
        let menuActions = [
            AccountCardActionFactory.menuEditAction(title: "Edit"),
            AccountCardActionFactory.menuRefreshAction(isEnabled: true),
            AccountCardActionFactory.menuDeleteAction(),
        ]

        XCTAssertEqual(primary.actionID, .activate)
        XCTAssertEqual(menuActions.map(\.actionID), [.edit, .refresh, .delete])
    }

    func testBDD_GivenLiveFailure_WhenBuildingDisplayErrorText_ThenUsesSharedPresentationSupport() {
        let message = ProviderUsageErrorPresentationSupport.displayText(
            error: UsageViewModelTestError(message: String(repeating: "x", count: 260))
        )

        XCTAssertEqual(message.count, 220)
        XCTAssertTrue(message.hasSuffix("..."))
    }
}
