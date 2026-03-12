import XCTest
import Foundation
import ProviderCatalog
@testable import nolon

@MainActor
final class CodexAdvancedConfigRoleDraftTests: XCTestCase {
    private var temporaryDirectories: [URL] = []

    override func tearDownWithError() throws {
        let fileManager = FileManager.default
        for directory in temporaryDirectories {
            try? fileManager.removeItem(at: directory)
        }
        temporaryDirectories.removeAll()
    }

    func testBDD_GivenAdvancedConfig_WhenCreateEmptyRoleDraft_ThenNewRoleFieldsAreBlank() {
        // Given
        // When
        let role = CodexAdvancedConfigViewModel.makeEmptyRoleDraft()

        // Then
        XCTAssertEqual(role.name, "")
        XCTAssertEqual(role.description, "")
        XCTAssertEqual(role.configFile, "")
        XCTAssertEqual(role.model, "")
        XCTAssertEqual(role.modelReasoningEffort, "")
        XCTAssertEqual(role.sandboxMode, "")
        XCTAssertEqual(role.approvalPolicy, "")
    }

    func testBDD_GivenMainActorViewModel_WhenReleaseInstance_ThenDeinitDoesNotCrash() throws {
        // Given
        let provider = try XCTUnwrap(ProviderTemplate(rawValue: "codex")?.createProvider())
        weak var weakViewModel: CodexAdvancedConfigViewModel?

        // When
        autoreleasepool {
            let viewModel = CodexAdvancedConfigViewModel(provider: provider)
            _ = viewModel.addRoleDraft()
            weakViewModel = viewModel
        }

        // Then
        XCTAssertNil(weakViewModel)
    }

    func testBDD_GivenBuiltinRole_WhenCreateDraft_ThenAppliesBuiltinDefaults() {
        // Given
        let builtinRole = CodexBuiltinAgentRole.worker

        // When
        let draft = CodexAdvancedConfigViewModel.makeBuiltinRoleDraft(builtinRole)

        // Then
        XCTAssertEqual(draft.name, "worker")
        XCTAssertEqual(draft.description, builtinRole.defaultDescription)
        XCTAssertEqual(draft.configFile, "")
        XCTAssertEqual(draft.model, "")
        XCTAssertEqual(draft.modelReasoningEffort, "")
        XCTAssertEqual(draft.sandboxMode, "")
        XCTAssertEqual(draft.approvalPolicy, "")
    }

    func testBDD_GivenRoleDraft_WhenCommitOnSave_ThenAppendsDraftToRoles() throws {
        // Given
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "~/.codex/skills",
            workflowPath: "~/.codex/prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let viewModel = CodexAdvancedConfigViewModel(provider: provider)
        let draft = CodexAgentRoleDraft(
            name: "reviewer",
            description: "code review role",
            configFile: "",
            model: "gpt-5-codex",
            modelReasoningEffort: "medium",
            sandboxMode: "workspace-write",
            approvalPolicy: "on-request"
        )
        XCTAssertEqual(viewModel.roleDrafts.count, 0)

        // When
        let roleID = viewModel.addRoleDraft(draft)

        // Then
        XCTAssertEqual(roleID, draft.id)
        XCTAssertEqual(viewModel.roleDrafts.count, 1)
        XCTAssertEqual(viewModel.roleDrafts.first, draft)
    }

    func testTDD_GivenUnknownTomlFields_WhenPatchingStructuredDraft_ThenPreservesUnknownContent() throws {
        // Given
        let original = """
        # user note
        model = "gpt-5-codex"
        custom_top = "keep"

        [features]
        undo = true
        legacy_flag = true

        [mcp_servers.local]
        command = "node"

        [agents]
        max_threads = 2
        custom_budget = 9

        [agents.worker]
        description = "old"
        custom_field = "keep"

        [other]
        value = "stay"
        """
        let draft = CodexAdvancedStructuredDraft(
            approvalPolicy: "on-request",
            sandboxMode: "workspace-write",
            webSearch: nil,
            modelProvider: nil,
            profile: nil,
            personality: nil,
            reasoningSummary: nil,
            verbosity: nil,
            featureValues: [
                "undo": false,
                "legacy_flag": true,
                "multi_agent": true
            ],
            agentsMaxThreads: 4,
            agentsMaxDepth: 8,
            roleDrafts: [
                CodexAgentRoleDraft(
                    name: "worker",
                    description: "updated",
                    configFile: "",
                    model: "gpt-5.3-codex",
                    modelReasoningEffort: "",
                    sandboxMode: "",
                    approvalPolicy: ""
                )
            ]
        )

        // When
        let patched = try CodexStructuredConfigPatchService().patch(original: original, draft: draft)

        // Then
        XCTAssertTrue(patched.contains("custom_top = \"keep\""))
        XCTAssertTrue(patched.contains("[mcp_servers.local]"))
        XCTAssertTrue(patched.contains("custom_budget = 9"))
        XCTAssertTrue(patched.contains("custom_field = \"keep\""))
        XCTAssertTrue(patched.contains("[other]"))
        XCTAssertTrue(patched.contains("approval_policy = \"on-request\""))
        XCTAssertTrue(patched.contains("sandbox_mode = \"workspace-write\""))
        XCTAssertTrue(patched.contains("max_threads = 4"))
        XCTAssertTrue(patched.contains("max_depth = 8"))
        XCTAssertTrue(patched.contains("description = \"updated\""))
        XCTAssertTrue(patched.contains("model = \"gpt-5.3-codex\""))
        XCTAssertTrue(patched.contains("multi_agent = true"))
        XCTAssertTrue(patched.contains("undo = false"))
    }

    func testTDD_GivenViewModelNotLoaded_WhenSchedulingStructuredSave_ThenDoesNotMutateConfigFile() throws {
        // Given
        let provider = try makeTemporaryCodexProvider(config: """
        model = "gpt-5-codex"
        custom_top = "keep"

        [features]
        undo = true
        """)
        let configURL = URL(fileURLWithPath: (provider.defaultSkillsPath as NSString).expandingTildeInPath)
            .deletingLastPathComponent()
            .appendingPathComponent("config.toml")
        let original = try String(contentsOf: configURL, encoding: .utf8)
        let viewModel = CodexAdvancedConfigViewModel(provider: provider)

        // When
        viewModel.scheduleStructuredSaveIfReady()
        let expectation = XCTestExpectation(description: "wait for unexpected save")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Then
        XCTAssertEqual(try String(contentsOf: configURL, encoding: .utf8), original)
    }

    func testTDD_GivenUnknownConfigFields_WhenSavingStructuredConfig_ThenPreservesUnsupportedToml() async throws {
        // Given
        let provider = try makeTemporaryCodexProvider(config: """
        # keep this comment
        model = "gpt-5-codex"
        custom_top = "keep"

        [features]
        undo = true

        [agents]
        max_threads = 2
        custom_budget = 9

        [agents.worker]
        description = "old"
        custom_field = "keep"

        [other]
        value = "stay"
        """)
        let configURL = URL(fileURLWithPath: (provider.defaultSkillsPath as NSString).expandingTildeInPath)
            .deletingLastPathComponent()
            .appendingPathComponent("config.toml")
        let viewModel = CodexAdvancedConfigViewModel(provider: provider)
        await viewModel.load()
        viewModel.approvalPolicyDraft = "on-request"
        viewModel.sandboxModeDraft = "workspace-write"
        viewModel.agentsMaxDepthDraft = "6"
        viewModel.setFeature("multi_agent", enabled: true)
        guard let index = viewModel.roleDrafts.firstIndex(where: { $0.name == "worker" }) else {
            XCTFail("Expected preloaded worker role")
            return
        }
        viewModel.roleDrafts[index].description = "updated"

        // When
        await viewModel.saveStructuredConfig()
        let saved = try String(contentsOf: configURL, encoding: .utf8)

        // Then
        XCTAssertTrue(saved.contains("custom_top = \"keep\""))
        XCTAssertTrue(saved.contains("# keep this comment"))
        XCTAssertTrue(saved.contains("custom_budget = 9"))
        XCTAssertTrue(saved.contains("custom_field = \"keep\""))
        XCTAssertTrue(saved.contains("[other]"))
        XCTAssertTrue(saved.contains("approval_policy = \"on-request\""))
        XCTAssertTrue(saved.contains("sandbox_mode = \"workspace-write\""))
        XCTAssertTrue(saved.contains("max_depth = 6"))
        XCTAssertTrue(saved.contains("multi_agent = true"))
        XCTAssertTrue(saved.contains("description = \"updated\""))
    }

    private func makeTemporaryCodexProvider(config: String) throws -> Provider {
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("codex-advanced-tests-\(UUID().uuidString)", isDirectory: true)
        temporaryDirectories.append(root)
        let codexHome = root.appendingPathComponent(".codex", isDirectory: true)
        let skills = codexHome.appendingPathComponent("skills", isDirectory: true)
        let prompts = codexHome.appendingPathComponent("prompts", isDirectory: true)
        try FileManager.default.createDirectory(at: skills, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: prompts, withIntermediateDirectories: true)
        try config.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)
        return Provider(
            name: "Codex",
            defaultSkillsPath: skills.path,
            workflowPath: prompts.path,
            installMethod: .symlink,
            templateId: "codex"
        )
    }
}
