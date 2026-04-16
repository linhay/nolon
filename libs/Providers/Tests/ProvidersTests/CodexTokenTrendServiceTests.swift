import Foundation
import Testing
@testable import ProviderUsage
@testable import CodexProvider

@Suite("Codex Token Trend Service")
struct CodexTokenTrendServiceTests {
    @Test("maps daily token entries and computes rolling summaries")
    func mapsDailyEntriesAndSummaries() async throws {
        let now = Self.makeLocalDate(year: 2026, month: 2, day: 26, hour: 12, minute: 0)
        let snapshot = CostUsageTokenSnapshot(
            sessionTokens: 120,
            sessionCostUSD: nil,
            todayInputTokens: 60,
            todayOutputTokens: 40,
            todayCachedInputTokens: 20,
            rangeDays: 30,
            rangeTokens: 1_000,
            rangeCostUSD: nil,
            rangeInputTokens: 500,
            rangeOutputTokens: 350,
            rangeCachedInputTokens: 150,
            daily: [
                CostUsageDailyReport.Entry(
                    date: "2026-02-24",
                    inputTokens: 100,
                    outputTokens: 80,
                    cacheReadTokens: 20,
                    totalTokens: 180,
                    costUSD: nil,
                    modelsUsed: nil,
                    modelBreakdowns: nil
                ),
                CostUsageDailyReport.Entry(
                    date: "2026-02-25",
                    inputTokens: 120,
                    outputTokens: 90,
                    cacheReadTokens: 30,
                    totalTokens: 210,
                    costUSD: nil,
                    modelsUsed: nil,
                    modelBreakdowns: nil
                ),
                CostUsageDailyReport.Entry(
                    date: "2026-02-26",
                    inputTokens: 60,
                    outputTokens: 40,
                    cacheReadTokens: 20,
                    totalTokens: 120,
                    costUSD: nil,
                    modelsUsed: nil,
                    modelBreakdowns: nil
                ),
            ],
            updatedAt: now,
            source: .scopedSessions
        )

        let service = CodexTokenTrendService { _, _, _, _ in snapshot }
        let result = try await service.fetchGlobalSnapshot(trailingDays: 30, environment: ["CODEX_HOME": "/tmp/account-home"])

        #expect(result.points.count == 3)
        #expect(result.points[0].date == "2026-02-24")
        #expect(result.points[0].totalTokens == 180)
        #expect(result.points[0].inputTokens == 100)
        #expect(result.points[0].outputTokens == 80)
        #expect(result.points[0].cacheReadTokens == 20)
        #expect(result.todayTokens == 120)
        #expect(result.last7DaysTokens == 510)
        #expect(result.last30DaysTokens == 510)
        #expect(result.allDaysTokens == 510)
        #expect(result.sourceLabel == "global local usage")
    }

    @Test("keeps summary metrics stable while slicing chart range")
    func keepsSummaryMetricsStableWhileSlicingChartRange() async throws {
        let now = Self.makeLocalDate(year: 2026, month: 2, day: 28, hour: 12, minute: 0)
        let entries = (1...40).map { index in
            CostUsageDailyReport.Entry(
                date: String(format: "2026-02-%02d", min(index, 28)),
                inputTokens: index,
                outputTokens: index,
                cacheReadTokens: 0,
                totalTokens: index * 10,
                costUSD: nil,
                modelsUsed: nil,
                modelBreakdowns: nil
            )
        }
        let snapshot = CostUsageTokenSnapshot(
            sessionTokens: 400,
            sessionCostUSD: nil,
            todayInputTokens: nil,
            todayOutputTokens: nil,
            todayCachedInputTokens: nil,
            rangeDays: nil,
            rangeTokens: nil,
            rangeCostUSD: nil,
            rangeInputTokens: nil,
            rangeOutputTokens: nil,
            rangeCachedInputTokens: nil,
            daily: entries,
            updatedAt: now,
            source: .globalFallback
        )

        let recorder = TrailingDaysRecorder()
        let service = CodexTokenTrendService { _, trailingDays, _, _ in
            await recorder.record(trailingDays)
            return snapshot
        }

        let result = try await service.fetchGlobalSnapshot(trailingDays: 7, environment: [:])

        #expect(await recorder.values() == [nil])
        #expect(result.points.count == 7)
        #expect(result.todayTokens == 400)
        #expect(result.last7DaysTokens == (34...40).map { $0 * 10 }.reduce(0, +))
        #expect(result.last30DaysTokens == (11...40).map { $0 * 10 }.reduce(0, +))
        #expect(result.allDaysTokens == (1...40).map { $0 * 10 }.reduce(0, +))
    }

    @Test("returns empty snapshot when scanner has no daily entries")
    func returnsEmptySnapshotWhenNoDailyEntries() async throws {
        let now = Self.makeLocalDate(year: 2026, month: 2, day: 26, hour: 12, minute: 0)
        let snapshot = CostUsageTokenSnapshot(
            sessionTokens: nil,
            sessionCostUSD: nil,
            todayInputTokens: nil,
            todayOutputTokens: nil,
            todayCachedInputTokens: nil,
            rangeDays: nil,
            rangeTokens: nil,
            rangeCostUSD: nil,
            rangeInputTokens: nil,
            rangeOutputTokens: nil,
            rangeCachedInputTokens: nil,
            daily: [],
            updatedAt: now,
            source: .globalFallback
        )

        let service = CodexTokenTrendService { _, _, _, _ in snapshot }
        let result = try await service.fetchGlobalSnapshot(trailingDays: nil, environment: [:])

        #expect(result.points.isEmpty)
        #expect(result.todayTokens == 0)
        #expect(result.last7DaysTokens == nil)
        #expect(result.last30DaysTokens == nil)
        #expect(result.allDaysTokens == nil)
    }

    @Test("returns zero for today when latest history point is before current date")
    func returnsZeroForTodayWhenLatestHistoryPointIsBeforeCurrentDate() async throws {
        let now = Self.makeLocalDate(year: 2026, month: 3, day: 1, hour: 9, minute: 0)
        let snapshot = CostUsageTokenSnapshot(
            sessionTokens: nil,
            sessionCostUSD: nil,
            todayInputTokens: nil,
            todayOutputTokens: nil,
            todayCachedInputTokens: nil,
            rangeDays: 30,
            rangeTokens: 390,
            rangeCostUSD: nil,
            rangeInputTokens: nil,
            rangeOutputTokens: nil,
            rangeCachedInputTokens: nil,
            daily: [
                CostUsageDailyReport.Entry(
                    date: "2026-02-27",
                    inputTokens: 80,
                    outputTokens: 20,
                    cacheReadTokens: 0,
                    totalTokens: 100,
                    costUSD: nil,
                    modelsUsed: nil,
                    modelBreakdowns: nil
                ),
                CostUsageDailyReport.Entry(
                    date: "2026-02-28",
                    inputTokens: 200,
                    outputTokens: 90,
                    cacheReadTokens: 0,
                    totalTokens: 290,
                    costUSD: nil,
                    modelsUsed: nil,
                    modelBreakdowns: nil
                ),
            ],
            updatedAt: now,
            source: .scopedSessions
        )

        let service = CodexTokenTrendService { _, _, _, _ in snapshot }
        let result = try await service.fetchGlobalSnapshot(trailingDays: 30, environment: [:])

        #expect(result.todayTokens == 0)
        #expect(result.last7DaysTokens == 390)
        #expect(result.last30DaysTokens == 390)
        #expect(result.allDaysTokens == 390)
    }
}

private actor TrailingDaysRecorder {
    private var storage: [Int?] = []

    func record(_ value: Int?) {
        storage.append(value)
    }

    func values() -> [Int?] {
        storage
    }
}

private extension CodexTokenTrendServiceTests {
    static func makeLocalDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
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
