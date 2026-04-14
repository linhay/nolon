import Foundation
import CodexBarProviderCatalog
import STFilePath

public struct CodexQuarterHourUsageDay: Sendable, Equatable {
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

public struct CodexQuarterHourUsageFetcher: Sendable {
    public init() {}

    public func loadQuarterHourDay(
        provider: UsageProvider,
        dayKey: String,
        forceRefresh: Bool = false,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) async throws -> CodexQuarterHourUsageDay? {
        guard provider == .codex else {
            throw CostUsageError.unsupportedProvider(provider)
        }

        guard let range = Self.makeDayRange(dayKey: dayKey) else {
            return nil
        }

        var options = CostUsageScanner.Options()
        let codexHome = CostUsageFetcher.codexHomeFolder(environment: environment)
        options.codexSessionsRoot = codexHome.folder("sessions")
        options.cacheRoot = codexHome.folder("cache")
        if forceRefresh {
            options.refreshMinIntervalSeconds = 0
            options.forceRescan = true
        }

        let now = Date()
        _ = CostUsageScanner.loadDailyReport(
            provider: .codex,
            since: range.start,
            until: range.end,
            now: now,
            options: options
        )

        let cache = CostUsageCacheIO.load(provider: .codex, cacheRoot: options.cacheRoot)
        let updatedAt = Date(timeIntervalSince1970: TimeInterval(cache.lastScanUnixMs) / 1000)
        let quarterHours = cache.quarterHours[dayKey] ?? [:]

        return CodexQuarterHourUsageDay(
            dayKey: dayKey,
            quarterHours: quarterHours,
            updatedAt: updatedAt,
            sourceLabel: "global"
        )
    }

    private static func makeDayRange(dayKey: String) -> (start: Date, end: Date)? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        guard let start = formatter.date(from: dayKey) else { return nil }
        guard let end = formatter.calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
        return (start, end)
    }
}
