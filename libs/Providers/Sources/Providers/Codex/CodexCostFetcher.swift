import Foundation
import CodexBarProviderCatalog

public struct CodexCostSnapshot: Sendable, Equatable {
    public let todayCostUSD: Double?
    public let todayTokens: Int?
    public let todayInputTokens: Int?
    public let todayOutputTokens: Int?
    public let todayCachedInputTokens: Int?
    public let rangeDays: Int?
    public let rangeCostUSD: Double?
    public let rangeTokens: Int?
    public let rangeInputTokens: Int?
    public let rangeOutputTokens: Int?
    public let rangeCachedInputTokens: Int?
    public let updatedAt: Date

    public init(
        todayCostUSD: Double?,
        todayTokens: Int?,
        todayInputTokens: Int?,
        todayOutputTokens: Int?,
        todayCachedInputTokens: Int?,
        rangeDays: Int?,
        rangeCostUSD: Double?,
        rangeTokens: Int?,
        rangeInputTokens: Int?,
        rangeOutputTokens: Int?,
        rangeCachedInputTokens: Int?,
        updatedAt: Date
    ) {
        self.todayCostUSD = todayCostUSD
        self.todayTokens = todayTokens
        self.todayInputTokens = todayInputTokens
        self.todayOutputTokens = todayOutputTokens
        self.todayCachedInputTokens = todayCachedInputTokens
        self.rangeDays = rangeDays
        self.rangeCostUSD = rangeCostUSD
        self.rangeTokens = rangeTokens
        self.rangeInputTokens = rangeInputTokens
        self.rangeOutputTokens = rangeOutputTokens
        self.rangeCachedInputTokens = rangeCachedInputTokens
        self.updatedAt = updatedAt
    }
}

public struct CodexCostFetcher: Sendable {
    public init() {}

    public func fetchCostSnapshot(
        now: Date = Date(),
        rangeDays: Int? = nil,
        forceRefresh: Bool = false
    ) async throws -> CodexCostSnapshot {
        let fetcher = CostUsageFetcher()
        let token = try await fetcher.loadTokenSnapshot(
            provider: .codex,
            now: now,
            trailingDays: rangeDays,
            forceRefresh: forceRefresh
        )
        return CodexCostSnapshot(
            todayCostUSD: token.sessionCostUSD,
            todayTokens: token.sessionTokens,
            todayInputTokens: token.todayInputTokens,
            todayOutputTokens: token.todayOutputTokens,
            todayCachedInputTokens: token.todayCachedInputTokens,
            rangeDays: token.rangeDays,
            rangeCostUSD: token.rangeCostUSD,
            rangeTokens: token.rangeTokens,
            rangeInputTokens: token.rangeInputTokens,
            rangeOutputTokens: token.rangeOutputTokens,
            rangeCachedInputTokens: token.rangeCachedInputTokens,
            updatedAt: token.updatedAt
        )
    }
}
