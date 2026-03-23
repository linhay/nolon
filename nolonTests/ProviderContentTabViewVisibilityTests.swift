import XCTest
@testable import nolon
import ProviderCatalog

final class ProviderContentTabViewVisibilityTests: XCTestCase {
    func testBDD_GivenNoProvider_WhenResolvingSidebarVisibility_ThenReturnsFalse() {
        XCTAssertFalse(ProviderContentTabView.shouldShowSidebarComponent(provider: nil))
    }

    func testBDD_GivenProvider_WhenResolvingSidebarVisibility_ThenReturnsTrue() {
        let provider = Provider(
            id: "codex",
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: "/tmp/codex/skills",
            workflowPath: "/tmp/codex/workflows",
            iconName: "terminal",
            installMethod: .symlink,
            vendorCategory: .original
        )

        XCTAssertTrue(ProviderContentTabView.shouldShowSidebarComponent(provider: provider))
    }
}
