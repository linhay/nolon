import XCTest
import ProviderCatalog
import NolonResourceKit
@testable import nolon

@MainActor
final class ProviderDetailGridViewModelSkillsTests: XCTestCase {
    private var fixture: TestFixture!

    override func setUpWithError() throws {
        fixture = try TestFixture()
    }

    override func tearDownWithError() throws {
        fixture.cleanup()
        fixture = nil
    }

    func testBDD_GivenMissingDefaultSkillsPathAndExistingAdditionalSkills_WhenLoadingData_ThenDisplaysAdditionalSkills() async throws {
        let providerRoot = fixture.tempRoot.appendingPathComponent("provider")
        let additionalSkills = providerRoot.appendingPathComponent("extra-skills")
        try fixture.fileManager.createDirectory(at: additionalSkills, withIntermediateDirectories: true)

        let orphanedSkill = additionalSkills.appendingPathComponent("displayable-skill")
        try fixture.fileManager.createDirectory(at: orphanedSkill, withIntermediateDirectories: true)
        try """
        ---
        name: Displayable Skill
        description: still visible from additional path
        version: 1.0.0
        ---
        """.write(
            to: orphanedSkill.appendingPathComponent("SKILL.md"),
            atomically: true,
            encoding: .utf8
        )

        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: providerRoot.appendingPathComponent("missing-skills").path,
            workflowPath: providerRoot.appendingPathComponent("prompts").path,
            installMethod: .symlink,
            templateId: ProviderTemplate.codex.rawValue,
            additionalSkillsPaths: [additionalSkills.path]
        )
        let viewModel = ProviderDetailGridViewModel(provider: provider, settings: fixture.providerSettings)

        await viewModel.loadData()

        XCTAssertEqual(viewModel.installedSkills.map { $0.id }, ["displayable-skill"])
        XCTAssertEqual(viewModel.installedSkills.first?.installationState, .orphaned)
        XCTAssertNil(viewModel.skillsErrorMessage)
    }
}
