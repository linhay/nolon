import SwiftUI
import AppKit
import Observation
import ProviderCatalog
import ProviderUsage
import CodexBarProviderCatalog
import NolonCoreCLIKit
import STFilePath
import NolonResourceKit
import Shimmer
import NolonUI
import NolonUIFoundation

struct NolonAccountsView: View, DebugPageLocatable {
    let settings: ProviderSettings
    let onSelectProvider: (Provider.ID) -> Void
    @State private var viewModel: NolonAccountsViewModel
    @State private var selectedWindow: AccountTimeWindow = .d7

    init(settings: ProviderSettings, onSelectProvider: @escaping (Provider.ID) -> Void) {
        self.settings = settings
        self.onSelectProvider = onSelectProvider
        self._viewModel = State(initialValue: NolonAccountsViewModel(settings: settings))
    }

    var debugPageMarkerItems: [PageMarkerItem] {
        PageMarkerRouteResolver.accountsItems()
    }

    var body: some View {
        NolonUI.AccountPanoramaScaffold(
            isEmpty: viewModel.sections.isEmpty
        ) {
            accountsHeader
        } emptyState: {
            emptyState
        } sections: {
            sectionsContent
        } dashboard: {
            accountsDashboard
        }
        .navigationTitle("")
        .debugPageLocator(debugPageMarkerItems)
        .task(id: settings.providers.map(\.id).joined(separator: ",")) {
            viewModel.refresh()
        }
    }

    private var emptyState: some View {
        ProviderUsageEmptyStateCard(
            title: LocalizedStringKey(
                NSLocalizedString("accounts.empty.title", value: "No account providers", comment: "No account providers")
            ),
            systemImage: "person.crop.circle.badge.exclamationmark",
            descriptionText: Text(
                NSLocalizedString(
                    "accounts.empty.description",
                    value: "Manage supported provider accounts from one place.",
                    comment: "Accounts subtitle"
                )
            )
        )
    }

    private var sectionsContent: some View {
        ForEach(viewModel.sections) { section in
            accountSection(section)
        }
    }

    @ViewBuilder
    private func accountSection(_ section: ProviderPresentationSections.ProviderSection) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            NolonUI.AccountSectionHeaderView(data: sectionHeaderData(section))

            ForEach(section.providers) { provider in
                accountProviderGroup(provider)
            }
        }
    }

    @ViewBuilder
    private func accountProviderGroup(_ provider: Provider) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            NolonUI.AccountSectionHeaderView(data: providerHeaderData(provider))
            ProviderUsageView(provider: provider, isEmbedded: true)
        }
    }

    private var accountsHeader: some View {
        NolonUI.AccountPageHeaderView(
            data: .init(
                isRefreshing: viewModel.isRefreshing
            ),
            onRefresh: { viewModel.refresh() },
            onAddAccount: {}
        )
    }

    private var accountsDashboard: some View {
        NolonUI.AccountDashboardSectionView {
            NolonUI.AccountTrendPanelView(data: trendPanelData) { id in
                guard let next = AccountTimeWindow(rawValue: id) else { return }
                selectedWindow = next
            }
        } rankingContent: {
            NolonUI.AccountRankingPanelView(data: rankingPanelData)
        }
    }

    private var trendPanelData: AccountTrendPanelData {
        AccountTrendPanelData(
            windowOptions: AccountTimeWindow.allCases.map { window in
                .init(
                    id: window.rawValue,
                    title: window.label,
                    isSelected: selectedWindow == window
                )
            },
            samples: trendSamples()
        )
    }

    private var rankingPanelData: AccountRankingPanelData {
        AccountRankingPanelData(
            items: rankingItems().map {
                .init(
                    id: $0.id,
                    name: $0.name,
                    ratio: $0.ratio,
                    valueText: $0.valueText,
                    tone: $0.tone
                )
            }
        )
    }

    private func trendSamples() -> [AccountTrendSampleData] {
        let values = rankingItems().map(\.value)
        let total = max(values.max() ?? 1, 1)
        let today = values.reduce(0, +)
        let p1 = max(1, today / 3)
        let p2 = max(1, today / 2)
        let p3 = max(1, (today * 2) / 3)
        let points = [p1, p2, p3, today]

        return points.enumerated().map { offset, value in
            let ratio = CGFloat(value) / CGFloat(max(total, value))
            let label = offset == 3
                ? NSLocalizedString("accounts.dashboard.today", value: "Today", comment: "Today label")
                : "03/\(offset + 6)"
            return AccountTrendSampleData(
                id: "trend-\(offset)",
                label: label,
                heightRatio: Double(ratio),
                opacity: 0.9 - Double(offset) * 0.12
            )
        }
    }

    private func rankingItems() -> [AccountProviderRankingItem] {
        let candidates = viewModel.sections.flatMap(\.providers)
        let computed = candidates.compactMap { provider -> AccountProviderRankingItem? in
            guard let summary = viewModel.usageSummaryByProviderID[provider.id] else { return nil }
            let value = max(summary.totalCount, 0)
            return AccountProviderRankingItem(
                id: provider.id,
                name: provider.name,
                value: value,
                tone: accentTone(for: provider)
            )
        }.sorted { $0.value > $1.value }

        let maxValue = max(computed.first?.value ?? 0, 1)
        if computed.isEmpty {
            return [
                AccountProviderRankingItem(id: "codex", name: "Codex", value: 120, tone: .secondary, ratio: 1, valueText: "120"),
                AccountProviderRankingItem(id: "gemini", name: "Gemini", value: 90, tone: .primary, ratio: 0.75, valueText: "90")
            ]
        }

        return computed.map { item in
            let ratio = Double(item.value) / Double(maxValue)
            return AccountProviderRankingItem(
                id: item.id,
                name: item.name,
                value: item.value,
                tone: item.tone,
                ratio: ratio,
                valueText: "\(item.value)"
            )
        }
    }

    private func accentTone(for provider: Provider) -> AccountProviderRankingItemData.Tone {
        switch provider.templateId {
        case ProviderTemplate.codex.rawValue: return .secondary
        case ProviderTemplate.gemini.rawValue: return .primary
        default: return .warning
        }
    }

    private func sectionHeaderData(_ section: ProviderPresentationSections.ProviderSection) -> AccountSectionHeaderData {
        let title = NSLocalizedString(section.titleKey, value: section.fallbackTitle, comment: "Account provider section")
        let shortLabel = String(title.prefix(1)).uppercased()
        let countText = "\(section.providers.count) \(NSLocalizedString("accounts.section.accounts", value: "accounts", comment: "accounts unit"))"
        let tone: AccountSectionHeaderData.SectionTone
        switch section.id {
        case .originalVendors:
            tone = .primary
        case .integratedVendors:
            tone = .secondary
        case .projects:
            tone = .success
        }
        return AccountSectionHeaderData(
            style: .section(
                .init(
                    shortLabel: shortLabel,
                    title: title,
                    accountCountText: countText,
                    tone: tone
                )
            )
        )
    }

    private func providerHeaderData(_ provider: Provider) -> AccountSectionHeaderData {
        let logoName = providerTemplate(for: provider)?.logoFile
        return AccountSectionHeaderData(
            style: .provider(
                .init(
                    name: provider.name,
                    logoName: logoName
                )
            )
        )
    }

    private func providerTemplate(for provider: Provider) -> ProviderTemplate? {
        guard let templateId = provider.templateId else { return nil }
        return ProviderTemplate(rawValue: templateId)
    }
}

private enum AccountTimeWindow: String, CaseIterable, Hashable {
    case d7
    case d14
    case d30
    case all

    var label: String {
        switch self {
        case .d7: return "7d"
        case .d14: return "14d"
        case .d30: return "30d"
        case .all: return "all"
        }
    }
}

private struct AccountProviderRankingItem {
    let id: String
    let name: String
    let value: Int
    let tone: AccountProviderRankingItemData.Tone
    let ratio: Double
    let valueText: String

    init(id: String, name: String, value: Int, tone: AccountProviderRankingItemData.Tone, ratio: Double = 0, valueText: String = "") {
        self.id = id
        self.name = name
        self.value = value
        self.tone = tone
        self.ratio = ratio
        self.valueText = valueText
    }
}

enum NolonAccountsThemeTokens {
    static let pageBackgroundLight = 0xF5F5F7
    static let pageBackgroundDark = 0x0F0F0F
    static let panelBackgroundLight = 0xFFFFFF
    static let panelBackgroundDark = 0x1C1C1E
}
