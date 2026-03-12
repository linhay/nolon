import Foundation

public struct ProviderTokenTrendPoint: Codable, Sendable, Equatable {
    public let date: String
    public let totalTokens: Int
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheReadTokens: Int

    public init(
        date: String,
        totalTokens: Int,
        inputTokens: Int,
        outputTokens: Int,
        cacheReadTokens: Int
    ) {
        self.date = date
        self.totalTokens = totalTokens
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheReadTokens = cacheReadTokens
    }
}

public struct ProviderTokenTrendSnapshot: Codable, Sendable, Equatable {
    public let points: [ProviderTokenTrendPoint]
    public let todayTokens: Int?
    public let last7DaysTokens: Int?
    public let last30DaysTokens: Int?
    public let allDaysTokens: Int?
    public let updatedAt: Date
    public let sourceLabel: String

    public init(
        points: [ProviderTokenTrendPoint],
        todayTokens: Int?,
        last7DaysTokens: Int?,
        last30DaysTokens: Int?,
        allDaysTokens: Int?,
        updatedAt: Date,
        sourceLabel: String
    ) {
        self.points = points
        self.todayTokens = todayTokens
        self.last7DaysTokens = last7DaysTokens
        self.last30DaysTokens = last30DaysTokens
        self.allDaysTokens = allDaysTokens
        self.updatedAt = updatedAt
        self.sourceLabel = sourceLabel
    }
}

public typealias CodexTokenTrendPoint = ProviderTokenTrendPoint
public typealias CodexTokenTrendSnapshot = ProviderTokenTrendSnapshot
