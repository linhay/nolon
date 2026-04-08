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
        XCTAssertEqual(role.modelReasoningSummary, "")
        XCTAssertEqual(role.modelVerbosity, "")
        XCTAssertEqual(role.sandboxMode, "")
        XCTAssertEqual(role.approvalPolicy, "")
        XCTAssertEqual(role.personality, "")
        XCTAssertEqual(role.webSearch, "")
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
        XCTAssertEqual(draft.modelReasoningSummary, "")
        XCTAssertEqual(draft.modelVerbosity, "")
        XCTAssertEqual(draft.sandboxMode, "")
        XCTAssertEqual(draft.approvalPolicy, "")
        XCTAssertEqual(draft.personality, "")
        XCTAssertEqual(draft.webSearch, "")
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
            modelReasoningSummary: "",
            modelVerbosity: "",
            sandboxMode: "workspace-write",
            approvalPolicy: "on-request",
            personality: "",
            webSearch: ""
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
            hideAgentReasoning: nil,
            modelAutoCompactTokenLimit: nil,
            compactPrompt: nil,
            experimentalCompactPromptFile: nil,
            reasoningSummary: nil,
            verbosity: nil,
            historyPersistence: nil,
            historyMaxBytes: nil,
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
                    modelReasoningSummary: "",
                    modelVerbosity: "",
                    sandboxMode: "",
                    approvalPolicy: "",
                    personality: "",
                    webSearch: ""
                )
            ],
            preservedTopLevelRawValues: [:],
            preservedHistoryRawValues: [:],
            preservedRoleRawValues: [:]
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

    func testTDD_GivenViewModelNotLoaded_WhenSchedulingStructuredSave_ThenDoesNotMutateConfigFile() async throws {
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
        try await Task.sleep(for: .milliseconds(200))

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

    func testTDD_GivenOfficialRuntimeControls_WhenSavingStructuredConfig_ThenPersistsHistoryAndCompactionFields() async throws {
        // Given
        let provider = try makeTemporaryCodexProvider(config: """
        model = "gpt-5-codex"
        hide_agent_reasoning = false
        model_auto_compact_token_limit = 240000
        compact_prompt = "Summarize old turns."
        experimental_compact_prompt_file = ".codex/compact.md"

        [history]
        persistence = "save-all"
        max_bytes = 2048
        """)
        let configURL = URL(fileURLWithPath: (provider.defaultSkillsPath as NSString).expandingTildeInPath)
            .deletingLastPathComponent()
            .appendingPathComponent("config.toml")
        let viewModel = CodexAdvancedConfigViewModel(provider: provider)
        await viewModel.load()
        viewModel.hideAgentReasoningDraft = true
        viewModel.modelAutoCompactTokenLimitDraft = "320000"
        viewModel.compactPromptDraft = "Keep recent decisions and compress older turns."
        viewModel.experimentalCompactPromptFileDraft = ".codex/prompts/compact.md"
        viewModel.historyPersistenceDraft = "none"
        viewModel.historyMaxBytesDraft = "8192"

        // When
        await viewModel.saveStructuredConfig()
        let saved = try String(contentsOf: configURL, encoding: .utf8)

        // Then
        XCTAssertTrue(saved.contains("hide_agent_reasoning = true"))
        XCTAssertTrue(saved.contains("model_auto_compact_token_limit = 320000"))
        XCTAssertTrue(saved.contains("compact_prompt = \"Keep recent decisions and compress older turns.\""))
        XCTAssertTrue(saved.contains("experimental_compact_prompt_file = \".codex/prompts/compact.md\""))
        XCTAssertTrue(saved.contains("[history]"))
        XCTAssertTrue(saved.contains("persistence = \"none\""))
        XCTAssertTrue(saved.contains("max_bytes = 8192"))
    }

    func testTDD_GivenGranularApprovalPolicy_WhenSavingOtherFields_ThenUnsupportedOfficialSyntaxIsPreserved() async throws {
        // Given
        let provider = try makeTemporaryCodexProvider(config: """
        approval_policy = { granular = { sandbox_approval = true, rules = false } }
        sandbox_mode = "workspace-write"
        model_verbosity = "medium"
        """)
        let configURL = URL(fileURLWithPath: (provider.defaultSkillsPath as NSString).expandingTildeInPath)
            .deletingLastPathComponent()
            .appendingPathComponent("config.toml")
        let viewModel = CodexAdvancedConfigViewModel(provider: provider)
        await viewModel.load()
        viewModel.verbosityDraft = "high"

        // When
        await viewModel.saveStructuredConfig()
        let saved = try String(contentsOf: configURL, encoding: .utf8)

        // Then
        XCTAssertTrue(saved.contains("approval_policy = { granular = { sandbox_approval = true, rules = false } }"))
        XCTAssertTrue(saved.contains("model_verbosity = \"high\""))
    }

    func testTDD_GivenRoleAdvancedFields_WhenSavingStructuredConfig_ThenPreservesAndUpdatesOfficialRoleOptions() async throws {
        // Given
        let provider = try makeTemporaryCodexProvider(config: """
        [features]
        multi_agent = true

        [agents.worker]
        description = "old"
        model = "gpt-5.3-codex"
        model_reasoning_effort = "medium"
        model_reasoning_summary = "concise"
        model_verbosity = "medium"
        personality = "pragmatic"
        web_search = "cached"
        """)
        let configURL = URL(fileURLWithPath: (provider.defaultSkillsPath as NSString).expandingTildeInPath)
            .deletingLastPathComponent()
            .appendingPathComponent("config.toml")
        let viewModel = CodexAdvancedConfigViewModel(provider: provider)
        await viewModel.load()
        guard let index = viewModel.roleDrafts.firstIndex(where: { $0.name == "worker" }) else {
            XCTFail("Expected worker role")
            return
        }
        viewModel.roleDrafts[index].modelReasoningSummary = "detailed"
        viewModel.roleDrafts[index].modelVerbosity = "high"
        viewModel.roleDrafts[index].personality = "friendly"
        viewModel.roleDrafts[index].webSearch = "live"

        // When
        await viewModel.saveStructuredConfig()
        let saved = try String(contentsOf: configURL, encoding: .utf8)

        // Then
        XCTAssertTrue(saved.contains("model_reasoning_summary = \"detailed\""))
        XCTAssertTrue(saved.contains("model_verbosity = \"high\""))
        XCTAssertTrue(saved.contains("personality = \"friendly\""))
        XCTAssertTrue(saved.contains("web_search = \"live\""))
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
