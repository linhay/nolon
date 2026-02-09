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

    public init(
        todayCostUSD: Double?,
        todayTokens: Int?,
        last30DaysCostUSD: Double?,
        last30DaysTokens: Int?,
        windowDays: Int? = 30,
        dailyCosts: [DailyCost],
        updatedAt: Date
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

public struct CodexCostFetcher: Sendable {
    public init() {}

    public func fetchCostSnapshot(
        now: Date = Date(),
        windowDays: Int? = 30,
        forceRefresh: Bool = false
    ) async throws -> CodexCostSnapshot {
        let fetcher = CostUsageFetcher()
        let token = try await fetcher.loadTokenSnapshot(provider: .codex, now: now, trailingDays: windowDays, forceRefresh: forceRefresh)
        return CodexCostSnapshot(
            todayCostUSD: token.sessionCostUSD,
            todayTokens: token.sessionTokens,
            last30DaysCostUSD: token.last30DaysCostUSD,
            last30DaysTokens: token.last30DaysTokens,
            windowDays: windowDays,
            dailyCosts: token.daily.map { entry in
                CodexCostSnapshot.DailyCost(date: entry.date, costUSD: entry.costUSD, tokens: entry.totalTokens)
            },
            updatedAt: token.updatedAt
        )
    }
}
