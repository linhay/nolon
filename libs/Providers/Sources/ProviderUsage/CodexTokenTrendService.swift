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

    private let loadSnapshot: SnapshotLoader

    public init(loadSnapshot: @escaping SnapshotLoader = { provider, trailingDays, forceRefresh, environment in
        try await CostUsageFetcher().loadTokenSnapshot(
            provider: provider,
            trailingDays: trailingDays,
            forceRefresh: forceRefresh,
            environment: environment
        )
    }) {
        self.loadSnapshot = loadSnapshot
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
        let allPoints = snapshot.daily
            .map { entry in
                let input = max(0, entry.inputTokens ?? 0)
                let output = max(0, entry.outputTokens ?? 0)
                let cache = max(0, entry.cacheReadTokens ?? 0)
                let total = max(0, entry.totalTokens ?? (input + output))
                return ProviderTokenTrendPoint(
                    date: entry.date,
                    totalTokens: total,
                    inputTokens: input,
                    outputTokens: output,
                    cacheReadTokens: cache
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
        let last7 = sumTrailing(points: allPoints, days: 7)
        let last30 = sumTrailing(points: allPoints, days: 30)
        let all = sumAll(points: allPoints)

        return ProviderTokenTrendSnapshot(
            points: points,
            todayTokens: today,
            last7DaysTokens: last7,
            last30DaysTokens: last30,
            allDaysTokens: all,
            updatedAt: snapshot.updatedAt,
            sourceLabel: "global local usage"
        )
    }

    private func sumTrailing(points: [CodexTokenTrendPoint], days: Int) -> Int? {
        guard days > 0, !points.isEmpty else { return nil }
        let values = points.suffix(days).map(\.totalTokens)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +)
    }

    private func sumAll(points: [CodexTokenTrendPoint]) -> Int? {
        guard !points.isEmpty else { return nil }
        return points.map(\.totalTokens).reduce(0, +)
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

    private static func dayKey(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
