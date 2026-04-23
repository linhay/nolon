import XCTest
import SwiftUI
import ProviderCatalog
import ProviderUsage
import CodexBarProviderCatalog
import NolonResourceKit
import NolonUIFoundation
@testable import nolon

@MainActor
final class PageMarkerRouteResolverTests: XCTestCase {
    private struct FakePage: DebugPageLocatable {
        var debugPageMarkerItems: [PageMarkerItem] {
            [
                PageMarkerItem(title: "Fake"),
                PageMarkerItem(title: "Details")
            ]
        }

        var body: some View { EmptyView() }
    }

    private struct FakeCard: DebugCardLocatable {
        var debugCardMarkerItems: [PageMarkerItem] {
            [
                PageMarkerItem(title: "Card"),
                PageMarkerItem(title: "Token")
            ]
        }

        var body: some View { EmptyView() }
    }

    func testBDD_GivenDebugBuild_WhenResolvingMarkerVisibility_ThenPageMarkersAreEnabled() {
        XCTAssertTrue(PageMarkerRouteResolver.isEnabledInCurrentBuild)
    }

    func testBDD_GivenCallsiteSource_WhenBuildingMetadataItem_ThenContainsFileLineAndFunction() {
        let source = PageMarkerRouteResolver.source(
            fileID: "/tmp/FakePage.swift",
            line: 42,
            function: "body"
        )

        XCTAssertEqual(
            PageMarkerRouteResolver.metadataText(source: source),
            "#FakePage.swift #42 #body"
        )
    }

    func testBDD_GivenAccountsPage_WhenResolvingItems_ThenReturnsAccountsLabel() {
        let items = PageMarkerRouteResolver.accountsItems()

        XCTAssertEqual(items.map(\.title), [
            NSLocalizedString("sidebar.tools.accounts", value: "Accounts", comment: "Accounts sidebar item")
        ])
    }

    func testBDD_GivenProviderUsagePage_WhenResolvingItems_ThenReturnsProviderAndSubpageLabels() {
        let provider = Provider(
            id: "codex",
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: "/tmp/codex/skills",
            workflowPath: "/tmp/codex/workflows",
            vendorCategory: .original,
            templateId: ProviderTemplate.codex.rawValue
        )

        let items = PageMarkerRouteResolver.providerDetailItems(
            provider: provider,
            selectedTab: .usage
        )

        XCTAssertEqual(items.map(\.title), [
            provider.displayName,
            ProviderContentTabType.usage.localizedName(for: provider)
        ])
    }

    func testBDD_GivenProviderNavigationWithoutTab_WhenResolvingItems_ThenReturnsProviderOnly() {
        let provider = Provider(
            id: "claude",
            kind: .vendor,
            name: "Claude",
            defaultSkillsPath: "/tmp/claude/skills",
            workflowPath: "/tmp/claude/workflows",
            vendorCategory: .original,
            templateId: ProviderTemplate.claudeCode.rawValue
        )

        let items = PageMarkerRouteResolver.providerNavigationItems(provider: provider)

        XCTAssertEqual(items.map(\.title), [provider.displayName])
    }

    func testBDD_GivenResourceCenterMCPTab_WhenResolvingItems_ThenReturnsMainAndSubpageLabels() {
        let items = PageMarkerRouteResolver.resourceCenterItems(selectedTab: .mcps)

        XCTAssertEqual(items.map(\.title), [
            NSLocalizedString("resource.center.title", value: "Resource Center", comment: "Resource center title"),
            ResourceCenterTabID.mcps.localizedName
        ])
    }

    func testBDD_GivenPluginManagementPage_WhenResolvingItems_ThenReturnsOnlyPluginManagementLabel() {
        let items = PageMarkerRouteResolver.pluginManagementItems()

        XCTAssertEqual(items.map(\.title), [
            NSLocalizedString("sidebar.plugins.management", value: "Plugin Management", comment: "Plugin management sidebar item")
        ])
    }

    func testBDD_GivenMultipleMarkerItems_WhenBuildingLocatorText_ThenJoinsWithSlashSeparator() {
        let provider = Provider(
            id: "codex",
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: "/tmp/codex/skills",
            workflowPath: "/tmp/codex/workflows",
            vendorCategory: .original,
            templateId: ProviderTemplate.codex.rawValue
        )
        let items = PageMarkerRouteResolver.providerDetailItems(provider: provider, selectedTab: .usage)
        let source = PageMarkerRouteResolver.source(
            fileID: "/tmp/ProviderDetailGridView.swift",
            line: 125,
            function: "body"
        )

        let text = PageMarkerRouteResolver.locatorText(for: items, source: source)

        XCTAssertEqual(
            text,
            "Codex / \(ProviderContentTabType.usage.localizedName(for: provider)) / #ProviderDetailGridView.swift #125 #body"
        )
    }

    func testBDD_GivenMarkerItemsIncludingMetadata_WhenBuildingLocatorText_ThenKeepsMetadataAtTail() {
        let items = [
            PageMarkerItem(title: "Accounts")
        ]
        let source = PageMarkerRouteResolver.source(
            fileID: "/tmp/NolonAccountsView.swift",
            line: 245,
            function: "body"
        )

        XCTAssertEqual(
            PageMarkerRouteResolver.locatorText(for: items, source: source),
            "Accounts / #NolonAccountsView.swift #245 #body"
        )
    }

    func testBDD_GivenDebugPageLocatableType_WhenBuildingLocatorText_ThenUsesSharedResolverOutput() {
        let page = FakePage()

        XCTAssertEqual(
            page.debugPageLocatorText(
                fileID: "/tmp/FakePage.swift",
                line: 18,
                function: "body"
            ),
            "Fake / Details / #FakePage.swift #18 #body"
        )
    }

    func testBDD_GivenDebugCardLocatableType_WhenBuildingLocatorText_ThenUsesSharedResolverOutput() {
        let card = FakeCard()

        XCTAssertEqual(
            card.debugCardLocatorText(
                fileID: "/tmp/FakeCard.swift",
                line: 27,
                function: "body"
            ),
            "Card / Token / #FakeCard.swift #27 #body"
        )
    }

    func testBDD_GivenProviderTokenTrendSection_WhenBuildingLocatorText_ThenIncludesTokenTrendPath() {
        let provider = Provider(
            id: "codex",
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: "/tmp/codex/skills",
            workflowPath: "/tmp/codex/workflows",
            vendorCategory: .original,
            templateId: ProviderTemplate.codex.rawValue
        )
        let section = ProviderTokenTrendSection(
            snapshot: nil,
            refreshStatus: nil,
            capability: .dailyWithIntradayDrilldown,
            selectedDayKey: nil,
            intradayBucket: .minute30,
            availableIntradayBuckets: [.minute15, .minute30, .hour1],
            intradaySnapshot: nil,
            intradayErrorMessage: nil,
            isLoadingIntraday: false,
            isLoading: false,
            errorMessage: nil,
            range: .days30,
            metricMode: .tokens,
            chartStyle: .bar,
            activeTab: .daily,
            onRangeChange: { _ in },
            onSelectDay: { _ in },
            onIntradayBucketChange: { _ in },
            onMetricModeChange: { _ in },
            onChartStyleChange: { _ in },
            onContentTabChange: { _ in },
            onRefresh: {},
            onRefreshIntraday: {},
            debugPageMarkerItems: [
                PageMarkerItem(title: provider.displayName),
                PageMarkerItem(title: ProviderContentTabType.usage.localizedName(for: provider)),
                PageMarkerItem(
                    title: NSLocalizedString(
                        "usage.token_trend.title",
                        value: "历史 Token 消耗",
                        comment: "Token trend section title"
                    )
                )
            ]
        )

        XCTAssertEqual(
            section.debugPageLocatorText(
                fileID: "/tmp/ProviderTokenTrendSection.swift",
                line: 36,
                function: "body"
            ),
            "Codex / \(ProviderContentTabType.usage.localizedName(for: provider)) / 历史 Token 消耗 / #ProviderTokenTrendSection.swift #36 #body"
        )
    }

    func testBDD_GivenProviderTokenTrendChildBlock_WhenBuildingMarkerItems_ThenAppendsChildTitleToSectionPath() {
        let baseItems = [
            PageMarkerItem(title: "Codex"),
            PageMarkerItem(title: "账号与用量"),
            PageMarkerItem(title: "历史 Token 消耗")
        ]
        let childItems = baseItems + [PageMarkerItem(title: "Daily Breakdown")]

        XCTAssertEqual(
            childItems.map(\.title),
            ["Codex", "账号与用量", "历史 Token 消耗", "Daily Breakdown"]
        )
    }

    func testBDD_GivenCopiedPageMarkerText_WhenShowingToast_ThenToastDisplaysCopiedText() {
        let center = DebugMarkerToastCenter.shared

        center.showCopiedPageMarkerToast("Codex / 账号与用量 / 历史 Token 消耗")

        XCTAssertTrue(center.isVisible)
        XCTAssertEqual(center.message, "Codex / 账号与用量 / 历史 Token 消耗")
    }

    func testBDD_GivenGitRepositorySidebarRow_WhenBuildingMarkerItems_ThenUsesResolvedDisplayName() {
        let repo = RemoteRepository(
            id: "repo-1",
            name: "OpenAI Codex",
            baseURL: "https://github.com/openai/codex",
            iconName: "shippingbox",
            logoName: nil,
            templateType: .git,
            isBuiltIn: false,
            localPath: nil,
            gitURL: "https://github.com/openai/codex.git",
            provider: .github
        )

        XCTAssertEqual(
            remoteRepositorySidebarMarkerItems(selectedRepository: repo).map(\.title),
            ["Repository Sidebar", "codex"]
        )
    }
}
