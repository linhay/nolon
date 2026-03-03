import Foundation
import Testing
@testable import NolonResourceKit

@Suite("XcodeMCPKitReleaseChecker")
struct XcodeMCPKitReleaseCheckerTests {
    @Test("latestStableRelease ignores prerelease and picks highest semantic version")
    func latestStableReleaseIgnoresPrerelease() async throws {
        let payload = """
        [
          {
            "tag_name": "v0.4.0-beta.1",
            "html_url": "https://github.com/linhay/XcodeMCPKit/releases/tag/v0.4.0-beta.1",
            "prerelease": true,
            "draft": false,
            "published_at": "2026-03-03T09:00:00Z"
          },
          {
            "tag_name": "v0.3.5",
            "html_url": "https://github.com/linhay/XcodeMCPKit/releases/tag/v0.3.5",
            "prerelease": false,
            "draft": false,
            "published_at": "2026-03-01T09:00:00Z"
          },
          {
            "tag_name": "v0.3.6",
            "html_url": "https://github.com/linhay/XcodeMCPKit/releases/tag/v0.3.6",
            "prerelease": false,
            "draft": false,
            "published_at": "2026-03-02T09:00:00Z"
          }
        ]
        """

        let checker = XcodeMCPKitReleaseChecker(
            dataLoader: { _ in Data(payload.utf8) }
        )

        let latest = try await checker.latestStableRelease()
        #expect(latest?.tag == "v0.3.6")
    }

    @Test("checkUpgrade marks upgrade when installed version is lower")
    func checkUpgradeWithLowerInstalledVersion() async {
        let payload = """
        [
          {
            "tag_name": "v0.3.6",
            "html_url": "https://github.com/linhay/XcodeMCPKit/releases/tag/v0.3.6",
            "prerelease": false,
            "draft": false,
            "published_at": "2026-03-02T09:00:00Z"
          }
        ]
        """

        let checker = XcodeMCPKitReleaseChecker(
            dataLoader: { _ in Data(payload.utf8) }
        )

        let status = await checker.checkUpgrade(installedVersion: "v0.3.5")
        #expect(status.hasUpgrade == true)
        #expect(status.latestVersion == "v0.3.6")
    }
}
