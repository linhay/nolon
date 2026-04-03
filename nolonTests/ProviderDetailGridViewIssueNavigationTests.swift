import XCTest
import NolonResourceKit
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
            skillsLinkEnabled: true
        )
        XCTAssertFalse(visible)
    }

    func testBDD_GivenMcpTabAndSkillsLinkEnabled_WhenCheckingQuickInstallVisibility_ThenReturnsTrue() {
        let visible = ProviderDetailGridView.shouldShowQuickInstallButton(
            selectedTab: .mcp,
            isCurrentTabLinkedToCodex: false,
            skillsLinkEnabled: true
        )
        XCTAssertTrue(visible)
    }

    func testBDD_GivenSkillsTabAndSkillsLinkDisabled_WhenCheckingQuickInstallVisibility_ThenReturnsTrue() {
        let visible = ProviderDetailGridView.shouldShowQuickInstallButton(
            selectedTab: .skills,
            isCurrentTabLinkedToCodex: false,
            skillsLinkEnabled: false
        )
        XCTAssertTrue(visible)
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
