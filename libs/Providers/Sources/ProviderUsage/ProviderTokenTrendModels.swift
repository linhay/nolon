import Foundation

public struct ProviderTokenTrendPoint: Codable, Sendable, Equatable {
    public let date: String
    public let totalTokens: Int
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheReadTokens: Int
    public let requestCount: Int

    private enum CodingKeys: String, CodingKey {
        case date
        case totalTokens
        case inputTokens
        case outputTokens
        case cacheReadTokens
        case requestCount
    }

    public init(
        date: String,
        totalTokens: Int,
        inputTokens: Int,
        outputTokens: Int,
        cacheReadTokens: Int,
        requestCount: Int = 0
    ) {
        self.date = date
        self.totalTokens = totalTokens
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheReadTokens = cacheReadTokens
        self.requestCount = requestCount
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.date = try container.decode(String.self, forKey: .date)
        self.totalTokens = try container.decode(Int.self, forKey: .totalTokens)
        self.inputTokens = try container.decode(Int.self, forKey: .inputTokens)
        self.outputTokens = try container.decode(Int.self, forKey: .outputTokens)
        self.cacheReadTokens = try container.decode(Int.self, forKey: .cacheReadTokens)
        self.requestCount = try container.decodeIfPresent(Int.self, forKey: .requestCount) ?? 0
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(date, forKey: .date)
        try container.encode(totalTokens, forKey: .totalTokens)
        try container.encode(inputTokens, forKey: .inputTokens)
        try container.encode(outputTokens, forKey: .outputTokens)
        try container.encode(cacheReadTokens, forKey: .cacheReadTokens)
        try container.encode(requestCount, forKey: .requestCount)
    }
}

public struct ProviderTokenTrendSnapshot: Codable, Sendable, Equatable {
    public let points: [ProviderTokenTrendPoint]
    public let todayTokens: Int?
    public let todayRequests: Int?
    public let last7DaysTokens: Int?
    public let last7DaysRequests: Int?
    public let last30DaysTokens: Int?
    public let last30DaysRequests: Int?
    public let allDaysTokens: Int?
    public let allDaysRequests: Int?
    public let updatedAt: Date
    public let sourceLabel: String

    private enum CodingKeys: String, CodingKey {
        case points
        case todayTokens
        case todayRequests
        case last7DaysTokens
        case last7DaysRequests
        case last30DaysTokens
        case last30DaysRequests
        case allDaysTokens
        case allDaysRequests
        case updatedAt
        case sourceLabel
    }

    public init(
        points: [ProviderTokenTrendPoint],
        todayTokens: Int?,
        todayRequests: Int? = nil,
        last7DaysTokens: Int?,
        last7DaysRequests: Int? = nil,
        last30DaysTokens: Int?,
        last30DaysRequests: Int? = nil,
        allDaysTokens: Int?,
        allDaysRequests: Int? = nil,
        updatedAt: Date,
        sourceLabel: String
    ) {
        self.points = points
        self.todayTokens = todayTokens
        self.todayRequests = todayRequests
        self.last7DaysTokens = last7DaysTokens
        self.last7DaysRequests = last7DaysRequests
        self.last30DaysTokens = last30DaysTokens
        self.last30DaysRequests = last30DaysRequests
        self.allDaysTokens = allDaysTokens
        self.allDaysRequests = allDaysRequests
        self.updatedAt = updatedAt
        self.sourceLabel = sourceLabel
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.points = try container.decode([ProviderTokenTrendPoint].self, forKey: .points)
        self.todayTokens = try container.decodeIfPresent(Int.self, forKey: .todayTokens)
        self.todayRequests = try container.decodeIfPresent(Int.self, forKey: .todayRequests)
        self.last7DaysTokens = try container.decodeIfPresent(Int.self, forKey: .last7DaysTokens)
        self.last7DaysRequests = try container.decodeIfPresent(Int.self, forKey: .last7DaysRequests)
        self.last30DaysTokens = try container.decodeIfPresent(Int.self, forKey: .last30DaysTokens)
        self.last30DaysRequests = try container.decodeIfPresent(Int.self, forKey: .last30DaysRequests)
        self.allDaysTokens = try container.decodeIfPresent(Int.self, forKey: .allDaysTokens)
        self.allDaysRequests = try container.decodeIfPresent(Int.self, forKey: .allDaysRequests)
        self.updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        self.sourceLabel = try container.decode(String.self, forKey: .sourceLabel)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(points, forKey: .points)
        try container.encodeIfPresent(todayTokens, forKey: .todayTokens)
        try container.encodeIfPresent(todayRequests, forKey: .todayRequests)
        try container.encodeIfPresent(last7DaysTokens, forKey: .last7DaysTokens)
        try container.encodeIfPresent(last7DaysRequests, forKey: .last7DaysRequests)
        try container.encodeIfPresent(last30DaysTokens, forKey: .last30DaysTokens)
        try container.encodeIfPresent(last30DaysRequests, forKey: .last30DaysRequests)
        try container.encodeIfPresent(allDaysTokens, forKey: .allDaysTokens)
        try container.encodeIfPresent(allDaysRequests, forKey: .allDaysRequests)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(sourceLabel, forKey: .sourceLabel)
    }
}

public enum ProviderUsageCurveCapability: String, Codable, Sendable, Equatable {
    case dailyOnly
    case dailyWithIntradayDrilldown
}

public enum ProviderIntradayBucket: String, Codable, Sendable, Equatable, CaseIterable {
    case minute1
    case minute5
    case minute10
    case minute15
    case minute30
    case hour1

    public var title: String {
        switch self {
        case .minute1:
            return "1min"
        case .minute5:
            return "5min"
        case .minute10:
            return "10min"
        case .minute15:
            return "15min"
        case .minute30:
            return "30min"
        case .hour1:
            return "60min"
        }
    }

    public var seconds: TimeInterval {
        switch self {
        case .minute1:
            return 60
        case .minute5:
            return 5 * 60
        case .minute10:
            return 10 * 60
        case .minute15:
            return 15 * 60
        case .minute30:
            return 30 * 60
        case .hour1:
            return 60 * 60
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
    public let requestCount: Int

    private enum CodingKeys: String, CodingKey {
        case start
        case end
        case totalTokens
        case inputTokens
        case outputTokens
        case cacheReadTokens
        case requestCount
    }

    public init(
        start: Date,
        end: Date,
        totalTokens: Int,
        inputTokens: Int,
        outputTokens: Int,
        cacheReadTokens: Int,
        requestCount: Int = 0
    ) {
        self.start = start
        self.end = end
        self.totalTokens = totalTokens
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheReadTokens = cacheReadTokens
        self.requestCount = requestCount
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.start = try container.decode(Date.self, forKey: .start)
        self.end = try container.decode(Date.self, forKey: .end)
        self.totalTokens = try container.decode(Int.self, forKey: .totalTokens)
        self.inputTokens = try container.decode(Int.self, forKey: .inputTokens)
        self.outputTokens = try container.decode(Int.self, forKey: .outputTokens)
        self.cacheReadTokens = try container.decode(Int.self, forKey: .cacheReadTokens)
        self.requestCount = try container.decodeIfPresent(Int.self, forKey: .requestCount) ?? 0
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(start, forKey: .start)
        try container.encode(end, forKey: .end)
        try container.encode(totalTokens, forKey: .totalTokens)
        try container.encode(inputTokens, forKey: .inputTokens)
        try container.encode(outputTokens, forKey: .outputTokens)
        try container.encode(cacheReadTokens, forKey: .cacheReadTokens)
        try container.encode(requestCount, forKey: .requestCount)
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

extension ProviderIntradayUsagePoint {
    var hasUsage: Bool {
        totalTokens > 0 || inputTokens > 0 || outputTokens > 0 || cacheReadTokens > 0 || requestCount > 0
    }
}

extension ProviderIntradayUsageSnapshot {
    func trimmedForPresentation(referenceDate: Date = Date()) -> ProviderIntradayUsageSnapshot {
        let timezone = TimeZone(identifier: timezoneIdentifier) ?? .current
        let visibleRangeEnd = Self.visibleRangeEnd(
            dayKey: dayKey,
            timezone: timezone,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            referenceDate: referenceDate
        )

        let visiblePoints = points.filter { point in
            point.start >= rangeStart && point.start < visibleRangeEnd && point.hasUsage
        }

        guard !visiblePoints.isEmpty else {
            return ProviderIntradayUsageSnapshot(
                dayKey: dayKey,
                timezoneIdentifier: timezoneIdentifier,
                bucket: bucket,
                actualBucketCount: 0,
                rangeStart: rangeStart,
                rangeEnd: max(rangeStart, visibleRangeEnd),
                points: [],
                fetchedAt: fetchedAt,
                sourceLabel: sourceLabel
            )
        }
        let trimmedRangeStart = visiblePoints.first?.start ?? rangeStart
        let trimmedRangeEnd = min(visiblePoints.last?.end ?? visibleRangeEnd, visibleRangeEnd)

        return ProviderIntradayUsageSnapshot(
            dayKey: dayKey,
            timezoneIdentifier: timezoneIdentifier,
            bucket: bucket,
            actualBucketCount: visiblePoints.count,
            rangeStart: trimmedRangeStart,
            rangeEnd: trimmedRangeEnd,
            points: visiblePoints,
            fetchedAt: fetchedAt,
            sourceLabel: sourceLabel
        )
    }

    private static func visibleRangeEnd(
        dayKey: String,
        timezone: TimeZone,
        rangeStart: Date,
        rangeEnd: Date,
        referenceDate: Date
    ) -> Date {
        let todayKey = Self.dayKey(for: referenceDate, timezone: timezone)
        if dayKey == todayKey {
            return max(rangeStart, min(rangeEnd, referenceDate))
        }
        if dayKey > todayKey {
            return rangeStart
        }
        return rangeEnd
    }

    private static func dayKey(for date: Date, timezone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Self.calendar(timezone: timezone)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timezone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func calendar(timezone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        return calendar
    }
}
