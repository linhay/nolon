import Foundation
import Testing
import CodexBarProviderCatalog
import STFilePath
@testable import CodexProvider

@Suite("Codex Quarter Hour Usage Fetcher")
struct CodexQuarterHourUsageFetcherTests {
    @Test("Uses cached projected minute usage for ordinary intraday reads and reserves full refresh for explicit force refresh")
    func loadQuarterHourDay_prefersCachedProjectionUnlessForceRefreshIsRequested() async throws {
        let timezone = try #require(TimeZone(identifier: "Asia/Shanghai"))
        let root = STFolder("/tmp").folder("codex-quarter-hour-cache-\(UUID().uuidString)")
        _ = root.createIfNotExists()
        defer { try? root.delete() }

        let codexHome = root.folder("codex-home")
        _ = codexHome.createIfNotExists()

        let rangeStart = try #require(Self.dayRange(dayKey: "2026-04-15", timezone: timezone)?.start)
        let cachedProjectionDay = CodexQuarterHourUsageDay(
            dayKey: "2026-04-15",
            quarterHours: ["00:00": [12, 3, 4]],
            updatedAt: rangeStart,
            sourceLabel: "cached projection"
        )
        let liveDay = CodexQuarterHourUsageDay(
            dayKey: "2026-04-15",
            quarterHours: ["00:00": [30, 10, 8]],
            updatedAt: rangeStart.addingTimeInterval(60),
            sourceLabel: "live projection"
        )

        final class Counter: @unchecked Sendable {
            var cachedCalls = 0
            var liveCalls = 0
        }
        let counter = Counter()
        let fetcher = CodexQuarterHourUsageFetcher(
            loadQuarterHourDay: { _, _, _, _ in
                counter.liveCalls += 1
                return liveDay
            },
            loadCachedQuarterHourDay: { _, _, _, _ in
                counter.cachedCalls += 1
                return cachedProjectionDay
            }
        )

        let cachedDayResult = try await fetcher.loadQuarterHourDay(
            provider: .codex,
            dayKey: "2026-04-15",
            timezone: timezone,
            forceRefresh: false,
            environment: ["CODEX_HOME": codexHome.path]
        )
        let requiredCachedDay = try #require(cachedDayResult)
        #expect(requiredCachedDay.sourceLabel == "cached projection")
        #expect(requiredCachedDay.quarterHours == ["00:00": [12, 3, 4]])
        #expect(counter.cachedCalls == 1)
        #expect(counter.liveCalls == 0)

        let refreshedDay = try await fetcher.loadQuarterHourDay(
            provider: .codex,
            dayKey: "2026-04-15",
            timezone: timezone,
            forceRefresh: true,
            environment: ["CODEX_HOME": codexHome.path]
        )
        let requiredRefreshedDay = try #require(refreshedDay)
        #expect(requiredRefreshedDay.sourceLabel == "live projection")
        #expect(requiredRefreshedDay.quarterHours == ["00:00": [30, 10, 8]])
        #expect(counter.cachedCalls == 1)
        #expect(counter.liveCalls == 1)
    }

    @Test("Projects UTC minute facts into the requested local day before folding quarter-hour buckets")
    func loadQuarterHourDay_projectsRequestedTimezoneBeforeBucketing() async throws {
        let timezone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let root = STFolder("/tmp").folder("codex-quarter-hour-timezone-\(UUID().uuidString)")
        _ = root.createIfNotExists()
        defer { try? root.delete() }

        let codexHome = root.folder("codex-home")
        _ = codexHome.createIfNotExists()

        let rollout = codexHome.file("sessions/timezone.jsonl")
        _ = rollout.parentFolder()?.createIfNotExists()
        try rollout.overlay(with: """
        {"timestamp":"2026-04-15T00:00:00Z","type":"session_meta","payload":{"id":"session-1"}}
        {"timestamp":"2026-04-15T00:00:01Z","type":"turn_context","payload":{"model":"gpt-5"}}
        {"timestamp":"2026-04-15T06:10:00Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":12,"cached_input_tokens":3,"output_tokens":4,"total_tokens":16}}}}
        {"timestamp":"2026-04-15T07:10:00Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":20,"cached_input_tokens":5,"output_tokens":7,"total_tokens":27}}}}
        """)

        let day = try await CodexQuarterHourUsageFetcher().loadQuarterHourDay(
            provider: .codex,
            dayKey: "2026-04-14",
            timezone: timezone,
            environment: ["CODEX_HOME": codexHome.path]
        )

        let requiredDay = try #require(day)
        #expect(requiredDay.dayKey == "2026-04-14")
        #expect(requiredDay.sourceLabel == "global local usage")
        #expect(requiredDay.quarterHours == [
            "23:00": [12, 3, 4]
        ])
    }
}

private extension CodexQuarterHourUsageFetcherTests {
    static func dayRange(dayKey: String, timezone: TimeZone) -> (start: Date, end: Date)? {
        let formatter = DateFormatter()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timezone
        formatter.dateFormat = "yyyy-MM-dd"
        guard let start = formatter.date(from: dayKey) else { return nil }
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
        return (start, end)
    }
}
