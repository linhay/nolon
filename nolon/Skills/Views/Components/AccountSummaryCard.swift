import SwiftUI
import ProviderUsage
import CodexBarProviderCatalog
import Shimmer

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

    static let active = AccountCardPresentation(
        selectionStyle: .active,
        showsSelectionBadge: false
    )

    static let pending = AccountCardPresentation(
        selectionStyle: .pending,
        showsSelectionBadge: false
    )

    static let selected = AccountCardPresentation(
        selectionStyle: .selected,
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

enum AccountSummaryCardBadgeTone: Equatable {
    case neutral
    case active
    case warning
}

struct AccountSummaryCardBadgeModel: Equatable {
    let text: String
    let tone: AccountSummaryCardBadgeTone
}

struct AccountSummaryCardHeaderModel: Equatable {
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

struct UnifiedAccountCard: View {
    let data: AccountCardViewData
    let onTap: (AccountRecordID) -> Void
    let onAction: (AccountRecordID, AccountCardActionID) -> Void

    var body: some View {
        AccountSummaryContentCard(
            presentation: data.presentation,
            header: data.header,
            showsDetailsSection: !data.detailRows.isEmpty,
            showsActionsSection: !data.primaryActions.isEmpty || data.footer != nil
        ) {
            bodyContent
        } details: {
            detailsContent
        } actions: {
            VStack(alignment: .leading, spacing: 10) {
                if !data.primaryActions.isEmpty {
                    actionsContent
                }
                if let footer = data.footer {
                    footerContent(footer)
                }
            }
        }
        .onTapGesture {
            guard data.tapBehavior != .none else { return }
            onTap(data.recordID)
        }
        .contextMenu {
            ForEach(data.menuActions) { action in
                Button(role: action.role) {
                    onAction(data.recordID, action.actionID)
                } label: {
                    if let systemImage = action.systemImage {
                        Label(action.title, systemImage: systemImage)
                    } else {
                        Text(action.title)
                    }
                }
                .disabled(!action.isEnabled)
            }
        }
        .accessibilityLabel(data.accessibilityLabel)
    }

    @ViewBuilder
    private var bodyContent: some View {
        switch data.body {
        case let .quota(quota):
            ProviderQuotaSection(
                provider: quota.provider,
                accountTitle: quota.accountTitle,
                usage: quota.usage,
                credits: quota.credits,
                creditsRefreshedAt: quota.creditsRefreshedAt,
                loginAt: quota.loginAt,
                syncedAt: quota.syncedAt,
                isLoading: quota.isLoading,
                showsEmptyState: quota.showsEmptyState,
                errorMessage: quota.errorMessage,
                onRefresh: quota.onRefreshActionID == nil ? nil : {
                    if let actionID = quota.onRefreshActionID {
                        onAction(data.recordID, actionID)
                    }
                },
                usesCardChrome: false,
                showsHeader: false
            )
        case let .rows(rows):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(rows) { row in
                    rowView(row)
                }
            }
        }
    }

    private var detailsContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(data.detailRows) { row in
                rowView(row)
            }
        }
    }

    private var actionsContent: some View {
        let primaryCount = data.primaryActions.filter { $0.prominence == .primary }.count
        return Group {
            if data.primaryActions.count == 2 && primaryCount == 1 {
                HStack(spacing: 8) {
                    ForEach(data.primaryActions) { action in
                        actionButton(action)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(data.primaryActions) { action in
                        actionButton(action)
                    }
                }
            }
        }
    }

    private func footerContent(_ footer: AccountCardFooterViewData) -> some View {
        HStack(alignment: .center, spacing: 8) {
            if let leadingTag = footer.leadingTag, !leadingTag.isEmpty {
                Text(leadingTag)
                    .font(.system(size: 8, weight: .black))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(DesignSystem.Colors.primary.opacity(0.15))
                    )
                    .foregroundStyle(DesignSystem.Colors.primary)
                    .textCase(.uppercase)
            }

            Spacer(minLength: 0)

            if let trailingText = footer.trailingText, !trailingText.isEmpty {
                Text(trailingText)
                    .font(.caption2)
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
            }
        }
    }

    private func actionButton(_ action: AccountCardActionViewData) -> some View {
        Group {
            if action.prominence == .primary {
                Button(role: action.role) {
                    onAction(data.recordID, action.actionID)
                } label: {
                    actionLabel(action)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button(role: action.role) {
                    onAction(data.recordID, action.actionID)
                } label: {
                    actionLabel(action)
                }
                .buttonStyle(.bordered)
            }
        }
        .controlSize(.small)
        .disabled(!action.isEnabled)
    }

    @ViewBuilder
    private func actionLabel(_ action: AccountCardActionViewData) -> some View {
        if let systemImage = action.systemImage {
            Label(action.title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        } else {
            Text(action.title)
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func rowView(_ row: AccountCardRowViewData) -> some View {
        switch row.style {
        case .metric:
            HStack(alignment: .center, spacing: 8) {
                if let title = row.title {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                }
                Spacer(minLength: 0)
                Text(row.value)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(tintColor(row.tint))
                if let auxiliary = row.auxiliary {
                    Text(auxiliary)
                        .font(.caption2)
                        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                }
            }
        case .kv:
            VStack(alignment: .leading, spacing: 4) {
                if let title = row.title {
                    Text(title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                        .textCase(.uppercase)
                }
                Text(row.value)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    .textSelection(.enabled)
                if let auxiliary = row.auxiliary {
                    Text(auxiliary)
                        .font(.caption2)
                        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                }
            }
        case .message:
            Text(row.value)
                .font(.caption)
                .foregroundStyle(tintColor(row.tint))
                .lineLimit(2)
                .textSelection(.enabled)
        case .code:
            VStack(alignment: .leading, spacing: 4) {
                if let title = row.title {
                    Text(title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                }
                Text(row.value)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    .textSelection(.enabled)
                    .lineLimit(2)
            }
        }
    }

    private func tintColor(_ tone: AccountSummaryCardBadgeTone?) -> Color {
        switch tone {
        case .active:
            return DesignSystem.Colors.primary
        case .warning:
            return DesignSystem.Colors.Status.warning
        case .neutral, .none:
            return DesignSystem.Colors.Text.primary
        }
    }
}

struct UnifiedAccountCardSkeleton: View {
    let providerName: String

    var body: some View {
        AccountSummaryContentCard(
            header: .init(
                eyebrow: providerName,
                title: "Loading",
                subtitle: "Loading",
                meta: "Loading",
                badge: nil
            ),
            showsActionsSection: true
        ) {
            VStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 28)
                }
            }
        } actions: {
            HStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 52, height: 12)

                Spacer()

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 76, height: 10)
            }
        }
        .redacted(reason: .placeholder)
        .shimmering(
            active: true,
            animation: .easeInOut(duration: 1.25).repeatForever(autoreverses: false),
            bandSize: 0.32
        )
        .accessibilityLabel("\(providerName) loading")
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
            return DesignSystem.Colors.Component.controlFillSubtle
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
