import XCTest
import SwiftUI
import ProviderCatalog
import CodexBarProviderCatalog
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
            ResourceContentTabType.mcps.localizedName
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
}
