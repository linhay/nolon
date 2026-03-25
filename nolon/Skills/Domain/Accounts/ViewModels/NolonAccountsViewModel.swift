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

@MainActor
@Observable
final class NolonAccountsViewModel {
    typealias CodexActivateAction = @Sendable (CodexAuthAccount, Provider) async throws -> Void
    typealias CodexGatewayStopAction = @Sendable (String) async throws -> Void
    typealias CopyTextAction = @Sendable (String) -> Void
    typealias OpenURLAction = @Sendable (URL) -> Void
    typealias ProviderUsageAccountsViewModelFactory = @MainActor @Sendable (Provider) -> ProviderUsageAccountsViewModel

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
    private let codexActivateAction: CodexActivateAction
    private let codexGatewayStopAction: CodexGatewayStopAction
    private let copyTextAction: CopyTextAction
    private let openURLAction: OpenURLAction
    private let providerUsageAccountsViewModelFactory: ProviderUsageAccountsViewModelFactory
    @ObservationIgnored private var providerUsageAccountsViewModelsByProviderID: [Provider.ID: ProviderUsageAccountsViewModel] = [:]

    var usageSummaryByProviderID: [Provider.ID: UsageSummary] = [:]
    var accountSummariesByProviderID: [Provider.ID: [AccountUsageSummary]] = [:]
    var codexAccountSummaryByProviderID: [Provider.ID: CodexAccountSummary] = [:]
    var activeCodexAccountIDByProviderID: [Provider.ID: UUID] = [:]
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
        codexActivateAction: CodexActivateAction? = nil,
        codexGatewayStopAction: CodexGatewayStopAction? = nil,
        copyTextAction: CopyTextAction? = nil,
        openURLAction: OpenURLAction? = nil,
        providerUsageViewModelFactory: ProviderUsageAccountsViewModelFactory? = nil
    ) {
        let hasCustomViewModelDependencies = usageMonitor != nil || codexActivateAction != nil
        let tokenStore = FileTokenAccountStore(fileURL: ProviderUsagePaths.defaultTokenAccountsFileURL())
        let resolvedUsageMonitor = usageMonitor ?? ProviderUsageMonitorService(tokenAccountStore: tokenStore)
        let resolvedCodexActivateAction = codexActivateAction ?? { account, provider in
            _ = try await CodexAuthActivationCoordinator.shared.activate(account: account, provider: provider)
        }
        let resolvedCodexGatewayStopAction = codexGatewayStopAction ?? { providerID in
            _ = try await NolonLiveCodexCLIService().gatewayStop(providerID: providerID)
        }

        self.settings = settings
        self.usageMonitor = resolvedUsageMonitor
        self.usageSettingsStore = usageSettingsStore ?? .shared
        self.codexAuthManager = codexAuthManager
        self.codexActivateAction = resolvedCodexActivateAction
        self.codexGatewayStopAction = resolvedCodexGatewayStopAction
        self.copyTextAction = copyTextAction ?? { text in
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
        self.openURLAction = openURLAction ?? { url in
            NSWorkspace.shared.open(url)
        }
        if let providerUsageViewModelFactory {
            self.providerUsageAccountsViewModelFactory = providerUsageViewModelFactory
        } else if hasCustomViewModelDependencies {
            self.providerUsageAccountsViewModelFactory = { provider in
                ProviderUsageRootViewModel(
                    provider: provider,
                    usageMonitor: resolvedUsageMonitor,
                    codexActivateAction: { account, provider in
                        try await resolvedCodexActivateAction(account, provider)
                        return CodexAuthActivationResult(runtimeSwitched: false, runtimeErrorDescription: nil)
                    }
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

                let accountSummaries = Self.makeAccountSummaries(outcomes: outcomes)
                if let summary = Self.makeUsageSummary(provider: provider, usageProvider: usageProvider, outcomes: outcomes) {
                    latestUsage[provider.id] = summary
                }

                if usageProvider == .codex {
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
                } else if usageProvider == .claude {
                    let sortedAccounts = accountsViewModel.claude.accounts.sorted { lhs, rhs in
                        let lhsActive = accountsViewModel.claude.isActiveAccount(lhs)
                        let rhsActive = accountsViewModel.claude.isActiveAccount(rhs)
                        if lhsActive != rhsActive { return lhsActive }
                        return lhs.updatedAt > rhs.updatedAt
                    }
                    latestClaudeAccounts[provider.id] = sortedAccounts
                    if let activeAccount = sortedAccounts.first(where: { accountsViewModel.claude.isActiveAccount($0) }) {
                        latestActiveClaudeAccounts[provider.id] = activeAccount.id
                    }
                } else if usageProvider == .gemini || usageProvider == .antigravity {
                    let sortedAccounts = accountsViewModel.gemini.accounts.sorted { lhs, rhs in
                        let lhsActive = accountsViewModel.gemini.isActiveAccount(lhs)
                        let rhsActive = accountsViewModel.gemini.isActiveAccount(rhs)
                        if lhsActive != rhsActive { return lhsActive }
                        return lhs.createdAt > rhs.createdAt
                    }
                    latestGeminiAccounts[provider.id] = sortedAccounts
                    if let activeAccount = sortedAccounts.first(where: { accountsViewModel.gemini.isActiveAccount($0) }) {
                        latestActiveGeminiAccounts[provider.id] = activeAccount.id
                    }
                } else if !accountSummaries.isEmpty {
                    latestAccountUsage[provider.id] = accountSummaries
                }
            }
        }
        usageSummaryByProviderID = latestUsage
        accountSummariesByProviderID = latestAccountUsage
        codexAccountSummaryByProviderID = latestCodexSummary
        activeCodexAccountIDByProviderID = latestActiveCodexAccounts
        claudeAccountsByProviderID = latestClaudeAccounts
        activeClaudeAccountIDByProviderID = latestActiveClaudeAccounts
        geminiAccountsByProviderID = latestGeminiAccounts
        activeGeminiAccountIDByProviderID = latestActiveGeminiAccounts
    }

    func activateCodexAccount(id: UUID, for provider: Provider) async {
        do {
            let accountsViewModel = providerUsageAccountsViewModel(for: provider)
            if let gatewayProviderID = Self.gatewayProviderID(for: provider) {
                try? await codexGatewayStopAction(gatewayProviderID)
            }
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

    private static func gatewayProviderID(for provider: Provider) -> String? {
        let normalizedTemplateID = provider.templateId?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalizedTemplateID {
        case ProviderTemplate.codex.rawValue.lowercased():
            return "codex"
        case ProviderTemplate.codexXcode.rawValue.lowercased(), "codex-xcode":
            return "codex-xcode"
        default:
            return nil
        }
    }

    func copyCodexAccountID(_ id: UUID) {
        copyTextAction(id.uuidString.lowercased())
    }

    func copyCodexAccountPath(_ id: UUID) async {
        guard let accounts = try? await codexAuthManager.loadAccounts(),
              let account = accounts.first(where: { $0.id == id })
        else { return }
        let file = await codexAuthManager.accountAuthFile(account)
        copyTextAction(file.url.path)
    }

    func copyCodexAccountAuthJSON(_ id: UUID) async {
        guard let accounts = try? await codexAuthManager.loadAccounts(),
              let account = accounts.first(where: { $0.id == id })
        else { return }
        let file = await codexAuthManager.accountAuthFile(account)
        guard let raw = try? file.read(), !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        copyTextAction(raw)
    }

    func editCodexAccountAuthJSON(_ id: UUID) async {
        guard let accounts = try? await codexAuthManager.loadAccounts(),
              let account = accounts.first(where: { $0.id == id })
        else { return }
        let file = await codexAuthManager.accountAuthFile(account)
        openURLAction(file.url)
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
            let supportsCodexSwitching = usageProvider == .codex
            let activeID = supportsCodexSwitching ? activeCodexAccountIDByProviderID[provider.id] : nil
            return summaries.map { summary in
                let accountID = supportsCodexSwitching
                    ? Self.resolveCodexAccountID(from: summary.id)
                    : nil
                let isActive = accountID == activeID
                let canOperateOnSnapshot = supportsCodexSwitching && accountID != nil
                let record = AccountRecordBuilder.codexAccounts(
                    providerName: provider.name,
                    usageProvider: usageProvider,
                    summary: summary,
                    isActive: isActive
                )
                return AccountCardViewDataMapper.map(
                    record: record,
                    primaryActions: !isActive && canOperateOnSnapshot ? [
                        .init(
                            id: "activate",
                            actionID: .activate,
                            title: NSLocalizedString("codex.accounts.action.activate", value: "Activate", comment: "Activate account"),
                            systemImage: nil,
                            role: nil,
                            prominence: .primary,
                            isEnabled: true
                        )
                    ] : [],
                    menuActions: canOperateOnSnapshot ? [
                        .init(
                            id: "copy-account-id",
                            actionID: .copyAccountID,
                            title: NSLocalizedString("codex.accounts.menu.copy_account_id", value: "Copy Account ID", comment: "Copy account id"),
                            systemImage: "number",
                            role: nil,
                            isEnabled: true
                        ),
                        .init(
                            id: "copy-auth-path",
                            actionID: .copyAuthPath,
                            title: NSLocalizedString("codex.accounts.menu.copy_auth_path", value: "Copy Auth Path", comment: "Copy auth path"),
                            systemImage: "doc.on.doc",
                            role: nil,
                            isEnabled: true
                        ),
                        .init(
                            id: "copy-auth-json",
                            actionID: .copyAuthJSON,
                            title: NSLocalizedString("codex.accounts.menu.copy_auth_json", value: "Copy auth.json", comment: "Copy auth json"),
                            systemImage: "doc.on.doc.fill",
                            role: nil,
                            isEnabled: true
                        ),
                        .init(
                            id: "edit-auth-json",
                            actionID: .editAuthJSON,
                            title: NSLocalizedString("codex.accounts.menu.edit_auth_json", value: "Edit auth.json", comment: "Edit auth json"),
                            systemImage: "pencil",
                            role: nil,
                            isEnabled: true
                        )
                    ] : [],
                    tapBehavior: !isActive && canOperateOnSnapshot ? .activate : .openProvider
                )
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
