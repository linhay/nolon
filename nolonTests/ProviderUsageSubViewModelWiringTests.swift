import Testing
import Foundation
import ProviderCatalog
import ProviderUsage
@testable import nolon

@MainActor
struct ProviderUsageSubViewModelWiringTests {
    @Test("BDD: Given root usage view model when creating domain view models then all share the same provider state")
    func testBDD_GivenRootUsageViewModel_WhenCreatingDomainViewModels_ThenAllShareTheSameProviderState() {
        let provider = Provider(
            id: "codex",
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: "/tmp/codex/skills",
            workflowPath: "/tmp/codex/prompts",
            vendorCategory: .original,
            templateId: ProviderTemplate.codex.rawValue
        )

        let root = ProviderUsageRootViewModel(provider: provider)

        #expect(root.accountsViewModel.usageProvider == root.usageProvider)
        #expect(root.accountsViewModel.codex.accounts == root.state.codexEngine.codexAccounts)
        #expect(root.tokenTrendViewModel.tokenTrendRange == root.state.commonEngine.tokenTrendRange)
        #expect(root.gatewayCardsViewModel.gatewayCardsState == root.state.codexEngine.gatewayCardsState)
        #expect(root.importExportViewModel.isShowingCodexImportSheet == root.state.codexEngine.isShowingCodexImportSheet)
        #expect(root.loginFlowViewModel.isRunningCLILogin == root.state.commonEngine.isRunningCLILogin)
    }

    @Test("BDD: Given generic provider when toggling account layout mode then shared layout state updates")
    func testBDD_GivenGenericProvider_WhenTogglingAccountLayoutMode_ThenSharedStateUpdates() {
        let provider = Provider(
            id: "gemini",
            kind: .vendor,
            name: "Gemini",
            defaultSkillsPath: "/tmp/gemini/skills",
            workflowPath: "/tmp/gemini/prompts",
            vendorCategory: .original,
            templateId: ProviderTemplate.gemini.rawValue
        )

        let root = ProviderUsageRootViewModel(provider: provider)
        root.accountsViewModel.setAccountLayoutMode(.cards)
        #expect(root.accountsViewModel.accountLayoutMode == .cards)

        root.accountsViewModel.setAccountLayoutMode(.list)
        #expect(root.accountsViewModel.accountLayoutMode == .list)
        #expect(root.state.commonEngine.settings.codexUseListLayout == true)
    }

    @Test("BDD: Given codex provider when changing grouping option then shared settings persist grouping raw value")
    func testBDD_GivenCodexProvider_WhenChangingGroupingOption_ThenSharedSettingsPersistGroupingRawValue() {
        let provider = Provider(
            id: "codex",
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: "/tmp/codex/skills",
            workflowPath: "/tmp/codex/prompts",
            vendorCategory: .original,
            templateId: ProviderTemplate.codex.rawValue
        )

        let root = ProviderUsageRootViewModel(provider: provider)
        root.accountsViewModel.codex.accountGroupingOption = .customSQLiteGroup

        #expect(root.accountsViewModel.codex.accountGroupingOption == .customSQLiteGroup)
        #expect(root.state.commonEngine.settings.codexAccountGroupingOptionRawValue == "customSQLiteGroup")
    }

    @Test("BDD: Given codex provider when reopening usage root then grouping option is restored from persisted settings")
    func testBDD_GivenCodexProvider_WhenReopeningUsageRoot_ThenGroupingOptionRestoresFromPersistedSettings() {
        let provider = Provider(
            id: "codex-\(UUID().uuidString)",
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: "/tmp/codex/skills",
            workflowPath: "/tmp/codex/prompts",
            vendorCategory: .original,
            templateId: ProviderTemplate.codex.rawValue
        )

        let store = UsageMonitorSettingsStore.shared
        store.update(settings: .init(codexAccountGroupingOptionRawValue: "typeInfo"), for: provider)

        let firstRoot = ProviderUsageRootViewModel(provider: provider)
        firstRoot.accountsViewModel.codex.accountGroupingOption = .customSQLiteGroup
        #expect(firstRoot.state.commonEngine.settings.codexAccountGroupingOptionRawValue == "customSQLiteGroup")

        let reopenedRoot = ProviderUsageRootViewModel(provider: provider)
        #expect(reopenedRoot.accountsViewModel.codex.accountGroupingOption == .customSQLiteGroup)
        #expect(reopenedRoot.state.commonEngine.settings.codexAccountGroupingOptionRawValue == "customSQLiteGroup")
    }

    @Test("BDD: Given codex header actions when not in multi-select then keep refresh/login/import visible")
    func testBDD_GivenCodexHeaderActions_WhenNotInMultiSelect_ThenShowsFirstThreePrimaryActions() {
        let visible = ProviderUsageAccountsViewModel.CodexState.visiblePrimaryHeaderActions(
            from: [.refreshAll, .login, .importAuth, .editConfig, .validateConfig],
            isMultiSelectionEnabled: false
        )

        #expect(visible == [.refreshAll, .login, .importAuth])
    }

    @Test("BDD: Given codex header actions when in multi-select then hide all primary actions")
    func testBDD_GivenCodexHeaderActions_WhenInMultiSelect_ThenShowsNoPrimaryActions() {
        let visible = ProviderUsageAccountsViewModel.CodexState.visiblePrimaryHeaderActions(
            from: [.refreshAll, .login, .importAuth],
            isMultiSelectionEnabled: true
        )

        #expect(visible.isEmpty)
    }
}
