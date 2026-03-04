import SwiftUI
import Observation
import NolonResourceKit
import AppKit
import Foundation

@MainActor
@Observable
final class PluginManagementViewModel {
    struct PluginItem: Identifiable, Equatable {
        let id: String
        let name: String
        let isInstalled: Bool
        let installedVersion: String?
        let latestVersion: String?
        let hasUpgrade: Bool
        let releaseURL: URL
    }

    var isChecking = false
    var plugin: PluginItem?
    var errorMessage: String?

    private let releaseChecker: XcodeMCPKitReleaseChecker
    private let installedVersionProvider: @Sendable () -> String?
    private let binaryExistsProvider: @Sendable (_ binaryName: String) -> Bool
    private let runtimeService: any XcodeMCPKitRuntimeServicing
    private let installService: any XcodeMCPKitInstallServicing
    private let releaseRootURL = URL(string: "https://github.com/linhay/XcodeMCPKit/releases")!

    var runtimeState: XcodeMCPKitRuntimeState = .idle
    var isInstalling = false
    var isUpgrading = false

    init(
        releaseChecker: XcodeMCPKitReleaseChecker = XcodeMCPKitReleaseChecker(),
        installedVersionProvider: (@Sendable () -> String?)? = nil,
        binaryExistsProvider: (@Sendable (_ binaryName: String) -> Bool)? = nil,
        runtimeService: (any XcodeMCPKitRuntimeServicing)? = nil,
        installService: (any XcodeMCPKitInstallServicing)? = nil
    ) {
        self.releaseChecker = releaseChecker
        self.installedVersionProvider = installedVersionProvider ?? { Self.defaultInstalledVersion() }
        self.binaryExistsProvider = binaryExistsProvider ?? { Self.defaultBinaryExists(binaryName: $0) }
        self.runtimeService = runtimeService ?? XcodeMCPKitRuntimeService()
        self.installService = installService ?? XcodeMCPKitInstallService()
        self.runtimeState = self.runtimeService.state
        self.runtimeService.onStateChange = { [weak self] state in
            self?.runtimeState = state
        }
    }

    func load() async {
        isChecking = true
        defer { isChecking = false }

        let isInstalled = binaryExistsProvider("xcodemcpkit")
        let rawInstalledVersion = installedVersionProvider()
        let installedVersion = isInstalled ? rawInstalledVersion : nil
        let status = await releaseChecker.checkUpgrade(installedVersion: rawInstalledVersion)
        plugin = PluginItem(
            id: "xcodemcpkit",
            name: "XcodeMCPKit",
            isInstalled: isInstalled,
            installedVersion: installedVersion,
            latestVersion: status.latestVersion,
            hasUpgrade: status.hasUpgrade,
            releaseURL: status.releaseURL ?? releaseRootURL
        )
        runtimeService.refreshStatus()
        runtimeState = runtimeService.state
    }

    func startPlugin() async {
        await runtimeService.start()
        runtimeState = runtimeService.state
    }

    func stopPlugin(force: Bool = false) async {
        await runtimeService.stop(force: force)
        runtimeState = runtimeService.state
    }

    func installPlugin() async {
        guard plugin?.isInstalled == false else { return }
        if isInstalling || isUpgrading { return }
        isInstalling = true
        defer { isInstalling = false }
        do {
            _ = try await installService.installLatest()
            errorMessage = nil
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func upgradePlugin() async {
        guard plugin?.isInstalled == true else { return }
        guard plugin?.hasUpgrade == true else { return }
        if isInstalling || isUpgrading { return }
        isUpgrading = true
        defer { isUpgrading = false }
        do {
            _ = try await installService.installLatest()
            errorMessage = nil
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var runtimeStatusText: String {
        if plugin?.isInstalled == false {
            return NSLocalizedString("plugin.runtime.not_installed", value: "Not Installed", comment: "Plugin runtime not installed")
        }
        switch runtimeState {
        case .idle:
            return NSLocalizedString("plugin.runtime.idle", value: "Stopped", comment: "Plugin runtime idle")
        case .starting:
            return NSLocalizedString("plugin.runtime.starting", value: "Starting...", comment: "Plugin runtime starting")
        case let .running(pid, _):
            return String(
                format: NSLocalizedString(
                    "plugin.runtime.running",
                    value: "Running (PID: %d)",
                    comment: "Plugin runtime running"
                ),
                pid
            )
        case .stopping:
            return NSLocalizedString("plugin.runtime.stopping", value: "Stopping...", comment: "Plugin runtime stopping")
        case let .failed(message):
            return String(
                format: NSLocalizedString(
                    "plugin.runtime.failed",
                    value: "Failed: %@",
                    comment: "Plugin runtime failed"
                ),
                message
            )
        }
    }

    var runtimeActionTitle: String {
        if plugin?.isInstalled == false {
            if isInstalling {
                return NSLocalizedString("plugin.action.installing", value: "Installing...", comment: "Installing plugin")
            }
            return NSLocalizedString("plugin.action.install", value: "Install", comment: "Install plugin")
        }
        switch runtimeState {
        case .idle:
            return NSLocalizedString("plugin.action.start", value: "Start", comment: "Start plugin runtime")
        case .starting:
            return NSLocalizedString("plugin.action.starting", value: "Starting...", comment: "Plugin starting action")
        case .running:
            return NSLocalizedString("plugin.action.stop", value: "Stop", comment: "Stop plugin runtime")
        case .stopping:
            return NSLocalizedString("plugin.action.stopping", value: "Stopping...", comment: "Plugin stopping action")
        case .failed:
            return NSLocalizedString("plugin.action.retry_start", value: "Retry Start", comment: "Retry start plugin runtime")
        }
    }

    var runtimeActionEnabled: Bool {
        if isInstalling || isUpgrading {
            return false
        }
        if plugin?.isInstalled == false {
            return !isInstalling
        }
        return !runtimeState.isBusy
    }

    var upgradeActionTitle: String {
        if isUpgrading {
            return NSLocalizedString("plugin.action.upgrading", value: "Upgrading...", comment: "Upgrading plugin")
        }
        return NSLocalizedString("plugin.action.upgrade", value: "Upgrade", comment: "Upgrade plugin")
    }

    var upgradeActionEnabled: Bool {
        guard plugin?.hasUpgrade == true else { return false }
        return !isInstalling && !isUpgrading
    }

    nonisolated private static func defaultInstalledVersion() -> String? {
        let versionFile = NolonManager.shared
            .rootURL
            .appendingPathComponent("plugins", isDirectory: true)
            .appendingPathComponent("xcodemcpkit", isDirectory: true)
            .appendingPathComponent("installed_version.txt", isDirectory: false)
        guard let data = try? Data(contentsOf: versionFile),
              let raw = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }
        return raw
    }

    nonisolated private static func defaultBinaryExists(binaryName: String) -> Bool {
        let fileManager = FileManager.default
        let localBinCandidate = NolonManager.shared.rootURL
            .appendingPathComponent("bin", isDirectory: true)
            .appendingPathComponent(binaryName, isDirectory: false)
            .path
        if fileManager.isExecutableFile(atPath: localBinCandidate) {
            return true
        }
        let pathEnv = ProcessInfo.processInfo.environment["PATH"] ?? ""
        for rawDir in pathEnv.split(separator: ":") {
            let dir = String(rawDir)
            if dir.isEmpty { continue }
            let candidate = URL(fileURLWithPath: dir, isDirectory: true)
                .appendingPathComponent(binaryName)
                .path
            if fileManager.isExecutableFile(atPath: candidate) {
                return true
            }
        }
        return false
    }
}

struct PluginManagementView: View {
    @State private var viewModel = PluginManagementViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if viewModel.isChecking {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let plugin = viewModel.plugin {
                    pluginCard(plugin)
                } else if !viewModel.isChecking {
                    ContentUnavailableView(
                        NSLocalizedString("plugin.empty.title", value: "No Plugin", comment: "No plugin title"),
                        systemImage: "puzzlepiece",
                        description: Text(
                            NSLocalizedString("plugin.empty.desc", value: "No available plugins.", comment: "No plugin description")
                        )
                        .dsSecondaryText(font: .body)
                    )
                }

                if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.callout)
                        .dsSecondaryText(font: .callout)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .task {
            await viewModel.load()
        }
    }

    @ViewBuilder
    private func pluginCard(_ plugin: PluginManagementViewModel.PluginItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(plugin.name, systemImage: "puzzlepiece.extension")
                    .font(.headline)
                Spacer(minLength: 0)
                Button(viewModel.runtimeActionTitle) {
                    Task {
                        guard viewModel.plugin?.isInstalled == true else {
                            await viewModel.installPlugin()
                            return
                        }
                        switch viewModel.runtimeState {
                        case .running:
                            await viewModel.stopPlugin()
                        default:
                            await viewModel.startPlugin()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.runtimeActionEnabled)

                if plugin.hasUpgrade {
                    Button(viewModel.upgradeActionTitle) {
                        Task {
                            await viewModel.upgradePlugin()
                        }
                    }
                    .dsPrimaryButton()
                    .disabled(!viewModel.upgradeActionEnabled)
                } else {
                    Button(
                        NSLocalizedString("plugin.action.open_release", value: "Open Releases", comment: "Open plugin releases")
                    ) {
                        NSWorkspace.shared.open(plugin.releaseURL)
                    }
                    .dsLinkButton()
                }
            }

            HStack(spacing: 14) {
                let installStatus = plugin.isInstalled
                    ? NSLocalizedString("plugin.install_status.installed", value: "Installed", comment: "Plugin installed status")
                    : NSLocalizedString("plugin.install_status.not_installed", value: "Not Installed", comment: "Plugin not installed status")
                Text("Status: \(installStatus)")
                    .font(.caption)
                    .dsSecondaryText(font: .caption)
                Text("Installed: \(plugin.installedVersion ?? "-")")
                    .font(.caption)
                    .dsSecondaryText(font: .caption)
                Text("Latest: \(plugin.latestVersion ?? "-")")
                    .font(.caption)
                    .dsSecondaryText(font: .caption)
            }

            Text(viewModel.runtimeStatusText)
                .font(.caption)
                .dsSecondaryText(font: .caption)
                .textSelection(.enabled)
        }
        .padding(12)
        .dsCard(
            background: DesignSystem.Colors.Background.elevated,
            cornerRadius: DesignSystem.Metrics.cornerRadiusM,
            borderColor: DesignSystem.Colors.Component.border.opacity(0.4)
        )
    }
}
