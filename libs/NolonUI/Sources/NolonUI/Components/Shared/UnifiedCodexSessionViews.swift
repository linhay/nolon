import AppKit
import NolonUIFoundation
import SwiftUI

public struct CodexSessionsOverviewCardView: View {
    public let data: CodexSessionsOverviewData
    public let onRefresh: () -> Void
    public let onSelectGroupingID: ((String) -> Void)?
    public let onSelectSortingID: ((String) -> Void)?

    public init(
        data: CodexSessionsOverviewData,
        onRefresh: @escaping () -> Void,
        onSelectGroupingID: ((String) -> Void)? = nil,
        onSelectSortingID: ((String) -> Void)? = nil
    ) {
        self.data = data
        self.onRefresh = onRefresh
        self.onSelectGroupingID = onSelectGroupingID
        self.onSelectSortingID = onSelectSortingID
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            metricsBand

            if hasFooterStatus {
                Divider()

                footerStatusBar
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCard(
            background: DesignSystem.Colors.Background.surface.opacity(0.98),
            cornerRadius: DesignSystem.Metrics.cornerRadiusL,
            borderColor: DesignSystem.Colors.Component.border.opacity(0.2),
            shadow: .subtle
        )
    }

    private var header: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
            GridRow(alignment: .top) {
                titleText
                    .gridCellUnsizedAxes(.vertical)
                    .frame(maxWidth: .infinity, alignment: .leading)

                headerControls
                    .gridCellAnchor(.topTrailing)
            }
            GridRow {
                subtitleText
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .gridCellColumns(2)
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, headerVerticalPadding)
    }

    private var titleText: some View {
        Text(data.title)
            .font(.headline.weight(.semibold))
            .foregroundStyle(DesignSystem.Colors.Text.primary)
            .lineLimit(1)
            .truncationMode(.tail)
            .layoutPriority(0)
    }

    private var subtitleText: some View {
        Text(data.subtitle)
            .font(.caption)
            .foregroundStyle(DesignSystem.Colors.Text.secondary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .help(data.subtitle)
    }

    private var headerControls: some View {
        Grid(alignment: .trailing, horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow(alignment: .center) {
                groupingPicker
                sortingMenu
                headerRefreshButton
            }
        }
        .gridCellUnsizedAxes([.horizontal, .vertical])
        .layoutPriority(1)
    }

    @ViewBuilder
    private var groupingPicker: some View {
        if let groupingTitle = data.groupingTitle,
           let selectedGroupingID = data.selectedGroupingID,
           !data.groupingOptions.isEmpty
        {
            Picker(
                selection: Binding(
                    get: { selectedGroupingID },
                    set: { onSelectGroupingID?($0) }
                )
            ) {
                ForEach(data.groupingOptions) { option in
                    Text(option.title).tag(option.id)
                }
            } label: {
                EmptyView()
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.small)
            .frame(minWidth: 180, idealWidth: 216, maxWidth: 240)
            .accessibilityLabel(groupingTitle)
        }
    }

    @ViewBuilder
    private var sortingMenu: some View {
        if let sortingTitle = data.sortingTitle,
           let selectedSortingID = data.selectedSortingID,
           !data.sortingOptions.isEmpty
        {
            Menu {
                ForEach(data.sortingOptions) { option in
                    Button {
                        onSelectSortingID?(option.id)
                    } label: {
                        HStack {
                            Text(option.title)
                            if option.id == selectedSortingID {
                                Spacer(minLength: 8)
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Label(currentSortingTitle(selectedSortingID: selectedSortingID), systemImage: "arrow.up.arrow.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusS, style: .continuous)
                            .fill(DesignSystem.Colors.Background.elevated.opacity(0.88))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusS, style: .continuous)
                            .stroke(DesignSystem.Colors.Component.border.opacity(0.18), lineWidth: 1)
                    )
            }
            .menuStyle(.borderlessButton)
            .help(sortingTitle)
            .accessibilityLabel(sortingTitle)
        }
    }

    private var headerRefreshButton: some View {
        Button(action: onRefresh) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .foregroundStyle(
            data.isRefreshDisabled
                ? DesignSystem.Colors.Text.tertiary
                : DesignSystem.Colors.Text.secondary
        )
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusS, style: .continuous)
                .fill(DesignSystem.Colors.Background.elevated.opacity(data.isRefreshDisabled ? 0.45 : 0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusS, style: .continuous)
                .stroke(DesignSystem.Colors.Component.border.opacity(0.18), lineWidth: 1)
        )
        .disabled(data.isRefreshDisabled)
        .help(data.refreshTitle)
        .accessibilityLabel(data.refreshTitle)
    }

    private var metricsBand: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) {
                ForEach(Array(data.metrics.enumerated()), id: \.element.id) { index, metric in
                    metricColumn(metric)

                    if index < data.metrics.count - 1 {
                        Divider()
                    }
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(data.metrics.enumerated()), id: \.element.id) { index, metric in
                    metricColumn(metric)

                    if index < data.metrics.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }

    private func metricColumn(_ metric: CodexSessionsMetricData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 6) {
                Circle()
                    .fill(metricAccentColor(for: metric.id))
                    .frame(width: 6, height: 6)

                Text(metric.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                    .lineLimit(1)
            }

            Text(metric.value)
                .font(metricValueFont)
                .monospacedDigit()
                .foregroundStyle(DesignSystem.Colors.Text.primary)
                .lineLimit(1)

            if let detailText = metric.detailText, !detailText.isEmpty {
                Text(detailText)
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, metricVerticalPadding)
    }

    @ViewBuilder
    private var footerStatusBar: some View {
        let entries = footerEntries
        if !entries.isEmpty {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 12) {
                    ForEach(entries, id: \.id) { entry in
                        footerStatusEntry(entry)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, footerVerticalPadding)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(entries, id: \.id) { entry in
                        footerStatusEntry(entry)
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, footerVerticalPadding)
            }
            .background(DesignSystem.Colors.Background.elevated.opacity(0.45))
        }
    }

    private func footerStatusEntry(_ entry: BannerEntry) -> some View {
        HStack(alignment: .center, spacing: 6) {
            Image(systemName: entry.systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(entry.tint)

            Text(entry.message)
                .font(.caption2)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .lineLimit(1)
                .help(entry.message)
        }
    }

    private func bannerEntry(id: String, message: String?, systemImage: String, tint: Color) -> BannerEntry? {
        guard let message, !message.isEmpty else { return nil }
        return BannerEntry(id: id, message: message, systemImage: systemImage, tint: tint)
    }

    private var footerEntries: [BannerEntry] {
        [
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
            bannerEntry(
                id: "pagination",
                message: data.paginationMessage,
                systemImage: "ellipsis.circle.fill",
                tint: DesignSystem.Colors.Status.warning
            ),
        ]
        .compactMap { $0 }
    }

    private var hasFooterStatus: Bool {
        !footerEntries.isEmpty
    }

    private func currentSortingTitle(selectedSortingID: String) -> String {
        guard let option = data.sortingOptions.first(where: { $0.id == selectedSortingID }) else {
            return data.sortingTitle ?? ""
        }
        return option.title
    }

    private func metricAccentColor(for metricID: String) -> Color {
        switch metricID {
        case "rewritable":
            return DesignSystem.Colors.Status.success
        case "groups":
            return DesignSystem.Colors.Status.info
        default:
            return DesignSystem.Colors.primary
        }
    }

    private var metricValueFont: Font {
        data.displayMode == .compact
            ? .title3.weight(.semibold)
            : .title2.weight(.semibold)
    }

    private var horizontalPadding: CGFloat {
        data.displayMode == .compact ? 14 : 16
    }

    private var headerVerticalPadding: CGFloat {
        data.displayMode == .compact ? 12 : 13
    }

    private var metricVerticalPadding: CGFloat {
        data.displayMode == .compact ? 11 : 12
    }

    private var footerVerticalPadding: CGFloat {
        data.displayMode == .compact ? 7 : 8
    }
}

public struct CodexSessionsSectionCardView<ExpandedRowContent: View>: View {
    public let data: CodexSessionsSectionData
    public let onTapSectionAction: (String) -> Void
    public let onCopySectionThreadIDs: (() -> Void)?
    public let onRevealSectionFolder: (() -> Void)?
    public let onTapRowAction: (CodexSessionsRowData, String) -> Void
    public let onRevealInFinder: (CodexSessionsRowData) -> Void
    public let onToggleCollapse: (String) -> Void
    public let selectedRowID: String?
    public let onSelectRow: (CodexSessionsRowData) -> Void
    public let onToggleRowExpansion: (CodexSessionsRowData) -> Void
    public let expandedRowID: String?
    public let expandedRowContent: (CodexSessionsRowData) -> ExpandedRowContent

    public init(
        data: CodexSessionsSectionData,
        onTapSectionAction: @escaping (String) -> Void,
        onCopySectionThreadIDs: (() -> Void)? = nil,
        onRevealSectionFolder: (() -> Void)? = nil,
        onTapRowAction: @escaping (CodexSessionsRowData, String) -> Void,
        onRevealInFinder: @escaping (CodexSessionsRowData) -> Void,
        onToggleCollapse: @escaping (String) -> Void = { _ in },
        selectedRowID: String? = nil,
        onSelectRow: @escaping (CodexSessionsRowData) -> Void = { _ in },
        onToggleRowExpansion: @escaping (CodexSessionsRowData) -> Void = { _ in },
        expandedRowID: String? = nil,
        @ViewBuilder expandedRowContent: @escaping (CodexSessionsRowData) -> ExpandedRowContent
    ) {
        self.data = data
        self.onTapSectionAction = onTapSectionAction
        self.onCopySectionThreadIDs = onCopySectionThreadIDs
        self.onRevealSectionFolder = onRevealSectionFolder
        self.onTapRowAction = onTapRowAction
        self.onRevealInFinder = onRevealInFinder
        self.onToggleCollapse = onToggleCollapse
        self.selectedRowID = selectedRowID
        self.onSelectRow = onSelectRow
        self.onToggleRowExpansion = onToggleRowExpansion
        self.expandedRowID = expandedRowID
        self.expandedRowContent = expandedRowContent
    }

    public var body: some View {
        Group {
            if prefersUnifiedSingleRowPresentation {
                adaptiveRowsContainer
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader

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
            }
        }
        .animation(.snappy(duration: 0.2), value: data.isExpanded)
    }

    private var prefersUnifiedSingleRowPresentation: Bool {
        data.rows.count == 1
    }

    private var sectionHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
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
        VStack(alignment: .leading, spacing: 6) {
            Text(data.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(DesignSystem.Colors.Text.primary)
                .lineLimit(1)
                .fixedSize(horizontal: false, vertical: true)

            if let subtitleRailText = sectionSubtitleRailText {
                if let sectionHeaderHelpText, !sectionHeaderHelpText.isEmpty {
                    subtitleRailText
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .help(sectionHeaderHelpText)
                } else {
                    subtitleRailText
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
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

            if hasSectionMenu {
                EllipsisMenuButton {
                    if !data.actions.isEmpty {
                        Menu {
                            ForEach(data.actions) { action in
                                Button(action.menuLabelText) {
                                    onTapSectionAction(action.targetProviderID)
                                }
                            }
                        } label: {
                            Label(
                                data.actionMenuTitle ?? NSLocalizedString(
                                    "codex.sessions.action.move",
                                    value: "Move",
                                    comment: "Move action label"
                                ),
                                systemImage: "arrow.right.circle"
                            )
                        }
                    }

                    if !data.actions.isEmpty, hasSectionUtilityActions || data.shareData != nil {
                        Divider()
                    }

                    if let onCopySectionThreadIDs {
                        Button {
                            onCopySectionThreadIDs()
                        } label: {
                            Label(
                                NSLocalizedString(
                                    "codex.sessions.group.action.copy_thread_ids",
                                    value: "Copy All Thread IDs",
                                    comment: "Copy all thread IDs in a session group"
                                ),
                                systemImage: "doc.on.doc"
                            )
                        }
                    }

                    if hasSectionUtilityActions, data.shareData != nil {
                        Divider()
                    }

                    if let shareData = data.shareData {
                        ShareLink(
                            item: shareData.item,
                            subject: Text(shareData.title)
                        ) {
                            Label(
                                NSLocalizedString(
                                    "codex.sessions.group.action.share",
                                    value: "Share Group",
                                    comment: "Share session group"
                                ),
                                systemImage: "square.and.arrow.up"
                            )
                        }
                    }
                }
                .help(sectionMenuHelpText)
            }
        }
    }

    private var isExpandable: Bool {
        guard let expansionTitle = data.expansionTitle else { return false }
        return !expansionTitle.isEmpty
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
                if expandedRowID == row.id {
                    expandedRowView(row)
                }
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
        .background(rowBackground(isSelected: selectedRowID == row.id))
        .contentShape(RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusS, style: .continuous))
        .onTapGesture {
            onSelectRow(row)
        }
        .contextMenu {
            rowContextMenu(row)
        }
    }

    private func compactRowView(_ row: CodexSessionsRowData) -> some View {
        VStack(alignment: .leading, spacing: 0) {
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
            .contentShape(RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusS, style: .continuous))
            .onTapGesture {
                onToggleRowExpansion(row)
            }
            .contextMenu {
                rowContextMenu(row)
            }

            if expandedRowID == row.id {
                Rectangle()
                    .fill(DesignSystem.Colors.Component.border.opacity(0.12))
                    .frame(height: 1)
                    .padding(.horizontal, 14)

                expandedRowView(row)
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, 12)
            }
        }
        .background(rowBackground(isSelected: selectedRowID == row.id))
    }

    private func expandedRowView(_ row: CodexSessionsRowData) -> some View {
        expandedRowContent(row)
            .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func compactRowContent(
        _ row: CodexSessionsRowData,
        usage: CodexSessionsUsageDisplayData
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                compactTitleLine(row)
                    .fixedSize(horizontal: false, vertical: true)

                compactRowSubtitle(row, usage: usage)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            rowMenuButton(row)
                .padding(.top, 2)
        }
    }

    private func compactTitleLine(_ row: CodexSessionsRowData) -> some View {
        compactTitleText(row)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func compactTitleText(_ row: CodexSessionsRowData) -> Text {
        Text(row.title)
            .font(.body.weight(.medium))
            .foregroundColor(DesignSystem.Colors.Text.primary)
    }

    private func compactRowSubtitle(
        _ row: CodexSessionsRowData,
        usage: CodexSessionsUsageDisplayData
    ) -> some View {
        compactRowSubtitleText(row, usage: usage)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func compactRowSubtitleText(
        _ row: CodexSessionsRowData,
        usage: CodexSessionsUsageDisplayData
    ) -> Text {
        var items = [compactStatusSubtitleText(for: row)]

        if !row.isEditable, let readOnlyText = row.readOnlyText, !readOnlyText.isEmpty {
            items.append(
                Text(readOnlyText)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.Status.warning)
            )
        }

        if showsProviderColumn, !row.providerText.isEmpty {
            items.append(
                Text(row.providerText)
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.Text.secondary)
            )
        }

        items.append(contentsOf: compactUsageSubtitleTexts(usage))
        items.append(
            Text(row.timeText)
                .font(.caption.monospaced())
                .foregroundColor(DesignSystem.Colors.Text.secondary)
        )

        return compactJoinedSubtitleText(items)
    }

    private func compactStatusSubtitleText(for row: CodexSessionsRowData) -> Text {
        let label = row.isArchived
            ? NSLocalizedString(
                "codex.sessions.badge.archived",
                value: "Archived",
                comment: "Archived badge"
            )
            : NSLocalizedString(
                "codex.sessions.badge.live",
                value: "Live",
                comment: "Live badge"
            )
        let tint = row.isArchived ? DesignSystem.Colors.Text.secondary : DesignSystem.Colors.Status.success

        return Text(label)
            .font(.caption.weight(.semibold))
            .foregroundColor(tint)
    }

    private func compactUsageSubtitleTexts(_ usage: CodexSessionsUsageDisplayData) -> [Text] {
        switch usage {
        case .placeholder:
            return []
        case .failed(let text):
            return [
                Text(text)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.Status.warning),
            ]
        case .value(let primaryText, let secondaryText):
            var items = [
                Text(primaryText)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.Text.secondary),
            ]

            if let secondaryText, !secondaryText.isEmpty {
                let secondaryItems = secondaryText
                    .split(separator: "·")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .map {
                        Text($0)
                            .font(.caption2.monospaced())
                            .foregroundColor(DesignSystem.Colors.Text.tertiary)
                    }
                items.append(contentsOf: secondaryItems)
            }

            return items
        }
    }

    private func compactJoinedSubtitleText(_ items: [Text]) -> Text {
        guard let first = items.first else { return Text("") }

        let separator = Text(" · ")
            .font(.caption)
            .foregroundColor(DesignSystem.Colors.Text.tertiary)

        return items.dropFirst().reduce(first) { partialResult, item in
            partialResult + separator + item
        }
    }

    private func nameColumnView(
        _ row: CodexSessionsRowData,
        summaryLineLimit: Int,
        metadataSpacing: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(row.title)
                .font(.body.weight(.medium))
                .foregroundStyle(DesignSystem.Colors.Text.primary)
                .fixedSize(horizontal: false, vertical: true)
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
            if let secondaryText, !secondaryText.isEmpty {
                Text(secondaryText)
                    .font(monospaced ? .caption2.monospaced() : .caption2)
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                    .lineLimit(1)
            }
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

    private var hasSectionMenu: Bool {
        !data.actions.isEmpty || hasSectionUtilityActions || data.shareData != nil
    }

    private var sectionMenuHelpText: String {
        if let actionMenuTitle = data.actionMenuTitle,
           !actionMenuTitle.isEmpty,
           !hasSectionUtilityActions,
           data.shareData == nil {
            return actionMenuTitle
        }
        return NSLocalizedString(
            "codex.sessions.group.action.menu.help",
            value: "Group actions",
            comment: "Group actions menu help text"
        )
    }

    private var hasSectionUtilityActions: Bool {
        onCopySectionThreadIDs != nil
    }

    private var sectionSubtitleRailText: Text? {
        let items = sectionSubtitleItems()
        guard !items.isEmpty else { return nil }
        return joinedSectionSubtitleText(items)
    }

    private var sectionHeaderHelpText: String? {
        if let subtitle = data.subtitle, !subtitle.isEmpty {
            return subtitle
        }
        return nil
    }

    private func sectionSubtitleItems() -> [Text] {
        var items: [Text] = []

        if let usage = data.usage {
            items.append(contentsOf: sectionUsageSubtitleTexts(usage))
        }

        items.append(
            contentsOf: data.badges.map {
                Text($0.text)
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.Text.secondary)
            }
        )

        if let secondaryStatusSummary, !secondaryStatusSummary.isEmpty {
            items.append(
                Text(secondaryStatusSummary)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.Text.tertiary)
            )
        }

        if let titleSecondaryText = data.titleSecondaryText, !titleSecondaryText.isEmpty {
            items.append(
                Text(titleSecondaryText)
                    .font(.caption.monospaced())
                    .foregroundColor(DesignSystem.Colors.Text.tertiary)
            )
        }

        return items
    }

    private func sectionUsageSubtitleTexts(_ usage: CodexSessionsUsageDisplayData) -> [Text] {
        switch usage {
        case .placeholder(let text):
            return [
                Text(text)
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.Text.tertiary),
            ]
        case .failed(let text):
            return [
                Text(text)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.Status.warning),
            ]
        case .value(let primaryText, let secondaryText):
            var items = [
                Text(primaryText)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.Text.secondary),
            ]

            if let secondaryText, !secondaryText.isEmpty {
                items.append(
                    contentsOf: secondaryText
                        .split(separator: "·")
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                        .map {
                            Text($0)
                                .font(.caption2.monospaced())
                                .foregroundColor(DesignSystem.Colors.Text.tertiary)
                        }
                )
            }

            return items
        }
    }

    private func joinedSectionSubtitleText(_ items: [Text]) -> Text {
        guard let first = items.first else { return Text("") }

        let separator = Text(" · ")
            .font(.caption)
            .foregroundColor(DesignSystem.Colors.Text.tertiary)

        return items.dropFirst().reduce(first) { partialResult, item in
            partialResult + separator + item
        }
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

        static var regular: TableLayout {
            TableLayout(
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
        }

        static var medium: TableLayout {
            TableLayout(
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
    }

    private func copyToPasteboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}

public extension CodexSessionsSectionCardView where ExpandedRowContent == EmptyView {
    init(
        data: CodexSessionsSectionData,
        onTapSectionAction: @escaping (String) -> Void,
        onTapRowAction: @escaping (CodexSessionsRowData, String) -> Void,
        onRevealInFinder: @escaping (CodexSessionsRowData) -> Void,
        onToggleCollapse: @escaping (String) -> Void = { _ in },
        selectedRowID: String? = nil,
        onSelectRow: @escaping (CodexSessionsRowData) -> Void = { _ in }
    ) {
        self.init(
            data: data,
            onTapSectionAction: onTapSectionAction,
            onTapRowAction: onTapRowAction,
            onRevealInFinder: onRevealInFinder,
            onToggleCollapse: onToggleCollapse,
            selectedRowID: selectedRowID,
            onSelectRow: onSelectRow,
            expandedRowID: nil
        ) { _ in
            EmptyView()
        }
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
