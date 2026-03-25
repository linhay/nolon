import SwiftUI
import ProviderUsage
import CodexBarProviderCatalog
import Shimmer
import NolonUI
import NolonUIFoundation

typealias AccountCardSelectionStyle = NolonUIFoundation.AccountCardSelectionStyle
typealias AccountCardPresentation = NolonUIFoundation.AccountCardPresentation
typealias AccountSummaryCardBadgeTone = NolonUIFoundation.AccountSummaryCardBadgeTone
typealias AccountSummaryCardBadgeModel = NolonUIFoundation.AccountSummaryCardBadgeModel
typealias AccountSummaryCardHeaderModel = NolonUIFoundation.AccountSummaryCardHeaderModel

struct AccountSummaryCard<Content: View>: View {
    @State private var viewModel = NolonUI.AccountSummaryCardViewModel()
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
        NolonUI.AccountSummaryCard(
            presentation: presentation,
            contentInsets: contentInsets
        ) {
            content
        }
    }

    static func backgroundOpacity(for selectionStyle: AccountCardSelectionStyle) -> Double {
        NolonUI.AccountSummaryCard<Content>.backgroundOpacity(for: selectionStyle)
    }

    static func borderLineWidth(for selectionStyle: AccountCardSelectionStyle) -> CGFloat {
        NolonUI.AccountSummaryCard<Content>.borderLineWidth(for: selectionStyle)
    }

    static func borderDash(for selectionStyle: AccountCardSelectionStyle) -> [CGFloat] {
        NolonUI.AccountSummaryCard<Content>.borderDash(for: selectionStyle)
    }
}

struct AccountSummaryContentCard<Body: View, Details: View, Actions: View>: View {
    @State private var componentViewModel = NolonUI.AccountSummaryContentCardViewModel()
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
        NolonUI.AccountSummaryContentCard(
            presentation: presentation,
            header: header,
            showsDetailsSection: showsDetailsSection,
            showsActionsSection: showsActionsSection
        ) {
            bodyContent
        } details: {
            detailsContent
        } actions: {
            actionsContent
        }
    }
}

struct UnifiedAccountCard: View, DebugCardLocatable {
    let data: AccountCardViewData
    let onTap: (AccountRecordID) -> Void
    let onAction: (AccountRecordID, AccountCardActionID) -> Void

    var debugCardMarkerItems: [PageMarkerItem] {
        var items: [PageMarkerItem] = []
        if let eyebrow = data.header.eyebrow, !eyebrow.isEmpty {
            items.append(PageMarkerItem(title: eyebrow))
        }
        items.append(PageMarkerItem(title: data.header.title))
        return items
    }

    var body: some View {
        Group {
            if Self.shouldInstallTapGesture(for: data.tapBehavior) {
                cardContent.onTapGesture {
                    onTap(data.recordID)
                }
            } else {
                cardContent
            }
        }
    }

    static func shouldInstallTapGesture(for tapBehavior: AccountCardTapBehavior) -> Bool {
        tapBehavior != .none
    }

    private var cardContent: some View {
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
        .debugPageMarkerContextMenu(debugCardMarkerItems) {
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
        .debugCardLocator(debugCardMarkerItems)
        .accessibilityLabel(data.accessibilityLabel)
    }

    @ViewBuilder
    private var bodyContent: some View {
        switch data.body {
        case let .quota(quota):
            quotaBodyContent(quota)
        case let .rows(rows):
            VStack(alignment: .leading, spacing: 10) {
                ForEach(rows) { row in
                    rowView(row)
                }
            }
        }
    }

    @ViewBuilder
    private func quotaBodyContent(_ quota: AccountCardQuotaViewData) -> some View {
        if quota.isLoading {
            NolonUI.AccountLoadingStateModule()
        } else if let message = quota.errorMessage?.trimmingCharacters(in: .whitespacesAndNewlines), !message.isEmpty {
            NolonUI.AccountErrorStateModule(
                title: NSLocalizedString("usage.error.title", value: "Sync Failed", comment: "Error title"),
                message: message
            )
        } else if let usage = quota.usage {
            NolonUI.AccountQuotaModule(
                rows: quotaRows(quota: quota, usage: usage, provider: quota.provider),
                creditsText: quotaCreditsText(quota.credits)
            )
        } else if quota.showsEmptyState {
            NolonUI.AccountEmptyStateModule(
                text: NSLocalizedString("usage.monitor.empty.desc", value: "No data available.", comment: "Empty data")
            )
        } else {
            NolonUI.AccountEmptyStateModule(
                text: NSLocalizedString("usage.monitor.empty.desc", value: "No data available.", comment: "Empty data")
            )
        }
    }

    private func quotaRows(
        quota: AccountCardQuotaViewData,
        usage: UsageSnapshot,
        provider: UsageProvider
    ) -> [NolonUI.AccountQuotaRow] {
        if let modelUsages = quota.modelUsages, !modelUsages.isEmpty {
            return modelUsages.map { model in
                let normalized = CGFloat(max(0, min(100, model.remainingPercent)) / 100)
                return NolonUI.AccountQuotaRow(
                    title: model.title,
                    remainingText: quotaPercentText(model.remainingPercent),
                    progress: normalized,
                    meta: quotaWindowMetaText(resetsAt: model.resetsAt)
                )
            }
        }
        return ProviderQuotaSection
            .displayWindows(for: usage, provider: provider)
            .map { item in
                let percent = item.window.remainingPercent
                let normalized = percent.isInfinite ? 1 : CGFloat(max(0, min(100, percent)) / 100)
                return NolonUI.AccountQuotaRow(
                    title: quotaWindowTitle(item, provider: provider),
                    remainingText: quotaPercentText(percent),
                    progress: normalized,
                    meta: quotaWindowMetaText(item.window)
                )
            }
    }

    private func quotaWindowTitle(_ item: UsageWindow, provider: UsageProvider) -> String {
        let metadata = ProviderUsageRegistry.metadata(for: provider)
        switch item.id {
        case "primary":
            return metadata?.sessionLabel ?? "Session"
        case "secondary":
            return metadata?.weeklyLabel ?? "Weekly"
        default:
            return item.title
        }
    }

    private func quotaWindowMetaText(_ window: RateWindow) -> String {
        quotaWindowMetaText(resetsAt: window.resetsAt)
    }

    private func quotaWindowMetaText(resetsAt: Date?) -> String {
        guard let resetsAt else { return "-" }
        let remaining = resetsAt.timeIntervalSinceNow
        if remaining <= 0 {
            return NSLocalizedString("usage.reset.now", value: "now", comment: "reset now")
        }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 1
        let value = formatter.string(from: remaining) ?? "-"
        return String(
            format: NSLocalizedString("usage.reset.suffix", value: "%@ left", comment: "reset suffix"),
            value
        )
    }

    private func quotaPercentText(_ percent: Double) -> String {
        if percent.isInfinite {
            return "∞"
        }
        return String(format: "%.0f%%", max(0, min(100, percent)))
    }

    private func quotaCreditsText(_ credits: CreditsSnapshot?) -> String {
        guard let credits else { return "-" }
        if credits.remaining.isInfinite {
            return NSLocalizedString("usage.metric.unlimited", value: "Unlimited", comment: "Unlimited")
        }
        if credits.remaining.isNaN {
            return "-"
        }
        return String(format: "%.0f", credits.remaining)
    }

    private var detailsContent: some View {
        VStack(alignment: .leading, spacing: 10) {
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
        .debugCardLocator(footerMarkerItems(footer))
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
        .debugCardLocator(actionMarkerItems(action))
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
        Group {
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
        .debugCardLocator(rowMarkerItems(row))
    }

    private func rowMarkerItems(_ row: AccountCardRowViewData) -> [PageMarkerItem] {
        debugCardMarkerItems + [PageMarkerItem(title: rowMarkerTitle(row))]
    }

    private func rowMarkerTitle(_ row: AccountCardRowViewData) -> String {
        if let title = row.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            return title
        }
        let value = row.value.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Row" : value
    }

    private func actionMarkerItems(_ action: AccountCardActionViewData) -> [PageMarkerItem] {
        debugCardMarkerItems + [PageMarkerItem(title: action.title)]
    }

    private func footerMarkerItems(_ footer: AccountCardFooterViewData) -> [PageMarkerItem] {
        let label = [
            footer.leadingTag?.trimmingCharacters(in: .whitespacesAndNewlines),
            footer.trailingText?.trimmingCharacters(in: .whitespacesAndNewlines),
        ]
        .compactMap { value in
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        .joined(separator: " • ")

        return debugCardMarkerItems + [PageMarkerItem(title: label.isEmpty ? "Footer" : label)]
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
