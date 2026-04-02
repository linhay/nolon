import Testing
import ProviderCatalog
@testable import nolon

@MainActor
struct CodexGatewayCardsViewModelParityTests {
    @Test("BDD: Given root and engine state when reading gateway cards state then values stay parity")
    func testBDD_GivenRootAndEngineState_WhenReadingGatewayCardsState_ThenValuesStayParity() {
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

        #expect(root.gatewayCardsViewModel.gatewayCards == root.state.codexEngine.gatewayCards)
    }
}

