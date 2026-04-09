import Foundation
import ProviderCatalog
import NolonResourceKit
import ProviderUsage
import CodexBarProviderCatalog
import SKProcessRunner
import STFilePath

extension NolonCoreCLIRunner {
    func listPlugins() async throws -> [NolonPluginStatusSnapshot] {
        var snapshots: [NolonPluginStatusSnapshot] = []
        snapshots.reserveCapacity(Self.pluginDescriptors.count)
        for descriptor in Self.pluginDescriptors {
            snapshots.append(try await pluginStatus(name: descriptor.id))
        }
        return snapshots
    }

    func pluginStatus(name: String) async throws -> NolonPluginStatusSnapshot {
        let descriptor = try resolvePluginDescriptor(name: name)
        let metadataPath = Self.pluginVersionFilePath(pluginName: descriptor.id)
        let installedVersion = try Self.readPluginVersion(at: metadataPath)
        let releaseStatus: XcodeMCPKitUpgradeStatus
        if descriptor.id == "xcodemcpkit" {
            releaseStatus = await Self.checkPluginUpgradeStatus(installedVersion: installedVersion)
        } else {
            releaseStatus = XcodeMCPKitUpgradeStatus(
                installedVersion: installedVersion,
                latestVersion: nil,
                hasUpgrade: false,
                releaseURL: nil
            )
        }
        let globalPath = Self.pluginGlobalMcpFilePath(pluginID: descriptor.id)
        let marker = try Self.readPluginMarker(fromGlobalMcpPath: globalPath)
        let runtime = try Self.currentRuntimeSnapshot(for: descriptor)
        return NolonPluginStatusSnapshot(
            name: descriptor.id,
            provider: "global",
            installedVersion: installedVersion,
            latestVersion: releaseStatus.latestVersion,
            hasUpgrade: releaseStatus.hasUpgrade,
            isInstalled: marker.exists,
            binariesReady: Self.arePluginBinariesReady(for: descriptor),
            runtime: runtime,
            globalPath: globalPath,
            managedByPlugin: marker.managedByPlugin,
            markerPluginID: marker.pluginID
        )
    }

    func installPlugin(
        name: String,
        provider: String,
        version: String?,
        force: Bool
    ) async throws -> NolonPluginMutationResult {
        let descriptor = try resolvePluginDescriptor(name: name)
        guard descriptor.capabilities.contains(.mcpGlobalInstall) else {
            throw NolonCoreCLIError.domainFailed(
                code: "plugin_capability_unsupported",
                message: "Plugin `\(descriptor.id)` does not support global MCP installation."
            )
        }
        guard Self.arePluginBinariesReady(for: descriptor) else {
            throw NolonCoreCLIError.domainFailed(
                code: "plugin_binary_missing",
                message: "Missing required binaries for plugin `\(descriptor.id)`."
            )
        }
        let globalPath = Self.pluginGlobalMcpFilePath(pluginID: descriptor.id)
        try Self.writePluginGlobalMcpFile(descriptor: descriptor, path: globalPath)

        let resolvedVersion: String?
        if let version, !version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            resolvedVersion = version
        } else if descriptor.id == "xcodemcpkit" {
            let status = await Self.checkPluginUpgradeStatus(installedVersion: nil)
            resolvedVersion = status.latestVersion
        } else {
            resolvedVersion = nil
        }
        if let resolvedVersion {
            try Self.writePluginVersion(resolvedVersion, pluginName: descriptor.id)
        }
        let snapshot = try await pluginStatus(name: descriptor.id)
        let message = force ? "plugin installed (force overwrite global)" : "plugin installed"
        return NolonPluginMutationResult(
            action: "install",
            name: descriptor.id,
            provider: provider,
            success: true,
            message: message,
            version: snapshot.installedVersion,
            globalPath: snapshot.globalPath,
            managedByPlugin: snapshot.managedByPlugin,
            markerPluginID: snapshot.markerPluginID
        )
    }

    func uninstallPlugin(
        name: String,
        provider: String,
        force: Bool
    ) async throws -> NolonPluginMutationResult {
        let descriptor = try resolvePluginDescriptor(name: name)
        guard descriptor.capabilities.contains(.mcpGlobalInstall) else {
            throw NolonCoreCLIError.domainFailed(
                code: "plugin_capability_unsupported",
                message: "Plugin `\(descriptor.id)` does not support global MCP uninstall."
            )
        }
        let globalPath = Self.pluginGlobalMcpFilePath(pluginID: descriptor.id)
        let marker = try Self.readPluginMarker(fromGlobalMcpPath: globalPath)
        if marker.exists {
            guard marker.managedByPlugin, marker.pluginID == descriptor.id else {
                throw NolonCoreCLIError.domainFailed(
                    code: "plugin_not_managed_by_nolon",
                    message: "Global MCP entry exists but is not managed by plugin `\(descriptor.id)`."
                )
            }
            if descriptor.capabilities.contains(.runtimeControl) {
                _ = try stopPlugin(name: descriptor.id, force: force)
            }
            try STFile(globalPath).delete()
        }
        try? STFile(Self.pluginVersionFilePath(pluginName: descriptor.id)).delete()

        let message = marker.exists ? "plugin uninstalled from global cache" : "plugin not installed in global cache"
        return NolonPluginMutationResult(
            action: "uninstall",
            name: descriptor.id,
            provider: provider,
            success: true,
            message: message,
            version: nil,
            globalPath: globalPath,
            managedByPlugin: false,
            markerPluginID: nil
        )
    }

    func upgradePlugin(
        name: String,
        provider: String,
        toVersion: String?,
        force: Bool
    ) async throws -> NolonPluginMutationResult {
        let descriptor = try resolvePluginDescriptor(name: name)
        let targetVersion: String?
        if let toVersion, !toVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            targetVersion = toVersion
        } else if descriptor.id == "xcodemcpkit" {
            let current = try Self.readPluginVersion(at: Self.pluginVersionFilePath(pluginName: descriptor.id))
            let status = await Self.checkPluginUpgradeStatus(installedVersion: current)
            targetVersion = status.latestVersion
        } else {
            targetVersion = nil
        }
        let installResult = try await installPlugin(
            name: descriptor.id,
            provider: provider,
            version: targetVersion,
            force: force
        )
        return NolonPluginMutationResult(
            action: "upgrade",
            name: descriptor.id,
            provider: provider,
            success: true,
            message: "plugin upgraded",
            version: installResult.version,
            globalPath: installResult.globalPath,
            managedByPlugin: installResult.managedByPlugin,
            markerPluginID: installResult.markerPluginID
        )
    }

    func startPlugin(name: String, forceRestart: Bool) throws -> NolonPluginRuntimeResult {
        let descriptor = try resolvePluginDescriptor(name: name)
        guard descriptor.capabilities.contains(.runtimeControl),
              let runtimeCommand = descriptor.runtimeStartCommand else {
            throw NolonCoreCLIError.domainFailed(
                code: "plugin_runtime_unsupported",
                message: "Plugin `\(descriptor.id)` does not support runtime control."
            )
        }
        guard Self.executablePath(named: runtimeCommand) != nil else {
            throw NolonCoreCLIError.domainFailed(
                code: "plugin_binary_missing",
                message: "Cannot find `\(runtimeCommand)` in PATH."
            )
        }
        if let current = try Self.waitForRunningServerPID(commandContains: runtimeCommand, timeoutMilliseconds: 400) {
            return NolonPluginRuntimeResult(
                action: "start",
                name: descriptor.id,
                state: "running",
                pid: current,
                message: "\(runtimeCommand) already running"
            )
        }
        let args = forceRestart ? ["--force-restart"] : []
        let pid = try Self.startDetachedProcess(command: runtimeCommand, arguments: args)
        guard let runningPID = try Self.waitForRunningServerPID(commandContains: runtimeCommand, timeoutMilliseconds: 800) else {
            throw NolonCoreCLIError.domainFailed(
                code: "plugin_runtime_start_failed",
                message: "\(runtimeCommand) failed to stay running (pid=\(pid))."
            )
        }
        let exitedQuickly = try Self.waitForProcessExit(
            commandContains: runtimeCommand,
            expectedPID: runningPID,
            timeoutMilliseconds: 250
        )
        if exitedQuickly {
            throw NolonCoreCLIError.domainFailed(
                code: "plugin_runtime_start_failed",
                message: "\(runtimeCommand) exited immediately after start (pid=\(runningPID))."
            )
        }
        return NolonPluginRuntimeResult(
            action: "start",
            name: descriptor.id,
            state: "running",
            pid: runningPID,
            message: "\(runtimeCommand) started"
        )
    }

    func stopPlugin(name: String, force: Bool) throws -> NolonPluginRuntimeResult {
        let descriptor = try resolvePluginDescriptor(name: name)
        guard descriptor.capabilities.contains(.runtimeControl),
              let runtimeCommand = descriptor.runtimeStartCommand else {
            throw NolonCoreCLIError.domainFailed(
                code: "plugin_runtime_unsupported",
                message: "Plugin `\(descriptor.id)` does not support runtime control."
            )
        }
        guard let pid = try Self.runningServerPID(commandContains: runtimeCommand) else {
            return NolonPluginRuntimeResult(
                action: "stop",
                name: descriptor.id,
                state: "stopped",
                pid: nil,
                message: "\(runtimeCommand) not running"
            )
        }
        let signal = force ? SIGKILL : SIGTERM
        _ = kill(pid_t(pid), signal)
        let stopped = try Self.waitForProcessExit(commandContains: runtimeCommand, expectedPID: pid, timeoutMilliseconds: 800)
        let message: String
        if force {
            message = stopped ? "sent SIGKILL" : "sent SIGKILL (still shutting down)"
        } else {
            message = stopped ? "sent SIGTERM" : "sent SIGTERM (still shutting down)"
        }
        return NolonPluginRuntimeResult(
            action: "stop",
            name: descriptor.id,
            state: "stopped",
            pid: pid,
            message: message
        )
    }

    func resolvePluginDescriptor(name raw: String) throws -> PluginDescriptor {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let descriptor = Self.pluginDescriptors.first(where: { $0.id == normalized }) {
            return descriptor
        }
        let supported = Self.pluginDescriptors.map(\.id).sorted().joined(separator: ", ")
        throw NolonCoreCLIError.invalidArguments("Unsupported plugin name: \(raw). Supported: \(supported)")
    }

    static func arePluginBinariesReady(for descriptor: PluginDescriptor) -> Bool {
        descriptor.requiredBinaries.allSatisfy { executablePath(named: $0) != nil }
    }

    static func executablePath(named name: String) -> String? {
        let fm = FileManager.default
        let pathEnv = ProcessInfo.processInfo.environment["PATH"] ?? ""
        for raw in pathEnv.split(separator: ":") {
            let dir = String(raw)
            if dir.isEmpty { continue }
            let candidate = URL(fileURLWithPath: dir, isDirectory: true).appendingPathComponent(name).path
            if fm.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    static func startDetachedProcess(command: String, arguments: [String]) throws -> Int {
        let commandLine = ([command] + arguments)
            .map(shellEscaped)
            .joined(separator: " ")
        let script = "nohup \(commandLine) >/dev/null 2>&1 & echo $!"

        var payload = SKProcessPayload.executableURL(STPath("/bin/sh").url)
        payload.arguments = ["-lc", script]
        payload.throwOnNonZeroExit = false
        payload.timeoutMs = 5_000

        let result = try SKProcessRunner.runSync(payload)
        guard result.exitCode == 0 else {
            let stderr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw NolonCoreCLIError.executionFailed(stderr.isEmpty ? "failed to start detached process" : stderr)
        }

        let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let line = output.split(separator: "\n").last,
              let pid = Int(line) else {
            throw NolonCoreCLIError.executionFailed("failed to parse detached process pid")
        }
        return pid
    }

    static func shellEscaped(_ value: String) -> String {
        if value.isEmpty { return "''" }
        if value.range(of: #"^[A-Za-z0-9_@%+=:,./-]+$"#, options: .regularExpression) != nil {
            return value
        }
        return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static func runningServerPID(commandContains: String) throws -> Int? {
        let currentPID = Int(ProcessInfo.processInfo.processIdentifier)

        var pgrepPayload = SKProcessPayload.executableURL(STPath("/usr/bin/pgrep").url)
        pgrepPayload.arguments = ["-f", commandContains]
        pgrepPayload.throwOnNonZeroExit = false
        pgrepPayload.timeoutMs = 5_000
        if let pgrepResult = try? SKProcessRunner.runSync(pgrepPayload),
           pgrepResult.exitCode == 0 {
            for line in pgrepResult.stdout.split(separator: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let pid = Int(trimmed), pid != currentPID else { continue }
                if let commandLine = try? processCommandLine(pid: pid),
                   matchesRuntimeCommand(commandLine, runtimeCommand: commandContains) {
                    return pid
                }
            }
        }

        var payload = SKProcessPayload.executableURL(STPath("/bin/ps").url)
        payload.arguments = ["-axo", "pid=,command="]
        payload.throwOnNonZeroExit = false
        payload.timeoutMs = 10_000
        payload.maxOutputBytes = 8 * 1024 * 1024
        let result = try SKProcessRunner.runSync(payload)
        guard result.exitCode == 0 else { return nil }

        let text = result.stdout
        for line in text.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count == 2, let pid = Int(parts[0]) else { continue }
            if pid == currentPID { continue }
            if matchesRuntimeCommand(String(parts[1]), runtimeCommand: commandContains) {
                return pid
            }
        }
        return nil
    }

    static func processCommandLine(pid: Int) throws -> String? {
        var payload = SKProcessPayload.executableURL(STPath("/bin/ps").url)
        payload.arguments = ["-p", String(pid), "-o", "command="]
        payload.throwOnNonZeroExit = false
        payload.timeoutMs = 5_000
        let result = try SKProcessRunner.runSync(payload)
        guard result.exitCode == 0 else { return nil }
        let command = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return command.isEmpty ? nil : command
    }

    static func waitForRunningServerPID(commandContains: String, timeoutMilliseconds: Int) throws -> Int? {
        let timeout = max(0, timeoutMilliseconds)
        let start = Date()
        repeat {
            if let pid = try runningServerPID(commandContains: commandContains) {
                return pid
            }
            if timeout == 0 {
                break
            }
            Thread.sleep(forTimeInterval: 0.05)
        } while Date().timeIntervalSince(start) * 1000.0 < Double(timeout)
        return nil
    }

    static func matchesRuntimeCommand(_ commandLine: String, runtimeCommand: String) -> Bool {
        let tokens = commandLine
            .split(whereSeparator: { $0 == " " || $0 == "\t" })
            .map(String.init)
        guard !tokens.isEmpty else { return false }
        let firstBase = URL(fileURLWithPath: tokens[0]).lastPathComponent
        if firstBase == runtimeCommand { return true }
        if firstBase == "env", tokens.count >= 2 {
            let secondBase = URL(fileURLWithPath: tokens[1]).lastPathComponent
            if secondBase == runtimeCommand { return true }
        }
        if firstBase == "nohup", tokens.count >= 2 {
            let secondBase = URL(fileURLWithPath: tokens[1]).lastPathComponent
            if secondBase == runtimeCommand { return true }
        }
        if Set(["sh", "bash", "zsh", "dash"]).contains(firstBase), tokens.count >= 2 {
            let scriptBase = URL(fileURLWithPath: tokens[1]).lastPathComponent
            if scriptBase == runtimeCommand { return true }
        }
        return false
    }

    static func currentRuntimeSnapshot(for descriptor: PluginDescriptor) throws -> NolonPluginRuntimeSnapshot {
        guard descriptor.capabilities.contains(.runtimeControl),
              let runtimeCommand = descriptor.runtimeStartCommand else {
            return NolonPluginRuntimeSnapshot(state: "unsupported", pid: nil)
        }
        if let pid = try runningServerPID(commandContains: runtimeCommand) {
            return NolonPluginRuntimeSnapshot(state: "running", pid: pid)
        }
        return NolonPluginRuntimeSnapshot(state: "stopped", pid: nil)
    }

    static func waitForProcessExit(
        commandContains: String,
        expectedPID: Int,
        timeoutMilliseconds: Int
    ) throws -> Bool {
        let deadline = Date().addingTimeInterval(Double(timeoutMilliseconds) / 1000.0)
        while Date() < deadline {
            let current = try runningServerPID(commandContains: commandContains)
            if current != expectedPID {
                return true
            }
            usleep(50_000)
        }
        return try runningServerPID(commandContains: commandContains) != expectedPID
    }

    static func pluginGlobalMcpFilePath(pluginID: String) -> String {
        let base: String
        if let custom = ProcessInfo.processInfo.environment["NOLON_HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines), !custom.isEmpty {
            base = NSString(string: custom).expandingTildeInPath
        } else {
            base = NSString(string: "~/.nolon").expandingTildeInPath
        }
        return URL(fileURLWithPath: base, isDirectory: true)
            .appendingPathComponent("mcps", isDirectory: true)
            .appendingPathComponent("\(pluginID).json", isDirectory: false)
            .path
    }

    static func writePluginGlobalMcpFile(descriptor: PluginDescriptor, path: String) throws {
        let marker: [String: Any] = [
            "plugin_id": descriptor.id,
            "managed": true,
            "schema_version": 1,
            "installed_by": "nolon-plugin-cli",
            "installed_at": ISO8601DateFormatter().string(from: Date()),
        ]
        let server: [String: Any] = [
            "command": descriptor.serverCommand,
            "enabled": true,
        ]
        let payload: [String: Any] = [
            "name": descriptor.displayName,
            "description": descriptor.summary,
            "mcpServers": [descriptor.serverName: server],
            "nolon_plugin": marker,
        ]
        let file = STFile(path)
        _ = file.parentFolder()?.createIfNotExists()
        let data = try JSONSerialization.data(
            withJSONObject: payload,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        try file.overlay(with: data)
    }

    static func readPluginMarker(fromGlobalMcpPath path: String) throws -> PluginMarkerState {
        let file = STFile(path)
        guard file.isExists else { return PluginMarkerState(exists: false, managedByPlugin: false, pluginID: nil) }
        let raw = try? Data(contentsOf: file.url)
        guard let raw else {
            return PluginMarkerState(exists: true, managedByPlugin: false, pluginID: nil)
        }
        guard let object = try? JSONSerialization.jsonObject(with: raw) as? [String: Any] else {
            return PluginMarkerState(exists: true, managedByPlugin: false, pluginID: nil)
        }
        guard let marker = object["nolon_plugin"] as? [String: Any] else {
            return PluginMarkerState(exists: true, managedByPlugin: false, pluginID: nil)
        }
        let pluginID = marker["plugin_id"] as? String
        let managed = marker["managed"] as? Bool ?? false
        return PluginMarkerState(exists: true, managedByPlugin: managed, pluginID: pluginID)
    }

    static func pluginVersionFilePath(pluginName: String) -> String {
        let base: String
        if let custom = ProcessInfo.processInfo.environment["NOLON_HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines), !custom.isEmpty {
            base = NSString(string: custom).expandingTildeInPath
        } else {
            base = NSString(string: "~/.nolon").expandingTildeInPath
        }
        return URL(fileURLWithPath: base, isDirectory: true)
            .appendingPathComponent("plugins", isDirectory: true)
            .appendingPathComponent(pluginName, isDirectory: true)
            .appendingPathComponent("installed_version.txt", isDirectory: false)
            .path
    }

    static func readPluginVersion(at path: String) throws -> String? {
        let file = STFile(path)
        guard file.isExists else { return nil }
        let raw = try file.read().trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.isEmpty ? nil : raw
    }

    static func writePluginVersion(_ version: String, pluginName: String) throws {
        let path = pluginVersionFilePath(pluginName: pluginName)
        let file = STFile(path)
        _ = file.parentFolder()?.createIfNotExists()
        try file.write(Data((version + "\n").utf8))
    }

    static func checkPluginUpgradeStatus(installedVersion: String?) async -> XcodeMCPKitUpgradeStatus {
        guard ProcessInfo.processInfo.environment["NOLON_PLUGIN_CHECK_LATEST"] == "1" else {
            return XcodeMCPKitUpgradeStatus(
                installedVersion: installedVersion,
                latestVersion: nil,
                hasUpgrade: false,
                releaseURL: URL(string: "https://github.com/linhay/XcodeMCPKit/releases")
            )
        }
        return await XcodeMCPKitReleaseChecker().checkUpgrade(installedVersion: installedVersion)
    }

    func formatPluginListText(result: [NolonPluginStatusSnapshot]) -> String {
        if result.isEmpty {
            return "no plugins"
        }
        return result.map { item in
            let installed = item.installedVersion ?? "-"
            let latest = item.latestVersion ?? "-"
            let runtime = item.runtime.pid.map { "running(pid=\($0))" } ?? item.runtime.state
            return "\(item.name) installed=\(installed) latest=\(latest) managed_by_plugin=\(item.managedByPlugin) binaries_ready=\(item.binariesReady) runtime=\(runtime)"
        }.joined(separator: "\n")
    }

    func formatPluginStatusText(result: NolonPluginStatusSnapshot) -> String {
        let installed = result.installedVersion ?? "-"
        let latest = result.latestVersion ?? "-"
        let runtime = result.runtime.pid.map { "running(pid=\($0))" } ?? result.runtime.state
        return """
        plugin: \(result.name)
        provider: \(result.provider)
        installed: \(installed)
        latest: \(latest)
        has_upgrade: \(result.hasUpgrade)
        global_path: \(result.globalPath)
        managed_by_plugin: \(result.managedByPlugin)
        marker_plugin_id: \(result.markerPluginID ?? "-")
        binaries_ready: \(result.binariesReady)
        runtime: \(runtime)
        """
    }

    func formatPluginMutationText(result: NolonPluginMutationResult) -> String {
        let version = result.version ?? "-"
        return "plugin \(result.action): \(result.name) provider=\(result.provider) version=\(version) global_path=\(result.globalPath ?? "-") managed_by_plugin=\(result.managedByPlugin ?? false) message=\(result.message)"
    }

    func formatPluginRuntimeText(result: NolonPluginRuntimeResult) -> String {
        let pid = result.pid.map(String.init) ?? "-"
        return "plugin runtime \(result.action): \(result.name) state=\(result.state) pid=\(pid) message=\(result.message)"
    }

}

struct NolonPluginRuntimeSnapshot: Encodable, Sendable {
    let state: String
    let pid: Int?
}

struct NolonPluginStatusSnapshot: Encodable, Sendable {
    let name: String
    let provider: String
    let installedVersion: String?
    let latestVersion: String?
    let hasUpgrade: Bool
    let isInstalled: Bool
    let binariesReady: Bool
    let runtime: NolonPluginRuntimeSnapshot
    let globalPath: String
    let managedByPlugin: Bool
    let markerPluginID: String?

    enum CodingKeys: String, CodingKey {
        case name
        case provider
        case installedVersion = "installed_version"
        case latestVersion = "latest_version"
        case hasUpgrade = "has_upgrade"
        case isInstalled = "is_installed"
        case binariesReady = "binaries_ready"
        case runtime
        case globalPath = "global_path"
        case managedByPlugin = "managed_by_plugin"
        case markerPluginID = "marker_plugin_id"
    }
}

struct NolonPluginRuntimeResult: Encodable, Sendable {
    let action: String
    let name: String
    let state: String
    let pid: Int?
    let message: String
}

struct NolonPluginMutationResult: Encodable, Sendable {
    let action: String
    let name: String
    let provider: String
    let success: Bool
    let message: String
    let version: String?
    let globalPath: String?
    let managedByPlugin: Bool?
    let markerPluginID: String?

    enum CodingKeys: String, CodingKey {
        case action
        case name
        case provider
        case success
        case message
        case version
        case globalPath = "global_path"
        case managedByPlugin = "managed_by_plugin"
        case markerPluginID = "marker_plugin_id"
    }
}

struct PluginListPayload: Encodable, Sendable {
    let result: [NolonPluginStatusSnapshot]
}

struct PluginStatusPayload: Encodable, Sendable {
    let result: NolonPluginStatusSnapshot
}

struct PluginMutationPayload: Encodable, Sendable {
    let result: NolonPluginMutationResult
}

struct PluginRuntimePayload: Encodable, Sendable {
    let result: NolonPluginRuntimeResult
}

enum PluginCapability: String, Sendable {
    case mcpGlobalInstall = "mcp_global_install"
    case runtimeControl = "runtime_control"
}

struct PluginDescriptor: Sendable {
    let id: String
    let displayName: String
    let summary: String
    let serverName: String
    let serverCommand: String
    let requiredBinaries: [String]
    let capabilities: Set<PluginCapability>
    let runtimeStartCommand: String?
}

struct PluginMarkerState: Sendable {
    let exists: Bool
    let managedByPlugin: Bool
    let pluginID: String?
}
