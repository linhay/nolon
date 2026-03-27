import XCTest
import NolonResourceKit
import ProviderCatalog
import NolonUIFoundation
@testable import nolon

@MainActor
final class ResourceCenterWindowCoordinatorTests: XCTestCase {
    func testBDD_GivenPayload_WhenPresentingResourceCenterWindow_ThenStoresPayload() {
        let fixture = try! TestFixture()
        defer { fixture.cleanup() }
        let provider = fixture.createProvider(name: "Codex", method: .symlink)
        let repository = SkillRepository(nolonManager: fixture.nolonManager)

        ResourceCenterWindowCoordinator.shared.present(
            payload: .init(
                settings: fixture.providerSettings,
                repository: repository,
                targetProvider: provider,
                selectedTab: .skills,
                onInstall: { _, _ in },
                onInstallWorkflow: nil,
                onInstallMCP: nil,
                onRegisterDeleteRequest: nil,
                onMakeDeleteRequestExecutor: nil,
                onClose: nil
            )
        )

        guard let payload = ResourceCenterWindowCoordinator.shared.payload else {
            return XCTFail("Expected payload")
        }
        XCTAssertEqual(payload.targetProvider?.id, provider.id)
        XCTAssertEqual(payload.selectedTab, .skills)
    }
}
