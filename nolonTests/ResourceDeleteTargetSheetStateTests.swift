import XCTest
import ProviderCatalog
@testable import nolon

final class ResourceDeleteTargetSheetStateTests: XCTestCase {
    func testBDD_GivenPreferredProvider_WhenBuildInitialState_ThenDefaultToProviderDeletion() {
        let providers = [
            Self.makeProvider(id: "provider-a", name: "Provider A"),
            Self.makeProvider(id: "provider-b", name: "Provider B")
        ]

        let state = ResourceDeleteTargetSheetState.initial(
            preferredProvider: providers[1],
            providers: providers
        )

        XCTAssertEqual(state.selectedProviderID, "provider-b")
        XCTAssertFalse(state.deleteAll)
    }

    func testBDD_GivenGlobalEntry_WhenBuildInitialState_ThenDefaultToDeleteAllIncludingGlobalCache() {
        let providers = [
            Self.makeProvider(id: "provider-a", name: "Provider A")
        ]

        let state = ResourceDeleteTargetSheetState.initial(
            preferredProvider: nil,
            providers: providers
        )

        XCTAssertNil(state.selectedProviderID)
        XCTAssertTrue(state.deleteAll)
    }

    func testBDD_GivenNoPreferredProvider_WhenResolveProviderSelection_ThenFallbackToFirstProvider() {
        let providers = [
            Self.makeProvider(id: "provider-a", name: "Provider A"),
            Self.makeProvider(id: "provider-b", name: "Provider B")
        ]

        let selection = ResourceDeleteTargetSheetState.providerSelection(
            preferredProvider: nil,
            providers: providers
        )

        XCTAssertEqual(selection, "provider-a")
    }

    private static func makeProvider(id: String, name: String) -> Provider {
        Provider(
            id: id,
            name: name,
            defaultSkillsPath: "/tmp/\(id)/skills",
            workflowPath: "/tmp/\(id)/workflows",
            installMethod: .symlink,
            templateId: nil
        )
    }
}
