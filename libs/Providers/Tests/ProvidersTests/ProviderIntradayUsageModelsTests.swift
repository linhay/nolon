import Foundation
@testable import ProviderUsage
import Testing

@Suite("ProviderIntradayUsageModels")
struct ProviderIntradayUsageModelsTests {
    @Test("Intraday bucket titles stay aligned with product copy")
    func intradayBucket_titles() {
        #expect(ProviderIntradayBucket.minute15.title == "15min")
        #expect(ProviderIntradayBucket.minute30.title == "30min")
        #expect(ProviderIntradayBucket.hour1.title == "60min")
    }

    @Test("Intraday snapshot keeps required metadata")
    func intradaySnapshot_metadata() {
        let start = Date(timeIntervalSince1970: 1_713_086_400)
        let end = Date(timeIntervalSince1970: 1_713_088_200)
        let point = ProviderIntradayUsagePoint(
            start: start,
            end: end,
            totalTokens: 120,
            inputTokens: 70,
            outputTokens: 30,
            cacheReadTokens: 20
        )

        let snapshot = ProviderIntradayUsageSnapshot(
            dayKey: "2026-04-14",
            timezoneIdentifier: "Asia/Shanghai",
            bucket: .minute30,
            actualBucketCount: 48,
            rangeStart: start,
            rangeEnd: end,
            points: [point],
            fetchedAt: end,
            sourceLabel: "fixture"
        )

        #expect(snapshot.dayKey == "2026-04-14")
        #expect(snapshot.timezoneIdentifier == "Asia/Shanghai")
        #expect(snapshot.bucket == .minute30)
        #expect(snapshot.actualBucketCount == 48)
        #expect(snapshot.rangeStart == start)
        #expect(snapshot.rangeEnd == end)
        #expect(snapshot.points == [point])
    }

    @Test("Intraday presentation removes all zero buckets and hides future time for today")
    func intradaySnapshot_trimmedForPresentation() throws {
        let timezone = try #require(TimeZone(identifier: "Asia/Shanghai"))
        let rangeStart = try #require(Self.makeDate(year: 2026, month: 4, day: 15, hour: 9, minute: 0, timezone: timezone))
        let rangeEnd = try #require(Self.makeDate(year: 2026, month: 4, day: 15, hour: 13, minute: 0, timezone: timezone))
        let referenceDate = try #require(Self.makeDate(year: 2026, month: 4, day: 15, hour: 11, minute: 20, timezone: timezone))
        let expectedTrimmedStart = try #require(Self.makeDate(year: 2026, month: 4, day: 15, hour: 9, minute: 30, timezone: timezone))
        let expectedTrimmedEnd = try #require(Self.makeDate(year: 2026, month: 4, day: 15, hour: 11, minute: 0, timezone: timezone))

        let snapshot = ProviderIntradayUsageSnapshot(
            dayKey: "2026-04-15",
            timezoneIdentifier: timezone.identifier,
            bucket: .minute30,
            actualBucketCount: 8,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            points: [
                Self.makePoint(year: 2026, month: 4, day: 15, hour: 9, minute: 0, total: 0, timezone: timezone),
                Self.makePoint(year: 2026, month: 4, day: 15, hour: 9, minute: 30, total: 120, timezone: timezone),
                Self.makePoint(year: 2026, month: 4, day: 15, hour: 10, minute: 0, total: 0, timezone: timezone),
                Self.makePoint(year: 2026, month: 4, day: 15, hour: 10, minute: 30, total: 90, timezone: timezone),
                Self.makePoint(year: 2026, month: 4, day: 15, hour: 11, minute: 0, total: 0, timezone: timezone),
                Self.makePoint(year: 2026, month: 4, day: 15, hour: 11, minute: 30, total: 0, timezone: timezone),
                Self.makePoint(year: 2026, month: 4, day: 15, hour: 12, minute: 0, total: 999, timezone: timezone),
                Self.makePoint(year: 2026, month: 4, day: 15, hour: 12, minute: 30, total: 0, timezone: timezone),
            ],
            fetchedAt: referenceDate,
            sourceLabel: "fixture"
        )

        let trimmed = snapshot.trimmedForPresentation(referenceDate: referenceDate)

        #expect(trimmed.actualBucketCount == 2)
        #expect(trimmed.points.count == 2)
        #expect(trimmed.points.map(\.totalTokens) == [120, 90])
        #expect(trimmed.points.allSatisfy { $0.start < referenceDate })
        #expect(trimmed.rangeStart == expectedTrimmedStart)
        #expect(trimmed.rangeEnd == expectedTrimmedEnd)
    }

    private static func makePoint(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        total: Int,
        timezone: TimeZone
    ) -> ProviderIntradayUsagePoint {
        let start = makeDate(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            timezone: timezone
        )!
        let end = start.addingTimeInterval(30 * 60)
        return ProviderIntradayUsagePoint(
            start: start,
            end: end,
            totalTokens: total,
            inputTokens: total,
            outputTokens: 0,
            cacheReadTokens: 0
        )
    }

    private static func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        timezone: TimeZone
    ) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        return calendar.date(from: DateComponents(
            timeZone: timezone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))
    }
}
