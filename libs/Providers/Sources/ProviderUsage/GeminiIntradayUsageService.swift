import Foundation
import CodexBarProviderCatalog

public struct GeminiIntradayUsageService: Sendable {
    typealias LoadActiveAccount = @Sendable (UsageProvider) async throws -> GeminiAuthAccount?
    typealias LoadSessionRoot = @Sendable () -> URL?
    typealias ListSessionFiles = @Sendable (URL) throws -> [URL]
    typealias ReadFile = @Sendable (URL) throws -> String
    typealias LoadFileFingerprint = @Sendable (URL) -> GeminiSessionFileFingerprint

    private let loadActiveAccount: LoadActiveAccount
    private let loadSessionRoot: LoadSessionRoot
    private let listSessionFiles: ListSessionFiles
    private let readFile: ReadFile
    private let loadFileFingerprint: LoadFileFingerprint
    private let usageStore: GeminiSessionUsageStore
    private let now: @Sendable () -> Date

    public init() {
        let store = GeminiAuthStore.shared
        self.loadActiveAccount = { provider in
            try await store.activeAccount(provider: provider)
        }
        self.loadSessionRoot = GeminiSessionUsageSupport.defaultSessionRoot
        self.listSessionFiles = GeminiSessionUsageSupport.defaultListSessionFiles
        self.readFile = { url in
            try String(contentsOf: url, encoding: .utf8)
        }
        self.loadFileFingerprint = GeminiSessionUsageStore.defaultLoadFileFingerprint
        self.usageStore = .shared
        self.now = Date.init
    }

    init(
        loadActiveAccount: @escaping LoadActiveAccount,
        loadSessionRoot: @escaping LoadSessionRoot = { nil },
        listSessionFiles: @escaping ListSessionFiles,
        readFile: @escaping ReadFile,
        loadFileFingerprint: @escaping LoadFileFingerprint = GeminiSessionUsageStore.defaultLoadFileFingerprint,
        usageStore: GeminiSessionUsageStore = GeminiSessionUsageStore(cacheFileURL: nil),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.loadActiveAccount = loadActiveAccount
        self.loadSessionRoot = loadSessionRoot
        self.listSessionFiles = listSessionFiles
        self.readFile = readFile
        self.loadFileFingerprint = loadFileFingerprint
        self.usageStore = usageStore
        self.now = now
    }

    public func fetchActiveSnapshot(
        provider: UsageProvider,
        dayKey: String,
        bucket: ProviderIntradayBucket = .minute30,
        timezone: TimeZone = .current
    ) async throws -> ProviderIntradayUsageSnapshot? {
        guard let account = try await loadActiveAccount(provider) else {
            return nil
        }
        _ = account
        let referenceDate = now()

        guard let range = Self.makeDayRange(dayKey: dayKey, timezone: timezone) else {
            return nil
        }

        guard let sessionRoot = loadSessionRoot() else {
            return Self.emptySnapshot(
                dayKey: dayKey,
                bucket: bucket,
                timezone: timezone,
                rangeStart: range.start,
                rangeEnd: range.end,
                fetchedAt: referenceDate
            )
            .trimmedForPresentation(referenceDate: referenceDate)
        }

        let sessionFiles = try listSessionFiles(sessionRoot)
        guard !sessionFiles.isEmpty else {
            return Self.emptySnapshot(
                dayKey: dayKey,
                bucket: bucket,
                timezone: timezone,
                rangeStart: range.start,
                rangeEnd: range.end,
                fetchedAt: referenceDate
            )
            .trimmedForPresentation(referenceDate: referenceDate)
        }

        let usageSnapshot = try await usageStore.loadSnapshot(
            sessionFiles: sessionFiles,
            readFile: readFile,
            loadFileFingerprint: loadFileFingerprint
        )
        let bucketSeconds = bucket.seconds
        let actualBucketCount = Int(ceil(range.end.timeIntervalSince(range.start) / bucketSeconds))
        var totals = Array(
            repeating: GeminiIntradayBucketTotals(),
            count: max(0, actualBucketCount)
        )

        for event in usageSnapshot.events {
            let timestamp = event.timestamp
            guard timestamp >= range.start,
                  timestamp < range.end,
                  !totals.isEmpty else {
                continue
            }

            let secondsSinceDayStart = timestamp.timeIntervalSince(range.start)
            let rawIndex = Int(secondsSinceDayStart / bucketSeconds)
            let bucketIndex = min(max(0, rawIndex), totals.count - 1)
            totals[bucketIndex].input += event.input
            totals[bucketIndex].output += event.output
            totals[bucketIndex].cached += event.cached
            totals[bucketIndex].total += event.total
            totals[bucketIndex].requests += event.requestCount
        }

        let points = totals.enumerated().map { index, item in
            let start = range.start.addingTimeInterval(Double(index) * bucketSeconds)
            let end = min(start.addingTimeInterval(bucketSeconds), range.end)
            return ProviderIntradayUsagePoint(
                start: start,
                end: end,
                totalTokens: item.total,
                inputTokens: item.input,
                outputTokens: item.output,
                cacheReadTokens: item.cached,
                requestCount: item.requests
            )
        }

        return ProviderIntradayUsageSnapshot(
            dayKey: dayKey,
            timezoneIdentifier: timezone.identifier,
            bucket: bucket,
            actualBucketCount: actualBucketCount,
            rangeStart: range.start,
            rangeEnd: range.end,
            points: points,
            fetchedAt: referenceDate,
            sourceLabel: "session"
        )
        .trimmedForPresentation(referenceDate: referenceDate)
    }

    private static func emptySnapshot(
        dayKey: String,
        bucket: ProviderIntradayBucket,
        timezone: TimeZone,
        rangeStart: Date,
        rangeEnd: Date,
        fetchedAt: Date
    ) -> ProviderIntradayUsageSnapshot {
        let bucketSeconds = bucket.seconds
        let actualBucketCount = Int(ceil(rangeEnd.timeIntervalSince(rangeStart) / bucketSeconds))
        let points = (0..<actualBucketCount).map { index in
            let start = rangeStart.addingTimeInterval(Double(index) * bucketSeconds)
            let end = min(start.addingTimeInterval(bucketSeconds), rangeEnd)
            return ProviderIntradayUsagePoint(
                start: start,
                end: end,
                totalTokens: 0,
                inputTokens: 0,
                outputTokens: 0,
                cacheReadTokens: 0,
                requestCount: 0
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
            fetchedAt: fetchedAt,
            sourceLabel: "session"
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

    private static func calendar(timezone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        return calendar
    }
}

private struct GeminiIntradayBucketTotals {
    var input = 0
    var output = 0
    var cached = 0
    var total = 0
    var requests = 0
}
