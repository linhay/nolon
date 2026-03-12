import XCTest
import ProviderUsage
import CodexBarProviderCatalog
@testable import nolon

@MainActor
final class AccountCardViewDataMapperTests: XCTestCase {
    func testBDD_GivenCardSwitchesOnCardTap_WhenMappingViewData_ThenDropsRedundantActivateButton() {
        let record = makeRecord()
        let data = AccountCardViewDataMapper.map(
            record: record,
            primaryActions: [
                .init(
                    id: "activate",
                    actionID: .activate,
                    title: "Activate",
                    systemImage: nil,
                    role: nil,
                    prominence: .primary,
                    isEnabled: true
                )
            ],
            tapBehavior: .activate
        )

        XCTAssertTrue(data.primaryActions.isEmpty)
    }

    func testBDD_GivenCardDoesNotSwitchOnCardTap_WhenMappingViewData_ThenKeepsPrimaryActions() {
        let record = makeRecord()
        let refreshAction = AccountCardActionViewData(
            id: "refresh",
            actionID: .refresh,
            title: "Refresh",
            systemImage: nil,
            role: nil,
            prominence: .secondary,
            isEnabled: true
        )

        let data = AccountCardViewDataMapper.map(
            record: record,
            primaryActions: [refreshAction],
            tapBehavior: .none
        )

        XCTAssertEqual(data.primaryActions, [refreshAction])
    }

    private func makeRecord() -> AccountRecord {
        AccountRecord(
            id: .init(provider: .codex, rawValue: "account-1"),
            providerName: "Codex",
            source: .local,
            identity: .init(
                displayName: "is.linhay@outlook.com",
                subtitle: nil,
                meta: nil
            ),
            activationState: .inactive,
            healthState: .healthy,
            bodyFields: [],
            detailFields: [],
            quota: nil,
            accessibilityLabel: "Codex is.linhay@outlook.com"
        )
    }
}
