import XCTest
import ProviderUsage
@testable import nolon

final class UsageMonitorServiceTests: XCTestCase {
    func testDefaultTokenAccountsFileURL_UsesNolonPathLayout() {
        let url = ProviderUsagePaths.defaultTokenAccountsFileURL()
        XCTAssertTrue(url.path.hasSuffix("/Nolon/token-accounts.json"))
    }

    @MainActor
    func testEffectiveCostWindowDays_GivenSelection_WhenResolving_ThenSelectedValueWins() {
        let settings = UsageMonitorProviderSettings(costWindowDays: 30)

        let value = ProviderUsageViewModel.resolveCostWindowDays(selectedCostWindowDays: 7, settings: settings)

        XCTAssertEqual(value, 7)
    }

    @MainActor
    func testEffectiveCostWindowDays_GivenNilSelection_WhenResolving_ThenFallbackToSettings() {
        let settings = UsageMonitorProviderSettings(costWindowDays: 14)

        let value = ProviderUsageViewModel.resolveCostWindowDays(selectedCostWindowDays: nil, settings: settings)

        XCTAssertEqual(value, 14)
    }
}
