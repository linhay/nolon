import AppKit
import NolonUIFoundation
import SwiftUI

public struct CodexSessionsOverviewCardView: View {
    public let data: CodexSessionsOverviewData
    public let onRefresh: () -> Void
    public let onSelectGroupingID: ((String) -> Void)?

    public init(
        data: CodexSessionsOverviewData,
        onRefresh: @escaping () -> Void,
        onSelectGroupingID: ((String) -> Void)? = nil
    ) {
        self.data = data
        self.onRefresh = onRefresh
        self.onSelectGroupingID = onSelectGroupingID
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: verticalSpacing) {
            header

            statusBanners

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 118), spacing: 10, alignment: .top)],
                alignment: .leading,
                spacing: 10
            ) {
                ForEach(data.metrics) { metric in
                    metricCard(metric)
                }
            }
        }
        .padding(cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCard(
            background: DesignSystem.Colors.Background.elevated.opacity(0.96),
            cornerRadius: DesignSystem.Metrics.cornerRadiusL,
            borderColor: DesignSystem.Colors.Component.border.opacity(0.32),
            shadow: .subtle
        )
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 14) {
                headerLead
                Spacer(minLength: 12)
                headerControls
            }
            .frame(minWidth: 660, alignment: .leading)

            VStack(alignment: .leading, spacing: 10) {
                headerLead
                headerControls
            }
        }
    }

    private var headerLead: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.primary.opacity(0.14))
                    .frame(width: iconSize, height: iconSize)

                Image(systemName: "arrow.left.arrow.right.circle.fill")
                    .font(.system(size: iconFontSize, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.primary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(data.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.Text.primary)

                Text(data.subtitle)
                    .font(data.displayMode == .compact ? .caption.weight(.medium) : .caption)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    .lineLimit(data.displayMode == .compact ? 1 : 2)
                    .fixedSize(horizontal: false, vertical: true)
                    .help(data.subtitle)
            }
        }
    }

    private var headerControls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 8) {
                groupingPicker
                headerRefreshButton
            }
            .frame(minWidth: 260, alignment: .trailing)

            VStack(alignment: .leading, spacing: 8) {
                groupingPicker
                headerRefreshButton
            }
        }
    }

    @ViewBuilder
    private var groupingPicker: some View {
        if let groupingTitle = data.groupingTitle,
           let selectedGroupingID = data.selectedGroupingID,
           !data.groupingOptions.isEmpty
        {
            Picker(
                groupingTitle,
                selection: Binding(
                    get: { selectedGroupingID },
                    set: { onSelectGroupingID?($0) }
                )
            ) {
                ForEach(data.groupingOptions) { option in
                    Text(option.title).tag(option.id)
                }
            }
            .pickerStyle(.segmented)
            .frame(minWidth: 180, idealWidth: 220, maxWidth: 240)
            .accessibilityLabel(groupingTitle)
        }
    }

    private var headerRefreshButton: some View {
        Button(action: onRefresh) {
            Label(data.refreshTitle, systemImage: "arrow.clockwise")
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .disabled(data.isRefreshDisabled)
    }

    @ViewBuilder
    private var statusBanners: some View {
        let entries = [
            bannerEntry(
                id: "status",
                message: data.statusMessage,
                systemImage: "checkmark.circle.fill",
                tint: DesignSystem.Colors.Status.success
            ),
            bannerEntry(
                id: "scanning",
                message: data.backgroundScanningMessage,
                systemImage: "arrow.clockwise.circle.fill",
                tint: DesignSystem.Colors.Status.info
            ),
        ].compactMap { $0 }

        if !entries.isEmpty {
            FlowLayout(spacing: 8) {
                ForEach(entries, id: \.id) { entry in
                    compactStatusBanner(
                        message: entry.message,
                        systemImage: entry.systemImage,
                        tint: entry.tint
                    )
                }
            }
        }
    }

    private func metricCard(_ metric: CodexSessionsMetricData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(metric.title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)

            Text(metric.value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(DesignSystem.Colors.Text.primary)
                .lineLimit(1)
        }
        .padding(data.displayMode == .compact ? 10 : 12)
        .frame(maxWidth: .infinity, minHeight: data.displayMode == .compact ? 60 : 68, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusM, style: .continuous)
                .fill(DesignSystem.Colors.Background.surface.opacity(0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusM, style: .continuous)
                .stroke(DesignSystem.Colors.Component.border.opacity(0.24), lineWidth: 1)
        )
    }

    private func compactStatusBanner(message: String, systemImage: String, tint: Color) -> some View {
        HStack(alignment: .center, spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)

            Text(message)
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .lineLimit(1)
                .help(message)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.08), in: Capsule())
        .overlay(
            Capsule()
                .stroke(tint.opacity(0.16), lineWidth: 1)
        )
    }

    private func bannerEntry(id: String, message: String?, systemImage: String, tint: Color) -> BannerEntry? {
        guard let message, !message.isEmpty else { return nil }
        return BannerEntry(id: id, message: message, systemImage: systemImage, tint: tint)
    }

    private var verticalSpacing: CGFloat {
        data.displayMode == .compact ? 10 : 12
    }

    private var cardPadding: CGFloat {
        data.displayMode == .compact ? 14 : 16
    }

    private var iconSize: CGFloat {
        data.displayMode == .compact ? 30 : 34
    }

    private var iconFontSize: CGFloat {
        data.displayMode == .compact ? 14 : 16
    }
}

public struct CodexSessionsSectionCardView: View {
    public let data: CodexSessionsSectionData
    public let onTapSectionAction: (String) -> Void
    public let onTapRowAction: (CodexSessionsRowData, String) -> Void
    public let onRevealInFinder: (CodexSessionsRowData) -> Void
    public let onToggleCollapse: (String) -> Void
    public let selectedRowID: String?
    public let onSelectRow: (CodexSessionsRowData) -> Void

    public init(
        data: CodexSessionsSectionData,
        onTapSectionAction: @escaping (String) -> Void,
        onTapRowAction: @escaping (CodexSessionsRowData, String) -> Void,
        onRevealInFinder: @escaping (CodexSessionsRowData) -> Void,
        onToggleCollapse: @escaping (String) -> Void = { _ in },
        selectedRowID: String? = nil,
        onSelectRow: @escaping (CodexSessionsRowData) -> Void = { _ in }
    ) {
        self.data = data
        self.onTapSectionAction = onTapSectionAction
        self.onTapRowAction = onTapRowAction
        self.onRevealInFinder = onRevealInFinder
        self.onToggleCollapse = onToggleCollapse
        self.selectedRowID = selectedRowID
        self.onSelectRow = onSelectRow
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader

            if let headerStatusCaption, !headerStatusCaption.isEmpty {
                sectionStatusCaption(headerStatusCaption)
            }

            if !data.rows.isEmpty {
                adaptiveRowsContainer
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCard(
            background: DesignSystem.Colors.Background.elevated.opacity(0.94),
            cornerRadius: DesignSystem.Metrics.cornerRadiusL,
            borderColor: sectionBorderColor,
            shadow: .subtle
        )
        .animation(.snappy(duration: 0.2), value: data.isExpanded)
    }

    private var sectionHeader: some View {
        VStack(alignment: .leading, spacing: 7) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    sectionHeaderLead
                    Spacer(minLength: 8)
                    sectionHeaderActions
                }
                .frame(minWidth: 560, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    sectionHeaderLead
                    sectionHeaderActions
                }
            }

            if showsSectionSecondaryLine {
                sectionSecondaryLine
            }
        }
    }

    @ViewBuilder
    private var sectionHeaderLead: some View {
        if isExpandable {
            Button(action: { onToggleCollapse(data.id) }) {
                sectionHeaderLeadContent
            }
            .buttonStyle(.plain)
            .contentShape(.rect)
            .help(data.expansionTitle ?? "")
            .accessibilityLabel(data.expansionTitle ?? "")
        } else {
            sectionHeaderLeadContent
        }
    }

    private var sectionHeaderLeadContent: some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(sectionAccentColor.opacity(0.12))
                    .frame(width: 30, height: 30)

                Image(systemName: sectionSymbolName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(sectionAccentColor)
            }

            HStack(alignment: .center, spacing: 8) {
                Text(data.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.Text.primary)
                    .lineLimit(1)

                if !data.badges.isEmpty {
                    headerBadgeRow
                }
            }
        }
    }

    private var sectionHeaderActions: some View {
        HStack(spacing: 8) {
            if let expansionTitle = data.expansionTitle, !expansionTitle.isEmpty {
                Button(action: { onToggleCollapse(data.id) }) {
                    Image(systemName: data.isExpanded ? "chevron.up.circle" : "chevron.down.circle")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(expansionTitle)
                .accessibilityLabel(expansionTitle)
            }

            if let actionMenuTitle = data.actionMenuTitle, !data.actions.isEmpty {
                Menu {
                    ForEach(data.actions) { action in
                        Button(action.title) {
                            onTapSectionAction(action.targetProviderID)
                        }
                    }
                } label: {
                    Label(sectionActionMenuShortTitle(for: actionMenuTitle), systemImage: "arrow.right.circle")
                }
                .menuStyle(.button)
                .controlSize(.small)
                .help(actionMenuTitle)
            }
        }
    }

    private var isExpandable: Bool {
        guard let expansionTitle = data.expansionTitle else { return false }
        return !expansionTitle.isEmpty
    }

    private var headerBadgeRow: some View {
        HStack(spacing: 6) {
            ForEach(data.badges) { badge in
                sectionHeaderBadge(text: badge.text)
            }
        }
    }

    @ViewBuilder
    private var sectionSecondaryLine: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 6) {
                if let titleSecondaryText = data.titleSecondaryText, !titleSecondaryText.isEmpty {
                    sectionPathLine(titleSecondaryText)
                }

                if let secondaryStatusSummary, !secondaryStatusSummary.isEmpty {
                    if let titleSecondaryText = data.titleSecondaryText, !titleSecondaryText.isEmpty {
                        Text("·")
                            .foregroundStyle(DesignSystem.Colors.Text.quaternary)
                    }
                    Text(secondaryStatusSummary)
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                        .lineLimit(1)
                        .help(data.subtitle ?? secondaryStatusSummary)
                }
            }

            if let titleSecondaryText = data.titleSecondaryText, !titleSecondaryText.isEmpty {
                sectionPathLine(titleSecondaryText)
            } else if let secondaryStatusSummary, !secondaryStatusSummary.isEmpty {
                Text(secondaryStatusSummary)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                    .lineLimit(1)
                    .help(data.subtitle ?? secondaryStatusSummary)
            }
        }
    }

    private func sectionStatusCaption(_ subtitle: String) -> some View {
        Text(subtitle)
            .font(.caption)
            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func sectionPathLine(_ titleSecondaryText: String) -> some View {
        HStack(alignment: .center, spacing: 6) {
            Image(systemName: "folder")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.Text.quaternary)

            Text(titleSecondaryText)
                .font(.caption.monospaced())
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .help(titleSecondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var adaptiveRowsContainer: some View {
        compactRowsContainer
    }

    private func tableContainer(layout: TableLayout) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            tableHeader(layout: layout)
            Divider()
                .overlay(DesignSystem.Colors.Component.border.opacity(0.3))
            ForEach(Array(data.rows.enumerated()), id: \.element.id) { index, row in
                tableRowView(row, layout: layout)
                if index < data.rows.count - 1 {
                    Divider()
                        .overlay(DesignSystem.Colors.Component.border.opacity(0.15))
                }
            }
        }
        .background(tableContainerBackground)
        .overlay(tableContainerOverlay)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusM, style: .continuous))
    }

    private var compactRowsContainer: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(data.rows.enumerated()), id: \.element.id) { index, row in
                compactRowView(row)
                if index < data.rows.count - 1 {
                    Divider()
                        .overlay(DesignSystem.Colors.Component.border.opacity(0.15))
                }
            }
        }
        .background(tableContainerBackground)
        .overlay(tableContainerOverlay)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusM, style: .continuous))
    }

    private var tableContainerBackground: some View {
        RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusM, style: .continuous)
            .fill(DesignSystem.Colors.Background.surface.opacity(0.5))
    }

    private var tableContainerOverlay: some View {
        RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusM, style: .continuous)
            .stroke(DesignSystem.Colors.Component.border.opacity(0.2), lineWidth: 1)
    }

    private func tableHeader(layout: TableLayout) -> some View {
        HStack(alignment: .center, spacing: layout.columnSpacing) {
            Text(NSLocalizedString("codex.sessions.table.name", value: "Name", comment: "Session table column header"))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(NSLocalizedString("codex.sessions.table.id", value: "ID", comment: "Session table column header"))
                .frame(width: layout.idColumnWidth, alignment: .leading)
            Text(NSLocalizedString("codex.sessions.table.time", value: "Time", comment: "Session table column header"))
                .frame(width: layout.timeColumnWidth, alignment: .leading)
            if showsProviderColumn {
                Text(NSLocalizedString("codex.sessions.table.provider", value: "Provider", comment: "Session table column header"))
                    .frame(width: layout.providerColumnWidth, alignment: .leading)
            }
            Text(NSLocalizedString("codex.sessions.table.usage", value: "Usage", comment: "Session table column header"))
                .frame(width: layout.usageColumnWidth, alignment: .leading)
            Text(NSLocalizedString("codex.sessions.table.menu", value: "Menu", comment: "Session table column header"))
                .frame(width: layout.menuColumnWidth, alignment: .trailing)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
        .padding(.horizontal, layout.horizontalPadding)
        .padding(.vertical, 9)
        .background(DesignSystem.Colors.Background.surface.opacity(0.7))
    }

    private func tableRowView(_ row: CodexSessionsRowData, layout: TableLayout) -> some View {
        HStack(alignment: .top, spacing: layout.columnSpacing) {
            nameColumnView(row, summaryLineLimit: layout.summaryLineLimit, metadataSpacing: layout.metadataSpacing)
                .frame(maxWidth: .infinity, alignment: .leading)

            idColumnView(row, isCompactIDSecondaryText: layout.usesCompactIDText)
                .frame(width: layout.idColumnWidth, alignment: .leading)

            timeColumnView(row)
                .frame(width: layout.timeColumnWidth, alignment: .leading)

            if showsProviderColumn {
                Text(row.providerText)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    .lineLimit(layout.providerLineLimit)
                    .frame(width: layout.providerColumnWidth, alignment: .leading)
            }

            usageView(row.usage)
                .frame(width: layout.usageColumnWidth, alignment: .leading)

            HStack(spacing: 6) {
                Spacer(minLength: 0)
                rowMenuButton(row)
            }
            .frame(width: layout.menuColumnWidth, alignment: .trailing)
        }
        .padding(.horizontal, layout.horizontalPadding)
        .padding(.vertical, layout.verticalPadding)
        .contextMenu {
            rowContextMenu(row)
        }
    }

    private func compactRowView(_ row: CodexSessionsRowData) -> some View {
        ViewThatFits(in: .horizontal) {
            compactRowContent(
                row,
                usage: compactUsageDisplayData(row.usage, showsSecondaryText: true)
            )
            .frame(minWidth: 700, alignment: .leading)

            compactRowContent(
                row,
                usage: compactUsageDisplayData(row.usage, showsSecondaryText: false)
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(rowBackground(isSelected: selectedRowID == row.id))
        .contentShape(RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusS, style: .continuous))
        .onTapGesture {
            onSelectRow(row)
        }
        .contextMenu {
            rowContextMenu(row)
        }
    }

    private func compactRowContent(
        _ row: CodexSessionsRowData,
        usage: CodexSessionsUsageDisplayData
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .center, spacing: 8) {
                    Text(row.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(DesignSystem.Colors.Text.primary)
                        .lineLimit(1)

                    FlowLayout(spacing: 6) {
                        compactStatusPills(row)
                    }
                }

                HStack(alignment: .center, spacing: 8) {
                    Label(row.timeText, systemImage: "clock")
                        .labelStyle(.titleAndIcon)
                        .lineLimit(1)

                    if showsProviderColumn {
                        Text("·")
                            .foregroundStyle(DesignSystem.Colors.Text.quaternary)
                        Text(row.providerText)
                            .lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
            }

            Spacer(minLength: 8)

            compactUsageItem(usage)
                .frame(minWidth: 68, alignment: .leading)

            HStack(spacing: 10) {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.Text.quaternary)

                rowMenuButton(row)
            }
        }
    }

    @ViewBuilder
    private func compactStatusPills(_ row: CodexSessionsRowData) -> some View {
        if row.isArchived {
            pill(
                text: NSLocalizedString(
                    "codex.sessions.badge.archived",
                    value: "Archived",
                    comment: "Archived badge"
                ),
                tint: DesignSystem.Colors.Text.secondary
            )
        }
        if !row.isEditable, let readOnlyText = row.readOnlyText, !readOnlyText.isEmpty {
            pill(text: readOnlyText, tint: DesignSystem.Colors.Status.warning)
        }
    }

    private func nameColumnView(
        _ row: CodexSessionsRowData,
        summaryLineLimit: Int,
        metadataSpacing: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(row.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(DesignSystem.Colors.Text.primary)
                .lineLimit(2)
            if !row.nameMetadataItems.isEmpty {
                FlowLayout(spacing: metadataSpacing) {
                    ForEach(row.nameMetadataItems) { item in
                        pill(text: item.text, tint: DesignSystem.Colors.Text.tertiary)
                    }
                }
            }
            if summaryLineLimit > 0, let summary = row.summary, !summary.isEmpty {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    .lineLimit(summaryLineLimit)
            }
        }
    }

    private func idColumnView(_ row: CodexSessionsRowData, isCompactIDSecondaryText: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(row.idText)
                .font(.caption.monospaced())
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .lineLimit(2)
                .textSelection(.enabled)
            if let idSecondaryText = row.idSecondaryText, !idSecondaryText.isEmpty {
                Text(idSecondaryText)
                    .font(.caption2.monospaced())
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                    .lineLimit(isCompactIDSecondaryText ? 2 : 1)
            }
        }
    }

    private func timeColumnView(_ row: CodexSessionsRowData) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(row.timeText)
                .font(.caption.monospaced())
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
            FlowLayout(spacing: 6) {
                if !row.isEditable, let readOnlyText = row.readOnlyText, !readOnlyText.isEmpty {
                    pill(text: readOnlyText, tint: DesignSystem.Colors.Status.warning)
                }
                if !row.isArchived {
                    pill(
                        text: NSLocalizedString("codex.sessions.badge.live", value: "Live", comment: "Live badge"),
                        tint: DesignSystem.Colors.Status.success
                    )
                }
            }
        }
    }

    private func compactMetadataItem(
        title: String,
        primaryText: String,
        secondaryText: String?,
        monospaced: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
            Text(primaryText)
                .font(monospaced ? .caption.monospaced() : .caption)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .lineLimit(2)
                .textSelection(.enabled)
            if let secondaryText, !secondaryText.isEmpty {
                Text(secondaryText)
                    .font(monospaced ? .caption2.monospaced() : .caption2)
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func compactUsageItem(_ usage: CodexSessionsUsageDisplayData) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(NSLocalizedString("codex.sessions.table.usage", value: "Usage", comment: "Session table column header"))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
            usageView(usage)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func compactUsageDisplayData(
        _ usage: CodexSessionsUsageDisplayData,
        showsSecondaryText: Bool
    ) -> CodexSessionsUsageDisplayData {
        guard showsSecondaryText == false else { return usage }
        guard case .value(let primaryText, _) = usage else { return usage }
        return .value(primaryText: primaryText, secondaryText: nil)
    }

    private func rowBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusS, style: .continuous)
            .fill(
                isSelected
                    ? DesignSystem.Colors.primary.opacity(0.10)
                    : Color.clear
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusS, style: .continuous)
                    .stroke(
                        isSelected
                            ? DesignSystem.Colors.primary.opacity(0.24)
                            : Color.clear,
                        lineWidth: 1
                    )
            )
    }

    private func rowMenuButton(_ row: CodexSessionsRowData) -> some View {
        EllipsisMenuButton {
            rowContextMenu(row)
        }
        .help(
            NSLocalizedString(
                "codex.sessions.action.more",
                value: "More actions",
                comment: "Codex sessions more actions label"
            )
        )
        .accessibilityLabel(
            NSLocalizedString(
                "codex.sessions.action.more",
                value: "More actions",
                comment: "Codex sessions more actions label"
            )
        )
    }

    @ViewBuilder
    private func rowContextMenu(_ row: CodexSessionsRowData) -> some View {
        ForEach(row.actions) { action in
            Button(action.title) {
                onTapRowAction(row, action.targetProviderID)
            }
        }
        if !row.actions.isEmpty {
            Divider()
        }
        if let showInFinderTitle = row.showInFinderTitle, !showInFinderTitle.isEmpty {
            Button(showInFinderTitle) {
                onRevealInFinder(row)
            }
        }
        if let copyPathTitle = row.copyPathTitle, !copyPathTitle.isEmpty {
            Button(copyPathTitle) {
                copyToPasteboard(row.rolloutPath)
            }
        }
        if row.showsRevealInFinder || row.copyPathTitle != nil {
            Divider()
        }
        let statusTexts = menuStatusTexts(for: row)
        if !statusTexts.isEmpty {
            ForEach(statusTexts, id: \.self) { text in
                Text(text)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
            }
            Divider()
        }
        if !row.menuMetadataItems.isEmpty {
            ForEach(row.menuMetadataItems) { item in
                Text(item.text)
                    .font(item.style == .code ? .caption.monospaced() : .caption)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
            }
            Divider()
        }
        Text(row.rolloutPath)
            .font(.caption.monospaced())
            .foregroundStyle(DesignSystem.Colors.Text.secondary)
        if row.stateRowCount > 0 {
            Text(
                String(
                    format: NSLocalizedString(
                        "codex.sessions.more.db_rows",
                        value: "DB rows: %d",
                        comment: "Codex sessions more menu DB rows"
                    ),
                    row.stateRowCount
                )
            )
            .font(.caption)
            .foregroundStyle(DesignSystem.Colors.Text.secondary)
        }
    }

    @ViewBuilder
    private func usageView(_ usage: CodexSessionsUsageDisplayData) -> some View {
        switch usage {
        case .placeholder(let text):
            Text(text)
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
        case .failed(let text):
            Text(text)
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.Status.warning)
        case .value(let primaryText, let secondaryText):
            VStack(alignment: .leading, spacing: 2) {
                Text(primaryText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.Text.primary)
                if let secondaryText, !secondaryText.isEmpty {
                    Text(secondaryText)
                        .font(.caption2.monospaced())
                        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                        .lineLimit(2)
                }
            }
        }
    }

    private func pill(text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(tint.opacity(0.10), in: Capsule())
    }

    private func sectionHeaderBadge(text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(DesignSystem.Colors.Text.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(DesignSystem.Colors.Text.secondary.opacity(0.08), in: Capsule())
            .lineLimit(1)
    }

    private var showsProviderColumn: Bool {
        guard data.titleSecondaryText == nil, !data.rows.isEmpty else { return true }
        let providerTexts = Set(data.rows.map(\.providerText))
        guard providerTexts.count == 1, let providerText = providerTexts.first else { return true }

        let normalizedTitle = normalizedProviderComparisonText(data.title)
        let normalizedProvider = normalizedProviderComparisonText(providerText)
        guard !normalizedTitle.isEmpty else { return true }
        return !normalizedProvider.contains(normalizedTitle)
    }

    private func minimumContentWidth(for layout: TableLayout) -> CGFloat {
        guard !showsProviderColumn else { return layout.minimumContentWidth }
        return layout.minimumContentWidth - layout.providerColumnWidth - layout.columnSpacing
    }

    private func menuStatusTexts(for row: CodexSessionsRowData) -> [String] {
        var texts: [String] = []

        if row.isArchived {
            texts.append(
                NSLocalizedString(
                    "codex.sessions.badge.archived",
                    value: "Archived",
                    comment: "Archived badge"
                )
            )
        }

        if !row.isEditable, let readOnlyText = row.readOnlyText, !readOnlyText.isEmpty {
            texts.append(readOnlyText)
        }

        if !row.isArchived {
            texts.append(
                NSLocalizedString(
                    "codex.sessions.badge.live",
                    value: "Live",
                    comment: "Live badge"
                )
            )
        }

        return texts
    }

    private func normalizedProviderComparisonText(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(
                of: "[^a-z0-9]+",
                with: "",
                options: .regularExpression
            )
    }

    private var sectionAccentColor: Color {
        switch data.presentationKind {
        case .rewritableGroup:
            return DesignSystem.Colors.primary
        case .singleSessionOnly:
            return DesignSystem.Colors.Text.secondary
        case .readOnly:
            return DesignSystem.Colors.Status.warning
        }
    }

    private var sectionBorderColor: Color {
        switch data.presentationKind {
        case .rewritableGroup:
            return DesignSystem.Colors.primary.opacity(0.24)
        case .singleSessionOnly:
            return DesignSystem.Colors.Component.border.opacity(0.28)
        case .readOnly:
            return DesignSystem.Colors.Status.warning.opacity(0.22)
        }
    }

    private var sectionSymbolName: String {
        switch data.presentationKind {
        case .rewritableGroup:
            return "arrow.left.arrow.right.circle.fill"
        case .singleSessionOnly:
            return "square.stack.3d.down.forward"
        case .readOnly:
            return "lock.fill"
        }
    }

    private var showsSectionSecondaryLine: Bool {
        if let titleSecondaryText = data.titleSecondaryText, !titleSecondaryText.isEmpty {
            return true
        }
        if let secondaryStatusSummary, !secondaryStatusSummary.isEmpty {
            return true
        }
        return false
    }

    private var secondaryStatusSummary: String? {
        switch data.presentationKind {
        case .rewritableGroup:
            return nil
        case .singleSessionOnly:
            return NSLocalizedString(
                "codex.sessions.group.status.single_session",
                value: "Single session",
                comment: "Section status for single-session groups"
            )
        case .readOnly:
            return NSLocalizedString(
                "codex.sessions.group.status.read_only",
                value: "Read-only",
                comment: "Section status for read-only groups"
            )
        }
    }

    private var headerStatusCaption: String? {
        guard data.presentationKind != .rewritableGroup else { return nil }
        guard let subtitle = data.subtitle, !subtitle.isEmpty else { return nil }
        return subtitle
    }

    private func sectionActionMenuShortTitle(for actionMenuTitle: String) -> String {
        if actionMenuTitle.localizedCaseInsensitiveContains("move") {
            return NSLocalizedString(
                "codex.sessions.group.action.move_short",
                value: "Move",
                comment: "Short section move action title"
            )
        }

        return actionMenuTitle
    }

    private struct TableLayout {
        let minimumContentWidth: CGFloat
        let idColumnWidth: CGFloat
        let timeColumnWidth: CGFloat
        let providerColumnWidth: CGFloat
        let usageColumnWidth: CGFloat
        let menuColumnWidth: CGFloat
        let columnSpacing: CGFloat
        let horizontalPadding: CGFloat
        let verticalPadding: CGFloat
        let summaryLineLimit: Int
        let providerLineLimit: Int
        let metadataSpacing: CGFloat
        let usesCompactIDText: Bool

        static let regular = TableLayout(
            minimumContentWidth: 940,
            idColumnWidth: 180,
            timeColumnWidth: 134,
            providerColumnWidth: 148,
            usageColumnWidth: 140,
            menuColumnWidth: 60,
            columnSpacing: 12,
            horizontalPadding: 14,
            verticalPadding: 10,
            summaryLineLimit: 0,
            providerLineLimit: 2,
            metadataSpacing: 6,
            usesCompactIDText: false
        )

        static let medium = TableLayout(
            minimumContentWidth: 760,
            idColumnWidth: 150,
            timeColumnWidth: 118,
            providerColumnWidth: 118,
            usageColumnWidth: 108,
            menuColumnWidth: 48,
            columnSpacing: 10,
            horizontalPadding: 12,
            verticalPadding: 10,
            summaryLineLimit: 0,
            providerLineLimit: 3,
            metadataSpacing: 5,
            usesCompactIDText: true
        )
    }

    private func copyToPasteboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}

public struct CodexSessionsLoadMoreButton: View {
    public let data: CodexSessionsLoadMoreData
    public let onTap: () -> Void

    public init(data: CodexSessionsLoadMoreData, onTap: @escaping () -> Void) {
        self.data = data
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: "chevron.down.circle.fill")
                    .font(.system(size: 15, weight: .semibold))

                Text(data.title)
                    .font(.headline)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .foregroundStyle(data.isDisabled ? DesignSystem.Colors.Text.tertiary : DesignSystem.Colors.primary)
        .disabled(data.isDisabled)
        .dsCard(
            background: DesignSystem.Colors.Background.elevated.opacity(0.92),
            cornerRadius: DesignSystem.Metrics.cornerRadiusM,
            borderColor: DesignSystem.Colors.Component.border.opacity(0.25)
        )
    }
}

private struct BannerEntry {
    let id: String
    let message: String
    let systemImage: String
    let tint: Color
}
