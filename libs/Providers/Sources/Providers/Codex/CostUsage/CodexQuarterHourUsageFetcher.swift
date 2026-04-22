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
    public typealias QuarterHourDayLoader = @Sendable (
        _ codexHome: URL,
        _ rangeStart: Date?,
        _ rangeEnd: Date?,
        _ timezone: TimeZone
    ) throws -> CodexQuarterHourUsageDay?

    private let loadQuarterHourDay: QuarterHourDayLoader
    private let loadCachedQuarterHourDay: QuarterHourDayLoader

    public init(
        loadQuarterHourDay: QuarterHourDayLoader? = nil,
        loadCachedQuarterHourDay: QuarterHourDayLoader? = nil
    ) {
        self.loadQuarterHourDay = loadQuarterHourDay ?? { codexHome, rangeStart, rangeEnd, timezone in
            let snapshot = try CodexSessionStore().loadProjectedQuarterHours(
                codexHome: codexHome,
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
                timezone: timezone
            )
            return snapshot.map {
                CodexQuarterHourUsageDay(
                    dayKey: "",
                    quarterHours: $0.buckets,
                    updatedAt: $0.updatedAt,
                    sourceLabel: $0.sourceLabel
                )
            }
        }
        self.loadCachedQuarterHourDay = loadCachedQuarterHourDay ?? { codexHome, rangeStart, rangeEnd, timezone in
            let snapshot = try CodexSessionStore().loadCachedProjectedQuarterHours(
                codexHome: codexHome,
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
                timezone: timezone
            )
            return snapshot.map {
                CodexQuarterHourUsageDay(
                    dayKey: "",
                    quarterHours: $0.buckets,
                    updatedAt: $0.updatedAt,
                    sourceLabel: $0.sourceLabel
                )
            }
        }
    }

    public func loadQuarterHourDay(
        provider: UsageProvider,
        dayKey: String,
        timezone: TimeZone = .current,
        forceRefresh: Bool = false,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) async throws -> CodexQuarterHourUsageDay? {
        guard provider == .codex else {
            throw CostUsageError.unsupportedProvider(provider)
        }

        guard let range = Self.makeDayRange(dayKey: dayKey, timezone: timezone) else {
            return nil
        }

        let codexHome = CostUsageFetcher.codexHomeFolder(environment: environment)
        let loadedDay: CodexQuarterHourUsageDay?
        if forceRefresh {
            loadedDay = try loadQuarterHourDay(codexHome.url, range.start, range.end, timezone)
        } else {
            let cachedDay = try loadCachedQuarterHourDay(codexHome.url, range.start, range.end, timezone)
            if let cachedDay {
                loadedDay = cachedDay
            } else {
                loadedDay = try loadQuarterHourDay(codexHome.url, range.start, range.end, timezone)
            }
        }
        let quarterHours = loadedDay?.quarterHours ?? [:]

        return CodexQuarterHourUsageDay(
            dayKey: dayKey,
            quarterHours: quarterHours,
            updatedAt: loadedDay?.updatedAt ?? Date(),
            sourceLabel: loadedDay?.sourceLabel ?? "global local usage"
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
