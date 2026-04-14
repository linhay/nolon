import Testing
import ProviderCatalog
import ProviderUsage
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

        #expect(root.tokenTrendViewModel.tokenTrendRange == root.state.commonEngine.tokenTrendRange)
        #expect(root.tokenTrendViewModel.tokenTrendSnapshot == root.state.commonEngine.tokenTrendSnapshot)
        #expect(root.tokenTrendViewModel.tokenTrendCapability == root.state.commonEngine.tokenTrendCapability)
        #expect(root.tokenTrendViewModel.selectedDayKey == root.state.commonEngine.selectedTokenTrendDayKey)
        #expect(root.tokenTrendViewModel.intradayBucket == root.state.commonEngine.intradayBucket)
        #expect(root.tokenTrendViewModel.intradaySnapshot == root.state.commonEngine.intradaySnapshot)
    }
}
