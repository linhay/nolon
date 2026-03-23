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
