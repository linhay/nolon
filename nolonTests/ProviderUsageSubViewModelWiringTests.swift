import Testing
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
        #expect(root.accountsViewModel.codex.accounts == root.state.engine.codexAccounts)
        #expect(root.tokenTrendViewModel.tokenTrendRange == root.state.engine.tokenTrendRange)
        #expect(root.gatewayCardsViewModel.gatewayCardsState == root.state.engine.gatewayCardsState)
        #expect(root.importExportViewModel.isShowingCodexImportSheet == root.state.engine.isShowingCodexImportSheet)
        #expect(root.loginFlowViewModel.isRunningCLILogin == root.state.engine.isRunningCLILogin)
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
        #expect(root.state.engine.settings.codexUseListLayout == true)
    }
}
