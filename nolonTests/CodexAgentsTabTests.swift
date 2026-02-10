import XCTest
import ProviderCatalog
@testable import nolon

@MainActor
final class CodexAgentsTabTests: XCTestCase {
    var fixture: TestFixture!
    var viewModel: ProviderDetailGridViewModel!

    override func setUpWithError() throws {
        fixture = try TestFixture()
    }

    override func tearDownWithError() throws {
        fixture.cleanup()
    }

    func testBDD_GivenCodexProvider_WhenLoadingData_ThenLoadsOnlyCodexHomeAgentsFiles() async throws {
        let codexHome = fixture.tempRoot.appendingPathComponent(".codex")
        let skills = codexHome.appendingPathComponent("skills")
        try fixture.fileManager.createDirectory(at: skills, withIntermediateDirectories: true)
        try "base".write(to: codexHome.appendingPathComponent("AGENTS.md"), atomically: true, encoding: .utf8)
        try "override".write(to: codexHome.appendingPathComponent("AGENTS.override.md"), atomically: true, encoding: .utf8)
        try "ignore".write(to: codexHome.appendingPathComponent("AGENTS.txt"), atomically: true, encoding: .utf8)

        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: skills.path,
            workflowPath: codexHome.appendingPathComponent("prompts").path,
            installMethod: .symlink,
            templateId: "codex"
        )
        viewModel = ProviderDetailGridViewModel(provider: provider, settings: fixture.providerSettings)

        await viewModel.loadData()

        XCTAssertEqual(viewModel.agentsFiles.count, 2)
        XCTAssertEqual(viewModel.agentsFiles.map(\.fileName), ["AGENTS.override.md", "AGENTS.md"])
    }

    func testBDD_GivenBothFiles_WhenLoading_ThenOverrideComesFirst() async throws {
        let codexHome = fixture.tempRoot.appendingPathComponent(".codex")
        let skills = codexHome.appendingPathComponent("skills")
        try fixture.fileManager.createDirectory(at: skills, withIntermediateDirectories: true)
        try "base".write(to: codexHome.appendingPathComponent("AGENTS.md"), atomically: true, encoding: .utf8)
        try "override".write(to: codexHome.appendingPathComponent("AGENTS.override.md"), atomically: true, encoding: .utf8)

        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: skills.path,
            workflowPath: codexHome.appendingPathComponent("prompts").path,
            installMethod: .symlink,
            templateId: "codex"
        )
        viewModel = ProviderDetailGridViewModel(provider: provider, settings: fixture.providerSettings)

        await viewModel.loadData()

        XCTAssertEqual(viewModel.agentsFiles.first?.kind, .override)
        XCTAssertEqual(viewModel.agentsFiles.last?.kind, .base)
    }

    func testBDD_GivenNoAgentsFiles_WhenCreateDraft_ThenCreatesAGENTSmd() async throws {
        let codexHome = fixture.tempRoot.appendingPathComponent(".codex")
        let skills = codexHome.appendingPathComponent("skills")
        try fixture.fileManager.createDirectory(at: skills, withIntermediateDirectories: true)

        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: skills.path,
            workflowPath: codexHome.appendingPathComponent("prompts").path,
            installMethod: .symlink,
            templateId: "codex"
        )
        viewModel = ProviderDetailGridViewModel(provider: provider, settings: fixture.providerSettings)

        let createdURL = viewModel.createAgentDocDraft()

        XCTAssertEqual(createdURL?.lastPathComponent, "AGENTS.md")
        XCTAssertTrue(fixture.fileManager.fileExists(atPath: createdURL?.path ?? ""))
    }

    func testBDD_GivenBaseExists_WhenCreateDraft_ThenCreatesAGENTSoverride() async throws {
        let codexHome = fixture.tempRoot.appendingPathComponent(".codex")
        let skills = codexHome.appendingPathComponent("skills")
        try fixture.fileManager.createDirectory(at: skills, withIntermediateDirectories: true)
        try "base".write(to: codexHome.appendingPathComponent("AGENTS.md"), atomically: true, encoding: .utf8)

        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: skills.path,
            workflowPath: codexHome.appendingPathComponent("prompts").path,
            installMethod: .symlink,
            templateId: "codex"
        )
        viewModel = ProviderDetailGridViewModel(provider: provider, settings: fixture.providerSettings)

        let createdURL = viewModel.createAgentDocDraft()

        XCTAssertEqual(createdURL?.lastPathComponent, "AGENTS.override.md")
        XCTAssertTrue(fixture.fileManager.fileExists(atPath: createdURL?.path ?? ""))
    }

    func testBDD_GivenAgentFile_WhenDeleting_ThenRemovedAndStateRefreshed() async throws {
        let codexHome = fixture.tempRoot.appendingPathComponent(".codex")
        let skills = codexHome.appendingPathComponent("skills")
        try fixture.fileManager.createDirectory(at: skills, withIntermediateDirectories: true)
        let base = codexHome.appendingPathComponent("AGENTS.md")
        try "base".write(to: base, atomically: true, encoding: .utf8)

        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: skills.path,
            workflowPath: codexHome.appendingPathComponent("prompts").path,
            installMethod: .symlink,
            templateId: "codex"
        )
        viewModel = ProviderDetailGridViewModel(provider: provider, settings: fixture.providerSettings)
        await viewModel.loadData()

        guard let first = viewModel.agentsFiles.first else {
            XCTFail("Expected AGENTS file")
            return
        }
        await viewModel.deleteAgentDoc(first)

        XCTAssertFalse(fixture.fileManager.fileExists(atPath: base.path))
        XCTAssertEqual(viewModel.agentsFiles.count, 0)
    }

    func testBDD_GivenCodexProvider_WhenLoadingTabCounts_ThenAgentsCountMatchesExistingFiles() async throws {
        let codexHome = fixture.tempRoot.appendingPathComponent(".codex")
        let skills = codexHome.appendingPathComponent("skills")
        try fixture.fileManager.createDirectory(at: skills, withIntermediateDirectories: true)
        try "base".write(to: codexHome.appendingPathComponent("AGENTS.md"), atomically: true, encoding: .utf8)

        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: skills.path,
            workflowPath: codexHome.appendingPathComponent("prompts").path,
            installMethod: .symlink,
            templateId: "codex"
        )
        let tabViewModel = ProviderContentTabViewModel(settings: fixture.providerSettings)

        await tabViewModel.loadCounts(for: provider)

        XCTAssertEqual(tabViewModel.count(for: .agents), 1)
    }
}
