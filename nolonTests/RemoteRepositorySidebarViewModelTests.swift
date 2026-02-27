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
}
