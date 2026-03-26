import SwiftUI
import NolonUIFoundation

public struct AccountListModeUsageWindow: Identifiable {
    public let id: String
    public let title: String
    public let progress: CGFloat
    public let percentText: String

    public init(id: String, title: String, progress: CGFloat, percentText: String) {
        self.id = id
        self.title = title
        self.progress = progress
        self.percentText = percentText
    }

    public init(title: String, progress: CGFloat, percentText: String) {
        self.id = UUID().uuidString
        self.title = title
        self.progress = progress
        self.percentText = percentText
    }
}

public struct AccountListModeRowAction: Identifiable {
    public let id: String
    public let title: String
    public let systemImage: String?
    public let role: ButtonRole?
    public let isEnabled: Bool

    public init(
        id: String,
        title: String,
        systemImage: String? = nil,
        role: ButtonRole? = nil,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.isEnabled = isEnabled
    }
}

public struct AccountListModeItem: Identifiable {
    public let id: String
    public let presentation: AccountCardPresentation
    public let header: AccountSummaryCardHeaderModel
    public let usageWindows: [AccountListModeUsageWindow]
    public let menuActions: [AccountListModeRowAction]
    public let isLoadingPlaceholder: Bool

    public init(
        id: String,
        presentation: AccountCardPresentation,
        header: AccountSummaryCardHeaderModel,
        usageWindows: [AccountListModeUsageWindow],
        menuActions: [AccountListModeRowAction] = [],
        isLoadingPlaceholder: Bool = false
    ) {
        self.id = id
        self.presentation = presentation
        self.header = header
        self.usageWindows = usageWindows
        self.menuActions = menuActions
        self.isLoadingPlaceholder = isLoadingPlaceholder
    }

    public init(
        presentation: AccountCardPresentation,
        header: AccountSummaryCardHeaderModel,
        usageWindows: [AccountListModeUsageWindow],
        menuActions: [AccountListModeRowAction] = [],
        isLoadingPlaceholder: Bool = false
    ) {
        self.init(
            id: UUID().uuidString,
            presentation: presentation,
            header: header,
            usageWindows: usageWindows,
            menuActions: menuActions,
            isLoadingPlaceholder: isLoadingPlaceholder
        )
    }

    public init(
        id: String,
        presentation: AccountCardPresentation,
        header: AccountSummaryCardHeaderModel,
        progress: CGFloat,
        percentText: String,
        menuActions: [AccountListModeRowAction] = [],
        isLoadingPlaceholder: Bool = false
    ) {
        self.init(
            id: id,
            presentation: presentation,
            header: header,
            usageWindows: [.init(title: "Session", progress: progress, percentText: percentText)],
            menuActions: menuActions,
            isLoadingPlaceholder: isLoadingPlaceholder
        )
    }

    public init(
        presentation: AccountCardPresentation,
        header: AccountSummaryCardHeaderModel,
        progress: CGFloat,
        percentText: String,
        menuActions: [AccountListModeRowAction] = [],
        isLoadingPlaceholder: Bool = false
    ) {
        self.init(
            id: UUID().uuidString,
            presentation: presentation,
            header: header,
            progress: progress,
            percentText: percentText,
            menuActions: menuActions,
            isLoadingPlaceholder: isLoadingPlaceholder
        )
    }
}

public struct AccountListModeSection: Identifiable {
    public let id: String
    public let title: String?
    public let items: [AccountListModeItem]

    public init(id: String = UUID().uuidString, title: String? = nil, items: [AccountListModeItem]) {
        self.id = id
        self.title = title
        self.items = items
    }
}

public struct AccountListModeModule: View {
    @State private var viewModel = AccountListModeModuleViewModel()
    let title: String?
    let sections: [AccountListModeSection]
    let accountColumnTitle: String
    let planColumnTitle: String
    let usageColumnTitle: String
    let planColumnWidth: CGFloat
    let usageColumnWidth: CGFloat
    let onTap: ((String) -> Void)?
    let onMenuAction: ((String, String) -> Void)?

    public init(
        title: String? = nil,
        items: [AccountListModeItem]
    ) {
        self.title = title
        self.sections = [.init(items: items)]
        self.accountColumnTitle = "Account"
        self.planColumnTitle = "Plan"
        self.usageColumnTitle = "Usage"
        self.planColumnWidth = 90
        self.usageColumnWidth = 220
        self.onTap = nil
        self.onMenuAction = nil
    }

    public init(
        title: String? = nil,
        sections: [AccountListModeSection],
        accountColumnTitle: String = "Account",
        planColumnTitle: String = "Plan",
        usageColumnTitle: String = "Usage",
        planColumnWidth: CGFloat = 90,
        usageColumnWidth: CGFloat = 220,
        onTap: ((String) -> Void)? = nil,
        onMenuAction: ((String, String) -> Void)? = nil
    ) {
        self.title = title
        self.sections = sections
        self.accountColumnTitle = accountColumnTitle
        self.planColumnTitle = planColumnTitle
        self.usageColumnTitle = usageColumnTitle
        self.planColumnWidth = planColumnWidth
        self.usageColumnWidth = usageColumnWidth
        self.onTap = onTap
        self.onMenuAction = onMenuAction
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PreviewLayoutTokens.Spacing.group) {
            if let title, !title.isEmpty {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
            }

            VStack(alignment: .leading, spacing: 0) {
                tableHeader

                ForEach(Array(sections.enumerated()), id: \.element.id) { sectionIndex, section in
                    if let title = section.title, !title.isEmpty {
                        Text(title)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                            .padding(.top, sectionIndex == 0 ? 0 : PreviewLayoutTokens.Spacing.row)
                            .padding(.bottom, 4)
                    }

                    ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                        tableRow(item)
                            .redacted(reason: item.isLoadingPlaceholder ? .placeholder : [])

                        if index < section.items.count - 1 {
                            Divider()
                                .overlay(DesignSystem.Colors.Component.border.opacity(0.25))
                        }
                    }
                }
            }
            .padding(.horizontal, PreviewLayoutTokens.Spacing.group)
            .padding(.vertical, PreviewLayoutTokens.Spacing.row)
            .background(DesignSystem.Colors.Background.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusL, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusL, style: .continuous)
                    .stroke(DesignSystem.Colors.Component.border.opacity(0.3), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tableHeader: some View {
        HStack(spacing: PreviewLayoutTokens.Spacing.group) {
            Text(accountColumnTitle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(planColumnTitle)
                .frame(width: planColumnWidth, alignment: .leading)
            Text(usageColumnTitle)
                .frame(width: usageColumnWidth, alignment: .leading)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
        .padding(.vertical, PreviewLayoutTokens.Spacing.row)
    }

    @ViewBuilder
    private func tableRow(_ item: AccountListModeItem) -> some View {
        let row = HStack(spacing: PreviewLayoutTokens.Spacing.group) {
            HStack(alignment: .top, spacing: 8) {
                Circle()
                    .fill(statusColor(for: item))
                    .frame(width: 6, height: 6)
                    .padding(.top, 3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.header.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DesignSystem.Colors.Text.primary)
                        .lineLimit(1)
                    if let secondary = accountSecondaryText(for: item) {
                        Text(secondary)
                            .font(.caption2)
                            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(planText(for: item))
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .lineLimit(1)
                .frame(width: planColumnWidth, alignment: .leading)

            usageWindowsColumn(item.usageWindows)
                .frame(width: usageColumnWidth, alignment: .leading)
        }
        .padding(.vertical, 10)

        if let onTap {
            if item.menuActions.isEmpty {
                row
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onTap(item.id)
                    }
            } else {
                row
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onTap(item.id)
                    }
                    .contextMenu {
                        ForEach(item.menuActions) { action in
                            Button(role: action.role) {
                                onMenuAction?(item.id, action.id)
                            } label: {
                                if let symbol = action.systemImage, !symbol.isEmpty {
                                    Label(action.title, systemImage: symbol)
                                } else {
                                    Text(action.title)
                                }
                            }
                            .disabled(!action.isEnabled)
                        }
                    }
            }
        } else if item.menuActions.isEmpty {
            row
        } else {
            row.contextMenu {
                ForEach(item.menuActions) { action in
                    Button(role: action.role) {
                        onMenuAction?(item.id, action.id)
                    } label: {
                        if let symbol = action.systemImage, !symbol.isEmpty {
                            Label(action.title, systemImage: symbol)
                        } else {
                            Text(action.title)
                        }
                    }
                    .disabled(!action.isEnabled)
                }
            }
        }
    }

    private func usageWindowsColumn(_ windows: [AccountListModeUsageWindow]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(windows) { window in
                HStack(spacing: 6) {
                    Text(window.title)
                        .font(.caption2)
                        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                        .frame(width: 46, alignment: .leading)
                    AccountInlineQuotaProgress(progress: window.progress, percentText: window.percentText)
                }
            }
        }
    }

    private func accountSecondaryText(for item: AccountListModeItem) -> String? {
        let eyebrow = item.header.eyebrow?.trimmingCharacters(in: .whitespacesAndNewlines)
        let meta = item.header.meta?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let eyebrow, !eyebrow.isEmpty, let meta, !meta.isEmpty {
            return "\(eyebrow) • \(meta)"
        }
        if let eyebrow, !eyebrow.isEmpty {
            return eyebrow
        }
        if let meta, !meta.isEmpty {
            return meta
        }
        return nil
    }

    private func planText(for item: AccountListModeItem) -> String {
        let raw = item.header.subtitle ?? "-"
        let normalized = raw.split(separator: "•").first?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (normalized?.isEmpty == false) ? normalized! : "-"
    }

    private func statusColor(for item: AccountListModeItem) -> Color {
        if let badge = item.header.badge {
            switch badge.tone {
            case .active:
                return DesignSystem.Colors.primary
            case .warning:
                return DesignSystem.Colors.Status.warning
            case .neutral:
                return DesignSystem.Colors.Text.secondary
            }
        }
        switch item.presentation.selectionStyle {
        case .active:
            return DesignSystem.Colors.primary
        case .pending:
            return DesignSystem.Colors.Status.warning
        case .selected:
            return DesignSystem.Colors.primary
        case .neutral:
            return DesignSystem.Colors.Text.secondary
        }
    }
}
