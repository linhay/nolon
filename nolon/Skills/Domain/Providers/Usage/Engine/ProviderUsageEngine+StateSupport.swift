import Foundation
import ProviderCatalog
import ProviderUsage
import CodexBarProviderCatalog
import NolonResourceKit

extension ProviderUsageEngine {
    func normalizedPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }

    func runCodexPreflight(forceBackup: Bool, reason: String) async throws -> CodexAuthAccount? {
        if let codexPreflightAction {
            return try await codexPreflightAction(provider, forceBackup, reason)
        }
        return try await codexAuthManager.preflightManagedAuthIfNeeded(
            for: provider,
            forceBackup: forceBackup,
            reason: reason
        )
    }

    func applyCodexAccountsForDisplay(_ accounts: [CodexAuthAccount]) async {
        codexAccounts = accounts
        let validIDs = Set(codexAccounts.map(\.id))
        codexScheduledRefreshLastAt = codexScheduledRefreshLastAt.filter { validIDs.contains($0.key) }
        codexScheduledRefreshFailureStreak = codexScheduledRefreshFailureStreak.filter { validIDs.contains($0.key) }
        reconcileCodexSelections()
        codexAccountSummaries = loadCodexAccountSummaries(accounts: codexAccounts)
        codexAccountCustomGroupNames = (try? await codexAuthManager.loadCustomGroupNamesByAccountID()) ?? [:]
        normalizeCodexGroupingOptionIfNeeded()
        activeCodexAccountId = await codexAuthManager.activeAccountId(for: provider, accounts: codexAccounts)
        codexAccountOutcomes = await loadCachedCodexAccountOutcomes(
            accounts: codexAccounts,
            summaries: codexAccountSummaries
        )
        reorderCodexAccountOutcomesForDisplay()
    }

    func normalizeCodexGroupingOptionIfNeeded() {
        guard codexAccountGroupingOption == .customSQLiteGroup else { return }
        guard !codexAccounts.isEmpty else { return }
        let hasCustomGroup = codexAccounts.contains { account in
            let name = codexAccountCustomGroupNames[account.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return !name.isEmpty
        }
        guard !hasCustomGroup else { return }
        setCodexAccountGroupingOption(.typeInfo)
    }

    func shouldIgnoreTemporaryFileChange(path: String) -> Bool {
        let lastComponent = (path as NSString).lastPathComponent
        if lastComponent.hasPrefix(".dat.nosync") {
            return true
        }
        return false
    }

    func activeCodexAccountForRefresh() -> CodexAuthAccount? {
        if let activeId = activeCodexAccountId,
           let account = codexAccounts.first(where: { $0.id == activeId }) {
            return account
        }
        if let matched = codexAccounts.first(where: { isActiveCodexAccount($0) }) {
            return matched
        }
        return codexAccounts.first
    }

    func setMultiAccountEnabled(_ enabled: Bool) {
        guard enabled != isMultiAccountEnabled else { return }
        isMultiAccountEnabled = enabled
        settingsStore.setMultiAccountEnabled(enabled, for: provider)

        if !enabled {
            cancelCLILoginIfNeeded()
            isShowingAuthFileImporter = false
            importedAuthFileURL = nil
            resetCodexMultiAccountState()
        }

        Task { await load() }
    }

    func buildCachedCodexAccountOutcome(
        for account: CodexAuthAccount,
        summary: CodexAuthSummary?
    ) async -> (ProviderAccountUsageOutcome, Date?) {
        let tokenAccount = ProviderTokenAccount(
            id: account.id,
            label: account.name,
            token: "",
            addedAt: account.createdAt.timeIntervalSince1970,
            lastUsed: nil
        )

        if let summary,
           summary.cardKind?.isSelfManagedConfiguredAccount != true,
           let persistedFailure = persistedCodexFailureOutcome(for: tokenAccount, summary: summary)
        {
            return (
                ProviderAccountUsageOutcome(
                    provider: .codex,
                    account: .tokenAccount(tokenAccount),
                    outcome: persistedFailure
                ),
                nil
            )
        }

        if let cache = try? await codexAuthManager.loadUsageCache(for: account) {
            let refreshedAt: Date?
            if let credits = cache.credits, !credits.remaining.isNaN {
                refreshedAt = cache.creditsRefreshedAt ?? cache.cachedAt
            } else {
                refreshedAt = nil
            }
            return (
                ProviderAccountUsageOutcome(
                    provider: .codex,
                    account: .tokenAccount(tokenAccount),
                    outcome: ProviderFetchOutcome(
                        fetchKind: cache.fetchKind,
                        result: .success(cache.toFetchResult())
                    )
                ),
                refreshedAt
            )
        }

        let placeholderUsage = UsageSnapshot(
            identity: nil,
            primary: nil,
            secondary: nil,
            tertiary: nil,
            updatedAt: account.createdAt
        )
        let placeholderResult = ProviderFetchResult(
            usage: placeholderUsage,
            credits: nil,
            cost: nil,
            sourceLabel: NSLocalizedString(
                "usage.monitor.cache.placeholder",
                value: "Cached",
                comment: "Placeholder cached usage label"
            ),
            fetchKind: .cli,
            strategyKind: .direct
        )
        return (
            ProviderAccountUsageOutcome(
                provider: .codex,
                account: .tokenAccount(tokenAccount),
                outcome: ProviderFetchOutcome(fetchKind: .cli, result: .success(placeholderResult))
            ),
            nil
        )
    }

    func loadCachedCodexAccountOutcomes(
        accounts: [CodexAuthAccount],
        summaries: [UUID: CodexAuthSummary]
    ) async -> [ProviderAccountUsageOutcome] {
        var outcomes: [ProviderAccountUsageOutcome] = []
        outcomes.reserveCapacity(accounts.count)
        var creditsRefreshedAt: [UUID: Date] = [:]

        for account in accounts {
            let (outcome, refreshedAt) = await buildCachedCodexAccountOutcome(
                for: account,
                summary: summaries[account.id]
            )
            outcomes.append(outcome)
            if let refreshedAt {
                creditsRefreshedAt[account.id] = refreshedAt
            }
        }

        codexAccountCreditsRefreshedAt = creditsRefreshedAt
        return outcomes
    }

    func persistedCodexFailureOutcome(
        for tokenAccount: ProviderTokenAccount,
        summary: CodexAuthSummary
    ) -> ProviderFetchOutcome? {
        let trimmedMessage = summary.lastSyncFailureMessage?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedMessage, !trimmedMessage.isEmpty {
            return ProviderFetchOutcome(
                fetchKind: .cli,
                result: .failure(PersistedCodexSyncFailureError(message: trimmedMessage))
            )
        }
        guard summary.lastSyncFailedAt != nil else { return nil }
        return ProviderFetchOutcome(
            fetchKind: .cli,
            result: .failure(
                PersistedCodexSyncFailureError(
                    message: NSLocalizedString(
                        "usage.monitor.codex.failure.cached",
                        value: "Last sync failed.",
                        comment: "Fallback message for persisted Codex sync failure"
                    )
                )
            )
        )
    }

    func updateSupportedModes() {
        guard let usageProvider else { return }
        supportedSourceModes = ProviderUsageRegistry.fetchPlan(for: usageProvider).sourceModes
            .sorted(by: { $0.rawValue < $1.rawValue })
        if !supportedSourceModes.contains(settings.sourceMode) {
            updateSettings(UsageMonitorProviderSettings(
                sourceMode: .auto,
                includeCredits: settings.includeCredits,
                webTimeoutSeconds: settings.webTimeoutSeconds,
                autoRefreshIntervalMinutes: settings.autoRefreshIntervalMinutes,
                costWindowDays: settings.costWindowDays,
                codexHideZeroQuotaAccounts: settings.codexHideZeroQuotaAccounts,
                codexHideErroredAccounts: settings.codexHideErroredAccounts,
                codexUseListLayout: settings.codexUseListLayout
            ))
        }
    }

    static func mapToUsageProvider(_ provider: Provider) -> UsageProvider? {
        if provider.templateId == ProviderTemplate.codexXcode.rawValue {
            return .codex
        }
        if provider.templateId == ProviderTemplate.claudeCode.rawValue {
            return .claude
        }
        if let templateId = provider.templateId, let mapped = UsageProvider(rawValue: templateId) {
            return mapped
        }
        return nil
    }

    func currentSnapshotItems() -> [ProviderUsageSnapshotItem] {
        let effectiveOutcomes: [ProviderAccountUsageOutcome]
        if usageProvider == .codex, isMultiAccountEnabled {
            effectiveOutcomes = codexAccountOutcomes
        } else {
            effectiveOutcomes = outcomes
        }

        return effectiveOutcomes.map { outcome in
            let id: String = {
                switch outcome.account {
                case .default:
                    return "default"
                case let .tokenAccount(account):
                    return account.id.uuidString
                }
            }()

            let status: ProviderUsageOutcomeStatus = {
                switch outcome.outcome.result {
                case .success:
                    return .success
                case .failure:
                    return .failure
                }
            }()

            let updatedAt: Date? = {
                guard case let .success(result) = outcome.outcome.result else { return nil }
                return result.usage.updatedAt
            }()

            let hasCredits: Bool = {
                guard case let .success(result) = outcome.outcome.result else { return false }
                return result.credits != nil
            }()

            return ProviderUsageSnapshotItem(
                id: id,
                status: status,
                updatedAt: updatedAt,
                hasCredits: hasCredits
            )
        }
    }

    var dashboardURL: URL? {
        guard let usageProvider else { return nil }
        guard let raw = ProviderUsageRegistry.metadata(for: usageProvider)?.dashboardURL else { return nil }
        return URL(string: raw)
    }
}
