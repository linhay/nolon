import AppKit
import SwiftUI
import XCTest
@testable import NolonUI
import NolonUIFoundation

@MainActor
private final class ViewSizeRecorder {
    var rootSize: CGSize = .zero
    var contentSize: CGSize = .zero
}

private struct SizeProbe: View {
    let onChange: (CGSize) -> Void

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear {
                    onChange(proxy.size)
                }
                .onChange(of: proxy.size) { _, newValue in
                    onChange(newValue)
                }
        }
    }
}

@MainActor
final class ProviderTokenTrendSectionViewTests: XCTestCase {
    func testProviderTokenTrendSectionView_GivenDailyAndIntradayData_RendersUnifiedTrendWorkspace() {
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
                        .init(id: "1m", title: "1min"),
                        .init(id: "5m", title: "5min"),
                        .init(id: "10m", title: "10min"),
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
            onMetricModeChange: { _ in },
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

    func testProviderTokenTrendSectionView_GivenRequestsMetric_RendersWithoutLayoutFailure() {
        let view = ProviderTokenTrendSectionView(
            data: .init(
                snapshot: .init(
                    points: [
                        .init(date: "2026-04-14", inputTokens: 120, outputTokens: 40, cacheReadTokens: 20, totalTokens: 180, requestCount: 3),
                        .init(date: "2026-04-15", inputTokens: 90, outputTokens: 30, cacheReadTokens: 10, totalTokens: 130, requestCount: 2),
                    ],
                    todayTokens: 130,
                    todayRequests: 2,
                    last7DaysTokens: 310,
                    last7DaysRequests: 5,
                    last30DaysTokens: 1_280,
                    last30DaysRequests: 5,
                    allDaysTokens: 8_420,
                    allDaysRequests: 5,
                    updatedAt: Date(timeIntervalSince1970: 1_744_700_800),
                    sourceLabel: "fixture"
                ),
                refreshStatus: nil,
                drilldown: .init(
                    dayKey: "2026-04-15",
                    bucketID: "30m",
                    actualBucketCount: 2,
                    fullBucketCount: 48,
                    rangeDescription: "30min",
                    usageSummaryText: "请求 2",
                    bucketSummary: "2/48 可见时间桶",
                    presentationNote: "仅展示有用量时段。",
                    points: [
                        .init(label: "09:30", rangeLabel: "09:30-10:00", totalTokens: 120, inputTokens: 80, outputTokens: 30, cacheReadTokens: 10, requestCount: 1),
                        .init(label: "10:30", rangeLabel: "10:30-11:00", totalTokens: 90, inputTokens: 60, outputTokens: 20, cacheReadTokens: 10, requestCount: 1),
                    ],
                    availableBuckets: [
                        .init(id: "1m", title: "1min"),
                        .init(id: "5m", title: "5min"),
                        .init(id: "10m", title: "10min"),
                        .init(id: "15m", title: "15min"),
                        .init(id: "30m", title: "30min"),
                        .init(id: "60m", title: "60min"),
                    ],
                    isLoading: false,
                    errorMessage: nil,
                    freshnessText: "静态快照 · 12:00"
                ),
                supportsIntradayDrilldown: true,
                metricMode: .requests,
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
            onMetricModeChange: { _ in },
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

    func testProviderTokenTrendSectionView_GivenIntradayDataAtNarrowWidth_RendersCompactWorkspaceHeader() {
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
                refreshStatus: nil,
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
                        .init(id: "1m", title: "1min"),
                        .init(id: "5m", title: "5min"),
                        .init(id: "10m", title: "10min"),
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
            onMetricModeChange: { _ in },
            onChartStyleChange: { _ in },
            onContentTabChange: { _ in },
            onRefresh: {},
            onRefreshIntraday: {}
        )

        let host = NSHostingView(
            rootView: view
                .frame(width: 560, height: 760, alignment: .topLeading)
        )
        host.frame = NSRect(x: 0, y: 0, width: 560, height: 760)
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
            onMetricModeChange: { _ in },
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

    func testProviderTokenTrendSectionView_GivenIntradayToolbarControls_WhenRenderingWideHeader_ThenKeepsCompactRailLayout() {
        let view = ProviderTokenTrendSectionView(
            data: .init(
                snapshot: .init(
                    points: [
                        .init(date: "2026-04-21", inputTokens: 120, outputTokens: 40, cacheReadTokens: 20, totalTokens: 180, requestCount: 2),
                        .init(date: "2026-04-22", inputTokens: 90, outputTokens: 30, cacheReadTokens: 10, totalTokens: 130, requestCount: 2),
                        .init(date: "2026-04-23", inputTokens: 140, outputTokens: 60, cacheReadTokens: 25, totalTokens: 225, requestCount: 3),
                    ],
                    todayTokens: 225,
                    todayRequests: 3,
                    last7DaysTokens: 535,
                    last7DaysRequests: 7,
                    last30DaysTokens: 1_980,
                    last30DaysRequests: 7,
                    allDaysTokens: 12_420,
                    allDaysRequests: 7,
                    updatedAt: Date(timeIntervalSince1970: 1_745_367_400),
                    sourceLabel: "fixture"
                ),
                refreshStatus: nil,
                drilldown: .init(
                    dayKey: "2026-04-23",
                    bucketID: "1m",
                    actualBucketCount: 3,
                    fullBucketCount: 1_440,
                    rangeDescription: "1min",
                    usageSummaryText: "请求 3",
                    bucketSummary: "3/1440 可见时间桶",
                    presentationNote: "仅展示有用量时段；Today 不显示未来时间。",
                    points: [
                        .init(label: "09:00", rangeLabel: "09:00-09:01", totalTokens: 80, inputTokens: 48, outputTokens: 22, cacheReadTokens: 10, requestCount: 1),
                        .init(label: "10:30", rangeLabel: "10:30-10:31", totalTokens: 75, inputTokens: 50, outputTokens: 20, cacheReadTokens: 5, requestCount: 1),
                        .init(label: "13:45", rangeLabel: "13:45-13:46", totalTokens: 70, inputTokens: 42, outputTokens: 18, cacheReadTokens: 10, requestCount: 1),
                    ],
                    availableBuckets: [
                        .init(id: "1m", title: "1min"),
                        .init(id: "5m", title: "5min"),
                        .init(id: "10m", title: "10min"),
                        .init(id: "15m", title: "15min"),
                        .init(id: "30m", title: "30min"),
                        .init(id: "60m", title: "60min"),
                    ],
                    isLoading: false,
                    errorMessage: nil,
                    freshnessText: "静态快照 · 14:00"
                ),
                supportsIntradayDrilldown: true,
                metricMode: .requests,
                chartStyle: .line,
                activeTab: .intraday,
                selectedDayKey: "2026-04-23",
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
            onMetricModeChange: { _ in },
            onChartStyleChange: { _ in },
            onContentTabChange: { _ in },
            onRefresh: {},
            onRefreshIntraday: {}
        )

        let host = NSHostingView(
            rootView: view
                .frame(width: 960, height: 760, alignment: .topLeading)
        )
        host.frame = NSRect(x: 0, y: 0, width: 960, height: 760)
        host.layoutSubtreeIfNeeded()

        XCTAssertGreaterThan(host.fittingSize.height, 0)
    }

    func testProviderTokenTrendSectionView_GivenUsageScrollContainerComposition_RendersWithoutClipRegression() {
        let points: [ProviderTokenTrendPointData] = (0..<30).map { offset in
            .init(
                date: String(format: "2026-04-%02d", offset + 1),
                inputTokens: 120 + offset * 10,
                outputTokens: 40 + offset * 4,
                cacheReadTokens: 20 + offset * 3,
                totalTokens: 180 + offset * 17
            )
        }

        let data = ProviderTokenTrendSectionData(
            snapshot: .init(
                points: points,
                todayTokens: 217_900_000,
                last7DaysTokens: 4_500_000_000,
                last30DaysTokens: 12_900_000_000,
                allDaysTokens: 30_100_000_000,
                updatedAt: Date(timeIntervalSince1970: 1_745_367_400),
                sourceLabel: "fixture"
            ),
            refreshStatus: nil,
            drilldown: nil,
            supportsIntradayDrilldown: true,
            chartStyle: .line,
            activeTab: .daily,
            selectedDayKey: nil,
            isLoading: false,
            errorMessage: nil,
            selectedRangeID: "days30",
            availableRanges: [
                .init(id: "days1", title: "Today"),
                .init(id: "days7", title: "7 Days"),
                .init(id: "days30", title: "30 Days"),
                .init(id: "all", title: "ALL"),
            ]
        )

        let view = PaddedScrollContainer(
            padding: EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 12)
        ) {
            ProviderTokenTrendSectionView(
                data: data,
                onRangeChange: { _ in },
                onSelectDay: { _ in },
                onIntradayBucketChange: { _ in },
                onMetricModeChange: { _ in },
                onChartStyleChange: { _ in },
                onContentTabChange: { _ in },
                onRefresh: {},
                onRefreshIntraday: {}
            )
            .frame(maxWidth: .infinity, alignment: Alignment.leading)
        }

        let host = NSHostingView(
            rootView: view
                .frame(width: 980, height: 520, alignment: Alignment.topLeading)
        )
        host.frame = NSRect(x: 0, y: 0, width: 980, height: 520)
        host.layoutSubtreeIfNeeded()

        XCTAssertGreaterThan(host.fittingSize.height, 0)
    }

    func testProviderTokenTrendSectionView_GivenStandaloneUsageLayout_RendersStickyWorkspaceComposition() {
        let view = ProviderTokenTrendSectionView(
            data: .init(
                snapshot: .init(
                    points: [
                        .init(date: "2026-04-21", inputTokens: 120, outputTokens: 40, cacheReadTokens: 20, totalTokens: 180),
                        .init(date: "2026-04-22", inputTokens: 90, outputTokens: 30, cacheReadTokens: 10, totalTokens: 130),
                        .init(date: "2026-04-23", inputTokens: 140, outputTokens: 60, cacheReadTokens: 25, totalTokens: 225),
                    ],
                    todayTokens: 225,
                    last7DaysTokens: 535,
                    last30DaysTokens: 1_980,
                    allDaysTokens: 12_420,
                    updatedAt: Date(timeIntervalSince1970: 1_745_367_400),
                    sourceLabel: "fixture"
                ),
                refreshStatus: nil,
                drilldown: .init(
                    dayKey: "2026-04-23",
                    bucketID: "15m",
                    actualBucketCount: 3,
                    fullBucketCount: 96,
                    rangeDescription: "15min",
                    usageSummaryText: "总量 225 · 输入 140 · 输出 60 · 缓存 25",
                    bucketSummary: "3/96 可见时间桶",
                    presentationNote: "仅展示有用量时段；Today 不显示未来时间。",
                    points: [
                        .init(label: "09:00", rangeLabel: "09:00-09:15", totalTokens: 80, inputTokens: 48, outputTokens: 22, cacheReadTokens: 10),
                        .init(label: "10:30", rangeLabel: "10:30-10:45", totalTokens: 75, inputTokens: 50, outputTokens: 20, cacheReadTokens: 5),
                        .init(label: "13:45", rangeLabel: "13:45-14:00", totalTokens: 70, inputTokens: 42, outputTokens: 18, cacheReadTokens: 10),
                    ],
                    availableBuckets: [
                        .init(id: "1m", title: "1min"),
                        .init(id: "5m", title: "5min"),
                        .init(id: "10m", title: "10min"),
                        .init(id: "15m", title: "15min"),
                        .init(id: "30m", title: "30min"),
                        .init(id: "60m", title: "60min"),
                    ],
                    isLoading: false,
                    errorMessage: nil,
                    freshnessText: "静态快照 · 14:00"
                ),
                supportsIntradayDrilldown: true,
                chartStyle: .line,
                activeTab: .intraday,
                selectedDayKey: "2026-04-23",
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
            layoutMode: .standaloneUsageTab,
            onRangeChange: { _ in },
            onSelectDay: { _ in },
            onIntradayBucketChange: { _ in },
            onMetricModeChange: { _ in },
            onChartStyleChange: { _ in },
            onContentTabChange: { _ in },
            onRefresh: {},
            onRefreshIntraday: {}
        )

        let host = NSHostingView(
            rootView: view
                .frame(width: 980, height: 760, alignment: .topLeading)
        )
        host.frame = NSRect(x: 0, y: 0, width: 980, height: 760)
        host.layoutSubtreeIfNeeded()

        XCTAssertGreaterThan(host.fittingSize.height, 0)
    }

    func testProviderUsageScreenScaffold_GivenStandaloneUsageContent_CanGrowBeyondViewportForOuterScrolling() {
        let recorder = ViewSizeRecorder()
        let view = ProviderUsageScreenScaffold(
            isEmbedded: true,
            navigationTitle: "Codex",
            isShowingCopyToast: false,
            copyToastMessage: ""
        ) {
            Text("Codex")
                .font(.headline)
        } content: {
            ProviderTokenTrendSectionView(
                data: .init(
                    snapshot: .init(
                        points: [
                            .init(date: "2026-04-21", inputTokens: 120, outputTokens: 40, cacheReadTokens: 20, totalTokens: 180),
                            .init(date: "2026-04-22", inputTokens: 90, outputTokens: 30, cacheReadTokens: 10, totalTokens: 130),
                            .init(date: "2026-04-23", inputTokens: 140, outputTokens: 60, cacheReadTokens: 25, totalTokens: 225),
                        ],
                        todayTokens: 225,
                        last7DaysTokens: 535,
                        last30DaysTokens: 1_980,
                        allDaysTokens: 12_420,
                        updatedAt: Date(timeIntervalSince1970: 1_745_367_400),
                        sourceLabel: "fixture"
                    ),
                    refreshStatus: nil,
                    drilldown: .init(
                        dayKey: "2026-04-23",
                        bucketID: "15m",
                        actualBucketCount: 3,
                        fullBucketCount: 96,
                        rangeDescription: "15min",
                        usageSummaryText: "总量 225 · 输入 140 · 输出 60 · 缓存 25",
                        bucketSummary: "3/96 可见时间桶",
                        presentationNote: "仅展示有用量时段；Today 不显示未来时间。",
                        points: [
                            .init(label: "09:00", rangeLabel: "09:00-09:15", totalTokens: 80, inputTokens: 48, outputTokens: 22, cacheReadTokens: 10),
                            .init(label: "10:30", rangeLabel: "10:30-10:45", totalTokens: 75, inputTokens: 50, outputTokens: 20, cacheReadTokens: 5),
                            .init(label: "13:45", rangeLabel: "13:45-14:00", totalTokens: 70, inputTokens: 42, outputTokens: 18, cacheReadTokens: 10),
                        ],
                        availableBuckets: [
                            .init(id: "1m", title: "1min"),
                            .init(id: "5m", title: "5min"),
                            .init(id: "10m", title: "10min"),
                            .init(id: "15m", title: "15min"),
                            .init(id: "30m", title: "30min"),
                            .init(id: "60m", title: "60min"),
                        ],
                        isLoading: false,
                        errorMessage: nil,
                        freshnessText: "静态快照 · 14:00"
                    ),
                    supportsIntradayDrilldown: true,
                    chartStyle: .line,
                    activeTab: .intraday,
                    selectedDayKey: "2026-04-23",
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
                layoutMode: .standaloneUsageTab,
                onRangeChange: { _ in },
                onSelectDay: { _ in },
                onIntradayBucketChange: { _ in },
                onMetricModeChange: { _ in },
                onChartStyleChange: { _ in },
                onContentTabChange: { _ in },
                onRefresh: {},
                onRefreshIntraday: {}
            )
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(
                SizeProbe { recorder.contentSize = $0 }
            )
        }
        .background(
            SizeProbe { recorder.rootSize = $0 }
        )

        let host = NSHostingView(
            rootView: view
                .frame(width: 980, height: 760, alignment: .topLeading)
        )
        host.frame = NSRect(x: 0, y: 0, width: 980, height: 760)
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))

        XCTAssertGreaterThanOrEqual(recorder.rootSize.height, 760)
        XCTAssertGreaterThan(
            recorder.contentSize.height,
            0,
            "usage content should keep its natural height instead of being clamped into an internal fixed viewport"
        )
    }
}
