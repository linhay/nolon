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

public enum ProviderUsageCurveCapability: String, Codable, Sendable, Equatable {
    case dailyOnly
    case dailyWithIntradayDrilldown
}

public enum ProviderIntradayBucket: String, Codable, Sendable, Equatable, CaseIterable {
    case minute15
    case minute30
    case hour1

    public var title: String {
        switch self {
        case .minute15:
            return "15min"
        case .minute30:
            return "30min"
        case .hour1:
            return "60min"
        }
    }
}

public struct ProviderIntradayUsagePoint: Codable, Sendable, Equatable {
    public let start: Date
    public let end: Date
    public let totalTokens: Int
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheReadTokens: Int

    public init(
        start: Date,
        end: Date,
        totalTokens: Int,
        inputTokens: Int,
        outputTokens: Int,
        cacheReadTokens: Int
    ) {
        self.start = start
        self.end = end
        self.totalTokens = totalTokens
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheReadTokens = cacheReadTokens
    }
}

public struct ProviderIntradayUsageSnapshot: Codable, Sendable, Equatable {
    public let dayKey: String
    public let timezoneIdentifier: String
    public let bucket: ProviderIntradayBucket
    public let actualBucketCount: Int
    public let rangeStart: Date
    public let rangeEnd: Date
    public let points: [ProviderIntradayUsagePoint]
    public let fetchedAt: Date
    public let sourceLabel: String

    public init(
        dayKey: String,
        timezoneIdentifier: String,
        bucket: ProviderIntradayBucket,
        actualBucketCount: Int,
        rangeStart: Date,
        rangeEnd: Date,
        points: [ProviderIntradayUsagePoint],
        fetchedAt: Date,
        sourceLabel: String
    ) {
        self.dayKey = dayKey
        self.timezoneIdentifier = timezoneIdentifier
        self.bucket = bucket
        self.actualBucketCount = actualBucketCount
        self.rangeStart = rangeStart
        self.rangeEnd = rangeEnd
        self.points = points
        self.fetchedAt = fetchedAt
        self.sourceLabel = sourceLabel
    }
}

public typealias CodexTokenTrendPoint = ProviderTokenTrendPoint
public typealias CodexTokenTrendSnapshot = ProviderTokenTrendSnapshot
