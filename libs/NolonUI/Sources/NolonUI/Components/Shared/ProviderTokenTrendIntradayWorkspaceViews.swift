import NolonUIFoundation
import SwiftUI

struct ProviderTokenTrendToggleOption<ID: Hashable>: Identifiable {
    let id: ID
    let title: String
}

struct ProviderTokenTrendToolbarField<Content: View>: View {
    let title: String?
    var width: CGFloat?
    let content: Content

    init(
        title: String? = nil,
        width: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.width = width
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .center, spacing: title == nil ? 0 : 8) {
            if let title, !title.isEmpty {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }

            Group {
                if let width {
                    content
                        .frame(width: width, alignment: .leading)
                } else {
                    content
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
        }
        .frame(height: 28, alignment: .leading)
        .fixedSize(horizontal: true, vertical: false)
    }
}

struct ProviderTokenTrendToggleControl<ID: Hashable>: View {
    let options: [ProviderTokenTrendToggleOption<ID>]
    let selection: ID
    let onSelectionChange: (ID) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options) { option in
                toggleButton(for: option)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(DesignSystem.Colors.Background.elevated.opacity(0.22))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(DesignSystem.Colors.Background.elevated.opacity(0.34), lineWidth: 1)
        )
        .frame(height: 28)
        .fixedSize(horizontal: true, vertical: false)
    }

    private func toggleButton(for option: ProviderTokenTrendToggleOption<ID>) -> some View {
        let isSelected = selection == option.id

        return Button {
            onSelectionChange(option.id)
        } label: {
            Text(option.title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(
                    isSelected
                        ? Color.white
                        : DesignSystem.Colors.Text.secondary
                )
                .padding(.horizontal, 12)
                .fixedSize(horizontal: true, vertical: false)
                .frame(height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            isSelected
                                ? DesignSystem.Colors.primary
                                : DesignSystem.Colors.Background.surface.opacity(0.72)
                        )
                )
                .shadow(
                    color: isSelected ? Color.black.opacity(0.08) : .clear,
                    radius: 1.5,
                    x: 0,
                    y: 1
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            isSelected
                                ? Color.clear
                                : DesignSystem.Colors.Background.elevated.opacity(0.16),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

struct ProviderTokenTrendMenuControl: View {
    let title: String
    let systemImage: String?
    var width: CGFloat?

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
            }

            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
        }
        .padding(.horizontal, 12)
        .frame(height: 28)
        .frame(width: width, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(DesignSystem.Colors.Background.elevated.opacity(0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(DesignSystem.Colors.Background.elevated.opacity(0.24), lineWidth: 1)
        )
        .fixedSize(horizontal: width == nil, vertical: false)
    }
}

struct ProviderTokenTrendToolbarGroup<Content: View>: View {
    let title: String?
    var icon: String?
    let content: Content

    init(
        title: String? = nil,
        icon: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            if icon != nil || title != nil {
                HStack(spacing: 5) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 10, weight: .semibold))
                    }
                    if let title, !title.isEmpty {
                        Text(title)
                            .font(.system(size: 11, weight: .semibold))
                    }
                }
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
            }

            content
        }
        .padding(.horizontal, 4)
    }
}

struct ProviderTokenTrendToolbarRail<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(DesignSystem.Colors.Background.surface.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(DesignSystem.Colors.Background.elevated.opacity(0.45), lineWidth: 1)
            )
    }
}

struct ProviderTokenTrendToolbarDivider: View {
    var body: some View {
        Rectangle()
            .fill(DesignSystem.Colors.Background.elevated.opacity(0.6))
            .frame(width: 1, height: 16)
            .padding(.horizontal, 1)
    }
}

struct ProviderTokenTrendContextTag: View {
    let icon: String
    let text: String
    var accentColor: Color = DesignSystem.Colors.Background.elevated
    var emphasizesText = false

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(accentColor)

            Text(text)
                .font(.system(size: 11, weight: emphasizesText ? .semibold : .medium, design: emphasizesText ? .monospaced : .default))
                .foregroundStyle(emphasizesText ? DesignSystem.Colors.Text.primary : DesignSystem.Colors.Text.secondary)
                .lineLimit(1)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(accentColor.opacity(0.1))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(accentColor.opacity(0.18), lineWidth: 1)
        )
    }
}

struct ProviderTokenTrendChartControlsView: View {
    let compact: Bool
    let chartStyle: ProviderTokenTrendChartStyle
    let onChartStyleChange: (ProviderTokenTrendChartStyle) -> Void

    var body: some View {
        ProviderTokenTrendToggleControl(
            options: [
                .init(id: ProviderTokenTrendChartStyle.bar, title: compact ? "Bar" : "Bars"),
                .init(id: ProviderTokenTrendChartStyle.line, title: "Line"),
            ],
            selection: chartStyle,
            onSelectionChange: onChartStyleChange
        )
    }
}

struct ProviderTokenTrendChartLegendView: View {
    let chartStyle: ProviderTokenTrendChartStyle
    let metricMode: ProviderTokenTrendMetricMode

    var body: some View {
        HStack(spacing: 12) {
            if chartStyle == .line {
                legendItem(
                    title: ProviderTokenTrendChartSupport.lineLegendTitle(metricMode: metricMode),
                    color: DesignSystem.Colors.primary
                )
            } else if metricMode == .requests {
                legendItem(title: "Requests", color: DesignSystem.Colors.primary)
            } else {
                legendItem(title: "Input", color: DesignSystem.Colors.primary)
                legendItem(title: "Output", color: DesignSystem.Colors.Status.success)
                legendItem(title: "Cache", color: DesignSystem.Colors.Status.warning)
            }
        }
    }

    private func legendItem(title: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
        }
    }
}

struct ProviderTokenTrendIntradayWorkspaceHeaderView: View {
    let data: ProviderTokenTrendSectionData
    let onIntradayBucketChange: (String) -> Void
    let onRefreshIntraday: () -> Void
    private let railContentInset: CGFloat = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            intradayTopRail
                .padding(.horizontal, railContentInset)
            ProviderTokenTrendIntradayChartPanelView(
                data: data,
                onRefreshIntraday: onRefreshIntraday
            )
        }
    }

    @ViewBuilder
    private var intradayTopRail: some View {
        intradayContextRail
    }

    @ViewBuilder
    private var intradayContextRail: some View {
        if let selectedDayKey = data.selectedDayKey {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 8) {
                    selectedDayTag(selectedDayKey)

                    if let usageSummaryText = data.drilldown?.usageSummaryText, !usageSummaryText.isEmpty {
                        ProviderTokenTrendToolbarDivider()
                        summaryTag(usageSummaryText)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    selectedDayTag(selectedDayKey)

                    if let usageSummaryText = data.drilldown?.usageSummaryText, !usageSummaryText.isEmpty {
                        summaryTag(usageSummaryText)
                    }
                }
            }
        } else {
            ProviderTokenTrendContextTag(
                icon: "cursorarrow.click.2",
                text: "先在 Daily 里选一天，再看分钟级明细。"
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func selectedDayTag(_ selectedDayKey: String) -> some View {
        ProviderTokenTrendContextTag(
            icon: "calendar",
            text: "\(selectedDayKey) · \(data.drilldown?.rangeDescription ?? "分钟级趋势")",
            accentColor: DesignSystem.Colors.primary,
            emphasizesText: true
        )
    }

    private func summaryTag(_ text: String) -> some View {
        ProviderTokenTrendContextTag(
            icon: "sum",
            text: text,
            accentColor: DesignSystem.Colors.Status.success
        )
    }
}

struct ProviderTokenTrendIntradayContentSectionView: View {
    let data: ProviderTokenTrendSectionData
    let onRefreshIntraday: () -> Void

    var body: some View {
        if let drilldown = data.drilldown {
            if let errorMessage = drilldown.errorMessage, !errorMessage.isEmpty, drilldown.points.isEmpty {
                intradayErrorState(message: errorMessage)
            } else if drilldown.isLoading, drilldown.points.isEmpty {
                intradayLoadingState
            } else if drilldown.points.isEmpty {
                intradayEmptyState
            } else {
                intradayTableSection(drilldown)
            }
        } else {
            intradaySelectionPrompt
        }
    }

    private func intradayTableSection(_ drilldown: ProviderTokenTrendDrilldownData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Intraday Breakdown")
                .font(.subheadline.weight(.semibold))

            VStack(spacing: 0) {
                intradayHeaderRow
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(DesignSystem.Colors.Background.elevated.opacity(0.3))

                VStack(spacing: 0) {
                    ForEach(Array(drilldown.points.enumerated()), id: \.offset) { _, point in
                        intradayDataRow(point: point)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(DesignSystem.Colors.Background.elevated.opacity(0.5), lineWidth: 1)
            )
        }
    }

    private var intradayHeaderRow: some View {
        HStack(spacing: 0) {
            Text("Time Range")
                .frame(width: 110, alignment: .leading)
                .font(.caption2.weight(.bold))
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
            Spacer()
            Text("Total")
                .frame(width: ProviderTokenTrendLayoutMetrics.tableNumericColumnWidth, alignment: .trailing)
                .font(.caption2.weight(.bold))
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
            Text("Requests")
                .frame(width: ProviderTokenTrendLayoutMetrics.tableNumericColumnWidth, alignment: .trailing)
                .font(.caption2.weight(.bold))
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
            Text("Input")
                .frame(width: ProviderTokenTrendLayoutMetrics.tableNumericColumnWidth, alignment: .trailing)
                .font(.caption2.weight(.bold))
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
            Text("Output")
                .frame(width: ProviderTokenTrendLayoutMetrics.tableNumericColumnWidth, alignment: .trailing)
                .font(.caption2.weight(.bold))
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
            Text("Cache")
                .frame(width: ProviderTokenTrendLayoutMetrics.tableNumericColumnWidth, alignment: .trailing)
                .font(.caption2.weight(.bold))
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
        }
    }

    private func intradayDataRow(point: ProviderIntradayUsagePointData) -> some View {
        HStack(spacing: 0) {
            Text(point.rangeLabel)
                .frame(width: 110, alignment: .leading)
            Spacer()
            cell(ProviderTokenTrendChartSupport.compactTokenCount(point.totalTokens), width: ProviderTokenTrendLayoutMetrics.tableNumericColumnWidth)
            cell(ProviderTokenTrendChartSupport.compactTokenCount(point.requestCount), width: ProviderTokenTrendLayoutMetrics.tableNumericColumnWidth, color: data.metricMode == .requests ? DesignSystem.Colors.primary : .primary)
            cell(ProviderTokenTrendChartSupport.compactTokenCount(point.inputTokens), width: ProviderTokenTrendLayoutMetrics.tableNumericColumnWidth, color: DesignSystem.Colors.primary.opacity(0.8))
            cell(ProviderTokenTrendChartSupport.compactTokenCount(point.outputTokens), width: ProviderTokenTrendLayoutMetrics.tableNumericColumnWidth, color: DesignSystem.Colors.Status.success.opacity(0.8))
            cell(ProviderTokenTrendChartSupport.compactTokenCount(point.cacheReadTokens), width: ProviderTokenTrendLayoutMetrics.tableNumericColumnWidth, color: DesignSystem.Colors.Status.warning.opacity(0.8))
        }
        .font(.system(size: 11, design: .monospaced))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DesignSystem.Colors.Background.elevated.opacity(0.3))
                .frame(height: 1)
        }
    }

    private func cell(_ text: String, width: CGFloat, color: Color = .primary) -> some View {
        Text(text)
            .foregroundStyle(color == .primary ? DesignSystem.Colors.Text.primary : color)
            .frame(width: width, alignment: .trailing)
    }

    private func intradayErrorState(message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.Status.error)
            Button(NSLocalizedString("generic.refresh", value: "Retry", comment: "Retry button")) {
                onRefreshIntraday()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var intradayLoadingState: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("正在生成分钟级钻取…")
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var intradayEmptyState: some View {
        Text("该日暂无分钟级使用数据。")
            .font(.caption)
            .foregroundStyle(DesignSystem.Colors.Text.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var intradaySelectionPrompt: some View {
        Text("先在 Daily Trend 里选择一天，这里会展示对应的分钟级明细。")
            .font(.caption)
            .foregroundStyle(DesignSystem.Colors.Text.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ProviderTokenTrendIntradayChartPanelView: View {
    let data: ProviderTokenTrendSectionData
    let onRefreshIntraday: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Group {
                if let drilldown = data.drilldown, !drilldown.points.isEmpty {
                    ProviderTokenTrendIntradayChartView(
                        points: drilldown.points,
                        chartStyle: data.chartStyle,
                        metricMode: data.metricMode
                    )
                } else if data.drilldown?.isLoading == true {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(DesignSystem.Colors.Background.elevated.opacity(0.28))
                        .frame(height: ProviderTokenTrendLayoutMetrics.intradayChartHeight)
                        .overlay(alignment: .center) {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("正在生成分钟级钻取…")
                                    .font(.caption)
                                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                            }
                        }
                } else if data.selectedDayKey == nil {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(DesignSystem.Colors.Background.elevated.opacity(0.2))
                        .frame(height: ProviderTokenTrendLayoutMetrics.intradayChartHeight)
                        .overlay(alignment: .center) {
                            Text("先在 Daily Trend 里选择一天，这里会展示对应的分钟级明细。")
                                .font(.caption)
                                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                        }
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(DesignSystem.Colors.Background.elevated.opacity(0.2))
                        .frame(height: ProviderTokenTrendLayoutMetrics.intradayChartHeight)
                        .overlay(alignment: .center) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("该日暂无分钟级使用数据。")
                                    .font(.caption)
                                    .foregroundStyle(DesignSystem.Colors.Text.secondary)

                                if let errorMessage = data.drilldown?.errorMessage, !errorMessage.isEmpty {
                                    Button(NSLocalizedString("generic.refresh", value: "Retry", comment: "Retry button")) {
                                        onRefreshIntraday()
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .help(errorMessage)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                        }
                }
            }

            if let drilldown = data.drilldown, !drilldown.points.isEmpty {
                chartFooter(drilldown)
            }
        }
    }

    private func chartFooter(_ drilldown: ProviderTokenTrendDrilldownData) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12) {
                ProviderTokenTrendChartLegendView(
                    chartStyle: data.chartStyle,
                    metricMode: data.metricMode
                )

                Spacer(minLength: 12)

                footerTextBlock(drilldown, alignment: .trailing, usesTrailingTextAlignment: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                ProviderTokenTrendChartLegendView(
                    chartStyle: data.chartStyle,
                    metricMode: data.metricMode
                )
                footerTextBlock(drilldown, alignment: .leading, usesTrailingTextAlignment: false)
            }
        }
    }

    private func footerTextBlock(
        _ drilldown: ProviderTokenTrendDrilldownData,
        alignment: HorizontalAlignment,
        usesTrailingTextAlignment: Bool
    ) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            if let bucketSummary = drilldown.bucketSummary, !bucketSummary.isEmpty {
                Text(bucketSummary)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.Text.primary)
                    .multilineTextAlignment(usesTrailingTextAlignment ? .trailing : .leading)
            }

            if let freshnessText = drilldown.freshnessText, !freshnessText.isEmpty {
                Text(freshnessText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                    .multilineTextAlignment(usesTrailingTextAlignment ? .trailing : .leading)
            }

            if let presentationNote = drilldown.presentationNote, !presentationNote.isEmpty {
                Text(presentationNote)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                    .multilineTextAlignment(usesTrailingTextAlignment ? .trailing : .leading)
            }
        }
    }
}

private struct ProviderTokenTrendIntradayChartView: View {
    let points: [ProviderIntradayUsagePointData]
    let chartStyle: ProviderTokenTrendChartStyle
    let metricMode: ProviderTokenTrendMetricMode

    var body: some View {
        switch chartStyle {
        case .bar:
            barChart
        case .line:
            lineChart
        }
    }

    private var barChart: some View {
        let maxValue = max(
            points.map {
                ProviderTokenTrendChartSupport.resolvedValue(
                    for: $0,
                    metricMode: metricMode
                )
            }.max() ?? 1,
            1
        )
        return GeometryReader { proxy in
            let layout = ProviderTokenTrendChartSupport.resolvedLayout(
                pointCount: points.count,
                containerWidth: proxy.size.width
            )
            let plotHeight = max(48, proxy.size.height - 24)

            ZStack(alignment: .bottomLeading) {
                chartGrid(height: plotHeight + 20)

                ScrollView(.horizontal) {
                    HStack(alignment: .bottom, spacing: 0) {
                        ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                            let metricValue = ProviderTokenTrendChartSupport.resolvedValue(
                                for: point,
                                metricMode: metricMode
                            )
                            let barHeight = max(6, CGFloat(metricValue) / CGFloat(maxValue) * plotHeight)
                            VStack(spacing: 6) {
                                Spacer(minLength: 0)
                                VStack(spacing: 0) {
                                    if metricMode == .requests {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(DesignSystem.Colors.primary)
                                            .frame(width: layout.barWidth, height: barHeight)
                                    } else {
                                        barSegment(value: point.inputTokens, total: point.totalTokens, height: barHeight, color: DesignSystem.Colors.primary)
                                        barSegment(value: point.outputTokens, total: point.totalTokens, height: barHeight, color: DesignSystem.Colors.Status.success)
                                        barSegment(value: point.cacheReadTokens, total: point.totalTokens, height: barHeight, color: DesignSystem.Colors.Status.warning)
                                    }
                                }
                                .frame(width: layout.barWidth, height: barHeight)
                                .background(DesignSystem.Colors.Background.elevated.opacity(0.28), in: RoundedRectangle(cornerRadius: 6))
                                .clipShape(RoundedRectangle(cornerRadius: 6))

                                Text(point.label)
                                    .font(.system(size: 9))
                                    .monospacedDigit()
                                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                            }
                            .frame(width: layout.slotWidth, height: plotHeight + 20, alignment: .bottom)
                        }
                    }
                    .padding(.horizontal, layout.edgePadding)
                    .padding(.bottom, 4)
                }
                .scrollIndicators(.hidden)
            }
        }
        .frame(height: ProviderTokenTrendLayoutMetrics.intradayChartHeight)
    }

    private var lineChart: some View {
        let maxValue = max(
            points.map {
                ProviderTokenTrendChartSupport.resolvedValue(
                    for: $0,
                    metricMode: metricMode
                )
            }.max() ?? 1,
            1
        )
        return GeometryReader { proxy in
            let layout = ProviderTokenTrendChartSupport.resolvedLayout(
                pointCount: points.count,
                containerWidth: proxy.size.width
            )
            let plotHeight = max(56, proxy.size.height - 28)
            let plotPoints = ProviderTokenTrendIntradayChartSupport.linePlotPoints(
                for: points,
                maxValue: maxValue,
                slotWidth: layout.slotWidth,
                plotHeight: plotHeight,
                metricMode: metricMode
            )
            let contentWidth = max(
                proxy.size.width - (layout.edgePadding * 2),
                CGFloat(max(points.count, 1)) * layout.slotWidth
            )

            ScrollView(.horizontal) {
                ZStack(alignment: .topLeading) {
                    chartGrid(width: contentWidth, height: plotHeight + 20)

                    Path { path in
                        guard let firstPoint = plotPoints.first,
                              let lastPoint = plotPoints.last else { return }
                        path.move(to: CGPoint(x: firstPoint.x, y: plotHeight))
                        path.addLine(to: CGPoint(x: firstPoint.x, y: firstPoint.y))
                        for point in plotPoints.dropFirst() {
                            path.addLine(to: CGPoint(x: point.x, y: point.y))
                        }
                        path.addLine(to: CGPoint(x: lastPoint.x, y: plotHeight))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignSystem.Colors.primary.opacity(0.18),
                                DesignSystem.Colors.primary.opacity(0.02),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    Path { path in
                        guard let firstPoint = plotPoints.first else { return }
                        path.move(to: CGPoint(x: firstPoint.x, y: firstPoint.y))
                        for point in plotPoints.dropFirst() {
                            path.addLine(to: CGPoint(x: point.x, y: point.y))
                        }
                    }
                    .stroke(DesignSystem.Colors.primary, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                    ForEach(plotPoints) { plotPoint in
                        lineValueLabel(plotPoint)
                        linePointMarker(plotPoint)
                    }

                    HStack(alignment: .bottom, spacing: 0) {
                        ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                            VStack(spacing: 6) {
                                Spacer(minLength: 0)
                                Text(point.label)
                                    .font(.system(size: 9))
                                    .monospacedDigit()
                                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                            }
                            .frame(width: layout.slotWidth, height: plotHeight + 20, alignment: .bottom)
                        }
                    }
                }
                .frame(width: contentWidth, height: plotHeight + 20)
                .padding(.horizontal, layout.edgePadding)
                .padding(.bottom, 4)
            }
            .scrollIndicators(.hidden)
        }
        .frame(height: ProviderTokenTrendLayoutMetrics.intradayChartHeight)
    }

    private func chartGrid(width: CGFloat? = nil, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach([1.0, 0.5, 0.0], id: \.self) { ratio in
                Rectangle()
                    .fill(DesignSystem.Colors.Background.elevated.opacity(ratio == 0 ? 0.45 : 0.24))
                    .frame(height: 1)
                if ratio > 0 {
                    Spacer()
                }
            }
        }
        .frame(width: width, height: height)
    }

    private func barSegment(value: Int, total: Int, height: CGFloat, color: Color) -> some View {
        let ratio = total > 0 ? CGFloat(value) / CGFloat(total) : 0
        return Rectangle()
            .fill(color)
            .frame(height: max(0, ratio * height))
    }

    private func linePointMarker(_ plotPoint: ProviderTokenTrendIntradayLinePlotPoint) -> some View {
        Circle()
            .fill(DesignSystem.Colors.Background.elevated)
            .overlay(
                Circle()
                    .stroke(DesignSystem.Colors.primary, lineWidth: 1.8)
            )
            .frame(width: 9, height: 9)
            .position(x: plotPoint.x, y: plotPoint.y)
    }

    private func lineValueLabel(_ plotPoint: ProviderTokenTrendIntradayLinePlotPoint) -> some View {
        Text(plotPoint.valueLabel)
            .font(.system(size: 8, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(DesignSystem.Colors.Text.secondary)
            .frame(width: 40)
            .position(x: plotPoint.x, y: max(8, plotPoint.y - 14))
    }
}
