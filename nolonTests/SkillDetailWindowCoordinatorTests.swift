import XCTest
import NolonResourceKit
import ProviderCatalog
@testable import nolon

@MainActor
final class SkillDetailWindowCoordinatorTests: XCTestCase {
    func testBDD_GivenLocalSkill_WhenPresentingInCoordinator_ThenStoresLocalPayload() {
        let fixture = try! TestFixture()
        defer { fixture.cleanup() }

        let skill = Skill(
            id: "sectionui",
            name: "SectionUI",
            description: "desc",
            version: "1.0.0",
            globalPath: "/tmp/sectionui",
            content: "content",
            referenceCount: 0,
            scriptCount: 0
        )
        let provider = fixture.createProvider(name: "Codex", method: .symlink)

        SkillDetailWindowCoordinator.shared.presentLocal(
            skill: skill,
            provider: provider,
            settings: fixture.providerSettings
        )

        guard case let .local(payload) = SkillDetailWindowCoordinator.shared.payload else {
            return XCTFail("Expected local payload")
        }
        XCTAssertEqual(payload.skill.id, "sectionui")
        XCTAssertEqual(payload.provider?.id, provider.id)
    }

    func testBDD_GivenRemoteSkill_WhenPresentingInCoordinator_ThenStoresRemotePayload() {
        let fixture = try! TestFixture()
        defer { fixture.cleanup() }

        let remoteSkill = RemoteSkill(
            slug: "sectionui",
            displayName: "SectionUI",
            summary: "summary",
            latestVersion: "1.0.0",
            updatedAt: nil,
            downloads: nil,
            stars: nil,
            localPath: nil
        )
        let provider = fixture.createProvider(name: "Codex", method: .symlink)

        SkillDetailWindowCoordinator.shared.presentRemote(
            skill: remoteSkill,
            providers: [provider],
            targetProvider: provider,
            onInstall: { _ in }
        )

        guard case let .remote(payload) = SkillDetailWindowCoordinator.shared.payload else {
            return XCTFail("Expected remote payload")
        }
        XCTAssertEqual(payload.skill.slug, "sectionui")
        XCTAssertEqual(payload.providers.count, 1)
        XCTAssertEqual(payload.targetProvider?.id, provider.id)
    }
}
