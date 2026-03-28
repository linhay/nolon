import XCTest
@testable import NolonUIFoundation

final class SidebarSectionBuilderTests: XCTestCase {
    func testBuildSections_GroupsProvidersByCategoryAndProject() {
        let providers: [SidebarProviderInput] = [
            .init(id: "codex", kind: .vendor, vendorCategory: .original, name: "Codex", subtitle: "/a", iconName: "terminal", hasDocumentation: true),
            .init(id: "claude", kind: .vendor, vendorCategory: .integrated, name: "Claude", subtitle: "/b", iconName: "message", hasDocumentation: true),
            .init(id: "proj", kind: .project, vendorCategory: nil, name: "Project", subtitle: "/c", iconName: "folder", hasDocumentation: false)
        ]

        let sections = SidebarSectionBuilder.buildSections(providers: providers)

        XCTAssertEqual(sections.map(\.id), [.originalVendors, .integratedVendors, .projects])
        XCTAssertEqual(sections[0].items.map(\.id), ["codex"])
        XCTAssertEqual(sections[1].items.map(\.id), ["claude"])
        XCTAssertEqual(sections[2].items.map(\.id), ["proj"])
    }

    func testSidebarDefaultTools_ContainsNolonEntry() {
        XCTAssertTrue(SidebarToolItem.default.contains { $0.id == .nolon })
    }
}
