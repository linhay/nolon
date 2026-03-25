import SwiftUI
import ProviderCatalog
import ProviderUsage
import CodexBarProviderCatalog
import NolonUIFoundation

struct ProviderUsageUnifiedAccountCardGrid: View {
    enum LayoutMode: String {
        case cards
        case list
    }

    struct ListLayout {
        static let planColumnWidth: CGFloat = 96
        static let usageColumnWidth: CGFloat = 232
    }

    struct ListUsageWindow: Identifiable {
        let id: String
        let title: String
        let remainingPercent: Double
    }

    let provider: Provider
    let cards: [AccountCardViewData]
    let isLoading: Bool
    let columns: [GridItem]
    let layoutMode: LayoutMode
    let onTap: (AccountCardViewData) -> Void
    let onAction: (AccountCardViewData, AccountCardActionID) -> Void

    var body: some View {
        Group {
            if isLoading {
                loadingContent
            } else if layoutMode == .list && !cards.isEmpty {
                listContent
            } else {
                cardGrid
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var loadingContent: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            ForEach(0..<ProviderUsageSkeletonPolicy.genericCardCount(for: provider), id: \.self) { _ in
                UnifiedAccountCardSkeleton(providerName: provider.name)
            }
        }
    }

    private var cardGrid: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            ForEach(cards) { card in
                UnifiedAccountCard(
                    data: card,
                    onTap: { _ in onTap(card) },
                    onAction: { _, action in onAction(card, action) }
                )
            }
        }
    }

    private var listContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            listTableHeader

            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                listRow(card: card)
                if index < cards.count - 1 {
                    Divider()
                        .overlay(DesignSystem.Colors.Component.border.opacity(0.25))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(DesignSystem.Colors.Background.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(DesignSystem.Colors.Component.border.opacity(0.3), lineWidth: 1)
        )
    }

    private var listTableHeader: some View {
        HStack(spacing: 12) {
            Text(NSLocalizedString("codex.accounts.list.header.account", value: "Account", comment: "Account list table account column"))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(NSLocalizedString("codex.accounts.list.header.plan", value: "Plan", comment: "Account list table plan column"))
                .frame(width: ListLayout.planColumnWidth, alignment: .leading)
            Text(NSLocalizedString("codex.accounts.list.header.usage", value: "Usage", comment: "Account list table usage column"))
                .frame(width: ListLayout.usageColumnWidth, alignment: .leading)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
        .padding(.vertical, 8)
    }

    private func listRow(card: AccountCardViewData) -> some View {
        let usageWindows = usageWindows(from: card)
        return HStack(alignment: .center, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                Circle()
                    .fill(statusColor(for: card.header.badge))
                    .frame(width: 6, height: 6)
                    .padding(.top, 3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(card.header.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.Text.primary)
                        .lineLimit(1)

                    if let secondary = secondaryText(from: card.header), !secondary.isEmpty {
                        Text(secondary)
                            .font(.caption2)
                            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(planText(from: card.header))
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .lineLimit(1)
                .frame(width: ListLayout.planColumnWidth, alignment: .leading)

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
            .frame(width: ListLayout.usageColumnWidth, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .contextMenu {
            ForEach(card.menuActions) { action in
                Button(role: action.role) {
                    onAction(card, action.actionID)
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
        .onTapGesture {
            onTap(card)
        }
    }

    private func usageWindows(from data: AccountCardViewData) -> [ListUsageWindow] {
        guard case let .quota(quota) = data.body else {
            return [.init(id: "none", title: "-", remainingPercent: 0)]
        }

        if let modelUsages = quota.modelUsages, !modelUsages.isEmpty {
            return modelUsages.prefix(3).map { item in
                .init(id: item.id, title: item.title, remainingPercent: item.remainingPercent)
            }
        }

        guard let usage = quota.usage else {
            return [.init(id: "none", title: "-", remainingPercent: 0)]
        }

        let metadata = ProviderUsageRegistry.metadata(for: quota.provider)
        return ProviderQuotaSection
            .displayWindows(for: usage, provider: quota.provider)
            .prefix(3)
            .map { item in
                let title: String
                switch item.id {
                case "primary":
                    title = metadata?.sessionLabel ?? "Session"
                case "secondary":
                    title = metadata?.weeklyLabel ?? "Weekly"
                default:
                    title = item.title
                }
                return .init(id: item.id, title: title, remainingPercent: item.window.remainingPercent)
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

    private func secondaryText(from header: AccountSummaryCardHeaderModel) -> String? {
        let eyebrow = header.eyebrow?.trimmingCharacters(in: .whitespacesAndNewlines)
        let meta = header.meta?.trimmingCharacters(in: .whitespacesAndNewlines)

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

    private func planText(from header: AccountSummaryCardHeaderModel) -> String {
        let raw = header.subtitle ?? "-"
        let plan = raw
            .split(separator: "•")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (plan?.isEmpty == false) ? plan! : "-"
    }

    private func statusColor(for badge: AccountSummaryCardBadgeModel?) -> Color {
        if let badge {
            switch badge.tone {
            case .active:
                return DesignSystem.Colors.primary
            case .warning:
                return DesignSystem.Colors.Status.warning
            case .neutral:
                return DesignSystem.Colors.Text.secondary
            }
        }
        return DesignSystem.Colors.Text.secondary
    }
}
