import XCTest
import SwiftUI
import ProviderUsage
import CodexBarProviderCatalog
@testable import nolon

final class ProviderQuotaSectionViewDataTests: XCTestCase {
    func testBDD_GivenExplicitAccountTitle_WhenResolvingHeaderTitle_ThenUsesExplicitTitleInsteadOfUsageEmail() {
        let section = ProviderQuotaSection(
            provider: .codex,
            accountTitle: "key-abcd",
            usage: UsageSnapshot(
                identity: UsageIdentity(
                    accountEmail: "user@example.com",
                    accountOrganization: nil,
                    loginMethod: "api_key",
                    plan: nil
                ),
                primary: nil,
                secondary: nil,
                tertiary: nil,
                updatedAt: Date()
            )
        )

        XCTAssertEqual(section.resolvedAccountTitle, "key-abcd")
    }

    func testBDD_GivenCreditsRefreshTime_WhenResolvingDisplayedTimestamp_ThenPrefersRefreshTime() {
        let refreshedAt = Date(timeIntervalSince1970: 1_710_000_000)
        let credits = CreditsSnapshot(
            remaining: 42,
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let section = ProviderQuotaSection(
            provider: .codex,
            usage: nil,
            credits: credits,
            creditsRefreshedAt: refreshedAt
        )

        XCTAssertEqual(section.displayedCreditsTimestamp(for: credits), refreshedAt)
    }

    func testBDD_GivenSeparateCreditsRefreshTime_WhenBuildingMetadataLines_ThenIncludesRefreshAndSnapshotTimes() {
        let refreshedAt = Date(timeIntervalSince1970: 1_710_000_000)
        let updatedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let credits = CreditsSnapshot(remaining: 42, updatedAt: updatedAt)
        let section = ProviderQuotaSection(
            provider: .codex,
            usage: nil,
            credits: credits,
            creditsRefreshedAt: refreshedAt
        )

        let lines = section.creditsMetadataLines(for: credits)

        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].prefixKey, "usage.metric.refreshed_at")
        XCTAssertEqual(lines[0].date, refreshedAt)
        XCTAssertEqual(lines[1].prefixKey, "usage.metric.updated_at")
        XCTAssertEqual(lines[1].date, updatedAt)
    }
    
    func test_GivenQuotaPercentage_WhenGettingStatusColor_ThenReturnsCorrectSemanticColor() {
        let section = ProviderQuotaSection(provider: .codex, usage: nil)
        
        XCTAssertEqual(section.statusColor(for: 100), DesignSystem.Colors.primary)
        XCTAssertEqual(section.statusColor(for: 24), DesignSystem.Colors.Status.warning)
        XCTAssertEqual(section.statusColor(for: 9), DesignSystem.Colors.Status.error)
        XCTAssertEqual(section.statusColor(for: .infinity), DesignSystem.Colors.Status.success)
    }
    
    func test_GivenPlanName_WhenGettingPlanColor_ThenReturnsCorrectThemeColor() {
        let section = ProviderQuotaSection(provider: .gemini, usage: nil)
        
        XCTAssertEqual(section.planColor("Pro Plan"), DesignSystem.Colors.primary)
        XCTAssertEqual(section.planColor("Enterprise"), DesignSystem.Colors.primary)
        XCTAssertEqual(section.planColor("Free Tier"), DesignSystem.Colors.Status.error)
        XCTAssertEqual(section.planColor("Limited"), DesignSystem.Colors.Status.error)
        XCTAssertEqual(section.planColor("Unknown"), DesignSystem.Colors.Text.secondary)
    }
    
    func test_GivenQuotaTitle_WhenGettingIconName_ThenReturnsCorrectSFSymbol() {
        let section = ProviderQuotaSection(provider: .copilot, usage: nil)
        
        XCTAssertEqual(section.iconName(for: "Session Window"), "timer")
        XCTAssertEqual(section.iconName(for: "Weekly Limit"), "calendar")
        XCTAssertEqual(section.iconName(for: "Daily Usage"), "calendar")
        XCTAssertEqual(section.iconName(for: "Other Metrics"), "chart.bar")
    }
}
