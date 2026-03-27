import SwiftUI
import ProviderCatalog
import ProviderUsage
import CodexBarProviderCatalog
import NolonUIFoundation
import NolonUI

struct ProviderUsageUnifiedAccountCardGrid: View {
    enum LayoutMode: String {
        case cards
        case list
    }

    struct ListLayout {
        static let planColumnWidth: CGFloat = 96
        static let usageColumnWidth: CGFloat = 232
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
        NolonUI.AdaptiveCardGrid(columns: columns) {
            ForEach(0..<ProviderUsageSkeletonPolicy.genericCardCount(for: provider), id: \.self) { _ in
                UnifiedAccountCardSkeleton(providerName: provider.name)
            }
        }
    }

    private var cardGrid: some View {
        NolonUI.AdaptiveCardGrid(columns: columns) {
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
        AccountListModeModule(
            sections: [.init(id: "provider-usage-unified", items: listModeItems)],
            planColumnWidth: ListLayout.planColumnWidth,
            usageColumnWidth: ListLayout.usageColumnWidth,
            onTap: { itemID in
                guard let card = cards.first(where: { $0.id == itemID }) else { return }
                onTap(card)
            },
            onMenuAction: { itemID, actionID in
                guard let card = cards.first(where: { $0.id == itemID }) else { return }
                guard let action = card.menuActions.first(where: { $0.id == actionID }) else { return }
                onAction(card, action.actionID)
            }
        )
    }

    private var listModeItems: [NolonUI.AccountListModeItem] {
        cards.map { card in
            .init(
                id: card.id,
                presentation: card.presentation,
                header: card.header,
                usageWindows: usageWindows(from: card),
                menuActions: card.menuActions.map {
                    .init(
                        id: $0.id,
                        title: $0.title,
                        systemImage: $0.systemImage,
                        role: $0.role,
                        isEnabled: $0.isEnabled
                    )
                }
            )
        }
    }

    private func usageWindows(from data: AccountCardViewData) -> [NolonUI.AccountListModeUsageWindow] {
        guard case let .quota(quota) = data.body else {
            return [.init(id: "none", title: "-", progress: 0, percentText: "0%")]
        }

        if let modelUsages = quota.modelUsages, !modelUsages.isEmpty {
            return modelUsages.prefix(3).map { item in
                .init(
                    id: item.id,
                    title: item.title,
                    progress: CGFloat(max(0, min(100, item.remainingPercent.isInfinite ? 100 : item.remainingPercent)) / 100),
                    percentText: item.remainingPercent.isInfinite ? "∞" : String(format: "%.0f%%", max(0, min(100, item.remainingPercent)))
                )
            }
        }

        guard let usage = quota.usage else {
            return [.init(id: "none", title: "-", progress: 0, percentText: "0%")]
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
                let percent = item.window.remainingPercent
                let normalized = max(0, min(100, percent.isInfinite ? 100 : percent))
                return .init(
                    id: item.id,
                    title: title,
                    progress: CGFloat(normalized / 100),
                    percentText: percent.isInfinite ? "∞" : String(format: "%.0f%%", normalized)
                )
            }
    }
}
