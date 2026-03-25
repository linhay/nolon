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

struct NolonAccountsView: View, DebugPageLocatable {
    let settings: ProviderSettings
    let onSelectProvider: (Provider.ID) -> Void
    @State private var viewModel: NolonAccountsViewModel
    @State private var selectedWindow: AccountTimeWindow = .d7
    private let pageBackground = Color(light: NolonAccountsThemeTokens.pageBackgroundLight, dark: NolonAccountsThemeTokens.pageBackgroundDark)
    private let panelBackground = Color(light: NolonAccountsThemeTokens.panelBackgroundLight, dark: NolonAccountsThemeTokens.panelBackgroundDark)
    private let primaryText = DesignSystem.Colors.Text.primary
    private let secondaryText = DesignSystem.Colors.Text.secondary
    private let tertiaryText = DesignSystem.Colors.Text.tertiary
    private let subtleBorder = Color(light: 0x000000, dark: 0xFFFFFF).opacity(0.08)
    private let subtleFill = Color(light: 0x000000, dark: 0xFFFFFF).opacity(0.06)
    private let subtleFillStrong = Color(light: 0x000000, dark: 0xFFFFFF).opacity(0.14)

    init(settings: ProviderSettings, onSelectProvider: @escaping (Provider.ID) -> Void) {
        self.settings = settings
        self.onSelectProvider = onSelectProvider
        self._viewModel = State(initialValue: NolonAccountsViewModel(settings: settings))
    }

    var debugPageMarkerItems: [PageMarkerItem] {
        PageMarkerRouteResolver.accountsItems()
    }

    var body: some View {
        ZStack {
            pageBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 58) {
                    accountsHeader

                    if viewModel.sections.isEmpty {
                        emptyState
                    } else {
                        sectionsContent
                        accountsDashboard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)
                .padding(.bottom, 48)
                .frame(maxWidth: 1100, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .top)
            }
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
            AccountSectionHeader(style: .section(section))

            ForEach(section.providers) { provider in
                accountProviderGroup(provider)
            }
        }
    }

    @ViewBuilder
    private func accountProviderGroup(_ provider: Provider) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            AccountSectionHeader(style: .provider(provider))
            ProviderUsageView(provider: provider, isEmbedded: true)
        }
    }

    private var accountsHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("accounts.title", value: "Account Panorama", comment: "Accounts title"))
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(primaryText)

                Text(
                    NSLocalizedString(
                        "accounts.empty.description",
                        value: "Unified management for all account-enabled providers.",
                        comment: "Accounts subtitle"
                    )
                )
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(tertiaryText)
            }

            Spacer()

            HStack(spacing: 12) {
                Button {
                    viewModel.refresh()
                } label: {
                    HStack(spacing: 6) {
                        if viewModel.isRefreshing {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(NSLocalizedString("accounts.action.refresh", value: "Refresh All", comment: "Refresh accounts"))
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(secondaryText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(subtleFill)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(subtleBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isRefreshing)

                Button {} label: {
                    Text(NSLocalizedString("accounts.action.add_account", value: "+ Add Account", comment: "Add account action"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.Text.onAccent)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(DesignSystem.Colors.primary)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var accountsDashboard: some View {
        VStack(alignment: .leading, spacing: 30) {
            Rectangle()
                .fill(subtleBorder)
                .frame(height: 1)

            HStack(alignment: .top, spacing: 30) {
                dashboardTrendPanel
                    .frame(maxWidth: .infinity)
                dashboardRankingPanel
                    .frame(width: 320)
            }
        }
        .padding(.top, 4)
    }

    private var dashboardTrendPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(NSLocalizedString("accounts.dashboard.trend", value: "Aggregated Usage Trend", comment: "Aggregated trend panel"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(primaryText)

                Spacer()

                HStack(spacing: 8) {
                    ForEach(AccountTimeWindow.allCases, id: \.self) { window in
                        GenericSelectionControl(
                            value: window,
                            selection: $selectedWindow
                        ) { isSelected in
                            Text(window.label)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(isSelected ? primaryText : secondaryText)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(isSelected ? subtleFillStrong : subtleFill)
                                )
                        }
                    }
                }
            }

            let samples = trendSamples()
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(samples.indices, id: \.self) { index in
                    let item = samples[index]
                    VStack(spacing: 8) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(subtleFill)
                                .frame(width: 32, height: 124)
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(item.color)
                                .frame(width: 32, height: item.height)
                        }
                        Text(item.label)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(secondaryText)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(28)
        .frame(maxWidth: .infinity, minHeight: 250, alignment: .topLeading)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(subtleBorder, lineWidth: 1)
        )
    }

    private var dashboardRankingPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(NSLocalizedString("accounts.dashboard.ranking", value: "Provider Ranking", comment: "Provider ranking panel"))
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(primaryText)

            ForEach(rankingItems(), id: \.id) { item in
                HStack(spacing: 10) {
                    Text(item.name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(secondaryText)
                        .frame(width: 78, alignment: .leading)

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule(style: .continuous)
                                .fill(subtleBorder)
                            Capsule(style: .continuous)
                                .fill(item.color)
                                .frame(width: max(8, proxy.size.width * CGFloat(item.ratio)))
                        }
                    }
                    .frame(height: 6)

                    Text(item.valueText)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(primaryText)
                        .frame(width: 46, alignment: .trailing)
                }
                .frame(height: 16)
            }
        }
        .padding(28)
        .frame(width: 320, alignment: .topLeading)
        .frame(minHeight: 250, alignment: .topLeading)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(subtleBorder, lineWidth: 1)
        )
    }

    private func trendSamples() -> [(label: String, height: CGFloat, color: Color)] {
        let values = rankingItems().map(\.value)
        let total = max(values.max() ?? 1, 1)
        let today = values.reduce(0, +)
        let p1 = max(1, today / 3)
        let p2 = max(1, today / 2)
        let p3 = max(1, (today * 2) / 3)
        let points = [p1, p2, p3, today]

        return points.enumerated().map { offset, value in
            let ratio = CGFloat(value) / CGFloat(max(total, value))
            let height = max(14, 100 * ratio)
            let label = offset == 3
                ? NSLocalizedString("accounts.dashboard.today", value: "Today", comment: "Today label")
                : "03/\(offset + 6)"
            return (label, height, DesignSystem.Colors.primary.opacity(0.9 - Double(offset) * 0.12))
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
                color: accentColor(for: provider)
            )
        }.sorted { $0.value > $1.value }

        let maxValue = max(computed.first?.value ?? 0, 1)
        if computed.isEmpty {
            return [
                AccountProviderRankingItem(id: "codex", name: "Codex", value: 120, color: DesignSystem.Colors.secondary, ratio: 1, valueText: "120"),
                AccountProviderRankingItem(id: "gemini", name: "Gemini", value: 90, color: DesignSystem.Colors.primary, ratio: 0.75, valueText: "90")
            ]
        }

        return computed.map { item in
            let ratio = Double(item.value) / Double(maxValue)
            return AccountProviderRankingItem(
                id: item.id,
                name: item.name,
                value: item.value,
                color: item.color,
                ratio: ratio,
                valueText: "\(item.value)"
            )
        }
    }

    private func accentColor(for provider: Provider) -> Color {
        switch provider.templateId {
        case ProviderTemplate.codex.rawValue: return DesignSystem.Colors.secondary
        case ProviderTemplate.gemini.rawValue: return DesignSystem.Colors.primary
        default: return Color(light: 0xD97757, dark: 0xD97757)
        }
    }
}

private enum AccountTimeWindow: CaseIterable, Hashable {
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

private struct AccountSectionHeader: View {
    enum Style {
        case section(ProviderPresentationSections.ProviderSection)
        case provider(Provider)
    }

    let style: Style

    var body: some View {
        switch style {
        case let .section(section):
            sectionHeader(section)
        case let .provider(provider):
            providerHeader(provider)
        }
    }

    private func sectionHeader(_ section: ProviderPresentationSections.ProviderSection) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(accent(for: section))
                .frame(width: 28, height: 28)
                .overlay(
                    Text(sectionShortLabel(for: section))
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(.white)
                )

            Text(NSLocalizedString(section.titleKey, value: section.fallbackTitle, comment: "Account provider section"))
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(DesignSystem.Colors.Text.primary)

            Spacer()

            Text("\(section.providers.count) \(NSLocalizedString("accounts.section.accounts", value: "accounts", comment: "accounts unit"))")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
        }
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(light: 0x000000, dark: 0xFFFFFF).opacity(0.08))
                .frame(height: 1)
        }
    }

    private func providerHeader(_ provider: Provider) -> some View {
        HStack(spacing: 10) {
            if let template = providerTemplate(for: provider) {
                ProviderLogoView(
                    name: provider.name,
                    logoName: template.logoFile,
                    iconSize: 16
                )
            } else {
                Circle()
                    .fill(DesignSystem.Colors.primary.opacity(0.9))
                    .frame(width: 8, height: 8)
            }

            Text(provider.name)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.Text.primary)

            Spacer()
        }
    }

    private func sectionShortLabel(for section: ProviderPresentationSections.ProviderSection) -> String {
        let title = NSLocalizedString(section.titleKey, value: section.fallbackTitle, comment: "Account provider section")
        return String(title.prefix(1)).uppercased()
    }

    private func accent(for section: ProviderPresentationSections.ProviderSection) -> Color {
        switch section.id {
        case .originalVendors:
            return DesignSystem.Colors.primary
        case .integratedVendors:
            return DesignSystem.Colors.secondary
        case .projects:
            return Color(light: 0x34C759, dark: 0x34C759)
        }
    }

    private func providerTemplate(for provider: Provider) -> ProviderTemplate? {
        guard let templateId = provider.templateId else { return nil }
        return ProviderTemplate(rawValue: templateId)
    }
}

private struct AccountProviderRankingItem {
    let id: String
    let name: String
    let value: Int
    let color: Color
    let ratio: Double
    let valueText: String

    init(id: String, name: String, value: Int, color: Color, ratio: Double = 0, valueText: String = "") {
        self.id = id
        self.name = name
        self.value = value
        self.color = color
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
