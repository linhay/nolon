import SwiftUI
import NolonUIFoundation

public struct ProviderTokenTrendSectionView: View {
    private let data: ProviderTokenTrendSectionData
    private let onRangeChange: (String) -> Void
    private let onRefresh: () -> Void

    @State private var sortKey: SortKey = .date
    @State private var sortAscending = false
    @State private var selectedDate: String?

    public init(
        data: ProviderTokenTrendSectionData,
        onRangeChange: @escaping (String) -> Void,
        onRefresh: @escaping () -> Void
    ) {
        self.data = data
        self.onRangeChange = onRangeChange
        self.onRefresh = onRefresh
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if let snapshot = data.snapshot {
                summary(snapshot: snapshot)
                chartSection(snapshot: snapshot)
                tableSection(snapshot: snapshot)
            } else if let errorMessage = data.errorMessage, !errorMessage.isEmpty {
                errorState(message: errorMessage)
            } else if data.isLoading {
                loadingState()
            } else {
                emptyState
            }
        }
        .padding(16)
        .dsCard()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text(NSLocalizedString("usage.token_trend.title", value: "历史 Token 消耗", comment: "Token trend section title"))
                    .font(.headline)

                Spacer()

                Button {
                    onRefresh()
                } label: {
                    if data.isLoading {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .medium))
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .help(NSLocalizedString("generic.refresh", value: "Refresh", comment: "Refresh button"))
            }

            HStack(alignment: .firstTextBaseline) {
                Text(NSLocalizedString("usage.token_trend.subtitle", value: "按日聚合输入、输出与缓存命中 token。", comment: "Token trend section subtitle"))
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)

                Spacer()

                if let snapshot = data.snapshot {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                        Text("\(snapshot.updatedAt.formatted(date: .abbreviated, time: .shortened)) 更新")
                        if !snapshot.sourceLabel.isEmpty {
                            Text("(\(snapshot.sourceLabel))")
                        }
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                }
            }
        }
    }

    private func summary(snapshot: ProviderTokenTrendSnapshotData) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
            ForEach(summaryMetrics(snapshot: snapshot, selectedDate: selectedDate)) { item in
                Button {
                    onRangeChange(item.targetRangeID)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(DesignSystem.Colors.Text.secondary)
                            .textCase(.uppercase)

                        Text(item.value)
                            .font(.title3.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(DesignSystem.Colors.Text.primary)

                        Text(item.detail)
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
                    .padding(12)
                    .background(summaryCardBackground(for: item))
                    .overlay(summaryCardBorder(for: item))
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func chartSection(snapshot: ProviderTokenTrendSnapshotData) -> some View {
        let title = NSLocalizedString("usage.token_trend.chart", value: "Daily Trend", comment: "Daily trend chart title")
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                chartLegend
            }
            chart(snapshot: snapshot)
        }
        .padding(12)
        .background(DesignSystem.Colors.Background.elevated.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
    }

    private var chartLegend: some View {
        HStack(spacing: 12) {
            legendItem(title: "Input", color: DesignSystem.Colors.primary)
            legendItem(title: "Output", color: DesignSystem.Colors.Status.success)
            legendItem(title: "Cache", color: DesignSystem.Colors.Status.warning)
        }
    }

    private func legendItem(title: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
        }
    }

    private func chart(snapshot: ProviderTokenTrendSnapshotData) -> some View {
        GeometryReader { proxy in
            let points = snapshot.points
            let maxValue = max(points.map(\.totalTokens).max() ?? 1, 1)
            let spacing: CGFloat = 8
            let availableWidth = proxy.size.width - (CGFloat(max(0, points.count - 1)) * spacing)
            let barWidth = max(4, min(24, availableWidth / CGFloat(max(1, points.count))))

            ScrollViewReader { scrollProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: spacing) {
                        ForEach(points, id: \.date) { point in
                            stackedBar(point: point, maxValue: maxValue, width: barWidth, maxHeight: proxy.size.height - 24)
                                .id(point.date)
                        }
                    }
                    .padding(.bottom, 4)
                }
                .onAppear {
                    if let lastDate = points.last?.date {
                        scrollProxy.scrollTo(lastDate, anchor: .trailing)
                    }
                }
            }
        }
        .frame(height: 160)
    }

    private func stackedBar(point: ProviderTokenTrendPointData, maxValue: Int, width: CGFloat, maxHeight: CGFloat) -> some View {
        let isSelected = point.date == selectedDate
        let totalRatio = CGFloat(point.totalTokens) / CGFloat(maxValue)
        let barHeight = max(4, totalRatio * maxHeight)

        return Button {
            withAnimation(.spring(response: 0.3)) {
                selectedDate = selectedDate == point.date ? nil : point.date
            }
        } label: {
            VStack(spacing: 6) {
                VStack(spacing: 0) {
                    barSegment(value: point.inputTokens, total: point.totalTokens, height: barHeight, color: DesignSystem.Colors.primary)
                    barSegment(value: point.outputTokens, total: point.totalTokens, height: barHeight, color: DesignSystem.Colors.Status.success)
                    barSegment(value: point.cacheReadTokens, total: point.totalTokens, height: barHeight, color: DesignSystem.Colors.Status.warning)
                }
                .frame(width: width, height: barHeight)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(DesignSystem.Colors.primary, lineWidth: isSelected ? 2 : 0)
                )
                .opacity(selectedDate == nil || isSelected ? 1.0 : 0.4)

                Text(shortDate(point.date))
                    .font(.system(size: 9))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? DesignSystem.Colors.Text.primary : DesignSystem.Colors.Text.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    private func barSegment(value: Int, total: Int, height: CGFloat, color: Color) -> some View {
        let ratio = total > 0 ? CGFloat(value) / CGFloat(total) : 0
        return Rectangle().fill(color).frame(height: ratio * height)
    }

    private func tableSection(snapshot: ProviderTokenTrendSnapshotData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("usage.token_trend.table", value: "Daily Breakdown", comment: "Daily breakdown table"))
                .font(.subheadline.weight(.semibold))

            VStack(spacing: 0) {
                headerRow
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(DesignSystem.Colors.Background.elevated.opacity(0.3))

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(sortedPoints(snapshot.points), id: \.date) { point in
                            dataRow(point: point)
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(DesignSystem.Colors.Background.elevated.opacity(0.5), lineWidth: 1)
            )
        }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            sortableHeader(title: "Date", key: .date, width: 90, alignment: .leading)
            Spacer()
            sortableHeader(title: "Total", key: .total, width: 80)
            sortableHeader(title: "Input", key: .input, width: 80)
            sortableHeader(title: "Output", key: .output, width: 80)
            sortableHeader(title: "Cache", key: .cache, width: 80)
        }
    }

    private func sortableHeader(title: String, key: SortKey, width: CGFloat, alignment: Alignment = .trailing) -> some View {
        Button {
            if sortKey == key {
                sortAscending.toggle()
            } else {
                sortKey = key
                sortAscending = key == .date
            }
        } label: {
            HStack(spacing: 4) {
                if alignment == .trailing && sortKey == key {
                    Image(systemName: sortAscending ? "chevron.up" : "chevron.down").font(.system(size: 8))
                }
                Text(title)
                if alignment == .leading && sortKey == key {
                    Image(systemName: sortAscending ? "chevron.up" : "chevron.down").font(.system(size: 8))
                }
            }
            .frame(width: width, alignment: alignment)
            .font(.caption2.weight(.bold))
            .foregroundStyle(sortKey == key ? DesignSystem.Colors.primary : DesignSystem.Colors.Text.secondary)
        }
        .buttonStyle(.plain)
    }

    private func dataRow(point: ProviderTokenTrendPointData) -> some View {
        let isSelected = point.date == selectedDate
        return HStack(spacing: 0) {
            Text(point.date).frame(width: 90, alignment: .leading)
            Spacer()
            cell(formatTokenCount(point.totalTokens), width: 80)
            cell(formatTokenCount(point.inputTokens), width: 80, color: DesignSystem.Colors.primary.opacity(0.8))
            cell(formatTokenCount(point.outputTokens), width: 80, color: DesignSystem.Colors.Status.success.opacity(0.8))
            cell(formatTokenCount(point.cacheReadTokens), width: 80, color: DesignSystem.Colors.Status.warning.opacity(0.8))
        }
        .font(.system(size: 11, design: .monospaced))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? DesignSystem.Colors.primary.opacity(0.08) : .clear)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedDate = selectedDate == point.date ? nil : point.date
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DesignSystem.Colors.Background.elevated.opacity(0.3))
                .frame(height: 1)
        }
    }

    private func cell(_ text: String, width: CGFloat, alignment: Alignment = .trailing, color: Color = .primary) -> some View {
        Text(text)
            .foregroundStyle(color == .primary ? DesignSystem.Colors.Text.primary : color)
            .frame(width: width, alignment: alignment)
    }

    private func loadingState() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 4).fill(DesignSystem.Colors.Background.elevated.opacity(0.35)).frame(width: 52, height: 10)
                        RoundedRectangle(cornerRadius: 6).fill(DesignSystem.Colors.Background.elevated.opacity(0.42)).frame(width: 88, height: 20)
                        RoundedRectangle(cornerRadius: 4).fill(DesignSystem.Colors.Background.elevated.opacity(0.28)).frame(width: 72, height: 8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(DesignSystem.Colors.Background.elevated.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .redacted(reason: .placeholder)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(DesignSystem.Colors.Status.error)
            Text(message)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .frame(maxWidth: 240)
            Button(NSLocalizedString("generic.refresh", value: "Retry", comment: "Retry button")) { onRefresh() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 40)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.title2)
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
            Text(NSLocalizedString("usage.token_trend.empty", value: "No token history yet.", comment: "Empty token trend state"))
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 40)
    }

    private func sortedPoints(_ points: [ProviderTokenTrendPointData]) -> [ProviderTokenTrendPointData] {
        points.sorted { lhs, rhs in
            let ordered: Bool
            switch sortKey {
            case .date: ordered = lhs.date < rhs.date
            case .total: ordered = lhs.totalTokens < rhs.totalTokens
            case .input: ordered = lhs.inputTokens < rhs.inputTokens
            case .output: ordered = lhs.outputTokens < rhs.outputTokens
            case .cache: ordered = lhs.cacheReadTokens < rhs.cacheReadTokens
            }
            return sortAscending ? ordered : !ordered
        }
    }

    private func shortDate(_ value: String) -> String {
        guard value.count >= 10 else { return value }
        return String(value.suffix(5))
    }

    private func formatTokenCount(_ value: Int?) -> String {
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
}

private extension ProviderTokenTrendSectionView {
    enum SortKey {
        case date, total, input, output, cache
    }

    struct SummaryMetric: Identifiable {
        let id = UUID()
        let title: String
        let value: String
        let detail: String
        let accentColor: Color
        let secondaryAccentColor: Color
        let targetRangeID: String
    }

    func summaryMetrics(snapshot: ProviderTokenTrendSnapshotData, selectedDate: String?) -> [SummaryMetric] {
        [
            .init(
                title: NSLocalizedString("usage.token_trend.summary.today", value: "Today", comment: "Today tokens"),
                value: formatTokenCount(snapshot.todayTokens),
                detail: selectedDate ?? NSLocalizedString("usage.token_trend.summary.latest", value: "Latest", comment: "Latest point"),
                accentColor: DesignSystem.Colors.primary,
                secondaryAccentColor: DesignSystem.Colors.primary.opacity(0.5),
                targetRangeID: "days1"
            ),
            .init(
                title: NSLocalizedString("usage.token_trend.summary.7d", value: "7 Days", comment: "7 day tokens"),
                value: formatTokenCount(snapshot.last7DaysTokens),
                detail: NSLocalizedString("usage.token_trend.summary.trailing", value: "Trailing total", comment: "Trailing total"),
                accentColor: DesignSystem.Colors.Status.success,
                secondaryAccentColor: DesignSystem.Colors.Status.success.opacity(0.5),
                targetRangeID: "days7"
            ),
            .init(
                title: NSLocalizedString("usage.token_trend.summary.30d", value: "30 Days", comment: "30 day tokens"),
                value: formatTokenCount(snapshot.last30DaysTokens),
                detail: NSLocalizedString("usage.token_trend.summary.trailing", value: "Trailing total", comment: "Trailing total"),
                accentColor: DesignSystem.Colors.Status.warning,
                secondaryAccentColor: DesignSystem.Colors.Status.warning.opacity(0.5),
                targetRangeID: "days30"
            ),
            .init(
                title: NSLocalizedString("codex.usage.range.all", value: "ALL", comment: "Codex usage trend range all"),
                value: formatTokenCount(snapshot.allDaysTokens),
                detail: NSLocalizedString("usage.token_trend.summary.trailing", value: "Trailing total", comment: "Trailing total"),
                accentColor: DesignSystem.Colors.Text.secondary,
                secondaryAccentColor: DesignSystem.Colors.Background.elevated,
                targetRangeID: "all"
            )
        ]
    }

    @ViewBuilder
    func summaryCardBackground(for item: SummaryMetric) -> some View {
        let isSelected = data.selectedRangeID == item.targetRangeID
        RoundedRectangle(cornerRadius: 12)
            .fill(
                LinearGradient(
                    colors: isSelected
                        ? [item.accentColor.opacity(0.26), item.secondaryAccentColor.opacity(0.16)]
                        : [item.accentColor.opacity(0.16), DesignSystem.Colors.Background.elevated.opacity(0.58)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    @ViewBuilder
    func summaryCardBorder(for item: SummaryMetric) -> some View {
        let isSelected = data.selectedRangeID == item.targetRangeID
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(
                isSelected ? item.accentColor.opacity(0.72) : item.accentColor.opacity(0.24),
                lineWidth: isSelected ? 1.5 : 1
            )
    }
}
