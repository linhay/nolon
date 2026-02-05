import Foundation
import ProvidersShared
import SKProcessRunner

// MARK: - Codex RPC client (local process)

struct RPCAccountResponse: Decodable {
    let account: RPCAccountDetails?
    let requiresOpenaiAuth: Bool?
}

enum RPCAccountDetails: Decodable {
    case apiKey
    case chatgpt(email: String, planType: String)

    enum CodingKeys: String, CodingKey {
        case type
        case email
        case planType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type.lowercased() {
        case "apikey":
            self = .apiKey
        case "chatgpt":
            let email = try container.decodeIfPresent(String.self, forKey: .email) ?? "unknown"
            let plan = try container.decodeIfPresent(String.self, forKey: .planType) ?? "unknown"
            self = .chatgpt(email: email, planType: plan)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown account type \(type)")
        }
    }
}

struct RPCRateLimitsResponse: Decodable, Encodable {
    let rateLimits: RPCRateLimitSnapshot
}

struct RPCRateLimitSnapshot: Decodable, Encodable {
    let primary: RPCRateLimitWindow?
    let secondary: RPCRateLimitWindow?
    let credits: RPCCreditsSnapshot?
}

struct RPCRateLimitWindow: Decodable, Encodable {
    let usedPercent: Double
    let windowDurationMins: Int?
    let resetsAt: Int?
}

struct RPCCreditsSnapshot: Decodable, Encodable {
    let hasCredits: Bool
    let unlimited: Bool
    let balance: String?
}

private enum RPCWireError: Error, LocalizedError {
    case startFailed(String)
    case requestFailed(String)
    case malformed(String)

    var errorDescription: String? {
        switch self {
        case let .startFailed(message):
            "Codex not running. Try running a Codex command first. (\(message))"
        case let .requestFailed(message):
            "Codex connection failed: \(message)"
        case let .malformed(message):
            "Codex returned invalid data: \(message)"
        }
    }
}
final class CodexRPCClient: @unchecked Sendable {
    private let process = Process()
    private let stdinPipe = Pipe()
    private let stdoutPipe = Pipe()
    private let stderrPipe = Pipe()
    private let stdoutLineStream: AsyncStream<Data>
    private let stdoutLineContinuation: AsyncStream<Data>.Continuation
    private var nextID = 1

    private final class LineBuffer: @unchecked Sendable {
        private let lock = NSLock()
        private var buffer = Data()

        func appendAndDrainLines(_ data: Data) -> [Data] {
            self.lock.lock()
            defer { self.lock.unlock() }

            self.buffer.append(data)
            var out: [Data] = []
            while let newline = self.buffer.firstIndex(of: 0x0A) {
                let lineData = Data(self.buffer[..<newline])
                self.buffer.removeSubrange(...newline)
                if !lineData.isEmpty {
                    out.append(lineData)
                }
            }
            return out
        }
    }

    private static func debugWriteStderr(_ message: String) {
        #if !os(Linux)
        fputs(message, stderr)
        #endif
    }

    init(
        executable: String = "codex",
        arguments: [String] = ["-s", "read-only", "-a", "untrusted", "app-server"],
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws
    {
        var stdoutContinuation: AsyncStream<Data>.Continuation!
        self.stdoutLineStream = AsyncStream<Data> { continuation in
            stdoutContinuation = continuation
        }
        self.stdoutLineContinuation = stdoutContinuation

        let resolvedExec = Self.resolveCodexExecutable(executable, environment: environment)
        guard let resolvedExec else {
            throw RPCWireError.startFailed(
                "Codex CLI not found. Install with `npm i -g @openai/codex` (or bun) and restart.")
        }
        var env = environment
        env["PATH"] = Self.effectivePATH(env: env)

        self.process.environment = env
        self.process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        self.process.arguments = [resolvedExec] + arguments
        self.process.standardInput = self.stdinPipe
        self.process.standardOutput = self.stdoutPipe
        self.process.standardError = self.stderrPipe

        do {
            try self.process.run()
        } catch {
            throw RPCWireError.startFailed(error.localizedDescription)
        }

        let stdoutHandle = self.stdoutPipe.fileHandleForReading
        let stdoutLineContinuation = self.stdoutLineContinuation
        let stdoutBuffer = LineBuffer()
        stdoutHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                stdoutLineContinuation.finish()
                return
            }

            let lines = stdoutBuffer.appendAndDrainLines(data)

            for lineData in lines {
                stdoutLineContinuation.yield(lineData)
            }
        }

        let stderrHandle = self.stderrPipe.fileHandleForReading
        stderrHandle.readabilityHandler = { handle in
            let data = handle.availableData
            // When the child closes stderr, availableData returns empty and will keep re-firing; clear the handler
            // to avoid a busy read loop on the file-descriptor monitoring queue.
            if data.isEmpty {
                handle.readabilityHandler = nil
                return
            }
            guard let text = String(data: data, encoding: .utf8), !text.isEmpty else { return }
            for line in text.split(whereSeparator: \.isNewline) {
                Self.debugWriteStderr("[codex stderr] \(line)\n")
            }
        }
    }

    private static func effectivePATH(env: [String: String]) -> String {
        var parts: [String] = []

        if let loginPATH = SKProcessRunner.loadUserShellPATHSync(environment: env) {
            parts.append(contentsOf: loginPATH.split(separator: ":").map(String.init))
        }
        if let existing = env["PATH"], !existing.isEmpty {
            parts.append(contentsOf: existing.split(separator: ":").map(String.init))
        }

        if parts.isEmpty {
            parts.append(contentsOf: ["/usr/bin", "/bin", "/usr/sbin", "/sbin"])
        }

        var seen = Set<String>()
        let deduped = parts.compactMap { p -> String? in
            let t = p.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { return nil }
            if seen.insert(t).inserted { return t }
            return nil
        }

        return deduped.joined(separator: ":")
    }

    func initialize(clientName: String, clientVersion: String) async throws {
        _ = try await self.request(
            method: "initialize",
            params: ["clientInfo": ["name": clientName, "version": clientVersion]])
        try self.sendNotification(method: "initialized")
    }

    func fetchRateLimits() async throws -> RPCRateLimitsResponse {
        let message = try await self.request(method: "account/rateLimits/read")
        return try self.decodeResult(from: message)
    }

    func fetchAccount() async throws -> RPCAccountResponse {
        let message = try await self.request(method: "account/read")
        return try self.decodeResult(from: message)
    }

    func shutdown() {
        if self.process.isRunning {
            self.process.terminate()
        }
    }

    // MARK: - JSON-RPC helpers

    private func request(method: String, params: [String: Any]? = nil) async throws -> [String: Any] {
        let id = self.nextID
        self.nextID += 1
        try self.sendRequest(id: id, method: method, params: params)

        while true {
            let message = try await self.readNextMessage()

            if message["id"] == nil, let methodName = message["method"] as? String {
                Self.debugWriteStderr("[codex notify] \(methodName)\n")
                continue
            }

            guard let messageID = self.jsonID(message["id"]), messageID == id else { continue }

            if let error = message["error"] as? [String: Any], let messageText = error["message"] as? String {
                throw RPCWireError.requestFailed(messageText)
            }

            return message
        }
    }

    private func sendNotification(method: String, params: [String: Any]? = nil) throws {
        let paramsValue: Any = params ?? [:]
        try self.sendPayload(["method": method, "params": paramsValue])
    }

    private func sendRequest(id: Int, method: String, params: [String: Any]?) throws {
        let paramsValue: Any = params ?? [:]
        let payload: [String: Any] = ["id": id, "method": method, "params": paramsValue]
        try self.sendPayload(payload)
    }

    private func sendPayload(_ payload: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: payload)
        self.stdinPipe.fileHandleForWriting.write(data)
        self.stdinPipe.fileHandleForWriting.write(Data([0x0A]))
    }

    private func readNextMessage() async throws -> [String: Any] {
        for await lineData in self.stdoutLineStream {
            if lineData.isEmpty { continue }
            if let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] {
                return json
            }
        }
        throw RPCWireError.malformed("codex app-server closed stdout")
    }

    private func decodeResult<T: Decodable>(from message: [String: Any]) throws -> T {
        guard let result = message["result"] else {
            throw RPCWireError.malformed("missing result field")
        }
        let data = try JSONSerialization.data(withJSONObject: result)
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    private func jsonID(_ value: Any?) -> Int? {
        switch value {
        case let int as Int:
            int
        case let number as NSNumber:
            number.intValue
        default:
            nil
        }
    }

    private static func resolveCodexExecutable(_ executable: String, environment: [String: String]) -> String? {
        if executable.contains("/") {
            return FileManager.default.isExecutableFile(atPath: executable) ? executable : nil
        }

        if let override = environment["CODEX_CLI_PATH"], FileManager.default.isExecutableFile(atPath: override) {
            return override
        }

        if let url = SKProcessRunner.resolveExecutableInPath(named: executable, environment: environment) {
            return url.path
        }

        var envWithLoginPATH = environment
        envWithLoginPATH["PATH"] = Self.effectivePATH(env: environment)
        if let url = SKProcessRunner.resolveExecutableInPath(named: executable, environment: envWithLoginPATH) {
            return url.path
        }

        if let url = SKProcessRunner.resolveExecutableInUserShellSync(named: executable, environment: environment) {
            return url.path
        }

        // Common macOS PATH additions (when app PATH is minimal).
        let fallbacks = [
            "/opt/homebrew/bin/\(executable)",
            "/usr/local/bin/\(executable)",
            "\(NSHomeDirectory())/.bun/bin/\(executable)",
            "\(NSHomeDirectory())/.npm-global/bin/\(executable)",
        ]
        for candidate in fallbacks where FileManager.default.isExecutableFile(atPath: candidate) {
            return candidate
        }

        if let resolved = TTYCommandRunner.which(executable, env: envWithLoginPATH) {
            return resolved
        }
        return TTYCommandRunner.which(executable, env: environment)
    }
}
