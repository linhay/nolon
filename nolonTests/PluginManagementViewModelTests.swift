import XCTest
import NolonResourceKit
@testable import nolon

final class PluginManagementViewModelTests: XCTestCase {
    @MainActor
    func testLoad_WhenLatestVersionIsHigher_ShowsUpgrade() async {
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
        let viewModel = PluginManagementViewModel(
            releaseChecker: checker,
            installedVersionProvider: { "v0.3.5" }
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.plugin?.name, "XcodeMCPKit")
        XCTAssertEqual(viewModel.plugin?.latestVersion, "v0.3.6")
        XCTAssertTrue(viewModel.plugin?.hasUpgrade == true)
    }

    @MainActor
    func testLoad_WhenLatestIsPrereleaseOnly_DoesNotShowUpgrade() async {
        let payload = """
        [
          {
            "tag_name": "v0.4.0-beta.1",
            "html_url": "https://github.com/linhay/XcodeMCPKit/releases/tag/v0.4.0-beta.1",
            "prerelease": true,
            "draft": false,
            "published_at": "2026-03-03T09:00:00Z"
          }
        ]
        """
        let checker = XcodeMCPKitReleaseChecker(
            dataLoader: { _ in Data(payload.utf8) }
        )
        let viewModel = PluginManagementViewModel(
            releaseChecker: checker,
            installedVersionProvider: { "v0.3.5" }
        )

        await viewModel.load()

        XCTAssertFalse(viewModel.plugin?.hasUpgrade ?? true)
    }
}
