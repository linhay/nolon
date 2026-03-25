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

        #expect(root.loginFlowViewModel.isRunningCLILogin == root.state.engine.isRunningCLILogin)
        #expect(root.loginFlowViewModel.isShowingLoginURLSheet == root.state.engine.isShowingLoginURLSheet)
    }
}

