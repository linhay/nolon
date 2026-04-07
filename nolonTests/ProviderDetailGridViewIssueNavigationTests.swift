import XCTest
import NolonResourceKit
import ProviderCatalog
@testable import nolon

final class ProviderDetailGridViewIssueNavigationTests: XCTestCase {
    func testBDD_GivenGroupedSkills_WhenFindingFirstOrphanedScrollTarget_ThenReturnsFirstVisibleOrphanedSkillID() {
        let installedA = makeSkill(id: "a-installed", name: "A", sourcePath: "/path-a", state: .installed)
        let orphanedA = makeSkill(id: "a-orphaned", name: "B", sourcePath: "/path-a", state: .orphaned)
        let orphanedB = makeSkill(id: "b-orphaned", name: "C", sourcePath: "/path-b", state: .orphaned)

        let groupedSkills: [(path: String, skills: [Skill])] = [
            (path: "/path-a", skills: [installedA, orphanedA]),
            (path: "/path-b", skills: [orphanedB])
        ]

        let target = ProviderDetailGridView.firstOrphanedSkillScrollID(from: groupedSkills)
        XCTAssertEqual(target, orphanedA.uniqueId)
    }

    func testBDD_GivenGroupedSkillsWithoutOrphaned_WhenFindingScrollTarget_ThenReturnsNil() {
        let installedA = makeSkill(id: "a-installed", name: "A", sourcePath: "/path-a", state: .installed)
        let brokenA = makeSkill(id: "a-broken", name: "B", sourcePath: "/path-a", state: .broken)

        let groupedSkills: [(path: String, skills: [Skill])] = [
            (path: "/path-a", skills: [installedA, brokenA])
        ]

        let target = ProviderDetailGridView.firstOrphanedSkillScrollID(from: groupedSkills)
        XCTAssertNil(target)
    }

    func testBDD_GivenSkillsTabAndSkillsLinkEnabled_WhenCheckingPlaceholderVisibility_ThenReturnsTrue() {
        let result = ProviderDetailGridView.shouldShowNolonSkillsLinkedPlaceholder(
            skillsLinkEnabled: true,
            selectedTab: .skills
        )
        XCTAssertTrue(result)
    }

    func testBDD_GivenMcpTabAndSkillsLinkEnabled_WhenCheckingPlaceholderVisibility_ThenReturnsFalse() {
        let result = ProviderDetailGridView.shouldShowNolonSkillsLinkedPlaceholder(
            skillsLinkEnabled: true,
            selectedTab: .mcp
        )
        XCTAssertFalse(result)
    }

    func testBDD_GivenNonSkillsTabOrLinkDisabled_WhenCheckingPlaceholderVisibility_ThenReturnsFalse() {
        XCTAssertFalse(
            ProviderDetailGridView.shouldShowNolonSkillsLinkedPlaceholder(
                skillsLinkEnabled: false,
                selectedTab: .skills
            )
        )
        XCTAssertFalse(
            ProviderDetailGridView.shouldShowNolonSkillsLinkedPlaceholder(
                skillsLinkEnabled: true,
                selectedTab: .workflows
            )
        )
        XCTAssertFalse(
            ProviderDetailGridView.shouldShowNolonSkillsLinkedPlaceholder(
                skillsLinkEnabled: true,
                selectedTab: nil
            )
        )
    }

    func testBDD_GivenSkillsTabAndSkillsLinkEnabled_WhenCheckingQuickInstallVisibility_ThenReturnsFalse() {
        let visible = ProviderDetailGridView.shouldShowQuickInstallButton(
            selectedTab: .skills,
            isCurrentTabLinkedToCodex: false,
            skillsLinkEnabled: true,
            mcpLinkEnabled: false,
            agentsLinkEnabled: false
        )
        XCTAssertFalse(visible)
    }

    func testBDD_GivenMcpTabAndMcpLinkDisabled_WhenCheckingQuickInstallVisibility_ThenReturnsTrue() {
        let visible = ProviderDetailGridView.shouldShowQuickInstallButton(
            selectedTab: .mcp,
            isCurrentTabLinkedToCodex: false,
            skillsLinkEnabled: true,
            mcpLinkEnabled: false,
            agentsLinkEnabled: false
        )
        XCTAssertTrue(visible)
    }

    func testBDD_GivenMcpTabAndMcpLinkEnabled_WhenCheckingQuickInstallVisibility_ThenReturnsFalse() {
        let visible = ProviderDetailGridView.shouldShowQuickInstallButton(
            selectedTab: .mcp,
            isCurrentTabLinkedToCodex: false,
            skillsLinkEnabled: false,
            mcpLinkEnabled: true,
            agentsLinkEnabled: false
        )
        XCTAssertFalse(visible)
    }

    func testBDD_GivenSkillsTabAndSkillsLinkDisabled_WhenCheckingQuickInstallVisibility_ThenReturnsTrue() {
        let visible = ProviderDetailGridView.shouldShowQuickInstallButton(
            selectedTab: .skills,
            isCurrentTabLinkedToCodex: false,
            skillsLinkEnabled: false,
            mcpLinkEnabled: false,
            agentsLinkEnabled: false
        )
        XCTAssertTrue(visible)
    }

    func testBDD_GivenAgentsTabAndAgentsLinkEnabled_WhenCheckingQuickInstallVisibility_ThenReturnsFalse() {
        let visible = ProviderDetailGridView.shouldShowQuickInstallButton(
            selectedTab: .agents,
            isCurrentTabLinkedToCodex: false,
            skillsLinkEnabled: false,
            mcpLinkEnabled: false,
            agentsLinkEnabled: true
        )
        XCTAssertFalse(visible)
    }

    func testBDD_GivenAgentsTabAndAgentsLinkEnabled_WhenCheckingPlaceholderVisibility_ThenReturnsTrue() {
        let visible = ProviderDetailGridView.shouldShowNolonAgentsLinkedPlaceholder(
            agentsLinkEnabled: true,
            selectedTab: .agents
        )
        XCTAssertTrue(visible)
    }

    func testBDD_GivenMcpTabAndMcpLinkEnabled_WhenCheckingMcpPlaceholderVisibility_ThenReturnsTrue() {
        let visible = ProviderDetailGridView.shouldShowNolonMcpLinkedPlaceholder(
            mcpLinkEnabled: true,
            selectedTab: .mcp
        )
        XCTAssertTrue(visible)
    }

    func testBDD_GivenNonMcpTabOrLinkDisabled_WhenCheckingMcpPlaceholderVisibility_ThenReturnsFalse() {
        XCTAssertFalse(
            ProviderDetailGridView.shouldShowNolonMcpLinkedPlaceholder(
                mcpLinkEnabled: false,
                selectedTab: .mcp
            )
        )
        XCTAssertFalse(
            ProviderDetailGridView.shouldShowNolonMcpLinkedPlaceholder(
                mcpLinkEnabled: true,
                selectedTab: .skills
            )
        )
    }

    func testBDD_GivenSupportedAgentsProviders_WhenCheckingAgentsLinkSupport_ThenReturnsTrueOnlyForSupportedVendors() throws {
        let codex = try XCTUnwrap(ProviderTemplate(rawValue: "codex")).createProvider()
        let openCode = try XCTUnwrap(ProviderTemplate(rawValue: "opencode")).createProvider()
        let copilot = try XCTUnwrap(ProviderTemplate(rawValue: "copilot")).createProvider()
        let claude = try XCTUnwrap(ProviderTemplate(rawValue: "claudeCode")).createProvider()
        let gemini = try XCTUnwrap(ProviderTemplate(rawValue: "gemini")).createProvider()

        XCTAssertTrue(ProviderDetailGridView.supportsAgentsLink(codex))
        XCTAssertTrue(ProviderDetailGridView.supportsAgentsLink(openCode))
        XCTAssertTrue(ProviderDetailGridView.supportsAgentsLink(copilot))
        XCTAssertFalse(ProviderDetailGridView.supportsAgentsLink(claude))
        XCTAssertFalse(ProviderDetailGridView.supportsAgentsLink(gemini))
        XCTAssertFalse(ProviderDetailGridView.supportsAgentsLink(nil))
    }

    func testBDD_GivenAgentsTabAndSupportedProvider_WhenCheckingAgentsToolbarVisibility_ThenReturnsTrueOnlyForSupportedVendors() throws {
        let codex = try XCTUnwrap(ProviderTemplate(rawValue: "codex")).createProvider()
        let openCode = try XCTUnwrap(ProviderTemplate(rawValue: "opencode")).createProvider()
        let claude = try XCTUnwrap(ProviderTemplate(rawValue: "claudeCode")).createProvider()

        XCTAssertTrue(
            ProviderDetailGridView.shouldShowAgentsLinkToolbar(
                selectedTab: .agents,
                provider: codex
            )
        )
        XCTAssertTrue(
            ProviderDetailGridView.shouldShowAgentsLinkToolbar(
                selectedTab: .agents,
                provider: openCode
            )
        )
        XCTAssertFalse(
            ProviderDetailGridView.shouldShowAgentsLinkToolbar(
                selectedTab: .agents,
                provider: claude
            )
        )
        XCTAssertFalse(
            ProviderDetailGridView.shouldShowAgentsLinkToolbar(
                selectedTab: .skills,
                provider: codex
            )
        )
        XCTAssertFalse(
            ProviderDetailGridView.shouldShowAgentsLinkToolbar(
                selectedTab: .agents,
                provider: nil
            )
        )
    }

    func testBDD_GivenDifferentProviders_WhenResolvingAgentsLinkPath_ThenReturnsVendorNativeTarget() throws {
        let codex = try XCTUnwrap(ProviderTemplate(rawValue: "codex")).createProvider()
        let openCode = try XCTUnwrap(ProviderTemplate(rawValue: "opencode")).createProvider()
        let copilot = try XCTUnwrap(ProviderTemplate(rawValue: "copilot")).createProvider()
        let claude = try XCTUnwrap(ProviderTemplate(rawValue: "claudeCode")).createProvider()

        XCTAssertEqual(
            ProviderDetailGridView.agentsLinkProviderPath(for: codex, fallbackPath: "/tmp/nolon/AGENTS.md"),
            codex.codexAgentsFileURL.path
        )
        XCTAssertEqual(
            ProviderDetailGridView.agentsLinkProviderPath(for: openCode, fallbackPath: "/tmp/nolon/AGENTS.md"),
            URL(fileURLWithPath: openCode.defaultSkillsPath)
                .deletingLastPathComponent()
                .appendingPathComponent("AGENTS.md")
                .path
        )
        XCTAssertEqual(
            ProviderDetailGridView.agentsLinkProviderPath(for: copilot, fallbackPath: "/tmp/nolon/AGENTS.md"),
            URL(fileURLWithPath: copilot.defaultSkillsPath)
                .deletingLastPathComponent()
                .appendingPathComponent("AGENTS.md")
                .path
        )
        XCTAssertEqual(
            ProviderDetailGridView.agentsLinkProviderPath(for: claude, fallbackPath: "/tmp/nolon/AGENTS.md"),
            "/tmp/nolon/AGENTS.md"
        )
        XCTAssertEqual(
            ProviderDetailGridView.agentsLinkProviderPath(for: nil, fallbackPath: "/tmp/nolon/AGENTS.md"),
            "/tmp/nolon/AGENTS.md"
        )
    }

    func testBDD_GivenAgentsScreenCopy_WhenResolvingDescriptions_ThenUsesProviderNeutralEmptyStateAndAgentSpecificNoResults() {
        XCTAssertEqual(
            ProviderDetailGridView.agentsEmptyDescription(),
            NSLocalizedString(
                "agents.empty_desc",
                value: "No AGENTS.md files found for this provider",
                comment: "No agents docs"
            )
        )
        XCTAssertEqual(
            ProviderDetailGridView.agentsNoResultsDescription(),
            NSLocalizedString(
                "agents.search.no_results_desc",
                value: "No matching AGENTS.md files found",
                comment: "No agent docs search results description"
            )
        )
    }

    private func makeSkill(
        id: String,
        name: String,
        sourcePath: String,
        state: SkillInstallationState
    ) -> Skill {
        var skill = Skill(
            id: id,
            name: name,
            description: "\(name)-desc",
            version: "1.0.0",
            globalPath: "/tmp/\(id)",
            content: "content",
            sourcePath: sourcePath
        )
        skill.installationState = state
        return skill
    }
}
