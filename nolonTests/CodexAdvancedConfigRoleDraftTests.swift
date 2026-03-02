import XCTest
import ProviderCatalog
@testable import nolon

@MainActor
final class CodexAdvancedConfigRoleDraftTests: XCTestCase {
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
}
