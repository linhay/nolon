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
import OSLog
import NolonUIFoundation

@MainActor
@Observable
final class NolonAccountsViewModel: CopyToastPresenting {
    private static let logger = Logger(subsystem: "com.nolon", category: "NolonAccountsViewModel")
    typealias CodexActivateAction = @Sendable (CodexAuthAccount, Provider) async throws -> Void
    typealias CopyTextAction = @Sendable (String) -> Void
    typealias OpenURLAction = @Sendable (URL) -> Void
    typealias ProviderUsageAccountsViewModelFactory = @MainActor @Sendable (Provider) -> ProviderUsageAccountsViewModel
    typealias ProviderTokenTrendFetchAction = @Sendable (UsageProvider) async throws -> ProviderTokenTrendSnapshot?

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

    struct DashboardTrendSample: Identifiable, Sendable, Equatable {
        let id: String
        let label: String
        let totalTokens: Int
    }

    private(set) var settings: ProviderSettings
    private let usageMonitor: ProviderUsageMonitorService
    private let usageSettingsStore: UsageMonitorSettingsStore
    private let codexAuthManager: CodexAuthManager
    private let codexActivateAction: CodexActivateAction
    private let copyTextAction: CopyTextAction
    private let openURLAction: OpenURLAction
    private let providerUsageAccountsViewModelFactory: ProviderUsageAccountsViewModelFactory
    @ObservationIgnored private let providerTokenTrendFetchAction: ProviderTokenTrendFetchAction
    @ObservationIgnored private var providerUsageAccountsViewModelsByProviderID: [Provider.ID: ProviderUsageAccountsViewModel] = [:]

    var usageSummaryByProviderID: [Provider.ID: UsageSummary] = [:]
    var tokenTrendPointsByProviderID: [Provider.ID: [ProviderTokenTrendPoint]] = [:]
    var accountSummariesByProviderID: [Provider.ID: [AccountUsageSummary]] = [:]
    var codexAccountSummaryByProviderID: [Provider.ID: CodexAccountSummary] = [:]
    var activeCodexAccountIDByProviderID: [Provider.ID: UUID] = [:]
    var claudeAccountsByProviderID: [Provider.ID: [ClaudeAccount]] = [:]
    var activeClaudeAccountIDByProviderID: [Provider.ID: UUID] = [:]
    var geminiAccountsByProviderID: [Provider.ID: [GeminiAuthAccount]] = [:]
    var activeGeminiAccountIDByProviderID: [Provider.ID: UUID] = [:]
    var isRefreshing = false
    var isShowingCopyToast = false
    var copyToastMessage = CopyToastSupport.message
    @ObservationIgnored var copyToastTask: Task<Void, Never>?

    init(
        settings: ProviderSettings,
        usageMonitor: ProviderUsageMonitorService? = nil,
        usageSettingsStore: UsageMonitorSettingsStore? = nil,
        codexAuthManager: CodexAuthManager = .shared,
        codexActivateAction: CodexActivateAction? = nil,
        copyTextAction: CopyTextAction? = nil,
        openURLAction: OpenURLAction? = nil,
        providerUsageViewModelFactory: ProviderUsageAccountsViewModelFactory? = nil,
        providerTokenTrendFetchAction: ProviderTokenTrendFetchAction? = nil
    ) {
        let hasCustomViewModelDependencies = usageMonitor != nil || codexActivateAction != nil
        let tokenStore = FileTokenAccountStore(fileURL: ProviderUsagePaths.defaultTokenAccountsFileURL())
        let resolvedUsageMonitor = usageMonitor ?? ProviderUsageMonitorService(tokenAccountStore: tokenStore)
        let resolvedCodexActivateAction = codexActivateAction ?? { account, provider in
            try await CodexAuthActivationCoordinator.shared.activate(account: account, provider: provider)
        }

        self.settings = settings
        self.usageMonitor = resolvedUsageMonitor
        self.usageSettingsStore = usageSettingsStore ?? .shared
        self.codexAuthManager = codexAuthManager
        self.codexActivateAction = resolvedCodexActivateAction
        self.copyTextAction = copyTextAction ?? { text in
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
        self.openURLAction = openURLAction ?? { url in
            NSWorkspace.shared.open(url)
        }
        self.providerTokenTrendFetchAction = providerTokenTrendFetchAction ?? { provider in
            try await ProviderUsageRegistry.fetchTokenTrendSnapshot(
                for: provider,
                trailingDays: nil
            )
        }
        if let providerUsageViewModelFactory {
            self.providerUsageAccountsViewModelFactory = providerUsageViewModelFactory
        } else if hasCustomViewModelDependencies {
            self.providerUsageAccountsViewModelFactory = { provider in
                ProviderUsageRootViewModel(
                    provider: provider,
                    usageMonitor: resolvedUsageMonitor,
                    codexActivateAction: resolvedCodexActivateAction
                ).accountsViewModel
            }
        } else {
            self.providerUsageAccountsViewModelFactory = { provider in
                ProviderUsageRootViewModelStore.shared.viewModel(for: provider).accountsViewModel
            }
        }
    }

    nonisolated deinit {}

    var sections: [ProviderPresentationSections.ProviderSection] {
        ProviderPresentationSections.accountProviders(from: settings.providers)
    }

    func updateSettings(_ settings: ProviderSettings) {
        self.settings = settings
        // Provider payload may change while keeping same id (e.g. template/path migration).
        // Rebuild child VMs to avoid stale provider context.
        providerUsageAccountsViewModelsByProviderID.removeAll()
        tokenTrendPointsByProviderID.removeAll()
    }

    func refresh() {
        Task {
            await refreshAsync()
        }
    }

    private func refreshAsync() async {
        isRefreshing = true
        defer { isRefreshing = false }
        let sqlitePath = codexAuthManager.accountsSQLiteFile().url.path

        var latestUsage: [Provider.ID: UsageSummary] = [:]
        var latestTokenTrendPoints: [Provider.ID: [ProviderTokenTrendPoint]] = [:]
        var latestAccountUsage: [Provider.ID: [AccountUsageSummary]] = [:]
        var latestCodexSummary: [Provider.ID: CodexAccountSummary] = [:]
        var latestActiveCodexAccounts: [Provider.ID: UUID] = [:]
        var latestClaudeAccounts: [Provider.ID: [ClaudeAccount]] = [:]
        var latestActiveClaudeAccounts: [Provider.ID: UUID] = [:]
        var latestGeminiAccounts: [Provider.ID: [GeminiAuthAccount]] = [:]
        var latestActiveGeminiAccounts: [Provider.ID: UUID] = [:]

        for section in sections {
            for provider in section.providers {
                let accountsViewModel = providerUsageAccountsViewModel(for: provider)
                guard let usageProvider = accountsViewModel.usageProvider else { continue }
                accountsViewModel.settings = usageSettingsStore.settings(for: provider)
                await accountsViewModel.load()
                let outcomes = accountsViewModel.outcomes
                if let points = await Self.loadTokenTrendPoints(
                    providerID: provider.id,
                    usageProvider: usageProvider,
                    fetchAction: providerTokenTrendFetchAction
                ) {
                    latestTokenTrendPoints[provider.id] = points
                }

                let accountSummaries = Self.makeAccountSummaries(outcomes: outcomes)
                if let summary = Self.makeUsageSummary(provider: provider, usageProvider: usageProvider, outcomes: outcomes) {
                    latestUsage[provider.id] = summary
                }

                if usageProvider == .codex {
                    Self.logger.info(
                        "Accounts refresh(codex) begin. providerID=\(provider.id, privacy: .public) templateID=\(provider.templateId ?? "-", privacy: .public) sqlite=\(sqlitePath, privacy: .public) loadedAccounts=\(accountsViewModel.codex.accounts.count, privacy: .public) loadedOutcomes=\(accountsViewModel.codex.accountOutcomes.count, privacy: .public)"
                    )
                    let codexSummary = Self.makeCodexAccountSummary(
                        activeAccountID: accountsViewModel.codex.activeAccountId,
                        accounts: accountsViewModel.codex.accounts,
                        summaries: accountsViewModel.codex.accountSummaries,
                        providerAuthSummary: nil
                    )
                    if let codexSummary {
                        latestCodexSummary[provider.id] = codexSummary
                    }
                    if let activeID = accountsViewModel.codex.activeAccountId {
                        latestActiveCodexAccounts[provider.id] = activeID
                    }
                    let mergedAccountSummaries = Self.mergeCodexSnapshotAccounts(
                        liveSummaries: accountSummaries,
                        accounts: accountsViewModel.codex.accounts,
                        summaries: accountsViewModel.codex.accountSummaries,
                        activeAccountID: accountsViewModel.codex.activeAccountId,
                        providerAuthSummary: nil
                    )
                    if !mergedAccountSummaries.isEmpty {
                        latestAccountUsage[provider.id] = mergedAccountSummaries
                    }
                    Self.logger.info(
                        "Accounts refresh(codex) end. providerID=\(provider.id, privacy: .public) mergedSummaries=\(mergedAccountSummaries.count, privacy: .public) activeAccountID=\(accountsViewModel.codex.activeAccountId?.uuidString ?? "-", privacy: .public)"
                    )
                } else if usageProvider == .claude {
                    let sortedAccounts = Self.sortedProviderAccounts(
                        accountsViewModel.claude.accounts,
                        isActive: { accountsViewModel.claude.isActiveAccount($0) }
                    )
                    latestClaudeAccounts[provider.id] = sortedAccounts
                    if let activeID = Self.activeProviderAccountID(
                        from: sortedAccounts,
                        isActive: { accountsViewModel.claude.isActiveAccount($0) }
                    ) {
                        latestActiveClaudeAccounts[provider.id] = activeID
                    }
                } else if usageProvider == .gemini || usageProvider == .antigravity {
                    let sortedAccounts = Self.sortedProviderAccounts(
                        accountsViewModel.gemini.accounts,
                        isActive: { accountsViewModel.gemini.isActiveAccount($0) }
                    )
                    latestGeminiAccounts[provider.id] = sortedAccounts
                    if let activeID = Self.activeProviderAccountID(
                        from: sortedAccounts,
                        isActive: { accountsViewModel.gemini.isActiveAccount($0) }
                    ) {
                        latestActiveGeminiAccounts[provider.id] = activeID
                    }
                } else if !accountSummaries.isEmpty {
                    latestAccountUsage[provider.id] = accountSummaries
                }
            }
        }
        usageSummaryByProviderID = latestUsage
        tokenTrendPointsByProviderID = latestTokenTrendPoints
        accountSummariesByProviderID = latestAccountUsage
        codexAccountSummaryByProviderID = latestCodexSummary
        activeCodexAccountIDByProviderID = latestActiveCodexAccounts
        claudeAccountsByProviderID = latestClaudeAccounts
        activeClaudeAccountIDByProviderID = latestActiveClaudeAccounts
        geminiAccountsByProviderID = latestGeminiAccounts
        activeGeminiAccountIDByProviderID = latestActiveGeminiAccounts
        Self.logger.info(
            "Accounts refresh completed. sections=\(self.sections.count, privacy: .public) codexProviders=\(latestCodexSummary.count, privacy: .public) codexAccountGroups=\(latestAccountUsage.filter { key, _ in self.settings.providers.first(where: { $0.id == key })?.templateId == ProviderTemplate.codex.rawValue }.count, privacy: .public)"
        )
    }

    func activateCodexAccount(id: UUID, for provider: Provider) async {
        do {
            let accountsViewModel = providerUsageAccountsViewModel(for: provider)
            _ = await accountsViewModel.loadIfNeeded()
            if await accountsViewModel.codex.activateAccount(id: id) {
                await refreshAsync()
            } else {
                let accounts = try await codexAuthManager.loadAccounts()
                guard let account = accounts.first(where: { $0.id == id }) else { return }
                try await codexActivateAction(account, provider)
                await refreshAsync()
            }
        } catch {
        }
    }

    func copyCodexAccountID(_ id: UUID) {
        copyTextAction(id.uuidString.lowercased())
        showCopyToast()
    }

    func copyCodexAccountPath(_ id: UUID) async {
        guard let accounts = try? await codexAuthManager.loadAccounts(),
              let account = accounts.first(where: { $0.id == id })
        else { return }
        copyTextAction(account.relativeAuthPath)
        showCopyToast()
    }

    func copyCodexAccountAuthJSON(_ id: UUID) async {
        guard let accounts = try? await codexAuthManager.loadAccounts(),
              let account = accounts.first(where: { $0.id == id })
        else { return }
        guard let data = codexAuthManager.accountAuthDataWithoutMaterialization(for: account),
              let raw = CodexAuthInspectionSupport.rawJSONString(from: data)
        else { return }
        copyTextAction(raw)
        showCopyToast()
    }

    func editCodexAccountAuthJSON(_ id: UUID) async {
        guard let accounts = try? await codexAuthManager.loadAccounts(),
              let account = accounts.first(where: { $0.id == id })
        else { return }
        guard let data = codexAuthManager.accountAuthData(for: account),
              let url = CodexAuthInspectionSupport.writeInspectionFile(accountID: account.id, data: data)
        else { return }
        openURLAction(url)
    }

    private func providerUsageAccountsViewModel(for provider: Provider) -> ProviderUsageAccountsViewModel {
        if let cached = providerUsageAccountsViewModelsByProviderID[provider.id] {
            return cached
        }
        let created = providerUsageAccountsViewModelFactory(provider)
        providerUsageAccountsViewModelsByProviderID[provider.id] = created
        return created
    }
}

extension NolonAccountsViewModel {
    private static func sortedProviderAccounts<Account: ProviderAccountRecordConvertible & Identifiable>(
        _ accounts: [Account],
        isActive: (Account) -> Bool
    ) -> [Account] where Account.ID == UUID {
        accounts.sorted { lhs, rhs in
            let lhsActive = isActive(lhs)
            let rhsActive = isActive(rhs)
            if lhsActive != rhsActive { return lhsActive }
            return lhs.accountSortDate > rhs.accountSortDate
        }
    }

    private static func activeProviderAccountID<Account: ProviderAccountRecordConvertible & Identifiable>(
        from accounts: [Account],
        isActive: (Account) -> Bool
    ) -> UUID? where Account.ID == UUID {
        accounts.first(where: { isActive($0) })?.id
    }

    private func makeProviderAccountCards<Account: ProviderAccountRecordConvertible & Identifiable>(
        provider: Provider,
        accounts: [Account],
        activeID: UUID?,
        quota: (Account, Bool) -> AccountRecordQuota? = { _, _ in nil }
    ) -> [AccountCardViewData] where Account.ID == UUID {
        guard !accounts.isEmpty else {
            return [emptyCard(provider: provider)]
        }
        return accounts.map { account in
            let isActive = account.id == activeID
            let record = AccountRecordBuilder.providerAccount(
                providerName: provider.name,
                account: account,
                isActive: isActive,
                quota: quota(account, isActive)
            )
            return AccountCardViewDataMapper.map(record: record)
        }
    }

    private func makeSummaryUsageCards(
        provider: Provider,
        usageProvider: UsageProvider,
        summaries: [AccountUsageSummary]
    ) -> [AccountCardViewData] {
        guard !summaries.isEmpty else {
            return [emptyCard(provider: provider)]
        }

        let supportsCodexSwitching = usageProvider == .codex
        let activeID = supportsCodexSwitching ? activeCodexAccountIDByProviderID[provider.id] : nil

        return summaries.map { summary in
            let accountID = supportsCodexSwitching
                ? Self.resolveCodexAccountID(from: summary.id)
                : nil
            let isActive = accountID == activeID
            let canOperateOnSnapshot = supportsCodexSwitching && accountID != nil
            let record = AccountRecordBuilder.summaryUsageAccount(
                providerName: provider.name,
                usageProvider: usageProvider,
                summary: summary,
                isActive: isActive
            )
            return AccountCardViewDataMapper.map(
                record: record,
                primaryActions: !isActive && canOperateOnSnapshot ? [
                    CodexAccountActionFactory.primaryActivateAction()
                ] : [],
                menuActions: canOperateOnSnapshot ? [
                    CodexAccountActionFactory.menuCopyAccountIDAction(),
                    CodexAccountActionFactory.menuCopyAuthPathAction(),
                    CodexAccountActionFactory.menuCopyAuthJSONAction(),
                    CodexAccountActionFactory.menuEditAuthJSONAction()
                ] : [],
                tapBehavior: !isActive && canOperateOnSnapshot ? .activate : .openProvider
            )
        }
    }

    static func filteredAccountCards(
        _ cards: [AccountCardViewData],
        hideZeroQuotaAccounts: Bool,
        hideErroredAccounts: Bool
    ) -> [AccountCardViewData] {
        cards.filter { card in
            if hideZeroQuotaAccounts, shouldHideCardForZeroQuota(card) {
                return false
            }
            if hideErroredAccounts, shouldHideCardForError(card) {
                return false
            }
            return true
        }
    }

    static func visibleAccountCount(in cards: [AccountCardViewData]) -> Int {
        cards.filter { !isPlaceholderCard($0) }.count
    }

    private static func shouldHideCardForZeroQuota(_ card: AccountCardViewData) -> Bool {
        guard case let .quota(quota) = card.body,
              let usage = quota.usage,
              let window = longestQuotaWindow(from: usage)
        else {
            return false
        }
        return window.remainingPercent <= 0
    }

    private static func shouldHideCardForError(_ card: AccountCardViewData) -> Bool {
        guard case let .quota(quota) = card.body else { return false }
        guard let message = quota.errorMessage?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return false
        }
        return !message.isEmpty
    }

    private static func longestQuotaWindow(from usage: UsageSnapshot) -> RateWindow? {
        let explicitWindow = usage.allWindows
            .map(\.window)
            .filter { ($0.windowMinutes ?? 0) > 0 }
            .max { lhs, rhs in
                (lhs.windowMinutes ?? 0) < (rhs.windowMinutes ?? 0)
            }
        if let explicitWindow {
            return explicitWindow
        }
        return usage.primary ?? usage.secondary ?? usage.tertiary
    }

    private static func isPlaceholderCard(_ card: AccountCardViewData) -> Bool {
        card.recordID.rawValue.hasSuffix(".empty")
    }

    nonisolated static func resolveCodexAccountID(from summaryID: String) -> UUID? {
        if let directID = UUID(uuidString: summaryID) {
            return directID
        }

        let components = summaryID.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: true)
        guard components.count == 2 else { return nil }
        return UUID(uuidString: String(components[1]))
    }

    static func mapUsageProvider(for provider: Provider) -> UsageProvider? {
        if provider.templateId == ProviderTemplate.codexXcode.rawValue {
            return .codex
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

        let accountEmail = TextNormalizationSupport.trimmed(firstSuccess?.usage.identity?.accountEmail)

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

    func trendPanelSamples(
        for window: AccountTimeWindow,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [AccountTrendSampleData] {
        let samples = Self.makeDashboardTrendSamples(
            pointsByProviderID: tokenTrendPointsByProviderID,
            window: window,
            now: now,
            calendar: calendar
        )
        let maxValue = max(samples.map(\.totalTokens).max() ?? 0, 1)

        return samples.enumerated().map { index, sample in
            AccountTrendSampleData(
                id: sample.id,
                label: sample.label,
                heightRatio: Double(sample.totalTokens) / Double(maxValue),
                opacity: Self.dashboardTrendOpacity(index: index, count: samples.count)
            )
        }
    }

    static func makeDashboardTrendSamples(
        pointsByProviderID: [Provider.ID: [ProviderTokenTrendPoint]],
        window: AccountTimeWindow,
        now: Date = Date(),
        calendar: Calendar = .current,
        maximumBars: Int = 7
    ) -> [DashboardTrendSample] {
        let normalizedCalendar = Self.normalizedCalendar(calendar)
        let totalsByDay = aggregateTokenTotalsByDay(pointsByProviderID: pointsByProviderID)
        let dayKeys = makeWindowDayKeys(
            totalsByDay: totalsByDay,
            window: window,
            now: now,
            calendar: normalizedCalendar
        )
        guard !dayKeys.isEmpty else { return [] }

        let dailyValues = dayKeys.map { dayKey in
            (dayKey: dayKey, totalTokens: totalsByDay[dayKey] ?? 0)
        }
        let groups = chunkedDailyValues(dailyValues, maximumBars: maximumBars)

        return groups.enumerated().map { index, group in
            DashboardTrendSample(
                id: "trend-\(index)",
                label: dashboardTrendLabel(for: group, now: now, calendar: normalizedCalendar),
                totalTokens: group.reduce(0) { $0 + $1.totalTokens }
            )
        }
    }

    private static func loadTokenTrendPoints(
        providerID: Provider.ID,
        usageProvider: UsageProvider,
        fetchAction: ProviderTokenTrendFetchAction
    ) async -> [ProviderTokenTrendPoint]? {
        guard supportsDashboardTrend(for: usageProvider) else { return nil }
        do {
            let snapshot = try await fetchAction(usageProvider)
            let points = snapshot?.points.sorted { $0.date < $1.date } ?? []
            return points.isEmpty ? nil : points
        } catch {
            logger.error(
                "Accounts refresh(token trend) failed. providerID=\(providerID, privacy: .public) usageProvider=\(usageProvider.rawValue, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    private static func supportsDashboardTrend(for usageProvider: UsageProvider) -> Bool {
        switch usageProvider {
        case .codex, .claude, .gemini, .antigravity:
            return true
        default:
            return false
        }
    }

    private static func aggregateTokenTotalsByDay(
        pointsByProviderID: [Provider.ID: [ProviderTokenTrendPoint]]
    ) -> [String: Int] {
        var totalsByDay: [String: Int] = [:]
        for points in pointsByProviderID.values {
            for point in points {
                totalsByDay[point.date, default: 0] += point.totalTokens
            }
        }
        return totalsByDay
    }

    private static func makeWindowDayKeys(
        totalsByDay: [String: Int],
        window: AccountTimeWindow,
        now: Date,
        calendar: Calendar
    ) -> [String] {
        let today = calendar.startOfDay(for: now)
        let dayCount: Int
        if let windowDayCount = window.dayCount {
            dayCount = max(1, windowDayCount)
        } else if let earliest = totalsByDay.keys.sorted().first,
                  let earliestDate = dayKeyFormatter(calendar: calendar).date(from: earliest)
        {
            let components = calendar.dateComponents([.day], from: earliestDate, to: today)
            dayCount = max(1, (components.day ?? 0) + 1)
        } else {
            dayCount = 7
        }

        let formatter = dayKeyFormatter(calendar: calendar)
        return (0..<dayCount).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset - (dayCount - 1), to: today) else {
                return nil
            }
            return formatter.string(from: date)
        }
    }

    private static func chunkedDailyValues(
        _ dailyValues: [(dayKey: String, totalTokens: Int)],
        maximumBars: Int
    ) -> [[(dayKey: String, totalTokens: Int)]] {
        let barLimit = max(1, maximumBars)
        guard dailyValues.count > barLimit else {
            return dailyValues.map { [$0] }
        }

        let chunkSize = Int(ceil(Double(dailyValues.count) / Double(barLimit)))
        return stride(from: 0, to: dailyValues.count, by: chunkSize).map { start in
            Array(dailyValues[start..<min(start + chunkSize, dailyValues.count)])
        }
    }

    private static func dashboardTrendLabel(
        for group: [(dayKey: String, totalTokens: Int)],
        now: Date,
        calendar: Calendar
    ) -> String {
        guard let first = group.first?.dayKey,
              let last = group.last?.dayKey
        else {
            return "-"
        }

        let todayKey = dayKeyFormatter(calendar: calendar).string(from: calendar.startOfDay(for: now))
        if group.count == 1, last == todayKey {
            return NSLocalizedString("accounts.dashboard.today", value: "Today", comment: "Today label")
        }

        let firstLabel = shortDateLabel(first)
        let lastLabel = shortDateLabel(last)
        if first == last {
            return lastLabel
        }
        return "\(firstLabel)-\(lastLabel)"
    }

    private static func shortDateLabel(_ dayKey: String) -> String {
        let parts = dayKey.split(separator: "-", omittingEmptySubsequences: true)
        guard parts.count == 3 else { return dayKey }
        return "\(parts[1])/\(parts[2])"
    }

    private static func dayKeyFormatter(calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private static func normalizedCalendar(_ calendar: Calendar) -> Calendar {
        var value = calendar
        if value.locale == nil {
            value.locale = Locale(identifier: "en_US_POSIX")
        }
        return value
    }

    private static func dashboardTrendOpacity(index: Int, count: Int) -> Double {
        guard count > 1 else { return 0.9 }
        let ratio = Double(index) / Double(max(count - 1, 1))
        return max(0.38, 0.92 - ratio * 0.36)
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
                let accountEmail = TextNormalizationSupport.trimmed(result.usage.identity?.accountEmail)
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
            let displayName = AccountDisplayTextSupport.codexSnapshotLabel(summary: summary, account: account)
            let activeLiveSummary = (account.id == activeAccountID) ? liveDefault : nil
            let latestSnapshotDate = summary?.lastSyncSucceededAt ?? summary?.lastLoginAt
            let failureMessage: String? = {
                if summary?.cardKind?.isSelfManagedConfiguredAccount == true {
                    return nil
                }
                return activeLiveSummary?.errorMessage ?? summary?.lastSyncFailureMessage
            }()

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
            let failureMessage: String? = {
                if providerAuthSummary.cardKind?.isSelfManagedConfiguredAccount == true {
                    return nil
                }
                return liveDefault.errorMessage ?? providerAuthSummary.lastSyncFailureMessage
            }()
            return [
                AccountUsageSummary(
                    id: liveDefault.id,
                    accountLabel: AccountDisplayTextSupport.codexTitle(
                        summary: providerAuthSummary,
                        relativeAuthPath: "auth.json",
                        defaultName: "auth",
                        accountID: nil
                    ),
                    accountEmail: providerAuthSummary.email ?? liveDefault.accountEmail,
                    plan: providerAuthSummary.plan ?? liveDefault.plan,
                    totalCount: liveDefault.totalCount,
                    successCount: liveDefault.successCount,
                    failureCount: liveDefault.failureCount,
                    latestUpdatedAt: liveDefault.latestUpdatedAt,
                    primaryUsedPercent: liveDefault.primaryUsedPercent,
                    errorMessage: failureMessage,
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

    func accountCards(for provider: Provider) -> [AccountCardViewData] {
        guard let usageProvider = Self.mapUsageProvider(for: provider) else {
            return [emptyCard(provider: provider)]
        }

        switch usageProvider {
        case .claude:
            let accounts = claudeAccountsByProviderID[provider.id] ?? []
            let activeID = activeClaudeAccountIDByProviderID[provider.id]
            return makeProviderAccountCards(
                provider: provider,
                accounts: accounts,
                activeID: activeID
            )
        case .gemini, .antigravity:
            let accounts = geminiAccountsByProviderID[provider.id] ?? []
            let activeID = activeGeminiAccountIDByProviderID[provider.id]
            let liveSummary = accountSummariesByProviderID[provider.id]?.first
            return makeProviderAccountCards(
                provider: provider,
                accounts: accounts,
                activeID: activeID
            ) { account, isActive in
                guard isActive, let liveSummary else { return nil }
                return .init(
                    provider: usageProvider,
                    accountTitle: AccountDisplayTextSupport.title(
                        primary: account.email,
                        fallback: account.name
                    ),
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
        default:
            let summaries = accountSummariesByProviderID[provider.id] ?? []
            return makeSummaryUsageCards(
                provider: provider,
                usageProvider: usageProvider,
                summaries: summaries
            )
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
