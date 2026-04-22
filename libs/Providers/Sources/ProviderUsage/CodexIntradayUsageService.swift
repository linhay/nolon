import Foundation
import CodexBarProviderCatalog
import CodexProvider

public struct CostUsageQuarterHourDay: Sendable, Equatable {
    public let dayKey: String
    public let quarterHours: [String: [Int]]
    public let updatedAt: Date
    public let sourceLabel: String

    public init(
        dayKey: String,
        quarterHours: [String: [Int]],
        updatedAt: Date,
        sourceLabel: String
    ) {
        self.dayKey = dayKey
        self.quarterHours = quarterHours
        self.updatedAt = updatedAt
        self.sourceLabel = sourceLabel
    }
}

public struct CodexIntradayUsageService: Sendable {
    public typealias QuarterHoursLoader = @Sendable (
        _ provider: UsageProvider,
        _ dayKey: String,
        _ timezone: TimeZone,
        _ forceRefresh: Bool,
        _ environment: [String: String]
    ) async throws -> CostUsageQuarterHourDay?

    private let loadQuarterHours: QuarterHoursLoader
    private let now: @Sendable () -> Date

    public init(
        loadQuarterHours: @escaping QuarterHoursLoader = { provider, dayKey, timezone, forceRefresh, environment in
            let fetched = try await CodexQuarterHourUsageFetcher().loadQuarterHourDay(
                provider: provider,
                dayKey: dayKey,
                timezone: timezone,
                forceRefresh: forceRefresh,
                environment: environment
            )
            return fetched.map {
                CostUsageQuarterHourDay(
                    dayKey: $0.dayKey,
                    quarterHours: $0.quarterHours,
                    updatedAt: $0.updatedAt,
                    sourceLabel: $0.sourceLabel
                )
            }
        },
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.loadQuarterHours = loadQuarterHours
        self.now = now
    }

    public func fetchGlobalSnapshot(
        dayKey: String,
        bucket: ProviderIntradayBucket = .minute30,
        timezone: TimeZone = .current,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) async throws -> ProviderIntradayUsageSnapshot? {
        guard let range = Self.makeDayRange(dayKey: dayKey, timezone: timezone) else {
            return nil
        }
        let referenceDate = now()

        var globalEnvironment = environment
        globalEnvironment.removeValue(forKey: "CODEX_HOME")

        let quarterHourDay = try await loadQuarterHours(.codex, dayKey, timezone, false, globalEnvironment)
        return Self.buildSnapshot(
            from: quarterHourDay,
            dayKey: dayKey,
            bucket: bucket,
            timezone: timezone,
            rangeStart: range.start,
            rangeEnd: range.end,
            fallbackFetchedAt: referenceDate
        )
        .trimmedForPresentation(referenceDate: referenceDate)
    }

    private static func buildSnapshot(
        from day: CostUsageQuarterHourDay?,
        dayKey: String,
        bucket: ProviderIntradayBucket,
        timezone: TimeZone,
        rangeStart: Date,
        rangeEnd: Date,
        fallbackFetchedAt: Date
    ) -> ProviderIntradayUsageSnapshot {
        let bucketSeconds = Self.bucketSeconds(for: bucket)
        let actualBucketCount = Int((rangeEnd.timeIntervalSince(rangeStart) / bucketSeconds).rounded())
        var totals = Array(
            repeating: IntradayBucketTotals(),
            count: max(0, actualBucketCount)
        )

        for (quarterHourKey, packed) in day?.quarterHours ?? [:] {
            guard let bucketStart = Self.makeBucketStart(
                dayKey: dayKey,
                bucketKey: quarterHourKey,
                timezone: timezone
            ) else {
                continue
            }
            guard bucketStart >= rangeStart, bucketStart < rangeEnd, !totals.isEmpty else {
                continue
            }

            let rawIndex = Int(bucketStart.timeIntervalSince(rangeStart) / bucketSeconds)
            let index = min(max(0, rawIndex), totals.count - 1)
            let input = max(0, packed[safe: 0] ?? 0)
            let cache = max(0, packed[safe: 1] ?? 0)
            let output = max(0, packed[safe: 2] ?? 0)
            totals[index].input += input
            totals[index].cache += cache
            totals[index].output += output
            totals[index].total += input + output
        }

        let points = totals.enumerated().map { index, item in
            let start = rangeStart.addingTimeInterval(Double(index) * bucketSeconds)
            let end = min(start.addingTimeInterval(bucketSeconds), rangeEnd)
            return ProviderIntradayUsagePoint(
                start: start,
                end: end,
                totalTokens: item.total,
                inputTokens: item.input,
                outputTokens: item.output,
                cacheReadTokens: item.cache
            )
        }

        return ProviderIntradayUsageSnapshot(
            dayKey: dayKey,
            timezoneIdentifier: timezone.identifier,
            bucket: bucket,
            actualBucketCount: actualBucketCount,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            points: points,
            fetchedAt: day?.updatedAt ?? fallbackFetchedAt,
            sourceLabel: day?.sourceLabel ?? "global local usage"
        )
    }

    private static func makeDayRange(dayKey: String, timezone: TimeZone) -> (start: Date, end: Date)? {
        let formatter = DateFormatter()
        formatter.calendar = Self.calendar(timezone: timezone)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timezone
        formatter.dateFormat = "yyyy-MM-dd"
        guard let start = formatter.date(from: dayKey) else { return nil }
        guard let end = formatter.calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
        return (start, end)
    }

    private static func makeBucketStart(
        dayKey: String,
        bucketKey: String,
        timezone: TimeZone
    ) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Self.calendar(timezone: timezone)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timezone
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: "\(dayKey) \(bucketKey)")
    }

    private static func bucketSeconds(for bucket: ProviderIntradayBucket) -> TimeInterval {
        switch bucket {
        case .minute15:
            return 15 * 60
        case .minute30:
            return 30 * 60
        case .hour1:
            return 60 * 60
        }
    }

    private static func calendar(timezone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        return calendar
    }
}

private struct IntradayBucketTotals: Sendable {
    var total = 0
    var input = 0
    var output = 0
    var cache = 0
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
