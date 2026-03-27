import SwiftUI
import Observation
import NolonResourceKit
import AppKit
import Foundation
import OSLog
import SKProcessRunner
import NolonUI
import NolonUIFoundation

@MainActor
@Observable
final class PluginManagementViewModel {
    private static let logger = Logger(subsystem: "com.nolon", category: "PluginManagement")
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
    private let detectedVersionProvider: @Sendable () -> String?
    private let binaryExistsProvider: @Sendable (_ binaryName: String) -> Bool
    private let runtimeService: any XcodeMCPKitRuntimeServicing
    private let installService: any XcodeMCPKitInstallServicing
    private let releaseRootURL = URL(string: "https://github.com/linhay/XcodeMCPKit/releases")!

    var runtimeState: XcodeMCPKitRuntimeState = .idle
    var runtimeLogs: String = ""
    var isInstalling = false
    var isUpgrading = false
    var isUninstalling = false

    init(
        releaseChecker: XcodeMCPKitReleaseChecker = XcodeMCPKitReleaseChecker(),
        installedVersionProvider: (@Sendable () -> String?)? = nil,
        detectedVersionProvider: (@Sendable () -> String?)? = nil,
        binaryExistsProvider: (@Sendable (_ binaryName: String) -> Bool)? = nil,
        runtimeService: (any XcodeMCPKitRuntimeServicing)? = nil,
        installService: (any XcodeMCPKitInstallServicing)? = nil
    ) {
        self.releaseChecker = releaseChecker
        self.installedVersionProvider = installedVersionProvider ?? { Self.defaultInstalledVersion() }
        self.detectedVersionProvider = detectedVersionProvider ?? { Self.defaultDetectedVersion() }
        self.binaryExistsProvider = binaryExistsProvider ?? { Self.defaultBinaryExists(binaryName: $0) }
        self.runtimeService = runtimeService ?? XcodeMCPKitRuntimeService()
        self.installService = installService ?? XcodeMCPKitInstallService()
        self.runtimeState = self.runtimeService.state
        self.runtimeLogs = self.runtimeService.logsText
        self.runtimeService.onStateChange = { [weak self] state in
            self?.runtimeState = state
        }
        self.runtimeService.onLogsChange = { [weak self] logs in
            self?.runtimeLogs = logs
        }
    }

    func load() async {
        Self.logger.info("Loading plugin status")
        isChecking = true
        defer { isChecking = false }

        let isInstalled = binaryExistsProvider("xcodemcpkit")
        let storedInstalledVersion = installedVersionProvider()
        let detectedVersion: String?
        if storedInstalledVersion == nil, isInstalled {
            let provider = detectedVersionProvider
            detectedVersion = await Task.detached(priority: .utility) {
                provider()
            }.value
        } else {
            detectedVersion = nil
        }
        let rawInstalledVersion = storedInstalledVersion ?? detectedVersion
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
        Self.logger.info("Plugin status loaded. installed=\(isInstalled), installedVersion=\(installedVersion ?? "-", privacy: .public), latestVersion=\(status.latestVersion ?? "-", privacy: .public), hasUpgrade=\(status.hasUpgrade)")
    }

    func startPlugin() async {
        Self.logger.info("Start plugin runtime requested")
        await runtimeService.start()
        runtimeState = runtimeService.state
        Self.logger.info("Runtime state after start: \(String(describing: self.runtimeState), privacy: .public)")
    }

    func stopPlugin(force: Bool = false) async {
        Self.logger.info("Stop plugin runtime requested. force=\(force)")
        await runtimeService.stop(force: force)
        runtimeState = runtimeService.state
        Self.logger.info("Runtime state after stop: \(String(describing: self.runtimeState), privacy: .public)")
    }

    func clearRuntimeLogs() {
        runtimeService.clearLogs()
        runtimeLogs = runtimeService.logsText
    }

    func installPlugin() async {
        guard plugin?.isInstalled == false else { return }
        if isInstalling || isUpgrading { return }
        Self.logger.info("Plugin install requested")
        isInstalling = true
        defer { isInstalling = false }
        do {
            let version = try await installService.installLatest()
            errorMessage = nil
            Self.logger.info("Plugin install succeeded. version=\(version, privacy: .public)")
            await load()
        } catch {
            errorMessage = error.localizedDescription
            Self.logger.error("Plugin install failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func upgradePlugin() async {
        guard plugin?.isInstalled == true else { return }
        guard plugin?.hasUpgrade == true else { return }
        if isInstalling || isUpgrading { return }
        Self.logger.info("Plugin upgrade requested")
        isUpgrading = true
        defer { isUpgrading = false }
        do {
            let version = try await installService.installLatest()
            errorMessage = nil
            Self.logger.info("Plugin upgrade succeeded. version=\(version, privacy: .public)")
            await load()
        } catch {
            errorMessage = error.localizedDescription
            Self.logger.error("Plugin upgrade failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func uninstallPlugin() async {
        guard plugin?.isInstalled == true else { return }
        if isInstalling || isUpgrading || isUninstalling { return }
        Self.logger.info("Plugin uninstall requested")
        isUninstalling = true
        defer { isUninstalling = false }
        do {
            if case .running = runtimeState {
                await stopPlugin(force: true)
            }
            try await installService.uninstall()
            errorMessage = nil
            Self.logger.info("Plugin uninstall succeeded")
            await load()
        } catch {
            errorMessage = error.localizedDescription
            Self.logger.error("Plugin uninstall failed: \(error.localizedDescription, privacy: .public)")
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
        if isInstalling || isUpgrading || isUninstalling {
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
        return !isInstalling && !isUpgrading && !isUninstalling
    }

    var uninstallActionTitle: String {
        if isUninstalling {
            return NSLocalizedString("plugin.action.uninstalling", value: "Uninstalling...", comment: "Uninstalling plugin")
        }
        return NSLocalizedString("plugin.action.uninstall", value: "Uninstall", comment: "Uninstall plugin")
    }

    var uninstallActionEnabled: Bool {
        guard plugin?.isInstalled == true else { return false }
        return !isInstalling && !isUpgrading && !isUninstalling && !runtimeState.isBusy
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

    nonisolated private static func defaultDetectedVersion() -> String? {
        let executableURL: URL = {
            let local = NolonManager.shared.rootURL
                .appendingPathComponent("bin", isDirectory: true)
                .appendingPathComponent("xcodemcpkit", isDirectory: false)
            if FileManager.default.isExecutableFile(atPath: local.path) {
                return local
            }
            if let resolved = SKProcessRunner.resolveExecutableInPath(
                named: "xcodemcpkit",
                environment: ProcessInfo.processInfo.environment
            ) {
                return resolved
            }
            return local
        }()

        var payload = SKProcessPayload.executableURL(executableURL)
        payload = payload.arguments(["--version"])
        guard let result = try? SKProcessRunner.runSync(payload), result.exitCode == 0 else {
            return nil
        }
        let merged = "\(result.stdout)\n\(result.stderr)"
        guard let matched = merged.firstMatch(of: #/v?\d+\.\d+\.\d+(?:[-+][0-9A-Za-z\.-]+)?/#) else {
            return nil
        }
        let version = String(matched.output)
        return version.hasPrefix("v") ? version : "v\(version)"
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

struct PluginManagementView: View, DebugPageLocatable {
    @State private var viewModel = PluginManagementViewModel()
    @State private var showingLogs = false
    @State private var logsAutoScroll = true

    var debugPageMarkerItems: [PageMarkerItem] {
        PageMarkerRouteResolver.pluginManagementItems()
    }

    var body: some View {
        NolonUI.PluginManagementPageScaffold(
            isChecking: viewModel.isChecking,
            hasPlugin: viewModel.plugin != nil,
            errorMessage: viewModel.errorMessage
        ) {
            if let plugin = viewModel.plugin {
                pluginCard(plugin)
            }
        }
        .debugPageLocator(debugPageMarkerItems)
        .task {
            await viewModel.load()
        }
    }

    @ViewBuilder
    private func pluginCard(_ plugin: PluginManagementViewModel.PluginItem) -> some View {
        NolonUI.PluginManagementCardView(
            data: pluginCardData(plugin),
            onRuntimeAction: {
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
            },
            onLogs: {
                showingLogs = true
            },
            onUpgrade: {
                Task { await viewModel.upgradePlugin() }
            },
            onOpenRelease: {
                NSWorkspace.shared.open(plugin.releaseURL)
            },
            onUninstall: {
                Task { await viewModel.uninstallPlugin() }
            }
        )
        .sheet(isPresented: $showingLogs) {
            NolonUI.PluginRuntimeLogsSheetView(
                logs: viewModel.runtimeLogs,
                autoScroll: $logsAutoScroll,
                onClear: {
                    viewModel.clearRuntimeLogs()
                },
                onCopy: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(viewModel.runtimeLogs, forType: .string)
                },
                onClose: {
                    showingLogs = false
                }
            )
        }
    }

    private func pluginCardData(_ plugin: PluginManagementViewModel.PluginItem) -> PluginManagementCardData {
        let installStatus = plugin.isInstalled
            ? NSLocalizedString("plugin.install_status.installed", value: "Installed", comment: "Plugin installed status")
            : NSLocalizedString("plugin.install_status.not_installed", value: "Not Installed", comment: "Plugin not installed status")
        let installedText: String = {
            if plugin.isInstalled {
                return plugin.installedVersion ?? NSLocalizedString("plugin.version.unknown", value: "Unknown", comment: "Installed version unknown")
            }
            return NSLocalizedString("plugin.version.not_installed", value: "Not Installed", comment: "Not installed version text")
        }()
        let latestText = plugin.latestVersion ?? NSLocalizedString("plugin.version.unavailable", value: "Unavailable", comment: "Latest version unavailable")

        return PluginManagementCardData(
            name: plugin.name,
            runtimeActionTitle: viewModel.runtimeActionTitle,
            runtimeActionEnabled: viewModel.runtimeActionEnabled,
            logsTitle: NSLocalizedString("plugin.action.logs", value: "Logs", comment: "Open plugin runtime logs"),
            showsUpgradeButton: plugin.hasUpgrade,
            upgradeActionTitle: viewModel.upgradeActionTitle,
            upgradeActionEnabled: viewModel.upgradeActionEnabled,
            openReleaseTitle: NSLocalizedString("plugin.action.open_release", value: "Open Releases", comment: "Open plugin releases"),
            showsUninstallButton: plugin.isInstalled,
            uninstallActionTitle: viewModel.uninstallActionTitle,
            uninstallActionEnabled: viewModel.uninstallActionEnabled,
            statusText: "Status: \(installStatus)",
            installedText: "Installed: \(installedText)",
            latestText: "Latest: \(latestText)",
            runtimeStatusText: viewModel.runtimeStatusText
        )
    }
}
