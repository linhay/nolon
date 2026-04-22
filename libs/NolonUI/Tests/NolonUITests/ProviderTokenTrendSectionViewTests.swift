import AppKit
import SwiftUI
import XCTest
@testable import NolonUI
import NolonUIFoundation

@MainActor
final class ProviderTokenTrendSectionViewTests: XCTestCase {
    func testProviderTokenTrendSectionView_GivenDailyAndIntradayData_RendersWithDualCards() {
        let view = ProviderTokenTrendSectionView(
            data: .init(
                snapshot: .init(
                    points: [
                        .init(date: "2026-04-14", inputTokens: 120, outputTokens: 40, cacheReadTokens: 20, totalTokens: 180),
                        .init(date: "2026-04-15", inputTokens: 90, outputTokens: 30, cacheReadTokens: 10, totalTokens: 130),
                    ],
                    todayTokens: 130,
                    last7DaysTokens: 310,
                    last30DaysTokens: 1_280,
                    allDaysTokens: 8_420,
                    updatedAt: Date(timeIntervalSince1970: 1_744_700_800),
                    sourceLabel: "fixture"
                ),
                refreshStatus: .init(
                    title: "正在回填派生用量",
                    detail: "已刷新 live 2 个、archived 1 个，跳过 116 个。",
                    progressLabel: "3 / 12",
                    fractionCompleted: 0.25
                ),
                drilldown: .init(
                    dayKey: "2026-04-15",
                    bucketID: "30m",
                    actualBucketCount: 2,
                    fullBucketCount: 48,
                    rangeDescription: "30min",
                    usageSummaryText: "总量 210 · 输入 140 · 输出 50 · 缓存 20",
                    bucketSummary: "2/48 可见时间桶",
                    presentationNote: "仅展示有用量时段；Today 不显示未来时间。",
                    points: [
                        .init(label: "09:30", rangeLabel: "09:30-10:00", totalTokens: 120, inputTokens: 80, outputTokens: 30, cacheReadTokens: 10),
                        .init(label: "10:30", rangeLabel: "10:30-11:00", totalTokens: 90, inputTokens: 60, outputTokens: 20, cacheReadTokens: 10),
                    ],
                    availableBuckets: [
                        .init(id: "15m", title: "15min"),
                        .init(id: "30m", title: "30min"),
                        .init(id: "60m", title: "60min"),
                    ],
                    isLoading: false,
                    errorMessage: nil,
                    freshnessText: "静态快照 · 12:00"
                ),
                supportsIntradayDrilldown: true,
                chartStyle: .line,
                activeTab: .intraday,
                selectedDayKey: "2026-04-15",
                isLoading: false,
                errorMessage: nil,
                selectedRangeID: "days30",
                availableRanges: [
                    .init(id: "days7", title: "7D"),
                    .init(id: "days30", title: "30D"),
                    .init(id: "all", title: "ALL"),
                ]
            ),
            onRangeChange: { _ in },
            onSelectDay: { _ in },
            onIntradayBucketChange: { _ in },
            onChartStyleChange: { _ in },
            onContentTabChange: { _ in },
            onRefresh: {},
            onRefreshIntraday: {}
        )

        let host = NSHostingView(
            rootView: view
                .frame(width: 960, height: 900, alignment: .topLeading)
        )
        host.frame = NSRect(x: 0, y: 0, width: 960, height: 900)
        host.layoutSubtreeIfNeeded()

        XCTAssertGreaterThan(host.fittingSize.height, 0)
    }

    func testProviderTokenTrendSectionView_GivenNarrowWidthAndRefreshProgress_RendersWithoutLayoutFailure() {
        let view = ProviderTokenTrendSectionView(
            data: .init(
                snapshot: .init(
                    points: [
                        .init(date: "2026-04-20", inputTokens: 120, outputTokens: 40, cacheReadTokens: 20, totalTokens: 180),
                        .init(date: "2026-04-21", inputTokens: 90, outputTokens: 30, cacheReadTokens: 10, totalTokens: 130),
                        .init(date: "2026-04-22", inputTokens: 110, outputTokens: 20, cacheReadTokens: 15, totalTokens: 145),
                    ],
                    todayTokens: 145,
                    last7DaysTokens: 455,
                    last30DaysTokens: 1_980,
                    allDaysTokens: 12_420,
                    updatedAt: Date(timeIntervalSince1970: 1_744_700_800),
                    sourceLabel: "fixture"
                ),
                refreshStatus: .init(
                    title: "正在分析会话文件",
                    detail: "正在解析 2026/04/22/rollout-123.jsonl，原因：发现新 rollout。",
                    progressLabel: "12 / 128",
                    fractionCompleted: 0.09375
                ),
                drilldown: nil,
                supportsIntradayDrilldown: true,
                chartStyle: .bar,
                activeTab: .daily,
                selectedDayKey: nil,
                isLoading: false,
                errorMessage: nil,
                selectedRangeID: "days7",
                availableRanges: [
                    .init(id: "days1", title: "Today"),
                    .init(id: "days7", title: "7 Days"),
                    .init(id: "days30", title: "30 Days"),
                    .init(id: "all", title: "ALL"),
                ]
            ),
            onRangeChange: { _ in },
            onSelectDay: { _ in },
            onIntradayBucketChange: { _ in },
            onChartStyleChange: { _ in },
            onContentTabChange: { _ in },
            onRefresh: {},
            onRefreshIntraday: {}
        )

        let host = NSHostingView(
            rootView: view
                .frame(width: 560, height: 520, alignment: .topLeading)
        )
        host.frame = NSRect(x: 0, y: 0, width: 560, height: 520)
        host.layoutSubtreeIfNeeded()

        XCTAssertGreaterThan(host.fittingSize.height, 0)
    }
}
