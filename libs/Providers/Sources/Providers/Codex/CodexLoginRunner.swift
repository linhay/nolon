import Foundation
import CodexCLIKit
import SKProcessRunner
import STFilePath
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public struct CodexLoginResult: Sendable, Equatable {
    public let authJSONString: String
    public let loginURL: String?

    public init(authJSONString: String, loginURL: String?) {
        self.authJSONString = authJSONString
        self.loginURL = loginURL
    }
}

public enum CodexLoginError: LocalizedError, Sendable, Equatable {
    case binaryNotFound(String)
    case launchFailed(String)
    case authNotCreated
    case authInvalidUTF8
    case loginTimedOut

    public var errorDescription: String? {
        switch self {
        case let .binaryNotFound(bin):
            "Missing CLI '\(bin)'. Install it (e.g. npm i -g @openai/codex) or add it to PATH."
        case let .launchFailed(msg):
            "Failed to launch Codex login: \(msg)"
        case .authNotCreated:
            "Login did not create auth.json."
        case .authInvalidUTF8:
            "Login created auth.json but content is not UTF-8."
        case .loginTimedOut:
            "Timed out waiting for auth.json."
        }
    }
}

public final class CodexLoginHandle: @unchecked Sendable {
    private let session: SKProcessPTYSession
    private let processIdentifier: Int32
    private let processExitState: ProcessExitState
    private let outputTask: Task<Void, Never>
    private let waitTask: Task<Void, Never>
    private let capture: LoginOutputCapture?

    fileprivate init(
        session: SKProcessPTYSession,
        processIdentifier: Int32,
        processExitState: ProcessExitState,
        outputTask: Task<Void, Never>,
        waitTask: Task<Void, Never>,
        capture: LoginOutputCapture?
    ) {
        self.session = session
        self.processIdentifier = processIdentifier
        self.processExitState = processExitState
        self.outputTask = outputTask
        self.waitTask = waitTask
        self.capture = capture
    }

    public var isRunning: Bool {
        guard !processExitState.hasExited else { return false }
        if Self.isProcessAlive(processIdentifier: processIdentifier) {
            return true
        }
        processExitState.markExited()
        return false
    }

    public func cancel(graceSeconds: TimeInterval = 0.8) {
        guard isRunning else { return }
        Task.detached {
            await self.session.terminate()
        }
        Self.terminateProcess(processIdentifier: processIdentifier, graceSeconds: graceSeconds)
        processExitState.markExited()
        outputTask.cancel()
        waitTask.cancel()
    }

    public var loginURL: String? {
        capture?.detectedURL
    }

    private static func terminateProcess(processIdentifier: Int32, graceSeconds: TimeInterval) {
        guard isProcessAlive(processIdentifier: processIdentifier) else { return }
        #if canImport(Darwin) || canImport(Glibc)
        _ = kill(-processIdentifier, SIGTERM)
        _ = kill(processIdentifier, SIGTERM)
        #endif
        let pollInterval: TimeInterval = 0.05
        let termDeadline = Date().addingTimeInterval(max(0.05, graceSeconds))
        while isProcessAlive(processIdentifier: processIdentifier), Date() < termDeadline {
            Thread.sleep(forTimeInterval: pollInterval)
        }

        guard isProcessAlive(processIdentifier: processIdentifier) else { return }
        #if canImport(Darwin) || canImport(Glibc)
        _ = kill(-processIdentifier, SIGKILL)
        _ = kill(processIdentifier, SIGKILL)
        let killDeadline = Date().addingTimeInterval(1.0)
        while isProcessAlive(processIdentifier: processIdentifier), Date() < killDeadline {
            Thread.sleep(forTimeInterval: pollInterval)
        }
        #endif
    }

    private static func isProcessAlive(processIdentifier: Int32) -> Bool {
        #if canImport(Darwin) || canImport(Glibc)
        if processIdentifier <= 0 {
            return false
        }
        if kill(processIdentifier, 0) == 0 {
            return true
        }
        return errno == EPERM
        #else
        return true
        #endif
    }
}

public struct CodexLoginRunner: Sendable {
    public init() {}

    public func startLogin(
        binary: String = "codex",
        environment: [String: String],
        codexHome: URL
    ) throws -> CodexLoginHandle {
        try startLogin(binary: binary, environment: environment, codexHome: STFolder(codexHome))
    }

    public func startLogin(
        binary: String = "codex",
        environment: [String: String],
        codexHome: STFolder
    ) throws -> CodexLoginHandle {
        let context = try startLoginSession(
            binary: binary,
            environment: environment,
            codexHome: codexHome,
            timeoutSeconds: 30 * 60,
            mirrorOutput: true,
            capture: LoginOutputCapture()
        )
        return CodexLoginHandle(
            session: context.session,
            processIdentifier: context.processIdentifier,
            processExitState: context.processExitState,
            outputTask: context.outputTask,
            waitTask: context.waitTask,
            capture: context.capture
        )
    }

    public func loginAndAwaitAuthJSONString(
        binary: String = "codex",
        environment: [String: String],
        codexHome: URL,
        timeoutSeconds: TimeInterval = 120,
        pollIntervalSeconds: TimeInterval = 0.25,
        processExitGraceSeconds: TimeInterval = 4
    ) async throws -> String {
        try await loginAndAwaitAuthResult(
            binary: binary,
            environment: environment,
            codexHome: STFolder(codexHome),
            timeoutSeconds: timeoutSeconds,
            pollIntervalSeconds: pollIntervalSeconds,
            processExitGraceSeconds: processExitGraceSeconds
        ).authJSONString
    }

    public func loginAndAwaitAuthJSONString(
        binary: String = "codex",
        environment: [String: String],
        codexHome: STFolder,
        timeoutSeconds: TimeInterval = 120,
        pollIntervalSeconds: TimeInterval = 0.25,
        processExitGraceSeconds: TimeInterval = 4
    ) async throws -> String {
        try await loginAndAwaitAuthResult(
            binary: binary,
            environment: environment,
            codexHome: codexHome,
            timeoutSeconds: timeoutSeconds,
            pollIntervalSeconds: pollIntervalSeconds,
            processExitGraceSeconds: processExitGraceSeconds
        ).authJSONString
    }

    public func loginAndAwaitAuthResult(
        binary: String = "codex",
        environment: [String: String],
        codexHome: URL,
        timeoutSeconds: TimeInterval = 120,
        pollIntervalSeconds: TimeInterval = 0.25,
        processExitGraceSeconds: TimeInterval = 4
    ) async throws -> CodexLoginResult {
        try await loginAndAwaitAuthResult(
            binary: binary,
            environment: environment,
            codexHome: STFolder(codexHome),
            timeoutSeconds: timeoutSeconds,
            pollIntervalSeconds: pollIntervalSeconds,
            processExitGraceSeconds: processExitGraceSeconds
        )
    }

    public func loginAndAwaitAuthResult(
        binary: String = "codex",
        environment: [String: String],
        codexHome: STFolder,
        timeoutSeconds: TimeInterval = 120,
        pollIntervalSeconds: TimeInterval = 0.25,
        processExitGraceSeconds: TimeInterval = 4
    ) async throws -> CodexLoginResult {
        let capture = LoginOutputCapture()
        let context = try startLoginSession(
            binary: binary,
            environment: environment,
            codexHome: codexHome,
            timeoutSeconds: max(timeoutSeconds + processExitGraceSeconds + 5, 10),
            mirrorOutput: true,
            capture: capture
        )

        let handle = CodexLoginHandle(
            session: context.session,
            processIdentifier: context.processIdentifier,
            processExitState: context.processExitState,
            outputTask: context.outputTask,
            waitTask: context.waitTask,
            capture: context.capture
        )

        defer {
            context.outputTask.cancel()
            context.waitTask.cancel()
            capture.detach()
            if handle.isRunning {
                handle.cancel()
            }
        }

        let authFile = codexHome.file("auth.json")
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        var processExitedAt: Date?
        let sleepNanoseconds = UInt64(max(0.01, pollIntervalSeconds) * 1_000_000_000)

        while true {
            try Task.checkCancellation()

            if authFile.isExists, let data = try? authFile.data(), !data.isEmpty {
                guard let raw = String(data: data, encoding: .utf8) else {
                    throw CodexLoginError.authInvalidUTF8
                }
                return CodexLoginResult(authJSONString: raw, loginURL: capture.detectedURL)
            }

            let hasExited = context.processExitState.hasExited || !handle.isRunning
            if hasExited {
                if processExitedAt == nil {
                    processExitedAt = Date()
                } else if Date().timeIntervalSince(processExitedAt!) >= processExitGraceSeconds {
                    throw CodexLoginError.authNotCreated
                }
            }

            if Date() >= deadline {
                if processExitedAt != nil {
                    throw CodexLoginError.authNotCreated
                }
                throw CodexLoginError.loginTimedOut
            }

            try await Task.sleep(nanoseconds: sleepNanoseconds)
        }
    }

    private struct LoginSessionContext {
        let session: SKProcessPTYSession
        let processIdentifier: Int32
        let processExitState: ProcessExitState
        let outputTask: Task<Void, Never>
        let waitTask: Task<Void, Never>
        let capture: LoginOutputCapture?
    }

    private func startLoginSession(
        binary: String,
        environment: [String: String],
        codexHome: STFolder,
        timeoutSeconds: TimeInterval,
        mirrorOutput: Bool,
        capture: LoginOutputCapture?
    ) throws -> LoginSessionContext {
        let env = Self.mergedEnvironment(environment: environment, codexHome: codexHome)
        let resolver = CodexCommandExecutor(executable: binary, environment: env)
        guard let resolved = resolver.resolveExecutable() else {
            throw CodexLoginError.binaryNotFound(binary)
        }

        let timeoutMs = Int(max(1.0, min(timeoutSeconds, 30 * 60)) * 1000.0)
        var payload = SKProcessPayload.executableURL(STFile(resolved).url)
        payload.arguments = ["login"]
        payload.environment = SKProcessEnvironment(env)
        payload.throwOnNonZeroExit = false
        payload.timeoutMs = timeoutMs
        payload.maxOutputBytes = 1024 * 1024
        payload.pty = SKProcessPTYConfiguration()

        let session: SKProcessPTYSession
        do {
            session = try SKProcessPTYSession(payload)
        } catch {
            throw CodexLoginError.launchFailed(error.localizedDescription)
        }

        let processExitState = ProcessExitState()
        let outputTask = Task.detached { [capture] in
            let stream = await session.output
            for await data in stream {
                if mirrorOutput {
                    FileHandle.standardOutput.write(data)
                }
                capture?.consume(data: data, mirrorTo: nil)
            }
        }
        let waitTask = Task.detached {
            _ = try? await session.wait()
            processExitState.markExited()
        }

        return LoginSessionContext(
            session: session,
            processIdentifier: session.pid,
            processExitState: processExitState,
            outputTask: outputTask,
            waitTask: waitTask,
            capture: capture
        )
    }

    private static func mergedEnvironment(environment: [String: String], codexHome: STFolder) -> [String: String] {
        let processEnv = ProcessInfo.processInfo.environment
        let shellEnv = SKProcessRunner.loadUserShellEnvironmentSync(environment: processEnv)
        var env = processEnv.merging(shellEnv, uniquingKeysWith: { _, shell in shell })
        env.merge(environment) { _, new in new }
        if env["PATH"]?.isEmpty != false,
           let shellPATH = SKProcessRunner.loadUserShellPATHSync(environment: processEnv) {
            env["PATH"] = shellPATH
        }
        env["CODEX_HOME"] = codexHome.url.path
        return env
    }

}

private final class ProcessExitState: @unchecked Sendable {
    private let lock = NSLock()
    private var exited = false

    func markExited() {
        lock.lock()
        exited = true
        lock.unlock()
    }

    var hasExited: Bool {
        lock.lock()
        defer { lock.unlock() }
        return exited
    }
}

private final class LoginOutputCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var loginURLStorage: String?
    private let regex = try? NSRegularExpression(pattern: #"https?://[^\s"'<>]+"#)

    var detectedURL: String? {
        lock.lock()
        defer { lock.unlock() }
        return loginURLStorage
    }

    func detach() {}

    func consume(data: Data, mirrorTo output: FileHandle?) {
        guard !data.isEmpty else { return }
        output?.write(data)
        guard let text = String(data: data, encoding: .utf8),
              let url = firstURL(in: text) else {
            return
        }
        lock.lock()
        defer { lock.unlock() }
        if loginURLStorage == nil {
            loginURLStorage = url
        }
    }

    private func firstURL(in text: String) -> String? {
        guard let regex else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              let matchRange = Range(match.range, in: text) else {
            return nil
        }
        return String(text[matchRange]).trimmingCharacters(in: CharacterSet(charactersIn: ".,);]"))
    }
}
