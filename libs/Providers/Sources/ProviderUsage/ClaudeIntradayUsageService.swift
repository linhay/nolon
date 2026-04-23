import Foundation

public struct ClaudeIntradayUsageService: Sendable {
    typealias LoadActiveAccount = @Sendable () async throws -> ClaudeAccount?
    typealias LoadProjectsRoots = @Sendable () -> [URL]
    typealias ListSessionFiles = @Sendable ([URL]) throws -> [URL]
    typealias ReadFile = @Sendable (URL) throws -> String
    typealias LoadFileFingerprint = @Sendable (URL) -> ClaudeSessionFileFingerprint

    private let loadActiveAccount: LoadActiveAccount
    private let loadProjectsRoots: LoadProjectsRoots
    private let listSessionFiles: ListSessionFiles
    private let readFile: ReadFile
    private let loadFileFingerprint: LoadFileFingerprint
    private let usageStore: ClaudeSessionUsageStore
    private let now: @Sendable () -> Date

    public init() {
        let manager = ClaudeAccountManager()
        self.loadActiveAccount = {
            guard let activeID = try await manager.activeAccountID() else { return nil }
            let accounts = try await manager.loadAccounts()
            return accounts.first(where: { $0.id == activeID })
        }
        self.loadProjectsRoots = {
            ClaudeSessionUsageSupport.defaultProjectsRoots()
        }
        self.listSessionFiles = { roots in
            try ClaudeSessionUsageSupport.defaultListSessionFiles(roots: roots)
        }
        self.readFile = { url in
            try String(contentsOf: url, encoding: .utf8)
        }
        self.loadFileFingerprint = ClaudeSessionUsageStore.defaultLoadFileFingerprint
        self.usageStore = .shared
        self.now = Date.init
    }

    init(
        loadActiveAccount: @escaping LoadActiveAccount,
        loadProjectsRoots: @escaping LoadProjectsRoots = { [] },
        listSessionFiles: @escaping ListSessionFiles,
        readFile: @escaping ReadFile,
        loadFileFingerprint: @escaping LoadFileFingerprint = ClaudeSessionUsageStore.defaultLoadFileFingerprint,
        usageStore: ClaudeSessionUsageStore = .shared,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.loadActiveAccount = loadActiveAccount
        self.loadProjectsRoots = loadProjectsRoots
        self.listSessionFiles = listSessionFiles
        self.readFile = readFile
        self.loadFileFingerprint = loadFileFingerprint
        self.usageStore = usageStore
        self.now = now
    }

    public func fetchActiveSnapshot(
        dayKey: String,
        bucket: ProviderIntradayBucket = .minute30,
        timezone: TimeZone = .current
    ) async throws -> ProviderIntradayUsageSnapshot? {
        guard try await loadActiveAccount() != nil else {
            return nil
        }

        let referenceDate = now()
        guard let range = ClaudeSessionUsageSupport.makeDayRange(dayKey: dayKey, timezone: timezone) else {
            return nil
        }

        let projectRoots = loadProjectsRoots()
        guard !projectRoots.isEmpty else {
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

        let sessionFiles = try listSessionFiles(projectRoots)
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

        let snapshot = try await usageStore.loadSnapshot(
            projectFiles: sessionFiles,
            readFile: readFile,
            loadFileFingerprint: loadFileFingerprint
        )

        let bucketSeconds = bucket.seconds
        let actualBucketCount = Int(ceil(range.end.timeIntervalSince(range.start) / bucketSeconds))
        var totals = Array(
            repeating: ClaudeIntradayBucketTotals(),
            count: max(0, actualBucketCount)
        )

        for event in snapshot.events {
            guard event.timestamp >= range.start,
                  event.timestamp < range.end,
                  !totals.isEmpty else {
                continue
            }

            let secondsSinceDayStart = event.timestamp.timeIntervalSince(range.start)
            let rawIndex = Int(secondsSinceDayStart / bucketSeconds)
            let bucketIndex = min(max(0, rawIndex), totals.count - 1)
            totals[bucketIndex].input += event.input
            totals[bucketIndex].output += event.output
            totals[bucketIndex].cacheRead += event.cacheRead
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
                cacheReadTokens: item.cacheRead,
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

}

private struct ClaudeIntradayBucketTotals: Sendable {
    var input = 0
    var output = 0
    var cacheRead = 0
    var total = 0
    var requests = 0
}
