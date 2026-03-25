import SwiftUI

protocol ViewComponentBindable: View {
    associatedtype ComponentViewModel
}

extension AccountSummaryCard: ViewComponentBindable {
    typealias ComponentViewModel = AccountSummaryCardViewModel
}

extension AccountSummaryContentCard: ViewComponentBindable {
    typealias ComponentViewModel = AccountSummaryContentCardViewModel
}

extension AddProviderSheet: ViewComponentBindable {
    typealias ComponentViewModel = AddProviderSheetViewModel
}

extension AddRepositorySheet: ViewComponentBindable {
    typealias ComponentViewModel = AddRepositorySheetViewModel
}

extension AppSettingsView: ViewComponentBindable {
    typealias ComponentViewModel = AppSettingsViewModel
}

extension CodexConfigEditorSheet: ViewComponentBindable {
    typealias ComponentViewModel = CodexConfigEditorSheetViewModel
}

extension CodexConfigEditorView: ViewComponentBindable {
    typealias ComponentViewModel = CodexConfigEditorViewModel
}

extension CodexImportSheet: ViewComponentBindable {
    typealias ComponentViewModel = CodexImportSheetViewModel
}

extension CodexLoginURLSheet: ViewComponentBindable {
    typealias ComponentViewModel = CodexLoginURLSheetViewModel
}

extension ColorSystemPreview: ViewComponentBindable {
    typealias ComponentViewModel = ColorSystemPreviewViewModel
}

extension ContentView: ViewComponentBindable {
    typealias ComponentViewModel = ContentViewModel
}

extension DebugPageMarkerContextMenuItem: ViewComponentBindable {
    typealias ComponentViewModel = DebugPageMarkerContextMenuItemViewModel
}

extension DirectoryPickerSheet: ViewComponentBindable {
    typealias ComponentViewModel = DirectoryPickerSheetViewModel
}

extension EditProviderSheet: ViewComponentBindable {
    typealias ComponentViewModel = EditProviderSheetViewModel
}

extension HighlightedText: ViewComponentBindable {
    typealias ComponentViewModel = HighlightedTextViewModel
}

extension LiquidBackgroundView: ViewComponentBindable {
    typealias ComponentViewModel = LiquidBackgroundViewModel
}

extension McpConfigEditorView: ViewComponentBindable {
    typealias ComponentViewModel = McpConfigEditorViewModel
}

extension McpServerCard: ViewComponentBindable {
    typealias ComponentViewModel = McpServerCardViewModel
}

extension MetadataItem: ViewComponentBindable {
    typealias ComponentViewModel = MetadataItemViewModel
}

extension OnboardingCompletionView: ViewComponentBindable {
    typealias ComponentViewModel = OnboardingCompletionViewModel
}

extension OnboardingProviderSelectionView: ViewComponentBindable {
    typealias ComponentViewModel = OnboardingProviderSelectionViewModel
}

extension OnboardingView: ViewComponentBindable {
    typealias ComponentViewModel = OnboardingViewModel
}

extension OnboardingWelcomeView: ViewComponentBindable {
    typealias ComponentViewModel = OnboardingWelcomeViewModel
}

extension ProviderAgentsGridView: ViewComponentBindable {
    typealias ComponentViewModel = ProviderAgentsGridViewModel
}

extension ProviderCodexBinaryView: ViewComponentBindable {
    typealias ComponentViewModel = ProviderCodexBinaryViewModel
}

extension ProviderLogoView: ViewComponentBindable {
    typealias ComponentViewModel = ProviderLogoViewModel
}

extension ProviderMcpGridView: ViewComponentBindable {
    typealias ComponentViewModel = ProviderMcpGridViewModel
}

extension ProviderQuotaSection: ViewComponentBindable {
    typealias ComponentViewModel = ProviderQuotaSectionViewModel
}

extension ProviderRowView: ViewComponentBindable {
    typealias ComponentViewModel = ProviderRowViewModel
}

extension ProviderRulesGridView: ViewComponentBindable {
    typealias ComponentViewModel = ProviderRulesGridViewModel
}

extension ProviderSkillCard: ViewComponentBindable {
    typealias ComponentViewModel = ProviderSkillCardViewModel
}

extension ProviderSkillRow: ViewComponentBindable {
    typealias ComponentViewModel = ProviderSkillRowViewModel
}

extension ProviderSkillsGridView: ViewComponentBindable {
    typealias ComponentViewModel = ProviderSkillsGridViewModel
}

extension ProviderTokenTrendSection: ViewComponentBindable {
    typealias ComponentViewModel = ProviderTokenTrendSectionViewModel
}

extension ProviderUsageEmptyStateCard: ViewComponentBindable {
    typealias ComponentViewModel = ProviderUsageEmptyStateCardViewModel
}

extension ProviderUsageSnapshotView: ViewComponentBindable {
    typealias ComponentViewModel = ProviderUsageSnapshotViewModel
}

extension ProviderUsageUnifiedAccountCardGrid: ViewComponentBindable {
    typealias ComponentViewModel = ProviderUsageUnifiedAccountCardGridViewModel
}

extension ProviderUsageView: ViewComponentBindable {
    typealias ComponentViewModel = ProviderUsageViewModel
}

extension ProviderWorkflowsGridView: ViewComponentBindable {
    typealias ComponentViewModel = ProviderWorkflowsGridViewModel
}

extension RemoteLocalSkillDetailView: ViewComponentBindable {
    typealias ComponentViewModel = RemoteLocalSkillDetailViewModel
}

extension RemoteMCPCardView: ViewComponentBindable {
    typealias ComponentViewModel = RemoteMCPCardViewModel
}

extension RemoteMCPDetailView: ViewComponentBindable {
    typealias ComponentViewModel = RemoteMCPDetailViewModel
}

extension RemoteSkillCardView: ViewComponentBindable {
    typealias ComponentViewModel = RemoteSkillCardViewModel
}

extension RemoteSkillDetailView: ViewComponentBindable {
    typealias ComponentViewModel = RemoteSkillDetailViewModel
}

extension RemoteWorkflowCardView: ViewComponentBindable {
    typealias ComponentViewModel = RemoteWorkflowCardViewModel
}

extension RemoteWorkflowDetailView: ViewComponentBindable {
    typealias ComponentViewModel = RemoteWorkflowDetailViewModel
}

extension ResourceCenterSidebar: ViewComponentBindable {
    typealias ComponentViewModel = ResourceCenterSidebarViewModel
}

extension ResourceCenterWindowRootView: ViewComponentBindable {
    typealias ComponentViewModel = ResourceCenterWindowRootViewModel
}

extension ResourceDeleteTargetSheet: ViewComponentBindable {
    typealias ComponentViewModel = ResourceDeleteTargetSheetViewModel
}

extension RuleCardView: ViewComponentBindable {
    typealias ComponentViewModel = RuleCardViewModel
}

extension RuleMarkdownEditorView: ViewComponentBindable {
    typealias ComponentViewModel = RuleMarkdownEditorViewModel
}

extension SearchField: ViewComponentBindable {
    typealias ComponentViewModel = SearchFieldViewModel
}

extension SheetDivider: ViewComponentBindable {
    typealias ComponentViewModel = SheetDividerViewModel
}

extension SkillAboutSection: ViewComponentBindable {
    typealias ComponentViewModel = SkillAboutSectionViewModel
}

extension SkillCardView: ViewComponentBindable {
    typealias ComponentViewModel = SkillCardViewModel
}

extension SkillContentToolbar: ViewComponentBindable {
    typealias ComponentViewModel = SkillContentToolbarViewModel
}

extension SkillDetailContentView: ViewComponentBindable {
    typealias ComponentViewModel = SkillDetailContentViewModel
}

extension SkillDetailSidebar: ViewComponentBindable {
    typealias ComponentViewModel = SkillDetailSidebarViewModel
}

extension SkillDetailWindowRootView: ViewComponentBindable {
    typealias ComponentViewModel = SkillDetailWindowRootViewModel
}

extension SkillEmptyStateView: ViewComponentBindable {
    typealias ComponentViewModel = SkillEmptyStateViewModel
}

extension SkillFileContentView: ViewComponentBindable {
    typealias ComponentViewModel = SkillFileContentViewModel
}

extension SkillFileNavigator: ViewComponentBindable {
    typealias ComponentViewModel = SkillFileNavigatorViewModel
}

extension SkillIdentityModule: ViewComponentBindable {
    typealias ComponentViewModel = SkillIdentityModuleViewModel
}

extension SkillInstallSheet: ViewComponentBindable {
    typealias ComponentViewModel = SkillInstallSheetViewModel
}

extension SkillInstallationSection: ViewComponentBindable {
    typealias ComponentViewModel = SkillInstallationSectionViewModel
}

extension SkillInstalledBadge: ViewComponentBindable {
    typealias ComponentViewModel = SkillInstalledBadgeViewModel
}

extension SkillListView: ViewComponentBindable {
    typealias ComponentViewModel = SkillListViewModel
}

extension SkillMetadataBoard: ViewComponentBindable {
    typealias ComponentViewModel = SkillMetadataBoardViewModel
}

extension SkillOrphanedBadge: ViewComponentBindable {
    typealias ComponentViewModel = SkillOrphanedBadgeViewModel
}

extension SkillRow: ViewComponentBindable {
    typealias ComponentViewModel = SkillRowViewModel
}

extension SkillSyncSection: ViewComponentBindable {
    typealias ComponentViewModel = SkillSyncSectionViewModel
}

extension SkillUsageSection: ViewComponentBindable {
    typealias ComponentViewModel = SkillUsageSectionViewModel
}

extension SkillVersionBadge: ViewComponentBindable {
    typealias ComponentViewModel = SkillVersionBadgeViewModel
}

extension ToastView: ViewComponentBindable {
    typealias ComponentViewModel = ToastViewModel
}

extension TokenInputSheet: ViewComponentBindable {
    typealias ComponentViewModel = TokenInputSheetViewModel
}

extension UIResourceCenterCloseButton: ViewComponentBindable {
    typealias ComponentViewModel = UIResourceCenterCloseButtonViewModel
}

extension UISheetHeaderView: ViewComponentBindable {
    typealias ComponentViewModel = UISheetHeaderViewModel
}

extension UnifiedAccountCardSkeleton: ViewComponentBindable {
    typealias ComponentViewModel = UnifiedAccountCardSkeletonViewModel
}

extension UnifiedAccountCard: ViewComponentBindable {
    typealias ComponentViewModel = UnifiedAccountCardViewModel
}

extension UpdateRowView: ViewComponentBindable {
    typealias ComponentViewModel = UpdateRowViewModel
}

extension UsageLoginSheet: ViewComponentBindable {
    typealias ComponentViewModel = UsageLoginSheetViewModel
}

extension WorkflowCardView: ViewComponentBindable {
    typealias ComponentViewModel = WorkflowCardViewModel
}

extension CheckForUpdatesView: ViewComponentBindable {
    typealias ComponentViewModel = CheckForUpdatesViewModel
}

extension UpdatesView: ViewComponentBindable {
    typealias ComponentViewModel = UpdatesViewModel
}

extension MainSplitView: ViewComponentBindable {
    typealias ComponentViewModel = MainSplitViewModel
}

extension CodexQuickSwitchMenuBarView: ViewComponentBindable {
    typealias ComponentViewModel = CodexQuickSwitchMenuBarViewModel
}

extension PluginManagementView: ViewComponentBindable {
    typealias ComponentViewModel = PluginManagementViewModel
}

extension ProviderSidebarView: ViewComponentBindable {
    typealias ComponentViewModel = ProviderSidebarViewModel
}

extension CodexBinaryConfigView: ViewComponentBindable {
    typealias ComponentViewModel = CodexBinaryConfigViewModel
}

extension CodexAdvancedConfigView: ViewComponentBindable {
    typealias ComponentViewModel = CodexAdvancedConfigViewModel
}

extension ProviderContentTabView: ViewComponentBindable {
    typealias ComponentViewModel = ProviderContentTabViewModel
}

extension CodexRuntimeTabView: ViewComponentBindable {
    typealias ComponentViewModel = CodexRuntimeTabViewModel
}

extension ProviderDetailGridView: ViewComponentBindable {
    typealias ComponentViewModel = ProviderDetailGridViewModel
}

extension ProviderSkillsView: ViewComponentBindable {
    typealias ComponentViewModel = ProviderSkillsViewModel
}

extension ResourceCenterView: ViewComponentBindable {
    typealias ComponentViewModel = ResourceCenterViewModel
}

extension ResourceCatalogGridView: ViewComponentBindable {
    typealias ComponentViewModel = ResourceCatalogGridViewModel
}

extension ResourceCenterTabView: ViewComponentBindable {
    typealias ComponentViewModel = ResourceCenterTabViewModel
}

extension RemoteRepositorySidebarView: ViewComponentBindable {
    typealias ComponentViewModel = RemoteRepositorySidebarViewModel
}

extension NolonAccountsView: ViewComponentBindable {
    typealias ComponentViewModel = NolonAccountsViewModel
}

extension SkillDetailContent: ViewComponentBindable {
    typealias ComponentViewModel = SkillDetailContentViewModel
}

extension SkillDetailView: ViewComponentBindable {
    typealias ComponentViewModel = SkillDetailViewModel
}
