import XCTest
import STFilePath
import NolonResourceKit
import ProviderCatalog
import ProviderUsage
import CodexBarProviderCatalog
import NolonUIFoundation
@testable import nolon

@MainActor
final class NolonAccountsViewModelIntegrationTests: XCTestCase {
    func testBDD_GivenRootFactory_WhenBuildingAccountsViewModel_ThenAcceptsRootViewModelDependency() {
        let provider = Provider(
            id: "codex",
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: "/tmp/codex/skills",
            workflowPath: "/tmp/codex/prompts",
            vendorCategory: .original,
            templateId: ProviderTemplate.codex.rawValue
        )
        let viewModel = NolonAccountsViewModel(
            settings: ProviderSettings(),
            providerUsageViewModelFactory: { _ in
                ProviderUsageRootViewModel(provider: provider)
            }
        )

        XCTAssertEqual(viewModel.accountCards(for: provider).count, 1)
    }
}
