import Foundation
import CodexBarProviderCatalog
import ProvidersShared

public enum CostUsageError: LocalizedError, Sendable {
    case unsupportedProvider(UsageProvider)
    case timedOut(seconds: Int)

    public var errorDescription: String? {
        switch self {
        case let .unsupportedProvider(provider):
            return "Cost summary is not supported for \(provider.rawValue)."
        case let .timedOut(seconds):
            if seconds >= 60, seconds % 60 == 0 {
                return "Cost refresh timed out after \(seconds / 60)m."
            }
            return "Cost refresh timed out after \(seconds)s."
        }
    }
}

public struct CostUsageFetcher: Sendable {
    public init() {}

    public func loadTokenSnapshot(
        provider: UsageProvider,
        now: Date = Date(),
        trailingDays: Int? = 30,
        forceRefresh: Bool = false) async throws -> CostUsageTokenSnapshot
    {
        guard provider == .codex else {
            throw CostUsageError.unsupportedProvider(provider)
        }

        let until = now
        let since: Date = {
            if let trailingDays, trailingDays > 0 {
                // Rolling window: N days (inclusive). Use -(N-1) for inclusive boundaries.
                return Calendar.current.date(byAdding: .day, value: -(trailingDays - 1), to: now) ?? now
            }
            // Nil means no explicit window limit.
            return Date(timeIntervalSince1970: 0)
        }()

        var options = CostUsageScanner.Options()
        if forceRefresh {
            options.refreshMinIntervalSeconds = 0
            options.forceRescan = true
        }
        let daily = CostUsageScanner.loadDailyReport(
            provider: provider,
            since: since,
            until: until,
            now: now,
            options: options)

        return Self.tokenSnapshot(from: daily, now: now, rangeDays: trailingDays)
    }

    static func tokenSnapshot(
        from daily: CostUsageDailyReport,
        now: Date,
        rangeDays: Int? = nil
    ) -> CostUsageTokenSnapshot {
        // Session fields should represent "today" only.
        let currentDay = daily.data
            .filter { entry in
                guard let date = CostUsageDateParser.parse(entry.date) else { return false }
                return Calendar.current.isDate(date, inSameDayAs: now)
            }
            .max { lhs, rhs in
            let lCost = lhs.costUSD ?? -1
            let rCost = rhs.costUSD ?? -1
            if lCost != rCost { return lCost < rCost }
            let lTokens = lhs.totalTokens ?? -1
            let rTokens = rhs.totalTokens ?? -1
            if lTokens != rTokens { return lTokens < rTokens }
            return lhs.date < rhs.date
            }
        // Prefer summary totals when present; fall back to summing daily entries.
        let totalFromSummary = daily.summary?.totalCostUSD
        let totalFromEntries = daily.data.compactMap(\.costUSD).reduce(0, +)
        let rangeCostUSD = totalFromSummary ?? (totalFromEntries > 0 ? totalFromEntries : nil)
        let totalTokensFromSummary = daily.summary?.totalTokens
        let totalTokensFromEntries = daily.data.compactMap(\.totalTokens).reduce(0, +)
        let rangeTokens = totalTokensFromSummary ?? (totalTokensFromEntries > 0 ? totalTokensFromEntries : nil)

        return CostUsageTokenSnapshot(
            sessionTokens: currentDay?.totalTokens,
            sessionCostUSD: currentDay?.costUSD,
            todayInputTokens: currentDay?.inputTokens,
            todayOutputTokens: currentDay?.outputTokens,
            todayCachedInputTokens: currentDay?.cacheReadTokens,
            rangeDays: rangeDays,
            rangeTokens: rangeTokens,
            rangeCostUSD: rangeCostUSD,
            rangeInputTokens: daily.summary?.totalInputTokens,
            rangeOutputTokens: daily.summary?.totalOutputTokens,
            rangeCachedInputTokens: daily.summary?.cacheReadTokens,
            daily: daily.data,
            updatedAt: now)
    }

    static func selectCurrentSession(from sessions: [CostUsageSessionReport.Entry])
        -> CostUsageSessionReport.Entry?
    {
        if sessions.isEmpty { return nil }
        return sessions.max { lhs, rhs in
            let lDate = CostUsageDateParser.parse(lhs.lastActivity) ?? .distantPast
            let rDate = CostUsageDateParser.parse(rhs.lastActivity) ?? .distantPast
            if lDate != rDate { return lDate < rDate }
            let lCost = lhs.costUSD ?? -1
            let rCost = rhs.costUSD ?? -1
            if lCost != rCost { return lCost < rCost }
            let lTokens = lhs.totalTokens ?? -1
            let rTokens = rhs.totalTokens ?? -1
            if lTokens != rTokens { return lTokens < rTokens }
            return lhs.session < rhs.session
        }
    }

    static func selectMostRecentMonth(from months: [CostUsageMonthlyReport.Entry])
        -> CostUsageMonthlyReport.Entry?
    {
        if months.isEmpty { return nil }
        return months.max { lhs, rhs in
            let lDate = CostUsageDateParser.parseMonth(lhs.month) ?? .distantPast
            let rDate = CostUsageDateParser.parseMonth(rhs.month) ?? .distantPast
            if lDate != rDate { return lDate < rDate }
            let lCost = lhs.costUSD ?? -1
            let rCost = rhs.costUSD ?? -1
            if lCost != rCost { return lCost < rCost }
            let lTokens = lhs.totalTokens ?? -1
            let rTokens = rhs.totalTokens ?? -1
            if lTokens != rTokens { return lTokens < rTokens }
            return lhs.month < rhs.month
        }
    }
}
