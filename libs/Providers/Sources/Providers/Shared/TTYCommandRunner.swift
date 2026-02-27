#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import Foundation
import SKProcessRunner
import STFilePath

/// Executes an interactive CLI inside a pseudo-terminal and returns all captured text.
public struct TTYCommandRunner: Sendable {
    public struct Result: Sendable {
        public let text: String

        public init(text: String) {
            self.text = text
        }
    }

    public struct Options: Sendable {
        public var rows: UInt16 = 50
        public var cols: UInt16 = 160
        public var timeout: TimeInterval = 20.0
        public var idleTimeout: TimeInterval?
        public var workingDirectory: URL?
        public var extraArgs: [String] = []
        public var initialDelay: TimeInterval = 0.4
        public var sendEnterEvery: TimeInterval?
        public var sendOnSubstrings: [String: String]
        public var stopOnURL: Bool
        public var stopOnSubstrings: [String]
        public var settleAfterStop: TimeInterval

        public init(
            rows: UInt16 = 50,
            cols: UInt16 = 160,
            timeout: TimeInterval = 20.0,
            idleTimeout: TimeInterval? = nil,
            workingDirectory: URL? = nil,
            extraArgs: [String] = [],
            initialDelay: TimeInterval = 0.4,
            sendEnterEvery: TimeInterval? = nil,
            sendOnSubstrings: [String: String] = [:],
            stopOnURL: Bool = false,
            stopOnSubstrings: [String] = [],
            settleAfterStop: TimeInterval = 0.25)
        {
            self.rows = rows
            self.cols = cols
            self.timeout = timeout
            self.idleTimeout = idleTimeout
            self.workingDirectory = workingDirectory
            self.extraArgs = extraArgs
            self.initialDelay = initialDelay
            self.sendEnterEvery = sendEnterEvery
            self.sendOnSubstrings = sendOnSubstrings
            self.stopOnURL = stopOnURL
            self.stopOnSubstrings = stopOnSubstrings
            self.settleAfterStop = settleAfterStop
        }
    }

    public enum Error: Swift.Error, LocalizedError, Sendable, Equatable {
        case binaryNotFound(String)
        case launchFailed(String)
        case timedOut

        public var errorDescription: String? {
            switch self {
            case let .binaryNotFound(bin):
                "Missing CLI '\(bin)'. Install it (e.g. npm i -g @openai/codex) or add it to PATH."
            case let .launchFailed(msg): "Failed to launch process: \(msg)"
            case .timedOut: "PTY command timed out."
            }
        }
    }

    public init() {}

    public static func which(
        _ command: String,
        env: [String: String] = ProcessInfo.processInfo.environment
    ) -> String?
    {
        if command.contains("/") {
            return isExecutable(command) ? command : nil
        }
        if let url = SKProcessRunner.resolveExecutableInPath(named: command, environment: env) {
            return url.path
        }
        if let url = SKProcessRunner.resolveExecutableInUserShellSync(named: command, environment: env) {
            return url.path
        }
        return nil
    }

    private static func isExecutable(_ path: String) -> Bool {
        let file = STFile(path)
        guard file.isExists else { return false }
        return file.permission.contains(.executable)
    }

    public func run(binary: String, send: String, options: Options = Options()) throws -> Result {
        let resolvedBinary: String
        if let located = Self.which(binary) {
            resolvedBinary = located
        } else {
            throw Error.binaryNotFound(binary)
        }

        var env = ProcessInfo.processInfo.environment
        env["PATH"] = env["PATH"] ?? "/usr/local/bin:/usr/bin:/bin"

        var payload = SKProcessPayload.executableURL(STFile(resolvedBinary).url)
        payload.arguments = options.extraArgs
        payload.stdinData = send.isEmpty ? nil : Data(send.utf8)
        payload.cwd = options.workingDirectory
        payload.environment = SKProcessEnvironment(env)
        payload.throwOnNonZeroExit = false
        payload.timeoutMs = Int(max(1.0, options.timeout + 2.0) * 1000.0)
        payload.maxOutputBytes = 2 * 1024 * 1024
        payload.pty = SKProcessPTYConfiguration(rows: Int(options.rows), cols: Int(options.cols))

        do {
            let result = try SKProcessRunner.runPTYSync(payload)
            let text = Self.combine(stdout: result.stdout, stderr: result.stderr)
            return Result(text: text)
        } catch let error as SKProcessRunError {
            switch error {
            case .timedOut:
                throw Error.timedOut
            default:
                throw Error.launchFailed(error.localizedDescription)
            }
        } catch {
            throw Error.launchFailed(error.localizedDescription)
        }
    }
}

extension TTYCommandRunner {
    public func run(binary: String, send: String, options: Options = Options()) async throws -> Result {
        try await runInternal(binary: binary, send: send, options: options)
    }
}

private extension TTYCommandRunner {
    final class TimeoutState: @unchecked Sendable {
        private let lock = NSLock()
        private var timedOut = false

        func markTimeout() {
            lock.lock()
            timedOut = true
            lock.unlock()
        }

        var isTimedOut: Bool {
            lock.lock()
            defer { lock.unlock() }
            return timedOut
        }
    }

    final class OutputState: @unchecked Sendable {
        private let lock = NSLock()
        private var text = ""
        private var lastOutputAt = Date()
        private var stopRequested = false
        private var sentKeys = Set<String>()

        func append(_ chunk: String) {
            lock.lock()
            text += chunk
            lastOutputAt = Date()
            lock.unlock()
        }

        func snapshot() -> String {
            lock.lock()
            defer { lock.unlock() }
            return text
        }

        func idleDuration() -> TimeInterval {
            lock.lock()
            defer { lock.unlock() }
            return Date().timeIntervalSince(lastOutputAt)
        }

        func markStopRequested() {
            lock.lock()
            stopRequested = true
            lock.unlock()
        }

        var isStopRequested: Bool {
            lock.lock()
            defer { lock.unlock() }
            return stopRequested
        }

        func consumePendingSendText(from map: [String: String]) -> [String] {
            lock.lock()
            defer { lock.unlock() }
            var pending: [String] = []
            for (key, value) in map where text.contains(key) {
                if sentKeys.insert(key).inserted {
                    pending.append(value)
                }
            }
            return pending
        }
    }

    func runInternal(binary: String, send: String, options: Options) async throws -> Result {
        let resolvedBinary: String
        if let located = Self.which(binary) {
            resolvedBinary = located
        } else {
            throw Error.binaryNotFound(binary)
        }

        var env = ProcessInfo.processInfo.environment
        env["PATH"] = env["PATH"] ?? "/usr/local/bin:/usr/bin:/bin"

        var payload = SKProcessPayload.executableURL(STFile(resolvedBinary).url)
        payload.arguments = options.extraArgs
        payload.cwd = options.workingDirectory
        payload.environment = SKProcessEnvironment(env)
        payload.throwOnNonZeroExit = false
        payload.timeoutMs = Int(max(1.0, options.timeout + 2.0) * 1000.0)
        payload.maxOutputBytes = 2 * 1024 * 1024
        payload.pty = SKProcessPTYConfiguration(rows: Int(options.rows), cols: Int(options.cols))

        let session: SKProcessPTYSession
        do {
            session = try SKProcessPTYSession(payload)
        } catch {
            throw Error.launchFailed(error.localizedDescription)
        }

        let timeoutState = TimeoutState()
        let outputState = OutputState()
        let watchdogTask = Task.detached(priority: .utility) {
            let startedAt = Date()
            while await session.isRunning() {
                if Date().timeIntervalSince(startedAt) >= options.timeout {
                    timeoutState.markTimeout()
                    await session.terminate()
                    return
                }
                if let idleTimeout = options.idleTimeout,
                   outputState.idleDuration() >= idleTimeout
                {
                    timeoutState.markTimeout()
                    await session.terminate()
                    return
                }
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
        }

        let initialSendTask = Task.detached(priority: .utility) {
            guard !send.isEmpty else { return }
            let delay = max(0, options.initialDelay)
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            try? await session.send(Data(send.utf8))
            try? await session.close()
        }

        let enterTask = Task.detached(priority: .utility) {
            guard let interval = options.sendEnterEvery, interval > 0 else { return }
            let sleepNs = UInt64(interval * 1_000_000_000)
            while await session.isRunning() {
                try? await Task.sleep(nanoseconds: sleepNs)
                guard await session.isRunning() else { return }
                try? await session.send(Data("\n".utf8))
            }
        }

        let stream = await session.output
        for await data in stream {
            guard !data.isEmpty else { continue }
            guard let text = String(data: data, encoding: .utf8), !text.isEmpty else { continue }
            outputState.append(text)

            let pendingText = outputState.consumePendingSendText(from: options.sendOnSubstrings)
            for value in pendingText {
                try? await session.send(Data(value.utf8))
            }

            if shouldStop(output: outputState.snapshot(), options: options) {
                outputState.markStopRequested()
                let settle = max(0, options.settleAfterStop)
                if settle > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(settle * 1_000_000_000))
                }
                await session.terminate()
                break
            }
        }

        initialSendTask.cancel()
        enterTask.cancel()
        watchdogTask.cancel()
        _ = try? await session.wait()

        if timeoutState.isTimedOut {
            throw Error.timedOut
        }

        return Result(text: outputState.snapshot())
    }

    func shouldStop(output: String, options: Options) -> Bool {
        if options.stopOnSubstrings.contains(where: { output.contains($0) }) {
            return true
        }
        guard options.stopOnURL else { return false }
        return output.range(of: #"https?://[^\s"'<>]+"#, options: .regularExpression) != nil
    }

    static func combine(stdout: String, stderr: String) -> String {
        if stdout.isEmpty { return stderr }
        if stderr.isEmpty { return stdout }
        return stdout + "\n" + stderr
    }
}
