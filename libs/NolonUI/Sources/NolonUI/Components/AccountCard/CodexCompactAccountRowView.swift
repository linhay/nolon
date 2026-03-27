import SwiftUI

public struct CodexCompactUsageWindowDisplay: Identifiable {
    public let id: String
    public let title: String
    public let remainingPercent: Double

    public init(id: String, title: String, remainingPercent: Double) {
        self.id = id
        self.title = title
        self.remainingPercent = remainingPercent
    }
}

public struct CodexCompactMenuAction: Identifiable {
    public let id: String
    public let title: String
    public let systemImage: String?
    public let role: ButtonRole?
    public let isEnabled: Bool

    public init(id: String, title: String, systemImage: String?, role: ButtonRole?, isEnabled: Bool) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.isEnabled = isEnabled
    }
}

public enum CodexCompactStatusTone {
    case neutral
    case primary
    case warning
}

public struct CodexCompactAccountsTableHeaderView: View {
    let accountTitle: String
    let planTitle: String
    let usageTitle: String
    let planColumnWidth: CGFloat
    let usageColumnWidth: CGFloat

    public init(
        accountTitle: String = NSLocalizedString("codex.accounts.list.header.account", value: "Account", comment: "Codex account list table account column"),
        planTitle: String = NSLocalizedString("codex.accounts.list.header.plan", value: "Plan", comment: "Codex account list table plan column"),
        usageTitle: String = NSLocalizedString("codex.accounts.list.header.usage", value: "Usage", comment: "Codex account list table usage column"),
        planColumnWidth: CGFloat,
        usageColumnWidth: CGFloat
    ) {
        self.accountTitle = accountTitle
        self.planTitle = planTitle
        self.usageTitle = usageTitle
        self.planColumnWidth = planColumnWidth
        self.usageColumnWidth = usageColumnWidth
    }

    public var body: some View {
        HStack(spacing: 12) {
            Text(accountTitle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(planTitle)
                .frame(width: planColumnWidth, alignment: .leading)
            Text(usageTitle)
                .frame(width: usageColumnWidth, alignment: .leading)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
        .padding(.vertical, 8)
    }
}

public struct CodexCompactAccountRowView: View {
    let statusTone: CodexCompactStatusTone
    let title: String
    let secondaryText: String?
    let planText: String
    let usageWindows: [CodexCompactUsageWindowDisplay]
    let planColumnWidth: CGFloat
    let usageColumnWidth: CGFloat
    let isSelected: Bool
    let menuActions: [CodexCompactMenuAction]
    let onMenuAction: (String) -> Void

    public init(
        statusTone: CodexCompactStatusTone,
        title: String,
        secondaryText: String?,
        planText: String,
        usageWindows: [CodexCompactUsageWindowDisplay],
        planColumnWidth: CGFloat,
        usageColumnWidth: CGFloat,
        isSelected: Bool,
        menuActions: [CodexCompactMenuAction],
        onMenuAction: @escaping (String) -> Void
    ) {
        self.statusTone = statusTone
        self.title = title
        self.secondaryText = secondaryText
        self.planText = planText
        self.usageWindows = usageWindows
        self.planColumnWidth = planColumnWidth
        self.usageColumnWidth = usageColumnWidth
        self.isSelected = isSelected
        self.menuActions = menuActions
        self.onMenuAction = onMenuAction
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                    .padding(.top, 3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.Text.primary)
                        .lineLimit(1)

                    if let secondaryText, !secondaryText.isEmpty {
                        Text(secondaryText)
                            .font(.caption2)
                            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(planText)
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .lineLimit(1)
                .frame(width: planColumnWidth, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(usageWindows) { window in
                    HStack(spacing: 6) {
                        Text(window.title)
                            .font(.caption2)
                            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                            .frame(width: 46, alignment: .leading)
                        usageProgressBar(remainingPercent: window.remainingPercent)
                    }
                }
            }
            .frame(width: usageColumnWidth, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(isSelected ? DesignSystem.Colors.primary.opacity(0.12) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .contextMenu {
            ForEach(menuActions) { action in
                Button(role: action.role) {
                    onMenuAction(action.id)
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

    private var statusColor: Color {
        switch statusTone {
        case .neutral:
            return DesignSystem.Colors.Text.secondary
        case .primary:
            return DesignSystem.Colors.primary
        case .warning:
            return DesignSystem.Colors.Status.warning
        }
    }

    private func usageProgressBar(remainingPercent: Double) -> some View {
        let normalized = max(0, min(100, remainingPercent.isInfinite ? 100 : remainingPercent))
        let progress = normalized / 100
        let color = quotaColor(for: remainingPercent)
        return HStack(spacing: 8) {
            GeometryReader { proxy in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(DesignSystem.Colors.Component.controlFill)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(color.opacity(0.22))
                            .frame(width: proxy.size.width * progress)
                    }
            }
            .frame(height: 8)

            Text(remainingPercent.isInfinite ? "∞" : String(format: "%.0f%%", normalized))
                .font(.caption2.weight(.bold))
                .foregroundStyle(color)
        }
    }

    private func quotaColor(for remainingPercent: Double) -> Color {
        if remainingPercent.isInfinite { return DesignSystem.Colors.Status.success }
        if remainingPercent < 10 { return DesignSystem.Colors.Status.error }
        if remainingPercent < 25 { return DesignSystem.Colors.Status.warning }
        return DesignSystem.Colors.primary
    }
}
