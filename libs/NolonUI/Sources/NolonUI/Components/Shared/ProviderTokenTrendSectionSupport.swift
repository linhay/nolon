import NolonUIFoundation
import SwiftUI

public enum ProviderTokenTrendSectionLayoutMode: Sendable, Equatable {
    case flowing
    case standaloneUsageTab
}

enum ProviderTokenTrendLayoutMetrics {
    static let summaryCardSpacing: CGFloat = 10
    static let summaryCardMinHeight: CGFloat = 88
    static let refreshStatusMinHeight: CGFloat = 82
    static let refreshProgressLabelWidth: CGFloat = 88
    static let chartHeight: CGFloat = 170
    static let intradayChartHeight: CGFloat = 158
    static let chartMinimumSlotWidth: CGFloat = 28
    static let chartMaximumSlotWidth: CGFloat = 54
    static let chartBarHorizontalInset: CGFloat = 8
    static let tableNumericColumnWidth: CGFloat = 72

    static func summaryGridColumns(metricCount: Int) -> [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: 0), spacing: summaryCardSpacing),
            count: max(metricCount, 1)
        )
    }
}

enum ProviderTokenTrendChartSupport {
    static func resolvedLayout(
        pointCount: Int,
        containerWidth: CGFloat
    ) -> ProviderTokenTrendSectionView.ChartLayout {
        let resolvedPointCount = max(pointCount, 1)
        let slotWidth = min(
            ProviderTokenTrendLayoutMetrics.chartMaximumSlotWidth,
            max(
                ProviderTokenTrendLayoutMetrics.chartMinimumSlotWidth,
                containerWidth / CGFloat(resolvedPointCount)
            )
        )
        let barWidth = max(
            12,
            slotWidth - ProviderTokenTrendLayoutMetrics.chartBarHorizontalInset
        )
        return ProviderTokenTrendSectionView.ChartLayout(
            slotWidth: slotWidth,
            barWidth: barWidth,
            edgePadding: 4
        )
    }

    static func compactTokenCount(_ value: Int?) -> String {
        guard let value else { return "-" }
        let absValue = abs(value)
        switch absValue {
        case 1_000_000_000...:
            return String(format: "%.1fB", Double(value) / 1_000_000_000)
        case 1_000_000...:
            return String(format: "%.1fM", Double(value) / 1_000_000)
        case 1_000...:
            return String(format: "%.1fK", Double(value) / 1_000)
        default:
            return "\(value)"
        }
    }

    static func resolvedValue(
        for point: ProviderTokenTrendPointData,
        metricMode: ProviderTokenTrendMetricMode
    ) -> Int {
        switch metricMode {
        case .tokens:
            return point.totalTokens
        case .requests:
            return point.requestCount
        }
    }

    static func resolvedValue(
        for point: ProviderIntradayUsagePointData,
        metricMode: ProviderTokenTrendMetricMode
    ) -> Int {
        switch metricMode {
        case .tokens:
            return point.totalTokens
        case .requests:
            return point.requestCount
        }
    }

    static func lineLegendTitle(metricMode: ProviderTokenTrendMetricMode) -> String {
        switch metricMode {
        case .tokens:
            return "Total"
        case .requests:
            return "Requests"
        }
    }
}

struct ProviderTokenTrendIntradayLinePlotPoint: Identifiable {
    let point: ProviderIntradayUsagePointData
    let x: CGFloat
    let y: CGFloat
    let valueLabel: String

    var id: String { point.rangeLabel }
}

enum ProviderTokenTrendIntradayChartSupport {
    static func linePlotPoints(
        for points: [ProviderIntradayUsagePointData],
        maxValue: Int,
        slotWidth: CGFloat,
        plotHeight: CGFloat,
        metricMode: ProviderTokenTrendMetricMode = .tokens
    ) -> [ProviderTokenTrendIntradayLinePlotPoint] {
        points.enumerated().map { index, point in
            let x = (CGFloat(index) * slotWidth) + (slotWidth / 2)
            let value = ProviderTokenTrendChartSupport.resolvedValue(
                for: point,
                metricMode: metricMode
            )
            let ratio = maxValue > 0 ? CGFloat(value) / CGFloat(maxValue) : 0
            let clampedRatio = min(max(ratio, 0), 1)
            let y = max(18, plotHeight - (clampedRatio * max(plotHeight - 22, 1)))
            return ProviderTokenTrendIntradayLinePlotPoint(
                point: point,
                x: x,
                y: y,
                valueLabel: ProviderTokenTrendChartSupport.compactTokenCount(value)
            )
        }
    }
}

extension ProviderTokenTrendSectionView {
    enum SortKey {
        case date, total, input, output, cache, requests
    }

    struct ChartLayout {
        let slotWidth: CGFloat
        let barWidth: CGFloat
        let edgePadding: CGFloat
    }

    struct LinePlotPoint: Identifiable {
        let point: ProviderTokenTrendPointData
        let x: CGFloat
        let y: CGFloat
        let valueLabel: String

        var id: String { point.date }
    }

    struct SummaryMetric: Identifiable {
        let id = UUID()
        let title: String
        let value: String
        let periodText: String
        let accentColor: Color
        let secondaryAccentColor: Color
        let targetRangeID: String
    }

    func resolvedChartLayout(pointCount: Int, containerWidth: CGFloat) -> ChartLayout {
        ProviderTokenTrendChartSupport.resolvedLayout(
            pointCount: pointCount,
            containerWidth: containerWidth
        )
    }

    func linePlotPoints(
        for points: [ProviderTokenTrendPointData],
        maxValue: Int,
        slotWidth: CGFloat,
        plotHeight: CGFloat,
        metricMode: ProviderTokenTrendMetricMode = .tokens
    ) -> [LinePlotPoint] {
        points.enumerated().map { index, point in
            let x = (CGFloat(index) * slotWidth) + (slotWidth / 2)
            let value = ProviderTokenTrendChartSupport.resolvedValue(
                for: point,
                metricMode: metricMode
            )
            let ratio = maxValue > 0 ? CGFloat(value) / CGFloat(maxValue) : 0
            let clampedRatio = min(max(ratio, 0), 1)
            let y = max(18, plotHeight - (clampedRatio * max(plotHeight - 22, 1)))
            return LinePlotPoint(
                point: point,
                x: x,
                y: y,
                valueLabel: ProviderTokenTrendChartSupport.compactTokenCount(value)
            )
        }
    }

    func linePointMarker(_ plotPoint: LinePlotPoint, isSelected: Bool) -> some View {
        let fillColor: Color = isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.Background.elevated
        let strokeWidth: CGFloat = isSelected ? 2.5 : 1.5
        let diameter: CGFloat = isSelected ? 11 : 9

        return Circle()
            .fill(fillColor)
            .overlay(
                Circle()
                    .stroke(DesignSystem.Colors.primary, lineWidth: strokeWidth)
            )
            .frame(width: diameter, height: diameter)
            .position(x: plotPoint.x, y: plotPoint.y)
    }

    func lineValueLabel(_ plotPoint: LinePlotPoint, isSelected: Bool) -> some View {
        Text(plotPoint.valueLabel)
            .font(.system(size: 8, weight: isSelected ? .bold : .semibold))
            .monospacedDigit()
            .foregroundStyle(
                isSelected
                    ? DesignSystem.Colors.Text.primary
                    : DesignSystem.Colors.Text.secondary
            )
            .frame(width: 44)
            .position(x: plotPoint.x, y: max(8, plotPoint.y - 14))
    }

    @ViewBuilder
    func refreshStatusProgressLabel(_ progressLabel: String?) -> some View {
        Group {
            if let progressLabel, !progressLabel.isEmpty {
                Text(progressLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    .lineLimit(1)
            } else {
                Color.clear
                    .frame(height: 14)
            }
        }
        .frame(width: ProviderTokenTrendLayoutMetrics.refreshProgressLabelWidth, alignment: .trailing)
    }
}
