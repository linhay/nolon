import Testing
import ProviderCatalog
@testable import nolon

@MainActor
struct ProviderUsageRootViewModelStoreTests {
    @Test("BDD: Given same provider id when resolving root usage view model then returns the same instance")
    func testBDD_GivenSameProviderID_WhenResolvingRootUsageViewModel_ThenReturnsSameInstance() {
        let store = ProviderUsageRootViewModelStore()
        let provider = Provider(
            id: "codex",
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: "/tmp/codex/skills",
            workflowPath: "/tmp/codex/prompts",
            vendorCategory: .original,
            templateId: ProviderTemplate.codex.rawValue
        )

        let first = store.viewModel(for: provider)
        let second = store.viewModel(for: provider)

        #expect(ObjectIdentifier(first) == ObjectIdentifier(second))
    }
}

