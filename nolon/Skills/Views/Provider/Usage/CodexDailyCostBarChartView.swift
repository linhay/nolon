import SwiftUI
import AppKit
import ProviderUsage
#if canImport(DGCharts)
import DGCharts
#endif

enum CostChartGranularity: String, Hashable {
    case day
    case month
}

enum CostChartValueDisplayMode: String, Hashable {
    case cost
    case tokens
    case both
}

struct CostChartSelection: Equatable {
    let id: String
    let label: String
    let costUSD: Double
    let tokens: Int?
}

#if canImport(DGCharts)
struct CodexDailyCostLineChartView: NSViewRepresentable {
    let entries: [CostSnapshot.DailyCost]
    var granularity: CostChartGranularity = .day
    var valueDisplayMode: CostChartValueDisplayMode = .both
    var selectedID: String? = nil
    var onSelect: ((CostChartSelection) -> Void)? = nil

    func granularity(_ granularity: CostChartGranularity) -> Self {
        var copy = self
        copy.granularity = granularity
        return copy
    }

    func onSelect(_ handler: @escaping (CostChartSelection) -> Void) -> Self {
        var copy = self
        copy.onSelect = handler
        return copy
    }

    func selectedID(_ id: String?) -> Self {
        var copy = self
        copy.selectedID = id
        return copy
    }

    func valueDisplayMode(_ mode: CostChartValueDisplayMode) -> Self {
        var copy = self
        copy.valueDisplayMode = mode
        return copy
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> LineChartView {
        let chartView = LineChartView(frame: .zero)
        chartView.chartDescription.enabled = false
        chartView.legend.enabled = false
        chartView.doubleTapToZoomEnabled = false
        chartView.dragEnabled = true
        chartView.pinchZoomEnabled = false
        chartView.setScaleEnabled(false)
        chartView.noDataText = ""

        chartView.rightAxis.enabled = false
        chartView.leftAxis.axisMinimum = 0
        chartView.leftAxis.labelTextColor = NSColor(DesignSystem.Colors.Text.tertiary)
        chartView.leftAxis.gridColor = NSColor(DesignSystem.Colors.Component.border)

        chartView.xAxis.labelPosition = .bottom
        chartView.xAxis.drawGridLinesEnabled = false
        chartView.xAxis.granularity = 1
        chartView.xAxis.labelTextColor = NSColor(DesignSystem.Colors.Text.tertiary)
        chartView.leftAxis.axisLineColor = NSColor(DesignSystem.Colors.Component.border)
        chartView.xAxis.axisLineColor = NSColor(DesignSystem.Colors.Component.border)
        chartView.highlightPerTapEnabled = true
        chartView.delegate = context.coordinator

        return chartView
    }

    func updateNSView(_ chartView: LineChartView, context: Context) {
        let points = chartPoints(from: entries, granularity: granularity)
        context.coordinator.parent = self
        context.coordinator.points = points

        guard !points.isEmpty else {
            chartView.clear()
            return
        }

        let lineEntries: [ChartDataEntry] = points.enumerated().map { index, point in
            ChartDataEntry(x: Double(index), y: point.costUSD)
        }
        let labels: [String] = points.map(\.label)

        let dataSet = LineChartDataSet(entries: lineEntries, label: "")
        dataSet.colors = [NSColor(DesignSystem.Colors.primary)]
        dataSet.circleColors = [NSColor(DesignSystem.Colors.primary)]
        dataSet.drawCirclesEnabled = true
        dataSet.circleRadius = 2.6
        dataSet.circleHoleRadius = 1.4
        dataSet.circleHoleColor = NSColor(DesignSystem.Colors.Background.elevated)
        dataSet.lineWidth = 2.8
        dataSet.mode = .cubicBezier
        dataSet.cubicIntensity = 0.18
        dataSet.drawFilledEnabled = false
        dataSet.valueTextColor = NSColor(DesignSystem.Colors.Text.tertiary)
        dataSet.valueFont = .monospacedSystemFont(ofSize: 8, weight: .regular)
        dataSet.highlightEnabled = true
        dataSet.drawHorizontalHighlightIndicatorEnabled = false
        dataSet.highlightColor = NSColor(DesignSystem.Colors.Text.secondary)
        dataSet.highlightLineWidth = 0.8
        dataSet.valueFormatter = CostBarValueFormatter(points: points, mode: valueDisplayMode)

        let data = LineChartData(dataSet: dataSet)
        let shouldDrawValues: Bool = {
            switch valueDisplayMode {
            case .cost, .tokens:
                return points.count <= (granularity == .day ? 28 : 24)
            case .both:
                return points.count <= (granularity == .day ? 14 : 18)
            }
        }()
        data.setDrawValues(shouldDrawValues)

        chartView.xAxis.valueFormatter = IndexAxisValueFormatter(values: labels)
        chartView.xAxis.labelCount = min(labels.count, granularity == .day ? 8 : 12)
        chartView.data = data

        let visibleCount = granularity == .day ? 14.0 : 12.0
        chartView.setVisibleXRangeMaximum(visibleCount)
        if context.coordinator.lastCount != points.count || context.coordinator.lastGranularity != granularity {
            chartView.moveViewToX(max(0, Double(points.count) - visibleCount))
            context.coordinator.lastCount = points.count
            context.coordinator.lastGranularity = granularity
        }

        let selectedIndex: Int = {
            if let selectedID, let index = points.firstIndex(where: { $0.id == selectedID }) {
                return index
            }
            return min(max(context.coordinator.selectedIndex ?? (points.count - 1), 0), points.count - 1)
        }()
        context.coordinator.selectedIndex = selectedIndex
        chartView.highlightValue(x: Double(selectedIndex), dataSetIndex: 0, callDelegate: false)
        context.coordinator.emitSelection(at: selectedIndex)

        chartView.notifyDataSetChanged()
    }

    private func chartPoints(from values: [CostSnapshot.DailyCost], granularity: CostChartGranularity) -> [ChartPoint] {
        var rawPoints: [ChartPoint] = []
        rawPoints.reserveCapacity(values.count)

        for entry in values {
            guard let parsedDate = Self.parseDate(entry.date) else { continue }
            rawPoints.append(
                ChartPoint(
                    id: Self.dayID(for: parsedDate),
                    date: parsedDate,
                    costUSD: max(0.0, entry.costUSD ?? 0.0),
                    tokens: entry.tokens
                )
            )
        }

        rawPoints.sort { lhs, rhs in
            lhs.date < rhs.date
        }

        switch granularity {
        case .day:
            if rawPoints.count > 60 {
                return Array(rawPoints.suffix(60)).map { point in
                    ChartPoint(
                        id: Self.dayID(for: point.date),
                        date: point.date,
                        costUSD: point.costUSD,
                        tokens: point.tokens,
                        label: Self.axisDayFormatter.string(from: point.date)
                    )
                }
            }
            return rawPoints.map { point in
                ChartPoint(
                    id: Self.dayID(for: point.date),
                    date: point.date,
                    costUSD: point.costUSD,
                    tokens: point.tokens,
                    label: Self.axisDayFormatter.string(from: point.date)
                )
            }
        case .month:
            var monthly: [MonthKey: (cost: Double, tokens: Int?)] = [:]
            for point in rawPoints {
                let key = MonthKey(date: point.date)
                var item = monthly[key] ?? (0.0, nil)
                item.cost += point.costUSD
                if let tokens = point.tokens {
                    item.tokens = (item.tokens ?? 0) + tokens
                }
                monthly[key] = item
            }

            let sorted = monthly.keys.sorted(by: { $0.date < $1.date }).map { key in
                let value = monthly[key] ?? (0.0, nil)
                return ChartPoint(
                    id: Self.monthID(for: key.year, month: key.month),
                    date: key.date,
                    costUSD: value.cost,
                    tokens: value.tokens,
                    label: Self.axisMonthFormatter.string(from: key.date)
                )
            }
            if sorted.count > 24 {
                return Array(sorted.suffix(24))
            }
            return sorted
        }
    }

    private static func parseDate(_ value: String) -> Date? {
        if let date = isoDateFormatterWithFraction.date(from: value) {
            return date
        }
        if let date = isoDateFormatter.date(from: value) {
            return date
        }
        return simpleDateFormatter.date(from: value)
    }

    private static let isoDateFormatterWithFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let simpleDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let axisDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter
    }()

    private static let axisMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("yMMM")
        return formatter
    }()

    private static let dayIDFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func dayID(for date: Date) -> String {
        "day-\(dayIDFormatter.string(from: date))"
    }

    private static func monthID(for year: Int, month: Int) -> String {
        "month-\(year)-\(String(format: "%02d", month))"
    }

    fileprivate struct ChartPoint {
        let id: String
        let date: Date
        let costUSD: Double
        let tokens: Int?
        let label: String

        init(id: String, date: Date, costUSD: Double, tokens: Int?, label: String? = nil) {
            self.id = id
            self.date = date
            self.costUSD = costUSD
            self.tokens = tokens
            self.label = label ?? CodexDailyCostLineChartView.axisDayFormatter.string(from: date)
        }
    }

    private struct MonthKey: Hashable {
        let year: Int
        let month: Int
        let date: Date

        init(date: Date) {
            let calendar = Calendar.current
            self.year = calendar.component(.year, from: date)
            self.month = calendar.component(.month, from: date)
            self.date = calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? date
        }
    }

    private final class CostBarValueFormatter: ValueFormatter {
        private let points: [ChartPoint]
        private let mode: CostChartValueDisplayMode

        init(points: [ChartPoint], mode: CostChartValueDisplayMode) {
            self.points = points
            self.mode = mode
        }

        func stringForValue(_ value: Double, entry: ChartDataEntry, dataSetIndex _: Int, viewPortHandler _: ViewPortHandler?) -> String {
            let index = Int(entry.x.rounded())
            guard points.indices.contains(index) else {
                return ""
            }
            let point = points[index]
            let costText = String(format: "$%.2f", point.costUSD)
            let tokenText = point.tokens.map { Self.tokensText($0) } ?? "--"

            switch mode {
            case .cost:
                return costText
            case .tokens:
                return tokenText
            case .both:
                guard point.tokens != nil else {
                    return costText
                }
                return "\(costText) • \(tokenText)"
            }
        }

        private static func tokensText(_ value: Int) -> String {
            if value >= 1_000_000 {
                let millions = Double(value) / 1_000_000.0
                return String(format: "%.1fM", millions)
            }
            if value >= 1_000 {
                let thousands = Double(value) / 1_000.0
                return String(format: "%.1fK", thousands)
            }
            return "\(value)"
        }
    }

    final class Coordinator: NSObject, ChartViewDelegate {
        var parent: CodexDailyCostLineChartView?
        fileprivate var points: [ChartPoint] = []
        var selectedIndex: Int?
        var lastCount: Int = 0
        var lastGranularity: CostChartGranularity = .day

        func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight _: Highlight) {
            guard chartView is LineChartView else { return }
            let index = Int(entry.x.rounded())
            selectedIndex = index
            emitSelection(at: index)
        }

        func emitSelection(at index: Int) {
            guard points.indices.contains(index) else { return }
            let point = points[index]
            parent?.onSelect?(
                CostChartSelection(
                    id: point.id,
                    label: point.label,
                    costUSD: point.costUSD,
                    tokens: point.tokens
                )
            )
        }
    }
}
#else
struct CodexDailyCostLineChartView: View {
    let entries: [CostSnapshot.DailyCost]
    var granularity: CostChartGranularity = .day
    var valueDisplayMode: CostChartValueDisplayMode = .both
    var selectedID: String? = nil
    var onSelect: ((CostChartSelection) -> Void)? = nil

    func granularity(_ granularity: CostChartGranularity) -> Self {
        var copy = self
        copy.granularity = granularity
        return copy
    }

    func onSelect(_ handler: @escaping (CostChartSelection) -> Void) -> Self {
        var copy = self
        copy.onSelect = handler
        return copy
    }

    func selectedID(_ id: String?) -> Self {
        var copy = self
        copy.selectedID = id
        return copy
    }

    func valueDisplayMode(_ mode: CostChartValueDisplayMode) -> Self {
        var copy = self
        copy.valueDisplayMode = mode
        return copy
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(entries.suffix(8).enumerated()), id: \.offset) { _, entry in
                HStack(spacing: 8) {
                    Text(entry.date)
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    Spacer()
                    Text(String(format: "$%.2f", entry.costUSD ?? 0))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(DesignSystem.Colors.Text.primary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
#endif
