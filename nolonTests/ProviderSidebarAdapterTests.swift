import XCTest
@testable import nolon
import ProviderCatalog
import NolonUIFoundation

final class ProviderSidebarAdapterTests: XCTestCase {
    func testSections_GroupsOriginalIntegratedAndProjects() {
        let providers: [Provider] = [
            Provider(
                id: "codex",
                kind: .vendor,
                name: "Codex",
                defaultSkillsPath: "/tmp/codex",
                workflowPath: "/tmp/codex/workflows",
                iconName: "terminal",
                installMethod: .symlink,
                vendorCategory: .original
            ),
            Provider(
                id: "claude",
                kind: .vendor,
                name: "Claude",
                defaultSkillsPath: "/tmp/claude",
                workflowPath: "/tmp/claude/workflows",
                iconName: "message",
                installMethod: .symlink,
                vendorCategory: .integrated
            ),
            Provider(
                id: "project",
                kind: .project,
                name: "My Project",
                projectRootPath: "/tmp/project",
                defaultSkillsPath: "/tmp/project/.codex/skills",
                workflowPath: "/tmp/project/.codex/workflows",
                iconName: "folder",
                installMethod: .symlink
            )
        ]

        let sections = ProviderSidebarAdapter.sections(from: providers)

        XCTAssertEqual(sections.map(\.id), [.originalVendors, .integratedVendors, .projects])
        XCTAssertEqual(sections[0].items.map(\.id), ["codex"])
        XCTAssertEqual(sections[1].items.map(\.id), ["claude"])
        XCTAssertEqual(sections[2].items.map(\.id), ["project"])
    }

    func testSelectionKeys_MatchLegacyStorageKeys() {
        XCTAssertEqual(ProviderSidebarAdapter.providerSelectionKey("abc"), MainSidebarSelection.provider("abc").storageKey)
        XCTAssertEqual(ProviderSidebarAdapter.accountsSelectionKey, MainSidebarSelection.accounts.storageKey)
        XCTAssertEqual(ProviderSidebarAdapter.pluginManagementSelectionKey, MainSidebarSelection.pluginManagement.storageKey)
    }
}
