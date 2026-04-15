import Testing
import ProviderCatalog
@testable import nolon

@MainActor
struct ProviderUsageLoginFlowViewModelParityTests {
    @Test("BDD: Given root and engine state when reading login flow state then values stay parity")
    func testBDD_GivenRootAndEngineState_WhenReadingLoginFlowState_ThenValuesStayParity() {
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

        #expect(root.loginFlowViewModel.isRunningCLILogin == root.state.accountsEngine.isRunningCLILogin)
        #expect(root.loginFlowViewModel.isShowingLoginURLSheet == root.state.accountsEngine.isShowingLoginURLSheet)
    }

    @Test("BDD: Given copilot usage page when reading generic header actions then sign in and refresh stay available")
    func testBDD_GivenCopilotUsagePage_WhenReadingHeaderActions_ThenContainsSignInAndRefresh() {
        let provider = Provider(
            id: "copilot",
            kind: .vendor,
            name: "GitHub Copilot",
            defaultSkillsPath: "/tmp/copilot/skills",
            workflowPath: "/tmp/copilot/workflows",
            vendorCategory: .integrated,
            templateId: ProviderTemplate.copilot.rawValue
        )
        let root = ProviderUsageRootViewModel(provider: provider)

        #expect(root.genericHeaderActions.contains(.signIn))
        #expect(root.genericHeaderActions.contains(.refresh))
    }
}
