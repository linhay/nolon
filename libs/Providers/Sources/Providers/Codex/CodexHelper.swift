import Foundation
import CodexCLIKit
import CodexAppServerKit
import ProvidersShared

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

    public struct ModelListSnapshot: Sendable, Equatable {
        public let fetchedAt: Date
        public let etag: String?
        public let clientVersion: String?
        public let models: [CodexModelsCache.Model]

        public init(fetchedAt: Date, etag: String?, clientVersion: String?, models: [CodexModelsCache.Model]) {
            self.fetchedAt = fetchedAt
            self.etag = etag
            self.clientVersion = clientVersion
            self.models = models
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
        CodexCommandExecutor(executable: codexBinary ?? "codex", environment: environment).resolveExecutable() != nil
    }

    public func fetchCredits(keepCLISessionsAlive: Bool = false) async throws -> CreditsSnapshot {
        try await fetcher.fetchCredits(keepCLISessionsAlive: keepCLISessionsAlive)
    }

    public func fetchRateLimits() async throws -> RateLimitsSnapshot {
        let limits = try await CodexRuntimeSupport.withRuntimeService(
            preferredBinary: self.codexBinary,
            environment: self.environment
        ) { service in
            try await service.readRateLimits()
        }

        func window(_ w: CodexRuntimeRateLimitWindow?) -> RateLimitWindow? {
            guard let w else { return nil }
            let resetsAt: Date? = w.resetsAt.map { Date(timeIntervalSince1970: TimeInterval($0)) }
            return RateLimitWindow(usedPercent: w.usedPercent, windowDurationMins: w.windowDurationMins, resetsAt: resetsAt)
        }

        return RateLimitsSnapshot(primary: window(limits.primary), secondary: window(limits.secondary), updatedAt: Date())
    }

    public func fetchAccountInfo() async throws -> AccountInfo {
        let account = try await CodexRuntimeSupport.withRuntimeService(
            preferredBinary: self.codexBinary,
            environment: self.environment
        ) { service in
            try await service.readAccount(refreshToken: false)
        }

        let plan: String?
        switch account.authMode {
        case .apikey:
            plan = "api_key"
        default:
            plan = account.planType
        }

        return AccountInfo(email: account.email, plan: plan)
    }

    public func loadModelsCache() throws -> ModelListSnapshot {
        let cacheURL = self.modelsCacheFileURL()
        let cache = try CodexModelsCache.load(from: cacheURL)
        return ModelListSnapshot(
            fetchedAt: cache.fetchedAt,
            etag: cache.etag,
            clientVersion: cache.clientVersion,
            models: cache.models
        )
    }

    public func loadVisibleModelsFromCache() throws -> [CodexModelsCache.Model] {
        let cache = try self.loadModelsCache()
        return cache.models.filter { model in
            let visibility = model.visibility?.lowercased()
            return visibility == nil || visibility == "list"
        }
    }

    private func modelsCacheFileURL() -> URL {
        return CodexCommandExecutor
            .codexHomeDirectoryURL(environment: self.environment)
            .appendingPathComponent("models_cache.json", isDirectory: false)
    }
}
