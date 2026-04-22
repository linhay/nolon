import NolonUIFoundation
import SwiftUI

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

    static func summaryGridColumns(metricCount: Int) -> [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: 0), spacing: summaryCardSpacing),
            count: max(metricCount, 1)
        )
    }
}

extension ProviderTokenTrendSectionView {
    enum SortKey {
        case date, total, input, output, cache
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
        return ChartLayout(
            slotWidth: slotWidth,
            barWidth: barWidth,
            edgePadding: 4
        )
    }

    func linePlotPoints(
        for points: [ProviderTokenTrendPointData],
        maxValue: Int,
        slotWidth: CGFloat,
        plotHeight: CGFloat
    ) -> [LinePlotPoint] {
        points.enumerated().map { index, point in
            let x = (CGFloat(index) * slotWidth) + (slotWidth / 2)
            let ratio = maxValue > 0 ? CGFloat(point.totalTokens) / CGFloat(maxValue) : 0
            let clampedRatio = min(max(ratio, 0), 1)
            let y = max(10, plotHeight - (clampedRatio * max(plotHeight - 12, 1)))
            return LinePlotPoint(point: point, x: x, y: y)
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
