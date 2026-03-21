import XCTest
import SwiftUI
@testable import NolonUI
import NolonUIFoundation

final class NolonUITests: XCTestCase {
    func testDefaultTools_ContainsAccountsAndPluginManagement() {
        let ids = SidebarToolItem.default.map(\.id)
        XCTAssertEqual(ids, [.accounts, .pluginManagement])
    }

    func testDefaultStyle_CanBeConstructed() {
        _ = ProviderSidebarStyle.default
    }

    func testDesignSystemMetrics_ExposeBaselineValues() {
        XCTAssertEqual(DesignSystem.Metrics.cornerRadiusM, 12)
        XCTAssertEqual(DesignSystem.Metrics.spacingM, 12)
    }

    func testDesignSystemCoreTokens_Accessible() {
        _ = DesignSystem.Colors.primary
        _ = DesignSystem.Typography.button
        _ = DesignSystem.Animations.quick
    }

    func testSidebarProviderRowMetrics_GivenSmallSize_HidesSubtitleAndUsesCompactIcon() {
        let metrics = SidebarProviderRowMetrics(sidebarRowSize: .small)

        XCTAssertFalse(metrics.showsSubtitle)
        XCTAssertEqual(metrics.iconFrameSize, 14)
        XCTAssertEqual(metrics.verticalPadding, 1)
    }

    func testSidebarProviderRowMetrics_GivenLargeSize_UsesLargerIconAndPadding() {
        let medium = SidebarProviderRowMetrics(sidebarRowSize: .medium)
        let large = SidebarProviderRowMetrics(sidebarRowSize: .large)

        XCTAssertTrue(large.showsSubtitle)
        XCTAssertGreaterThan(large.iconFrameSize, medium.iconFrameSize)
        XCTAssertGreaterThan(large.verticalPadding, medium.verticalPadding)
    }

    @MainActor
    func testAccountSummaryCardSelectionMetrics_ExposeExpectedValues() {
        XCTAssertEqual(AccountSummaryCard<EmptyView>.backgroundOpacity(for: AccountCardSelectionStyle.neutral), 0)
        XCTAssertEqual(AccountSummaryCard<EmptyView>.backgroundOpacity(for: AccountCardSelectionStyle.active), 0.08)
        XCTAssertEqual(AccountSummaryCard<EmptyView>.borderLineWidth(for: AccountCardSelectionStyle.selected), 1.5)
        XCTAssertEqual(AccountSummaryCard<EmptyView>.borderDash(for: AccountCardSelectionStyle.pending), [5, 4])
    }

    func testResourceCenterCloseButtonMetrics_ExposeExpectedBaseline() {
        XCTAssertEqual(ResourceCenterCloseButtonMetrics.iconSystemName, "xmark")
        XCTAssertEqual(ResourceCenterCloseButtonMetrics.iconFontSize, 13)
        XCTAssertEqual(ResourceCenterCloseButtonMetrics.buttonFrameSize, 32)
    }

    func testResourceCenterSidebarMetrics_ExposeExpectedHeaderLayout() {
        XCTAssertEqual(ResourceCenterSidebarMetrics.headerHeight, 52)
        XCTAssertEqual(ResourceCenterSidebarMetrics.headerHorizontalPadding, 16)
    }

    func testProviderContentTabSidebarMetrics_ExposeExpectedColumnWidth() {
        XCTAssertEqual(ProviderContentTabSidebarMetrics.headerHeight, 52)
        XCTAssertEqual(ProviderContentTabSidebarMetrics.headerHorizontalPadding, 16)
        XCTAssertEqual(ProviderContentTabSidebarMetrics.columnMinWidth, 160)
        XCTAssertEqual(ProviderContentTabSidebarMetrics.columnIdealWidth, 180)
        XCTAssertEqual(ProviderContentTabSidebarMetrics.columnMaxWidth, 200)
    }

    func testSidebarMetrics_AreAlignedBetweenResourceAndProvider() {
        XCTAssertEqual(ProviderContentTabSidebarMetrics.headerHeight, ResourceCenterSidebarMetrics.headerHeight)
        XCTAssertEqual(ProviderContentTabSidebarMetrics.headerHorizontalPadding, ResourceCenterSidebarMetrics.headerHorizontalPadding)
        XCTAssertEqual(ProviderContentTabSidebarMetrics.columnMinWidth, ResourceCenterSidebarMetrics.columnMinWidth)
        XCTAssertEqual(ProviderContentTabSidebarMetrics.columnIdealWidth, ResourceCenterSidebarMetrics.columnIdealWidth)
        XCTAssertEqual(ProviderContentTabSidebarMetrics.columnMaxWidth, ResourceCenterSidebarMetrics.columnMaxWidth)
    }

    func testProviderContentTabSidebarItem_RetainsAccessoryAndCount() {
        let item = ProviderContentTabSidebarItem(
            id: "advanced",
            title: "Advanced",
            iconName: "slider.horizontal.3",
            countText: nil,
            trailingSymbolName: "arrow.up.right.square",
            trailingHelpText: "View Official Documentation"
        )

        XCTAssertEqual(item.id, "advanced")
        XCTAssertNil(item.countText)
        XCTAssertEqual(item.trailingSymbolName, "arrow.up.right.square")
        XCTAssertEqual(item.trailingHelpText, "View Official Documentation")
    }
}
