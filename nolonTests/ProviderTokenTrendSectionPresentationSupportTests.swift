import Foundation
import Testing
import ProviderUsage
import NolonUIFoundation
@testable import nolon

@MainActor
struct ProviderTokenTrendSectionPresentationSupportTests {
    @Test("BDD: Given intraday snapshot when building drilldown data then uses time ranges and visible bucket summary")
    func testBDD_GivenIntradaySnapshot_WhenBuildingDrilldownData_ThenUsesTimeRangesAndVisibleBucketSummary() throws {
        let timezone = try #require(TimeZone(identifier: "Asia/Shanghai"))
        let start = try #require(Self.makeDate(year: 2026, month: 4, day: 15, hour: 9, minute: 30, timezone: timezone))
        let middle = try #require(Self.makeDate(year: 2026, month: 4, day: 15, hour: 10, minute: 30, timezone: timezone))
        let end = try #require(Self.makeDate(year: 2026, month: 4, day: 16, hour: 0, minute: 0, timezone: timezone))
        let fetchedAt = try #require(Self.makeDate(year: 2026, month: 4, day: 15, hour: 12, minute: 0, timezone: timezone))

        let snapshot = ProviderIntradayUsageSnapshot(
            dayKey: "2026-04-15",
            timezoneIdentifier: timezone.identifier,
            bucket: .minute30,
            actualBucketCount: 2,
            rangeStart: start,
            rangeEnd: end,
            points: [
                .init(
                    start: start,
                    end: start.addingTimeInterval(30 * 60),
                    totalTokens: 120,
                    inputTokens: 80,
                    outputTokens: 30,
                    cacheReadTokens: 10
                ),
                .init(
                    start: middle,
                    end: middle.addingTimeInterval(30 * 60),
                    totalTokens: 90,
                    inputTokens: 60,
                    outputTokens: 20,
                    cacheReadTokens: 10
                )
            ],
            fetchedAt: fetchedAt,
            sourceLabel: "fixture"
        )

        let drilldown = ProviderTokenTrendSectionPresentationSupport.makeDrilldownData(
            dayKey: "2026-04-15",
            bucket: .minute30,
            snapshot: snapshot,
            isLoading: false,
            errorMessage: nil,
            availableBuckets: ProviderIntradayBucket.allCases.map {
                .init(id: $0.rawValue, title: $0.title)
            },
            referenceDate: fetchedAt
        )

        #expect(drilldown.rangeDescription == "30min")
        #expect(drilldown.actualBucketCount == 2)
        #expect(drilldown.fullBucketCount == 48)
        #expect(drilldown.bucketSummary == "2/48 可见时间桶")
        #expect(drilldown.presentationNote == "仅展示有用量时段；Today 不显示未来时间。")
        #expect(drilldown.points.map(\.label) == ["09:30", "10:30"])
        #expect(drilldown.points.map(\.rangeLabel) == ["09:30-10:00", "10:30-11:00"])
    }

    @Test("BDD: Given DST day when resolving expected intraday bucket count then honors timezone day length")
    func testBDD_GivenDSTDay_WhenResolvingExpectedIntradayBucketCount_ThenHonorsTimezoneDayLength() throws {
        let timezone = try #require(TimeZone(identifier: "America/Los_Angeles"))

        let bucketCount = ProviderTokenTrendSectionPresentationSupport.expectedBucketCount(
            dayKey: "2026-03-08",
            bucket: .minute30,
            timezone: timezone
        )

        #expect(bucketCount == 46)
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
