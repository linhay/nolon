import XCTest
import ProviderCatalog
import NolonUIFoundation
@testable import nolon

@MainActor
final class CodexRulesTabTests: XCTestCase {
    var fixture: TestFixture!
    var viewModel: ProviderDetailGridViewModel!

    override func setUpWithError() throws {
        fixture = try TestFixture()
    }

    override func tearDownWithError() throws {
        fixture.cleanup()
    }

    func testBDD_GivenCodexProvider_WhenLoadingData_ThenLoadsRulesFilesRecursively() async throws {
        // Given
        let codexHome = fixture.tempRoot.appendingPathComponent(".codex")
        let skills = codexHome.appendingPathComponent("skills")
        let rules = codexHome.appendingPathComponent("rules")
        let nested = rules.appendingPathComponent("ios")
        try fixture.fileManager.createDirectory(at: skills, withIntermediateDirectories: true)
        try fixture.fileManager.createDirectory(at: nested, withIntermediateDirectories: true)
        try "use swift".write(to: rules.appendingPathComponent("a.rules"), atomically: true, encoding: .utf8)
        try "prefer tests".write(to: nested.appendingPathComponent("b.rules"), atomically: true, encoding: .utf8)
        try "# legacy".write(to: rules.appendingPathComponent("legacy.md"), atomically: true, encoding: .utf8)
        try "not a rule".write(to: rules.appendingPathComponent("ignore.txt"), atomically: true, encoding: .utf8)

        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: skills.path,
            workflowPath: codexHome.appendingPathComponent("prompts").path,
            installMethod: .symlink,
            templateId: "codex"
        )
        viewModel = ProviderDetailGridViewModel(provider: provider, settings: fixture.providerSettings)

        // When
        await viewModel.loadData()

        // Then
        XCTAssertEqual(viewModel.rules.count, 2)
        XCTAssertEqual(viewModel.rules.map(\.relativePath), ["a.rules", "ios/b.rules"])
        XCTAssertEqual(viewModel.rules.first?.name, "a")
        XCTAssertEqual(viewModel.rules.first?.preview, "use swift")
    }

    func testBDD_GivenHiddenRulesFile_WhenLoadingData_ThenHiddenRulesAreIgnored() async throws {
        // Given
        let codexHome = fixture.tempRoot.appendingPathComponent(".codex")
        let skills = codexHome.appendingPathComponent("skills")
        let rules = codexHome.appendingPathComponent("rules")
        try fixture.fileManager.createDirectory(at: skills, withIntermediateDirectories: true)
        try fixture.fileManager.createDirectory(at: rules, withIntermediateDirectories: true)
        try "visible".write(to: rules.appendingPathComponent("visible.rules"), atomically: true, encoding: .utf8)
        try "hidden".write(to: rules.appendingPathComponent(".hidden.rules"), atomically: true, encoding: .utf8)

        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: skills.path,
            workflowPath: codexHome.appendingPathComponent("prompts").path,
            installMethod: .symlink,
            templateId: "codex"
        )
        viewModel = ProviderDetailGridViewModel(provider: provider, settings: fixture.providerSettings)

        // When
        await viewModel.loadData()

        // Then
        XCTAssertEqual(viewModel.rules.map(\.relativePath), ["visible.rules"])
    }

    func testBDD_GivenRule_WhenDeleting_ThenFileIsRemovedAndStateRefreshed() async throws {
        // Given
        let codexHome = fixture.tempRoot.appendingPathComponent(".codex")
        let skills = codexHome.appendingPathComponent("skills")
        let rules = codexHome.appendingPathComponent("rules")
        try fixture.fileManager.createDirectory(at: skills, withIntermediateDirectories: true)
        try fixture.fileManager.createDirectory(at: rules, withIntermediateDirectories: true)
        let ruleURL = rules.appendingPathComponent("cleanup.rules")
        try "Cleanup".write(to: ruleURL, atomically: true, encoding: .utf8)

        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: skills.path,
            workflowPath: codexHome.appendingPathComponent("prompts").path,
            installMethod: .symlink,
            templateId: "codex"
        )
        viewModel = ProviderDetailGridViewModel(provider: provider, settings: fixture.providerSettings)
        await viewModel.loadData()
        XCTAssertEqual(viewModel.rules.count, 1)

        // When
        guard let firstRule = viewModel.rules.first else {
            XCTFail("Expected a rule")
            return
        }
        await viewModel.deleteRule(firstRule)

        // Then
        XCTAssertEqual(viewModel.rules.count, 0)
        XCTAssertFalse(fixture.fileManager.fileExists(atPath: ruleURL.path))
    }

    func testBDD_GivenRulesFolder_WhenLoadingTabCounts_ThenRulesCountMatchesRulesFiles() async throws {
        // Given
        let codexHome = fixture.tempRoot.appendingPathComponent(".codex")
        let skills = codexHome.appendingPathComponent("skills")
        let rules = codexHome.appendingPathComponent("rules")
        try fixture.fileManager.createDirectory(at: skills, withIntermediateDirectories: true)
        try fixture.fileManager.createDirectory(at: rules, withIntermediateDirectories: true)
        try "One".write(to: rules.appendingPathComponent("one.rules"), atomically: true, encoding: .utf8)
        try "Two".write(to: rules.appendingPathComponent("two.rules"), atomically: true, encoding: .utf8)
        try "legacy".write(to: rules.appendingPathComponent("legacy.md"), atomically: true, encoding: .utf8)
        try "ignored".write(to: rules.appendingPathComponent("note.txt"), atomically: true, encoding: .utf8)

        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: skills.path,
            workflowPath: codexHome.appendingPathComponent("prompts").path,
            installMethod: .symlink,
            templateId: "codex"
        )
        let tabViewModel = ProviderContentTabViewModel(settings: fixture.providerSettings)

        // When
        await tabViewModel.loadCounts(for: provider)

        // Then
        XCTAssertEqual(tabViewModel.count(for: .rules), 2)
    }

    func testBDD_GivenCodexProvider_WhenCreatingRuleDraft_ThenCreatesNewRuleFileAndRefreshesRules() async throws {
        // Given
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

        // When
        let createdURL = viewModel.createRuleDraft()

        // Then
        XCTAssertNotNil(createdURL)
        guard let createdURL else { return }
        XCTAssertEqual(createdURL.pathExtension, "rules")
        XCTAssertEqual(createdURL.lastPathComponent, "new-rule-1.rules")
        XCTAssertTrue(fixture.fileManager.fileExists(atPath: createdURL.path))
        XCTAssertEqual(viewModel.rules.count, 1)
        XCTAssertEqual(
            viewModel.rules.first.map { URL(fileURLWithPath: $0.path).standardizedFileURL.path },
            createdURL.standardizedFileURL.path
        )
    }

    func testBDD_GivenExistingRuleName_WhenCreatingRuleDraft_ThenCreatesNextIncrementedRuleFile() async throws {
        // Given
        let codexHome = fixture.tempRoot.appendingPathComponent(".codex")
        let skills = codexHome.appendingPathComponent("skills")
        let rules = codexHome.appendingPathComponent("rules")
        try fixture.fileManager.createDirectory(at: skills, withIntermediateDirectories: true)
        try fixture.fileManager.createDirectory(at: rules, withIntermediateDirectories: true)
        try "default".write(
            to: rules.appendingPathComponent("default.rules"),
            atomically: true,
            encoding: .utf8
        )
        try "first".write(
            to: rules.appendingPathComponent("new-rule-1.rules"),
            atomically: true,
            encoding: .utf8
        )

        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: skills.path,
            workflowPath: codexHome.appendingPathComponent("prompts").path,
            installMethod: .symlink,
            templateId: "codex"
        )
        viewModel = ProviderDetailGridViewModel(provider: provider, settings: fixture.providerSettings)

        // When
        let createdURL = viewModel.createRuleDraft()

        // Then
        XCTAssertEqual(createdURL?.lastPathComponent, "new-rule-2.rules")
        XCTAssertEqual(viewModel.rules.count, 3)
    }

    func testTDD_GivenGenericProvider_WhenCreatingRuleDraft_ThenReturnsNil() async throws {
        // Given
        let provider = Provider(
            name: "Claude",
            defaultSkillsPath: fixture.tempRoot.appendingPathComponent("claude/skills").path,
            workflowPath: fixture.tempRoot.appendingPathComponent("claude/prompts").path,
            installMethod: .copy,
            templateId: "claudeCode"
        )
        viewModel = ProviderDetailGridViewModel(provider: provider, settings: fixture.providerSettings)

        // When
        let createdURL = viewModel.createRuleDraft()

        // Then
        XCTAssertNil(createdURL)
    }
}
