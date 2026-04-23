import XCTest
@testable import NolonUI
import NolonUIFoundation

final class ProviderTokenTrendIntradayChartSupportTests: XCTestCase {
    func testLinePlotPoints_GivenIntradayUsagePoints_WhenResolvingPlot_ThenIncludesCompactValueLabels() {
        let points = [
            ProviderIntradayUsagePointData(
                label: "09:30",
                rangeLabel: "09:30-10:00",
                totalTokens: 1_530,
                inputTokens: 1_000,
                outputTokens: 400,
                cacheReadTokens: 130
            ),
            ProviderIntradayUsagePointData(
                label: "10:00",
                rangeLabel: "10:00-10:30",
                totalTokens: 980,
                inputTokens: 720,
                outputTokens: 180,
                cacheReadTokens: 80
            ),
        ]

        let plotPoints = ProviderTokenTrendIntradayChartSupport.linePlotPoints(
            for: points,
            maxValue: 1_530,
            slotWidth: 28,
            plotHeight: 108
        )

        XCTAssertEqual(plotPoints.map(\.valueLabel), ["1.5K", "980"])
        XCTAssertEqual(plotPoints.map(\.x), [14, 42])
        XCTAssertTrue(plotPoints.allSatisfy { $0.y >= 18 && $0.y <= 108 })
    }
}
