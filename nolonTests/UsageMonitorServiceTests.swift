import XCTest
import ProviderUsage
@testable import nolon

final class UsageMonitorServiceTests: XCTestCase {
    func testDefaultTokenAccountsFileURL_UsesNolonPathLayout() {
        let url = ProviderUsagePaths.defaultTokenAccountsFileURL()
        XCTAssertTrue(url.path.hasSuffix("/Nolon/token-accounts.json"))
    }

    func testEffectiveCostWindowDays_GivenSelection_WhenResolving_ThenSelectedValueWins() {
        let settings = UsageMonitorProviderSettings(costWindowDays: 30)

        let value = settings.effectiveCostWindowDays(selected: 7)

        XCTAssertEqual(value, 7)
    }

    func testEffectiveCostWindowDays_GivenNilSelection_WhenResolving_ThenFallbackToSettings() {
        let settings = UsageMonitorProviderSettings(costWindowDays: 14)

        let value = settings.effectiveCostWindowDays(selected: nil)

        XCTAssertEqual(value, 14)
    }
}
