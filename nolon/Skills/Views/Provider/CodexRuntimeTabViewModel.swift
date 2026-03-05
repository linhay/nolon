import Foundation
import Observation
import OSLog
import ProviderCatalog
import NolonCoreCLIKit
import SKProcessRunner

struct CodexRuntimeProcessItem: Identifiable, Equatable {
    let pid: Int32
    let ppid: Int32?
    let elapsed: String
    let providerHint: String?
    let command: String

    var id: Int32 { pid }
}

struct CodexRuntimeStopResult: Equatable {
    let pid: Int32
    let requestedSignal: String
    let didEscalateToKill: Bool
    let exited: Bool
}

struct CodexRuntimeDiagnosticsSnapshot: Equatable {
    let providerID: String
    let accountCount: Int
    let activeAccountID: String?
    let selectedVersionID: String?
    let currentVersion: String?
    let pathActive: Bool
    let runtimeCount: Int
    let resolvedExecutable: String?
    let probeWarning: String?
    let probeHint: String?

    static func empty(providerID: String) -> Self {
        .init(
            providerID: providerID,
            accountCount: 0,
            activeAccountID: nil,
            selectedVersionID: nil,
            currentVersion: nil,
            pathActive: false,
            runtimeCount: 0,
            resolvedExecutable: nil,
            probeWarning: nil,
            probeHint: nil
        )
    }
}

protocol CodexRuntimeTabServicing {
    func runtimeList(providerID: String?) async throws -> [CodexRuntimeProcessItem]
    func runtimeStop(pid: Int32, force: Bool, timeoutSeconds: Int) async throws -> CodexRuntimeStopResult
    func diagnostics(providerID: String) async throws -> CodexRuntimeDiagnosticsSnapshot
}

struct CodexRuntimeCLIService: CodexRuntimeTabServicing {
    private let codexService: any NolonCodexCLIServing

    init(codexService: any NolonCodexCLIServing = NolonLiveCodexCLIService()) {
        self.codexService = codexService
    }

    func runtimeList(providerID: String?) async throws -> [CodexRuntimeProcessItem] {
        let payload = try await codexService.runtimeList(providerID: providerID)
        return payload.processes.map {
            CodexRuntimeProcessItem(
                pid: $0.pid,
                ppid: $0.ppid,
                elapsed: $0.elapsed,
                providerHint: $0.providerHint,
                command: $0.command
            )
        }
    }

    func runtimeStop(pid: Int32, force: Bool, timeoutSeconds: Int) async throws -> CodexRuntimeStopResult {
        let payload = try await codexService.runtimeStop(pid: pid, force: force, timeoutSeconds: timeoutSeconds)
        return CodexRuntimeStopResult(
            pid: payload.pid,
            requestedSignal: payload.requestedSignal,
            didEscalateToKill: payload.didEscalateToKill,
            exited: payload.exited
        )
    }

    func diagnostics(providerID: String) async throws -> CodexRuntimeDiagnosticsSnapshot {
        async let auth = codexService.authStatus(providerID: providerID)
        async let binary = codexService.binaryDoctor()
        async let runtime = codexService.runtimeList(providerID: providerID)

        let probe: NolonCodexStatusProbePayload?
        var probeFallbackWarning: String?
        do {
            probe = try await codexService.statusProbe(providerID: providerID)
        } catch {
            probe = nil
            probeFallbackWarning = error.localizedDescription
        }

        let authPayload = try await auth
        let binaryPayload = try await binary
        let runtimePayload = try await runtime

        return CodexRuntimeDiagnosticsSnapshot(
            providerID: providerID,
            accountCount: authPayload.accountCount,
            activeAccountID: authPayload.activeAccountID?.uuidString,
            selectedVersionID: binaryPayload.selectedVersionID,
            currentVersion: binaryPayload.currentVersion,
            pathActive: binaryPayload.pathActive,
            runtimeCount: runtimePayload.processes.count,
            resolvedExecutable: probe?.resolvedExecutable,
            probeWarning: probe?.probeWarning ?? probeFallbackWarning,
            probeHint: probe?.probeHint
        )
    }
}

enum CodexPIDSystemLogServiceError: LocalizedError {
    case invalidArguments(String)
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case let .invalidArguments(message), let .commandFailed(message):
            return message
        }
    }
}

protocol CodexPIDSystemLogServicing {
    func fetchLogs(pid: Int32, lastSeconds: Int, maxLines: Int) async throws -> String
}

struct CodexPIDSystemLogService: CodexPIDSystemLogServicing {
    typealias CommandRunner = @Sendable (_ pid: Int32, _ lastSeconds: Int) throws -> String

    private let commandRunner: CommandRunner

    init(commandRunner: CommandRunner? = nil) {
        self.commandRunner = commandRunner ?? Self.liveCommandRunner
    }

    func fetchLogs(pid: Int32, lastSeconds: Int = 120, maxLines: Int = 300) async throws -> String {
        guard pid > 1 else {
            throw CodexPIDSystemLogServiceError.invalidArguments("Invalid pid: \(pid)")
        }
        guard lastSeconds > 0 else {
            throw CodexPIDSystemLogServiceError.invalidArguments("Invalid lastSeconds: \(lastSeconds)")
        }
        guard maxLines > 0 else {
            throw CodexPIDSystemLogServiceError.invalidArguments("Invalid maxLines: \(maxLines)")
        }

        let raw = try await Task.detached(priority: .utility) {
            try commandRunner(pid, lastSeconds)
        }.value

        let lines = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return "" }
        return lines.suffix(maxLines).joined(separator: "\n")
    }

    private static func liveCommandRunner(pid: Int32, lastSeconds: Int) throws -> String {
        var payload = SKProcessPayload.command("/usr/bin/log")
        payload.arguments = [
            "show",
            "--style", "compact",
            "--last", "\(lastSeconds)s",
            "--predicate", "processIdentifier == \(pid)"
        ]
        payload.throwOnNonZeroExit = false
        payload.timeoutMs = 15_000

        let result = try SKProcessRunner.runSync(payload)
        guard result.exitCode == 0 else {
            let stderr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            let stdout = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            let message = stderr.isEmpty ? (stdout.isEmpty ? "log show failed" : stdout) : stderr
            throw CodexPIDSystemLogServiceError.commandFailed(message)
        }

        return result.stdout
    }
}

@MainActor
@Observable
final class CodexRuntimeTabViewModel {
    private static let logger = Logger(subsystem: "com.nolon", category: "CodexRuntimeTabViewModel")

    let provider: Provider

    var processes: [CodexRuntimeProcessItem] = []
    var selectedPID: Int32?
    var diagnostics: CodexRuntimeDiagnosticsSnapshot?

    var isRefreshing = false
    var isStopping = false
    var isLoadingLogs = false

    var logsText: String = ""
    var logsErrorMessage: String?

    var alertMessage: String?
    var lastStopMessage: String?
    var pendingForceStopPID: Int32?

    private let runtimeService: any CodexRuntimeTabServicing
    private let logService: any CodexPIDSystemLogServicing

    init(
        provider: Provider,
        runtimeService: any CodexRuntimeTabServicing = CodexRuntimeCLIService(),
        logService: any CodexPIDSystemLogServicing = CodexPIDSystemLogService()
    ) {
        self.provider = provider
        self.runtimeService = runtimeService
        self.logService = logService
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        alertMessage = nil
        defer { isRefreshing = false }

        let providerID = canonicalProviderID

        do {
            let latest = try await runtimeService.runtimeList(providerID: providerID)
            processes = latest.sorted(by: { $0.pid < $1.pid })
        } catch {
            processes = []
            selectedPID = nil
            logsText = ""
            logsErrorMessage = nil
            alertMessage = Self.formattedError(error)
            Self.logger.error("Runtime list failed: \(error.localizedDescription, privacy: .public)")
            return
        }

        do {
            diagnostics = try await runtimeService.diagnostics(providerID: providerID)
        } catch {
            diagnostics = nil
            alertMessage = Self.formattedError(error)
            Self.logger.error("Runtime diagnostics failed: \(error.localizedDescription, privacy: .public)")
        }

        if let selectedPID, processes.contains(where: { $0.pid == selectedPID }) {
            await refreshSelectedProcessLogs()
            return
        }

        selectedPID = processes.first?.pid
        await refreshSelectedProcessLogs()
    }

    func selectProcess(pid: Int32?) {
        selectedPID = pid
        logsErrorMessage = nil
        logsText = ""
    }

    func clearLogs() {
        logsText = ""
        logsErrorMessage = nil
    }

    func refreshSelectedProcessLogs(lastSeconds: Int = 120, maxLines: Int = 300) async {
        guard let selectedPID else {
            logsText = ""
            logsErrorMessage = nil
            return
        }

        isLoadingLogs = true
        defer { isLoadingLogs = false }

        do {
            logsText = try await logService.fetchLogs(pid: selectedPID, lastSeconds: lastSeconds, maxLines: maxLines)
            logsErrorMessage = nil
        } catch {
            logsErrorMessage = Self.formattedError(error)
            Self.logger.error("Runtime logs failed pid=\(selectedPID): \(error.localizedDescription, privacy: .public)")
        }
    }

    func stop(pid: Int32, force: Bool, timeoutSeconds: Int = 3) async {
        guard !isStopping else { return }
        isStopping = true
        defer { isStopping = false }

        do {
            let result = try await runtimeService.runtimeStop(pid: pid, force: force, timeoutSeconds: timeoutSeconds)
            lastStopMessage = String(
                format: NSLocalizedString(
                    "codex.runtime.stop.summary",
                    value: "PID %d (%@) -> exited=%@",
                    comment: "Runtime stop summary"
                ),
                result.pid,
                result.requestedSignal.uppercased(),
                result.exited
                    ? NSLocalizedString(
                        "codex.runtime.bool.true",
                        value: "true",
                        comment: "Runtime boolean true"
                    )
                    : NSLocalizedString(
                        "codex.runtime.bool.false",
                        value: "false",
                        comment: "Runtime boolean false"
                    )
            )
            await refresh()
        } catch {
            alertMessage = Self.formattedError(error)
            Self.logger.error("Runtime stop failed pid=\(pid): \(error.localizedDescription, privacy: .public)")
        }
    }

    func requestForceStop(pid: Int32) {
        pendingForceStopPID = pid
    }

    func confirmForceStop(timeoutSeconds: Int = 3) async {
        guard let pid = pendingForceStopPID else { return }
        pendingForceStopPID = nil
        await stop(pid: pid, force: true, timeoutSeconds: timeoutSeconds)
    }

    var canonicalProviderID: String {
        if provider.templateId == "codexXcode" {
            return "codex-xcode"
        }
        return "codex"
    }

    private static func formattedError(_ error: Error) -> String {
        if let cliError = error as? NolonCoreCLIError {
            switch cliError {
            case let .invalidArguments(message):
                return "[invalid_arguments] \(message)"
            case let .executionFailed(message):
                return "[execution_failed] \(message)"
            case let .domainFailed(code, message):
                return "[\(code)] \(message)"
            case let .syncFailed(code, message, _):
                return "[\(code)] \(message)"
            }
        }
        return error.localizedDescription
    }
}
