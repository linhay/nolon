import Foundation
import Testing
@testable import CodexProvider
import ProvidersShared

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
}
