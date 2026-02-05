import Foundation
import ProvidersShared
import SKProcessRunner

/// Convenience wrapper around `CodexCreditsFetcher`.
public struct CodexHelper: Sendable {
    public struct RateLimitWindow: Sendable, Equatable, Codable {
        public let usedPercent: Double
        public let windowDurationMins: Int?
        public let resetsAt: Date?

        public init(usedPercent: Double, windowDurationMins: Int?, resetsAt: Date?) {
            self.usedPercent = usedPercent
            self.windowDurationMins = windowDurationMins
            self.resetsAt = resetsAt
        }
    }

    public struct RateLimitsSnapshot: Sendable, Equatable, Codable {
        public let primary: RateLimitWindow?
        public let secondary: RateLimitWindow?
        public let updatedAt: Date

        public init(primary: RateLimitWindow?, secondary: RateLimitWindow?, updatedAt: Date = Date()) {
            self.primary = primary
            self.secondary = secondary
            self.updatedAt = updatedAt
        }
    }

    public struct AccountInfo: Sendable, Equatable, Codable {
        public let email: String?
        public let plan: String?

        public init(email: String?, plan: String?) {
            self.email = email
            self.plan = plan
        }
    }

    private let codexBinary: String?
    private let environment: [String: String]
    private let fetcher: CodexCreditsFetcher

    public init(
        codexBinary: String? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.codexBinary = codexBinary
        self.environment = environment
        self.fetcher = CodexCreditsFetcher(codexBinary: codexBinary, environment: environment)
    }

    public var isCLIAvailable: Bool {
        if let path = codexBinary, FileManager.default.isExecutableFile(atPath: path) {
            return true
        }
        if let override = environment["CODEX_CLI_PATH"], FileManager.default.isExecutableFile(atPath: override) {
            return true
        }
        if TTYCommandRunner.which("codex", env: environment) != nil {
            return true
        }
        return SKProcessRunner.resolveExecutableInUserShellSync(named: "codex", environment: environment) != nil
    }

    public func fetchCredits(keepCLISessionsAlive: Bool = false) async throws -> CreditsSnapshot {
        try await fetcher.fetchCredits(keepCLISessionsAlive: keepCLISessionsAlive)
    }

    public func fetchRateLimits() async throws -> RateLimitsSnapshot {
        let binary = self.codexBinary ?? "codex"
        let rpc = try CodexRPCClient(executable: binary, environment: environment)
        defer { rpc.shutdown() }

        try await rpc.initialize(clientName: "codexhelper", clientVersion: "1.0.0")
        let limits = try await rpc.fetchRateLimits().rateLimits

        func window(_ w: RPCRateLimitWindow?) -> RateLimitWindow? {
            guard let w else { return nil }
            let resetsAt: Date? = w.resetsAt.map { Date(timeIntervalSince1970: TimeInterval($0)) }
            return RateLimitWindow(usedPercent: w.usedPercent, windowDurationMins: w.windowDurationMins, resetsAt: resetsAt)
        }

        return RateLimitsSnapshot(primary: window(limits.primary), secondary: window(limits.secondary), updatedAt: Date())
    }

    public func fetchAccountInfo() async throws -> AccountInfo {
        let binary = self.codexBinary ?? "codex"
        let rpc = try CodexRPCClient(executable: binary, environment: environment)
        defer { rpc.shutdown() }

        try await rpc.initialize(clientName: "codexhelper", clientVersion: "1.0.0")
        let response = try await rpc.fetchAccount()

        let info: AccountInfo = switch response.account {
        case .none:
            AccountInfo(email: nil, plan: nil)
        case .apiKey:
            AccountInfo(email: nil, plan: "api_key")
        case let .chatgpt(email, planType):
            AccountInfo(email: email, plan: planType)
        }

        return info
    }
}
