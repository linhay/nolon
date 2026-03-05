import Foundation
import CodexBarProviderCatalog

public enum ProviderSourceMode: String, CaseIterable, Codable, Sendable {
    case auto
    case cli
    case web
    case oauth
    case apiToken
    case localProbe
    case webDashboard
}

public struct ProviderFetchPlan: Sendable, Equatable {
    public let sourceModes: [ProviderSourceMode]

    public init(sourceModes: [ProviderSourceMode]) {
        self.sourceModes = sourceModes
    }
}

public enum ProviderFetchKind: String, Codable, Sendable {
    case cli
    case web
    case oauth
    case apiToken
    case localProbe
    case webDashboard
}

public struct RateWindow: Codable, Sendable, Equatable {
    public let usedPercent: Double
    public let resetDescription: String?
    public let resetsAt: Date?
    public let windowMinutes: Int?

    public var remainingPercent: Double {
        max(0, min(100, 100 - usedPercent))
    }

    public init(
        usedPercent: Double,
        resetDescription: String? = nil,
        resetsAt: Date? = nil,
        windowMinutes: Int? = nil
    ) {
        self.usedPercent = usedPercent
        self.resetDescription = resetDescription
        self.resetsAt = resetsAt
        self.windowMinutes = windowMinutes
    }
}

public struct UsageIdentity: Codable, Sendable, Equatable {
    public let accountEmail: String?
    public let accountOrganization: String?
    public let loginMethod: String?
    public let plan: String?

    public init(accountEmail: String?, accountOrganization: String?, loginMethod: String?, plan: String? = nil) {
        self.accountEmail = accountEmail
        self.accountOrganization = accountOrganization
        self.loginMethod = loginMethod
        self.plan = plan
    }

    public func scoped(to _: UsageProvider) -> UsageIdentity {
        self
    }
}

public struct UsageSnapshot: Codable, Sendable, Equatable {
    public let identity: UsageIdentity?
    public let primary: RateWindow?
    public let secondary: RateWindow?
    public let tertiary: RateWindow?
    public let updatedAt: Date

    public init(
        identity: UsageIdentity?,
        primary: RateWindow?,
        secondary: RateWindow?,
        tertiary: RateWindow?,
        updatedAt: Date = Date()
    ) {
        self.identity = identity
        self.primary = primary
        self.secondary = secondary
        self.tertiary = tertiary
        self.updatedAt = updatedAt
    }
}

public struct CreditsSnapshot: Codable, Sendable, Equatable {
    public let remaining: Double
    public let updatedAt: Date

    public init(remaining: Double, updatedAt: Date = Date()) {
        self.remaining = remaining
        self.updatedAt = updatedAt
    }
}

public struct CostSnapshot: Codable, Sendable, Equatable {
    public struct DailyCost: Codable, Sendable, Equatable {
        public let date: String
        public let costUSD: Double?
        public let tokens: Int?

        public init(date: String, costUSD: Double?, tokens: Int? = nil) {
            self.date = date
            self.costUSD = costUSD
            self.tokens = tokens
        }
    }

    public let todayCostUSD: Double?
    public let todayTokens: Int?
    public let last30DaysCostUSD: Double?
    public let last30DaysTokens: Int?
    public let windowDays: Int?
    public let dailyCosts: [DailyCost]?
    public let updatedAt: Date

    public init(
        todayCostUSD: Double?,
        todayTokens: Int?,
        last30DaysCostUSD: Double?,
        last30DaysTokens: Int?,
        windowDays: Int? = 30,
        dailyCosts: [DailyCost]? = nil,
        updatedAt: Date = Date()
    ) {
        self.todayCostUSD = todayCostUSD
        self.todayTokens = todayTokens
        self.last30DaysCostUSD = last30DaysCostUSD
        self.last30DaysTokens = last30DaysTokens
        self.windowDays = windowDays
        self.dailyCosts = dailyCosts
        self.updatedAt = updatedAt
    }
}

public enum ProviderFetchStrategyKind: String, Codable, Sendable {
    case direct
    case fallback
}

public struct ProviderFetchResult: Sendable, Equatable {
    public let usage: UsageSnapshot
    public let credits: CreditsSnapshot?
    public let cost: CostSnapshot?
    public let sourceLabel: String
    public let fetchKind: ProviderFetchKind
    public let strategyKind: ProviderFetchStrategyKind

    public init(
        usage: UsageSnapshot,
        credits: CreditsSnapshot?,
        cost: CostSnapshot?,
        sourceLabel: String,
        fetchKind: ProviderFetchKind,
        strategyKind: ProviderFetchStrategyKind
    ) {
        self.usage = usage
        self.credits = credits
        self.cost = cost
        self.sourceLabel = sourceLabel
        self.fetchKind = fetchKind
        self.strategyKind = strategyKind
    }
}

public struct ProviderFetchOutcome: Sendable {
    public let fetchKind: ProviderFetchKind
    public let result: Result<ProviderFetchResult, Error>

    public init(fetchKind: ProviderFetchKind, result: Result<ProviderFetchResult, Error>) {
        self.fetchKind = fetchKind
        self.result = result
    }
}

public enum ProviderUsageError: LocalizedError, Sendable, Equatable {
    case unsupported(UsageProvider)
    case missingToken(UsageProvider)
    case missingAccount(UsageProvider)
    case authExpired(UsageProvider)

    public var errorDescription: String? {
        switch self {
        case let .unsupported(provider):
            return "Usage not supported for \(provider.rawValue)."
        case let .missingToken(provider):
            return "Missing token for \(provider.rawValue)."
        case let .missingAccount(provider):
            return "No active account for \(provider.rawValue). Please sign in."
        case let .authExpired(provider):
            return "Authentication expired for \(provider.rawValue). Please sign in again."
        }
    }
}

public enum GeminiAuthMethod: String, Codable, CaseIterable, Sendable, Equatable {
    case oauthPersonal = "oauth-personal"
    case geminiAPIKey = "gemini-api-key"
    case vertexAI = "vertex-ai"
}

public struct GeminiAuthAccount: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let providerID: UsageProvider
    public let name: String
    public let method: GeminiAuthMethod
    public let createdAt: Date
    public let lastUsedAt: Date?
    public let lastLoginAt: Date?
    public let email: String?
    public let project: String?
    public let location: String?
    public let runtimeHomeRelativePath: String

    public init(
        id: UUID,
        providerID: UsageProvider,
        name: String,
        method: GeminiAuthMethod,
        createdAt: Date,
        lastUsedAt: Date?,
        lastLoginAt: Date?,
        email: String?,
        project: String?,
        location: String?,
        runtimeHomeRelativePath: String
    ) {
        self.id = id
        self.providerID = providerID
        self.name = name
        self.method = method
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.lastLoginAt = lastLoginAt
        self.email = email
        self.project = project
        self.location = location
        self.runtimeHomeRelativePath = runtimeHomeRelativePath
    }
}

public struct ProviderFetchContext: Sendable {
    public let provider: UsageProvider
    public let sourceMode: ProviderSourceMode
    public let includeCredits: Bool
    public let timeout: TimeInterval
    public let costWindowDays: Int?
    public let environment: [String: String]
    public let token: String?

    public init(
        provider: UsageProvider,
        sourceMode: ProviderSourceMode,
        includeCredits: Bool,
        timeout: TimeInterval,
        costWindowDays: Int? = 30,
        environment: [String: String],
        token: String?
    ) {
        self.provider = provider
        self.sourceMode = sourceMode
        self.includeCredits = includeCredits
        self.timeout = timeout
        self.costWindowDays = costWindowDays
        self.environment = environment
        self.token = token
    }
}
