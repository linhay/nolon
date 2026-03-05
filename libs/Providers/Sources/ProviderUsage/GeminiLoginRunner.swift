import Foundation
import SKProcessRunner
import CodexBarProviderCatalog
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public struct GeminiLoginResult: Sendable, Equatable {
    public let accountID: UUID
    public let loginURL: String?
    public let runtimeHomeURL: URL

    public init(accountID: UUID, loginURL: String?, runtimeHomeURL: URL) {
        self.accountID = accountID
        self.loginURL = loginURL
        self.runtimeHomeURL = runtimeHomeURL
    }
}

public enum GeminiLoginError: LocalizedError, Sendable, Equatable {
    case binaryNotFound(String)
    case launchFailed(String)
    case loginTimedOut
    case authNotCompleted

    public var errorDescription: String? {
        switch self {
        case let .binaryNotFound(binary):
            return "Missing CLI '\(binary)'. Install Gemini CLI and make it available in PATH."
        case let .launchFailed(message):
            return "Failed to launch Gemini login: \(message)"
        case .loginTimedOut:
            return "Timed out waiting for Gemini authentication."
        case .authNotCompleted:
            return "Gemini authentication did not complete."
        }
    }
}

public final class GeminiLoginHandle: @unchecked Sendable {
    private let session: SKProcessPTYSession
    private let pid: Int32
    private let capture: GeminiLoginOutputCapture
    private let outputTask: Task<Void, Never>
    private let waitTask: Task<Void, Never>
    private let state: GeminiProcessExitState

    fileprivate init(
        session: SKProcessPTYSession,
        pid: Int32,
        capture: GeminiLoginOutputCapture,
        outputTask: Task<Void, Never>,
        waitTask: Task<Void, Never>,
        state: GeminiProcessExitState
    ) {
        self.session = session
        self.pid = pid
        self.capture = capture
        self.outputTask = outputTask
        self.waitTask = waitTask
        self.state = state
    }

    public var loginURL: String? {
        capture.detectedURL
    }

    public var isRunning: Bool {
        guard !state.hasExited else { return false }
        return Self.isProcessAlive(pid: pid)
    }

    public func cancel(graceSeconds: TimeInterval = 0.8) {
        guard isRunning else { return }
        Task.detached { await self.session.terminate() }
        Self.terminate(pid: pid, graceSeconds: graceSeconds)
        state.markExited()
        outputTask.cancel()
        waitTask.cancel()
    }

    private static func isProcessAlive(pid: Int32) -> Bool {
        #if canImport(Darwin) || canImport(Glibc)
        if pid <= 0 { return false }
        if kill(pid, 0) == 0 { return true }
        return errno == EPERM
        #else
        return true
        #endif
    }

    private static func terminate(pid: Int32, graceSeconds: TimeInterval) {
        #if canImport(Darwin) || canImport(Glibc)
        _ = kill(-pid, SIGTERM)
        _ = kill(pid, SIGTERM)
        #endif
        let deadline = Date().addingTimeInterval(max(graceSeconds, 0.1))
        while isProcessAlive(pid: pid), Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        #if canImport(Darwin) || canImport(Glibc)
        if isProcessAlive(pid: pid) {
            _ = kill(-pid, SIGKILL)
            _ = kill(pid, SIGKILL)
        }
        #endif
    }
}

public struct GeminiLoginRunner: Sendable {
    public init() {}

    public func startOAuthLogin(
        provider: UsageProvider,
        accountID: UUID,
        runtimeHomeURL: URL,
        binary: String = "gemini",
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> GeminiLoginHandle {
        let capture = GeminiLoginOutputCapture()
        let mergedEnv = Self.loginEnvironment(
            provider: provider,
            runtimeHomeURL: runtimeHomeURL,
            base: environment
        )
        try Self.writeSettings(runtimeHomeURL: runtimeHomeURL, authType: .oauthPersonal)
        let session = try Self.startSession(
            binary: binary,
            environment: mergedEnv,
            capture: capture
        )
        return GeminiLoginHandle(
            session: session.session,
            pid: session.session.pid,
            capture: capture,
            outputTask: session.outputTask,
            waitTask: session.waitTask,
            state: session.exitState
        )
    }

    public func loginWithOAuthAndAwait(
        provider: UsageProvider,
        accountID: UUID,
        runtimeHomeURL: URL,
        binary: String = "gemini",
        environment: [String: String] = ProcessInfo.processInfo.environment,
        timeoutSeconds: TimeInterval = 300,
        pollIntervalSeconds: TimeInterval = 0.25,
        processExitGraceSeconds: TimeInterval = 4
    ) async throws -> GeminiLoginResult {
        let handle = try startOAuthLogin(
            provider: provider,
            accountID: accountID,
            runtimeHomeURL: runtimeHomeURL,
            binary: binary,
            environment: environment
        )
        defer {
            if handle.isRunning {
                handle.cancel()
            }
        }

        let tokenFile = runtimeHomeURL
            .appendingPathComponent(".gemini", isDirectory: true)
            .appendingPathComponent("mcp-oauth-tokens-v2.json")
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        var exitedAt: Date?

        while true {
            try Task.checkCancellation()
            if FileManager.default.fileExists(atPath: tokenFile.path),
               let data = try? Data(contentsOf: tokenFile),
               !data.isEmpty {
                return GeminiLoginResult(
                    accountID: accountID,
                    loginURL: handle.loginURL,
                    runtimeHomeURL: runtimeHomeURL
                )
            }

            if !handle.isRunning {
                if exitedAt == nil {
                    exitedAt = Date()
                } else if Date().timeIntervalSince(exitedAt!) >= processExitGraceSeconds {
                    throw GeminiLoginError.authNotCompleted
                }
            }

            if Date() >= deadline {
                throw GeminiLoginError.loginTimedOut
            }
            try await Task.sleep(nanoseconds: UInt64(max(0.01, pollIntervalSeconds) * 1_000_000_000))
        }
    }

    public static func loginEnvironment(
        provider: UsageProvider,
        runtimeHomeURL: URL,
        base: [String: String]
    ) -> [String: String] {
        var env = base
        env["GEMINI_CLI_HOME"] = runtimeHomeURL.path
        env["GEMINI_FORCE_FILE_STORAGE"] = "true"
        env["GOOGLE_GENAI_USE_GCA"] = "true"
        if provider == .antigravity {
            env["GEMINI_DEFAULT_AUTH_TYPE"] = GeminiAuthMethod.oauthPersonal.rawValue
        }
        return env
    }

    public static func writeSettings(runtimeHomeURL: URL, authType: GeminiAuthMethod) throws {
        let geminiDir = runtimeHomeURL.appendingPathComponent(".gemini", isDirectory: true)
        try FileManager.default.createDirectory(at: geminiDir, withIntermediateDirectories: true)
        let settingsURL = geminiDir.appendingPathComponent("settings.json")
        let payload: [String: Any] = [
            "security": [
                "auth": [
                    "selectedType": authType.rawValue,
                    "useExternal": false
                ]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: settingsURL, options: .atomic)
    }

    private static func startSession(
        binary: String,
        environment: [String: String],
        capture: GeminiLoginOutputCapture
    ) throws -> (session: SKProcessPTYSession, outputTask: Task<Void, Never>, waitTask: Task<Void, Never>, exitState: GeminiProcessExitState) {
        let executableURL = try resolveExecutableURL(binary: binary, environment: environment)

        var payload = SKProcessPayload.executableURL(executableURL)
        payload.environment = SKProcessEnvironment(environment)
        payload.throwOnNonZeroExit = false
        payload.timeoutMs = 30 * 60 * 1000
        payload.maxOutputBytes = 1024 * 1024
        payload.pty = SKProcessPTYConfiguration()

        let session: SKProcessPTYSession
        do {
            session = try SKProcessPTYSession(payload)
        } catch {
            throw GeminiLoginError.launchFailed(error.localizedDescription)
        }

        let exitState = GeminiProcessExitState()
        let outputTask = Task.detached {
            let stream = await session.output
            for await data in stream {
                capture.consume(data: data)
            }
        }
        let waitTask = Task.detached {
            _ = try? await session.wait()
            exitState.markExited()
        }
        return (session, outputTask, waitTask, exitState)
    }

    static func resolveExecutableURL(
        binary: String,
        environment: [String: String],
        fileManager: FileManager = .default,
        shellResolver: (_ binary: String, _ environment: [String: String]) -> URL? = { binary, environment in
            SKProcessRunner.resolveExecutableInUserShellSync(named: binary, environment: environment)
        }
    ) throws -> URL {
        if binary.contains("/") {
            if fileManager.isExecutableFile(atPath: binary) {
                return URL(fileURLWithPath: binary)
            }
            throw GeminiLoginError.binaryNotFound(binary)
        }

        if let resolved = shellResolver(binary, environment) {
            return resolved
        }
        throw GeminiLoginError.binaryNotFound(binary)
    }
}

private final class GeminiProcessExitState: @unchecked Sendable {
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

private final class GeminiLoginOutputCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var loginURL: String?
    private let regex = try? NSRegularExpression(pattern: #"https?://[^\s"'<>]+"#)

    var detectedURL: String? {
        lock.lock()
        defer { lock.unlock() }
        return loginURL
    }

    func consume(data: Data) {
        guard !data.isEmpty,
              let text = String(data: data, encoding: .utf8),
              let url = firstURL(in: text) else {
            return
        }
        lock.lock()
        if loginURL == nil {
            loginURL = url
        }
        lock.unlock()
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
