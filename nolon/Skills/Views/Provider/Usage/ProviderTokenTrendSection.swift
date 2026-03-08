import SwiftUI
import ProviderUsage

struct ProviderTokenTrendSection: View {
    let snapshot: ProviderTokenTrendSnapshot?
    let isLoading: Bool
    let errorMessage: String?
    let range: ProviderUsageViewModel.TokenTrendRange
    let onRangeChange: (ProviderUsageViewModel.TokenTrendRange) -> Void
    let onRefresh: () -> Void

    @State private var sortKey: SortKey = .date
    @State private var sortAscending = false
    @State private var selectedDate: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if let snapshot {
                summary(snapshot: snapshot)
                chartSection(snapshot: snapshot)
                tableSection(snapshot: snapshot)
            } else if let errorMessage, !errorMessage.isEmpty {
                errorState(message: errorMessage)
            } else if isLoading {
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
            // 第一行：标题 + 操作
            HStack(alignment: .center) {
                Text(NSLocalizedString("usage.token_trend.title", value: "历史 Token 消耗", comment: "Token trend section title"))
                    .font(.headline)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button {
                        onRefresh()
                    } label: {
                        if isLoading {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 13, weight: .medium))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    .help(NSLocalizedString("generic.refresh", value: "Refresh", comment: "Refresh button"))

                    Picker(
                        "",
                        selection: Binding(
                            get: { range },
                            set: { onRangeChange($0) }
                        )
                    ) {
                        ForEach(ProviderUsageViewModel.TokenTrendRange.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }
            }
            
            // 第二行：描述 + 更新时间
            HStack(alignment: .firstTextBaseline) {
                Text(NSLocalizedString("usage.token_trend.subtitle", value: "按日聚合输入、输出与缓存命中 token。", comment: "Token trend section subtitle"))
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                
                Spacer()
                
                if let snapshot = snapshot {
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

    private func summary(snapshot: ProviderTokenTrendSnapshot) -> some View {
        let items: [SummaryMetric] = [
            .init(
                title: NSLocalizedString("usage.token_trend.summary.today", value: "Today", comment: "Today tokens"),
                value: tokenText(snapshot.todayTokens),
                detail: selectedDate ?? NSLocalizedString("usage.token_trend.summary.latest", value: "Latest", comment: "Latest point"),
                color: DesignSystem.Colors.primary
            ),
            .init(
                title: NSLocalizedString("usage.token_trend.summary.7d", value: "7 Days", comment: "7 day tokens"),
                value: tokenText(snapshot.last7DaysTokens),
                detail: NSLocalizedString("usage.token_trend.summary.trailing", value: "Trailing total", comment: "Trailing total"),
                color: DesignSystem.Colors.Status.success
            ),
            .init(
                title: NSLocalizedString("usage.token_trend.summary.30d", value: "30 Days", comment: "30 day tokens"),
                value: tokenText(snapshot.last30DaysTokens),
                detail: NSLocalizedString("usage.token_trend.summary.trailing", value: "Trailing total", comment: "Trailing total"),
                color: DesignSystem.Colors.Status.warning
            )
        ]

        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
            ForEach(items) { item in
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(DesignSystem.Colors.Background.elevated.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(DesignSystem.Colors.Background.elevated, lineWidth: 1)
                )
            }
        }
    }

    private func chartSection(snapshot: ProviderTokenTrendSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(NSLocalizedString("usage.token_trend.chart", value: "Daily Trend", comment: "Daily trend chart title"))
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
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
        }
    }

    private func chart(snapshot: ProviderTokenTrendSnapshot) -> some View {
        GeometryReader { proxy in
            let points = snapshot.points
            let maxValue = max(points.map(\.totalTokens).max() ?? 1, 1)
            let barCount = points.count
            let spacing: CGFloat = 8
            let availableWidth = proxy.size.width - (CGFloat(max(0, barCount - 1)) * spacing)
            let barWidth = max(4, min(24, availableWidth / CGFloat(max(1, barCount))))
            
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

    private func stackedBar(point: ProviderTokenTrendPoint, maxValue: Int, width: CGFloat, maxHeight: CGFloat) -> some View {
        let isSelected = point.date == selectedDate
        let totalRatio = CGFloat(point.totalTokens) / CGFloat(maxValue)
        let barHeight = max(4, totalRatio * maxHeight)
        
        return Button {
            withAnimation(.spring(response: 0.3)) {
                selectedDate = isSelected ? nil : point.date
            }
        } label: {
            VStack(spacing: 6) {
                VStack(spacing: 0) {
                    // Input (Top)
                    barSegment(value: point.inputTokens, total: point.totalTokens, height: barHeight, color: DesignSystem.Colors.primary)
                    // Output (Middle)
                    barSegment(value: point.outputTokens, total: point.totalTokens, height: barHeight, color: DesignSystem.Colors.Status.success)
                    // Cache (Bottom)
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
        return Rectangle()
            .fill(color)
            .frame(height: ratio * height)
    }

    private func tableSection(snapshot: ProviderTokenTrendSnapshot) -> some View {
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
                        let rows = sortedPoints(snapshot.points)
                        ForEach(rows, id: \.date) { point in
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

    private func dataRow(point: ProviderTokenTrendPoint) -> some View {
        let isSelected = point.date == selectedDate
        return HStack(spacing: 0) {
            Text(point.date)
                .frame(width: 90, alignment: .leading)
            Spacer()
            cell(TokenCountCompactFormatter.format(point.totalTokens), width: 80)
            cell(TokenCountCompactFormatter.format(point.inputTokens), width: 80, color: DesignSystem.Colors.primary.opacity(0.8))
            cell(TokenCountCompactFormatter.format(point.outputTokens), width: 80, color: DesignSystem.Colors.Status.success.opacity(0.8))
            cell(TokenCountCompactFormatter.format(point.cacheReadTokens), width: 80, color: DesignSystem.Colors.Status.warning.opacity(0.8))
        }
        .font(.system(size: 11, design: .monospaced))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? DesignSystem.Colors.primary.opacity(0.08) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedDate = isSelected ? nil : point.date
            }
        }
        .divider(at: .bottom, color: DesignSystem.Colors.Background.elevated.opacity(0.3))
    }

    private func cell(_ text: String, width: CGFloat, alignment: Alignment = .trailing, color: Color = .primary) -> some View {
        Text(text)
            .foregroundStyle(color == .primary ? DesignSystem.Colors.Text.primary : color)
            .frame(width: width, alignment: alignment)
    }

    private func loadingState() -> some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text(NSLocalizedString("usage.token_trend.loading", value: "Loading token history…", comment: "Loading token trend"))
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 40)
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
            Button(NSLocalizedString("generic.refresh", value: "Retry", comment: "Retry button")) {
                onRefresh()
            }
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

    private func sortedPoints(_ points: [ProviderTokenTrendPoint]) -> [ProviderTokenTrendPoint] {
        points.sorted { lhs, rhs in
            let ordered: Bool = switch sortKey {
            case .date: lhs.date < rhs.date
            case .total: lhs.totalTokens < rhs.totalTokens
            case .input: lhs.inputTokens < rhs.inputTokens
            case .output: lhs.outputTokens < rhs.outputTokens
            case .cache: lhs.cacheReadTokens < rhs.cacheReadTokens
            }
            return sortAscending ? ordered : !ordered
        }
    }

    private func shortDate(_ value: String) -> String {
        guard value.count >= 10 else { return value }
        return String(value.suffix(5))
    }

    private func tokenText(_ value: Int?) -> String {
        guard let value else { return "-" }
        return TokenCountCompactFormatter.format(value)
    }
}

private extension ProviderTokenTrendSection {
    enum SortKey {
        case date, total, input, output, cache
    }

    struct SummaryMetric: Identifiable {
        let id = UUID()
        let title: String
        let value: String
        let detail: String
        let color: Color
    }
}

extension View {
    func divider(at edge: Edge, color: Color) -> some View {
        self.overlay(
            Rectangle()
                .fill(color)
                .frame(height: edge == .top || edge == .bottom ? 1 : nil)
                .frame(width: edge == .leading || edge == .trailing ? 1 : nil),
            alignment: Alignment(horizontal: edge == .leading ? .leading : (edge == .trailing ? .trailing : .center),
                                 vertical: edge == .top ? .top : (edge == .bottom ? .bottom : .center))
        )
    }
}
