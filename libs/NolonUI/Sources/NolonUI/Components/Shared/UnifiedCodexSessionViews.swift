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
        VStack(alignment: .leading, spacing: 18) {
            header

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
            }

            statusBanners

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 132), spacing: 12, alignment: .top)],
                alignment: .leading,
                spacing: 12
            ) {
                ForEach(data.metrics) { metric in
                    metricCard(metric)
                }
            }
        }
        .padding(22)
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
            HStack(alignment: .top, spacing: 16) {
                headerLead
                Spacer(minLength: 16)
                headerRefreshButton
            }
            .frame(minWidth: 540, alignment: .leading)

            VStack(alignment: .leading, spacing: 14) {
                headerLead
                headerRefreshButton
            }
        }
    }

    private var headerLead: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.primary.opacity(0.14))
                    .frame(width: 42, height: 42)

                Image(systemName: "arrow.left.arrow.right.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.primary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(data.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.Text.primary)

                Text(data.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var headerRefreshButton: some View {
        Button(action: onRefresh) {
            Label(data.refreshTitle, systemImage: "arrow.clockwise")
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
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
            VStack(alignment: .leading, spacing: 10) {
                ForEach(entries, id: \.id) { entry in
                    statusBanner(
                        message: entry.message,
                        systemImage: entry.systemImage,
                        tint: entry.tint
                    )
                }
            }
        }
    }

    private func metricCard(_ metric: CodexSessionsMetricData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(metric.title)
                .font(.caption.weight(.medium))
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)

            Text(metric.value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(DesignSystem.Colors.Text.primary)
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusM, style: .continuous)
                .fill(DesignSystem.Colors.Background.surface.opacity(0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusM, style: .continuous)
                .stroke(DesignSystem.Colors.Component.border.opacity(0.24), lineWidth: 1)
        )
    }

    private func statusBanner(message: String, systemImage: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .padding(.top, 1)

            Text(message)
                .font(.callout)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusM, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusM, style: .continuous)
                .stroke(tint.opacity(0.16), lineWidth: 1)
        )
    }

    private func bannerEntry(id: String, message: String?, systemImage: String, tint: Color) -> BannerEntry? {
        guard let message, !message.isEmpty else { return nil }
        return BannerEntry(id: id, message: message, systemImage: systemImage, tint: tint)
    }
}

public struct CodexSessionsSectionCardView: View {
    public let data: CodexSessionsSectionData
    public let onTapSectionAction: (String) -> Void
    public let onTapRowAction: (CodexSessionsRowData, String) -> Void
    public let onRevealInFinder: (CodexSessionsRowData) -> Void
    public let onToggleCollapse: (String) -> Void

    public init(
        data: CodexSessionsSectionData,
        onTapSectionAction: @escaping (String) -> Void,
        onTapRowAction: @escaping (CodexSessionsRowData, String) -> Void,
        onRevealInFinder: @escaping (CodexSessionsRowData) -> Void,
        onToggleCollapse: @escaping (String) -> Void = { _ in }
    ) {
        self.data = data
        self.onTapSectionAction = onTapSectionAction
        self.onTapRowAction = onTapRowAction
        self.onRevealInFinder = onRevealInFinder
        self.onToggleCollapse = onToggleCollapse
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader

            if let subtitle = data.subtitle, !subtitle.isEmpty {
                capabilityBanner(subtitle)
            }

            if !data.badges.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(data.badges) { badge in
                        pill(text: badge.text, tint: DesignSystem.Colors.Text.secondary)
                    }
                }
            }

            if !data.rows.isEmpty {
                adaptiveRowsContainer
            }
        }
        .padding(20)
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
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 14) {
                sectionHeaderLead
                Spacer(minLength: 12)
                sectionHeaderActions
            }
            .frame(minWidth: 680, alignment: .leading)

            VStack(alignment: .leading, spacing: 14) {
                sectionHeaderLead
                sectionHeaderActions
            }
        }
    }

    private var sectionHeaderLead: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(sectionAccentColor.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: sectionSymbolName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(sectionAccentColor)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(data.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.Text.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if let titleSecondaryText = data.titleSecondaryText, !titleSecondaryText.isEmpty {
                    Text(titleSecondaryText)
                        .font(.caption.monospaced())
                        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private var sectionHeaderActions: some View {
        HStack(spacing: 8) {
            if let expansionTitle = data.expansionTitle, !expansionTitle.isEmpty {
                Button(action: { onToggleCollapse(data.id) }) {
                    Label(
                        expansionTitle,
                        systemImage: data.isExpanded ? "chevron.up" : "chevron.down"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
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
                    Label(actionMenuTitle, systemImage: "arrow.right.circle")
                }
                .menuStyle(.button)
                .controlSize(.large)
            }
        }
    }

    private func capabilityBanner(_ subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: capabilitySymbolName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(sectionAccentColor)
                .padding(.top, 1)

            Text(subtitle)
                .font(.callout)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(sectionAccentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusM, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusM, style: .continuous)
                .stroke(sectionAccentColor.opacity(0.14), lineWidth: 1)
        )
    }

    private var adaptiveRowsContainer: some View {
        ViewThatFits(in: .horizontal) {
            tableContainer(layout: .regular)
                .frame(minWidth: TableLayout.regular.minimumContentWidth)
            tableContainer(layout: .medium)
                .frame(minWidth: TableLayout.medium.minimumContentWidth)
            compactRowsContainer
        }
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
            Text(NSLocalizedString("codex.sessions.table.provider", value: "Provider", comment: "Session table column header"))
                .frame(width: layout.providerColumnWidth, alignment: .leading)
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

            Text(row.providerText)
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .lineLimit(layout.providerLineLimit)
                .frame(width: layout.providerColumnWidth, alignment: .leading)

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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                nameColumnView(row, summaryLineLimit: 3, metadataSpacing: 6)
                Spacer(minLength: 8)
                rowMenuButton(row)
            }

            FlowLayout(spacing: 6) {
                pill(
                    text: row.isArchived
                        ? NSLocalizedString("codex.sessions.badge.archived", value: "Archived", comment: "Archived badge")
                        : NSLocalizedString("codex.sessions.badge.live", value: "Live", comment: "Live badge"),
                    tint: row.isArchived ? DesignSystem.Colors.Status.warning : DesignSystem.Colors.Status.success
                )
                if !row.isEditable, let readOnlyText = row.readOnlyText, !readOnlyText.isEmpty {
                    pill(text: readOnlyText, tint: DesignSystem.Colors.Status.warning)
                }
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150), spacing: 10, alignment: .top)],
                alignment: .leading,
                spacing: 10
            ) {
                compactDetailCard(
                    title: NSLocalizedString("codex.sessions.table.id", value: "ID", comment: "Session table column header"),
                    primaryText: row.idText,
                    secondaryText: row.idSecondaryText,
                    monospaced: true
                )
                compactDetailCard(
                    title: NSLocalizedString("codex.sessions.table.time", value: "Time", comment: "Session table column header"),
                    primaryText: row.timeText,
                    secondaryText: !row.isEditable ? row.readOnlyText : nil,
                    monospaced: true
                )
                compactDetailCard(
                    title: NSLocalizedString("codex.sessions.table.provider", value: "Provider", comment: "Session table column header"),
                    primaryText: row.providerText,
                    secondaryText: nil
                )
                compactUsageCard(row.usage)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contextMenu {
            rowContextMenu(row)
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
            if let summary = row.summary, !summary.isEmpty {
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
            HStack(spacing: 6) {
                Image(systemName: row.isArchived ? "archivebox.fill" : "circle.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(
                        row.isArchived
                            ? DesignSystem.Colors.Status.warning
                            : DesignSystem.Colors.Status.success
                    )
                Text(
                    row.isArchived
                        ? NSLocalizedString("codex.sessions.badge.archived", value: "Archived", comment: "Archived badge")
                        : NSLocalizedString("codex.sessions.badge.live", value: "Live", comment: "Live badge")
                )
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
            }
        }
    }

    private func timeColumnView(_ row: CodexSessionsRowData) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(row.timeText)
                .font(.caption.monospaced())
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
            if !row.isEditable, let readOnlyText = row.readOnlyText, !readOnlyText.isEmpty {
                pill(text: readOnlyText, tint: DesignSystem.Colors.Status.warning)
            }
        }
    }

    private func compactDetailCard(
        title: String,
        primaryText: String,
        secondaryText: String?,
        monospaced: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
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
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusS, style: .continuous)
                .fill(DesignSystem.Colors.Background.surface.opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusS, style: .continuous)
                .stroke(DesignSystem.Colors.Component.border.opacity(0.16), lineWidth: 1)
        )
    }

    private func compactUsageCard(_ usage: CodexSessionsUsageDisplayData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(NSLocalizedString("codex.sessions.table.usage", value: "Usage", comment: "Session table column header"))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
            usageView(usage)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusS, style: .continuous)
                .fill(DesignSystem.Colors.Background.surface.opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusS, style: .continuous)
                .stroke(DesignSystem.Colors.Component.border.opacity(0.16), lineWidth: 1)
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

    private var capabilitySymbolName: String {
        switch data.presentationKind {
        case .rewritableGroup:
            return "sparkles"
        case .singleSessionOnly:
            return "info.circle.fill"
        case .readOnly:
            return "exclamationmark.triangle.fill"
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
            summaryLineLimit: 2,
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
            summaryLineLimit: 2,
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
