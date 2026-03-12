import SwiftUI
import Observation
import ProviderCatalog
import ProviderUsage
import CodexBarProviderCatalog
import STFilePath
import NolonResourceKit
import Shimmer

@MainActor
@Observable
final class NolonAccountsViewModel {
    struct UsageSummary: Sendable, Equatable {
        let provider: UsageProvider
        let totalCount: Int
        let successCount: Int
        let failureCount: Int
        let latestUpdatedAt: Date?
        let accountEmail: String?
        let primaryUsedPercent: Double?
    }

    struct CodexAccountSummary: Sendable, Equatable {
        let accountEmail: String?
        let plan: String?
    }

    struct AccountUsageSummary: Identifiable, Sendable, Equatable {
        let id: String
        let accountLabel: String
        let accountEmail: String?
        let plan: String?
        let totalCount: Int
        let successCount: Int
        let failureCount: Int
        let latestUpdatedAt: Date?
        let primaryUsedPercent: Double?
        let errorMessage: String?
        let isSnapshotOnly: Bool
    }

    let settings: ProviderSettings
    private let usageMonitor: ProviderUsageMonitorService
    private let usageSettingsStore: UsageMonitorSettingsStore
    private let codexAuthManager: CodexAuthManager
    private let claudeAccountManager: ClaudeAccountManager
    private let geminiAuthStore: GeminiAuthStore

    var usageSummaryByProviderID: [Provider.ID: UsageSummary] = [:]
    var accountSummariesByProviderID: [Provider.ID: [AccountUsageSummary]] = [:]
    var codexAccountSummaryByProviderID: [Provider.ID: CodexAccountSummary] = [:]
    var claudeAccountsByProviderID: [Provider.ID: [ClaudeAccount]] = [:]
    var activeClaudeAccountIDByProviderID: [Provider.ID: UUID] = [:]
    var geminiAccountsByProviderID: [Provider.ID: [GeminiAuthAccount]] = [:]
    var activeGeminiAccountIDByProviderID: [Provider.ID: UUID] = [:]
    var isRefreshing = false

    init(
        settings: ProviderSettings,
        usageMonitor: ProviderUsageMonitorService? = nil,
        usageSettingsStore: UsageMonitorSettingsStore? = nil,
        codexAuthManager: CodexAuthManager = CodexAuthManager(),
        claudeAccountManager: ClaudeAccountManager = ClaudeAccountManager(),
        geminiAuthStore: GeminiAuthStore = .shared
    ) {
        self.settings = settings
        let tokenStore = FileTokenAccountStore(fileURL: ProviderUsagePaths.defaultTokenAccountsFileURL())
        self.usageMonitor = usageMonitor ?? ProviderUsageMonitorService(tokenAccountStore: tokenStore)
        self.usageSettingsStore = usageSettingsStore ?? .shared
        self.codexAuthManager = codexAuthManager
        self.claudeAccountManager = claudeAccountManager
        self.geminiAuthStore = geminiAuthStore
    }

    var sections: [ProviderPresentationSections.ProviderSection] {
        ProviderPresentationSections.accountProviders(from: settings.providers)
    }

    func refresh() {
        Task {
            await refreshAsync()
        }
    }

    private func refreshAsync() async {
        isRefreshing = true
        defer { isRefreshing = false }

        var latestUsage: [Provider.ID: UsageSummary] = [:]
        var latestAccountUsage: [Provider.ID: [AccountUsageSummary]] = [:]
        var latestCodexSummary: [Provider.ID: CodexAccountSummary] = [:]
        var latestClaudeAccounts: [Provider.ID: [ClaudeAccount]] = [:]
        var latestActiveClaudeAccounts: [Provider.ID: UUID] = [:]
        var latestGeminiAccounts: [Provider.ID: [GeminiAuthAccount]] = [:]
        var latestActiveGeminiAccounts: [Provider.ID: UUID] = [:]

        for section in sections {
            for provider in section.providers {
                guard let usageProvider = Self.mapUsageProvider(for: provider) else { continue }
                let monitorSettings = usageSettingsStore.settings(for: provider)
                let outcomes = await usageMonitor.fetchOutcomes(provider: usageProvider, settings: monitorSettings)

                let accountSummaries = Self.makeAccountSummaries(outcomes: outcomes)
                if let summary = Self.makeUsageSummary(provider: provider, usageProvider: usageProvider, outcomes: outcomes) {
                    latestUsage[provider.id] = summary
                }

                if usageProvider == .codex {
                    let codexSnapshot = await loadCodexSnapshotAccounts(for: provider, liveSummaries: accountSummaries)
                    if let codexSummary = codexSnapshot.summary {
                        latestCodexSummary[provider.id] = codexSummary
                    }
                    if !codexSnapshot.accountSummaries.isEmpty {
                        latestAccountUsage[provider.id] = codexSnapshot.accountSummaries
                    }
                } else if usageProvider == .claude {
                    do {
                        let accounts = try await claudeAccountManager.loadAccounts()
                        let activeID = try await claudeAccountManager.activeAccountID()
                        latestClaudeAccounts[provider.id] = accounts.sorted { lhs, rhs in
                            let lhsActive = lhs.id == activeID
                            let rhsActive = rhs.id == activeID
                            if lhsActive != rhsActive { return lhsActive }
                            return lhs.updatedAt > rhs.updatedAt
                        }
                        if let activeID {
                            latestActiveClaudeAccounts[provider.id] = activeID
                        }
                    } catch {
                        latestClaudeAccounts[provider.id] = []
                    }
                } else if usageProvider == .gemini || usageProvider == .antigravity {
                    do {
                        let accounts = try await geminiAuthStore.listAccounts(provider: usageProvider)
                        let activeID = try await geminiAuthStore.activeAccount(provider: usageProvider)?.id
                        latestGeminiAccounts[provider.id] = accounts.sorted { lhs, rhs in
                            let lhsActive = lhs.id == activeID
                            let rhsActive = rhs.id == activeID
                            if lhsActive != rhsActive { return lhsActive }
                            return lhs.createdAt > rhs.createdAt
                        }
                        if let activeID {
                            latestActiveGeminiAccounts[provider.id] = activeID
                        }
                    } catch {
                        latestGeminiAccounts[provider.id] = []
                    }
                } else if !accountSummaries.isEmpty {
                    latestAccountUsage[provider.id] = accountSummaries
                }
            }
        }
        usageSummaryByProviderID = latestUsage
        accountSummariesByProviderID = latestAccountUsage
        codexAccountSummaryByProviderID = latestCodexSummary
        claudeAccountsByProviderID = latestClaudeAccounts
        activeClaudeAccountIDByProviderID = latestActiveClaudeAccounts
        geminiAccountsByProviderID = latestGeminiAccounts
        activeGeminiAccountIDByProviderID = latestActiveGeminiAccounts
    }
}

struct NolonAccountsView: View {
    @ObservedObject var settings: ProviderSettings
    let onSelectProvider: (Provider.ID) -> Void
    @State private var viewModel: NolonAccountsViewModel
    @State private var selectedWindow: AccountTimeWindow = .d7
    private let accountCardColumns: [GridItem] = [
        GridItem(.adaptive(minimum: 240, maximum: 340), spacing: 12, alignment: .topLeading)
    ]
    private let pageBackground = Color(light: 0x0F0F0F, dark: 0x0F0F0F)
    private let panelBackground = Color(light: 0x1C1C1E, dark: 0x1C1C1E)

    init(settings: ProviderSettings, onSelectProvider: @escaping (Provider.ID) -> Void) {
        self.settings = settings
        self.onSelectProvider = onSelectProvider
        self._viewModel = State(initialValue: NolonAccountsViewModel(settings: settings))
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
        .task(id: settings.providers.map(\.id).joined(separator: ",")) {
            viewModel.refresh()
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            NSLocalizedString("accounts.empty.title", value: "No account providers", comment: "No account providers"),
            systemImage: "person.crop.circle.badge.exclamationmark",
            description: Text(
                NSLocalizedString(
                    "accounts.empty.description",
                    value: "Manage supported provider accounts from one place.",
                    comment: "Accounts subtitle"
                )
            )
        )
        .foregroundStyle(.white)
    }

    private var sectionsContent: some View {
        ForEach(viewModel.sections) { section in
            accountSection(section)
        }
    }

    @ViewBuilder
    private func accountSection(_ section: ProviderPresentationSections.ProviderSection) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            AccountProviderSectionHeader(section: section)

            ForEach(section.providers) { provider in
                accountProviderGroup(provider)
            }
        }
    }

    @ViewBuilder
    private func accountProviderGroup(_ provider: Provider) -> some View {
        let cards = viewModel.accountCards(for: provider)
        let cardCount = max(cards.count, 1)

        VStack(alignment: .leading, spacing: 12) {
            AccountVendorGroupHeader(provider: provider, accountCount: cardCount)
            accountCardGrid(provider: provider, cards: cards)
        }
    }

    @ViewBuilder
    private func accountCardGrid(provider: Provider, cards: [AccountCardViewData]) -> some View {
        LazyVGrid(columns: accountCardColumns, alignment: .leading, spacing: 12) {
            if shouldShowLoadingSkeletons {
                ForEach(0..<skeletonCardCount(for: provider), id: \.self) { _ in
                    UnifiedAccountCardSkeleton(providerName: provider.name)
                }
            } else {
                ForEach(cards) { card in
                    UnifiedAccountCard(
                        data: card,
                        onTap: { _ in onSelectProvider(provider.id) },
                        onAction: { _, _ in onSelectProvider(provider.id) }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var shouldShowLoadingSkeletons: Bool {
        guard viewModel.isRefreshing else { return false }
        return viewModel.usageSummaryByProviderID.isEmpty
            && viewModel.accountSummariesByProviderID.isEmpty
            && viewModel.codexAccountSummaryByProviderID.isEmpty
            && viewModel.claudeAccountsByProviderID.isEmpty
            && viewModel.geminiAccountsByProviderID.isEmpty
    }

    private func skeletonCardCount(for provider: Provider) -> Int {
        switch provider.templateId {
        case ProviderTemplate.codex.rawValue:
            return 2
        default:
            return 1
        }
    }

    private var accountsHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("accounts.title", value: "Account Panorama", comment: "Accounts title"))
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(.white)

                Text(
                    NSLocalizedString(
                        "accounts.empty.description",
                        value: "Unified management for all account-enabled providers.",
                        comment: "Accounts subtitle"
                    )
                )
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(light: 0x636366, dark: 0x636366))
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
                    .foregroundStyle(Color(light: 0xAEAEB2, dark: 0xAEAEB2))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isRefreshing)

                Button {} label: {
                    Text(NSLocalizedString("accounts.action.add_account", value: "+ Add Account", comment: "Add account action"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
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
                .fill(Color.white.opacity(0.08))
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
                    .foregroundStyle(.white)

                Spacer()

                HStack(spacing: 8) {
                    ForEach(AccountTimeWindow.allCases, id: \.self) { window in
                        Button {
                            selectedWindow = window
                        } label: {
                            Text(window.label)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(selectedWindow == window ? .white : Color(light: 0xAEAEB2, dark: 0xAEAEB2))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(selectedWindow == window ? Color.white.opacity(0.14) : Color.white.opacity(0.05))
                                )
                        }
                        .buttonStyle(.plain)
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
                                .fill(Color.white.opacity(0.06))
                                .frame(width: 32, height: 124)
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(item.color)
                                .frame(width: 32, height: item.height)
                        }
                        Text(item.label)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(light: 0xAEAEB2, dark: 0xAEAEB2))
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
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var dashboardRankingPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(NSLocalizedString("accounts.dashboard.ranking", value: "Provider Ranking", comment: "Provider ranking panel"))
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)

            ForEach(rankingItems(), id: \.id) { item in
                HStack(spacing: 10) {
                    Text(item.name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(light: 0xAEAEB2, dark: 0xAEAEB2))
                        .frame(width: 78, alignment: .leading)

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.08))
                            Capsule(style: .continuous)
                                .fill(item.color)
                                .frame(width: max(8, proxy.size.width * CGFloat(item.ratio)))
                        }
                    }
                    .frame(height: 6)

                    Text(item.valueText)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
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
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
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

private struct AccountProviderSectionHeader: View {
    let section: ProviderPresentationSections.ProviderSection

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(accent)
                .frame(width: 28, height: 28)
                .overlay(
                    Text(shortLabel)
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(.white)
                )

            Text(NSLocalizedString(section.titleKey, value: section.fallbackTitle, comment: "Account provider section"))
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(.white)

            Spacer()

            Text("\(section.providers.count) \(NSLocalizedString("accounts.section.accounts", value: "accounts", comment: "accounts unit"))")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(light: 0x636366, dark: 0x636366))
        }
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
    }

    private var shortLabel: String {
        let title = NSLocalizedString(section.titleKey, value: section.fallbackTitle, comment: "Account provider section")
        return String(title.prefix(1)).uppercased()
    }

    private var accent: Color {
        switch section.id {
        case .originalVendors:
            return DesignSystem.Colors.primary
        case .integratedVendors:
            return DesignSystem.Colors.secondary
        case .projects:
            return Color(light: 0x34C759, dark: 0x34C759)
        }
    }
}


private struct AccountVendorGroupHeader: View {
    let provider: Provider
    let accountCount: Int

    private var template: ProviderTemplate? {
        guard let templateId = provider.templateId else { return nil }
        return ProviderTemplate(rawValue: templateId)
    }

    var body: some View {
        HStack(spacing: 10) {
            if let template {
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
                .foregroundStyle(.white)

            Spacer()

            Text(
                String(
                    format: NSLocalizedString("accounts.section.accounts_count", value: "%d accounts", comment: "Accounts count in provider group"),
                    accountCount
                )
            )
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Color(light: 0x636366, dark: 0x636366))
        }
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

extension NolonAccountsViewModel {
    static func mapUsageProvider(for provider: Provider) -> UsageProvider? {
        if provider.templateId == ProviderTemplate.codexXcode.rawValue {
            return nil
        }
        if provider.templateId == ProviderTemplate.claudeCode.rawValue {
            return .claude
        }

        guard let templateId = provider.templateId else { return nil }
        return UsageProvider(rawValue: templateId)
    }

    static func makeUsageSummary(
        provider _: Provider,
        usageProvider: UsageProvider,
        outcomes: [ProviderAccountUsageOutcome]
    ) -> UsageSummary? {
        guard !outcomes.isEmpty else { return nil }

        let snapshotService = ProviderUsageSnapshotService()
        let snapshotItems = outcomes.map { outcome in
            let status: ProviderUsageOutcomeStatus
            let updatedAt: Date?

            switch outcome.outcome.result {
            case let .success(result):
                status = .success
                updatedAt = result.usage.updatedAt
            case .failure:
                status = .failure
                updatedAt = nil
            }

            return ProviderUsageSnapshotItem(
                id: outcome.id,
                status: status,
                updatedAt: updatedAt,
                hasCredits: false
            )
        }
        let aggregate = snapshotService.aggregate(items: snapshotItems)

        let firstSuccess = outcomes.compactMap { outcome -> ProviderFetchResult? in
            guard case let .success(result) = outcome.outcome.result else { return nil }
            return result
        }.first

        let rawAccountEmail = firstSuccess?.usage.identity?.accountEmail
        let trimmedAccountEmail = rawAccountEmail?.trimmingCharacters(in: .whitespacesAndNewlines)
        let accountEmail = (trimmedAccountEmail?.isEmpty == false) ? trimmedAccountEmail : nil

        return UsageSummary(
            provider: usageProvider,
            totalCount: aggregate.totalCount,
            successCount: aggregate.successCount,
            failureCount: aggregate.failureCount,
            latestUpdatedAt: aggregate.latestUpdatedAt,
            accountEmail: accountEmail,
            primaryUsedPercent: firstSuccess?.usage.primary?.usedPercent
        )
    }

    static func makeAccountSummaries(
        outcomes: [ProviderAccountUsageOutcome]
    ) -> [AccountUsageSummary] {
        outcomes.map { outcome in
            let accountLabel: String = switch outcome.account {
            case .default:
                NSLocalizedString("accounts.account.default", value: "Default", comment: "Default account label")
            case let .tokenAccount(account):
                account.displayName
            }

            switch outcome.outcome.result {
            case let .success(result):
                let rawEmail = result.usage.identity?.accountEmail?.trimmingCharacters(in: .whitespacesAndNewlines)
                let accountEmail = (rawEmail?.isEmpty == false) ? rawEmail : nil
                return AccountUsageSummary(
                    id: outcome.id,
                    accountLabel: accountLabel,
                    accountEmail: accountEmail,
                    plan: result.usage.identity?.plan,
                    totalCount: 1,
                    successCount: 1,
                    failureCount: 0,
                    latestUpdatedAt: result.usage.updatedAt,
                    primaryUsedPercent: result.usage.primary?.usedPercent,
                    errorMessage: nil,
                    isSnapshotOnly: false
                )
            case let .failure(error):
                return AccountUsageSummary(
                    id: outcome.id,
                    accountLabel: accountLabel,
                    accountEmail: nil,
                    plan: nil,
                    totalCount: 1,
                    successCount: 0,
                    failureCount: 1,
                    latestUpdatedAt: nil,
                    primaryUsedPercent: nil,
                    errorMessage: error.localizedDescription,
                    isSnapshotOnly: false
                )
            }
        }
    }

    static func mergeCodexSnapshotAccounts(
        liveSummaries: [AccountUsageSummary],
        accounts: [CodexAuthAccount],
        summaries: [UUID: CodexAuthSummary],
        activeAccountID: UUID?,
        providerAuthSummary: CodexAuthSummary?
    ) -> [AccountUsageSummary] {
        let liveDefault = liveSummaries.first(where: { $0.id == "codex.default" })
        let extraLiveAccounts = liveSummaries.filter { $0.id != "codex.default" }

        let snapshotAccounts: [AccountUsageSummary] = accounts.map { account in
            let summary = summaries[account.id]
            let fallbackStem = URL(fileURLWithPath: account.relativeAuthPath).deletingPathExtension().lastPathComponent
            let displayName = summary?.preferredDisplayName(fallbackFileStem: fallbackStem) ?? account.name
            let activeLiveSummary = (account.id == activeAccountID) ? liveDefault : nil
            let latestSnapshotDate = summary?.lastSyncSucceededAt ?? summary?.lastLoginAt
            let failureMessage = activeLiveSummary?.errorMessage ?? summary?.lastSyncFailureMessage

            return AccountUsageSummary(
                id: account.id.uuidString,
                accountLabel: displayName,
                accountEmail: summary?.email,
                plan: summary?.plan,
                totalCount: activeLiveSummary?.totalCount ?? 0,
                successCount: activeLiveSummary?.successCount ?? 0,
                failureCount: activeLiveSummary?.failureCount ?? 0,
                latestUpdatedAt: activeLiveSummary?.latestUpdatedAt ?? latestSnapshotDate,
                primaryUsedPercent: activeLiveSummary?.primaryUsedPercent,
                errorMessage: failureMessage,
                isSnapshotOnly: activeLiveSummary == nil
            )
        }

        if let providerAuthSummary,
           snapshotAccounts.isEmpty,
           let liveDefault
        {
            return [
                AccountUsageSummary(
                    id: liveDefault.id,
                    accountLabel: providerAuthSummary.preferredDisplayName(fallbackFileStem: "auth"),
                    accountEmail: providerAuthSummary.email ?? liveDefault.accountEmail,
                    plan: providerAuthSummary.plan ?? liveDefault.plan,
                    totalCount: liveDefault.totalCount,
                    successCount: liveDefault.successCount,
                    failureCount: liveDefault.failureCount,
                    latestUpdatedAt: liveDefault.latestUpdatedAt,
                    primaryUsedPercent: liveDefault.primaryUsedPercent,
                    errorMessage: liveDefault.errorMessage ?? providerAuthSummary.lastSyncFailureMessage,
                    isSnapshotOnly: false
                )
            ] + extraLiveAccounts
        }

        if snapshotAccounts.isEmpty {
            return liveSummaries
        }

        return snapshotAccounts + extraLiveAccounts
    }

    private static func makeCodexAccountSummary(
        activeAccountID: UUID?,
        accounts: [CodexAuthAccount],
        summaries: [UUID: CodexAuthSummary],
        providerAuthSummary: CodexAuthSummary?
    ) -> CodexAccountSummary? {
        if let activeAccountID,
           let active = summaries[activeAccountID]
        {
            return CodexAccountSummary(
                accountEmail: active.email,
                plan: active.plan
            )
        }

        if let first = accounts.first,
           let summary = summaries[first.id]
        {
            return CodexAccountSummary(
                accountEmail: summary.email,
                plan: summary.plan
            )
        }

        if let providerAuthSummary {
            return CodexAccountSummary(
                accountEmail: providerAuthSummary.email,
                plan: providerAuthSummary.plan
            )
        }

        return nil
    }

    private func loadCodexSnapshotAccounts(
        for provider: Provider,
        liveSummaries: [AccountUsageSummary]
    ) async -> (summary: CodexAccountSummary?, accountSummaries: [AccountUsageSummary]) {
        let accounts = (try? await codexAuthManager.loadAccounts()) ?? []
        var summaries: [UUID: CodexAuthSummary] = [:]

        for account in accounts {
            let authFile = await codexAuthManager.accountAuthFile(account)
            guard let data = try? authFile.data() else { continue }
            summaries[account.id] = CodexAuthSummary.fromJSONData(data)
        }

        let activeAccountID = await codexAuthManager.activeAccountId(for: provider)
        let providerAuthSummary: CodexAuthSummary?
        if let providerAuthFile = await codexAuthManager.authFile(for: provider),
           let providerAuthData = try? providerAuthFile.data()
        {
            providerAuthSummary = CodexAuthSummary.fromJSONData(providerAuthData)
        } else {
            providerAuthSummary = nil
        }

        let summary = Self.makeCodexAccountSummary(
            activeAccountID: activeAccountID,
            accounts: accounts,
            summaries: summaries,
            providerAuthSummary: providerAuthSummary
        )
        let accountSummaries = Self.mergeCodexSnapshotAccounts(
            liveSummaries: liveSummaries,
            accounts: accounts,
            summaries: summaries,
            activeAccountID: activeAccountID,
            providerAuthSummary: providerAuthSummary
        )
        return (summary, accountSummaries)
    }

    func accountCards(for provider: Provider) -> [AccountCardViewData] {
        guard let usageProvider = Self.mapUsageProvider(for: provider) else {
            return [emptyCard(provider: provider)]
        }

        switch usageProvider {
        case .claude:
            let accounts = claudeAccountsByProviderID[provider.id] ?? []
            if accounts.isEmpty {
                return [emptyCard(provider: provider)]
            }
            let activeID = activeClaudeAccountIDByProviderID[provider.id]
            return accounts.map { account in
                let record = AccountRecordBuilder.claude(
                    providerName: provider.name,
                    account: account,
                    isActive: account.id == activeID
                )
                return AccountCardViewDataMapper.map(record: record)
            }
        case .gemini, .antigravity:
            let accounts = geminiAccountsByProviderID[provider.id] ?? []
            if accounts.isEmpty {
                return [emptyCard(provider: provider)]
            }
            let activeID = activeGeminiAccountIDByProviderID[provider.id]
            let liveSummary = accountSummariesByProviderID[provider.id]?.first
            return accounts.map { account in
                let isActive = account.id == activeID
                let quota: AccountRecordQuota? = {
                    if isActive, let liveSummary {
                        return .init(
                            provider: usageProvider,
                            accountTitle: account.email ?? account.name,
                            usage: UsageSnapshot(
                                identity: UsageIdentity(
                                    accountEmail: liveSummary.accountEmail ?? account.email,
                                    accountOrganization: account.project,
                                    loginMethod: account.method.rawValue,
                                    plan: liveSummary.plan
                                ),
                                primary: liveSummary.primaryUsedPercent.map { RateWindow(usedPercent: $0) },
                                secondary: nil,
                                tertiary: nil,
                                updatedAt: liveSummary.latestUpdatedAt ?? account.lastLoginAt ?? account.createdAt
                            ),
                            credits: nil,
                            creditsRefreshedAt: nil,
                            loginAt: account.lastLoginAt,
                            syncedAt: liveSummary.latestUpdatedAt,
                            isLoading: false,
                            showsEmptyState: liveSummary.totalCount == 0,
                            errorMessage: liveSummary.errorMessage
                        )
                    }
                    return nil
                }()

                let record = AccountRecordBuilder.gemini(
                    providerName: provider.name,
                    account: account,
                    isActive: isActive,
                    quota: quota
                )
                return AccountCardViewDataMapper.map(record: record)
            }
        default:
            let summaries = accountSummariesByProviderID[provider.id] ?? []
            if summaries.isEmpty {
                return [emptyCard(provider: provider)]
            }
            return summaries.map { summary in
                let record = AccountRecordBuilder.codexAccounts(
                    providerName: provider.name,
                    usageProvider: usageProvider,
                    summary: summary
                )
                return AccountCardViewDataMapper.map(record: record)
            }
        }
    }

    private func emptyCard(provider: Provider) -> AccountCardViewData {
        let usageProvider = Self.mapUsageProvider(for: provider) ?? .codex
        let record = AccountRecordBuilder.empty(
            providerName: provider.name,
            usageProvider: usageProvider,
            providerID: provider.id
        )
        return AccountCardViewDataMapper.map(record: record)
    }
}
