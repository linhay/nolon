import Foundation
import OSLog
import SKProcessRunner
import NolonResourceKit

enum XcodeMCPKitRuntimeState: Equatable {
    case idle
    case starting
    case running(pid: Int32, startedAt: Date)
    case stopping
    case failed(message: String)

    var isBusy: Bool {
        switch self {
        case .starting, .stopping:
            return true
        default:
            return false
        }
    }
}

protocol XcodeMCPKitRuntimeSessioning: AnyObject {
    var pid: Int32 { get }
    func wait() async throws -> SKProcessResult
    func terminate() async
    func isRunning() async -> Bool
    func sendSignal(_ signal: Int32) async
    func stdoutStream() async -> AsyncStream<Data>
    func stderrStream() async -> AsyncStream<Data>
}

extension SKProcessPipeSession: XcodeMCPKitRuntimeSessioning {
    func stdoutStream() async -> AsyncStream<Data> { stdout }
    func stderrStream() async -> AsyncStream<Data> { stderr }
}

@MainActor
protocol XcodeMCPKitRuntimeServicing: AnyObject {
    var state: XcodeMCPKitRuntimeState { get }
    var logsText: String { get }
    var onStateChange: ((XcodeMCPKitRuntimeState) -> Void)? { get set }
    var onLogsChange: ((String) -> Void)? { get set }
    func refreshStatus()
    func start() async
    func stop(force: Bool) async
    func clearLogs()
}

@MainActor
final class XcodeMCPKitRuntimeService: XcodeMCPKitRuntimeServicing {
    private static let logger = Logger(subsystem: "com.nolon", category: "XcodeMCPKitRuntime")

    var onStateChange: ((XcodeMCPKitRuntimeState) -> Void)?
    var onLogsChange: ((String) -> Void)?

    private(set) var state: XcodeMCPKitRuntimeState = .idle {
        didSet { onStateChange?(state) }
    }
    private(set) var logsText: String = "" {
        didSet { onLogsChange?(logsText) }
    }

    private let executableResolver: () -> URL?
    private let sessionFactory: (URL) throws -> any XcodeMCPKitRuntimeSessioning
    private let nowProvider: () -> Date
    private let stopTimeoutNanoseconds: UInt64

    private var session: (any XcodeMCPKitRuntimeSessioning)?
    private var manualStopInProgress = false
    private var expectedStopPIDs = Set<Int32>()
    private var monitorTask: Task<Void, Never>?
    private var stdoutTask: Task<Void, Never>?
    private var stderrTask: Task<Void, Never>?
    private var logLines: [String] = []
    private let maxLogLines = 2000
    private let preKillSnapshotLineCount = 8

    init(
        executableResolver: (() -> URL?)? = nil,
        sessionFactory: ((URL) throws -> (any XcodeMCPKitRuntimeSessioning))? = nil,
        nowProvider: @escaping () -> Date = { Date() },
        stopTimeoutNanoseconds: UInt64 = 3_000_000_000
    ) {
        self.executableResolver = executableResolver ?? {
            let local = NolonManager.shared.rootURL
                .appendingPathComponent("bin", isDirectory: true)
                .appendingPathComponent("xcodemcpkit", isDirectory: false)
            if FileManager.default.isExecutableFile(atPath: local.path) {
                return local
            }
            return SKProcessRunner.resolveExecutableInPath(
                named: "xcodemcpkit",
                environment: ProcessInfo.processInfo.environment
            )
        }
        self.sessionFactory = sessionFactory ?? { executableURL in
            var payload = SKProcessPayload.executableURL(executableURL)
            payload = payload.timeoutMs(30 * 60 * 1000)
            payload = payload.maxOutputBytes(2 * 1024 * 1024)
            payload = payload.terminationGracePeriodMs(3_000)
            payload = payload.throwOnNonZeroExit()
            return try SKProcessPipeSession(payload)
        }
        self.nowProvider = nowProvider
        self.stopTimeoutNanoseconds = stopTimeoutNanoseconds
    }

    func refreshStatus() {
        guard let session else {
            state = .idle
            return
        }

        let pid = session.pid
        if case .running = state {
            return
        }
        state = .running(pid: pid, startedAt: nowProvider())
        Self.logger.debug("Refresh runtime status -> running pid=\(pid)")
    }

    func clearLogs() {
        logLines.removeAll(keepingCapacity: true)
        logsText = ""
    }

    func start() async {
        switch state {
        case .starting, .running:
            return
        case .stopping:
            return
        case .idle, .failed:
            break
        }

        guard let executableURL = executableResolver() else {
            state = .failed(
                message: NSLocalizedString(
                    "plugin.runtime.error.binary_not_found",
                    value: "Cannot find `xcodemcpkit` in PATH.",
                    comment: "XcodeMCPKit binary missing"
                )
            )
            return
        }
        Self.logger.info("Starting xcodemcpkit from \(executableURL.path, privacy: .public)")

        state = .starting
        manualStopInProgress = false
        monitorTask?.cancel()
        monitorTask = nil
        stdoutTask?.cancel()
        stderrTask?.cancel()
        stdoutTask = nil
        stderrTask = nil

        do {
            let session = try sessionFactory(executableURL)
            self.session = session
            let pid = session.pid
            state = .running(pid: pid, startedAt: nowProvider())
            Self.logger.info("xcodemcpkit started. pid=\(pid)")
            appendRuntimeLog("[system] started pid=\(pid)")
            stdoutTask = Task { [weak self] in
                guard let self else { return }
                let stream = await session.stdoutStream()
                for await data in stream {
                    await MainActor.run {
                        self.appendRuntimeLogData(data, source: "stdout")
                    }
                }
            }
            stderrTask = Task { [weak self] in
                guard let self else { return }
                let stream = await session.stderrStream()
                for await data in stream {
                    await MainActor.run {
                        self.appendRuntimeLogData(data, source: "stderr")
                    }
                }
            }
            monitorTask = Task { [weak self] in
                guard let self else { return }
                await self.monitorExit(for: session)
            }
        } catch {
            self.session = nil
            state = .failed(message: error.localizedDescription)
            Self.logger.error("Failed to start xcodemcpkit: \(error.localizedDescription, privacy: .public)")
        }
    }

    func stop(force: Bool = false) async {
        guard let session else {
            state = .idle
            return
        }

        if case .stopping = state {
            return
        }

        let stoppingPID = session.pid
        expectedStopPIDs.insert(stoppingPID)
        manualStopInProgress = true
        state = .stopping
        Self.logger.info("Stopping xcodemcpkit pid=\(stoppingPID), force=\(force)")

        if force {
            await session.sendSignal(SIGKILL)
        } else {
            await session.terminate()
        }

        let step: UInt64 = 100_000_000
        var waited: UInt64 = 0

        while await session.isRunning() && waited < stopTimeoutNanoseconds {
            try? await Task.sleep(nanoseconds: step)
            waited += step
        }

        if await session.isRunning() {
            Self.logger.warning("xcodemcpkit pid=\(stoppingPID) did not exit in time, sending SIGKILL")
            await session.sendSignal(SIGKILL)
        }

        monitorTask?.cancel()
        stdoutTask?.cancel()
        stderrTask?.cancel()
        monitorTask = nil
        stdoutTask = nil
        stderrTask = nil
        self.session = nil
        state = .idle
        manualStopInProgress = false
        Self.logger.info("xcodemcpkit stop flow completed for pid=\(stoppingPID)")
        appendRuntimeLog("[system] stop completed pid=\(stoppingPID)")
    }

    private func monitorExit(for session: any XcodeMCPKitRuntimeSessioning) async {
        do {
            let result = try await session.wait()
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.handleSessionFinished(result: result, pid: session.pid)
            }
        } catch {
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.handleSessionFailed(error: error, pid: session.pid)
            }
        }
    }

    private func handleSessionFinished(result: SKProcessResult, pid: Int32) {
        self.session = nil
        stdoutTask?.cancel()
        stderrTask?.cancel()
        stdoutTask = nil
        stderrTask = nil
        if manualStopInProgress || expectedStopPIDs.contains(pid) {
            expectedStopPIDs.remove(pid)
            state = .idle
            manualStopInProgress = false
            Self.logger.info("xcodemcpkit pid=\(pid) exited during expected stop flow")
            appendRuntimeLog("[system] exited during expected stop pid=\(pid)")
            return
        }

        let status = result.exitCode
        if status == 0 {
            state = .idle
            Self.logger.info("xcodemcpkit exited cleanly pid=\(pid)")
            appendRuntimeLog("[system] exited cleanly pid=\(pid)")
        } else {
            let details = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if status == 9 && details.isEmpty {
                state = .idle
                Self.logger.warning("xcodemcpkit exited with SIGKILL pid=\(pid), treating as stopped")
                appendRuntimeLog("[system] exited with SIGKILL pid=\(pid), treated as stopped")
                appendPreKillOutputSnapshotIfNeeded()
                return
            }
            if details.isEmpty {
                state = .failed(
                    message: String(
                        format: NSLocalizedString(
                            "plugin.runtime.error.exited",
                            value: "XcodeMCPKit exited unexpectedly (%d).",
                            comment: "XcodeMCPKit terminated unexpectedly"
                        ),
                        status
                    )
                )
            } else {
                state = .failed(message: details)
            }
            Self.logger.error("xcodemcpkit exited unexpectedly pid=\(pid), code=\(status), stderr=\(result.stderr, privacy: .public)")
            appendRuntimeLog("[system] exited unexpectedly pid=\(pid) code=\(status)")
        }
    }

    private func handleSessionFailed(error: Error, pid: Int32) {
        self.session = nil
        stdoutTask?.cancel()
        stderrTask?.cancel()
        stdoutTask = nil
        stderrTask = nil
        if manualStopInProgress || expectedStopPIDs.contains(pid) {
            expectedStopPIDs.remove(pid)
            state = .idle
            manualStopInProgress = false
            Self.logger.info("xcodemcpkit pid=\(pid) failure ignored due to expected stop: \(error.localizedDescription, privacy: .public)")
            appendRuntimeLog("[system] failure ignored due to expected stop pid=\(pid): \(error.localizedDescription)")
            return
        }

        switch error {
        case let SKProcessRunError.nonZeroExit(exitCode, _, stderrData):
            let details = String(data: stderrData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if exitCode == 9 && details.isEmpty {
                state = .idle
                Self.logger.warning("xcodemcpkit runtime SIGKILL pid=\(pid), treating as stopped")
                appendRuntimeLog("[system] runtime SIGKILL pid=\(pid), treated as stopped")
                appendPreKillOutputSnapshotIfNeeded()
                return
            }
            if details.isEmpty {
                state = .failed(
                    message: String(
                        format: NSLocalizedString(
                            "plugin.runtime.error.exited",
                            value: "XcodeMCPKit exited unexpectedly (%d).",
                            comment: "XcodeMCPKit terminated unexpectedly"
                        ),
                        exitCode
                    )
                )
            } else {
                state = .failed(message: details)
            }
            Self.logger.error("xcodemcpkit runtime error pid=\(pid), exit=\(exitCode), stderr=\(details, privacy: .public)")
            appendRuntimeLog("[system] runtime error pid=\(pid) exit=\(exitCode): \(details)")
        default:
            state = .failed(message: error.localizedDescription)
            Self.logger.error("xcodemcpkit runtime error pid=\(pid): \(error.localizedDescription, privacy: .public)")
            appendRuntimeLog("[system] runtime error pid=\(pid): \(error.localizedDescription)")
        }
    }

    private func appendRuntimeLogData(_ data: Data, source: String) {
        guard !data.isEmpty else { return }
        let content = String(decoding: data, as: UTF8.self)
        appendRuntimeLog("[\(source)] \(content)")
    }

    private func appendRuntimeLog(_ message: String) {
        let cleaned = message.replacingOccurrences(of: "\r", with: "")
        let lines = cleaned.split(separator: "\n", omittingEmptySubsequences: false)
        let timestamp = ISO8601DateFormatter().string(from: Date())
        for line in lines {
            let entry = "\(timestamp) \(line)"
            logLines.append(entry)
        }
        if logLines.count > maxLogLines {
            logLines.removeFirst(logLines.count - maxLogLines)
        }
        logsText = logLines.joined(separator: "\n")
    }

    private func appendPreKillOutputSnapshotIfNeeded() {
        let outputLines = logLines.filter { !$0.contains("[system]") && !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let snapshot = Array(outputLines.suffix(preKillSnapshotLineCount))
        guard !snapshot.isEmpty else { return }
        appendRuntimeLog("[system] pre-kill output snapshot begin")
        for line in snapshot {
            appendRuntimeLog("[snapshot] \(line)")
        }
        appendRuntimeLog("[system] pre-kill output snapshot end")
    }
}
