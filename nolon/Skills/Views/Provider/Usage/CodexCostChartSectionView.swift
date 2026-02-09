import SwiftUI
import ProviderUsage

struct CodexCostChartSectionView: View {
    let todayLine: String?
    let last30Line: String?
    let dailyCosts: [CostSnapshot.DailyCost]

    @Binding var granularity: CostChartGranularity
    @Binding var valueDisplayMode: CostChartValueDisplayMode
    @Binding var selection: CostChartSelection?
    @Binding var selectedID: String?
    @Binding var tableSelection: Set<String>
    @Binding var windowDays: Int?

    @State private var tableSortOrder: [KeyPathComparator<CostTableRow>] = [
        KeyPathComparator(\.date, order: .reverse)
    ]

    private var hasSummaryContent: Bool {
        todayLine != nil || last30Line != nil
    }

    private var sortedTableRows: [CostTableRow] {
        costTableRows(from: dailyCosts, granularity: granularity).sorted(using: tableSortOrder)
    }

    var body: some View {
        if hasSummaryContent {
            VStack(alignment: .leading, spacing: 4) {
                summaryHeader

                if !dailyCosts.isEmpty {
                    chartCard
                }
            }
        }
    }
}

// MARK: - Subviews

private extension CodexCostChartSectionView {
    
    var summaryHeader: some View {
        HStack(alignment: .center, spacing: 4) {
            if let todayLine {
                Text(todayLine)
            }

            if let last30Line {
                Text(last30Line)
            }
        }
        .font(.caption)
        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
    }

    var chartCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            controlsPanel
                .padding(.top, 4)
            .onChange(of: granularity) { _, _ in
                resetSelectionState()
            }
            .onChange(of: windowDays) { _, _ in
                resetSelectionState()
            }

            chartView

            HStack {
                Spacer()
                rangeSelector
            }

            if let selection {
                Text(costChartSelectionText(selection, mode: valueDisplayMode))
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
            }

            if !sortedTableRows.isEmpty {
                tableView
            }
        }
    }

    var controlsPanel: some View {
        HStack(spacing: 14) {
            HStack(spacing: 6) {
                Text(NSLocalizedString("usage.cost.chart.period", value: "周期", comment: "Period label"))
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                Picker("", selection: $granularity) {
                    Text(NSLocalizedString("usage.cost.chart.day", value: "日", comment: "Day granularity")).tag(CostChartGranularity.day)
                    Text(NSLocalizedString("usage.cost.chart.month", value: "月", comment: "Month granularity")).tag(CostChartGranularity.month)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 140)
                .controlSize(.small)
            }

            Spacer()

            HStack(spacing: 6) {
                Text(NSLocalizedString("usage.cost.chart.display", value: "显示", comment: "Display label"))
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                Toggle(NSLocalizedString("usage.cost.chart.value_mode.cost", value: "费用", comment: "Cost only"), isOn: costDisplayEnabledBinding)
                    .toggleStyle(.checkbox)
                    .controlSize(.small)
                Toggle(NSLocalizedString("usage.cost.chart.value_mode.tokens", value: "Tokens", comment: "Tokens only"), isOn: tokenDisplayEnabledBinding)
                    .toggleStyle(.checkbox)
                    .controlSize(.small)
            }
        }
    }

    var chartView: some View {
        CodexDailyCostLineChartView(entries: dailyCosts)
            .granularity(granularity)
            .valueDisplayMode(valueDisplayMode)
            .selectedID(selectedID)
            .onSelect { picked in
                DispatchQueue.main.async {
                    handleChartSelection(picked)
                }
            }
            .frame(height: 240)
    }

    var rangeSelector: some View {
        HStack(spacing: 6) {
            Text(NSLocalizedString("usage.cost.chart.range", value: "范围", comment: "Range label"))
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
            Picker("", selection: windowBinding) {
                ForEach(CostHistoryWindow.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 240)
            .controlSize(.small)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(DesignSystem.Colors.Component.controlFillStrong)
        .clipShape(.rect(cornerRadius: 8))
    }

    var tableView: some View {
        Table(sortedTableRows, selection: $tableSelection, sortOrder: $tableSortOrder) {
            TableColumn(NSLocalizedString("usage.cost.table.date", value: "日期", comment: "Cost table date"), value: \.date) { row in
                tableCellText(row.dateLabel, rowID: row.id)
            }
            TableColumn(NSLocalizedString("usage.cost.table.cost", value: "费用", comment: "Cost table cost"), value: \.costUSD) { row in
                tableCellText(row.costText, rowID: row.id, monospacedDigits: true)
            }
            TableColumn(NSLocalizedString("usage.cost.table.tokens", value: "Tokens", comment: "Cost table tokens"), value: \.tokens) { row in
                tableCellText(row.tokensText, rowID: row.id, monospacedDigits: true)
            }
        }
        .font(.body)
        .frame(minHeight: 260, maxHeight: 360)
        .clipShape(.rect(cornerRadius: 8))
        .onChange(of: tableSelection) { _, selectedRows in
            handleTableSelection(selectedRows)
        }
    }

    @ViewBuilder
    func tableCellText(_ value: String, rowID: String, monospacedDigits: Bool = false) -> some View {
        let isSelected = tableSelection.contains(rowID)
        Text(value)
            .font(.body)
            .if(monospacedDigits) { view in
                view.monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            .background(isSelected ? DesignSystem.Colors.primary.opacity(0.16) : .clear)
            .clipShape(.rect(cornerRadius: 6))
    }
}

// MARK: - Bindings

private extension CodexCostChartSectionView {
    var windowBinding: Binding<CostHistoryWindow> {
        Binding(
            get: { CostHistoryWindow.from(days: windowDays) },
            set: { windowDays = $0.days }
        )
    }

    var costDisplayEnabledBinding: Binding<Bool> {
        Binding(
            get: {
                switch valueDisplayMode {
                case .cost, .both: return true
                case .tokens: return false
                }
            },
            set: { isEnabled in
                let tokenEnabled: Bool = {
                    switch valueDisplayMode {
                    case .tokens, .both: return true
                    case .cost: return false
                    }
                }()
                valueDisplayMode = modeFrom(costEnabled: isEnabled, tokenEnabled: tokenEnabled)
            }
        )
    }

    var tokenDisplayEnabledBinding: Binding<Bool> {
        Binding(
            get: {
                switch valueDisplayMode {
                case .tokens, .both: return true
                case .cost: return false
                }
            },
            set: { isEnabled in
                let costEnabled: Bool = {
                    switch valueDisplayMode {
                    case .cost, .both: return true
                    case .tokens: return false
                    }
                }()
                valueDisplayMode = modeFrom(costEnabled: costEnabled, tokenEnabled: isEnabled)
            }
        )
    }
}

// MARK: - Actions

private extension CodexCostChartSectionView {
    func resetSelectionState() {
        selection = nil
        selectedID = nil
        tableSelection.removeAll()
    }

    func handleChartSelection(_ picked: CostChartSelection) {
        if selection != picked {
            selection = picked
        }
        if selectedID != picked.id {
            selectedID = picked.id
        }
        let selectedSet = Set([picked.id])
        if tableSelection != selectedSet {
            tableSelection = selectedSet
        }
    }

    func handleTableSelection(_ selectedRows: Set<String>) {
        guard let nextID = sortedTableRows.first(where: { selectedRows.contains($0.id) })?.id else {
            return
        }
        if selectedID != nextID {
            selectedID = nextID
        }
    }

    func modeFrom(costEnabled: Bool, tokenEnabled: Bool) -> CostChartValueDisplayMode {
        switch (costEnabled, tokenEnabled) {
        case (true, true):
            return .both
        case (true, false):
            return .cost
        case (false, true):
            return .tokens
        case (false, false):
            return .cost
        }
    }
}

// MARK: - Formatters & Mapping

private extension CodexCostChartSectionView {
    func costChartSelectionText(_ selection: CostChartSelection, mode: CostChartValueDisplayMode) -> String {
        let costText = String(format: "$%.2f", selection.costUSD)
        let tokenText = selection.tokens.map { tokenCountText($0) }

        switch mode {
        case .cost:
            return "\(selection.label): \(costText)"
        case .tokens:
            return "\(selection.label): \(tokenText ?? "--")"
        case .both:
            if let tokenText {
                return "\(selection.label): \(costText) • \(tokenText)"
            }
            return "\(selection.label): \(costText)"
        }
    }

    func tokenCountText(_ value: Int) -> String {
        if value >= 1_000_000 {
            let millions = Double(value) / 1_000_000.0
            return String(format: NSLocalizedString("usage.metric.tokens_m", value: "%.0fM tokens", comment: "Token count in millions"), millions)
        }
        if value >= 1_000 {
            let thousands = Double(value) / 1_000.0
            return String(format: NSLocalizedString("usage.metric.tokens_k", value: "%.0fK tokens", comment: "Token count in thousands"), thousands)
        }
        return String(format: NSLocalizedString("usage.metric.tokens", value: "%d tokens", comment: "Token count"), value)
    }

    func costTableRows(from values: [CostSnapshot.DailyCost], granularity: CostChartGranularity) -> [CostTableRow] {
        let parsedRows: [ParsedCostRow] = values.compactMap { entry in
            guard let date = Self.parseDate(entry.date) else { return nil }
            return ParsedCostRow(date: date, costUSD: max(0.0, entry.costUSD ?? 0.0), tokens: entry.tokens)
        }

        switch granularity {
        case .day:
            return parsedRows
                .sorted(by: { $0.date > $1.date })
                .map { row in
                    CostTableRow(
                        id: Self.dayRowID(row.date),
                        date: row.date,
                        dateLabel: Self.dayTableDateFormatter.string(from: row.date),
                        costUSD: row.costUSD,
                        tokens: row.tokens ?? 0,
                        costText: String(format: "$%.2f", row.costUSD),
                        tokensText: row.tokens.map { tokenCountText($0) } ?? "--"
                    )
                }
        case .month:
            var grouped: [CostMonthKey: (cost: Double, tokens: Int?)] = [:]
            for row in parsedRows {
                let key = CostMonthKey(date: row.date)
                var current = grouped[key] ?? (0.0, nil)
                current.cost += row.costUSD
                if let tokens = row.tokens {
                    current.tokens = (current.tokens ?? 0) + tokens
                }
                grouped[key] = current
            }

            return grouped.keys
                .sorted(by: { $0.date > $1.date })
                .map { key in
                    let value = grouped[key] ?? (0.0, nil)
                    return CostTableRow(
                        id: Self.monthRowID(year: key.year, month: key.month),
                        date: key.date,
                        dateLabel: Self.monthTableDateFormatter.string(from: key.date),
                        costUSD: value.cost,
                        tokens: value.tokens ?? 0,
                        costText: String(format: "$%.2f", value.cost),
                        tokensText: value.tokens.map { tokenCountText($0) } ?? "--"
                    )
                }
        }
    }

    static func parseDate(_ value: String) -> Date? {
        if let date = isoDateFormatterWithFraction.date(from: value) {
            return date
        }
        if let date = isoDateFormatter.date(from: value) {
            return date
        }
        return simpleDateFormatter.date(from: value)
    }

    static func dayRowID(_ date: Date) -> String {
        "day-\(rowIDDateFormatter.string(from: date))"
    }

    static func monthRowID(year: Int, month: Int) -> String {
        "month-\(year)-\(String(format: "%02d", month))"
    }

    static let isoDateFormatterWithFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let isoDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let simpleDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let dayTableDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("yMMMd")
        return formatter
    }()

    static let monthTableDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("yMMM")
        return formatter
    }()

    static let rowIDDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
