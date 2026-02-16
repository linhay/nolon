import XCTest
import ProviderCatalog
@testable import nolon

@MainActor
final class RemoteInstallOrchestratorTests: XCTestCase {
    var fixture: TestFixture!
    var repository: SkillRepository!
    var installer: SkillInstaller!

    override func setUpWithError() throws {
        fixture = try TestFixture()
        repository = SkillRepository(nolonManager: fixture.nolonManager)
        installer = SkillInstaller(
            repository: repository,
            settings: fixture.providerSettings,
            nolonManager: fixture.nolonManager
        )
    }

    override func tearDownWithError() throws {
        fixture.cleanup()
    }

    func testBDD_GivenLocalSkill_WhenInstallSkill_ThenSkipRemoteDownload() async throws {
        let localSkillURL = try fixture.createSampleSkill(id: "local-skill", name: "Local Skill")
        let provider = fixture.createProvider(name: "Cursor", method: .symlink)
        var downloadCallCount = 0
        let orchestrator = RemoteInstallOrchestrator(
            downloadRemoteResource: { _, _, _, _ in
                downloadCallCount += 1
                return URL(fileURLWithPath: "/tmp/should-not-be-called.zip")
            }
        )
        let skill = RemoteSkill(
            slug: "local-skill",
            displayName: "Local Skill",
            summary: nil,
            latestVersion: nil,
            updatedAt: Date(),
            downloads: nil,
            stars: nil,
            localPath: localSkillURL.path
        )

        try await orchestrator.installSkill(
            skill,
            to: provider,
            installer: installer,
            remoteBaseURL: "https://clawdhub.com"
        )

        XCTAssertEqual(downloadCallCount, 0)
        XCTAssertTrue(fixture.fileManager.fileExists(atPath: "\(provider.defaultSkillsPath)/local-skill"))
    }

    func testBDD_GivenRemoteWorkflow_WhenInstallWorkflow_ThenDownloadAndInstall() async throws {
        let provider = fixture.createProvider(name: "Cursor", method: .copy)
        let remoteFile = fixture.tempRoot
            .appendingPathComponent("downloads", isDirectory: true)
            .appendingPathComponent("remote-review.md")
        try fixture.fileManager.createDirectory(at: remoteFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
        ---
        name: review
        description: review flow
        ---
        # Review
        """.write(to: remoteFile, atomically: true, encoding: .utf8)

        var downloadCallCount = 0
        let orchestrator = RemoteInstallOrchestrator(
            downloadRemoteResource: { kind, slug, _, _ in
                downloadCallCount += 1
                XCTAssertEqual(kind, .workflow)
                XCTAssertEqual(slug, "remote-review")
                return remoteFile
            }
        )
        let workflow = RemoteWorkflow(
            slug: "remote-review",
            displayName: "Remote Review",
            summary: nil,
            latestVersion: "1.0.0",
            updatedAt: Date(),
            downloads: nil,
            stars: nil,
            usages: nil,
            localPath: nil
        )

        try await orchestrator.installWorkflow(
            workflow,
            to: provider,
            installer: installer,
            remoteBaseURL: "https://clawdhub.com"
        )

        XCTAssertEqual(downloadCallCount, 1)
        XCTAssertTrue(fixture.fileManager.fileExists(atPath: "\(provider.workflowPath)/remote-review.md"))
    }
}
