import XCTest
import NolonResourceKit
@testable import nolon

@MainActor
final class RemoteRepositorySidebarViewModelTests: XCTestCase {
    func testHandleDirectoryCandidatesFound_PreselectsExistingSkillsPaths() throws {
        let fixture = try TestFixture()
        defer { fixture.cleanup() }

        let existing = RemoteRepository(
            name: "Repo",
            templateType: .git,
            gitURL: "https://github.com/acme/repo.git",
            skillsPaths: [".", "skills"]
        )
        fixture.providerSettings.addRemoteRepository(existing)

        let viewModel = RemoteRepositorySidebarViewModel()
        let candidates: [GitRepository.SkillsDirectoryCandidate] = [
            .init(path: ".", skillCount: 1, skillNames: ["root"]),
            .init(path: "skills", skillCount: 2, skillNames: ["a", "b"]),
            .init(path: "other", skillCount: 1, skillNames: ["c"])
        ]

        viewModel.handleDirectoryCandidatesFound(repo: existing, candidates: candidates)

        XCTAssertEqual(viewModel.selectedDirectoryIndices, Set([0, 1]))
    }

    func testConfirmDirectorySelection_UpdatesExistingRepositoryInsteadOfAppending() throws {
        let fixture = try TestFixture()
        defer { fixture.cleanup() }

        var existing = RemoteRepository(
            name: "Repo",
            templateType: .git,
            gitURL: "https://github.com/acme/repo.git",
            skillsPaths: ["skills"]
        )
        fixture.providerSettings.addRemoteRepository(existing)
        let initialCount = fixture.providerSettings.remoteRepositories.count

        let viewModel = RemoteRepositorySidebarViewModel()
        let candidates: [GitRepository.SkillsDirectoryCandidate] = [
            .init(path: ".", skillCount: 1, skillNames: ["root"]),
            .init(path: "skills", skillCount: 2, skillNames: ["a", "b"])
        ]
        viewModel.handleDirectoryCandidatesFound(repo: existing, candidates: candidates)
        viewModel.selectedDirectoryIndices = [0]

        viewModel.confirmDirectorySelection(settings: fixture.providerSettings)

        XCTAssertEqual(fixture.providerSettings.remoteRepositories.count, initialCount)
        guard let updated = fixture.providerSettings.remoteRepositories.first(where: { $0.id == existing.id }) else {
            XCTFail("Expected updated repository by id")
            return
        }
        XCTAssertEqual(updated.skillsPaths, ["."])

        existing.skillsPaths = ["."]
        XCTAssertEqual(updated, existing)
    }

    func testShouldPresentAddRepositorySheet_WithGitURLAndIdleState_ReturnsTrue() {
        let viewModel = RemoteRepositorySidebarViewModel()

        let shouldPresent = viewModel.shouldPresentAddRepositorySheet(
            for: "https://github.com/acme/repo"
        )

        XCTAssertTrue(shouldPresent)
    }

    func testShouldPresentAddRepositorySheet_WithClawhubURL_ReturnsFalse() {
        let viewModel = RemoteRepositorySidebarViewModel()

        let shouldPresent = viewModel.shouldPresentAddRepositorySheet(
            for: "https://clawhub.ai/steipete/gemini"
        )

        XCTAssertFalse(shouldPresent)
    }

    func testShouldPresentAddRepositorySheet_WhenSheetAlreadyPresented_ReturnsFalse() {
        let viewModel = RemoteRepositorySidebarViewModel()
        viewModel.showingAddRepository = true

        let shouldPresent = viewModel.shouldPresentAddRepositorySheet(
            for: "https://github.com/acme/repo"
        )

        XCTAssertFalse(shouldPresent)
    }

    func testRevealTargets_GivenGitRelativeSkillsPath_ResolvesUnderClonePath() throws {
        let fixture = try TestFixture()
        defer { fixture.cleanup() }

        let cloneRoot = fixture.tempRoot.appendingPathComponent("git-clone", isDirectory: true)
        let skillsDir = cloneRoot.appendingPathComponent("skills", isDirectory: true)
        try fixture.fileManager.createDirectory(at: skillsDir, withIntermediateDirectories: true)

        let repo = RemoteRepository(
            name: "Repo",
            templateType: .git,
            gitURL: "https://github.com/acme/repo.git",
            skillsPaths: ["skills"]
        )

        let viewModel = RemoteRepositorySidebarViewModel()
        let urls = viewModel.revealTargets(for: repo, baseClonePath: cloneRoot, fileManager: fixture.fileManager)

        XCTAssertEqual(urls, [skillsDir.standardizedFileURL])
    }

    func testRevealTargets_GivenGitLegacyAbsoluteSkillsPath_UsesAbsolutePathAsIs() throws {
        let fixture = try TestFixture()
        defer { fixture.cleanup() }

        let cloneRoot = fixture.tempRoot.appendingPathComponent("git-clone", isDirectory: true)
        let legacyAbsolute = fixture.tempRoot
            .appendingPathComponent("legacy-absolute", isDirectory: true)
            .appendingPathComponent("skills", isDirectory: true)
        try fixture.fileManager.createDirectory(at: legacyAbsolute, withIntermediateDirectories: true)

        let repo = RemoteRepository(
            name: "Repo",
            templateType: .git,
            gitURL: "https://github.com/acme/repo.git",
            skillsPaths: [legacyAbsolute.path]
        )

        let viewModel = RemoteRepositorySidebarViewModel()
        let urls = viewModel.revealTargets(for: repo, baseClonePath: cloneRoot, fileManager: fixture.fileManager)

        XCTAssertEqual(urls, [legacyAbsolute.standardizedFileURL])
    }

    func testRevealTargets_GivenGitMissingConfiguredPath_FallsBackToCloneRoot() throws {
        let fixture = try TestFixture()
        defer { fixture.cleanup() }

        let cloneRoot = fixture.tempRoot.appendingPathComponent("git-clone", isDirectory: true)
        try fixture.fileManager.createDirectory(at: cloneRoot, withIntermediateDirectories: true)

        let repo = RemoteRepository(
            name: "Repo",
            templateType: .git,
            gitURL: "https://github.com/acme/repo.git",
            skillsPaths: ["skills"]
        )

        let viewModel = RemoteRepositorySidebarViewModel()
        let urls = viewModel.revealTargets(for: repo, baseClonePath: cloneRoot, fileManager: fixture.fileManager)

        XCTAssertEqual(urls, [cloneRoot.standardizedFileURL])
    }
}
