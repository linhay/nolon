import SwiftUI
import AppKit
import ProviderCatalog
import Observation
import WebKit
import ProviderUsage
import CodexBarProviderCatalog
import CodexProvider
import UniformTypeIdentifiers
import OSLog
import Combine
import NolonResourceKit
import NolonCoreCLIKit
import NolonUIFoundation
import GRDB
@preconcurrency import STFilePath
import STJSON

extension ProviderUsageEngine {
    func loadCodexAccountSummaries(accounts: [CodexAuthAccount]) -> [UUID: CodexAuthSummary] {
        var summaries: [UUID: CodexAuthSummary] = [:]
        summaries.reserveCapacity(accounts.count)
        for account in accounts {
            if let data = codexAuthManager.accountAuthData(for: account) {
                summaries[account.id] = CodexAuthSummary.fromJSONData(data)
            }
        }
        return summaries
    }

    func mergeCachedCodexUsageIfNeeded(
        outcome: ProviderAccountUsageOutcome,
        accounts: [CodexAuthAccount]
    ) async -> ProviderAccountUsageOutcome {
        guard case let .success(result) = outcome.outcome.result else { return outcome }
        guard let activeId = await codexAuthManager.activeAccountId(for: provider),
              let activeAccount = accounts.first(where: { $0.id == activeId }),
              let cache = try? await codexAuthManager.loadUsageCache(for: activeAccount)
        else { return outcome }

        let mergedUsage = mergeUsageSnapshot(live: result.usage, cached: cache.usage)
        let mergedResult = ProviderFetchResult(
            usage: mergedUsage,
            credits: result.credits,
            cost: nil,
            sourceLabel: result.sourceLabel,
            fetchKind: result.fetchKind,
            strategyKind: result.strategyKind
        )
        let mergedOutcome = ProviderFetchOutcome(fetchKind: outcome.outcome.fetchKind, result: .success(mergedResult))
        return ProviderAccountUsageOutcome(provider: outcome.provider, account: outcome.account, outcome: mergedOutcome)
    }

    func mergeUsageSnapshot(live: UsageSnapshot, cached: UsageSnapshot) -> UsageSnapshot {
        let mergedWindows = mergeUsageWindows(live: live, cached: cached)
        return UsageSnapshot(
            identity: live.identity ?? cached.identity,
            windows: mergedWindows,
            primary: mergeRateWindow(live: live.primary, cached: cached.primary),
            secondary: mergeRateWindow(live: live.secondary, cached: cached.secondary),
            tertiary: mergeRateWindow(live: live.tertiary, cached: cached.tertiary),
            updatedAt: live.updatedAt
        )
    }

    func mergeUsageWindows(live: UsageSnapshot, cached: UsageSnapshot) -> [UsageWindow] {
        guard !live.windows.isEmpty || !cached.windows.isEmpty else {
            return []
        }

        var mergedByID = Dictionary(uniqueKeysWithValues: cached.windows.map { ($0.id, $0) })
        for item in live.windows {
            if let cachedItem = mergedByID[item.id] {
                mergedByID[item.id] = UsageWindow(
                    id: item.id,
                    title: item.title,
                    window: mergeRateWindow(live: item.window, cached: cachedItem.window) ?? item.window
                )
            } else {
                mergedByID[item.id] = item
            }
        }

        var ordered: [UsageWindow] = []
        var seen = Set<String>()
        for item in live.windows + cached.windows {
            guard let merged = mergedByID[item.id], seen.insert(item.id).inserted else { continue }
            ordered.append(merged)
        }
        return ordered
    }

    func mergeRateWindow(live: RateWindow?, cached: RateWindow?) -> RateWindow? {
        switch (live, cached) {
        case (nil, nil):
            return nil
        case (nil, let cached):
            return cached
        case (let live, nil):
            return live
        case let (live?, cached?):
            return RateWindow(
                usedPercent: live.usedPercent,
                resetDescription: live.resetDescription ?? cached.resetDescription,
                resetsAt: live.resetsAt ?? cached.resetsAt,
                windowMinutes: live.windowMinutes ?? cached.windowMinutes
            )
        }
    }

    func revealCodexAccountInFinder(id: UUID) {
        guard let account = codexAccounts.first(where: { $0.id == id }) else { return }
        guard let data = codexAuthManager.accountAuthDataWithoutMaterialization(for: account), !data.isEmpty else {
            return
        }
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("nolon-codex-auth-reveal", isDirectory: true)
            .appendingPathComponent(account.id.uuidString.lowercased(), isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true, attributes: nil)
            let authURL = tempRoot.appendingPathComponent("auth.json", isDirectory: false)
            try data.write(to: authURL, options: .atomic)
            NSWorkspace.shared.activateFileViewerSelecting([authURL])
        } catch {
            Self.logger.error("Failed to materialize temporary auth.json for Finder reveal: \(error.localizedDescription, privacy: .public)")
        }
    }

    func refreshCodexAccount(id: UUID) {
        Task { [weak self] in
            guard let self else { return }
            await self.refreshCodexAccountImmediately(id: id)
        }
    }

    func refreshCodexAccountImmediately(id: UUID) async {
        guard let account = codexAccounts.first(where: { $0.id == id }) else { return }
        await refreshCodexAccountOutcome(account)
    }

    func refreshCodexAccountsIfNeeded(activeId: UUID?, summaries: [UUID: CodexAuthSummary]) async {
        let targets = orderedAccounts(activeId: activeId).filter { account in
            if shouldSkipRefresh(accountID: account.id, summaries: summaries) {
                return false
            }
            let isActive = account.id == activeId || (activeId == nil && isActiveCodexAccount(account))
            if isActive { return true }
            return isAccountInfoMissing(accountId: account.id, summaries: summaries)
        }

        await refreshCodexAccountsInParallel(targets)
    }

    func refreshCodexAccountOutcome(_ account: CodexAuthAccount) async {
        let accountId = account.id
        guard isMultiAccountEnabled,
              codexAccounts.contains(where: { $0.id == accountId })
        else {
            return
        }
        guard !codexRefreshingAccountIds.contains(accountId) else { return }

        codexRefreshingAccountIds.insert(accountId)
        var isRefreshingCleared = false
        defer {
            if !isRefreshingCleared {
                codexRefreshingAccountIds.remove(accountId)
            }
        }

        guard let authURL = codexAuthSourceURL(for: account) else {
            let outcome = Self.codexMissingAuthSourceOutcome(for: account)
            codexRefreshingAccountIds.remove(accountId)
            isRefreshingCleared = true
            await applyRefreshedCodexOutcome(outcome, for: account)
            return
        }
        let outcome = await fetchCodexOutcomeWithTimeout(account: account, settings: settings, authURL: authURL)
        codexRefreshingAccountIds.remove(accountId)
        isRefreshingCleared = true
        await applyRefreshedCodexOutcome(outcome, for: account)
    }

    func refreshCodexAccountsOnInitialLoad(activeId: UUID?, summaries: [UUID: CodexAuthSummary]) async {
        let targets = orderedAccounts(activeId: activeId).filter { account in
            if shouldSkipRefresh(accountID: account.id, summaries: summaries) {
                return false
            }
            return true
        }
        await refreshCodexAccountsInParallel(targets)
    }

    func refreshCodexAccountsInParallel(_ accounts: [CodexAuthAccount]) async {
        guard !accounts.isEmpty else { return }
        let targets = accounts.filter { account in
            codexAccounts.contains(where: { $0.id == account.id }) && !codexRefreshingAccountIds.contains(account.id)
        }
        guard !targets.isEmpty else { return }

        let refreshingIDs = Set(targets.map(\.id))
        codexRefreshingAccountIds.formUnion(refreshingIDs)
        defer { codexRefreshingAccountIds.subtract(refreshingIDs) }

        let settingsSnapshot = settings
        var tasks: [UUID: Task<ProviderAccountUsageOutcome, Never>] = [:]
        tasks.reserveCapacity(targets.count)

        for account in targets {
            tasks[account.id] = Task(priority: .userInitiated) {
                guard let authURL = self.codexAuthSourceURL(for: account) else {
                    return Self.codexMissingAuthSourceOutcome(for: account)
                }
                return await self.fetchCodexOutcomeWithTimeout(account: account, settings: settingsSnapshot, authURL: authURL)
            }
        }

        for account in targets {
            if Task.isCancelled {
                tasks.values.forEach { $0.cancel() }
                break
            }
            guard let task = tasks[account.id] else { continue }
            let outcome = await task.value
            codexRefreshingAccountIds.remove(account.id)
            if Task.isCancelled { continue }
            await applyRefreshedCodexOutcome(outcome, for: account)
        }
    }

    func applyRefreshedCodexOutcome(_ outcome: ProviderAccountUsageOutcome, for account: CodexAuthAccount) async {
        let accountId = account.id
        lastUsageRefreshAt = Date()
        codexScheduledRefreshLastAt[accountId] = Date()

        if case let .success(result) = outcome.outcome.result {
            replaceCodexOutcome(outcome, for: account.id)
            let now = Date()
            codexScheduledRefreshFailureStreak[accountId] = 0
            codexRefreshedAccountIdsInSession.insert(accountId)
            try? await codexAuthManager.updateSyncSuccess(for: account, date: now)
            let creditsRefreshedAt: Date? = {
                guard let credits = result.credits, !credits.remaining.isNaN else { return nil }
                return now
            }()
            if let creditsRefreshedAt {
                codexAccountCreditsRefreshedAt[accountId] = creditsRefreshedAt
            } else {
                codexAccountCreditsRefreshedAt.removeValue(forKey: accountId)
            }
            do {
                let cache = CodexAuthUsageCache(
                    cachedAt: now,
                    creditsRefreshedAt: creditsRefreshedAt,
                    fetchKind: outcome.outcome.fetchKind,
                    strategyKind: result.strategyKind,
                sourceLabel: result.sourceLabel,
                usage: result.usage,
                credits: result.credits,
                cost: nil
            )
            codexUsageCacheWriteCount += 1
            defer { codexUsageCacheWriteCount = max(0, codexUsageCacheWriteCount - 1) }
            try await codexAuthManager.storeUsageCache(cache, for: account)
            } catch {
                // Best-effort cache write; ignore.
            }

            if let identity = result.usage.identity {
                var summary = codexAccountSummaries[accountId] ?? CodexAuthSummary()
                if let email = identity.accountEmail?.trimmingCharacters(in: .whitespacesAndNewlines),
                   Self.isNotBlank(email)
                {
                    if summary.email == nil {
                        _ = try? await codexAuthManager.backfillEmailIfMissing(for: account, email: email)
                    }
                    summary.email = email
                }
                if let plan = identity.plan?.trimmingCharacters(in: .whitespacesAndNewlines),
                   Self.isNotBlank(plan)
                {
                    _ = try? await codexAuthManager.upsertPlanType(for: account, plan: plan)
                    summary.plan = plan
                }
                summary.lastSyncSucceededAt = now
                summary.lastSyncFailedAt = nil
                summary.lastSyncFailureMessage = nil
                codexAccountSummaries[accountId] = summary
            }
        } else if case let .failure(error) = outcome.outcome.result {
            let now = Date()
            let nextStreak = max(1, (codexScheduledRefreshFailureStreak[accountId] ?? 0) + 1)
            codexScheduledRefreshFailureStreak[accountId] = nextStreak
            codexRefreshedAccountIdsInSession.remove(accountId)
            let message = error.localizedDescription
            if !shouldRetainExistingCodexSuccessResult(for: accountId, error: error) {
                replaceCodexOutcome(outcome, for: account.id)
            }
            try? await codexAuthManager.updateSyncFailure(for: account, message: message, date: now)
            var summary = codexAccountSummaries[accountId] ?? CodexAuthSummary()
            summary.lastSyncFailedAt = now
            summary.lastSyncFailureMessage = message
            codexAccountSummaries[accountId] = summary
        }
    }

    func shouldRetainExistingCodexSuccessResult(for accountID: UUID, error: Error) -> Bool {
        guard error is CodexHTTPUsageQueryError else { return false }
        guard let existing = codexAccountOutcomes.first(where: { outcome in
            guard case let .tokenAccount(account) = outcome.account else { return false }
            return account.id == accountID
        }) else {
            return false
        }
        guard case .success = existing.outcome.result else { return false }
        return true
    }

    func orderedAccounts(activeId: UUID?) -> [CodexAuthAccount] {
        guard !codexAccounts.isEmpty else { return [] }
        let uniqueAccounts = uniqueCodexAccountsInDisplayOrder()
        let resolvedActiveID: UUID? = {
            if let activeId { return activeId }
            if let active = uniqueAccounts.first(where: { account in
                guard let current = activeCodexAccountForRefresh() else { return false }
                return account.id == current.id
            }) {
                return active.id
            }
            return nil
        }()
        guard let resolvedActiveID else { return uniqueAccounts }

        var ordered: [CodexAuthAccount] = []
        ordered.reserveCapacity(uniqueAccounts.count)
        if let active = uniqueAccounts.first(where: { $0.id == resolvedActiveID }) {
            ordered.append(active)
        }
        ordered.append(contentsOf: uniqueAccounts.filter { $0.id != resolvedActiveID })
        return ordered
    }

    func shouldSkipRefresh(accountID: UUID, summaries: [UUID: CodexAuthSummary]) -> Bool {
        guard let summary = summaries[accountID] else { return false }
        return CodexAuthFailureClassifier.shouldSkipRefresh(summary: summary)
    }

    func nonCodexScheduledRefreshDecision(now: Date) -> RefreshDecision {
        let interval = refreshInterval(for: refreshPolicyProfile, role: .nonCodex)
        let lastRefresh = nonCodexScheduledRefreshLastAt ?? lastUsageRefreshAt
        guard let lastRefresh else {
            return RefreshDecision(shouldRefresh: true, nextEligibleAt: now, reason: "noncodex_initial")
        }
        let nextEligibleAt = lastRefresh.addingTimeInterval(interval)
        let shouldRefresh = now >= nextEligibleAt
        return RefreshDecision(
            shouldRefresh: shouldRefresh,
            nextEligibleAt: nextEligibleAt,
            reason: shouldRefresh ? "noncodex_interval_elapsed" : "noncodex_wait_interval"
        )
    }

    enum CodexRefreshRole {
        case active
        case recent
        case backoff(streak: Int)
        case ignored
        case nonCodex
    }

    struct CodexScheduledRefreshPolicy: Equatable {
        let interval: TimeInterval
        let dueReason: String
        let waitReason: String
    }

    struct CodexWindowUsageSignal: Equatable {
        let windowMinutes: Int
        let usedPercent: Double
        let remainingPercent: Double
        let resetsAt: Date?
    }

    func codexScheduledRefreshDecision(for account: CodexAuthAccount, now: Date) -> RefreshDecision {
        guard let role = codexRefreshRole(for: account, now: now) else {
            return RefreshDecision(shouldRefresh: false, nextEligibleAt: .distantFuture, reason: "codex_not_active_or_recent")
        }
        let lastRefresh = codexScheduledRefreshLastAt[account.id]
        if let immediateDecision = codexImmediateRefreshDecisionForShortestWindowReset(
            accountID: account.id,
            role: role,
            lastRefresh: lastRefresh,
            now: now
        ) {
            return immediateDecision
        }
        let policy = codexScheduledRefreshPolicy(for: account.id, role: role)
        let nextEligibleAt = (lastRefresh ?? .distantPast).addingTimeInterval(policy.interval)
        let shouldRefresh = now >= nextEligibleAt
        return RefreshDecision(
            shouldRefresh: shouldRefresh,
            nextEligibleAt: shouldRefresh ? now : nextEligibleAt,
            reason: shouldRefresh ? policy.dueReason : policy.waitReason
        )
    }

    func codexScheduledRefreshPolicy(for accountID: UUID, role: CodexRefreshRole) -> CodexScheduledRefreshPolicy {
        switch role {
        case .active, .recent:
            if let longestSignal = codexLongestWindowSignal(for: accountID),
               longestSignal.remainingPercent <= 0
            {
                let remainingToken = Self.codexPercentReasonToken(longestSignal.remainingPercent)
                Self.logger.debug(
                    "Codex longest-window zero quota throttle hit. provider=\(self.provider.id, privacy: .public) account=\(accountID.uuidString, privacy: .public) window=\(longestSignal.windowMinutes, privacy: .public) remaining=\(remainingToken, privacy: .public)"
                )
                let base = "codex_longest_zero_quota_w\(longestSignal.windowMinutes)_r\(remainingToken)"
                return CodexScheduledRefreshPolicy(
                    interval: 60 * 60,
                    dueReason: "\(base)_due",
                    waitReason: "\(base)_wait"
                )
            }

            if let tierSignal = codexTieredShortestWindowSignal(for: accountID),
               let roleLabel = codexTierRoleLabel(for: role)
            {
                let usedToken = Self.codexPercentReasonToken(tierSignal.usedPercent)
                let base = "codex_\(roleLabel)_tier_\(tierSignal.tierLabel)_w\(tierSignal.windowMinutes)_u\(usedToken)"
                return CodexScheduledRefreshPolicy(
                    interval: tierSignal.interval,
                    dueReason: "\(base)_due",
                    waitReason: "\(base)_wait"
                )
            }

            let fallbackInterval = refreshInterval(for: refreshPolicyProfile, role: role)
            return CodexScheduledRefreshPolicy(
                interval: fallbackInterval,
                dueReason: codexDecisionReason(role: role, shouldRefresh: true),
                waitReason: codexDecisionReason(role: role, shouldRefresh: false)
            )
        case let .backoff(streak):
            let backoffRole = CodexRefreshRole.backoff(streak: streak)
            return CodexScheduledRefreshPolicy(
                interval: refreshInterval(for: refreshPolicyProfile, role: backoffRole),
                dueReason: codexDecisionReason(role: backoffRole, shouldRefresh: true),
                waitReason: codexDecisionReason(role: backoffRole, shouldRefresh: false)
            )
        case .ignored:
            return CodexScheduledRefreshPolicy(interval: .infinity, dueReason: "codex_ignored", waitReason: "codex_ignored")
        case .nonCodex:
            return CodexScheduledRefreshPolicy(
                interval: refreshInterval(for: refreshPolicyProfile, role: .nonCodex),
                dueReason: "noncodex_due",
                waitReason: "noncodex_wait"
            )
        }
    }

    func codexRefreshRole(for account: CodexAuthAccount, now: Date) -> CodexRefreshRole? {
        let isActive = account.id == activeCodexAccountId
        if isActive {
            if isCodexAccountInFailureState(account.id) {
                let streak = max(1, codexScheduledRefreshFailureStreak[account.id] ?? 1)
                return .backoff(streak: streak)
            }
            return .active
        }

        guard isCodexRecentlyUsedAccount(account.id, now: now) else { return nil }
        if isCodexAccountInFailureState(account.id) {
            let streak = max(1, codexScheduledRefreshFailureStreak[account.id] ?? 1)
            return .backoff(streak: streak)
        }
        return .recent
    }

    func isCodexRecentlyUsedAccount(_ accountID: UUID, now: Date) -> Bool {
        guard let lastSuccess = codexAccountSummaries[accountID]?.lastSyncSucceededAt else { return false }
        return now.timeIntervalSince(lastSuccess) <= 24 * 60 * 60
    }

    func isCodexAccountInFailureState(_ accountID: UUID) -> Bool {
        guard let summary = codexAccountSummaries[accountID] else { return false }
        guard let failedAt = summary.lastSyncFailedAt else { return false }
        guard let succeededAt = summary.lastSyncSucceededAt else { return true }
        return failedAt > succeededAt
    }

    func refreshInterval(for profile: RefreshPolicyProfile, role: CodexRefreshRole) -> TimeInterval {
        switch profile {
        case .balanced:
            switch role {
            case .active:
                return 5 * 60
            case .recent:
                return 15 * 60
            case let .backoff(streak):
                return streak >= 2 ? 60 * 60 : 30 * 60
            case .ignored:
                return .infinity
            case .nonCodex:
                return 15 * 60
            }
        }
    }

    func codexDecisionReason(role: CodexRefreshRole, shouldRefresh: Bool) -> String {
        switch role {
        case .active:
            return shouldRefresh ? "codex_active_due" : "codex_active_wait"
        case .recent:
            return shouldRefresh ? "codex_recent_due" : "codex_recent_wait"
        case let .backoff(streak):
            return shouldRefresh ? "codex_backoff_due_\(streak)" : "codex_backoff_wait_\(streak)"
        case .ignored:
            return "codex_ignored"
        case .nonCodex:
            return shouldRefresh ? "noncodex_due" : "noncodex_wait"
        }
    }

    func codexUsageSnapshot(for accountID: UUID) -> UsageSnapshot? {
        guard let outcome = codexAccountOutcomes.first(where: { outcome in
            guard case let .tokenAccount(account) = outcome.account else { return false }
            return account.id == accountID
        }) else {
            return nil
        }
        guard case let .success(result) = outcome.outcome.result else { return nil }
        return result.usage
    }

    func codexShortestWindowSignal(for accountID: UUID) -> CodexWindowUsageSignal? {
        guard let usage = codexUsageSnapshot(for: accountID) else { return nil }
        let windows = usage.allWindows
            .map(\.window)
            .filter { ($0.windowMinutes ?? 0) > 0 }
        guard let shortest = windows.min(by: { ($0.windowMinutes ?? 0) < ($1.windowMinutes ?? 0) }),
              let windowMinutes = shortest.windowMinutes,
              let usedPercent = Self.normalizedPercent(shortest.usedPercent),
              let remainingPercent = Self.normalizedPercent(shortest.remainingPercent)
        else {
            return nil
        }
        return CodexWindowUsageSignal(
            windowMinutes: windowMinutes,
            usedPercent: usedPercent,
            remainingPercent: remainingPercent,
            resetsAt: shortest.resetsAt
        )
    }

    func codexLongestWindowSignal(for accountID: UUID) -> CodexWindowUsageSignal? {
        guard let usage = codexUsageSnapshot(for: accountID) else { return nil }
        let windows = usage.allWindows
            .map(\.window)
            .filter { ($0.windowMinutes ?? 0) > 0 }
        guard let longest = windows.max(by: { ($0.windowMinutes ?? 0) < ($1.windowMinutes ?? 0) }),
              let windowMinutes = longest.windowMinutes,
              let usedPercent = Self.normalizedPercent(longest.usedPercent),
              let remainingPercent = Self.normalizedPercent(longest.remainingPercent)
        else {
            return nil
        }
        return CodexWindowUsageSignal(
            windowMinutes: windowMinutes,
            usedPercent: usedPercent,
            remainingPercent: remainingPercent,
            resetsAt: longest.resetsAt
        )
    }

    func codexImmediateRefreshDecisionForShortestWindowReset(
        accountID: UUID,
        role: CodexRefreshRole,
        lastRefresh: Date?,
        now: Date
    ) -> RefreshDecision? {
        guard codexTierRoleLabel(for: role) != nil else { return nil }
        guard let shortestSignal = codexShortestWindowSignal(for: accountID),
              shortestSignal.remainingPercent <= 0,
              let shortestResetsAt = shortestSignal.resetsAt,
              shortestResetsAt <= now
        else {
            return nil
        }
        if let longestSignal = codexLongestWindowSignal(for: accountID),
           longestSignal.windowMinutes > shortestSignal.windowMinutes,
           longestSignal.remainingPercent <= 0
        {
            return nil
        }
        if let lastRefresh, lastRefresh >= shortestResetsAt {
            let remainingToken = Self.codexPercentReasonToken(shortestSignal.remainingPercent)
            let base = "codex_shortest_reset_w\(shortestSignal.windowMinutes)_r\(remainingToken)"
            return RefreshDecision(
                shouldRefresh: false,
                nextEligibleAt: shortestResetsAt.addingTimeInterval(1),
                reason: "\(base)_already_refreshed"
            )
        }

        let remainingToken = Self.codexPercentReasonToken(shortestSignal.remainingPercent)
        let base = "codex_shortest_reset_w\(shortestSignal.windowMinutes)_r\(remainingToken)"
        return RefreshDecision(
            shouldRefresh: true,
            nextEligibleAt: now,
            reason: "\(base)_due"
        )
    }

    func codexTieredShortestWindowSignal(for accountID: UUID) -> (interval: TimeInterval, tierLabel: String, windowMinutes: Int, usedPercent: Double)? {
        guard let shortest = codexShortestWindowSignal(for: accountID) else { return nil }
        switch shortest.usedPercent {
        case 90...:
            return (3 * 60, "ge90", shortest.windowMinutes, shortest.usedPercent)
        case 75..<90:
            return (5 * 60, "ge75", shortest.windowMinutes, shortest.usedPercent)
        case 50..<75:
            return (10 * 60, "ge50", shortest.windowMinutes, shortest.usedPercent)
        default:
            return (15 * 60, "lt50", shortest.windowMinutes, shortest.usedPercent)
        }
    }

    func codexTierRoleLabel(for role: CodexRefreshRole) -> String? {
        switch role {
        case .active:
            return "active"
        case .recent:
            return "recent"
        default:
            return nil
        }
    }

    static func normalizedPercent(_ value: Double) -> Double? {
        guard value.isFinite else { return nil }
        return max(0, min(100, value))
    }

    static func codexPercentReasonToken(_ value: Double) -> Int {
        Int(value.rounded())
    }

    func persistCurrentCodexOutcomeIfPossible(
        outcome: ProviderAccountUsageOutcome,
        accounts: [CodexAuthAccount]
    ) async {
        guard case let .success(result) = outcome.outcome.result else { return }
        guard !accounts.isEmpty else { return }
        guard let activeId = await codexAuthManager.activeAccountId(for: provider),
              let activeAccount = accounts.first(where: { $0.id == activeId })
        else { return }

        do {
            let now = Date()
            let creditsRefreshedAt: Date? = {
                guard let credits = result.credits, !credits.remaining.isNaN else { return nil }
                return now
            }()
            if let creditsRefreshedAt {
                codexAccountCreditsRefreshedAt[activeAccount.id] = creditsRefreshedAt
            } else {
                codexAccountCreditsRefreshedAt.removeValue(forKey: activeAccount.id)
            }
            let cache = CodexAuthUsageCache(
                cachedAt: now,
                creditsRefreshedAt: creditsRefreshedAt,
                fetchKind: outcome.outcome.fetchKind,
                strategyKind: result.strategyKind,
                sourceLabel: result.sourceLabel,
                usage: result.usage,
                credits: result.credits,
                cost: nil
            )
            codexUsageCacheWriteCount += 1
            defer { codexUsageCacheWriteCount = max(0, codexUsageCacheWriteCount - 1) }
            try await codexAuthManager.storeUsageCache(cache, for: activeAccount)
        } catch {
            // Best-effort cache write; ignore.
        }
    }

    func shouldIgnoreAuthChange(path: String, kind: STPathChangeKind) -> Bool {
        let authFolderPath = codexAuthManager.nolonCodexAuthFolder().url.standardizedFileURL.path
        let isAuthFolderChange = path == authFolderPath || path.hasPrefix(authFolderPath + "/")
        if isAuthFolderChange {
            if !gatewaySwitchInProgressTokens.isEmpty {
                Self.logger.debug("Ignoring auth change during gateway switch. kind=\(String(describing: kind), privacy: .public) path=\(path, privacy: .public)")
                return true
            }
            if codexUsageCacheWriteCount > 0 {
                Self.logger.debug("Ignoring auth change during cache write. kind=\(String(describing: kind), privacy: .public) path=\(path, privacy: .public)")
                return true
            }
            if !codexRefreshingAccountIds.isEmpty {
                Self.logger.debug("Ignoring auth change during refresh. kind=\(String(describing: kind), privacy: .public) path=\(path, privacy: .public)")
                return true
            }
        }

        return false
    }

    func withGatewaySwitchInProgress(_ operation: @MainActor () async -> Void) async {
        let token = UUID()
        gatewaySwitchInProgressTokens.insert(token)
        defer { gatewaySwitchInProgressTokens.remove(token) }
        await operation()
    }

    func ensureGatewayVirtualAccountActivatedForCurrentProviderIfNeeded() async {
        guard let gatewayProviderID = resolvedGatewayProviderIDForCLI() else {
            return
        }
        let virtual: CodexAuthAccount?
        if let dedicatedVirtual = await codexAuthManager.gatewayVirtualAccount(providerID: gatewayProviderID) {
            virtual = dedicatedVirtual
        } else {
            let accounts = (try? await codexAuthManager.loadAccounts()) ?? []
            virtual = accounts.first(where: { account in
                let data = codexAuthManager.accountAuthData(for: account)
                return Self.isGatewayVirtualCodexAccount(
                    relativeAuthPath: account.relativeAuthPath,
                    authData: data
                )
            })
        }
        guard let virtual else { return }
        try? await codexAuthManager.activateAccountAndMarkActive(virtual, for: provider)
    }

    func fetchCodexOutcomeWithTimeout(
        account: CodexAuthAccount,
        settings: UsageMonitorProviderSettings,
        authURL: URL
    ) async -> ProviderAccountUsageOutcome {
        let timeoutSeconds = max(3, TimeInterval(settings.webTimeoutSeconds)) + codexRefreshTimeoutGraceSeconds

        return await withTaskGroup(of: ProviderAccountUsageOutcome.self) { group in
            group.addTask { [codexOutcomeFetchAction] in
                await codexOutcomeFetchAction(account, settings, authURL)
            }
            group.addTask {
                let sleepSeconds = max(0.1, timeoutSeconds)
                try? await Task.sleep(nanoseconds: UInt64(sleepSeconds * 1_000_000_000))
                return Self.codexTimedOutOutcome(for: account, timeoutSeconds: timeoutSeconds)
            }

            let first = await group.next() ?? Self.codexTimedOutOutcome(for: account, timeoutSeconds: timeoutSeconds)
            group.cancelAll()
            return first
        }
    }

    nonisolated static func codexTimedOutOutcome(
        for account: CodexAuthAccount,
        timeoutSeconds: TimeInterval
    ) -> ProviderAccountUsageOutcome {
        let tokenAccount = ProviderTokenAccount(
            id: account.id,
            label: account.name,
            token: "",
            addedAt: account.createdAt.timeIntervalSince1970,
            lastUsed: nil
        )
        let error = NSError(
            domain: "ProviderUsageEngine.CodexRefresh",
            code: 408,
            userInfo: [
                NSLocalizedDescriptionKey: String(
                    format: NSLocalizedString(
                        "usage.monitor.codex.refresh_timeout",
                        value: "Codex refresh timed out after %.0f seconds.",
                        comment: "Codex refresh timeout message"
                    ),
                    timeoutSeconds
                )
            ]
        )
        return ProviderAccountUsageOutcome(
            provider: .codex,
            account: .tokenAccount(tokenAccount),
            outcome: ProviderFetchOutcome(fetchKind: .cli, result: .failure(error))
        )
    }

    nonisolated static func codexMissingAuthSourceOutcome(
        for account: CodexAuthAccount
    ) -> ProviderAccountUsageOutcome {
        let tokenAccount = ProviderTokenAccount(
            id: account.id,
            label: account.name,
            token: "",
            addedAt: account.createdAt.timeIntervalSince1970,
            lastUsed: nil
        )
        let error = NSError(
            domain: "ProviderUsageEngine.CodexRefresh",
            code: 404,
            userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString(
                    "usage.monitor.codex.missing_auth_source",
                    value: "Codex auth snapshot is missing.",
                    comment: "Codex auth source missing message"
                ),
            ]
        )
        return ProviderAccountUsageOutcome(
            provider: .codex,
            account: .tokenAccount(tokenAccount),
            outcome: ProviderFetchOutcome(fetchKind: .cli, result: .failure(error))
        )
    }

    func codexAuthSourceURL(for account: CodexAuthAccount) -> URL? {
        guard let data = codexAuthManager.accountAuthData(for: account), !data.isEmpty else {
            return nil
        }
        let folderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("nolon-codex-auth-sources", isDirectory: true)
            .appendingPathComponent(account.id.uuidString.lowercased(), isDirectory: true)
        let fileURL = folderURL.appendingPathComponent("auth.json", isDirectory: false)
        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            Self.logger.error("Failed to materialize Codex auth source file. accountId=\(account.id.uuidString, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func replaceCodexOutcome(_ outcome: ProviderAccountUsageOutcome, for accountID: UUID) {
        if let index = codexAccountOutcomes.firstIndex(where: { outcome in
            switch outcome.account {
            case let .tokenAccount(account):
                return account.id == accountID
            case .default:
                return false
            }
        }) {
            codexAccountOutcomes[index] = outcome
        } else {
            codexAccountOutcomes.append(outcome)
        }
        reorderCodexAccountOutcomesForDisplay()
    }

    func reorderCodexAccountOutcomesForDisplay() {
        let byAccountID = Dictionary(
            codexAccountOutcomes.compactMap { outcome -> (UUID, ProviderAccountUsageOutcome)? in
                switch outcome.account {
                case let .tokenAccount(account):
                    return (account.id, outcome)
                case .default:
                    return nil
                }
            },
            uniquingKeysWith: { _, newest in newest }
        )

        codexAccountOutcomes = uniqueCodexAccountIDsInDisplayOrder().compactMap { byAccountID[$0] }
    }

    func uniqueCodexAccountIDsInDisplayOrder() -> [UUID] {
        var seen: Set<UUID> = []
        return codexAccounts.compactMap { account in
            if seen.insert(account.id).inserted {
                return account.id
            }
            return nil
        }
    }

    func uniqueCodexAccountsInDisplayOrder() -> [CodexAuthAccount] {
        var seen: Set<UUID> = []
        return codexAccounts.compactMap { account in
            if seen.insert(account.id).inserted {
                return account
            }
            return nil
        }
    }

    func isAccountInfoMissing(accountId: UUID, summaries: [UUID: CodexAuthSummary]) -> Bool {
        let summary = summaries[accountId]
        let email = summary?.email?.trimmingCharacters(in: .whitespacesAndNewlines)
        let plan = summary?.plan?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let email, !email.isEmpty { return false }
        if let plan, !plan.isEmpty { return false }

        if let outcome = codexAccountOutcomes.first(where: { outcome in
            guard case let .tokenAccount(account) = outcome.account else { return false }
            return account.id == accountId
        }) {
            if case let .success(result) = outcome.outcome.result {
                if let identityEmail = result.usage.identity?.accountEmail?.trimmingCharacters(in: .whitespacesAndNewlines),
                   Self.isNotBlank(identityEmail)
                {
                    return false
                }
                if let identityPlan = result.usage.identity?.plan?.trimmingCharacters(in: .whitespacesAndNewlines),
                   Self.isNotBlank(identityPlan)
                {
                    return false
                }
            }
        }

        return true
    }

    func displayState(
        accountID: UUID?,
        outcome: ProviderAccountUsageOutcome,
        summary: CodexAuthSummary?
    ) -> CodexAccountDisplayState {
        if case let .failure(error) = outcome.outcome.result {
            let isAuthFailure = CodexAuthFailureClassifier.isAuthFailure(errorText: Self.errorDetailText(error: error))
            let supportsRelogin = summary?.cardKind == .chatgptAccount || summary?.cardKind == nil
            return (isAuthFailure && supportsRelogin) ? .needsReauth : .failed
        }

        let persistedFailureText = summary?.lastSyncFailureMessage?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let persistedFailureText, !persistedFailureText.isEmpty {
            let supportsRelogin = summary?.cardKind == .chatgptAccount || summary?.cardKind == nil
            return (CodexAuthFailureClassifier.isAuthFailure(errorText: persistedFailureText) && supportsRelogin)
            ? .needsReauth
            : .failed
        }
        if summary?.lastSyncFailedAt != nil {
            return .failed
        }

        guard let accountID else { return .pending }
        return codexRefreshedAccountIdsInSession.contains(accountID) ? .healthy : .pending
    }

    nonisolated static func fetchCodexOutcomeDetached(
        for account: CodexAuthAccount,
        settings: UsageMonitorProviderSettings,
        authSourceURL: URL
    ) async -> ProviderAccountUsageOutcome {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("nolon-codex-home-\(account.id.uuidString)", isDirectory: true)

        let tokenAccount = ProviderTokenAccount(
            id: account.id,
            label: account.name,
            token: "",
            addedAt: account.createdAt.timeIntervalSince1970,
            lastUsed: nil
        )

        do {
            try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true, attributes: nil)
            defer { try? FileManager.default.removeItem(at: tempRoot) }
            let authURL = tempRoot.appendingPathComponent("auth.json")
            let data = try Data(contentsOf: authSourceURL)
            let cleanData = CodexAuthManager.cleanedAuthJSONData(from: data) ?? data
            try STFile(authURL).overlay(with: cleanData)

            var environment = ProcessInfo.processInfo.environment
            if let managedEnv = try? await CodexBinaryManager.shared.launchEnvironmentVariables() {
                environment.merge(managedEnv) { _, new in new }
            }
            environment["CODEX_HOME"] = tempRoot.path
            environment[CodexHTTPUsageQueryExecutor.authSourcePathEnvironmentKey] = authSourceURL.path

            let context = ProviderFetchContext(
                provider: .codex,
                sourceMode: settings.sourceMode,
                includeCredits: settings.includeCredits,
                timeout: TimeInterval(settings.webTimeoutSeconds),
                costWindowDays: nil,
                environment: environment,
                token: nil
            )
            let descriptor = ProviderUsageRegistry.descriptor(for: .codex)
            let fetchOutcome = await descriptor.fetchOutcome(context: context)
            return ProviderAccountUsageOutcome(provider: .codex, account: .tokenAccount(tokenAccount), outcome: fetchOutcome)
        } catch {
            let fetchOutcome = ProviderFetchOutcome(fetchKind: .cli, result: .failure(error))
            return ProviderAccountUsageOutcome(provider: .codex, account: .tokenAccount(tokenAccount), outcome: fetchOutcome)
        }
    }

    nonisolated static func testCodexImportConnectionDetached(
        validationResult: CodexAuthManager.CodexImportValidationResult,
        settings: UsageMonitorProviderSettings
    ) async -> ProviderAccountUsageOutcome {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("nolon-codex-import-test-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tempRoot) }

            let authURL = tempRoot.appendingPathComponent("auth.json")
            let raw = validationResult.authJSONString ?? ""
            try Data(raw.utf8).write(to: authURL)

            let account = CodexAuthAccount(
                id: UUID(),
                name: validationResult.suggestedName ?? validationResult.fileURL.deletingPathExtension().lastPathComponent,
                createdAt: Date(),
                relativeAuthPath: "auth/import-test.json"
            )
            var environment = ProcessInfo.processInfo.environment
            if let managedEnv = try? await CodexBinaryManager.shared.launchEnvironmentVariables() {
                environment.merge(managedEnv) { _, new in new }
            }
            environment[CodexHTTPUsageQueryExecutor.authSourcePathEnvironmentKey] = authURL.path
            guard let resolved = try CodexHTTPUsageQueryExecutor.resolveConfiguration(from: environment),
                  resolved.source == CodexHTTPUsageQueryConfigurationSource.explicit
            else {
                let tokenAccount = ProviderTokenAccount(
                    id: account.id,
                    label: account.name,
                    token: "",
                    addedAt: account.createdAt.timeIntervalSince1970,
                    lastUsed: nil
                )
                let fetchOutcome = ProviderFetchOutcome(
                    fetchKind: .web,
                    result: .failure(NSError(
                        domain: "ProviderUsageEngine.CodexImportHTTP",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: NSLocalizedString(
                            "codex.import.sheet.test.skipped.no_explicit_http",
                            value: "未配置 HTTP 用量查询，已跳过在线测试；仍可继续导入。",
                            comment: "Skipped import online test because no explicit HTTP usage query is configured"
                        )]
                    ))
                )
                return ProviderAccountUsageOutcome(provider: .codex, account: .tokenAccount(tokenAccount), outcome: fetchOutcome)
            }

            do {
                let result = try await CodexHTTPUsageQueryExecutor().execute(resolved, includeCredits: settings.includeCredits)
                let fetchOutcome = ProviderFetchOutcome(fetchKind: .web, result: .success(result))
                let tokenAccount = ProviderTokenAccount(
                    id: account.id,
                    label: account.name,
                    token: "",
                    addedAt: account.createdAt.timeIntervalSince1970,
                    lastUsed: nil
                )
                return ProviderAccountUsageOutcome(provider: .codex, account: .tokenAccount(tokenAccount), outcome: fetchOutcome)
            } catch {
                let tokenAccount = ProviderTokenAccount(
                    id: account.id,
                    label: account.name,
                    token: "",
                    addedAt: account.createdAt.timeIntervalSince1970,
                    lastUsed: nil
                )
                let fetchOutcome = ProviderFetchOutcome(fetchKind: .web, result: .failure(error))
                return ProviderAccountUsageOutcome(provider: .codex, account: .tokenAccount(tokenAccount), outcome: fetchOutcome)
            }
        } catch {
            let tokenAccount = ProviderTokenAccount(
                id: UUID(),
                label: validationResult.suggestedName ?? validationResult.fileURL.lastPathComponent,
                token: "",
                addedAt: Date().timeIntervalSince1970,
                lastUsed: nil
            )
            let fetchOutcome = ProviderFetchOutcome(fetchKind: .cli, result: .failure(error))
            return ProviderAccountUsageOutcome(provider: .codex, account: .tokenAccount(tokenAccount), outcome: fetchOutcome)
        }
    }

    nonisolated static func validateCodexConfiguredAccountDetached(
        account: CodexAuthAccount,
        authManager: CodexAuthManager = .shared,
        session: URLSession = .shared
    ) async throws -> String {
        guard let authData = authManager.accountAuthData(for: account), !authData.isEmpty else {
            throw NSError(
                domain: "ProviderUsageEngine.CodexValidate",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "auth.json is missing for the selected account."]
            )
        }

        return try await CodexAccountValidationService.validate(authData: authData, session: session)
    }

    func readAuthJSONString(fromImportedFileURL url: URL) throws -> String {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped { url.stopAccessingSecurityScopedResource() }
        }

        let data = try Data(contentsOf: url)
        guard let raw = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        return raw
    }

    func prepareCLILoginHomeDirectory() throws -> URL {
        let providerID = CodexGatewayProviderIDResolver.resolveOrDefault(provider: provider)
        let codexHome = codexAuthManager.cliLoginCodexHomeFolder(providerID: providerID)
        _ = codexHome.createIfNotExists()
        try writeCLILoginConfig(codexHome: codexHome)
        try removeCLILoginAuthFileIfPresent(codexHome: codexHome)
        return codexHome.url.standardizedFileURL
    }

    func writeCLILoginConfig(codexHome: STFolder) throws {
        let configFile = codexHome.file("config.toml")
        let content = "cli_auth_credentials_store = \"file\"\n"
        if configFile.isExists,
           let existing = try? configFile.read(),
           existing == content {
            return
        }
        try configFile.overlay(with: content)
    }

    func removeCLILoginAuthFileIfPresent(codexHome: STFolder) throws {
        let authFileURL = codexHome.file("auth.json").url
        do {
            try FileManager.default.removeItem(at: authFileURL)
        } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileNoSuchFileError {
            return
        } catch let error as NSError where error.domain == NSPOSIXErrorDomain && error.code == ENOENT {
            return
        }
    }
}
