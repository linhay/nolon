import Testing
import ProviderCatalog
@testable import nolon

@MainActor
struct ProviderUsageAccountsViewModelParityTests {
    @Test("BDD: Given root and engine state when reading account state then values stay parity")
    func testBDD_GivenRootAndEngineState_WhenReadingAccountState_ThenValuesStayParity() {
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

        #expect(root.accountsViewModel.codex.accounts == root.state.codexEngine.codexAccounts)
        #expect(root.accountsViewModel.codex.accountSummaries == root.state.codexEngine.codexAccountSummaries)
        #expect(root.accountsViewModel.codex.cloudSyncSnapshot == root.state.codexEngine.codexCloudSyncSnapshot)
    }
}
