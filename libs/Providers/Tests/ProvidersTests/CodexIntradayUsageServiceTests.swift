import Foundation
import Testing
import CodexBarProviderCatalog
import CodexProvider
@testable import ProviderUsage

@Suite("CodexIntradayUsageService")
struct CodexIntradayUsageServiceTests {
    @Test("Aggregates projected minute facts into 30min drilldown buckets")
    func fetchGlobalSnapshot_aggregatesQuarterHours() async throws {
        let timezone = try #require(TimeZone(secondsFromGMT: 0))
        let minute10_00 = try #require(Self.makeDate(dayKey: "2026-04-14", hour: 10, minute: 0, timezone: timezone))
        let minute10_15 = try #require(Self.makeDate(dayKey: "2026-04-14", hour: 10, minute: 15, timezone: timezone))
        let minute10_30 = try #require(Self.makeDate(dayKey: "2026-04-14", hour: 10, minute: 30, timezone: timezone))
        let service = CodexIntradayUsageService(
            loadProjectedUsage: { dayKey, requestedTimezone, _, environment in
                #expect(dayKey == "2026-04-14")
                #expect(requestedTimezone == timezone)
                #expect(environment["CODEX_HOME"] == nil)
                return CodexSessionProjectedUsage(
                    entries: [
                        .init(minuteStartUnixMs: Self.unixMilliseconds(minute10_00), inputTokens: 10, cachedInputTokens: 4, outputTokens: 3, requestCount: 1),
                        .init(minuteStartUnixMs: Self.unixMilliseconds(minute10_15), inputTokens: 7, cachedInputTokens: 2, outputTokens: 5, requestCount: 2),
                        .init(minuteStartUnixMs: Self.unixMilliseconds(minute10_30), inputTokens: 9, cachedInputTokens: 1, outputTokens: 4, requestCount: 1),
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
        #expect(snapshot.points.map(\.inputTokens) == [17, 9])
        #expect(snapshot.points.map(\.cacheReadTokens) == [6, 1])
        #expect(snapshot.points.map(\.outputTokens) == [8, 4])
        #expect(snapshot.points.map(\.totalTokens) == [25, 13])
        #expect(snapshot.points.map(\.requestCount) == [3, 1])
        #expect(snapshot.sourceLabel == "global local usage")
    }

    @Test("Aggregates projected minute facts into 1min drilldown buckets")
    func fetchGlobalSnapshot_aggregatesMinuteBuckets() async throws {
        let timezone = try #require(TimeZone(secondsFromGMT: 0))
        let minute10_00 = try #require(Self.makeDate(dayKey: "2026-04-14", hour: 10, minute: 0, timezone: timezone))
        let minute10_01 = try #require(Self.makeDate(dayKey: "2026-04-14", hour: 10, minute: 1, timezone: timezone))
        let minute10_02 = try #require(Self.makeDate(dayKey: "2026-04-14", hour: 10, minute: 2, timezone: timezone))
        let service = CodexIntradayUsageService(
            loadProjectedUsage: { dayKey, requestedTimezone, _, _ in
                #expect(dayKey == "2026-04-14")
                #expect(requestedTimezone == timezone)
                return CodexSessionProjectedUsage(
                    entries: [
                        .init(minuteStartUnixMs: Self.unixMilliseconds(minute10_00), inputTokens: 10, cachedInputTokens: 4, outputTokens: 3, requestCount: 1),
                        .init(minuteStartUnixMs: Self.unixMilliseconds(minute10_01), inputTokens: 7, cachedInputTokens: 2, outputTokens: 5, requestCount: 2),
                        .init(minuteStartUnixMs: Self.unixMilliseconds(minute10_02), inputTokens: 9, cachedInputTokens: 1, outputTokens: 4, requestCount: 1),
                    ],
                    updatedAt: Date(timeIntervalSince1970: 1_712_000_000),
                    sourceLabel: "global local usage"
                )
            }
        )

        let snapshot = try #require(
            await service.fetchGlobalSnapshot(
                dayKey: "2026-04-14",
                bucket: .minute1,
                timezone: timezone
            )
        )

        #expect(snapshot.bucket == .minute1)
        #expect(snapshot.actualBucketCount == 3)
        #expect(snapshot.points.count == 3)
        #expect(snapshot.points.map(\.totalTokens) == [13, 12, 13])
        #expect(snapshot.points.map(\.requestCount) == [1, 2, 1])
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
        let minute09_00 = try #require(Self.makeDate(dayKey: "2026-04-15", hour: 9, minute: 0, timezone: timezone))
        let minute10_00 = try #require(Self.makeDate(dayKey: "2026-04-15", hour: 10, minute: 0, timezone: timezone))
        let minute12_00 = try #require(Self.makeDate(dayKey: "2026-04-15", hour: 12, minute: 0, timezone: timezone))
        let service = CodexIntradayUsageService(
            loadProjectedUsage: { dayKey, requestedTimezone, _, _ in
                #expect(requestedTimezone == timezone)
                return CodexSessionProjectedUsage(
                    entries: [
                        .init(minuteStartUnixMs: Self.unixMilliseconds(minute09_00), inputTokens: 8, cachedInputTokens: 0, outputTokens: 4, requestCount: 1),
                        .init(minuteStartUnixMs: Self.unixMilliseconds(minute10_00), inputTokens: 6, cachedInputTokens: 0, outputTokens: 3, requestCount: 1),
                        .init(minuteStartUnixMs: Self.unixMilliseconds(minute12_00), inputTokens: 99, cachedInputTokens: 0, outputTokens: 1, requestCount: 1),
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

private extension CodexIntradayUsageServiceTests {
    static func makeDate(dayKey: String, hour: Int, minute: Int, timezone: TimeZone) -> Date? {
        let formatter = DateFormatter()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timezone
        formatter.dateFormat = "yyyy-MM-dd"
        guard let dayStart = formatter.date(from: dayKey) else {
            return nil
        }
        return calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: dayStart
        )
    }

    static func unixMilliseconds(_ date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1_000).rounded())
    }
}
