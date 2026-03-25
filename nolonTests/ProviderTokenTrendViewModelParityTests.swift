import Testing
import ProviderCatalog
@testable import nolon

@MainActor
struct ProviderTokenTrendViewModelParityTests {
    @Test("BDD: Given root and engine state when reading token trend state then values stay parity")
    func testBDD_GivenRootAndEngineState_WhenReadingTokenTrendState_ThenValuesStayParity() {
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

        #expect(root.tokenTrendViewModel.tokenTrendRange == root.state.engine.tokenTrendRange)
        #expect(root.tokenTrendViewModel.tokenTrendSnapshot == root.state.engine.tokenTrendSnapshot)
    }
}

