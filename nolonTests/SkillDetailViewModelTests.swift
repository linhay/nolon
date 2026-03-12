import XCTest
import NolonResourceKit
import ProviderCatalog
@testable import nolon

@MainActor
final class SkillDetailViewModelTests: XCTestCase {
    func testBDD_GivenLocalSkill_WhenBuildingDetailPresentation_ThenUsesLocalFileBrowserLayout() async throws {
        let fixture = try TestFixture()
        defer { fixture.cleanup() }

        let skillURL = try fixture.createSampleSkill(id: "sectionui", name: "SectionUI")
        let skill = Skill(
            id: "sectionui",
            name: "SectionUI",
            description: "A sample skill for testing",
            version: "1.0.0",
            globalPath: skillURL.path,
            content: try String(contentsOf: skillURL.appendingPathComponent("SKILL.md")),
            referenceCount: 1,
            scriptCount: 1
        )

        let viewModel = SkillDetailViewModel(skill: skill, settings: fixture.providerSettings)
        await viewModel.loadData(checkProviders: [], currentProvider: nil)

        XCTAssertEqual(viewModel.detailMode, .local)
        XCTAssertEqual(viewModel.contentMode, .fileBrowser)
        XCTAssertTrue(viewModel.showsFileNavigator)
        XCTAssertTrue(viewModel.showsRevealInFinder)
        XCTAssertEqual(viewModel.contentTitle, "SKILL.md")
    }

    func testBDD_GivenRemoteSkillWithInstalledLocalPath_WhenBuildingDetailPresentation_ThenUsesUnifiedInstalledFileBrowserLayout() async throws {
        let fixture = try TestFixture()
        defer { fixture.cleanup() }

        let localPath = try fixture.createSampleSkill(id: "sectionui", name: "SectionUI")
        let remoteSkill = RemoteSkill(
            slug: "sectionui",
            displayName: "SectionUI",
            summary: "Remote summary",
            latestVersion: "1.0.0",
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            downloads: 42,
            stars: 7,
            localPath: localPath.path
        )

        let viewModel = SkillDetailViewModel(
            remoteSkill: remoteSkill,
            onInstall: { _, _ in }
        )
        await viewModel.loadData(checkProviders: [], currentProvider: nil)

        XCTAssertEqual(viewModel.detailMode, .remoteInstalled)
        XCTAssertEqual(viewModel.contentMode, .fileBrowser)
        XCTAssertTrue(viewModel.showsFileNavigator)
        XCTAssertTrue(viewModel.showsRevealInFinder)
        XCTAssertEqual(viewModel.contentTitle, "SKILL.md")
    }

    func testBDD_GivenRemoteSkillWithoutLocalInstall_WhenBuildingDetailPresentation_ThenUsesUnifiedRemoteOverviewLayout() async {
        let fixture = try! TestFixture()
        defer { fixture.cleanup() }

        let remoteSkill = RemoteSkill(
            slug: "sectionui",
            displayName: "SectionUI",
            summary: "Remote summary",
            latestVersion: "1.0.0",
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            downloads: 42,
            stars: 7,
            localPath: nil
        )

        let viewModel = SkillDetailViewModel(
            remoteSkill: remoteSkill,
            onInstall: { _, _ in }
        )
        await viewModel.loadData(checkProviders: [], currentProvider: nil)

        XCTAssertEqual(viewModel.detailMode, .remoteCatalog)
        XCTAssertEqual(viewModel.contentMode, .remoteOverview)
        XCTAssertFalse(viewModel.showsFileNavigator)
        XCTAssertFalse(viewModel.showsRevealInFinder)
        XCTAssertEqual(viewModel.contentTitle, "Overview")
    }

    func testBDD_GivenRemoteInstalledSkill_WhenCheckingProviderInstallationStates_ThenResolvesPerProviderFromSlug() async throws {
        let fixture = try TestFixture()
        defer { fixture.cleanup() }

        let localPath = try fixture.createSampleSkill(id: "sectionui", name: "SectionUI")
        let installedProvider = fixture.createProvider(name: "Codex", method: .symlink)
        let uninstalledProvider = fixture.createProvider(name: "Claude", method: .copy)
        fixture.providerSettings.providers = [installedProvider, uninstalledProvider]

        let installedSkillPath = URL(fileURLWithPath: installedProvider.defaultSkillsPath)
            .appendingPathComponent("sectionui")
        try FileManager.default.createDirectory(at: installedSkillPath, withIntermediateDirectories: true)

        let remoteSkill = RemoteSkill(
            slug: "sectionui",
            displayName: "SectionUI",
            summary: "Remote summary",
            latestVersion: "1.0.0",
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            downloads: 42,
            stars: 7,
            localPath: localPath.path
        )

        let viewModel = SkillDetailViewModel(
            remoteSkill: remoteSkill,
            onInstall: { _, _ in }
        )
        await viewModel.loadData(checkProviders: fixture.providerSettings.providers, currentProvider: nil)

        XCTAssertEqual(viewModel.providerInstallationStates[installedProvider.id], true)
        XCTAssertEqual(viewModel.providerInstallationStates[uninstalledProvider.id], false)
    }
}
