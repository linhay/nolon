import XCTest
import ProviderCatalog
import NolonResourceKit

final class ProviderPresentationSectionsTests: XCTestCase {
    func testBDD_GivenMixedProviders_WhenBuildingSections_ThenUsesStableSectionOrderAndPreservesInGroupOrder() {
        let providers = [
            Provider(
                id: "integrated-1",
                kind: .vendor,
                name: "Pi",
                defaultSkillsPath: "/tmp/pi/skills",
                workflowPath: "/tmp/pi/prompts",
                vendorCategory: .integrated,
                templateId: "pi"
            ),
            Provider(
                id: "original-1",
                kind: .vendor,
                name: "Codex",
                defaultSkillsPath: "/tmp/codex/skills",
                workflowPath: "/tmp/codex/prompts",
                vendorCategory: .original,
                templateId: "codex"
            ),
            Provider(
                id: "project-1",
                kind: .project,
                name: "Project",
                projectRootPath: "/tmp/project",
                defaultSkillsPath: "/tmp/project/.codex/skills",
                workflowPath: "/tmp/project/.codex/prompts"
            ),
            Provider(
                id: "integrated-2",
                kind: .vendor,
                name: "OpenCode",
                defaultSkillsPath: "/tmp/opencode/skills",
                workflowPath: "/tmp/opencode/commands",
                vendorCategory: .integrated,
                templateId: "opencode"
            )
        ]

        let sections = ProviderPresentationSections.providerSections(providers: providers)

        XCTAssertEqual(sections.map(\.id), [.originalVendors, .integratedVendors, .projects])
        XCTAssertEqual(sections[0].providers.map(\.id), ["original-1"])
        XCTAssertEqual(sections[1].providers.map(\.id), ["integrated-1", "integrated-2"])
        XCTAssertEqual(sections[2].providers.map(\.id), ["project-1"])
    }

    func testBDD_GivenTemplateCatalog_WhenBuildingTemplateSections_ThenPiAppearsUnderIntegratedVendors() {
        let sections = ProviderPresentationSections.templateSections()
        let integrated = sections.first { $0.id == .integratedVendors }

        XCTAssertNotNil(integrated)
        XCTAssertTrue(integrated?.templates.contains(.pi) == true)
        XCTAssertFalse(integrated?.templates.contains(.codex) == true)
    }

    func testBDD_GivenAccountTemplates_WhenBuildingAccountProviders_ThenExcludesPiAndKeepsGeminiAndAntigravity() {
        let providers = [
            Provider(
                id: "codex",
                kind: .vendor,
                name: "Codex",
                defaultSkillsPath: "/tmp/codex/skills",
                workflowPath: "/tmp/codex/prompts",
                vendorCategory: .original,
                templateId: ProviderTemplate.codex.rawValue
            ),
            Provider(
                id: "gemini",
                kind: .vendor,
                name: "Gemini",
                defaultSkillsPath: "/tmp/gemini/skills",
                workflowPath: "/tmp/gemini/workflows",
                vendorCategory: .original,
                templateId: ProviderTemplate.gemini.rawValue
            ),
            Provider(
                id: "antigravity",
                kind: .vendor,
                name: "Antigravity",
                defaultSkillsPath: "/tmp/antigravity/skills",
                workflowPath: "/tmp/antigravity/workflows",
                vendorCategory: .integrated,
                templateId: ProviderTemplate.antigravity.rawValue
            ),
            Provider(
                id: "pi",
                kind: .vendor,
                name: "Pi",
                defaultSkillsPath: "/tmp/pi/skills",
                workflowPath: "/tmp/pi/prompts",
                vendorCategory: .integrated,
                templateId: ProviderTemplate.pi.rawValue
            )
        ]

        let sections = ProviderPresentationSections.accountProviders(from: providers)

        XCTAssertEqual(sections.count, 2)
        XCTAssertEqual(sections.first?.id, .originalVendors)
        XCTAssertEqual(sections.first?.providers.map(\.id), ["codex", "gemini"])
        XCTAssertEqual(sections.last?.id, .integratedVendors)
        XCTAssertEqual(sections.last?.providers.map(\.id), ["antigravity"])
        XCTAssertFalse(sections.flatMap(\.providers).contains(where: { $0.id == "pi" }))
    }
}
