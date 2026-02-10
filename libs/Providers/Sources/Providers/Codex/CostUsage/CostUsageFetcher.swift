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
        trailingDays: Int? = nil,
        forceRefresh: Bool = false) async throws -> CostUsageTokenSnapshot
    {
        guard provider == .codex else {
            throw CostUsageError.unsupportedProvider(provider)
        }

        let until = now
        let since: Date
        let normalizedRangeDays: Int?
        if let trailingDays {
            let days = max(1, trailingDays)
            // Inclusive window: trailingDays=1 means only today.
            since = Calendar.current.date(byAdding: .day, value: -(days - 1), to: now) ?? now
            normalizedRangeDays = days
        } else {
            // Nil means full history.
            since = Date(timeIntervalSince1970: 0)
            normalizedRangeDays = nil
        }

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

        return Self.tokenSnapshot(from: daily, now: now, rangeDays: normalizedRangeDays)
    }

    static func tokenSnapshot(from daily: CostUsageDailyReport, now: Date, rangeDays: Int? = nil) -> CostUsageTokenSnapshot {
        let calendar = Calendar.current
        let today = daily.data
            .filter { entry in
                guard let date = CostUsageDateParser.parse(entry.date) else { return false }
                return calendar.isDate(date, inSameDayAs: now)
            }
            .max(by: Self.dayEntrySort)
        // Prefer summary totals when present; fall back to summing daily entries.
        let totalCostFromSummary = daily.summary?.totalCostUSD
        let totalCostFromEntries = daily.data.compactMap(\.costUSD).reduce(0, +)
        let rangeCostUSD = totalCostFromSummary ?? (totalCostFromEntries > 0 ? totalCostFromEntries : nil)
        let totalTokensFromSummary = daily.summary?.totalTokens
        let totalTokensFromEntries = daily.data.compactMap(\.totalTokens).reduce(0, +)
        let rangeTokens = totalTokensFromSummary ?? (totalTokensFromEntries > 0 ? totalTokensFromEntries : nil)
        let totalInputFromSummary = daily.summary?.totalInputTokens
        let totalInputFromEntries = daily.data.compactMap(\.inputTokens).reduce(0, +)
        let rangeInputTokens = totalInputFromSummary ?? (totalInputFromEntries > 0 ? totalInputFromEntries : nil)
        let totalOutputFromSummary = daily.summary?.totalOutputTokens
        let totalOutputFromEntries = daily.data.compactMap(\.outputTokens).reduce(0, +)
        let rangeOutputTokens = totalOutputFromSummary ?? (totalOutputFromEntries > 0 ? totalOutputFromEntries : nil)
        let totalCachedFromSummary = daily.summary?.cacheReadTokens
        let totalCachedFromEntries = daily.data.compactMap(\.cacheReadTokens).reduce(0, +)
        let rangeCachedInputTokens = totalCachedFromSummary ?? (totalCachedFromEntries > 0 ? totalCachedFromEntries : nil)

        return CostUsageTokenSnapshot(
            sessionTokens: today?.totalTokens,
            sessionCostUSD: today?.costUSD,
            todayInputTokens: today?.inputTokens,
            todayOutputTokens: today?.outputTokens,
            todayCachedInputTokens: today?.cacheReadTokens,
            rangeDays: rangeDays,
            rangeTokens: rangeTokens,
            rangeCostUSD: rangeCostUSD,
            rangeInputTokens: rangeInputTokens,
            rangeOutputTokens: rangeOutputTokens,
            rangeCachedInputTokens: rangeCachedInputTokens,
            daily: daily.data,
            updatedAt: now)
    }

    private static func dayEntrySort(lhs: CostUsageDailyReport.Entry, rhs: CostUsageDailyReport.Entry) -> Bool {
        let lDate = CostUsageDateParser.parse(lhs.date) ?? .distantPast
        let rDate = CostUsageDateParser.parse(rhs.date) ?? .distantPast
        if lDate != rDate { return lDate < rDate }
        let lCost = lhs.costUSD ?? -1
        let rCost = rhs.costUSD ?? -1
        if lCost != rCost { return lCost < rCost }
        let lTokens = lhs.totalTokens ?? -1
        let rTokens = rhs.totalTokens ?? -1
        if lTokens != rTokens { return lTokens < rTokens }
        return lhs.date < rhs.date
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
