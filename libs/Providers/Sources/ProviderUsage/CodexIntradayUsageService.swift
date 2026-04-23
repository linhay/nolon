import Foundation
import CodexProvider

public struct CodexIntradayUsageService: Sendable {
    public typealias ProjectedUsageLoader = @Sendable (
        _ dayKey: String,
        _ timezone: TimeZone,
        _ forceRefresh: Bool,
        _ environment: [String: String]
    ) async throws -> CodexSessionProjectedUsage?

    private let loadProjectedUsage: ProjectedUsageLoader
    private let now: @Sendable () -> Date

    public init(
        loadProjectedUsage: ProjectedUsageLoader? = nil,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.loadProjectedUsage = loadProjectedUsage ?? Self.defaultProjectedUsageLoader
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

        let projectedUsage = try await loadProjectedUsage(dayKey, timezone, false, globalEnvironment)
        return Self.buildSnapshot(
            from: projectedUsage,
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
        from projectedUsage: CodexSessionProjectedUsage?,
        dayKey: String,
        bucket: ProviderIntradayBucket,
        timezone: TimeZone,
        rangeStart: Date,
        rangeEnd: Date,
        fallbackFetchedAt: Date
    ) -> ProviderIntradayUsageSnapshot {
        let bucketSeconds = bucket.seconds
        let actualBucketCount = Int(ceil(rangeEnd.timeIntervalSince(rangeStart) / bucketSeconds))
        var totals = Array(
            repeating: IntradayBucketTotals(),
            count: max(0, actualBucketCount)
        )

        for entry in projectedUsage?.entries ?? [] {
            let bucketStart = entry.minuteStartAt
            guard bucketStart >= rangeStart,
                  bucketStart < rangeEnd,
                  !totals.isEmpty else {
                continue
            }

            let rawIndex = Int(bucketStart.timeIntervalSince(rangeStart) / bucketSeconds)
            let index = min(max(0, rawIndex), totals.count - 1)
            let input = max(0, entry.inputTokens)
            let cache = max(0, entry.cachedInputTokens)
            let output = max(0, entry.outputTokens)
            let requests = max(0, entry.requestCount)
            totals[index].input += input
            totals[index].cache += cache
            totals[index].output += output
            totals[index].total += input + output
            totals[index].requests += requests
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
                cacheReadTokens: item.cache,
                requestCount: item.requests
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
            fetchedAt: projectedUsage?.updatedAt ?? fallbackFetchedAt,
            sourceLabel: projectedUsage?.sourceLabel ?? "global local usage"
        )
    }

    static func makeDayRange(dayKey: String, timezone: TimeZone) -> (start: Date, end: Date)? {
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

    private static func calendar(timezone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        return calendar
    }

    static func defaultProjectedUsageLoader(
        dayKey: String,
        timezone: TimeZone,
        forceRefresh: Bool,
        environment: [String: String]
    ) throws -> CodexSessionProjectedUsage? {
        guard let range = Self.makeDayRange(dayKey: dayKey, timezone: timezone) else {
            return nil
        }
        let codexHome = Self.resolveCodexHomeURL(environment: environment)
        let store = CodexSessionStore()

        if forceRefresh {
            let projected = try store.loadProjectedUsageMinutes(
                codexHome: codexHome,
                rangeStart: range.start,
                rangeEnd: range.end
            )
            return projected.entries.isEmpty ? nil : projected
        }

        if let cached = try? store.loadCachedProjectedUsageMinutes(
            codexHome: codexHome,
            rangeStart: range.start,
            rangeEnd: range.end
        ),
           !cached.entries.isEmpty {
            return cached
        }

        let projected = try store.loadProjectedUsageMinutes(
            codexHome: codexHome,
            rangeStart: range.start,
            rangeEnd: range.end
        )
        return projected.entries.isEmpty ? nil : projected
    }

    static func resolveCodexHomeURL(environment: [String: String]) -> URL {
        if let override = environment["CODEX_HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        return URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            .appendingPathComponent(".codex", isDirectory: true)
    }
}

private struct IntradayBucketTotals: Sendable {
    var total = 0
    var input = 0
    var output = 0
    var cache = 0
    var requests = 0
}
