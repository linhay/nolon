import Foundation
import Testing
import CodexBarProviderCatalog
@testable import ProviderUsage

@Suite("CodexIntradayUsageService")
struct CodexIntradayUsageServiceTests {
    @Test("Aggregates quarter-hour facts into 30min drilldown buckets")
    func fetchGlobalSnapshot_aggregatesQuarterHours() async throws {
        let timezone = try #require(TimeZone(secondsFromGMT: 0))
        let service = CodexIntradayUsageService(
            loadQuarterHours: { provider, dayKey, requestedTimezone, _, environment in
                #expect(provider == .codex)
                #expect(dayKey == "2026-04-14")
                #expect(requestedTimezone == timezone)
                #expect(environment["CODEX_HOME"] == nil)
                return CostUsageQuarterHourDay(
                    dayKey: dayKey,
                    quarterHours: [
                        "10:00": [10, 4, 3],
                        "10:15": [7, 2, 5],
                        "10:30": [9, 1, 4],
                    ],
                    updatedAt: Date(timeIntervalSince1970: 1_712_000_000),
                    sourceLabel: "global local usage"
                )
            }
        )

        let snapshot = try #require(
            await service.fetchGlobalSnapshot(
                dayKey: "2026-04-14",
                bucket: .minute30,
                timezone: timezone,
                environment: ["CODEX_HOME": "/tmp/custom-codex-home"]
            )
        )

        #expect(snapshot.bucket == .minute30)
        #expect(snapshot.actualBucketCount == 2)
        #expect(snapshot.points.count == 2)
        #expect(snapshot.points[0].inputTokens == 17)
        #expect(snapshot.points[0].cacheReadTokens == 6)
        #expect(snapshot.points[0].outputTokens == 8)
        #expect(snapshot.points[0].totalTokens == 25)
        #expect(snapshot.points[1].totalTokens == 13)
        #expect(snapshot.sourceLabel == "global local usage")
    }

    @Test("Hides future buckets when selected day is today")
    func fetchGlobalSnapshot_hidesFutureBucketsForToday() async throws {
        let timezone = try #require(TimeZone(secondsFromGMT: 0))
        let calendar = Calendar(identifier: .gregorian)
        let referenceDate = try #require(
            calendar.date(from: DateComponents(
                calendar: calendar,
                timeZone: timezone,
                year: 2026,
                month: 4,
                day: 15,
                hour: 11,
                minute: 20
            ))
        )
        let service = CodexIntradayUsageService(
            loadQuarterHours: { _, dayKey, requestedTimezone, _, _ in
                #expect(requestedTimezone == timezone)
                return CostUsageQuarterHourDay(
                    dayKey: dayKey,
                    quarterHours: [
                        "09:00": [8, 0, 4],
                        "10:00": [6, 0, 3],
                        "12:00": [99, 0, 1],
                    ],
                    updatedAt: referenceDate,
                    sourceLabel: "global local usage"
                )
            },
            now: { referenceDate }
        )

        let snapshot = try #require(
            await service.fetchGlobalSnapshot(
                dayKey: "2026-04-15",
                bucket: .minute30,
                timezone: timezone
            )
        )

        #expect(snapshot.points.count == 2)
        #expect(snapshot.points.map(\.totalTokens) == [12, 9])
        #expect(snapshot.points.allSatisfy { $0.start < referenceDate })
    }
}
