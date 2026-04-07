import XCTest
import ProviderCatalog
import NolonUIFoundation
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

    func testBDD_GivenOpenCodeProvider_WhenLoadingData_ThenReadsGlobalAGENTSmd() async throws {
        let opencodeHome = fixture.tempRoot.appendingPathComponent(".config/opencode")
        let skills = opencodeHome.appendingPathComponent("skills")
        try fixture.fileManager.createDirectory(at: skills, withIntermediateDirectories: true)
        try "# OpenCode".write(to: opencodeHome.appendingPathComponent("AGENTS.md"), atomically: true, encoding: .utf8)

        let provider = Provider(
            name: "OpenCode",
            defaultSkillsPath: skills.path,
            workflowPath: opencodeHome.appendingPathComponent("commands").path,
            installMethod: .symlink,
            templateId: "opencode"
        )
        viewModel = ProviderDetailGridViewModel(provider: provider, settings: fixture.providerSettings)

        await viewModel.loadData()

        XCTAssertEqual(viewModel.agentsFiles.map(\.fileName), ["AGENTS.md"])
    }

    func testBDD_GivenCopilotProvider_WhenLoadingData_ThenReadsHomeAndCustomDirsAGENTSmd() async throws {
        let copilotHome = fixture.tempRoot.appendingPathComponent(".copilot")
        let skills = copilotHome.appendingPathComponent("agents")
        try fixture.fileManager.createDirectory(at: skills, withIntermediateDirectories: true)
        try "# Copilot Home".write(to: copilotHome.appendingPathComponent("AGENTS.md"), atomically: true, encoding: .utf8)

        let customRoot = fixture.tempRoot.appendingPathComponent("copilot-custom")
        try fixture.fileManager.createDirectory(at: customRoot, withIntermediateDirectories: true)
        try "# Copilot Custom".write(to: customRoot.appendingPathComponent("AGENTS.md"), atomically: true, encoding: .utf8)

        setenv("COPILOT_CUSTOM_INSTRUCTIONS_DIRS", customRoot.path, 1)
        defer { unsetenv("COPILOT_CUSTOM_INSTRUCTIONS_DIRS") }

        let provider = Provider(
            name: "GitHub Copilot",
            defaultSkillsPath: skills.path,
            workflowPath: copilotHome.appendingPathComponent("workflows").path,
            installMethod: .symlink,
            templateId: "copilot"
        )
        viewModel = ProviderDetailGridViewModel(provider: provider, settings: fixture.providerSettings)

        await viewModel.loadData()

        XCTAssertEqual(viewModel.agentsFiles.count, 2)
        XCTAssertTrue(viewModel.agentsFiles.contains(where: { $0.path == copilotHome.appendingPathComponent("AGENTS.md").path }))
        XCTAssertTrue(viewModel.agentsFiles.contains(where: { $0.path == customRoot.appendingPathComponent("AGENTS.md").path }))
    }

    func testBDD_GivenOpenCodeProvider_WhenCreatingDraft_ThenCreatesGlobalAGENTSmd() async throws {
        let opencodeHome = fixture.tempRoot.appendingPathComponent(".config/opencode")
        let skills = opencodeHome.appendingPathComponent("skills")
        try fixture.fileManager.createDirectory(at: skills, withIntermediateDirectories: true)

        let provider = Provider(
            name: "OpenCode",
            defaultSkillsPath: skills.path,
            workflowPath: opencodeHome.appendingPathComponent("commands").path,
            installMethod: .symlink,
            templateId: "opencode"
        )
        viewModel = ProviderDetailGridViewModel(provider: provider, settings: fixture.providerSettings)

        let createdURL = viewModel.createAgentDocDraft()

        XCTAssertEqual(createdURL?.path, opencodeHome.appendingPathComponent("AGENTS.md").path)
        XCTAssertTrue(fixture.fileManager.fileExists(atPath: createdURL?.path ?? ""))
    }
}
