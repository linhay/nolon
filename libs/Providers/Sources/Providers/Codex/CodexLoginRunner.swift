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
    case invalidSuccessCallbackURL(String)

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
        case let .invalidSuccessCallbackURL(message):
            "Invalid Codex success callback URL: \(message)"
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

    public static func authJSONString(fromSuccessCallbackURLString raw: String) throws -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            throw CodexLoginError.invalidSuccessCallbackURL("Malformed URL")
        }

        let host = components.host?.lowercased()
        let path = components.path.lowercased()
        guard components.scheme?.lowercased() == "http",
              (host == "localhost" || host == "127.0.0.1" || host == "::1"),
              path == "/success" || path == "/auth/callback"
        else {
            throw CodexLoginError.invalidSuccessCallbackURL("Expected localhost callback URL at /success or /auth/callback")
        }

        let queryItems = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value) })
        let queryValue: (String) -> String? = { key in
            guard let maybeValue = queryItems[key],
                  let value = maybeValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty
            else { return nil }
            return value
        }
        let idToken = queryValue("id_token")
        let accessToken = queryValue("access_token")
        let refreshToken = queryValue("refresh_token")

        guard let idToken, !idToken.isEmpty else {
            throw CodexLoginError.invalidSuccessCallbackURL("Missing id_token")
        }
        let payload = decodeJWTPayload(idToken)
        let accountID = [
            nestedString(payload, path: ["https://api.openai.com/auth", "chatgpt_account_id"]),
            nestedString(payload, path: ["auth", "chatgpt_account_id"]),
            queryValue("account_id"),
        ]
            .compactMap { $0 }
            .first
        let email = [
            nestedString(payload, path: ["email"]),
            nestedString(payload, path: ["https://api.openai.com/profile", "email"]),
            queryValue("email"),
        ]
            .compactMap { $0 }
            .first
        let authMode = refreshToken?.isEmpty == false ? "chatgpt" : "chatgptAuthTokens"
        let lastRefresh = ISO8601DateFormatter().string(from: Date())

        var root: [String: Any] = [
            "auth_mode": authMode,
            "OPENAI_API_KEY": NSNull(),
            "last_refresh": lastRefresh,
            "tokens": [
                "id_token": idToken,
                "access_token": accessToken?.isEmpty == false ? accessToken as Any : NSNull(),
                "refresh_token": refreshToken?.isEmpty == false ? refreshToken as Any : NSNull(),
                "account_id": accountID ?? NSNull(),
            ],
        ]
        if let email {
            root["email"] = email
        }

        let data = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
        guard let authJSONString = String(data: data, encoding: .utf8) else {
            throw CodexLoginError.authInvalidUTF8
        }
        return authJSONString
    }

    private static func decodeJWTPayload(_ jwt: String) -> [String: Any]? {
        let parts = jwt.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 2,
              let data = base64URLDecode(String(parts[1])),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return object
    }

    private static func nestedString(_ object: [String: Any]?, path: [String]) -> String? {
        guard let object, !path.isEmpty else { return nil }
        var current: Any = object
        for key in path.dropLast() {
            guard let next = (current as? [String: Any])?[key] else { return nil }
            current = next
        }
        guard let string = (current as? [String: Any])?[path[path.count - 1]] as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func base64URLDecode(_ raw: String) -> Data? {
        var normalized = raw
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = normalized.count % 4
        if remainder != 0 {
            normalized += String(repeating: "=", count: 4 - remainder)
        }
        return Data(base64Encoded: normalized)
    }

    public static func awaitAuthResult(
        codexHome: STFolder,
        timeoutSeconds: TimeInterval = 120,
        pollIntervalSeconds: TimeInterval = 0.25
    ) async throws -> CodexLoginResult {
        let authFile = codexHome.file("auth.json")
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        let sleepNanoseconds = UInt64(max(0.01, pollIntervalSeconds) * 1_000_000_000)
        var sawInvalidUTF8 = false

        while true {
            try Task.checkCancellation()

            if authFile.isExists, let data = try? authFile.data(), !data.isEmpty {
                guard let raw = String(data: data, encoding: .utf8) else {
                    sawInvalidUTF8 = true
                    if Date() >= deadline {
                        throw CodexLoginError.authInvalidUTF8
                    }
                    try await Task.sleep(nanoseconds: sleepNanoseconds)
                    continue
                }
                return CodexLoginResult(authJSONString: raw, loginURL: nil)
            }

            if Date() >= deadline {
                if sawInvalidUTF8 {
                    throw CodexLoginError.authInvalidUTF8
                }
                throw CodexLoginError.authNotCreated
            }

            try await Task.sleep(nanoseconds: sleepNanoseconds)
        }
    }

    /// Waits for `auth.json` as the primary success signal.
    /// The app-server completion waiter is optional and best-effort only:
    /// its failures are ignored because some environments can miss completion
    /// callbacks while still writing a valid `auth.json`.
    public static func awaitAuthResultPreferFile(
        codexHome: STFolder,
        timeoutSeconds: TimeInterval = 120,
        pollIntervalSeconds: TimeInterval = 0.25,
        completionWaiter: (@Sendable () async throws -> Void)? = nil
    ) async throws -> CodexLoginResult {
        guard let completionWaiter else {
            return try await awaitAuthResult(
                codexHome: codexHome,
                timeoutSeconds: timeoutSeconds,
                pollIntervalSeconds: pollIntervalSeconds
            )
        }

        let completionTask = Task {
            try? await completionWaiter()
        }
        defer { completionTask.cancel() }

        return try await awaitAuthResult(
            codexHome: codexHome,
            timeoutSeconds: timeoutSeconds,
            pollIntervalSeconds: pollIntervalSeconds
        )
    }

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

        let deadline = Date().addingTimeInterval(timeoutSeconds)
        var processExitedAt: Date?
        let sleepNanoseconds = UInt64(max(0.01, pollIntervalSeconds) * 1_000_000_000)

        while true {
            try Task.checkCancellation()

            if let authResult = try Self.tryReadAuthResult(codexHome: codexHome, loginURL: capture.detectedURL) {
                if authResult.loginURL != nil {
                    return authResult
                }
                let loginURL = await Self.awaitDetectedLoginURL(
                    capture: capture,
                    timeoutSeconds: 0.35,
                    pollIntervalSeconds: 0.05
                )
                return CodexLoginResult(
                    authJSONString: authResult.authJSONString,
                    loginURL: loginURL
                )
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

    private static func tryReadAuthResult(codexHome: STFolder, loginURL: String?) throws -> CodexLoginResult? {
        let authFile = codexHome.file("auth.json")
        guard authFile.isExists,
              let data = try? authFile.data(),
              !data.isEmpty
        else { return nil }
        guard let raw = String(data: data, encoding: .utf8) else {
            throw CodexLoginError.authInvalidUTF8
        }
        return CodexLoginResult(authJSONString: raw, loginURL: loginURL)
    }

    private static func awaitDetectedLoginURL(
        capture: LoginOutputCapture,
        timeoutSeconds: TimeInterval,
        pollIntervalSeconds: TimeInterval
    ) async -> String? {
        if let detected = capture.detectedURL {
            return detected
        }
        let deadline = Date().addingTimeInterval(max(0.01, timeoutSeconds))
        let sleepNanoseconds = UInt64(max(0.01, pollIntervalSeconds) * 1_000_000_000)
        while Date() < deadline {
            if let detected = capture.detectedURL {
                return detected
            }
            try? await Task.sleep(nanoseconds: sleepNanoseconds)
        }
        return capture.detectedURL
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
