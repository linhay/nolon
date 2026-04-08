import XCTest
import ProviderCatalog
import CodexProvider
import NolonUIFoundation
@testable import nolon

final class CodexBinaryReleaseNotesViewModelTests: XCTestCase {
    @MainActor
    func testBDD_GivenRemoteReleaseSelected_WhenBuildingReleaseNotesData_ThenReturnsNotesAndGitHubURL() throws {
        let provider = try XCTUnwrap(ProviderTemplate(rawValue: "codex")).createProvider()
        let viewModel = CodexBinaryConfigViewModel(provider: provider)
        viewModel.remoteReleases = [
            CodexRemoteRelease(
                tag: "rust-v0.118.0",
                version: "0.118.0",
                assetURL: URL(string: "https://example.com/codex-aarch64-apple-darwin.tar.gz")!,
                htmlURL: URL(string: "https://github.com/openai/codex/releases/tag/rust-v0.118.0"),
                publishedAt: Date(timeIntervalSince1970: 1_743_415_200),
                notes: "## Notes\n- Added changelog support",
                isPrerelease: false
            )
        ]
        viewModel.selectVersionRow("remote-rust-v0.118.0")

        let data = try XCTUnwrap(viewModel.selectedReleaseNotesData())

        XCTAssertEqual(data.versionText, "v0.118.0")
        XCTAssertTrue(data.notesMarkdown?.contains("Added changelog support") == true)
        XCTAssertEqual(data.actionURL?.absoluteString, "https://github.com/openai/codex/releases/tag/rust-v0.118.0")
    }

    @MainActor
    func testBDD_GivenLocalDownloadedVersion_WhenBuildingReleaseNotesData_ThenMatchesRemoteReleaseBySourceURL() throws {
        let provider = try XCTUnwrap(ProviderTemplate(rawValue: "codex")).createProvider()
        let viewModel = CodexBinaryConfigViewModel(provider: provider)
        let assetURL = URL(string: "https://example.com/codex-aarch64-apple-darwin.tar.gz")!
        viewModel.manifest = CodexBinaryManifest(
            versions: [
                ManagedCodexVersion(
                    id: "v0.118.0-test",
                    displayName: "Codex 0.118.0",
                    detectedVersion: "0.118.0",
                    binaryRelativePath: "versions/v0.118.0-test/codex",
                    sha256: "abc",
                    source: "download",
                    sourceURL: assetURL.absoluteString,
                    importedAt: Date(),
                    notes: nil
                )
            ]
        )
        viewModel.remoteReleases = [
            CodexRemoteRelease(
                tag: "rust-v0.118.0",
                version: "0.118.0",
                assetURL: assetURL,
                htmlURL: URL(string: "https://github.com/openai/codex/releases/tag/rust-v0.118.0"),
                publishedAt: nil,
                notes: "Matched by source URL",
                isPrerelease: false
            )
        ]
        viewModel.selectVersionRow("local-v0.118.0-test")

        let data = try XCTUnwrap(viewModel.selectedReleaseNotesData())

        XCTAssertEqual(data.notesMarkdown, "Matched by source URL")
    }
}
