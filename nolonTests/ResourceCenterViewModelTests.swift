import XCTest
import ProviderCatalog
import NolonResourceKit
import NolonUIFoundation
@testable import nolon

@MainActor
final class ResourceCenterViewModelTests: XCTestCase {
    private func makeProvider(id: String, name: String, root: String) -> Provider {
        Provider(
            id: id,
            name: name,
            defaultSkillsPath: "\(root)/\(id)/skills",
            workflowPath: "\(root)/\(id)/workflows",
            installMethod: .symlink,
            templateId: nil
        )
    }

    func testBDD_GivenSelectedTab_WhenInitializeViewModel_ThenSelectionIsPreserved() async {
        let viewModel = ResourceCenterViewModel(selectedTab: .workflows)
        let selectedTab = viewModel.selectedTab

        XCTAssertEqual(selectedTab, .workflows)
    }

    func testBDD_GivenGlobalSkillsRepository_WhenResolveEffectiveTargetProvider_ThenIgnoreSelectedProvider() async {
        let viewModel = ResourceCenterViewModel(selectedTab: .skills)
        let provider = Provider(
            id: "provider-a",
            name: "Provider A",
            defaultSkillsPath: "/tmp/provider-a/skills",
            workflowPath: "/tmp/provider-a/workflows",
            installMethod: .symlink,
            templateId: nil
        )
        let effectiveProvider = viewModel.effectiveTargetProvider(
            for: .globalSkills,
            fallback: provider
        )

        XCTAssertNil(effectiveProvider)
    }

    func testBDD_GivenNonGlobalRepository_WhenResolveEffectiveTargetProvider_ThenKeepSelectedProvider() async {
        let viewModel = ResourceCenterViewModel(selectedTab: .skills)
        let provider = Provider(
            id: "provider-a",
            name: "Provider A",
            defaultSkillsPath: "/tmp/provider-a/skills",
            workflowPath: "/tmp/provider-a/workflows",
            installMethod: .symlink,
            templateId: nil
        )
        let repository = RemoteRepository(
            id: "repo-clawhub",
            name: "Clawhub",
            baseURL: "https://clawhub.ai",
            templateType: .clawdhub,
            isBuiltIn: true
        )
        let effectiveProvider = viewModel.effectiveTargetProvider(
            for: repository,
            fallback: provider
        )

        XCTAssertEqual(effectiveProvider?.id, "provider-a")
    }

    func testBDD_GivenGlobalSkillsRepository_WhenRefreshInstalledResources_ThenIgnoreProviderScopedInstallState() async throws {
        let fixture = try TestFixture()
        defer { fixture.cleanup() }

        let repository = SkillRepository(nolonManager: fixture.nolonManager)
        let globalSource = try fixture.createSampleSkill(id: "global-only", name: "Global Only")
        _ = try repository.importSkill(from: globalSource)

        let provider = makeProvider(id: "provider-a", name: "Provider A", root: fixture.tempRoot.path)
        fixture.providerSettings.providers = [provider]

        let providerOnlyURL = URL(fileURLWithPath: provider.defaultSkillsPath).appendingPathComponent("provider-only")
        try FileManager.default.createDirectory(at: providerOnlyURL, withIntermediateDirectories: true)
        try """
        ---
        name: Provider Only
        description: Provider scoped skill
        version: 1.0.0
        ---
        """.write(to: providerOnlyURL.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        let viewModel = ResourceCenterViewModel(selectedTab: .skills)
        viewModel.refreshInstalledResources(
            repository: repository,
            selectedRepository: .globalSkills,
            fallbackTargetProvider: provider,
            settings: fixture.providerSettings
        )
        let installedSlugs = viewModel.installedSlugs

        XCTAssertEqual(installedSlugs, ["global-only"])
    }
}
