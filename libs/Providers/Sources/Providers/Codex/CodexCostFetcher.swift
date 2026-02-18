import Foundation
import CodexBarProviderCatalog

public struct CodexCostSnapshot: Sendable, Equatable {
    public struct DailyCost: Sendable, Equatable {
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
    public let dailyCosts: [DailyCost]
    public let updatedAt: Date
    public let tokenSource: CostUsageTokenSnapshot.Source

    public init(
        todayCostUSD: Double?,
        todayTokens: Int?,
        last30DaysCostUSD: Double?,
        last30DaysTokens: Int?,
        windowDays: Int? = 30,
        dailyCosts: [DailyCost],
        updatedAt: Date,
        tokenSource: CostUsageTokenSnapshot.Source = .scopedSessions
    ) {
        self.todayCostUSD = todayCostUSD
        self.todayTokens = todayTokens
        self.last30DaysCostUSD = last30DaysCostUSD
        self.last30DaysTokens = last30DaysTokens
        self.windowDays = windowDays
        self.dailyCosts = dailyCosts
        self.updatedAt = updatedAt
        self.tokenSource = tokenSource
    }
}

public struct CodexCostFetcher: Sendable {
    public init() {}

    public func fetchCostSnapshot(
        now: Date = Date(),
        windowDays: Int? = 30,
        forceRefresh: Bool = false,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) async throws -> CodexCostSnapshot {
        let fetcher = CostUsageFetcher()
        let token = try await fetcher.loadTokenSnapshot(
            provider: .codex,
            now: now,
            trailingDays: windowDays,
            forceRefresh: forceRefresh,
            environment: environment
        )
        return CodexCostSnapshot(
            todayCostUSD: token.sessionCostUSD,
            todayTokens: token.sessionTokens,
            last30DaysCostUSD: token.rangeCostUSD,
            last30DaysTokens: token.rangeTokens,
            windowDays: windowDays,
            dailyCosts: token.daily.map { entry in
                CodexCostSnapshot.DailyCost(date: entry.date, costUSD: entry.costUSD, tokens: entry.totalTokens)
            },
            updatedAt: token.updatedAt,
            tokenSource: token.source
        )
    }
}
