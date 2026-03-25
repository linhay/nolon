import Testing
import ProviderCatalog
@testable import nolon

@MainActor
struct CodexQuickSwitchMenuBarViewModelTests {
    @Test("BDD: Given mixed providers when filtering quick switch providers then keeps codex and gemini only")
    func testBDD_GivenMixedProviders_WhenFilteringQuickSwitchProviders_ThenKeepsCodexAndGeminiOnly() {
        let providers = [
            Provider(id: "codex", name: "Codex", defaultSkillsPath: "/tmp/codex", workflowPath: "/tmp/codex", templateId: ProviderTemplate.codex.rawValue),
            Provider(id: "gemini", name: "Gemini", defaultSkillsPath: "/tmp/gemini", workflowPath: "/tmp/gemini", templateId: ProviderTemplate.gemini.rawValue),
            Provider(id: "claude", name: "Claude", defaultSkillsPath: "/tmp/claude", workflowPath: "/tmp/claude", templateId: ProviderTemplate.claudeCode.rawValue)
        ]
        let filtered = CodexQuickSwitchProviderResolver.providers(from: providers)
        #expect(filtered.map(\.id) == ["codex", "gemini"])
    }
}
