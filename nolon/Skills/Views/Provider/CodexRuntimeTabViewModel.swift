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
    let workingDirectory: String?

    init(
        pid: Int32,
        ppid: Int32?,
        elapsed: String,
        providerHint: String?,
        command: String,
        workingDirectory: String? = nil
    ) {
        self.pid = pid
        self.ppid = ppid
        self.elapsed = elapsed
        self.providerHint = providerHint
        self.command = command
        self.workingDirectory = workingDirectory
    }

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
    let activeAccountName: String?
    let activeAccountEmail: String?
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
            activeAccountName: nil,
            activeAccountEmail: nil,
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

struct CodexRuntimeProcessDiagnosticField: Equatable {
    enum Key: String, Equatable {
        case provider
        case accounts
        case active
        case running
        case binary
        case pathActive = "path_active"
        case executable
        case hint
    }

    let key: Key
    let value: String
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
                command: $0.command,
                workingDirectory: $0.workingDirectory
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
        async let authList = codexService.authList(providerID: providerID)
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
        let authListPayload = try await authList
        let binaryPayload = try await binary
        let runtimePayload = try await runtime
        let activeID = authPayload.activeAccountID ?? authListPayload.activeAccountID
        let activeAccount = activeID.flatMap { id in
            authListPayload.accounts.first(where: { $0.id == id })
        }

        return CodexRuntimeDiagnosticsSnapshot(
            providerID: providerID,
            accountCount: authPayload.accountCount,
            activeAccountID: activeID?.uuidString,
            activeAccountName: Self.normalizedNonEmpty(activeAccount?.name),
            activeAccountEmail: Self.normalizedNonEmpty(activeAccount?.email),
            selectedVersionID: binaryPayload.selectedVersionID,
            currentVersion: binaryPayload.currentVersion,
            pathActive: binaryPayload.pathActive,
            runtimeCount: runtimePayload.processes.count,
            resolvedExecutable: probe?.resolvedExecutable,
            probeWarning: probe?.probeWarning ?? probeFallbackWarning,
            probeHint: probe?.probeHint
        )
    }

    private static func normalizedNonEmpty(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
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

    nonisolated private static func liveCommandRunner(pid: Int32, lastSeconds: Int) throws -> String {
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
    private let pollingIntervalNanoseconds: UInt64
    private var pollingTask: Task<Void, Never>?
    private var isPollingProcessList = false

    init(
        provider: Provider,
        runtimeService: (any CodexRuntimeTabServicing)? = nil,
        logService: (any CodexPIDSystemLogServicing)? = nil,
        pollingIntervalNanoseconds: UInt64 = 5_000_000_000
    ) {
        self.provider = provider
        self.runtimeService = runtimeService ?? CodexRuntimeCLIService()
        self.logService = logService ?? CodexPIDSystemLogService()
        self.pollingIntervalNanoseconds = pollingIntervalNanoseconds
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

    func startProcessPolling() {
        guard pollingTask == nil else { return }

        pollingTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: self.pollingIntervalNanoseconds)
                } catch {
                    break
                }
                if Task.isCancelled {
                    break
                }
                await self.pollProcessesOnly()
            }
        }
    }

    func stopProcessPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    var canonicalProviderID: String {
        if provider.templateId == "codexXcode" {
            return "codex-xcode"
        }
        return "codex"
    }

    func processDiagnosticsRows(for process: CodexRuntimeProcessItem) -> [CodexRuntimeProcessDiagnosticField] {
        guard let diagnostics else { return [] }

        let providerValue: String = {
            let trimmed = process.providerHint?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? diagnostics.providerID : trimmed
        }()

        return [
            .init(key: .provider, value: providerValue),
            .init(key: .accounts, value: "\(diagnostics.accountCount)"),
            .init(key: .active, value: activeAccountDisplayText(for: diagnostics)),
            .init(key: .running, value: "\(diagnostics.runtimeCount)"),
            .init(key: .binary, value: diagnostics.currentVersion ?? "-"),
            .init(key: .pathActive, value: diagnostics.pathActive ? "true" : "false"),
            .init(key: .executable, value: diagnostics.resolvedExecutable ?? "-"),
            .init(key: .hint, value: diagnostics.probeHint ?? diagnostics.probeWarning ?? "-")
        ]
    }

    private func activeAccountDisplayText(for diagnostics: CodexRuntimeDiagnosticsSnapshot) -> String {
        let id = Self.normalizedNonEmpty(diagnostics.activeAccountID)
        let name = Self.normalizedNonEmpty(diagnostics.activeAccountName)
        let email = Self.normalizedNonEmpty(diagnostics.activeAccountEmail)

        guard id != nil || name != nil || email != nil else { return "-" }

        let identity: String? = {
            if let name, let email {
                return "\(name) (\(email))"
            }
            if let email {
                return email
            }
            return name
        }()

        if let identity, let id {
            return "\(identity) [id: \(abbreviatedID(id))]"
        }
        if let identity {
            return identity
        }
        if let id {
            return id
        }
        return "-"
    }

    private func abbreviatedID(_ raw: String) -> String {
        guard raw.count > 8 else { return raw }
        return "\(raw.prefix(4))...\(raw.suffix(4))"
    }

    private static func normalizedNonEmpty(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
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

    private func pollProcessesOnly() async {
        guard !isRefreshing, !isStopping, !isPollingProcessList else { return }
        isPollingProcessList = true
        defer { isPollingProcessList = false }

        do {
            let latest = try await runtimeService.runtimeList(providerID: canonicalProviderID)
            processes = latest.sorted(by: { $0.pid < $1.pid })

            if let selectedPID, !processes.contains(where: { $0.pid == selectedPID }) {
                self.selectedPID = processes.first?.pid
                await refreshSelectedProcessLogs()
            } else if selectedPID == nil, !processes.isEmpty {
                selectedPID = processes.first?.pid
                await refreshSelectedProcessLogs()
            }
        } catch {
            Self.logger.error("Runtime process polling failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
