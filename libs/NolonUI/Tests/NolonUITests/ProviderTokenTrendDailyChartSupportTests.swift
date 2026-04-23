import XCTest
@testable import NolonUI
import NolonUIFoundation

final class ProviderTokenTrendDailyChartSupportTests: XCTestCase {
    @MainActor
    func testLinePlotPoints_GivenDailyUsagePoints_WhenResolvingPlot_ThenIncludesCompactValueLabels() {
        let view = ProviderTokenTrendSectionView(
            data: .init(
                snapshot: nil,
                refreshStatus: nil,
                drilldown: nil,
                supportsIntradayDrilldown: true,
                chartStyle: .line,
                activeTab: .daily,
                selectedDayKey: nil,
                isLoading: false,
                errorMessage: nil,
                selectedRangeID: "days7",
                availableRanges: []
            ),
            onRangeChange: { _ in },
            onSelectDay: { _ in },
            onIntradayBucketChange: { _ in },
            onMetricModeChange: { _ in },
            onChartStyleChange: { _ in },
            onContentTabChange: { _ in },
            onRefresh: {},
            onRefreshIntraday: {}
        )
        let points = [
            ProviderTokenTrendPointData(
                date: "2026-04-21",
                inputTokens: 1_200,
                outputTokens: 280,
                cacheReadTokens: 120,
                totalTokens: 1_480
            ),
            ProviderTokenTrendPointData(
                date: "2026-04-22",
                inputTokens: 980,
                outputTokens: 240,
                cacheReadTokens: 60,
                totalTokens: 1_220
            ),
        ]

        let plotPoints = view.linePlotPoints(
            for: points,
            maxValue: 1_480,
            slotWidth: 28,
            plotHeight: 108
        )

        XCTAssertEqual(plotPoints.map(\.valueLabel), ["1.5K", "1.2K"])
        XCTAssertEqual(plotPoints.map(\.x), [14, 42])
        XCTAssertTrue(plotPoints.allSatisfy { $0.y >= 18 && $0.y <= 108 })
    }
}
