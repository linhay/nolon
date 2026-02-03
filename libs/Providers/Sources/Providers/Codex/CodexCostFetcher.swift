import Foundation
import CodexBarProviderCatalog

public struct CodexCostSnapshot: Sendable, Equatable {
    public let todayCostUSD: Double?
    public let todayTokens: Int?
    public let last30DaysCostUSD: Double?
    public let last30DaysTokens: Int?
    public let updatedAt: Date

    public init(
        todayCostUSD: Double?,
        todayTokens: Int?,
        last30DaysCostUSD: Double?,
        last30DaysTokens: Int?,
        updatedAt: Date
    ) {
        self.todayCostUSD = todayCostUSD
        self.todayTokens = todayTokens
        self.last30DaysCostUSD = last30DaysCostUSD
        self.last30DaysTokens = last30DaysTokens
        self.updatedAt = updatedAt
    }
}

public struct CodexCostFetcher: Sendable {
    public init() {}

    public func fetchCostSnapshot(
        now: Date = Date(),
        forceRefresh: Bool = false
    ) async throws -> CodexCostSnapshot {
        let fetcher = CostUsageFetcher()
        let token = try await fetcher.loadTokenSnapshot(provider: .codex, now: now, forceRefresh: forceRefresh)
        return CodexCostSnapshot(
            todayCostUSD: token.sessionCostUSD,
            todayTokens: token.sessionTokens,
            last30DaysCostUSD: token.last30DaysCostUSD,
            last30DaysTokens: token.last30DaysTokens,
            updatedAt: token.updatedAt
        )
    }
}

