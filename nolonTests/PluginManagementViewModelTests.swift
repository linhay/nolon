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
            installedVersionProvider: { "v0.3.5" },
            binaryExistsProvider: { _ in true }
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.plugin?.name, "XcodeMCPKit")
        XCTAssertTrue(viewModel.plugin?.isInstalled == true)
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
            installedVersionProvider: { "v0.3.5" },
            binaryExistsProvider: { _ in true }
        )

        await viewModel.load()

        XCTAssertFalse(viewModel.plugin?.hasUpgrade ?? true)
    }

    @MainActor
    func testLoad_WhenBinaryExists_MarksInstalledTrue() async {
        let checker = XcodeMCPKitReleaseChecker(dataLoader: { _ in Data("[]".utf8) })
        let viewModel = PluginManagementViewModel(
            releaseChecker: checker,
            installedVersionProvider: { "v1.0.0" },
            binaryExistsProvider: { _ in true }
        )

        await viewModel.load()

        XCTAssertTrue(viewModel.plugin?.isInstalled == true)
        XCTAssertEqual(viewModel.plugin?.installedVersion, "v1.0.0")
    }

    @MainActor
    func testLoad_WhenBinaryMissing_MarksInstalledFalse() async {
        let checker = XcodeMCPKitReleaseChecker(dataLoader: { _ in Data("[]".utf8) })
        let viewModel = PluginManagementViewModel(
            releaseChecker: checker,
            installedVersionProvider: { "v1.0.0" },
            binaryExistsProvider: { _ in false }
        )

        await viewModel.load()

        XCTAssertFalse(viewModel.plugin?.isInstalled ?? true)
        XCTAssertEqual(viewModel.plugin?.installedVersion, nil)
    }

    @MainActor
    func testLoad_WhenBinaryExistsButVersionMissing_InstalledTrueAndVersionDashSource() async {
        let checker = XcodeMCPKitReleaseChecker(dataLoader: { _ in Data("[]".utf8) })
        let viewModel = PluginManagementViewModel(
            releaseChecker: checker,
            installedVersionProvider: { nil },
            binaryExistsProvider: { _ in true }
        )

        await viewModel.load()

        XCTAssertTrue(viewModel.plugin?.isInstalled == true)
        XCTAssertNil(viewModel.plugin?.installedVersion)
    }

    @MainActor
    func testLoad_WhenBinaryMissingButVersionExists_InstalledFalseAndVersionHidden() async {
        let checker = XcodeMCPKitReleaseChecker(dataLoader: { _ in Data("[]".utf8) })
        let viewModel = PluginManagementViewModel(
            releaseChecker: checker,
            installedVersionProvider: { "v9.9.9" },
            binaryExistsProvider: { _ in false }
        )

        await viewModel.load()

        XCTAssertFalse(viewModel.plugin?.isInstalled ?? true)
        XCTAssertNil(viewModel.plugin?.installedVersion)
    }

    @MainActor
    func testRuntimeAction_WhenIdle_StartInvokesRuntimeService() async {
        let runtime = MockXcodeMCPKitRuntimeService(initial: .idle)
        let viewModel = PluginManagementViewModel(
            releaseChecker: XcodeMCPKitReleaseChecker(dataLoader: { _ in Data("[]".utf8) }),
            installedVersionProvider: { "v0.3.5" },
            binaryExistsProvider: { _ in true },
            runtimeService: runtime
        )

        await viewModel.startPlugin()

        XCTAssertEqual(runtime.startCallCount, 1)
        if case .running = viewModel.runtimeState {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected running state after start")
        }
    }

    @MainActor
    func testRuntimeAction_WhenRunning_StopInvokesRuntimeService() async {
        let runtime = MockXcodeMCPKitRuntimeService(initial: .running(pid: 123, startedAt: Date()))
        let viewModel = PluginManagementViewModel(
            releaseChecker: XcodeMCPKitReleaseChecker(dataLoader: { _ in Data("[]".utf8) }),
            installedVersionProvider: { "v0.3.5" },
            binaryExistsProvider: { _ in true },
            runtimeService: runtime
        )

        await viewModel.stopPlugin()

        XCTAssertEqual(runtime.stopCallCount, 1)
        if case .idle = viewModel.runtimeState {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected idle state after stop")
        }
    }

    @MainActor
    func testRuntimeStatusText_WhenFailed_IncludesFailureMessage() async {
        let runtime = MockXcodeMCPKitRuntimeService(initial: .failed(message: "boom"))
        let viewModel = PluginManagementViewModel(
            releaseChecker: XcodeMCPKitReleaseChecker(dataLoader: { _ in Data("[]".utf8) }),
            installedVersionProvider: { "v0.3.5" },
            binaryExistsProvider: { _ in true },
            runtimeService: runtime
        )

        XCTAssertTrue(viewModel.runtimeStatusText.contains("boom"))
        XCTAssertEqual(viewModel.runtimeActionTitle, "Retry Start")
    }

    @MainActor
    func testRuntimeControls_WhenPluginNotInstalled_ShowsInstallActionEnabled() async {
        let runtime = MockXcodeMCPKitRuntimeService(initial: .idle)
        let viewModel = PluginManagementViewModel(
            releaseChecker: XcodeMCPKitReleaseChecker(dataLoader: { _ in Data("[]".utf8) }),
            installedVersionProvider: { nil },
            binaryExistsProvider: { _ in false },
            runtimeService: runtime
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.runtimeStatusText, "Not Installed")
        XCTAssertEqual(viewModel.runtimeActionTitle, "Install")
        XCTAssertTrue(viewModel.runtimeActionEnabled)
    }

    @MainActor
    func testInstallPlugin_WhenNotInstalled_InvokesInstallerAndRefreshesInstalledState() async {
        var installed = false
        let installer = MockXcodeMCPKitInstallService {
            installed = true
            return "v1.2.3"
        }
        let viewModel = PluginManagementViewModel(
            releaseChecker: XcodeMCPKitReleaseChecker(dataLoader: { _ in Data("[]".utf8) }),
            installedVersionProvider: { installed ? "v1.2.3" : nil },
            binaryExistsProvider: { _ in installed },
            runtimeService: MockXcodeMCPKitRuntimeService(initial: .idle),
            installService: installer
        )

        await viewModel.load()
        XCTAssertFalse(viewModel.plugin?.isInstalled ?? true)

        await viewModel.installPlugin()

        XCTAssertEqual(installer.installCallCount, 1)
        XCTAssertTrue(viewModel.plugin?.isInstalled == true)
        XCTAssertEqual(viewModel.plugin?.installedVersion, "v1.2.3")
    }

    @MainActor
    func testInstallPlugin_WhenInstallerFails_SetsErrorAndResetsInstallingState() async {
        struct MockError: LocalizedError {
            var errorDescription: String? { "install failed" }
        }
        let installer = MockXcodeMCPKitInstallService {
            throw MockError()
        }
        let viewModel = PluginManagementViewModel(
            releaseChecker: XcodeMCPKitReleaseChecker(dataLoader: { _ in Data("[]".utf8) }),
            installedVersionProvider: { nil },
            binaryExistsProvider: { _ in false },
            runtimeService: MockXcodeMCPKitRuntimeService(initial: .idle),
            installService: installer
        )

        await viewModel.load()
        await viewModel.installPlugin()

        XCTAssertEqual(installer.installCallCount, 1)
        XCTAssertEqual(viewModel.errorMessage, "install failed")
        XCTAssertFalse(viewModel.isInstalling)
        XCTAssertEqual(viewModel.runtimeActionTitle, "Install")
    }

    @MainActor
    func testInstallPlugin_WhenAlreadyInstalled_DoesNotInvokeInstaller() async {
        let installer = MockXcodeMCPKitInstallService {
            XCTFail("Installer should not be called when already installed")
            return "v1.2.3"
        }
        let viewModel = PluginManagementViewModel(
            releaseChecker: XcodeMCPKitReleaseChecker(dataLoader: { _ in Data("[]".utf8) }),
            installedVersionProvider: { "v1.2.3" },
            binaryExistsProvider: { _ in true },
            runtimeService: MockXcodeMCPKitRuntimeService(initial: .idle),
            installService: installer
        )

        await viewModel.load()
        await viewModel.installPlugin()

        XCTAssertEqual(installer.installCallCount, 0)
        XCTAssertFalse(viewModel.isInstalling)
    }

    @MainActor
    func testRuntimeAction_WhenInstalling_ShowsInstallingAndDisabled() async {
        let installer = MockXcodeMCPKitInstallService {
            try await Task.sleep(nanoseconds: 200_000_000)
            return "v1.2.3"
        }
        let viewModel = PluginManagementViewModel(
            releaseChecker: XcodeMCPKitReleaseChecker(dataLoader: { _ in Data("[]".utf8) }),
            installedVersionProvider: { nil },
            binaryExistsProvider: { _ in false },
            runtimeService: MockXcodeMCPKitRuntimeService(initial: .idle),
            installService: installer
        )

        await viewModel.load()

        let task = Task { await viewModel.installPlugin() }
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertTrue(viewModel.isInstalling)
        XCTAssertEqual(viewModel.runtimeActionTitle, "Installing...")
        XCTAssertFalse(viewModel.runtimeActionEnabled)

        await task.value
    }

    @MainActor
    func testUpgradePlugin_WhenHasUpgrade_InvokesInstallerAndRefreshesStatus() async {
        var installedVersion = "v1.0.0"
        let payload = """
        [
          {
            "tag_name": "v1.1.0",
            "html_url": "https://github.com/linhay/XcodeMCPKit/releases/tag/v1.1.0",
            "prerelease": false,
            "draft": false,
            "published_at": "2026-03-04T09:00:00Z"
          }
        ]
        """
        let checker = XcodeMCPKitReleaseChecker(dataLoader: { _ in Data(payload.utf8) })
        let installer = MockXcodeMCPKitInstallService {
            installedVersion = "v1.1.0"
            return "v1.1.0"
        }
        let viewModel = PluginManagementViewModel(
            releaseChecker: checker,
            installedVersionProvider: { installedVersion },
            binaryExistsProvider: { _ in true },
            runtimeService: MockXcodeMCPKitRuntimeService(initial: .idle),
            installService: installer
        )

        await viewModel.load()
        XCTAssertTrue(viewModel.plugin?.hasUpgrade == true)

        await viewModel.upgradePlugin()

        XCTAssertEqual(installer.installCallCount, 1)
        XCTAssertEqual(viewModel.plugin?.installedVersion, "v1.1.0")
        XCTAssertFalse(viewModel.plugin?.hasUpgrade ?? true)
    }

    @MainActor
    func testUpgradePlugin_WhenNoUpgrade_DoesNotInvokeInstaller() async {
        let payload = """
        [
          {
            "tag_name": "v1.1.0",
            "html_url": "https://github.com/linhay/XcodeMCPKit/releases/tag/v1.1.0",
            "prerelease": false,
            "draft": false,
            "published_at": "2026-03-04T09:00:00Z"
          }
        ]
        """
        let checker = XcodeMCPKitReleaseChecker(dataLoader: { _ in Data(payload.utf8) })
        let installer = MockXcodeMCPKitInstallService {
            XCTFail("Installer should not be called when no upgrade")
            return "v1.1.0"
        }
        let viewModel = PluginManagementViewModel(
            releaseChecker: checker,
            installedVersionProvider: { "v1.1.0" },
            binaryExistsProvider: { _ in true },
            runtimeService: MockXcodeMCPKitRuntimeService(initial: .idle),
            installService: installer
        )

        await viewModel.load()
        XCTAssertFalse(viewModel.plugin?.hasUpgrade ?? true)

        await viewModel.upgradePlugin()

        XCTAssertEqual(installer.installCallCount, 0)
    }

    @MainActor
    func testUpgradePlugin_WhenInstallerFails_SetsErrorAndResetsUpgradingState() async {
        struct MockError: LocalizedError {
            var errorDescription: String? { "upgrade failed" }
        }
        let payload = """
        [
          {
            "tag_name": "v1.1.0",
            "html_url": "https://github.com/linhay/XcodeMCPKit/releases/tag/v1.1.0",
            "prerelease": false,
            "draft": false,
            "published_at": "2026-03-04T09:00:00Z"
          }
        ]
        """
        let checker = XcodeMCPKitReleaseChecker(dataLoader: { _ in Data(payload.utf8) })
        let installer = MockXcodeMCPKitInstallService {
            throw MockError()
        }
        let viewModel = PluginManagementViewModel(
            releaseChecker: checker,
            installedVersionProvider: { "v1.0.0" },
            binaryExistsProvider: { _ in true },
            runtimeService: MockXcodeMCPKitRuntimeService(initial: .idle),
            installService: installer
        )

        await viewModel.load()
        await viewModel.upgradePlugin()

        XCTAssertEqual(installer.installCallCount, 1)
        XCTAssertEqual(viewModel.errorMessage, "upgrade failed")
        XCTAssertFalse(viewModel.isUpgrading)
        XCTAssertEqual(viewModel.upgradeActionTitle, "Upgrade")
    }
}

@MainActor
private final class MockXcodeMCPKitRuntimeService: XcodeMCPKitRuntimeServicing {
    var onStateChange: ((XcodeMCPKitRuntimeState) -> Void)?
    var state: XcodeMCPKitRuntimeState
    var startCallCount = 0
    var stopCallCount = 0

    init(initial: XcodeMCPKitRuntimeState) {
        self.state = initial
    }

    func refreshStatus() {}

    func start() async {
        startCallCount += 1
        state = .running(pid: 777, startedAt: Date())
        onStateChange?(state)
    }

    func stop(force: Bool) async {
        stopCallCount += 1
        state = .idle
        onStateChange?(state)
    }
}

private final class MockXcodeMCPKitInstallService: XcodeMCPKitInstallServicing {
    var installCallCount = 0
    private let action: @Sendable () async throws -> String

    init(action: @escaping @Sendable () async throws -> String) {
        self.action = action
    }

    func installLatest() async throws -> String {
        installCallCount += 1
        return try await action()
    }
}
