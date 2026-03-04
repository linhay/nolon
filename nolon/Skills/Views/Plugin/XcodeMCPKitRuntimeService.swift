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
}

extension SKProcessPipeSession: XcodeMCPKitRuntimeSessioning {}

@MainActor
protocol XcodeMCPKitRuntimeServicing: AnyObject {
    var state: XcodeMCPKitRuntimeState { get }
    var onStateChange: ((XcodeMCPKitRuntimeState) -> Void)? { get set }
    func refreshStatus()
    func start() async
    func stop(force: Bool) async
}

@MainActor
final class XcodeMCPKitRuntimeService: XcodeMCPKitRuntimeServicing {
    private static let logger = Logger(subsystem: "com.nolon", category: "XcodeMCPKitRuntime")

    var onStateChange: ((XcodeMCPKitRuntimeState) -> Void)?

    private(set) var state: XcodeMCPKitRuntimeState = .idle {
        didSet { onStateChange?(state) }
    }

    private let executableResolver: () -> URL?
    private let sessionFactory: (URL) throws -> any XcodeMCPKitRuntimeSessioning
    private let nowProvider: () -> Date
    private let stopTimeoutNanoseconds: UInt64

    private var session: (any XcodeMCPKitRuntimeSessioning)?
    private var manualStopInProgress = false
    private var monitorTask: Task<Void, Never>?

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

        state = .starting
        manualStopInProgress = false
        monitorTask?.cancel()
        monitorTask = nil

        do {
            let session = try sessionFactory(executableURL)
            self.session = session
            let pid = session.pid
            state = .running(pid: pid, startedAt: nowProvider())
            Self.logger.info("xcodemcpkit started. pid=\(pid)")
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

        manualStopInProgress = true
        state = .stopping

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
            await session.sendSignal(SIGKILL)
        }

        monitorTask?.cancel()
        monitorTask = nil
        self.session = nil
        state = .idle
        manualStopInProgress = false
    }

    private func monitorExit(for session: any XcodeMCPKitRuntimeSessioning) async {
        do {
            let result = try await session.wait()
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.handleSessionFinished(result: result)
            }
        } catch {
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.handleSessionFailed(error: error)
            }
        }
    }

    private func handleSessionFinished(result: SKProcessResult) {
        self.session = nil
        if manualStopInProgress {
            state = .idle
            manualStopInProgress = false
            return
        }

        let status = result.exitCode
        if status == 0 {
            state = .idle
        } else {
            let details = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
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
        }
    }

    private func handleSessionFailed(error: Error) {
        self.session = nil
        if manualStopInProgress {
            state = .idle
            manualStopInProgress = false
            return
        }

        switch error {
        case let SKProcessRunError.nonZeroExit(exitCode, _, stderrData):
            let details = String(data: stderrData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
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
        default:
            state = .failed(message: error.localizedDescription)
        }
    }
}
