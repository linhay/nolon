import Providers
import Testing

@Suite("ProviderUsageRegistry")
struct ProviderUsageRegistryTests {
    @Test("Fetch plan for codex contains CLI")
    func fetchPlan_codex_containsCLI() {
        let plan = ProviderUsageRegistry.fetchPlan(for: .codex)
        #expect(plan.sourceModes.contains(.auto))
        #expect(plan.sourceModes.contains(.cli))
    }

    @Test("Fetch plan for copilot contains API token")
    func fetchPlan_copilot_containsApiToken() {
        let plan = ProviderUsageRegistry.fetchPlan(for: .copilot)
        #expect(plan.sourceModes.contains(.auto))
        #expect(plan.sourceModes.contains(.apiToken))
    }

    @Test("Fetch plan for gemini contains cli source")
    func fetchPlan_gemini_containsCLI() {
        let plan = ProviderUsageRegistry.fetchPlan(for: .gemini)
        #expect(plan.sourceModes.contains(.auto))
        #expect(plan.sourceModes.contains(.cli))
    }

    @Test("Fetch plan for claude contains web source")
    func fetchPlan_claude_containsWeb() {
        let plan = ProviderUsageRegistry.fetchPlan(for: .claude)
        #expect(plan.sourceModes.contains(.auto))
        #expect(plan.sourceModes.contains(.web))
    }

    @Test("Metadata for codex has dashboard URL")
    func metadata_codex_containsDashboardURL() {
        let metadata = ProviderUsageRegistry.metadata(for: .codex)
        #expect(metadata?.dashboardURL != nil)
        #expect(metadata?.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
    }
}
