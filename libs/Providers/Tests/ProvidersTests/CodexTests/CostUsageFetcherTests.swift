import Foundation
import Testing
@testable import CodexProvider
import ProvidersShared
import STFilePath

@Suite("Cost Usage Fetcher")
struct CostUsageFetcherTests {
    @Test("TDD: Given no entry for today when building snapshot then today cost/tokens stay empty")
    func tdd_givenNoTodayEntry_whenBuildingSnapshot_thenTodayFieldsAreNil() {
        let now = Self.makeLocalDate(year: 2026, month: 2, day: 10, hour: 10, minute: 0)
        let daily = CostUsageDailyReport(
            data: [
                .init(
                    date: "2026-02-08",
                    inputTokens: 900,
                    outputTokens: 100,
                    totalTokens: 1_000,
                    costUSD: 0.12,
                    modelsUsed: ["gpt-5"],
                    modelBreakdowns: nil
                ),
                .init(
                    date: "2026-02-09",
                    inputTokens: 1800,
                    outputTokens: 200,
                    totalTokens: 2_000,
                    costUSD: 0.24,
                    modelsUsed: ["gpt-5"],
                    modelBreakdowns: nil
                ),
            ],
            summary: .init(
                totalInputTokens: 2_700,
                totalOutputTokens: 300,
                totalTokens: 3_000,
                totalCostUSD: 0.36
            )
        )

        let snapshot = CostUsageFetcher.tokenSnapshot(from: daily, now: now, rangeDays: nil)

        #expect(snapshot.sessionTokens == nil)
        #expect(snapshot.sessionCostUSD == nil)
        #expect(snapshot.rangeDays == nil)
        #expect(snapshot.rangeTokens == 3_000)
        #expect(snapshot.rangeCostUSD == 0.36)
        #expect(snapshot.rangeInputTokens == 2_700)
        #expect(snapshot.rangeOutputTokens == 300)
        #expect(snapshot.rangeCachedInputTokens == nil)
    }

    @Test("BDD: Given today and yesterday entries when building snapshot then today values are used")
    func bdd_givenTodayAndYesterdayEntries_whenBuildingSnapshot_thenUsesTodayEntryOnly() {
        let now = Self.makeLocalDate(year: 2026, month: 2, day: 10, hour: 22, minute: 30)
        let daily = CostUsageDailyReport(
            data: [
                .init(
                    date: "2026-02-09",
                    inputTokens: 2100,
                    outputTokens: 100,
                    totalTokens: 2_200,
                    costUSD: 9.9,
                    modelsUsed: ["gpt-5.2-codex"],
                    modelBreakdowns: nil
                ),
                .init(
                    date: "2026-02-10",
                    inputTokens: 1900,
                    outputTokens: 100,
                    totalTokens: 2_000,
                    costUSD: 0.4,
                    modelsUsed: ["gpt-5"],
                    modelBreakdowns: nil
                ),
            ],
            summary: nil
        )

        let snapshot = CostUsageFetcher.tokenSnapshot(from: daily, now: now, rangeDays: 7)

        #expect(snapshot.sessionTokens == 2_000)
        #expect(snapshot.sessionCostUSD == 0.4)
        #expect(snapshot.rangeDays == 7)
        #expect(snapshot.rangeTokens == 4_200)
        #expect(snapshot.rangeCostUSD == 10.3)
        #expect(snapshot.todayInputTokens == 1_900)
        #expect(snapshot.todayOutputTokens == 100)
    }

    @Test("BDD: Given cached/input/output totals when building snapshot then returns all token dimensions")
    func bdd_givenCacheInputOutputTotals_whenBuildingSnapshot_thenReturnsTokenBreakdowns() {
        let now = Self.makeLocalDate(year: 2026, month: 2, day: 10, hour: 8, minute: 0)
        let daily = CostUsageDailyReport(
            data: [
                .init(
                    date: "2026-02-10",
                    inputTokens: 1000,
                    outputTokens: 200,
                    cacheReadTokens: 300,
                    totalTokens: 1200,
                    costUSD: 1.2,
                    modelsUsed: ["gpt-5"],
                    modelBreakdowns: nil
                )
            ],
            summary: .init(
                totalInputTokens: 1000,
                totalOutputTokens: 200,
                cacheReadTokens: 300,
                totalTokens: 1200,
                totalCostUSD: 1.2
            )
        )

        let snapshot = CostUsageFetcher.tokenSnapshot(from: daily, now: now, rangeDays: nil)

        #expect(snapshot.todayInputTokens == 1_000)
        #expect(snapshot.todayOutputTokens == 200)
        #expect(snapshot.todayCachedInputTokens == 300)
        #expect(snapshot.rangeInputTokens == 1_000)
        #expect(snapshot.rangeOutputTokens == 200)
        #expect(snapshot.rangeCachedInputTokens == 300)
    }

    private static func makeLocalDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var comps = DateComponents()
        comps.calendar = Calendar.current
        comps.timeZone = TimeZone.current
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        return comps.date ?? Date(timeIntervalSince1970: 0)
    }

    @Test("BDD: Given CODEX_HOME override when resolving cost usage home then use override folder")
    func bdd_givenCodexHomeOverride_whenResolvingHome_thenUseOverride() {
        let env = ["CODEX_HOME": "/tmp/codex-home-a"]
        let folder = CostUsageFetcher.codexHomeFolder(environment: env)
        #expect(folder.url.standardizedFileURL.path == STFolder("/tmp/codex-home-a").url.standardizedFileURL.path)
    }

    @Test("BDD: Given no CODEX_HOME when resolving cost usage home then fallback to ~/.codex")
    func bdd_givenNoCodexHome_whenResolvingHome_thenFallbackToDefault() {
        let folder = CostUsageFetcher.codexHomeFolder(environment: [:])
        let expected = STFolder(NSHomeDirectory()).folder(".codex")
        #expect(folder.url.standardizedFileURL.path == expected.url.standardizedFileURL.path)
    }

    @Test("TDD: Given empty daily report when checking usability then returns false")
    func tdd_givenEmptyReport_whenCheckingUsableCostData_thenFalse() {
        let report = CostUsageDailyReport(data: [], summary: nil)
        #expect(CostUsageFetcher.hasUsableCostData(report) == false)
    }

    @Test("BDD: Given summary total tokens when checking usability then returns true")
    func bdd_givenSummaryTokens_whenCheckingUsableCostData_thenTrue() {
        let report = CostUsageDailyReport(
            data: [],
            summary: .init(totalInputTokens: nil, totalOutputTokens: nil, totalTokens: 42, totalCostUSD: nil)
        )
        #expect(CostUsageFetcher.hasUsableCostData(report) == true)
    }

    @Test("TDD: Given 30 day cache already built when loading all-time snapshot then older history is still preserved")
    func tdd_given30DayCacheAlreadyBuilt_whenLoadingAllTimeSnapshot_thenOlderHistoryIsStillPreserved() async throws {
        let root = STFolder("/tmp").folder("cost-usage-fetcher-all-history-\(UUID().uuidString)")
        _ = root.createIfNotExists()
        defer { try? root.delete() }

        let codexHome = root.folder("codex-home")
        _ = codexHome.createIfNotExists()

        try Self.writeSessionUsageFile(
            codexHome: codexHome,
            dayPath: "2026/02/10",
            filename: "old.jsonl",
            sessionID: "session-old",
            timestamp: "2026-02-10T10:00:02Z",
            inputTokens: 100,
            cachedInputTokens: 0,
            outputTokens: 20,
            totalTokens: 120
        )
        try Self.writeSessionUsageFile(
            codexHome: codexHome,
            dayPath: "2026/04/10",
            filename: "recent.jsonl",
            sessionID: "session-recent",
            timestamp: "2026-04-10T10:00:02Z",
            inputTokens: 200,
            cachedInputTokens: 10,
            outputTokens: 30,
            totalTokens: 230
        )

        let now = Self.makeLocalDate(year: 2026, month: 4, day: 15, hour: 12, minute: 0)
        let environment = ["CODEX_HOME": codexHome.url.path]
        let fetcher = CostUsageFetcher()

        let last30Days = try await fetcher.loadTokenSnapshot(
            provider: .codex,
            now: now,
            trailingDays: 30,
            environment: environment
        )
        #expect(last30Days.rangeTokens == 230)
        #expect(last30Days.daily.map(\.date) == ["2026-04-10"])

        let allTime = try await fetcher.loadTokenSnapshot(
            provider: .codex,
            now: now,
            trailingDays: nil,
            environment: environment
        )
        #expect(allTime.rangeTokens == 350)
        #expect(allTime.daily.map(\.date) == ["2026-02-10", "2026-04-10"])
    }

    private static func writeSessionUsageFile(
        codexHome: STFolder,
        dayPath: String,
        filename: String,
        sessionID: String,
        timestamp: String,
        inputTokens: Int,
        cachedInputTokens: Int,
        outputTokens: Int,
        totalTokens: Int
    ) throws {
        let parts = dayPath.split(separator: "/").map(String.init)
        var folder = codexHome.folder("sessions")
        for part in parts {
            folder = folder.folder(part)
        }
        _ = folder.createIfNotExists()

        let file = folder.file(filename)
        try file.overlay(with: """
        {"timestamp":"\(timestamp)","type":"session_meta","payload":{"id":"\(sessionID)"}}
        {"timestamp":"\(timestamp)","type":"turn_context","payload":{"model":"gpt-5"}}
        {"timestamp":"\(timestamp)","type":"event_msg","payload":{"type":"token_count","info":{"model":"gpt-5","last_token_usage":{"input_tokens":\(inputTokens),"cached_input_tokens":\(cachedInputTokens),"output_tokens":\(outputTokens),"total_tokens":\(totalTokens)}}}}
        """)
    }
}
