import Foundation
import CodexCLIKit
import SKProcessRunner
import STFilePath

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
    private let process: Process

    init(process: Process) {
        self.process = process
    }

    public var isRunning: Bool {
        process.isRunning
    }

    public func cancel() {
        if process.isRunning {
            process.terminate()
        }
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
        let env = Self.mergedEnvironment(environment: environment, codexHome: codexHome)
        let resolver = CodexCommandExecutor(executable: binary, environment: env)
        guard let resolved = resolver.resolveExecutable() else {
            throw CodexLoginError.binaryNotFound(binary)
        }

        let process = Process()
        process.executableURL = STFile(resolved).url
        process.arguments = ["login"]
        process.environment = env
        process.standardInput = nil
        process.standardOutput = nil
        process.standardError = nil

        do {
            try process.run()
        } catch {
            throw CodexLoginError.launchFailed(error.localizedDescription)
        }

        return CodexLoginHandle(process: process)
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
        let env = Self.mergedEnvironment(environment: environment, codexHome: codexHome)
        let resolver = CodexCommandExecutor(executable: binary, environment: env)
        guard let resolved = resolver.resolveExecutable() else {
            throw CodexLoginError.binaryNotFound(binary)
        }

        let process = Process()
        process.executableURL = STFile(resolved).url
        process.arguments = ["login"]
        process.environment = env
        process.standardInput = nil

        let capture = LoginOutputCapture()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        capture.attach(stdout: stdoutPipe.fileHandleForReading, stderr: stderrPipe.fileHandleForReading)

        do {
            try process.run()
        } catch {
            capture.detach(stdout: stdoutPipe.fileHandleForReading, stderr: stderrPipe.fileHandleForReading)
            throw CodexLoginError.launchFailed(error.localizedDescription)
        }

        let handle = CodexLoginHandle(process: process)
        defer {
            capture.detach(stdout: stdoutPipe.fileHandleForReading, stderr: stderrPipe.fileHandleForReading)
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

            if !handle.isRunning {
                if processExitedAt == nil {
                    processExitedAt = Date()
                } else if Date().timeIntervalSince(processExitedAt!) >= processExitGraceSeconds {
                    throw CodexLoginError.authNotCreated
                }
            }

            if Date() >= deadline {
                throw CodexLoginError.loginTimedOut
            }

            try await Task.sleep(nanoseconds: sleepNanoseconds)
        }
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

private final class LoginOutputCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var loginURLStorage: String?
    private let regex = try? NSRegularExpression(pattern: #"https?://[^\s"'<>]+"#)

    var detectedURL: String? {
        lock.lock()
        defer { lock.unlock() }
        return loginURLStorage
    }

    func attach(stdout: FileHandle, stderr: FileHandle) {
        stdout.readabilityHandler = { [weak self] handle in
            self?.consume(data: handle.availableData, mirrorTo: .standardOutput)
        }
        stderr.readabilityHandler = { [weak self] handle in
            self?.consume(data: handle.availableData, mirrorTo: .standardError)
        }
    }

    func detach(stdout: FileHandle, stderr: FileHandle) {
        stdout.readabilityHandler = nil
        stderr.readabilityHandler = nil
    }

    private func consume(data: Data, mirrorTo output: FileHandle) {
        guard !data.isEmpty else { return }
        output.write(data)
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
