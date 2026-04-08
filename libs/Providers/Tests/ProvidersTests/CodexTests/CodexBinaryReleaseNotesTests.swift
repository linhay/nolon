import Foundation
import Testing
@testable import CodexProvider

@Suite("CodexBinaryManager Release Notes")
struct CodexBinaryReleaseNotesTests {
    @Test("Given GitHub release payload, when fetching remote releases, then notes metadata is preserved")
    func fetchRemoteReleasesIncludesNotes() async throws {
        let payload = """
        [
          {
            "tag_name": "rust-v0.118.0",
            "html_url": "https://github.com/openai/codex/releases/tag/rust-v0.118.0",
            "body": "## What's Changed\\n- Added release notes support",
            "published_at": "2026-03-31T10:00:00Z",
            "draft": false,
            "prerelease": false,
            "assets": [
              {
                "name": "codex-aarch64-apple-darwin.tar.gz",
                "browser_download_url": "https://github.com/openai/codex/releases/download/rust-v0.118.0/codex-aarch64-apple-darwin.tar.gz"
              }
            ]
          }
        ]
        """
        let manager = CodexBinaryManager(
            releaseDataLoader: { _ in
                (
                    Data(payload.utf8),
                    HTTPURLResponse(
                        url: URL(string: "https://api.github.com/repos/openai/codex/releases?per_page=30")!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: nil
                    )!
                )
            }
        )

        let releases = try await manager.fetchRemoteReleases(includePrerelease: false)

        #expect(releases.count == 1)
        #expect(releases[0].tag == "rust-v0.118.0")
        #expect(releases[0].htmlURL?.absoluteString == "https://github.com/openai/codex/releases/tag/rust-v0.118.0")
        #expect(releases[0].publishedAt != nil)
        #expect(releases[0].notes?.contains("Added release notes support") == true)
    }

    @Test("Given release with notes, when checking updates, then manifest caches latest release notes metadata")
    func updateCheckCachesLatestReleaseNotes() async throws {
        let payload = """
        [
          {
            "tag_name": "rust-v0.118.0",
            "html_url": "https://github.com/openai/codex/releases/tag/rust-v0.118.0",
            "body": "Latest fixes",
            "published_at": "2026-03-31T10:00:00Z",
            "draft": false,
            "prerelease": false,
            "assets": [
              {
                "name": "codex-aarch64-apple-darwin.tar.gz",
                "browser_download_url": "https://github.com/openai/codex/releases/download/rust-v0.118.0/codex-aarch64-apple-darwin.tar.gz"
              }
            ]
          }
        ]
        """
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-release-notes-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = CodexBinaryManager(
            homeURL: root,
            releaseDataLoader: { _ in
                (
                    Data(payload.utf8),
                    HTTPURLResponse(
                        url: URL(string: "https://api.github.com/repos/openai/codex/releases?per_page=30")!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: nil
                    )!
                )
            }
        )

        let manifest = await manager.checkForRustReleaseUpdateIfNeeded(force: true)

        #expect(manifest.lastSeenRemoteTag == "rust-v0.118.0")
        #expect(manifest.lastSeenRemoteHTMLURL == "https://github.com/openai/codex/releases/tag/rust-v0.118.0")
        #expect(manifest.lastSeenRemoteNotes == "Latest fixes")
        #expect(manifest.lastSeenRemotePublishedAt != nil)
    }
}
