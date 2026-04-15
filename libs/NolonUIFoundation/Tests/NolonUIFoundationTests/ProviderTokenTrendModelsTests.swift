import XCTest
@testable import NolonUIFoundation

final class ProviderTokenTrendModelsTests: XCTestCase {
    func testIntradayUsagePointData_RetainsRangeLabel() {
        let point = ProviderIntradayUsagePointData(
            label: "09:30",
            rangeLabel: "09:30-10:00",
            totalTokens: 120,
            inputTokens: 80,
            outputTokens: 30,
            cacheReadTokens: 10
        )

        XCTAssertEqual(point.label, "09:30")
        XCTAssertEqual(point.rangeLabel, "09:30-10:00")
    }

    func testTokenTrendDrilldownData_RetainsPresentationFields() {
        let drilldown = ProviderTokenTrendDrilldownData(
            dayKey: "2026-04-15",
            bucketID: "30m",
            actualBucketCount: 2,
            fullBucketCount: 48,
            rangeDescription: "30min",
            bucketSummary: "2/48 可见时间桶",
            presentationNote: "仅展示有用量时段；Today 不显示未来时间。",
            points: [],
            availableBuckets: [],
            isLoading: false,
            errorMessage: nil,
            freshnessText: "静态快照 · 12:00"
        )

        XCTAssertEqual(drilldown.actualBucketCount, 2)
        XCTAssertEqual(drilldown.fullBucketCount, 48)
        XCTAssertEqual(drilldown.bucketSummary, "2/48 可见时间桶")
        XCTAssertEqual(drilldown.presentationNote, "仅展示有用量时段；Today 不显示未来时间。")
    }
}
