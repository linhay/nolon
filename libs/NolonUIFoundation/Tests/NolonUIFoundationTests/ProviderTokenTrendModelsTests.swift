import XCTest
@testable import NolonUIFoundation

final class ProviderTokenTrendModelsTests: XCTestCase {
    func testTokenTrendSnapshotDisplayDateRange_UsesTrailingWindowForKnownRanges() {
        let snapshot = ProviderTokenTrendSnapshotData(
            points: [
                .init(date: "2026-04-13", inputTokens: 0, outputTokens: 0, cacheReadTokens: 0, totalTokens: 0),
                .init(date: "2026-04-14", inputTokens: 0, outputTokens: 0, cacheReadTokens: 0, totalTokens: 0),
                .init(date: "2026-04-15", inputTokens: 0, outputTokens: 0, cacheReadTokens: 0, totalTokens: 0),
                .init(date: "2026-04-16", inputTokens: 0, outputTokens: 0, cacheReadTokens: 0, totalTokens: 0),
                .init(date: "2026-04-17", inputTokens: 0, outputTokens: 0, cacheReadTokens: 0, totalTokens: 0),
                .init(date: "2026-04-18", inputTokens: 0, outputTokens: 0, cacheReadTokens: 0, totalTokens: 0),
                .init(date: "2026-04-19", inputTokens: 0, outputTokens: 0, cacheReadTokens: 0, totalTokens: 0),
                .init(date: "2026-04-20", inputTokens: 0, outputTokens: 0, cacheReadTokens: 0, totalTokens: 0),
                .init(date: "2026-04-21", inputTokens: 0, outputTokens: 0, cacheReadTokens: 0, totalTokens: 0),
                .init(date: "2026-04-22", inputTokens: 0, outputTokens: 0, cacheReadTokens: 0, totalTokens: 0),
            ],
            todayTokens: 0,
            last7DaysTokens: 0,
            last30DaysTokens: 0,
            allDaysTokens: 0,
            updatedAt: .distantPast,
            sourceLabel: "fixture"
        )

        XCTAssertEqual(snapshot.displayDateRange(for: "days1"), "04-22")
        XCTAssertEqual(snapshot.displayDateRange(for: "days7"), "04-16 - 04-22")
        XCTAssertEqual(snapshot.displayDateRange(for: "days30"), "04-13 - 04-22")
        XCTAssertEqual(snapshot.displayDateRange(for: "all"), "04-13 - 04-22")
    }

    func testTokenTrendSnapshotDisplayDateRange_GivenCrossYearRange_KeepsFullDates() {
        let snapshot = ProviderTokenTrendSnapshotData(
            points: [
                .init(date: "2025-12-31", inputTokens: 0, outputTokens: 0, cacheReadTokens: 0, totalTokens: 0),
                .init(date: "2026-01-01", inputTokens: 0, outputTokens: 0, cacheReadTokens: 0, totalTokens: 0),
                .init(date: "2026-01-02", inputTokens: 0, outputTokens: 0, cacheReadTokens: 0, totalTokens: 0),
            ],
            todayTokens: 0,
            last7DaysTokens: 0,
            last30DaysTokens: 0,
            allDaysTokens: 0,
            updatedAt: .distantPast,
            sourceLabel: "fixture"
        )

        XCTAssertEqual(snapshot.displayDateRange(for: "all"), "2025-12-31 - 2026-01-02")
    }

    func testIntradayUsagePointData_RetainsRangeLabel() {
        let point = ProviderIntradayUsagePointData(
            label: "09:30",
            rangeLabel: "09:30-10:00",
            totalTokens: 120,
            inputTokens: 80,
            outputTokens: 30,
            cacheReadTokens: 10,
            requestCount: 3
        )

        XCTAssertEqual(point.label, "09:30")
        XCTAssertEqual(point.rangeLabel, "09:30-10:00")
        XCTAssertEqual(point.requestCount, 3)
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

    func testTokenTrendPresentationEnums_ExposeStableRawValues() {
        XCTAssertEqual(ProviderTokenTrendChartStyle.bar.rawValue, "bar")
        XCTAssertEqual(ProviderTokenTrendChartStyle.line.rawValue, "line")
        XCTAssertEqual(ProviderTokenTrendContentTab.daily.rawValue, "daily")
        XCTAssertEqual(ProviderTokenTrendContentTab.intraday.rawValue, "intraday")
        XCTAssertEqual(ProviderTokenTrendMetricMode.tokens.rawValue, "tokens")
        XCTAssertEqual(ProviderTokenTrendMetricMode.requests.rawValue, "requests")
    }

    func testTokenTrendSectionData_RetainsPresentationState() {
        let data = ProviderTokenTrendSectionData(
            snapshot: nil,
            refreshStatus: nil,
            drilldown: nil,
            supportsIntradayDrilldown: true,
            metricMode: .requests,
            chartStyle: .line,
            activeTab: .intraday,
            selectedDayKey: "2026-04-22",
            isLoading: false,
            errorMessage: nil,
            selectedRangeID: "days7",
            availableRanges: [.init(id: "days7", title: "7 Days")]
        )

        XCTAssertTrue(data.supportsIntradayDrilldown)
        XCTAssertEqual(data.metricMode, .requests)
        XCTAssertEqual(data.chartStyle, .line)
        XCTAssertEqual(data.activeTab, .intraday)
        XCTAssertEqual(data.selectedDayKey, "2026-04-22")
    }
}
