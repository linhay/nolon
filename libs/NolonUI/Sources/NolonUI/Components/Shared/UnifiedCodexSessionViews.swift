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
        HStack(alignment: .top, spacing: 16) {
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

            Spacer(minLength: 16)

            Button(action: onRefresh) {
                Label(data.refreshTitle, systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(data.isRefreshDisabled)
        }
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
            bannerEntry(
                id: "pagination",
                message: data.paginationMessage,
                systemImage: "line.3.horizontal.decrease.circle.fill",
                tint: DesignSystem.Colors.Text.secondary
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

            if !data.isCollapsed && !data.rows.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    tableHeader
                    Divider()
                        .overlay(DesignSystem.Colors.Component.border.opacity(0.3))
                    ForEach(Array(data.rows.enumerated()), id: \.element.id) { index, row in
                        tableRowView(row)
                        if index < data.rows.count - 1 {
                            Divider()
                                .overlay(DesignSystem.Colors.Component.border.opacity(0.15))
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusM, style: .continuous)
                        .fill(DesignSystem.Colors.Background.surface.opacity(0.5))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusM, style: .continuous)
                        .stroke(DesignSystem.Colors.Component.border.opacity(0.2), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusM, style: .continuous))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCard(
            background: DesignSystem.Colors.Background.elevated.opacity(0.94),
            cornerRadius: DesignSystem.Metrics.cornerRadiusL,
            borderColor: data.actions.isEmpty
                ? DesignSystem.Colors.Component.border.opacity(0.28)
                : DesignSystem.Colors.primary.opacity(0.24),
            shadow: .subtle
        )
        .animation(.snappy(duration: 0.2), value: data.isCollapsed)
    }

    private var sectionHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            Button {
                onToggleCollapse(data.id)
            } label: {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                        .padding(.top, 16)
                        .rotationEffect(.degrees(data.isCollapsed ? 0 : 90))

                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(sectionAccentColor.opacity(0.12))
                            .frame(width: 44, height: 44)

                        Image(systemName: data.actions.isEmpty ? "square.stack.3d.down.forward" : "arrow.left.arrow.right.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(sectionAccentColor)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(data.title)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(DesignSystem.Colors.Text.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                data.isCollapsed
                    ? NSLocalizedString(
                        "codex.sessions.section.expand",
                        value: "Expand Group",
                        comment: "Expand sessions group"
                    )
                    : NSLocalizedString(
                        "codex.sessions.section.collapse",
                        value: "Collapse Group",
                        comment: "Collapse sessions group"
                    )
            )

            Spacer(minLength: 12)

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
            Image(systemName: data.actions.isEmpty ? "info.circle.fill" : "sparkles")
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

    private var tableHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(NSLocalizedString("codex.sessions.table.session", value: "Session", comment: "Session table column header"))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(NSLocalizedString("codex.sessions.table.status", value: "Status", comment: "Status table column header"))
                .frame(width: 110, alignment: .leading)
            Text(NSLocalizedString("codex.sessions.table.context", value: "Context", comment: "Context table column header"))
                .frame(width: 150, alignment: .leading)
            Text(NSLocalizedString("codex.sessions.table.path", value: "Path", comment: "Path table column header"))
                .frame(width: 180, alignment: .leading)
            Text(NSLocalizedString("codex.sessions.table.actions", value: "Actions", comment: "Actions table column header"))
                .frame(width: 110, alignment: .trailing)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(DesignSystem.Colors.Background.surface.opacity(0.7))
    }

    private func tableRowView(_ row: CodexSessionsRowData) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Session column
            VStack(alignment: .leading, spacing: 3) {
                Text(row.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(DesignSystem.Colors.Text.primary)
                    .lineLimit(2)
                if let summary = row.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Status column
            VStack(alignment: .leading, spacing: 4) {
                pill(
                    text: row.isArchived
                        ? NSLocalizedString("codex.sessions.badge.archived", value: "Archived", comment: "Archived badge")
                        : NSLocalizedString("codex.sessions.badge.live", value: "Live", comment: "Live badge"),
                    tint: row.isArchived ? DesignSystem.Colors.Status.warning : DesignSystem.Colors.Status.success
                )
                if let providerName = row.providerName, !providerName.isEmpty {
                    pill(text: providerName, tint: DesignSystem.Colors.primary)
                }
                if let dbBadge = row.badges.first(where: { $0.id == "db" }) {
                    pill(text: dbBadge.text, tint: DesignSystem.Colors.Text.secondary)
                }
                if !row.isEditable, let readOnlyText = row.readOnlyText, !readOnlyText.isEmpty {
                    pill(text: readOnlyText, tint: DesignSystem.Colors.Status.warning)
                }
            }
            .frame(width: 110, alignment: .leading)

            // Context column
            VStack(alignment: .leading, spacing: 4) {
                ForEach(row.metadataItems) { item in
                    HStack(spacing: 5) {
                        Image(systemName: item.icon)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                        Group {
                            switch item.style {
                            case .regular:
                                Text(item.text).font(.caption)
                            case .code:
                                Text(item.text).font(.caption.monospaced())
                            }
                        }
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                        .lineLimit(1)
                    }
                }
            }
            .frame(width: 150, alignment: .leading)

            // Path column
            HStack(spacing: 5) {
                Image(systemName: "doc.text")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                Text(row.rolloutPath)
                    .font(.caption.monospaced())
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                    .lineLimit(2)
            }
            .frame(width: 180, alignment: .leading)

            // Actions column
            HStack {
                Spacer(minLength: 0)
                if row.actions.isEmpty {
                    if let showInFinderTitle = row.showInFinderTitle, !showInFinderTitle.isEmpty {
                        Button {
                            onRevealInFinder(row)
                        } label: {
                            Image(systemName: "folder")
                        }
                        .buttonStyle(.bordered)
                        .help(showInFinderTitle)
                    }
                } else if let actionMenuTitle = row.actionMenuTitle, !actionMenuTitle.isEmpty {
                    Menu {
                        if let showInFinderTitle = row.showInFinderTitle, !showInFinderTitle.isEmpty {
                            Button(showInFinderTitle) {
                                onRevealInFinder(row)
                            }
                        }
                        if row.showsRevealInFinder {
                            Divider()
                        }
                        ForEach(row.actions) { action in
                            Button(action.title) {
                                onTapRowAction(row, action.targetProviderID)
                            }
                        }
                    } label: {
                        Label(actionMenuTitle, systemImage: "arrow.triangle.swap")
                    }
                    .menuStyle(.button)
                }
            }
            .frame(width: 110)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
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
        data.actions.isEmpty ? DesignSystem.Colors.Status.warning : DesignSystem.Colors.primary
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
