import Foundation
import Testing
@testable import ProviderUsage
@testable import CodexProvider

@Suite("Codex Token Trend Service")
struct CodexTokenTrendServiceTests {
    @Test("maps daily token entries and computes rolling summaries")
    func mapsDailyEntriesAndSummaries() async throws {
        let now = Date(timeIntervalSince1970: 1_746_000_000)
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
        #expect(result.sourceLabel == "global")
    }

    @Test("returns empty snapshot when scanner has no daily entries")
    func returnsEmptySnapshotWhenNoDailyEntries() async throws {
        let now = Date(timeIntervalSince1970: 1_746_000_000)
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
        #expect(result.todayTokens == nil)
        #expect(result.last7DaysTokens == nil)
        #expect(result.last30DaysTokens == nil)
    }
}
