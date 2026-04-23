import Foundation

public struct ClaudeTokenTrendService: Sendable {
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
        trailingDays: Int? = nil,
        timezone: TimeZone = .current
    ) async throws -> ProviderTokenTrendSnapshot? {
        guard try await loadActiveAccount() != nil else {
            return nil
        }

        let referenceDate = now()
        let projectRoots = loadProjectsRoots()
        guard !projectRoots.isEmpty else {
            return Self.emptySnapshot(referenceDate: referenceDate)
        }

        let sessionFiles = try listSessionFiles(projectRoots)
        guard !sessionFiles.isEmpty else {
            return Self.emptySnapshot(referenceDate: referenceDate)
        }

        let snapshot = try await usageStore.loadSnapshot(
            projectFiles: sessionFiles,
            readFile: readFile,
            loadFileFingerprint: loadFileFingerprint
        )

        let allPoints = Self.makeDailyPoints(events: snapshot.events, timezone: timezone)
        let points: [ProviderTokenTrendPoint]
        if let trailingDays, trailingDays > 0, allPoints.count > trailingDays {
            points = Array(allPoints.suffix(trailingDays))
        } else {
            points = allPoints
        }

        return ProviderTokenTrendSnapshot(
            points: points,
            todayTokens: Self.todayTokens(from: allPoints, now: referenceDate, timezone: timezone),
            todayRequests: Self.todayRequests(from: allPoints, now: referenceDate, timezone: timezone),
            last7DaysTokens: Self.sumTrailing(points: allPoints, days: 7),
            last7DaysRequests: Self.sumTrailingRequests(points: allPoints, days: 7),
            last30DaysTokens: Self.sumTrailing(points: allPoints, days: 30),
            last30DaysRequests: Self.sumTrailingRequests(points: allPoints, days: 30),
            allDaysTokens: Self.sumAll(points: allPoints),
            allDaysRequests: Self.sumAllRequests(points: allPoints),
            updatedAt: referenceDate,
            sourceLabel: "session"
        )
    }

    private static func emptySnapshot(referenceDate: Date) -> ProviderTokenTrendSnapshot {
        ProviderTokenTrendSnapshot(
            points: [],
            todayTokens: nil,
            todayRequests: nil,
            last7DaysTokens: nil,
            last7DaysRequests: nil,
            last30DaysTokens: nil,
            last30DaysRequests: nil,
            allDaysTokens: nil,
            allDaysRequests: nil,
            updatedAt: referenceDate,
            sourceLabel: "session"
        )
    }

    private static func makeDailyPoints(
        events: [ClaudeCachedTokenEvent],
        timezone: TimeZone
    ) -> [ProviderTokenTrendPoint] {
        var totalsByDay: [String: ClaudeDailyTotals] = [:]

        for event in events {
            let dayKey = ClaudeSessionUsageSupport.dayKey(from: event.timestamp, timezone: timezone)
            var totals = totalsByDay[dayKey, default: ClaudeDailyTotals()]
            totals.input += event.input
            totals.output += event.output
            totals.cacheRead += event.cacheRead
            totals.total += event.total
            totals.requests += event.requestCount
            totalsByDay[dayKey] = totals
        }

        return totalsByDay.keys.sorted().map { dayKey in
            let totals = totalsByDay[dayKey, default: ClaudeDailyTotals()]
            return ProviderTokenTrendPoint(
                date: dayKey,
                totalTokens: totals.total,
                inputTokens: totals.input,
                outputTokens: totals.output,
                cacheReadTokens: totals.cacheRead,
                requestCount: totals.requests
            )
        }
    }

    private static func todayTokens(
        from points: [ProviderTokenTrendPoint],
        now: Date,
        timezone: TimeZone
    ) -> Int {
        let todayKey = ClaudeSessionUsageSupport.dayKey(from: now, timezone: timezone)
        return points.first(where: { $0.date == todayKey })?.totalTokens ?? 0
    }

    private static func todayRequests(
        from points: [ProviderTokenTrendPoint],
        now: Date,
        timezone: TimeZone
    ) -> Int {
        let todayKey = ClaudeSessionUsageSupport.dayKey(from: now, timezone: timezone)
        return points.first(where: { $0.date == todayKey })?.requestCount ?? 0
    }

    private static func sumTrailing(points: [ProviderTokenTrendPoint], days: Int) -> Int? {
        guard days > 0, !points.isEmpty else { return nil }
        let values = points.suffix(days).map(\.totalTokens)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +)
    }

    private static func sumTrailingRequests(points: [ProviderTokenTrendPoint], days: Int) -> Int? {
        guard days > 0, !points.isEmpty else { return nil }
        let values = points.suffix(days).map(\.requestCount)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +)
    }

    private static func sumAll(points: [ProviderTokenTrendPoint]) -> Int? {
        guard !points.isEmpty else { return nil }
        return points.map(\.totalTokens).reduce(0, +)
    }

    private static func sumAllRequests(points: [ProviderTokenTrendPoint]) -> Int? {
        guard !points.isEmpty else { return nil }
        return points.map(\.requestCount).reduce(0, +)
    }
}

private struct ClaudeDailyTotals: Sendable {
    var input = 0
    var output = 0
    var cacheRead = 0
    var total = 0
    var requests = 0
}
