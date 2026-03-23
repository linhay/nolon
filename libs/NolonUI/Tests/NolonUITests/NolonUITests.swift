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

    func testMainSplitScaffoldMetrics_ExposeExpectedDefaults() {
        XCTAssertEqual(MainSplitScaffoldMetrics.overlayAnimationDuration, 0.18)
        XCTAssertEqual(MainSplitScaffoldMetrics.overlayTransitionScale, 0.98)
    }

    func testSkillDetailScaffoldMetrics_ExposeExpectedDefaults() {
        XCTAssertEqual(SkillDetailScaffoldMetrics.sidebarWidth, 280)
        XCTAssertEqual(SkillDetailScaffoldMetrics.closeButtonSize, 32)
        XCTAssertEqual(SkillDetailScaffoldMetrics.closeButtonPadding, 16)
    }

    func testThreeColumnSidebarWidth_StoresExpectedValues() {
        let width = ThreeColumnSidebarWidth(min: 200, ideal: 220, max: 240)
        XCTAssertEqual(width.min, 200)
        XCTAssertEqual(width.ideal, 220)
        XCTAssertEqual(width.max, 240)
    }

    func testMcpServerCardCacheState_ContainsExpectedStates() {
        let states: Set<McpServerCardCacheState> = [.notMigrated, .migratedUpToDate, .migratedNeedsUpdate]
        XCTAssertEqual(states.count, 3)
    }

    func testMcpServerMaintenanceAction_ResolvesFromCacheState() {
        XCTAssertEqual(McpServerCardView<EmptyView, EmptyView>.resolveMaintenanceAction(for: .notMigrated), .migrate)
        XCTAssertEqual(McpServerCardView<EmptyView, EmptyView>.resolveMaintenanceAction(for: .migratedNeedsUpdate), .update)
        XCTAssertEqual(McpServerCardView<EmptyView, EmptyView>.resolveMaintenanceAction(for: .migratedUpToDate), .none)
    }

    func testMcpServerCommandAvailability_ResolvesFromCommandText() {
        XCTAssertFalse(McpServerCardView<EmptyView, EmptyView>.isMissingCommand("npx -y @modelcontextprotocol/server-filesystem"))
        XCTAssertTrue(McpServerCardView<EmptyView, EmptyView>.isMissingCommand("  "))
        XCTAssertTrue(McpServerCardView<EmptyView, EmptyView>.isMissingCommand(nil))
    }

    func testMcpServerPrimaryAction_ResolvesWithHierarchy() {
        XCTAssertEqual(
            McpServerCardView<EmptyView, EmptyView>.resolvePrimaryAction(cacheState: .notMigrated, hasWorkflow: true),
            .migrate
        )
        XCTAssertEqual(
            McpServerCardView<EmptyView, EmptyView>.resolvePrimaryAction(cacheState: .migratedNeedsUpdate, hasWorkflow: false),
            .update
        )
        XCTAssertEqual(
            McpServerCardView<EmptyView, EmptyView>.resolvePrimaryAction(cacheState: .migratedUpToDate, hasWorkflow: false),
            .linkWorkflow
        )
        XCTAssertEqual(
            McpServerCardView<EmptyView, EmptyView>.resolvePrimaryAction(cacheState: .migratedUpToDate, hasWorkflow: true),
            .none
        )
    }

    func testResourceCardMetaItem_CommandPayload_RetainsValue() {
        let item = ResourceCardMetaItem.command("npx -y @modelcontextprotocol/server-git")

        XCTAssertEqual(item, .command("npx -y @modelcontextprotocol/server-git"))
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

    func testProviderContentTabSidebarHeaderTitle_GivenProviderSelected_HidesTitle() {
        let title = ProviderContentTabSidebarComponent<String>.resolveHeaderTitle(
            hasProviderSelection: true,
            emptyTitle: "Select a Provider"
        )

        XCTAssertEqual(title, "")
    }

    func testProviderContentTabSidebarHeaderTitle_GivenNoProvider_UsesEmptyTitle() {
        let title = ProviderContentTabSidebarComponent<String>.resolveHeaderTitle(
            hasProviderSelection: false,
            emptyTitle: "Select a Provider"
        )

        XCTAssertEqual(title, "Select a Provider")
    }

    func testHighlightedTextMatchRanges_GivenSubsequence_ReturnsOrderedMatches() {
        let ranges = HighlightedTextMatcher.matchRanges(text: "Provider", query: "pvr")

        XCTAssertEqual(ranges.count, 3)
        XCTAssertEqual(ranges.map { $0.lowerBound.utf16Offset(in: "Provider") }, [0, 3, 7])
    }

    func testHighlightedTextMatchRanges_GivenBrokenSequence_StopsAtFirstBreak() {
        let ranges = HighlightedTextMatcher.matchRanges(text: "Agent", query: "azt")

        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(ranges.map { $0.lowerBound.utf16Offset(in: "Agent") }, [0])
    }

    func testResourceInstallStateResolve_GivenInstalledAndInstalling_PrioritizesInstalled() {
        let state = ResourceInstallState.resolve(
            isInstalled: true,
            isInstalling: true,
            errorMessage: "boom"
        )

        XCTAssertEqual(state, .installed)
    }

    func testResourceInstallStateResolve_GivenError_UsesErrorState() {
        let state = ResourceInstallState.resolve(
            isInstalled: false,
            isInstalling: false,
            errorMessage: "network failed"
        )

        XCTAssertEqual(state, .failed(message: "network failed"))
    }

    func testWorkflowSourceLocalizationKeys_AreStable() {
        XCTAssertEqual(WorkflowSource.skill.localizedKey, "workflow.source.skill")
        XCTAssertEqual(WorkflowSource.user.localizedKey, "workflow.source.user")
        XCTAssertEqual(WorkflowSource.mcp.localizedKey, "workflow.source.mcp")
        XCTAssertEqual(WorkflowSource.unknown.localizedKey, "workflow.source.unknown")
    }
}
