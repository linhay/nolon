import XCTest
import ProviderCatalog
import NolonUIFoundation
@testable import nolon

final class ProviderSidebarAdapterTests: XCTestCase {
    func testSections_GroupsOriginalIntegratedAndProjects() {
        let providers: [SidebarProviderInput] = [
            .init(
                id: "codex",
                kind: .vendor,
                vendorCategory: .original,
                name: "Codex",
                subtitle: "/tmp/codex",
                iconName: "terminal",
                hasDocumentation: true
            ),
            .init(
                id: "claude",
                kind: .vendor,
                vendorCategory: .integrated,
                name: "Claude",
                subtitle: "/tmp/claude",
                iconName: "message",
                hasDocumentation: true
            ),
            .init(
                id: "project",
                kind: .project,
                vendorCategory: nil,
                name: "My Project",
                subtitle: "/tmp/project",
                iconName: "folder",
                hasDocumentation: false
            )
        ]

        let sections = SidebarSectionBuilder.buildSections(providers: providers)

        XCTAssertEqual(sections.map(\.id), [.originalVendors, .integratedVendors, .projects])
        XCTAssertEqual(sections[0].items.map(\.id), ["codex"])
        XCTAssertEqual(sections[1].items.map(\.id), ["claude"])
        XCTAssertEqual(sections[2].items.map(\.id), ["project"])
    }

    func testSelectionKeys_MatchLegacyStorageKeys() {
        XCTAssertEqual(SidebarSelectionKey.provider("abc").rawValue, MainSidebarSelection.provider("abc").storageKey)
        XCTAssertEqual(SidebarSelectionKey.accounts.rawValue, MainSidebarSelection.accounts.storageKey)
        XCTAssertEqual(SidebarSelectionKey.pluginManagement.rawValue, MainSidebarSelection.pluginManagement.storageKey)
    }
}
