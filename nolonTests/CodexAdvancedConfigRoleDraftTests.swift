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
}
