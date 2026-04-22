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
            usageSummaryText: "总量 210 · 输入 140 · 输出 50 · 缓存 20",
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
        XCTAssertEqual(drilldown.usageSummaryText, "总量 210 · 输入 140 · 输出 50 · 缓存 20")
        XCTAssertEqual(drilldown.bucketSummary, "2/48 可见时间桶")
        XCTAssertEqual(drilldown.presentationNote, "仅展示有用量时段；Today 不显示未来时间。")
    }

    func testTokenTrendRefreshStatus_RetainsPresentationFields() {
        let status = ProviderTokenTrendRefreshStatusData(
            title: "正在回填派生用量",
            detail: "已刷新 live 2 个、archived 1 个，跳过 116 个。",
            progressLabel: "3 / 12",
            fractionCompleted: 0.25
        )

        XCTAssertEqual(status.title, "正在回填派生用量")
        XCTAssertEqual(status.detail, "已刷新 live 2 个、archived 1 个，跳过 116 个。")
        XCTAssertEqual(status.progressLabel, "3 / 12")
        XCTAssertEqual(status.fractionCompleted, 0.25)
        XCTAssertEqual(
            status.headlineText,
            "正在回填派生用量：已刷新 live 2 个、archived 1 个，跳过 116 个。"
        )
    }

    func testTokenTrendRefreshStatus_WithoutDetail_UsesTitleAsHeadline() {
        let status = ProviderTokenTrendRefreshStatusData(title: "正在扫描会话文件")

        XCTAssertEqual(status.headlineText, "正在扫描会话文件")
    }
}
