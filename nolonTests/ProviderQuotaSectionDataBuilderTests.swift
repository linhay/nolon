import XCTest
import ProviderUsage
import CodexBarProviderCatalog
import NolonUIFoundation
@testable import nolon

final class ProviderQuotaSectionDataBuilderTests: XCTestCase {
    func testBDD_GivenLegacyUsageWindows_WhenBuildingQuotaData_ThenUsesProviderLabelsAndPercentRows() {
        let usage = UsageSnapshot(
            identity: UsageIdentity(accountEmail: "dev@example.com", accountOrganization: nil, loginMethod: nil, plan: "pro"),
            windows: [],
            primary: RateWindow(usedPercent: 20),
            secondary: RateWindow(usedPercent: 40),
            tertiary: nil,
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let data = ProviderQuotaSectionDataBuilder.build(
            provider: .codex,
            accountTitle: nil,
            usage: usage,
            credits: CreditsSnapshot(remaining: 42),
            syncText: "Synced just now",
            isLoading: false,
            errorMessage: nil,
            showsEmptyState: false,
            usesCardChrome: true,
            showsHeader: true
        )

        XCTAssertEqual(data.accountTitle, "dev@example.com")
        XCTAssertEqual(data.rows.map(\.title), ["Session", "Weekly"])
        XCTAssertEqual(data.rows.map(\.percentText), ["80%", "60%"])
        XCTAssertEqual(data.creditsText, "42")
        XCTAssertEqual(data.syncText, "Synced just now")
    }

    func testBDD_GivenExplicitAccountTitle_WhenBuildingQuotaData_ThenKeepsExplicitTitle() {
        let usage = UsageSnapshot(
            identity: UsageIdentity(accountEmail: "dev@example.com", accountOrganization: nil, loginMethod: nil, plan: nil),
            primary: RateWindow(usedPercent: 10),
            secondary: nil,
            tertiary: nil,
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let data = ProviderQuotaSectionDataBuilder.build(
            provider: .codex,
            accountTitle: "Team Workspace",
            usage: usage,
            credits: nil,
            syncText: nil,
            isLoading: false,
            errorMessage: nil,
            showsEmptyState: false,
            usesCardChrome: true,
            showsHeader: true
        )

        XCTAssertEqual(data.accountTitle, "Team Workspace")
    }
}
