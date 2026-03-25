import Testing
import ProviderCatalog
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
}

