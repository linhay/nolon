import Foundation
import CodexBarProviderCatalog
import CodexProvider

public struct CodexTokenTrendService: Sendable {
    public typealias SnapshotLoader = @Sendable (
        _ provider: UsageProvider,
        _ trailingDays: Int?,
        _ forceRefresh: Bool,
        _ environment: [String: String]
    ) async throws -> CostUsageTokenSnapshot
    typealias RefreshAffectedDayKeysLoader = @Sendable (
        _ codexHome: URL,
        _ timezone: TimeZone
    ) throws -> [String]
    typealias CachedProjectedUsageLoader = @Sendable (
        _ codexHome: URL,
        _ rangeStart: Date?,
        _ rangeEnd: Date?
    ) throws -> CodexSessionProjectedUsage?

    private let loadSnapshot: SnapshotLoader
    private let cacheStore: CodexTokenTrendSnapshotCache
    private let refreshAffectedDayKeys: RefreshAffectedDayKeysLoader
    private let loadCachedProjectedUsage: CachedProjectedUsageLoader
    private let now: @Sendable () -> Date

    public init(loadSnapshot: @escaping SnapshotLoader = { provider, _, _, environment in
            guard provider == .codex else {
                throw CostUsageError.unsupportedProvider(provider)
            }
            return try Self.loadSessionBackedSnapshot(environment: environment)
        }) {
        self.init(
            loadSnapshot: loadSnapshot,
            cacheStore: .init(),
            refreshAffectedDayKeys: { codexHome, timezone in
                try CodexSessionStore().refreshChangedProjectedUsageDayKeys(
                    codexHome: codexHome,
                    timezone: timezone
                )
            },
            loadCachedProjectedUsage: { codexHome, rangeStart, rangeEnd in
                let projected = try CodexSessionStore().loadCachedProjectedUsageMinutes(
                    codexHome: codexHome,
                    rangeStart: rangeStart,
                    rangeEnd: rangeEnd
                )
                return projected.entries.isEmpty ? nil : projected
            },
            now: Date.init
        )
    }

    init(
        loadSnapshot: @escaping SnapshotLoader,
        cacheStore: CodexTokenTrendSnapshotCache,
        refreshAffectedDayKeys: @escaping RefreshAffectedDayKeysLoader = { _, _ in [] },
        loadCachedProjectedUsage: @escaping CachedProjectedUsageLoader,
        now: @escaping @Sendable () -> Date
    ) {
        self.loadSnapshot = loadSnapshot
        self.cacheStore = cacheStore
        self.refreshAffectedDayKeys = refreshAffectedDayKeys
        self.loadCachedProjectedUsage = loadCachedProjectedUsage
        self.now = now
    }

    public func fetchGlobalSnapshot(
        trailingDays: Int? = 30,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) async throws -> ProviderTokenTrendSnapshot {
        var globalEnvironment = environment
        globalEnvironment.removeValue(forKey: "CODEX_HOME")

        // Always load the full history, then slice points locally for the selected chart range.
        // Summary cards (especially ALL) must be computed from the complete dataset.
        let snapshot = try await loadSnapshot(.codex, nil, false, globalEnvironment)
        let fullSnapshot = makeProviderSnapshot(from: snapshot, trailingDays: nil)
        let codexHome = Self.resolveCodexHomeURL(environment: globalEnvironment)
        try? cacheStore.save(fullSnapshot, codexHome: codexHome)
        return Self.slice(snapshot: fullSnapshot, trailingDays: trailingDays)
    }

    public func fetchCachedGlobalSnapshot(
        trailingDays: Int? = 30,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> ProviderTokenTrendSnapshot? {
        var globalEnvironment = environment
        globalEnvironment.removeValue(forKey: "CODEX_HOME")

        let codexHome = Self.resolveCodexHomeURL(environment: globalEnvironment)
        let now = now()
        guard let cachedSnapshot = cachedBaseSnapshot(
            codexHome: codexHome,
            timezone: .current,
            now: now
        ) else {
            return nil
        }
        return Self.slice(snapshot: cachedSnapshot, trailingDays: trailingDays)
    }

    public func fetchRefreshedGlobalSnapshot(
        trailingDays: Int? = 30,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) async throws -> ProviderTokenTrendSnapshot {
        var globalEnvironment = environment
        globalEnvironment.removeValue(forKey: "CODEX_HOME")

        let codexHome = Self.resolveCodexHomeURL(environment: globalEnvironment)
        let now = now()
        guard let cachedSnapshot = cachedBaseSnapshot(
            codexHome: codexHome,
            timezone: .current,
            now: now
        ) else {
            return try await fetchGlobalSnapshot(
                trailingDays: trailingDays,
                environment: globalEnvironment
            )
        }

        let refreshedSnapshot = try await refreshCachedSnapshot(
            cachedSnapshot,
            codexHome: codexHome,
            timezone: .current,
            now: now
        )
        try? cacheStore.save(refreshedSnapshot, codexHome: codexHome)
        return Self.slice(snapshot: refreshedSnapshot, trailingDays: trailingDays)
    }

    private func cachedBaseSnapshot(
        codexHome: URL,
        timezone: TimeZone,
        now: Date
    ) -> ProviderTokenTrendSnapshot? {
        guard let cachedSnapshot = try? cacheStore.load(codexHome: codexHome) else {
            return nil
        }
        return reconcileCachedSnapshot(
            cachedSnapshot,
            codexHome: codexHome,
            timezone: timezone,
            now: now
        )
    }

    private func makeProviderSnapshot(
        from snapshot: CostUsageTokenSnapshot,
        trailingDays: Int?
    ) -> ProviderTokenTrendSnapshot {
        let allPoints = snapshot.daily
            .map { entry in
                let input = max(0, entry.inputTokens ?? 0)
                let output = max(0, entry.outputTokens ?? 0)
                let cache = max(0, entry.cacheReadTokens ?? 0)
                let total = max(0, entry.totalTokens ?? (input + output))
                let requests = max(0, entry.requestCount ?? 0)
                return ProviderTokenTrendPoint(
                    date: entry.date,
                    totalTokens: total,
                    inputTokens: input,
                    outputTokens: output,
                    cacheReadTokens: cache,
                    requestCount: requests
                )
            }
            .sorted { $0.date < $1.date }

        let points: [ProviderTokenTrendPoint]
        if let trailingDays, trailingDays > 0, allPoints.count > trailingDays {
            points = Array(allPoints.suffix(trailingDays))
        } else {
            points = allPoints
        }

        let today = todayTokens(
            from: allPoints,
            sessionTokens: snapshot.sessionTokens,
            now: snapshot.updatedAt
        )
        let todayRequests = self.todayRequests(
            from: allPoints,
            sessionRequests: snapshot.sessionRequests ?? snapshot.todayRequests,
            now: snapshot.updatedAt
        )
        let last7 = Self.sumTrailing(points: allPoints, days: 7)
        let last7Requests = Self.sumTrailingRequests(points: allPoints, days: 7)
        let last30 = Self.sumTrailing(points: allPoints, days: 30)
        let last30Requests = Self.sumTrailingRequests(points: allPoints, days: 30)
        let all = Self.sumAll(points: allPoints)
        let allRequests = Self.sumAllRequests(points: allPoints)

        return ProviderTokenTrendSnapshot(
            points: points,
            todayTokens: today,
            todayRequests: todayRequests,
            last7DaysTokens: last7,
            last7DaysRequests: last7Requests,
            last30DaysTokens: last30,
            last30DaysRequests: last30Requests,
            allDaysTokens: all,
            allDaysRequests: allRequests,
            updatedAt: snapshot.updatedAt,
            sourceLabel: "global local usage"
        )
    }

    private static func slice(
        snapshot: ProviderTokenTrendSnapshot,
        trailingDays: Int?
    ) -> ProviderTokenTrendSnapshot {
        let points: [ProviderTokenTrendPoint]
        if let trailingDays, trailingDays > 0, snapshot.points.count > trailingDays {
            points = Array(snapshot.points.suffix(trailingDays))
        } else {
            points = snapshot.points
        }

        return ProviderTokenTrendSnapshot(
            points: points,
            todayTokens: snapshot.todayTokens,
            todayRequests: snapshot.todayRequests,
            last7DaysTokens: snapshot.last7DaysTokens,
            last7DaysRequests: snapshot.last7DaysRequests,
            last30DaysTokens: snapshot.last30DaysTokens,
            last30DaysRequests: snapshot.last30DaysRequests,
            allDaysTokens: snapshot.allDaysTokens,
            allDaysRequests: snapshot.allDaysRequests,
            updatedAt: snapshot.updatedAt,
            sourceLabel: snapshot.sourceLabel
        )
    }

    private func reconcileCachedSnapshot(
        _ snapshot: ProviderTokenTrendSnapshot,
        codexHome: URL,
        timezone: TimeZone,
        now: Date
    ) -> ProviderTokenTrendSnapshot {
        guard let todayRange = Self.dayRange(for: now, timezone: timezone),
              let projected = try? loadCachedProjectedUsage(codexHome, todayRange.start, todayRange.end),
              let todayPoint = Self.makePoint(
                from: projected,
                dayKey: Self.dayKey(from: now, timezone: timezone)
              )
        else {
            return snapshot
        }

        var points = snapshot.points.filter { $0.date != todayPoint.date }
        points.append(todayPoint)
        points.sort { $0.date < $1.date }

        return Self.makeProviderSnapshot(
            from: points,
            updatedAt: max(snapshot.updatedAt, projected.updatedAt),
            sourceLabel: snapshot.sourceLabel,
            todayKey: todayPoint.date
        )
    }

    private func refreshCachedSnapshot(
        _ snapshot: ProviderTokenTrendSnapshot,
        codexHome: URL,
        timezone: TimeZone,
        now: Date
    ) async throws -> ProviderTokenTrendSnapshot {
        let affectedDayKeys = try refreshAffectedDayKeys(codexHome, timezone)
        guard !affectedDayKeys.isEmpty else {
            return snapshot
        }

        var mergedPointsByDay = Dictionary(uniqueKeysWithValues: snapshot.points.map { ($0.date, $0) })
        var updatedAt = snapshot.updatedAt

        for dayKey in affectedDayKeys {
            guard let dayRange = Self.dayRange(forDayKey: dayKey, timezone: timezone) else {
                mergedPointsByDay.removeValue(forKey: dayKey)
                continue
            }

            let projected = try loadCachedProjectedUsage(codexHome, dayRange.start, dayRange.end)
            if let projected {
                updatedAt = max(updatedAt, projected.updatedAt)
            }

            if let projected,
               let point = Self.makePoint(from: projected, dayKey: dayKey) {
                mergedPointsByDay[dayKey] = point
            } else {
                mergedPointsByDay.removeValue(forKey: dayKey)
            }
        }

        return Self.makeProviderSnapshot(
            from: Array(mergedPointsByDay.values),
            updatedAt: updatedAt,
            sourceLabel: snapshot.sourceLabel,
            todayKey: Self.dayKey(from: now, timezone: timezone)
        )
    }

    private static func makeProviderSnapshot(
        from points: [ProviderTokenTrendPoint],
        updatedAt: Date,
        sourceLabel: String,
        todayKey: String
    ) -> ProviderTokenTrendSnapshot {
        let sortedPoints = points.sorted { $0.date < $1.date }
        let today = sortedPoints.first(where: { $0.date == todayKey })?.totalTokens ?? 0
        let todayRequests = sortedPoints.first(where: { $0.date == todayKey })?.requestCount ?? 0
        let last7 = sumTrailing(points: sortedPoints, days: 7)
        let last7Requests = sumTrailingRequests(points: sortedPoints, days: 7)
        let last30 = sumTrailing(points: sortedPoints, days: 30)
        let last30Requests = sumTrailingRequests(points: sortedPoints, days: 30)
        let all = sumAll(points: sortedPoints)
        let allRequests = sumAllRequests(points: sortedPoints)

        return ProviderTokenTrendSnapshot(
            points: sortedPoints,
            todayTokens: today,
            todayRequests: todayRequests,
            last7DaysTokens: last7,
            last7DaysRequests: last7Requests,
            last30DaysTokens: last30,
            last30DaysRequests: last30Requests,
            allDaysTokens: all,
            allDaysRequests: allRequests,
            updatedAt: updatedAt,
            sourceLabel: sourceLabel
        )
    }

    private static func sumTrailing(points: [CodexTokenTrendPoint], days: Int) -> Int? {
        guard days > 0, !points.isEmpty else { return nil }
        let values = points.suffix(days).map(\.totalTokens)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +)
    }

    private static func sumAll(points: [CodexTokenTrendPoint]) -> Int? {
        guard !points.isEmpty else { return nil }
        return points.map(\.totalTokens).reduce(0, +)
    }

    private static func sumTrailingRequests(points: [CodexTokenTrendPoint], days: Int) -> Int? {
        guard days > 0, !points.isEmpty else { return nil }
        let values = points.suffix(days).map(\.requestCount)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +)
    }

    private static func sumAllRequests(points: [CodexTokenTrendPoint]) -> Int? {
        guard !points.isEmpty else { return nil }
        return points.map(\.requestCount).reduce(0, +)
    }

    private func todayTokens(
        from points: [CodexTokenTrendPoint],
        sessionTokens: Int?,
        now: Date
    ) -> Int {
        if let sessionTokens {
            return max(0, sessionTokens)
        }

        let todayKey = Self.dayKey(from: now)
        return points.first(where: { $0.date == todayKey })?.totalTokens ?? 0
    }

    private func todayRequests(
        from points: [CodexTokenTrendPoint],
        sessionRequests: Int?,
        now: Date
    ) -> Int {
        if let sessionRequests {
            return max(0, sessionRequests)
        }

        let todayKey = Self.dayKey(from: now)
        return points.first(where: { $0.date == todayKey })?.requestCount ?? 0
    }

    private static func dayKey(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    public static func loadSessionBackedSnapshot(
        environment: [String: String]
    ) throws -> CostUsageTokenSnapshot {
        try loadSessionBackedSnapshot(
            environment: environment,
            timezone: TimeZone.current,
            now: Date(),
            loadProjectedUsage: { codexHome in
                try CodexSessionStore().loadProjectedUsageMinutes(codexHome: codexHome)
            }
        )
    }

    static func loadSessionBackedSnapshot(
        environment: [String: String],
        timezone: TimeZone,
        now: Date,
        loadProjectedUsage: (URL) throws -> CodexSessionProjectedUsage
    ) throws -> CostUsageTokenSnapshot {
        let codexHome = resolveCodexHomeURL(environment: environment)
        let projected = try loadProjectedUsage(codexHome)
        return makeTokenSnapshot(from: projected, timezone: timezone, now: now)
    }

    static func makePoint(
        from projected: CodexSessionProjectedUsage,
        dayKey: String
    ) -> ProviderTokenTrendPoint? {
        guard !projected.entries.isEmpty else { return nil }

        let totals = projected.entries.reduce(
            into: (input: 0, output: 0, cached: 0, requests: 0)
        ) { partialResult, entry in
            partialResult.input += entry.inputTokens
            partialResult.output += entry.outputTokens
            partialResult.cached += entry.cachedInputTokens
            partialResult.requests += entry.requestCount
        }

        let totalTokens = totals.input + totals.output
        guard totalTokens > 0 || totals.cached > 0 || totals.requests > 0 else {
            return nil
        }

        return .init(
            date: dayKey,
            totalTokens: totalTokens,
            inputTokens: totals.input,
            outputTokens: totals.output,
            cacheReadTokens: totals.cached,
            requestCount: totals.requests
        )
    }

    static func makePointsByDay(
        from projected: CodexSessionProjectedUsage,
        timezone: TimeZone
    ) -> [String: ProviderTokenTrendPoint] {
        guard !projected.entries.isEmpty else { return [:] }

        var dayBuckets: [String: [CodexSessionProjectedMinuteEntry]] = [:]
        for entry in projected.entries {
            let dayKey = Self.dayKey(from: entry.minuteStartAt, timezone: timezone)
            dayBuckets[dayKey, default: []].append(entry)
        }

        return dayBuckets.reduce(into: [:]) { partialResult, item in
            let projectedDay = CodexSessionProjectedUsage(
                entries: item.value,
                updatedAt: projected.updatedAt,
                sourceLabel: projected.sourceLabel
            )
            if let point = makePoint(from: projectedDay, dayKey: item.key) {
                partialResult[item.key] = point
            }
        }
    }

    static func makeTokenSnapshot(
        from projected: CodexSessionProjectedUsage,
        timezone: TimeZone,
        now: Date
    ) -> CostUsageTokenSnapshot {
        struct DayTotals {
            var input = 0
            var cached = 0
            var output = 0
            var requests = 0

            var total: Int { input + output }
        }

        var dayTotals: [String: DayTotals] = [:]
        for entry in projected.entries {
            let dayKey = Self.dayKey(from: entry.minuteStartAt, timezone: timezone)
            var totals = dayTotals[dayKey] ?? DayTotals()
            totals.input += entry.inputTokens
            totals.cached += entry.cachedInputTokens
            totals.output += entry.outputTokens
            totals.requests += entry.requestCount
            dayTotals[dayKey] = totals
        }

        let daily = dayTotals.keys.sorted().map { dayKey in
            let totals = dayTotals[dayKey] ?? DayTotals()
            return CostUsageDailyReport.Entry(
                date: dayKey,
                inputTokens: totals.input,
                outputTokens: totals.output,
                cacheReadTokens: totals.cached,
                totalTokens: totals.total,
                requestCount: totals.requests,
                costUSD: nil,
                modelsUsed: nil,
                modelBreakdowns: nil
            )
        }

        let todayKey = Self.dayKey(from: now, timezone: timezone)
        let today = dayTotals[todayKey]
        let aggregate = dayTotals.values.reduce(into: DayTotals()) { partialResult, item in
            partialResult.input += item.input
            partialResult.cached += item.cached
            partialResult.output += item.output
            partialResult.requests += item.requests
        }

        return CostUsageTokenSnapshot(
            sessionTokens: today?.total,
            sessionRequests: today?.requests,
            sessionCostUSD: nil,
            todayInputTokens: today?.input,
            todayOutputTokens: today?.output,
            todayCachedInputTokens: today?.cached,
            todayRequests: today?.requests,
            rangeDays: nil,
            rangeTokens: daily.isEmpty ? nil : aggregate.total,
            rangeRequests: daily.isEmpty ? nil : aggregate.requests,
            rangeCostUSD: nil,
            rangeInputTokens: daily.isEmpty ? nil : aggregate.input,
            rangeOutputTokens: daily.isEmpty ? nil : aggregate.output,
            rangeCachedInputTokens: daily.isEmpty ? nil : aggregate.cached,
            daily: daily,
            updatedAt: projected.updatedAt,
            source: .scopedSessions
        )
    }

    static func dayKey(from date: Date, timezone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar(timezone: timezone)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timezone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func dayRange(for date: Date, timezone: TimeZone) -> (start: Date, end: Date)? {
        let calendar = calendar(timezone: timezone)
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let start = calendar.date(from: components),
              let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            return nil
        }
        return (start, end)
    }

    static func dayRange(forDayKey dayKey: String, timezone: TimeZone) -> (start: Date, end: Date)? {
        let formatter = DateFormatter()
        formatter.calendar = calendar(timezone: timezone)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timezone
        formatter.dateFormat = "yyyy-MM-dd"
        guard let start = formatter.date(from: dayKey) else {
            return nil
        }
        guard let end = calendar(timezone: timezone).date(byAdding: .day, value: 1, to: start) else {
            return nil
        }
        return (start, end)
    }

    static func calendar(timezone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        return calendar
    }

    static func resolveCodexHomeURL(environment: [String: String]) -> URL {
        if let override = environment["CODEX_HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !override.isEmpty
        {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        return URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            .appendingPathComponent(".codex", isDirectory: true)
    }
}
