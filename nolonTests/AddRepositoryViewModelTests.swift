import XCTest
import NolonResourceKit
@testable import nolon

@MainActor
final class AddRepositoryViewModelTests: XCTestCase {
    func testAvailableTemplates_ExcludesBuiltInRepositories() {
        let templates = AddRepositoryViewModel.selectableTemplates

        XCTAssertEqual(Set(templates), Set([.git, .localFolder]))
    }

    func testApplyGitURLFromText_TrimAndRejectEmpty() throws {
        XCTAssertNil(AddRepositoryViewModel.normalizedGitURLInput("   "))
        XCTAssertEqual(
            AddRepositoryViewModel.normalizedGitURLInput("  https://github.com/acme/repo  "),
            "https://github.com/acme/repo"
        )
    }

    func testApplyDroppedFolderURLs_OnlyAcceptsDirectory() throws {
        let baseURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("nolon-addrepo-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: baseURL) }

        let fileURL = baseURL.appendingPathComponent("not-folder.txt")
        try "x".write(to: fileURL, atomically: true, encoding: .utf8)
        let folderURL = baseURL.appendingPathComponent("skills-folder", isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        XCTAssertNil(AddRepositoryViewModel.firstDirectoryURL(in: [fileURL]))
        XCTAssertEqual(AddRepositoryViewModel.firstDirectoryURL(in: [fileURL, folderURL]), folderURL)
    }

    func testPendingImportPrefill_WithPendingGitURL_PrefillsGitFields() {
        let prefill = AddRepositoryViewModel.pendingImportPrefill(for: "https://github.com/acme/repo")

        XCTAssertEqual(prefill?.template, .git)
        XCTAssertEqual(prefill?.normalizedGitURL, "https://github.com/acme/repo.git")
        XCTAssertEqual(prefill?.name, "repo")
    }

    func testPendingImportPrefill_WithPendingClawhubURL_DoesNotPrefillGitFields() {
        let prefill = AddRepositoryViewModel.pendingImportPrefill(for: "https://clawhub.ai/steipete/gemini")

        XCTAssertNil(prefill)
    }
}
