import SwiftUI

enum AccountCardSelectionStyle: Equatable, Sendable {
    case neutral
    case active
    case pending
    case selected
}

struct AccountCardPresentation: Equatable, Sendable {
    let selectionStyle: AccountCardSelectionStyle
    let showsSelectionBadge: Bool

    static let neutral = AccountCardPresentation(
        selectionStyle: .neutral,
        showsSelectionBadge: false
    )

    static func claude(isActive: Bool) -> AccountCardPresentation {
        AccountCardPresentation(
            selectionStyle: isActive ? .active : .neutral,
            showsSelectionBadge: false
        )
    }

    static func codex(
        isActive: Bool,
        isPending: Bool,
        isBatchSelected: Bool
    ) -> AccountCardPresentation {
        if isActive {
            return AccountCardPresentation(selectionStyle: .active, showsSelectionBadge: false)
        }
        if isPending {
            return AccountCardPresentation(selectionStyle: .pending, showsSelectionBadge: false)
        }
        if isBatchSelected {
            return AccountCardPresentation(selectionStyle: .selected, showsSelectionBadge: true)
        }
        return .neutral
    }
}

struct AccountSummaryCard<Content: View>: View {
    let presentation: AccountCardPresentation
    let contentInsets: EdgeInsets
    @ViewBuilder let content: Content

    init(
        presentation: AccountCardPresentation = .neutral,
        contentInsets: EdgeInsets = EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12),
        @ViewBuilder content: () -> Content
    ) {
        self.presentation = presentation
        self.contentInsets = contentInsets
        self.content = content()
    }

    var body: some View {
        content
            .padding(contentInsets)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(backgroundShape)
            .overlay(borderShape)
            .overlay(alignment: .topTrailing) {
                if presentation.showsSelectionBadge {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(DesignSystem.Colors.primary)
                        .padding(10)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusL, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusL, style: .continuous))
    }

    private var backgroundShape: some View {
        RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusL, style: .continuous)
            .fill(backgroundColor)
    }

    private var borderShape: some View {
        RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusL, style: .continuous)
            .strokeBorder(borderColor, style: borderStyle)
    }

    private var backgroundColor: Color {
        switch presentation.selectionStyle {
        case .neutral:
            return DesignSystem.Colors.Background.elevated
        case .active:
            return DesignSystem.Colors.primary.opacity(0.16)
        case .pending:
            return DesignSystem.Colors.primary.opacity(0.1)
        case .selected:
            return DesignSystem.Colors.primary.opacity(0.14)
        }
    }

    private var borderColor: Color {
        switch presentation.selectionStyle {
        case .neutral:
            return DesignSystem.Colors.Component.border.opacity(0.6)
        case .active, .pending, .selected:
            return DesignSystem.Colors.primary
        }
    }

    private var borderStyle: StrokeStyle {
        StrokeStyle(
            lineWidth: presentation.selectionStyle == .neutral ? 1 : 2,
            dash: presentation.selectionStyle == .pending ? [6, 4] : []
        )
    }
}

enum AccountSummaryCardBadgeTone {
    case neutral
    case active
    case warning
}

struct AccountSummaryCardBadgeModel {
    let text: String
    let tone: AccountSummaryCardBadgeTone
}

struct AccountSummaryCardHeaderModel {
    let eyebrow: String?
    let title: String
    let subtitle: String?
    let meta: String?
    let badge: AccountSummaryCardBadgeModel?
}

struct AccountSummaryContentCard<Body: View, Details: View, Actions: View>: View {
    let presentation: AccountCardPresentation
    let header: AccountSummaryCardHeaderModel
    let showsDetailsSection: Bool
    let showsActionsSection: Bool
    @ViewBuilder let bodyContent: Body
    @ViewBuilder let detailsContent: Details
    @ViewBuilder let actionsContent: Actions

    init(
        presentation: AccountCardPresentation = .neutral,
        header: AccountSummaryCardHeaderModel,
        showsDetailsSection: Bool = false,
        showsActionsSection: Bool = false,
        @ViewBuilder body: () -> Body,
        @ViewBuilder details: () -> Details = { EmptyView() },
        @ViewBuilder actions: () -> Actions = { EmptyView() }
    ) {
        self.presentation = presentation
        self.header = header
        self.showsDetailsSection = showsDetailsSection
        self.showsActionsSection = showsActionsSection
        self.bodyContent = body()
        self.detailsContent = details()
        self.actionsContent = actions()
    }

    var body: some View {
        AccountSummaryCard(presentation: presentation) {
            VStack(alignment: .leading, spacing: 12) {
                headerSection
                bodyContent

                if showsDetailsSection {
                    sectionDivider
                    detailsContent
                }

                if showsActionsSection {
                    sectionDivider
                    actionsContent
                }
            }
        }
    }

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                if let eyebrow = header.eyebrow, !eyebrow.isEmpty {
                    Text(eyebrow)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                        .textCase(.uppercase)
                }

                Text(header.title)
                    .font(.headline)
                    .foregroundStyle(DesignSystem.Colors.Text.primary)
                    .lineLimit(1)

                if let subtitle = header.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                if let badge = header.badge {
                    AccountSummaryCardBadge(badge: badge)
                }

                if let meta = header.meta, !meta.isEmpty {
                    Text(meta)
                        .font(.caption2)
                        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(DesignSystem.Colors.Component.border.opacity(0.35))
            .frame(height: 1)
    }
}

private struct AccountSummaryCardBadge: View {
    let badge: AccountSummaryCardBadgeModel

    var body: some View {
        Text(badge.text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(backgroundColor)
            )
            .foregroundStyle(foregroundColor)
    }

    private var backgroundColor: Color {
        switch badge.tone {
        case .neutral:
            return DesignSystem.Colors.Component.fill.opacity(0.5)
        case .active:
            return DesignSystem.Colors.primary.opacity(0.2)
        case .warning:
            return DesignSystem.Colors.Status.warning.opacity(0.18)
        }
    }

    private var foregroundColor: Color {
        switch badge.tone {
        case .neutral:
            return DesignSystem.Colors.Text.secondary
        case .active:
            return DesignSystem.Colors.primary
        case .warning:
            return DesignSystem.Colors.Status.warning
        }
    }
}
