import SwiftUI
import AppKit
import ProviderCatalog
import Observation
import WebKit
import ProviderUsage
import CodexBarProviderCatalog
import UniformTypeIdentifiers
@preconcurrency import STFilePath

@MainActor
@Observable
final class ProviderUsageViewModel {
    private let service = UsageMonitorService()
    private let settingsStore = UsageMonitorSettingsStore.shared
    private let codexAuthService = CodexAuthService()
    @ObservationIgnored private var usageWatcher: UsageMonitorFileWatcher? = nil

    let provider: Provider
    let usageProvider: UsageProvider?

    var settings: UsageMonitorProviderSettings
    var supportedSourceModes: [ProviderSourceMode] = []
    var isMultiAccountEnabled: Bool

    var isLoading = false
    var outcomes: [ProviderAccountUsageOutcome] = []

    var isShowingLogin = false

    var codexAccounts: [CodexAuthAccount] = []
    var codexAccountOutcomes: [ProviderAccountUsageOutcome] = []
    var codexAccountSummaries: [UUID: CodexAuthSummary] = [:]
    var codexAccountCreditsRefreshedAt: [UUID: Date] = [:]
    var codexRefreshingAccountIds: Set<UUID> = []
    var currentCodexAuthHashHex: String?
    var codexAuthFilePath: String?
    var activeCodexAccountId: UUID?

    var addAccountSource: CodexAddSource = .current
    var importedAuthFileURL: URL?
    var isShowingAuthFileImporter = false
    var isRunningCLILogin = false
    var cliLoginStatus: String?

    var isShowingActivateConfirm = false
    var pendingActivateCodexAccount: CodexAuthAccount?

    var alertTitle: String?
    var alertMessage: String?

    private var cliLoginTask: Task<Void, Never>?
    private var cliLoginProcess: Process?
    private var codexAuthChangeSuppressions: [String: Date] = [:]
    private let codexAuthChangeSuppressionWindow: TimeInterval = 2.5
    private var codexUsageCacheWriteCount = 0
    private var hasTriggeredAppearRefresh = false
    private var didStartInitialLoad = false
    private var lastUsageRefreshAt: Date?

    init(provider: Provider) {
        self.provider = provider
        self.usageProvider = ProviderUsageViewModel.mapToUsageProvider(provider)
        self.settings = settingsStore.settings(for: provider)
        self.isMultiAccountEnabled = settingsStore.isMultiAccountEnabled(for: provider)
        self.updateSupportedModes()
        let watcher = UsageMonitorFileWatcher { [weak self] change in
            Task { await self?.handleUsageFileChange(change) }
        }
        self.usageWatcher = watcher
    }

    deinit {
        let watcher = usageWatcher
        Task { @MainActor in
            watcher?.stop()
        }
    }

    enum CodexAddSource: String, CaseIterable, Identifiable {
        case current
        case file
        case cliLogin

        var id: String { rawValue }

        var title: String {
            switch self {
            case .current:
                return NSLocalizedString("codex.accounts.add.source.current", value: "Current auth.json", comment: "Current auth.json")
            case .file:
                return NSLocalizedString("codex.accounts.add.source.file", value: "Import auth.json file", comment: "Import auth.json file")
            case .cliLogin:
                return NSLocalizedString("codex.accounts.add.source.cli", value: "CLI Login", comment: "CLI login")
            }
        }
    }

    func updateSettings(_ newSettings: UsageMonitorProviderSettings) {
        settings = newSettings
        settingsStore.update(settings: newSettings, for: provider)
    }

    @discardableResult
    func loadIfNeeded() async -> Bool {
        guard !didStartInitialLoad else { return false }
        didStartInitialLoad = true
        await load()
        return true
    }

    func handleUsageViewAppear() async {
        guard let usageProvider else { return }
        let now = Date()
        let intervalMinutes = settings.autoRefreshIntervalMinutes
        let intervalSeconds = TimeInterval(max(0, intervalMinutes)) * 60
        let shouldRefresh: Bool
        if !hasTriggeredAppearRefresh {
            hasTriggeredAppearRefresh = true
            shouldRefresh = true
        } else if intervalSeconds == 0 {
            shouldRefresh = true
        } else if let lastUsageRefreshAt {
            shouldRefresh = now.timeIntervalSince(lastUsageRefreshAt) >= intervalSeconds
        } else {
            shouldRefresh = true
        }

        guard shouldRefresh else { return }

        if await loadIfNeeded() {
            return
        }
        guard !isLoading else { return }

        if usageProvider == .codex, isMultiAccountEnabled {
            if codexAccounts.isEmpty {
                await load()
                return
            }

            if let account = activeCodexAccountForRefresh() {
                await refreshCodexAccountOutcome(account)
            } else {
                await load()
            }
            return
        }

        await load()
    }

    func load() async {
        guard let usageProvider else { return }

        didStartInitialLoad = true
        isLoading = true
        defer { isLoading = false }

        if usageProvider == .codex, isMultiAccountEnabled {
            outcomes = []
        } else {
            outcomes = await service.fetchOutcomes(provider: usageProvider, settings: settings)
            lastUsageRefreshAt = Date()
        }

        guard usageProvider == .codex else {
            await updateUsageFileWatcher()
            return
        }
        do {
            codexAuthFilePath = await codexAuthService.authFile(for: provider)?.url.path
            currentCodexAuthHashHex = await codexAuthService.currentAuthHashHex(for: provider)

            let loadedAccounts = try await codexAuthService.loadAccounts()

            guard isMultiAccountEnabled else {
                if let outcome = outcomes.first(where: { outcome in
                    if case .default = outcome.account { return true }
                    return false
                }) {
                    let merged = await mergeCachedCodexUsageIfNeeded(outcome: outcome, accounts: loadedAccounts)
                    outcomes = outcomes.map { item in
                        item.id == outcome.id ? merged : item
                    }
                    await persistCurrentCodexOutcomeIfPossible(outcome: merged, accounts: loadedAccounts)
                }
                resetCodexMultiAccountState()
                return
            }

            codexAccounts = loadedAccounts
            codexAccountSummaries = loadCodexAccountSummaries(accounts: codexAccounts)
            activeCodexAccountId = await codexAuthService.activeAccountId(for: provider)
            codexAccountOutcomes = await loadCachedCodexAccountOutcomes(accounts: codexAccounts)

            Task { [weak self] in
                guard let self else { return }
                await self.refreshCodexAccountsIfNeeded(
                    activeId: self.activeCodexAccountId,
                    summaries: self.codexAccountSummaries
                )
            }
        } catch {
            resetCodexMultiAccountState()
            guard isMultiAccountEnabled else { return }
            alertTitle = NSLocalizedString("codex.accounts.title", value: "Accounts", comment: "Codex accounts title")
            alertMessage = NSLocalizedString("codex.accounts.error.add", value: "Failed to add this account.", comment: "Error message")
        }

        await updateUsageFileWatcher()
    }

    func performAutoRefresh() async {
        guard !isLoading else { return }
        guard let usageProvider else { return }

        if usageProvider == .codex, isMultiAccountEnabled {
            if codexAccounts.isEmpty {
                await load()
                return
            }

            await refreshCodexAccountsIfNeeded(
                activeId: activeCodexAccountId,
                summaries: codexAccountSummaries
            )
            return
        }

        await load()
    }

    private func updateUsageFileWatcher() async {
        guard let usageProvider else {
            usageWatcher?.stop()
            return
        }

        var paths: [String] = []
        paths.append(UsageMonitorService.defaultTokenAccountsFileURL().path)

        if usageProvider == .codex {
            if isMultiAccountEnabled {
                paths.append(codexAuthService.nolonCodexAuthFolder().url.path)
            }
            if let authFile = await codexAuthService.authFile(for: provider) {
                paths.append(authFile.url.path)
            }
        }

        usageWatcher?.startWatching(paths: paths)
    }

    private func handleUsageFileChange(_ change: STPathChanged) async {
        guard !isLoading else { return }
        guard let usageProvider else { return }

        if usageProvider == .codex {
            await handleCodexUsageFileChange(change)
        } else {
            await load()
        }
    }

    private func handleCodexUsageFileChange(_ change: STPathChanged) async {
        let changedPath = change.path.url.standardizedFileURL.path
        if shouldIgnoreAuthChange(path: changedPath, kind: change.kind) {
            return
        }

        let authFolderPath = codexAuthService.nolonCodexAuthFolder().url.standardizedFileURL.path
        let authFilePath: String? = await {
            if let current = codexAuthFilePath {
                return normalizedPath(current)
            }
            if let refreshed = await codexAuthService.authFile(for: provider)?.url.path {
                codexAuthFilePath = refreshed
                return normalizedPath(refreshed)
            }
            return nil
        }()

        let isAuthFolderChange = changedPath == authFolderPath || changedPath.hasPrefix(authFolderPath + "/")
        let isAuthFileChange = authFilePath == changedPath

        guard isAuthFolderChange || isAuthFileChange else { return }

        if isAuthFileChange, let updatedFile = await codexAuthService.syncActiveAuthTokensIfNeeded(for: provider) {
            markAuthCacheWrite(at: updatedFile.url)
        }

        guard isMultiAccountEnabled else {
            await load()
            return
        }

        let refreshUsage: Bool
        if isAuthFileChange {
            refreshUsage = true
        } else {
            switch change.kind {
            case .created, .deleted, .renamed:
                refreshUsage = true
            case .modified:
                refreshUsage = false
            }
        }

        await reloadCodexFromDisk(refreshUsage: refreshUsage)
    }

    private func reloadCodexFromDisk(refreshUsage: Bool) async {
        do {
            codexAuthFilePath = await codexAuthService.authFile(for: provider)?.url.path
            currentCodexAuthHashHex = await codexAuthService.currentAuthHashHex(for: provider)

            let loadedAccounts = try await codexAuthService.loadAccounts()
            codexAccounts = loadedAccounts
            codexAccountSummaries = loadCodexAccountSummaries(accounts: codexAccounts)
            activeCodexAccountId = await codexAuthService.activeAccountId(for: provider)
            codexAccountOutcomes = await loadCachedCodexAccountOutcomes(accounts: codexAccounts)

            if refreshUsage {
                await refreshCodexAccountsIfNeeded(
                    activeId: activeCodexAccountId,
                    summaries: codexAccountSummaries
                )
            }
        } catch {
            // Ignore file reload errors; watcher will fire again on next change.
        }
    }

    private func normalizedPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }

    private func activeCodexAccountForRefresh() -> CodexAuthAccount? {
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

    private func loadCachedCodexAccountOutcomes(accounts: [CodexAuthAccount]) async -> [ProviderAccountUsageOutcome] {
        var outcomes: [ProviderAccountUsageOutcome] = []
        outcomes.reserveCapacity(accounts.count)
        var creditsRefreshedAt: [UUID: Date] = [:]

        for account in accounts {
            let tokenAccount = ProviderTokenAccount(
                id: account.id,
                label: account.name,
                token: "",
                addedAt: account.createdAt.timeIntervalSince1970,
                lastUsed: nil
            )

            if let cache = try? await codexAuthService.loadUsageCache(for: account) {
                if let credits = cache.credits, !credits.remaining.isNaN {
                    creditsRefreshedAt[account.id] = cache.creditsRefreshedAt ?? cache.cachedAt
                }
                let cachedResult = cache.toFetchResult()
                let cachedOutcome = ProviderFetchOutcome(
                    fetchKind: cache.fetchKind,
                    result: .success(cachedResult)
                )
                outcomes.append(
                    ProviderAccountUsageOutcome(
                        provider: .codex,
                        account: .tokenAccount(tokenAccount),
                        outcome: cachedOutcome
                    )
                )
            } else {
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
                    sourceLabel: NSLocalizedString("usage.monitor.cache.placeholder", value: "Cached", comment: "Placeholder cached usage label"),
                    fetchKind: .cli,
                    strategyKind: .direct
                )
                let placeholderOutcome = ProviderFetchOutcome(fetchKind: .cli, result: .success(placeholderResult))
                outcomes.append(
                    ProviderAccountUsageOutcome(
                        provider: .codex,
                        account: .tokenAccount(tokenAccount),
                        outcome: placeholderOutcome
                    )
                )
            }
        }

        codexAccountCreditsRefreshedAt = creditsRefreshedAt
        return outcomes
    }

    private func updateSupportedModes() {
        guard let usageProvider else { return }
        supportedSourceModes = ProviderUsageRegistry.fetchPlan(for: usageProvider).sourceModes
            .sorted(by: { $0.rawValue < $1.rawValue })
        if !supportedSourceModes.contains(settings.sourceMode) {
            updateSettings(UsageMonitorProviderSettings(
                sourceMode: .auto,
                includeCredits: settings.includeCredits,
                webTimeoutSeconds: settings.webTimeoutSeconds,
                autoRefreshIntervalMinutes: settings.autoRefreshIntervalMinutes))
        }
    }

    private static func mapToUsageProvider(_ provider: Provider) -> UsageProvider? {
        if let templateId = provider.templateId, let mapped = UsageProvider(rawValue: templateId) {
            return mapped
        }
        return nil
    }

    var dashboardURL: URL? {
        guard let usageProvider else { return nil }
        guard let raw = ProviderUsageRegistry.metadata(for: usageProvider)?.dashboardURL else { return nil }
        return URL(string: raw)
    }

    func beginAddAccount(_ source: CodexAddSource) {
        addAccountSource = source
        if source != .cliLogin {
            cancelCLILoginIfNeeded()
        }
        switch source {
        case .current:
            Task { await confirmAddAccount() }
        case .file:
            importedAuthFileURL = nil
            isShowingAuthFileImporter = true
        case .cliLogin:
            startCLILoginFlow()
        }
    }

    func confirmAddAccount() async {
        guard usageProvider == .codex else { return }
        guard addAccountSource != .cliLogin else {
            startCLILoginFlow()
            return
        }

        do {
            let authJSONString: String
            switch addAccountSource {
            case .current:
                guard let raw = try await codexAuthService.readAuthJSONString(from: provider) else {
                    alertTitle = NSLocalizedString("codex.accounts.add.title", value: "Add Account", comment: "Add account title")
                    alertMessage = NSLocalizedString("codex.accounts.current.none", value: "Current: No auth.json found.", comment: "Current auth summary")
                    return
                }
                authJSONString = raw
            case .file:
                guard let url = importedAuthFileURL else {
                    alertTitle = NSLocalizedString("codex.accounts.add.title", value: "Add Account", comment: "Add account title")
                    alertMessage = NSLocalizedString("codex.accounts.add.error.no_file", value: "Select an auth.json file first.", comment: "Error")
                    return
                }
                authJSONString = try readAuthJSONString(fromImportedFileURL: url)
            case .cliLogin:
                return
            }

            let finalName = codexAuthService.deriveAccountName(fromAuthJSONString: authJSONString)
            _ = try await codexAuthService.addAccount(name: finalName, authJSONString: authJSONString)
            await load()
        } catch {
            alertTitle = NSLocalizedString("codex.accounts.add.title", value: "Add Account", comment: "Add account title")
            alertMessage = NSLocalizedString("codex.accounts.error.add", value: "Failed to add this account.", comment: "Error message")
        }
    }

    func cancelCLILoginIfNeeded() {
        cliLoginTask?.cancel()
        cliLoginTask = nil
        if let process = cliLoginProcess, process.isRunning {
            process.terminate()
        }
        cliLoginProcess = nil
        isRunningCLILogin = false
        cliLoginStatus = nil
    }

    private func resetCodexMultiAccountState() {
        codexAccounts = []
        codexAccountOutcomes = []
        codexAccountSummaries = [:]
        codexAccountCreditsRefreshedAt = [:]
        codexRefreshingAccountIds = []
        currentCodexAuthHashHex = nil
        codexAuthFilePath = nil
        activeCodexAccountId = nil
        pendingActivateCodexAccount = nil
    }

    func startCLILoginFlow() {
        guard usageProvider == .codex else { return }
        guard !isRunningCLILogin else { return }

        isRunningCLILogin = true
        cliLoginStatus = NSLocalizedString("codex.accounts.add.cli.running", value: "Logging in…", comment: "CLI login running status")

        cliLoginTask?.cancel()
        cliLoginTask = Task { [weak self] in
            guard let self else { return }
            await self.runCLILoginFlow()
        }
    }

    private func runCLILoginFlow() async {
        defer {
            cliLoginProcess = nil
            cliLoginTask = nil
            isRunningCLILogin = false
            cliLoginStatus = nil
        }

        do {
            try await codexAuthService.prepareForCLILogin(provider: provider, archiveAccountName: nil)

            guard let authFile = await codexAuthService.authFile(for: provider) else {
                alertTitle = NSLocalizedString("codex.cli_login.title", value: "CLI Login", comment: "CLI login title")
                alertMessage = NSLocalizedString("codex.accounts.add.no_codex_home", value: "Codex home path could not be resolved from this provider.", comment: "No Codex home")
                return
            }

            let command = buildCodexLoginCommand()

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-lc", command]
            process.standardInput = nil
            process.standardOutput = nil
            process.standardError = nil
            try process.run()
            cliLoginProcess = process

            cliLoginStatus = NSLocalizedString("codex.accounts.add.cli.waiting", value: "Waiting for auth.json…", comment: "CLI login waiting status")

            let fileManager = FileManager.default
            while !Task.isCancelled {
                if fileManager.fileExists(atPath: authFile.url.path),
                   let data = try? authFile.data(),
                   !data.isEmpty {
                    break
                }

                if !process.isRunning, !fileManager.fileExists(atPath: authFile.url.path) {
                    alertTitle = NSLocalizedString("codex.cli_login.title", value: "CLI Login", comment: "CLI login title")
                    alertMessage = NSLocalizedString(
                        "codex.accounts.add.cli.error.no_auth",
                        value: "Login did not create auth.json.",
                        comment: "CLI login did not create auth.json"
                    )
                    return
                }

                try await Task.sleep(nanoseconds: 250_000_000)
            }

            guard !Task.isCancelled else { return }

            _ = try await codexAuthService.finalizeCLILogin(provider: provider, newAccountName: "")

            if process.isRunning {
                process.terminate()
            }

            await load()
        } catch {
            alertTitle = NSLocalizedString("codex.cli_login.title", value: "CLI Login", comment: "CLI login title")
            alertMessage = error.localizedDescription
        }
    }

    func requestActivateCodexAccount(id: UUID) {
        guard let account = codexAccounts.first(where: { $0.id == id }) else { return }
        pendingActivateCodexAccount = account
        isShowingActivateConfirm = true
    }

    func confirmActivate() async {
        guard let account = pendingActivateCodexAccount else { return }
        do {
            try await codexAuthService.activateAccount(account, for: provider)
            pendingActivateCodexAccount = nil
            await load()
        } catch {
            alertTitle = NSLocalizedString("codex.accounts.title", value: "Accounts", comment: "Codex accounts title")
            alertMessage = NSLocalizedString("codex.accounts.error.activate", value: "Failed to activate this account.", comment: "Error message")
        }
    }

    func isActiveCodexAccount(_ account: CodexAuthAccount) -> Bool {
        if let activeCodexAccountId {
            return account.id == activeCodexAccountId
        }
        guard let currentCodexAuthHashHex else { return false }
        let file = codexAuthService.accountAuthFile(relativeAuthPath: account.relativeAuthPath)
        guard let data = try? file.data(),
              let raw = String(data: data, encoding: .utf8)
        else { return false }
        return CodexAuthAccount.hashHex(for: raw) == currentCodexAuthHashHex
    }

    private func loadCodexAccountSummaries(accounts: [CodexAuthAccount]) -> [UUID: CodexAuthSummary] {
        var summaries: [UUID: CodexAuthSummary] = [:]
        summaries.reserveCapacity(accounts.count)
        for account in accounts {
            let file = codexAuthService.accountAuthFile(relativeAuthPath: account.relativeAuthPath)
            if let data = try? file.data() {
                summaries[account.id] = CodexAuthSummary.fromJSONData(data)
            }
        }
        return summaries
    }

    private func mergeCachedCodexUsageIfNeeded(
        outcome: ProviderAccountUsageOutcome,
        accounts: [CodexAuthAccount]
    ) async -> ProviderAccountUsageOutcome {
        guard case let .success(result) = outcome.outcome.result else { return outcome }
        guard let activeId = await codexAuthService.activeAccountId(for: provider),
              let activeAccount = accounts.first(where: { $0.id == activeId }),
              let cache = try? await codexAuthService.loadUsageCache(for: activeAccount)
        else { return outcome }

        let mergedUsage = mergeUsageSnapshot(live: result.usage, cached: cache.usage)
        let mergedResult = ProviderFetchResult(
            usage: mergedUsage,
            credits: result.credits,
            cost: result.cost,
            sourceLabel: result.sourceLabel,
            fetchKind: result.fetchKind,
            strategyKind: result.strategyKind
        )
        let mergedOutcome = ProviderFetchOutcome(fetchKind: outcome.outcome.fetchKind, result: .success(mergedResult))
        return ProviderAccountUsageOutcome(provider: outcome.provider, account: outcome.account, outcome: mergedOutcome)
    }

    private func mergeUsageSnapshot(live: UsageSnapshot, cached: UsageSnapshot) -> UsageSnapshot {
        UsageSnapshot(
            identity: live.identity ?? cached.identity,
            primary: mergeRateWindow(live: live.primary, cached: cached.primary),
            secondary: mergeRateWindow(live: live.secondary, cached: cached.secondary),
            tertiary: mergeRateWindow(live: live.tertiary, cached: cached.tertiary),
            updatedAt: live.updatedAt
        )
    }

    private func mergeRateWindow(live: RateWindow?, cached: RateWindow?) -> RateWindow? {
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
        let file = codexAuthService.accountAuthFile(relativeAuthPath: account.relativeAuthPath)
        NSWorkspace.shared.activateFileViewerSelecting([file.url])
    }

    func refreshCodexAccount(id: UUID) {
        guard let account = codexAccounts.first(where: { $0.id == id }) else { return }
        Task { [weak self] in
            guard let self else { return }
            await self.refreshCodexAccountOutcome(account)
        }
    }

    private func refreshCodexAccountsIfNeeded(activeId: UUID?, summaries: [UUID: CodexAuthSummary]) async {
        let targets = codexAccounts.filter { account in
            let isActive = account.id == activeId || (activeId == nil && isActiveCodexAccount(account))
            if isActive { return true }
            return isAccountInfoMissing(accountId: account.id, summaries: summaries)
        }

        for account in targets {
            await refreshCodexAccountOutcome(account)
        }
    }

    private func refreshCodexAccountOutcome(_ account: CodexAuthAccount) async {
        let accountId = account.id
        guard isMultiAccountEnabled,
              codexAccounts.contains(where: { $0.id == accountId })
        else {
            return
        }
        guard !codexRefreshingAccountIds.contains(accountId) else { return }

        codexRefreshingAccountIds.insert(accountId)
        defer { codexRefreshingAccountIds.remove(accountId) }

        let outcome = await fetchCodexOutcome(for: account, settings: settings)
        updateCodexOutcome(outcome, for: account)
        lastUsageRefreshAt = Date()

        if case let .success(result) = outcome.outcome.result {
            let now = Date()
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
                    cost: result.cost
                )
                let targetFile = codexAuthService.accountAuthFile(relativeAuthPath: account.relativeAuthPath)
                markAuthCacheWrite(at: targetFile.url)
                codexUsageCacheWriteCount += 1
                defer { codexUsageCacheWriteCount = max(0, codexUsageCacheWriteCount - 1) }
                try await codexAuthService.storeUsageCache(cache, for: account)
            } catch {
                // Best-effort cache write; ignore.
            }

            if let identity = result.usage.identity {
                var summary = codexAccountSummaries[accountId] ?? CodexAuthSummary()
                if let email = identity.accountEmail?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !email.isEmpty,
                   summary.email == nil
                {
                    summary.email = email
                }
                if let plan = identity.plan?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !plan.isEmpty,
                   summary.plan == nil
                {
                    summary.plan = plan
                }
                codexAccountSummaries[accountId] = summary
            }
        }
    }

    private func persistCurrentCodexOutcomeIfPossible(
        outcome: ProviderAccountUsageOutcome,
        accounts: [CodexAuthAccount]
    ) async {
        guard case let .success(result) = outcome.outcome.result else { return }
        guard !accounts.isEmpty else { return }
        guard let activeId = await codexAuthService.activeAccountId(for: provider),
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
                cost: result.cost
            )
            let targetFile = codexAuthService.accountAuthFile(relativeAuthPath: activeAccount.relativeAuthPath)
            markAuthCacheWrite(at: targetFile.url)
            codexUsageCacheWriteCount += 1
            defer { codexUsageCacheWriteCount = max(0, codexUsageCacheWriteCount - 1) }
            try await codexAuthService.storeUsageCache(cache, for: activeAccount)
        } catch {
            // Best-effort cache write; ignore.
        }
    }

    private func markAuthCacheWrite(at url: URL) {
        let expiry = Date().addingTimeInterval(codexAuthChangeSuppressionWindow)
        let filePath = url.standardizedFileURL.path
        codexAuthChangeSuppressions[filePath] = expiry

        let folderPath = codexAuthService.nolonCodexAuthFolder().url.standardizedFileURL.path
        codexAuthChangeSuppressions[folderPath] = expiry
    }

    private func shouldIgnoreAuthChange(path: String, kind: STPathChangeKind) -> Bool {
        let now = Date()
        codexAuthChangeSuppressions = codexAuthChangeSuppressions.filter { $0.value > now }
        if codexUsageCacheWriteCount > 0, kind == .renamed {
            let authFolderPath = codexAuthService.nolonCodexAuthFolder().url.standardizedFileURL.path
            if path == authFolderPath || path.hasPrefix(authFolderPath + "/") {
                return true
            }
        }

        guard !codexAuthChangeSuppressions.isEmpty else { return false }

        if let expiry = codexAuthChangeSuppressions[path], expiry > now {
            return true
        }

        for (key, expiry) in codexAuthChangeSuppressions where expiry > now {
            if path.hasPrefix(key + "/") { return true }
        }

        return false
    }

    private func updateCodexOutcome(_ outcome: ProviderAccountUsageOutcome, for account: CodexAuthAccount) {
        guard let index = codexAccounts.firstIndex(where: { $0.id == account.id }) else { return }
        if codexAccountOutcomes.indices.contains(index) {
            codexAccountOutcomes[index] = outcome
        } else {
            codexAccountOutcomes.append(outcome)
        }
    }

    private func isAccountInfoMissing(accountId: UUID, summaries: [UUID: CodexAuthSummary]) -> Bool {
        let summary = summaries[accountId]
        let email = summary?.email?.trimmingCharacters(in: .whitespacesAndNewlines)
        let plan = summary?.plan?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let email, !email.isEmpty { return false }
        if let plan, !plan.isEmpty { return false }

        if let outcome = codexAccountOutcomes.first(where: { outcome in
            if case let .tokenAccount(account) = outcome.account {
                return account.id == accountId
            }
            return false
        }) {
            if case let .success(result) = outcome.outcome.result {
                if let identityEmail = result.usage.identity?.accountEmail?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !identityEmail.isEmpty
                {
                    return false
                }
                if let identityPlan = result.usage.identity?.plan?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !identityPlan.isEmpty
                {
                    return false
                }
            }
        }

        return true
    }

    private func fetchCodexOutcome(for account: CodexAuthAccount, settings: UsageMonitorProviderSettings) async -> ProviderAccountUsageOutcome {
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
            let file = codexAuthService.accountAuthFile(relativeAuthPath: account.relativeAuthPath)
            let data = try file.data()
            let cleanData = CodexAuthService.cleanedAuthJSONData(from: data) ?? data
            try STFile(authURL).overlay(with: cleanData)

            var environment = ProcessInfo.processInfo.environment
            environment["CODEX_HOME"] = tempRoot.path

            let context = ProviderFetchContext(
                provider: .codex,
                sourceMode: settings.sourceMode,
                includeCredits: settings.includeCredits,
                timeout: TimeInterval(settings.webTimeoutSeconds),
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

    private func readAuthJSONString(fromImportedFileURL url: URL) throws -> String {
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

    private func buildCodexLoginCommand() -> String {
        let skillsURL = URL(fileURLWithPath: provider.defaultSkillsPath)
        let codexHome = skillsURL.deletingLastPathComponent().path
        let escaped = codexHome.replacingOccurrences(of: "\"", with: "\\\"")
        return "CODEX_HOME=\"\(escaped)\" codex login"
    }
}

struct ProviderUsageView: View {
    let provider: Provider
    let isEmbedded: Bool
    @State private var viewModel: ProviderUsageViewModel

    private let codexAccountColumns: [GridItem] = [
        GridItem(.adaptive(minimum: 240, maximum: 340), spacing: 12, alignment: .topLeading)
    ]

    init(provider: Provider, isEmbedded: Bool = false) {
        self.provider = provider
        self.isEmbedded = isEmbedded
        self._viewModel = State(initialValue: ProviderUsageViewModel(provider: provider))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            content

        }
        .if(!isEmbedded) { view in
            view.navigationTitle(NSLocalizedString("tab.usage", value: "Usage", comment: "Usage"))
        }
        .task(id: provider.id) {
            await viewModel.loadIfNeeded()
        }
        .onAppear {
            Task { await viewModel.handleUsageViewAppear() }
        }
        .onChange(of: viewModel.settings) { _, _ in
            Task { await viewModel.load() }
        }
        .sheet(isPresented: Bindable(viewModel).isShowingLogin) {
            UsageLoginSheet(title: provider.name, url: viewModel.dashboardURL)
        }
        .fileImporter(
            isPresented: $viewModel.isShowingAuthFileImporter,
            allowedContentTypes: [.json, .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                viewModel.importedAuthFileURL = urls.first
                if urls.first != nil {
                    viewModel.addAccountSource = .file
                    Task { await viewModel.confirmAddAccount() }
                }
            case .failure:
                viewModel.importedAuthFileURL = nil
            }
        }
        .alert(viewModel.alertTitle ?? "", isPresented: Binding(get: {
            viewModel.alertTitle != nil || viewModel.alertMessage != nil
        }, set: { newValue in
            if !newValue {
                viewModel.alertTitle = nil
                viewModel.alertMessage = nil
            }
        })) {
            Button(NSLocalizedString("generic.ok", value: "OK", comment: "OK")) {
                viewModel.alertTitle = nil
                viewModel.alertMessage = nil
            }
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
        .alert(
            NSLocalizedString("codex.accounts.activate.title", value: "Activate Account", comment: "Activate account title"),
            isPresented: $viewModel.isShowingActivateConfirm
        ) {
            Button(NSLocalizedString("generic.cancel", value: "Cancel", comment: "Cancel"), role: .cancel) {
                viewModel.pendingActivateCodexAccount = nil
            }
            Button(NSLocalizedString("codex.accounts.action.activate", value: "Activate", comment: "Activate account")) {
                Task { await viewModel.confirmActivate() }
            }
        } message: {
            let name = viewModel.pendingActivateCodexAccount?.name ?? ""
            let path = viewModel.codexAuthFilePath ?? "~/.codex/auth.json"
            let format = NSLocalizedString(
                "codex.accounts.activate.message",
                value: "Switch to \"%@\"? This will overwrite:\n%@",
                comment: "Activate account message"
            )
            Text(String(format: format, name, path))
        }
        .task(id: viewModel.settings.autoRefreshIntervalMinutes) {
            let minutes = viewModel.settings.autoRefreshIntervalMinutes
            guard minutes > 0 else { return }
            let interval = UInt64(minutes) * 60 * 1_000_000_000
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: interval)
                if Task.isCancelled { break }
                await viewModel.performAutoRefresh()
            }
        }
    }

    private var autoRefreshIntervalBinding: Binding<Int> {
        Binding(
            get: { viewModel.settings.autoRefreshIntervalMinutes },
            set: { newValue in
                var updated = viewModel.settings
                updated.autoRefreshIntervalMinutes = newValue
                viewModel.settings = updated
            }
        )
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.usageProvider == nil {
            ContentUnavailableView(
                NSLocalizedString("usage.monitor.unsupported.title", value: "Usage not supported", comment: "Unsupported title"),
                systemImage: "chart.bar.xaxis",
                description: Text(NSLocalizedString(
                    "usage.monitor.unsupported.desc",
                    value: "Usage is not configured for this provider yet.",
                    comment: "Unsupported description"
                ))
            )
        } else if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.usageProvider == .codex {
            codexContent
        } else if viewModel.outcomes.isEmpty {
            ContentUnavailableView(
                NSLocalizedString("usage.monitor.empty.title", value: "No usage data", comment: "Empty title"),
                systemImage: "chart.bar",
                description: Text(NSLocalizedString("usage.monitor.empty.desc", value: "No provider data available yet.", comment: "Empty description"))
            )
        } else {
            genericUsageContent
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(provider.name)
                .font(.headline)

            Spacer()

            if viewModel.usageProvider != .codex {
                Button(NSLocalizedString("usage.monitor.login", value: "Sign in…", comment: "Sign in")) {
                    viewModel.isShowingLogin = true
                }
            }

            actionsMenu
        }
        .onChange(of: viewModel.settings) { _, newValue in
            viewModel.updateSettings(newValue)
        }
    }

    private var actionsMenu: some View {
        Menu {
            Button(NSLocalizedString("usage.monitor.refresh", value: "Refresh", comment: "Refresh")) {
                Task { await viewModel.load() }
            }

            Divider()

            Picker(
                NSLocalizedString("usage.monitor.auto_refresh.title", value: "Auto refresh", comment: "Auto refresh interval"),
                selection: autoRefreshIntervalBinding
            ) {
                ForEach(UsageAutoRefreshInterval.allCases) { option in
                    Text(option.title).tag(option.rawValue)
                }
            }

            if viewModel.usageProvider == .codex {
                Divider()

                Menu(NSLocalizedString("codex.accounts.action.add", value: "Add Account", comment: "Add account")) {
                    Button(NSLocalizedString("codex.accounts.add.source.current", value: "Current auth.json", comment: "Current auth.json")) {
                        viewModel.beginAddAccount(.current)
                    }
                    Button(NSLocalizedString("codex.accounts.add.source.file", value: "Import auth.json file", comment: "Import auth.json file")) {
                        viewModel.beginAddAccount(.file)
                    }
                    Button(NSLocalizedString("codex.accounts.add.source.cli", value: "CLI Login", comment: "CLI login")) {
                        viewModel.beginAddAccount(.cliLogin)
                    }
                    .disabled(viewModel.isRunningCLILogin)

                    if let status = viewModel.cliLoginStatus, viewModel.isRunningCLILogin {
                        Divider()
                        Text(status)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(!viewModel.isMultiAccountEnabled)

                Toggle(
                    NSLocalizedString("codex.accounts.multi.enable", value: "Multi-account", comment: "Multi-account toggle"),
                    isOn: Binding(
                        get: { viewModel.isMultiAccountEnabled },
                        set: { viewModel.setMultiAccountEnabled($0) }
                    )
                )
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.body)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private var genericUsageContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(viewModel.outcomes) { outcome in
                    ProviderUsageSnapshotView(outcome: outcome)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var codexCurrentOutcome: ProviderAccountUsageOutcome? {
        if let outcome = viewModel.outcomes.first(where: { outcome in
            if case .default = outcome.account { return true }
            return false
        }) {
            return outcome
        }
        return viewModel.outcomes.first
    }

    private func creditsRefreshedAt(for outcome: ProviderAccountUsageOutcome) -> Date? {
        guard viewModel.usageProvider == .codex else { return nil }
        switch outcome.account {
        case let .tokenAccount(account):
            return viewModel.codexAccountCreditsRefreshedAt[account.id]
        case .default:
            if let activeId = viewModel.activeCodexAccountId {
                return viewModel.codexAccountCreditsRefreshedAt[activeId]
            }
            return nil
        }
    }

    private var codexContent: some View {
        ScrollView {
            if viewModel.isMultiAccountEnabled {
                VStack(alignment: .leading, spacing: 16) {
                    if viewModel.codexAccounts.isEmpty {
                        ContentUnavailableView(
                            NSLocalizedString("codex.accounts.empty.title", value: "No accounts", comment: "Empty state title"),
                            systemImage: "person.crop.circle.badge.plus",
                            description: Text(NSLocalizedString(
                                "codex.accounts.empty.desc",
                                value: "Add a snapshot of Codex auth.json to quickly switch accounts.",
                                comment: "Empty state description"
                            ))
                        )
                    }

                    LazyVGrid(columns: codexAccountColumns, alignment: .leading, spacing: 12) {
                        ForEach(viewModel.codexAccountOutcomes) { outcome in
                            codexOutcomeCard(outcome: outcome)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    if let outcome = codexCurrentOutcome {
                        ProviderUsageSnapshotView(
                            outcome: outcome,
                            creditsRefreshedAt: creditsRefreshedAt(for: outcome)
                        )
                    } else {
                        ContentUnavailableView(
                            NSLocalizedString("usage.monitor.empty.title", value: "No usage data", comment: "Empty title"),
                            systemImage: "chart.bar",
                            description: Text(NSLocalizedString("usage.monitor.empty.desc", value: "No provider data available yet.", comment: "Empty description"))
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func codexOutcomeCard(outcome: ProviderAccountUsageOutcome) -> some View {
        let accountId: UUID? = {
            switch outcome.account {
            case .default:
                return nil
            case let .tokenAccount(account):
                return account.id
            }
        }()

        let isPending: Bool = {
            guard let accountId else { return false }
            return viewModel.pendingActivateCodexAccount?.id == accountId
        }()

        let isActive: Bool = {
            guard let accountId else { return false }
            guard let saved = viewModel.codexAccounts.first(where: { $0.id == accountId }) else { return false }
            return viewModel.isActiveCodexAccount(saved)
        }()

        let isSelected = isActive || isPending
        let borderColor = isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.Component.border.opacity(0.35)
        let borderStyle = StrokeStyle(
            lineWidth: isSelected ? 2 : 1,
            dash: isPending && !isActive ? [6, 4] : []
        )
        let summary = accountId.flatMap { viewModel.codexAccountSummaries[$0] }
        let creditsRefreshedAt = accountId.flatMap { viewModel.codexAccountCreditsRefreshedAt[$0] }
        let isRefreshing = accountId.map { viewModel.codexRefreshingAccountIds.contains($0) } ?? false

        codexCompactSnapshotView(
            outcome: outcome,
            isSelected: isSelected,
            isRefreshing: isRefreshing,
            summary: summary,
            creditsRefreshedAt: creditsRefreshedAt,
            onRefresh: accountId.map { id in
                { viewModel.refreshCodexAccount(id: id) }
            }
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    borderColor,
                    style: borderStyle
                )
        }
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(DesignSystem.Colors.primary.opacity(isActive ? 0.12 : 0.08))
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture {
            guard let accountId, !isActive else { return }
            viewModel.requestActivateCodexAccount(id: accountId)
        }
        .contextMenu {
            if let accountId {
                Button {
                    viewModel.revealCodexAccountInFinder(id: accountId)
                } label: {
                    Label(NSLocalizedString("action.show_in_finder", comment: "Show in Finder"), systemImage: "folder")
                }
            }
        }
    }

    @ViewBuilder
    private func codexCompactSnapshotView(
        outcome: ProviderAccountUsageOutcome,
        isSelected: Bool,
        isRefreshing: Bool,
        summary: CodexAuthSummary?,
        creditsRefreshedAt: Date?,
        onRefresh: (() -> Void)?
    ) -> some View {
        let title = outcome.displayName
        let fallbackEmail = summary?.email?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackPlan = summary?.plan?.trimmingCharacters(in: .whitespacesAndNewlines)

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.Text.primary)
                    .lineLimit(1)

                Spacer()

                if let onRefresh {
                    Button {
                        onRefresh()
                    } label: {
                        if isRefreshing {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption.weight(.semibold))
                        }
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    .help(NSLocalizedString("usage.monitor.refresh", value: "Refresh", comment: "Refresh"))
                }
            }

            switch outcome.outcome.result {
            case let .success(result):
                let identity = result.usage.identity?.scoped(to: outcome.provider)
                let email = (identity?.accountEmail?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? fallbackEmail
                let plan = (identity?.plan?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? fallbackPlan

                if let subtitle = codexSubtitleText(title: title, email: email, plan: plan) {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                        .lineLimit(1)
                }

                let metadata = ProviderUsageRegistry.metadata(for: outcome.provider)

                if result.usage.primary == nil,
                   result.usage.secondary == nil,
                   result.usage.tertiary == nil,
                   result.credits == nil
                {
                    Text(result.usage.updatedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        if let primary = result.usage.primary {
                            codexQuotaRow(
                                title: metadata?.sessionLabel
                                    ?? NSLocalizedString("usage.metric.session", value: "Session", comment: "Session"),
                                window: primary
                            )
                        }

                        if let secondary = result.usage.secondary {
                            codexQuotaRow(
                                title: metadata?.weeklyLabel
                                    ?? NSLocalizedString("usage.metric.weekly", value: "Weekly", comment: "Weekly"),
                                window: secondary
                            )
                        }

                        if let tertiary = result.usage.tertiary {
                            codexQuotaRow(
                                title: metadata?.opusLabel
                                    ?? NSLocalizedString("usage.metric.third", value: "Other", comment: "Other"),
                                window: tertiary
                            )
                        }

                        if let credits = result.credits, !credits.remaining.isNaN {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text(NSLocalizedString("usage.metric.credits", value: "Credits", comment: "Credits"))
                                        .font(.caption)
                                        .foregroundStyle(DesignSystem.Colors.Text.tertiary)

                                    Spacer()

                                    Text(codexCreditsText(credits.remaining))
                                        .font(.caption)
                                        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                                        .monospacedDigit()
                                }

                                Text(credits.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)

                                if let creditsRefreshedAt {
                                    Text(String(
                                        format: NSLocalizedString(
                                            "usage.metric.refreshed_at",
                                            value: "Refreshed %@",
                                            comment: "Credits refreshed time"),
                                        creditsRefreshedAt.formatted(date: .abbreviated, time: .shortened)
                                    ))
                                    .font(.caption)
                                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                                }
                            }
                        }

                        if let cost = result.cost {
                            let todayLine = codexCostLineToday(cost)
                            let last30Line = codexCostLineLast30(cost)
                            if todayLine != nil || last30Line != nil {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(NSLocalizedString("usage.metric.cost", value: "Cost", comment: "Cost label"))
                                        .font(.caption)
                                        .foregroundStyle(DesignSystem.Colors.Text.tertiary)

                                    if let todayLine {
                                        Text(todayLine)
                                            .font(.caption)
                                            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                                    }
                                    if let last30Line {
                                        Text(last30Line)
                                            .font(.caption)
                                            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                                    }
                                }
                            }
                        }
                    }
                }
            case let .failure(error):
                if let subtitle = codexSubtitleText(title: title, email: fallbackEmail, plan: fallbackPlan) {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                        .lineLimit(1)
                }

                let errorText = {
                    let trimmed = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                    return trimmed.isEmpty ? String(describing: error) : trimmed
                }()

                Text(NSLocalizedString("usage.monitor.error.title", value: "Failed to load usage", comment: "Error title"))
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Status.error)
                    .lineLimit(1)

                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                    .lineLimit(2)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .background(DesignSystem.Colors.Background.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func codexSubtitleText(title: String, email: String?, plan: String?) -> String? {
        let trimmedEmail = email?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPlan = plan?.trimmingCharacters(in: .whitespacesAndNewlines)

        let parts = [
            (trimmedEmail?.isEmpty == false && trimmedEmail != title) ? trimmedEmail : nil,
            (trimmedPlan?.isEmpty == false) ? trimmedPlan : nil,
        ].compactMap { $0 }

        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private func codexQuotaRow(title: String, window: RateWindow) -> some View {
        let percent = min(100, max(0, window.remainingPercent))

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)

                Spacer()

                Text(String(format: "%.0f%%", percent))
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                    .monospacedDigit()
            }

            ProgressView(value: percent, total: 100)
                .tint(DesignSystem.Colors.primary)
                .controlSize(.small)

            let periodText = codexWindowPeriodText(window.windowMinutes)
            let countdownText = codexResetCountdownText(resetsAt: window.resetsAt)
            if periodText != nil || countdownText != nil {
                HStack(spacing: 8) {
                    if let periodText {
                        Text(periodText)
                    }

                    Spacer()

                    if let countdownText {
                        Text(countdownText)
                    }
                }
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                .lineLimit(1)
            }
        }
    }

    private func codexResetCountdownText(resetsAt: Date?) -> String? {
        guard let resetsAt else { return nil }
        let remaining = max(0, resetsAt.timeIntervalSinceNow)
        if remaining <= 0 { return nil }
        let seconds = Int(remaining.rounded(.down))
        let minutes = max(0, seconds / 60)
        let days = minutes / (60 * 24)
        let hours = (minutes % (60 * 24)) / 60
        let mins = minutes % 60

        let isChinese = isChineseLocale
        let dayUnit = isChinese ? "天" : "d"
        let hourUnit = isChinese ? "小时" : "h"
        let minuteUnit = isChinese ? "分钟" : "m"

        var parts: [String] = []
        if days > 0 { parts.append("\(days)\(dayUnit)") }
        if hours > 0 { parts.append("\(hours)\(hourUnit)") }
        if parts.isEmpty, mins > 0 { parts.append("\(mins)\(minuteUnit)") }
        if parts.count < 2, mins > 0, days == 0, hours > 0 {
            parts.append("\(mins)\(minuteUnit)")
        }
        let countdown = parts.joined()
        if countdown.isEmpty { return nil }

        return String(
            format: NSLocalizedString(
                "usage.metric.resets_in_compact",
                value: "resets in %@",
                comment: "Compact resets countdown label"
            ),
            countdown
        )
    }

    private func codexWindowPeriodText(_ windowMinutes: Int?) -> String? {
        guard let windowMinutes, windowMinutes > 0 else { return nil }

        let weekMinutes = 60 * 24 * 7
        let dayMinutes = 60 * 24
        let isChinese = isChineseLocale

        if windowMinutes % weekMinutes == 0 {
            let value = windowMinutes / weekMinutes
            return isChinese ? "\(value)周" : "\(value)w"
        }
        if windowMinutes % dayMinutes == 0 {
            let value = windowMinutes / dayMinutes
            return isChinese ? "\(value)天" : "\(value)d"
        }
        if windowMinutes % 60 == 0 {
            let value = windowMinutes / 60
            return isChinese ? "\(value)小时" : "\(value)h"
        }
        return isChinese ? "\(windowMinutes)分钟" : "\(windowMinutes)m"
    }

    private var isChineseLocale: Bool {
        if #available(macOS 13.0, *) {
            if let code = Locale.current.language.languageCode?.identifier {
                return code.hasPrefix("zh")
            }
        }
        if let code = Locale.current.languageCode {
            return code.hasPrefix("zh")
        }
        return Locale.current.identifier.hasPrefix("zh")
    }

    private func codexCreditsText(_ value: Double) -> String {
        if value.isInfinite {
            return NSLocalizedString("usage.metric.unlimited", value: "Unlimited", comment: "Unlimited")
        }
        if value.isNaN {
            return NSLocalizedString("usage.metric.unknown", value: "Unknown", comment: "Unknown")
        }
        return String(format: "%.0f", value)
    }

    private func codexCostLineToday(_ cost: CostSnapshot) -> String? {
        guard let dollars = cost.todayCostUSD else { return nil }
        let tokens = cost.todayTokens
        let tokenText = tokens.map { " • \(codexTokenCountText($0))" } ?? ""
        return String(
            format: NSLocalizedString(
                "usage.metric.cost.today_format",
                value: "Today: $%.2f%@",
                comment: "Today cost format"
            ),
            dollars,
            tokenText
        )
    }

    private func codexCostLineLast30(_ cost: CostSnapshot) -> String? {
        guard let dollars = cost.last30DaysCostUSD else { return nil }
        let tokens = cost.last30DaysTokens
        let tokenText = tokens.map { " • \(codexTokenCountText($0))" } ?? ""
        return String(
            format: NSLocalizedString(
                "usage.metric.cost.last30_format",
                value: "Last 30 days: $%.2f%@",
                comment: "Last 30 days cost format"
            ),
            dollars,
            tokenText
        )
    }

    private func codexTokenCountText(_ value: Int) -> String {
        if value >= 1_000_000 {
            let millions = Double(value) / 1_000_000.0
            return String(format: NSLocalizedString("usage.metric.tokens_m", value: "%.0fM tokens", comment: "Token count in millions"), millions)
        }
        if value >= 1_000 {
            let thousands = Double(value) / 1_000.0
            return String(format: NSLocalizedString("usage.metric.tokens_k", value: "%.0fK tokens", comment: "Token count in thousands"), thousands)
        }
        return String(format: NSLocalizedString("usage.metric.tokens", value: "%d tokens", comment: "Token count"), value)
    }

}

private extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

private extension ProviderSourceMode {
    var displayName: String {
        switch self {
        case .auto: return NSLocalizedString("usage.monitor.source_mode.auto", value: "Auto", comment: "Auto")
        case .cli: return NSLocalizedString("usage.monitor.source_mode.cli", value: "CLI", comment: "CLI")
        case .web: return NSLocalizedString("usage.monitor.source_mode.web", value: "Web", comment: "Web")
        case .oauth: return NSLocalizedString("usage.monitor.source_mode.oauth", value: "OAuth", comment: "OAuth")
        case .apiToken: return NSLocalizedString("usage.monitor.source_mode.api_token", value: "API token", comment: "API token")
        case .localProbe: return NSLocalizedString("usage.monitor.source_mode.local_probe", value: "Local probe", comment: "Local probe")
        case .webDashboard: return NSLocalizedString("usage.monitor.source_mode.web_dashboard", value: "Web dashboard", comment: "Web dashboard")
        }
    }
}

private enum UsageAutoRefreshInterval: Int, CaseIterable, Identifiable {
    case off = 0
    case fiveMinutes = 5
    case fifteenMinutes = 15
    case thirtyMinutes = 30
    case twoHours = 120
    case fiveHours = 300

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .off:
            return NSLocalizedString("usage.monitor.auto_refresh.off", value: "Off", comment: "Auto refresh off")
        case .fiveMinutes:
            return NSLocalizedString("usage.monitor.auto_refresh.5m", value: "5m", comment: "Auto refresh 5 minutes")
        case .fifteenMinutes:
            return NSLocalizedString("usage.monitor.auto_refresh.15m", value: "15m", comment: "Auto refresh 15 minutes")
        case .thirtyMinutes:
            return NSLocalizedString("usage.monitor.auto_refresh.30m", value: "30m", comment: "Auto refresh 30 minutes")
        case .twoHours:
            return NSLocalizedString("usage.monitor.auto_refresh.2h", value: "2h", comment: "Auto refresh 2 hours")
        case .fiveHours:
            return NSLocalizedString("usage.monitor.auto_refresh.5h", value: "5h", comment: "Auto refresh 5 hours")
        }
    }
}

private struct UsageLoginSheet: View {
    let title: String
    let url: URL?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button(NSLocalizedString("common.done", value: "Done", comment: "Done")) {
                    dismiss()
                }
            }
            .padding()

            Divider()

            if let url {
                ProviderLoginWebView(url: url)
            } else {
                ContentUnavailableView(
                    NSLocalizedString("usage.monitor.login", value: "Sign in…", comment: "Sign in"),
                    systemImage: "globe",
                    description: Text(NSLocalizedString("usage.monitor.unsupported.desc", value: "Usage is not configured for this provider yet.", comment: "Unsupported"))
                )
            }
        }
        .frame(minWidth: 900, minHeight: 700)
    }
}

private struct ProviderLoginWebView: NSViewRepresentable {
    let url: URL

    func makeNSView(context _: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let view = WKWebView(frame: .zero, configuration: config)
        view.load(URLRequest(url: url))
        return view
    }

    func updateNSView(_ nsView: WKWebView, context _: Context) {
        if nsView.url != url {
            nsView.load(URLRequest(url: url))
        }
    }
}
