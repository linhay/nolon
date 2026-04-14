import Foundation
import Testing
import CodexBarProviderCatalog
@testable import ProviderUsage

@Suite("CodexIntradayUsageService")
struct CodexIntradayUsageServiceTests {
    @Test("Aggregates quarter-hour facts into 30min drilldown buckets")
    func fetchGlobalSnapshot_aggregatesQuarterHours() async throws {
        let service = CodexIntradayUsageService(
            loadQuarterHours: { provider, dayKey, _, environment in
                #expect(provider == .codex)
                #expect(dayKey == "2026-04-14")
                #expect(environment["CODEX_HOME"] == nil)
                return CostUsageQuarterHourDay(
                    dayKey: dayKey,
                    quarterHours: [
                        "10:00": [10, 4, 3],
                        "10:15": [7, 2, 5],
                        "10:30": [9, 1, 4],
                    ],
                    updatedAt: Date(timeIntervalSince1970: 1_712_000_000),
                    sourceLabel: "global"
                )
            }
        )

        let snapshot = try #require(
            await service.fetchGlobalSnapshot(
                dayKey: "2026-04-14",
                bucket: .minute30,
                timezone: .current,
                environment: ["CODEX_HOME": "/tmp/custom-codex-home"]
            )
        )

        #expect(snapshot.bucket == .minute30)
        #expect(snapshot.points.count == 48)
        #expect(snapshot.points[20].inputTokens == 17)
        #expect(snapshot.points[20].cacheReadTokens == 6)
        #expect(snapshot.points[20].outputTokens == 8)
        #expect(snapshot.points[20].totalTokens == 25)
        #expect(snapshot.points[21].totalTokens == 13)
        #expect(snapshot.sourceLabel == "global")
    }
}
