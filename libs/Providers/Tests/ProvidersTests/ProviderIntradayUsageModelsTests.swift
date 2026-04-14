import Foundation
import Providers
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
}
