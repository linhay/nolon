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
import NolonResourceKit
@preconcurrency import STFilePath

@MainActor
@Observable
final class ProviderUsageViewModel {
    private static let logger = Logger(subsystem: "com.nolon", category: "ProviderUsageViewModel")
    private static var codexInitialFullRefreshProviderIDs: Set<String> = []
    typealias CodexActivateAction = @MainActor @Sendable (CodexAuthAccount, Provider) async throws -> CodexAuthActivationResult
    typealias CodexDeleteAction = @MainActor @Sendable (UUID) async throws -> Void
    typealias CodexRefreshAllAction = @MainActor @Sendable ([CodexAuthAccount]) async -> Void
    typealias AsyncVoidAction = @MainActor @Sendable () async -> Void

    private let usageMonitor: ProviderUsageMonitorService
    private let codexTokenTrendService = CodexTokenTrendService()
    private let settingsStore = UsageMonitorSettingsStore.shared
    private let codexAuthManager = CodexAuthManager()
    private let codexActivateAction: CodexActivateAction
    private let postActivationLoadAction: AsyncVoidAction?
    private let codexDeleteAction: CodexDeleteAction?
    private let postDeleteLoadAction: AsyncVoidAction?
    private let codexRefreshAllAction: CodexRefreshAllAction?
    private let usageSnapshotService = ProviderUsageSnapshotService()
    @ObservationIgnored private var usageWatcher: UsageMonitorFileWatcher? = nil

    let provider: Provider
    let usageProvider: UsageProvider?

    var settings: UsageMonitorProviderSettings
    var supportedSourceModes: [ProviderSourceMode] = []
    var isMultiAccountEnabled: Bool
    var codexManagementStatus: CodexAuthManager.CodexManagementStatus?

    var isLoading = false
    var outcomes: [ProviderAccountUsageOutcome] = []

    var isShowingLogin = false

    var codexAccounts: [CodexAuthAccount] = []
    var codexAccountOutcomes: [ProviderAccountUsageOutcome] = []
    var codexAccountSummaries: [UUID: CodexAuthSummary] = [:]
    var codexAccountCreditsRefreshedAt: [UUID: Date] = [:]
    var codexRefreshingAccountIds: Set<UUID> = []
    var codexRefreshedAccountIdsInSession: Set<UUID> = []
    var currentCodexAuthHashHex: String?
    var codexAuthFilePath: String?
    var activeCodexAccountId: UUID?
    var codexTrendRange: CodexTrendRange = .days30
    var codexTrendSnapshot: CodexTokenTrendSnapshot?
    var codexTrendErrorMessage: String?
    var isLoadingCodexTrend = false

    var addAccountSource: CodexAddSource = .current
    var importedAuthFileURL: URL?
    var importedAuthFileURLs: [URL] = []
    var isShowingAuthFileImporter = false
    var isRunningCLILogin = false
    var cliLoginStatus: String?
    var cliLoginPreferredAccountId: UUID?
    @ObservationIgnored private var cliLoginHandle: CodexLoginHandle?
    @ObservationIgnored private var cliLoginTempDir: URL?

    var isShowingActivateConfirm = false
    var pendingActivateCodexAccount: CodexAuthAccount?
    var isShowingDeleteConfirm = false
    var pendingDeleteCodexAccount: CodexAuthAccount?
    var isShowingImportValidationConfirm = false
    var importValidationSummaryMessage: String?
    var pendingImportValidationResults: [CodexAuthManager.CodexImportValidationResult] = []
    var isShowingLoginURLSheet = false
    var loginURLForSheet: URL?
    var loginModeForSheet: String?

    var alertTitle: String?
    var alertMessage: String?
    var isShowingCopyToast = false
    var copyToastMessage = NSLocalizedString("remote.error.copied", value: "Copied", comment: "Copied tooltip")

    private var cliLoginTask: Task<Void, Never>?
    private var cliLoginSessionId: UUID?
    @ObservationIgnored private var copyToastTask: Task<Void, Never>?
    private var codexAuthChangeSuppressor = CodexAuthChangeSuppressionStore()
    private let codexAuthChangeSuppressionWindow: TimeInterval = 2.5
    private var codexUsageCacheWriteCount = 0
    private var hasTriggeredAppearRefresh = false
    private var didStartInitialLoad = false
    private var lastUsageRefreshAt: Date?
    private let cliLoginTimeoutSeconds: TimeInterval = 10 * 60

    enum CodexAccountDisplayState: String, Sendable {
        case pending
        case healthy
        case failed
        case needsReauth
    }

    var usageAggregate: ProviderUsageAggregate {
        usageSnapshotService.aggregate(items: currentSnapshotItems())
    }

    init(
        provider: Provider,
        usageMonitor: ProviderUsageMonitorService? = nil,
        codexActivateAction: CodexActivateAction? = nil,
        postActivationLoadAction: AsyncVoidAction? = nil,
        codexDeleteAction: CodexDeleteAction? = nil,
        codexRefreshAllAction: CodexRefreshAllAction? = nil,
        postDeleteLoadAction: AsyncVoidAction? = nil
    ) {
        let tokenStore = FileTokenAccountStore(fileURL: ProviderUsagePaths.defaultTokenAccountsFileURL())
        self.usageMonitor = usageMonitor ?? ProviderUsageMonitorService(tokenAccountStore: tokenStore)
        self.provider = provider
        self.usageProvider = ProviderUsageViewModel.mapToUsageProvider(provider)
        let initialSettings = settingsStore.settings(for: provider)
        self.settings = initialSettings
        if ProviderUsageViewModel.mapToUsageProvider(provider) == .codex {
            self.isMultiAccountEnabled = true
        } else {
            self.isMultiAccountEnabled = settingsStore.isMultiAccountEnabled(for: provider)
        }
        self.codexActivateAction = codexActivateAction ?? { account, provider in
            try await CodexAuthActivationCoordinator.shared.activate(account: account, provider: provider)
        }
        self.postActivationLoadAction = postActivationLoadAction
        self.codexDeleteAction = codexDeleteAction
        self.codexRefreshAllAction = codexRefreshAllAction
        self.postDeleteLoadAction = postDeleteLoadAction
        self.updateSupportedModes()
        let watcher = UsageMonitorFileWatcher { [weak self] change in
            Task { await self?.handleUsageFileChange(change) }
        }
        self.usageWatcher = watcher
    }

    deinit {
        copyToastTask?.cancel()
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

    enum CodexTrendRange: String, CaseIterable, Identifiable {
        case days7
        case days30
        case all

        var id: String { rawValue }

        var title: String {
            switch self {
            case .days7:
                return NSLocalizedString("codex.usage.range.7d", value: "7D", comment: "Codex usage trend range 7 days")
            case .days30:
                return NSLocalizedString("codex.usage.range.30d", value: "30D", comment: "Codex usage trend range 30 days")
            case .all:
                return NSLocalizedString("codex.usage.range.all", value: "ALL", comment: "Codex usage trend range all")
            }
        }

        var trailingDays: Int? {
            switch self {
            case .days7: 7
            case .days30: 30
            case .all: nil
            }
        }
    }

    func updateSettings(_ newSettings: UsageMonitorProviderSettings) {
        settings = newSettings
        settingsStore.update(settings: newSettings, for: provider)
    }

    func loadCodexManagementStatus() async {
        guard usageProvider == .codex else { return }
        codexManagementStatus = await codexAuthManager.managementStatus(for: provider)
    }

    func enableCodexManagement() async {
        guard usageProvider == .codex else { return }
        do {
            _ = try await codexAuthManager.enableManagedAuth(for: provider)
            await loadCodexManagementStatus()
            await load()
        } catch {
            alertTitle = NSLocalizedString("codex.accounts.title", value: "Accounts", comment: "Codex accounts title")
            alertMessage = error.localizedDescription
        }
    }

    func migrateCodexManagementData() async {
        guard usageProvider == .codex else { return }
        do {
            _ = try await codexAuthManager.migrateManagedAuthData(for: provider)
            await loadCodexManagementStatus()
            await load()
        } catch {
            alertTitle = NSLocalizedString("codex.accounts.title", value: "Accounts", comment: "Codex accounts title")
            alertMessage = error.localizedDescription
        }
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
        let shouldRefresh = UsageRefreshPolicy.shouldRefresh(
            hasTriggeredAppearRefresh: hasTriggeredAppearRefresh,
            intervalMinutes: intervalMinutes,
            lastRefreshAt: lastUsageRefreshAt,
            now: now
        )
        hasTriggeredAppearRefresh = true

        guard shouldRefresh else { return }

        Self.logger.debug(
            "Usage view appear refresh. provider=\(usageProvider.rawValue, privacy: .public) interval=\(intervalMinutes, privacy: .public)m last=\(String(describing: self.lastUsageRefreshAt), privacy: .public)"
        )
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

        Self.logger.info("Loading usage. provider=\(usageProvider.rawValue, privacy: .public) multiAccount=\(self.isMultiAccountEnabled, privacy: .public)")
        if usageProvider == .codex, isMultiAccountEnabled {
            do {
                _ = try await codexAuthManager.preflightManagedAuthIfNeeded(
                    for: provider,
                    forceBackup: true,
                    reason: "usage_load"
                )
            } catch {
                Self.logger.error("Codex preflight failed on load: \(String(describing: error), privacy: .public)")
            }
            outcomes = []
        } else {
            outcomes = await usageMonitor.fetchOutcomes(
                provider: usageProvider,
                settings: settings,
                costWindowDays: nil
            )
            lastUsageRefreshAt = Date()
        }

        guard usageProvider == .codex else {
            await updateUsageFileWatcher()
            return
        }
        let trendRefreshTask = Task { [weak self] in
            await self?.refreshCodexTokenTrend()
        }
        do {
            codexAuthFilePath = await codexAuthManager.authFile(for: provider)?.url.path
            currentCodexAuthHashHex = await codexAuthManager.currentAuthHashHex(for: provider)

            let loadedAccounts = try await codexAuthManager.loadAccounts()

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
                await trendRefreshTask.value
                return
            }

            codexAccounts = loadedAccounts
            codexAccountSummaries = loadCodexAccountSummaries(accounts: codexAccounts)
            activeCodexAccountId = await codexAuthManager.activeAccountId(for: provider)
            codexAccountOutcomes = await loadCachedCodexAccountOutcomes(accounts: codexAccounts)
            reorderCodexAccountOutcomesForDisplay()
            if Self.codexInitialFullRefreshProviderIDs.contains(provider.id) {
                if let account = activeCodexAccountForRefresh(),
                   !shouldSkipRefresh(accountID: account.id, summaries: codexAccountSummaries) {
                    await refreshCodexAccountOutcome(account)
                }
            } else {
                await refreshCodexAccountsOnInitialLoad(
                    activeId: activeCodexAccountId,
                    summaries: codexAccountSummaries
                )
                Self.codexInitialFullRefreshProviderIDs.insert(provider.id)
            }
        } catch {
            resetCodexMultiAccountState()
            Self.logger.error("Failed to load codex accounts: \(String(describing: error), privacy: .public)")
        }

        await trendRefreshTask.value
        await loadCodexManagementStatus()
        await updateUsageFileWatcher()
    }

    func performAutoRefresh() async {
        guard !isLoading else { return }
        guard let usageProvider else { return }

        if usageProvider == .codex, isMultiAccountEnabled {
            do {
                _ = try await codexAuthManager.preflightManagedAuthIfNeeded(
                    for: provider,
                    forceBackup: false,
                    reason: "usage_auto_refresh"
                )
            } catch {
                Self.logger.error("Codex preflight failed on auto refresh: \(String(describing: error), privacy: .public)")
            }
            if codexAccounts.isEmpty {
                await load()
                return
            }

            if let account = activeCodexAccountForRefresh(),
               !shouldSkipRefresh(accountID: account.id, summaries: codexAccountSummaries) {
                await refreshCodexAccountOutcome(account)
            }
            return
        }

        await load()
    }

    func refreshFromHeader() async {
        guard !isLoading else { return }
        guard let usageProvider else { return }

        if usageProvider == .codex, isMultiAccountEnabled {
            do {
                _ = try await codexAuthManager.preflightManagedAuthIfNeeded(
                    for: provider,
                    forceBackup: true,
                    reason: "header_refresh"
                )
            } catch {
                Self.logger.error("Codex preflight failed from header refresh: \(String(describing: error), privacy: .public)")
            }
            if codexAccounts.isEmpty {
                await load()
                return
            }

            let targets = codexHeaderRefreshTargets()
            guard !targets.isEmpty else { return }

            if let codexRefreshAllAction {
                await codexRefreshAllAction(targets)
            } else {
                await refreshCodexAccountsInParallel(targets)
            }
            return
        }

        await load()
    }

    func codexHeaderRefreshTargets() -> [CodexAuthAccount] {
        orderedAccounts(activeId: activeCodexAccountId)
    }

    func setCodexTrendRange(_ range: CodexTrendRange) {
        guard codexTrendRange != range else { return }
        codexTrendRange = range
    }

    func refreshCodexTokenTrendNow() {
        Task { [weak self] in
            await self?.refreshCodexTokenTrend()
        }
    }

    private func refreshCodexTokenTrend() async {
        guard usageProvider == .codex else { return }
        isLoadingCodexTrend = true
        codexTrendErrorMessage = nil
        defer { isLoadingCodexTrend = false }
        do {
            let snapshot = try await codexTokenTrendService.fetchGlobalSnapshot(
                trailingDays: nil,
                environment: ProcessInfo.processInfo.environment
            )
            codexTrendSnapshot = snapshot
        } catch {
            codexTrendSnapshot = nil
            codexTrendErrorMessage = error.localizedDescription
        }
    }

    private func updateUsageFileWatcher() async {
        guard let usageProvider else {
            usageWatcher?.stop()
            return
        }

        var paths: [String] = []
        paths.append(ProviderUsagePaths.defaultTokenAccountsFileURL().path)

        if usageProvider == .codex {
            if isMultiAccountEnabled {
                paths.append(codexAuthManager.nolonCodexAuthFolder().url.path)
            }
        }

        Self.logger.debug(
            "Updating usage watcher. provider=\(usageProvider.rawValue, privacy: .public) paths=\(paths.count, privacy: .public)"
        )
        usageWatcher?.startWatching(paths: paths)
    }

    func rebuildUsageWatcherForTesting() async {
        await updateUsageFileWatcher()
    }

    func watchedPathsForTesting() -> [String] {
        usageWatcher?.watchedPathsForTesting ?? []
    }

    private func handleUsageFileChange(_ change: STPathChanged) async {
        guard !isLoading else { return }
        guard let usageProvider else { return }

        Self.logger.debug(
            "Usage file change. provider=\(usageProvider.rawValue, privacy: .public) kind=\(String(describing: change.kind), privacy: .public) path=\(change.path.url.path, privacy: .public)"
        )
        if usageProvider == .codex {
            await handleCodexUsageFileChange(change)
        } else {
            await load()
        }
    }

    private func handleCodexUsageFileChange(_ change: STPathChanged) async {
        let changedPath = change.path.url.standardizedFileURL.path
        if shouldIgnoreTemporaryFileChange(path: changedPath) {
            return
        }
        if shouldIgnoreAuthChange(path: changedPath, kind: change.kind) {
            Self.logger.debug("Ignored auth change. kind=\(String(describing: change.kind), privacy: .public) path=\(changedPath, privacy: .public)")
            return
        }

        let authFolderPath = codexAuthManager.nolonCodexAuthFolder().url.standardizedFileURL.path

        let isAuthFolderChange = changedPath == authFolderPath || changedPath.hasPrefix(authFolderPath + "/")
        let isAuthFileChange: Bool = {
            guard let codexAuthFilePath else { return false }
            return changedPath == normalizedPath(codexAuthFilePath)
        }()

        Self.logger.debug(
            "Codex auth change. isAuthFolder=\(isAuthFolderChange, privacy: .public) isAuthFile=\(isAuthFileChange, privacy: .public) path=\(changedPath, privacy: .public)"
        )
        guard isAuthFolderChange || isAuthFileChange else { return }

        if CodexAuthEventPolicy.shouldIgnoreKnownAuthRename(
            changedPath: changedPath,
            kind: change.kind == .renamed ? .renamed : .other,
            isAuthFolderChange: isAuthFolderChange,
            isAuthFileChange: isAuthFileChange,
            knownAuthFileNames: Set(codexAccounts.map { ($0.relativeAuthPath as NSString).lastPathComponent })
        ) {
            Self.logger.debug("Ignored auth rename for known account file. path=\(changedPath, privacy: .public)")
            return
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
            case .created, .deleted:
                refreshUsage = true
            case .renamed, .modified:
                refreshUsage = false
            }
        }

        Self.logger.info(
            "Reloading Codex from disk. refreshUsage=\(refreshUsage, privacy: .public) kind=\(String(describing: change.kind), privacy: .public)"
        )
        await reloadCodexFromDisk(refreshUsage: refreshUsage)
    }

    private func reloadCodexFromDisk(refreshUsage: Bool) async {
        do {
            codexAuthFilePath = await codexAuthManager.authFile(for: provider)?.url.path
            currentCodexAuthHashHex = await codexAuthManager.currentAuthHashHex(for: provider)

            let loadedAccounts = try await codexAuthManager.loadAccounts()
            codexAccounts = loadedAccounts
            codexAccountSummaries = loadCodexAccountSummaries(accounts: codexAccounts)
            activeCodexAccountId = await codexAuthManager.activeAccountId(for: provider)
            codexAccountOutcomes = await loadCachedCodexAccountOutcomes(accounts: codexAccounts)
            reorderCodexAccountOutcomesForDisplay()

            Self.logger.debug(
                "Codex disk reload complete. accounts=\(self.codexAccounts.count, privacy: .public) refreshUsage=\(refreshUsage, privacy: .public)"
            )
            if refreshUsage {
                await refreshCodexAccountsIfNeeded(
                    activeId: activeCodexAccountId,
                    summaries: codexAccountSummaries
                )
            }
        } catch {
            // Ignore file reload errors; watcher will fire again on next change.
            Self.logger.error("Codex disk reload failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func normalizedPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }

    private func shouldIgnoreTemporaryFileChange(path: String) -> Bool {
        let lastComponent = (path as NSString).lastPathComponent
        if lastComponent.hasPrefix(".dat.nosync") {
            return true
        }
        return false
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

            if let cache = try? await codexAuthManager.loadUsageCache(for: account) {
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
                autoRefreshIntervalMinutes: settings.autoRefreshIntervalMinutes,
                costWindowDays: settings.costWindowDays))
        }
    }

    private static func mapToUsageProvider(_ provider: Provider) -> UsageProvider? {
        if provider.templateId == ProviderTemplate.codexXcode.rawValue {
            return .codex
        }
        if let templateId = provider.templateId, let mapped = UsageProvider(rawValue: templateId) {
            return mapped
        }
        return nil
    }

    private func currentSnapshotItems() -> [ProviderUsageSnapshotItem] {
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

    func beginImportAuthFiles() {
        importedAuthFileURL = nil
        importedAuthFileURLs = []
        isShowingAuthFileImporter = true
    }

    func validateImportedAuthFiles(_ urls: [URL]) async {
        guard usageProvider == .codex else { return }
        importedAuthFileURLs = urls
        let results = await codexAuthManager.validateImportAuthFiles(urls: urls)
        pendingImportValidationResults = results

        let validCount = results.filter(\.isValid).count
        let invalid = results.filter { !$0.isValid }

        guard validCount > 0 else {
            alertTitle = NSLocalizedString("codex.accounts.add.title", value: "Add Account", comment: "Add account title")
            if invalid.isEmpty {
                alertMessage = NSLocalizedString("codex.accounts.add.error.no_file", value: "Select an auth.json file first.", comment: "Error")
            } else {
                alertMessage = invalid.map {
                    "\($0.fileURL.lastPathComponent): \($0.reason ?? "Invalid file")"
                }.joined(separator: "\n")
            }
            return
        }

        guard !invalid.isEmpty else {
            await applyValidatedImports()
            return
        }

        importValidationSummaryMessage = invalid.map {
            "\($0.fileURL.lastPathComponent): \($0.reason ?? "Invalid file")"
        }.joined(separator: "\n")
        isShowingImportValidationConfirm = true
    }

    func applyValidatedImports() async {
        guard usageProvider == .codex else { return }
        do {
            _ = try await codexAuthManager.importValidatedAuthFiles(results: pendingImportValidationResults)
            pendingImportValidationResults = []
            importValidationSummaryMessage = nil
            await load()
        } catch {
            alertTitle = NSLocalizedString("codex.accounts.add.title", value: "Add Account", comment: "Add account title")
            alertMessage = error.localizedDescription
        }
    }

    func startLoginFlow() {
        if isRunningCLILogin {
            cancelCLILoginIfNeeded()
        }
        startCLILoginFlow()
    }

    func copyLoginURL() {
        guard let raw = loginURLForSheet?.absoluteString, !raw.isEmpty else { return }
        copyText(raw)
    }

    func copyErrorText(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        copyText(trimmed)
    }

    func copyCodexAccountID(id: UUID) {
        copyText(id.uuidString.lowercased())
    }

    func copyCodexAccountPath(id: UUID) {
        guard let account = codexAccounts.first(where: { $0.id == id }) else { return }
        let file = codexAuthManager.accountAuthFile(relativeAuthPath: account.relativeAuthPath)
        copyText(file.url.path)
    }

    private func copyText(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        showCopyToast()
    }

    private func showCopyToast() {
        copyToastTask?.cancel()
        copyToastMessage = NSLocalizedString("remote.error.copied", value: "Copied", comment: "Copied tooltip")
        isShowingCopyToast = true
        copyToastTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard let self else { return }
            self.isShowingCopyToast = false
        }
    }

    static func isAuthFailure(error: Error) -> Bool {
        CodexAuthFailureClassifier.isAuthFailure(errorText: errorDetailText(error: error))
    }

    static func errorSummaryText(error: Error, maxLength: Int = 140) -> String {
        if isAuthFailure(error: error) {
            return NSLocalizedString(
                "codex.accounts.error.auth_expired",
                value: "Authentication expired. Please sign in again.",
                comment: "Codex auth expired summary"
            )
        }

        let compact = errorDetailText(error: error)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard compact.count > maxLength else { return compact }
        let prefixLength = max(0, maxLength - 3)
        return String(compact.prefix(prefixLength)) + "..."
    }

    static func errorDetailText(error: Error) -> String {
        let trimmed = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        return String(describing: error).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func reopenLoginURLInBrowser() {
        guard let url = loginURLForSheet else { return }
        NSWorkspace.shared.open(url)
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
                guard let raw = try await codexAuthManager.readAuthJSONString(from: provider) else {
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

            let finalName = codexAuthManager.deriveAccountName(fromAuthJSONString: authJSONString)
            _ = try await codexAuthManager.addAccount(name: finalName, authJSONString: authJSONString)
            await load()
        } catch {
            alertTitle = NSLocalizedString("codex.accounts.add.title", value: "Add Account", comment: "Add account title")
            let fallback = NSLocalizedString("codex.accounts.error.add", value: "Failed to add this account.", comment: "Error message")
            let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            alertMessage = message.isEmpty ? fallback : message
        }
    }

    func cancelCLILoginIfNeeded() {
        cliLoginSessionId = nil
        cliLoginTask?.cancel()
        cliLoginTask = nil
        cleanupCLILoginArtifacts()
        isRunningCLILogin = false
        cliLoginStatus = nil
        cliLoginPreferredAccountId = nil
        isShowingLoginURLSheet = false
        loginURLForSheet = nil
        loginModeForSheet = nil
    }

    private func cleanupCLILoginArtifacts() {
        cliLoginHandle?.cancel()
        cliLoginHandle = nil
        if let tempDir = cliLoginTempDir {
            try? FileManager.default.removeItem(at: tempDir)
            cliLoginTempDir = nil
        }
    }

    private func finalizeCLILoginSessionIfNeeded(sessionId: UUID) {
        guard cliLoginSessionId == sessionId else { return }
        cliLoginTask = nil
        cliLoginSessionId = nil
        cleanupCLILoginArtifacts()
        isRunningCLILogin = false
        cliLoginStatus = nil
        cliLoginPreferredAccountId = nil
        isShowingLoginURLSheet = false
        loginURLForSheet = nil
        loginModeForSheet = nil
    }

    private func resetCodexMultiAccountState() {
        codexAccounts = []
        codexAccountOutcomes = []
        codexAccountSummaries = [:]
        codexAccountCreditsRefreshedAt = [:]
        codexRefreshingAccountIds = []
        codexRefreshedAccountIdsInSession = []
        currentCodexAuthHashHex = nil
        codexAuthFilePath = nil
        activeCodexAccountId = nil
        pendingActivateCodexAccount = nil
        pendingDeleteCodexAccount = nil
        isShowingDeleteConfirm = false
    }

    func startCLILoginFlow(preferredAccountId: UUID? = nil) {
        guard usageProvider == .codex else { return }
        guard !isRunningCLILogin else { return }

        let sessionId = UUID()
        cliLoginSessionId = sessionId
        isRunningCLILogin = true
        cliLoginStatus = NSLocalizedString("codex.accounts.add.cli.running", value: "Logging in…", comment: "CLI login running status")
        cliLoginPreferredAccountId = preferredAccountId

        cliLoginTask?.cancel()
        cliLoginTask = Task { [weak self] in
            guard let self else { return }
            await self.runUnifiedLoginFlow(sessionId: sessionId)
        }
    }

    private func runUnifiedLoginFlow(sessionId: UUID) async {
        defer {
            finalizeCLILoginSessionIfNeeded(sessionId: sessionId)
        }
        do {
            try await runAppServerLoginFlow(sessionId: sessionId)
            return
        } catch {
            Self.logger.error("App-server login failed, fallback to direct login. error=\(String(describing: error), privacy: .public)")
        }
        await runCLILoginFlow(sessionId: sessionId)
    }

    private func runAppServerLoginFlow(sessionId: UUID) async throws {
        guard cliLoginSessionId == sessionId else { return }
        let tempDir = try createCLILoginTempDir()
        cliLoginTempDir = tempDir
        var env = ProcessInfo.processInfo.environment
        if let managedEnv = try? await CodexBinaryManager.shared.launchEnvironmentVariables() {
            env.merge(managedEnv) { _, new in new }
        }
        env["CODEX_HOME"] = tempDir.path
        let service = CodexAccountRuntimeService(
            executable: env["CODEX_CLI_PATH"] ?? "codex",
            environment: env
        )
        defer { Task { await service.shutdown() } }

        try await service.initialize(clientName: "nolon", clientVersion: "1.0.0")
        let started = try await service.startChatGPTLogin()
        loginURLForSheet = started.authURL
        loginModeForSheet = "CLI(AppServer)"
        isShowingLoginURLSheet = true
        NSWorkspace.shared.open(started.authURL)
        cliLoginStatus = NSLocalizedString("codex.accounts.add.cli.waiting", value: "Waiting for auth.json…", comment: "CLI login waiting status")
        try await service.awaitChatGPTLoginCompletion(loginID: started.loginID, timeout: cliLoginTimeoutSeconds)

        let authFile = tempDir.appendingPathComponent("auth.json")
        let data = try Data(contentsOf: authFile)
        guard let raw = String(data: data, encoding: .utf8), !raw.isEmpty else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        _ = try await codexAuthManager.recordCLILoginSnapshot(
            authJSONString: raw,
            preferredAccountID: cliLoginPreferredAccountId,
            loginAt: Date()
        )
        await load()
    }

    private func runCLILoginFlow(sessionId: UUID) async {
        defer {
            finalizeCLILoginSessionIfNeeded(sessionId: sessionId)
        }

        do {
            let tempDir = try createCLILoginTempDir()
            cliLoginTempDir = tempDir
            Self.logger.info("CLI login started. tempDir=\(tempDir.path, privacy: .public)")

            var env = ProcessInfo.processInfo.environment
            if let managedEnv = try? await CodexBinaryManager.shared.launchEnvironmentVariables() {
                env.merge(managedEnv) { _, new in new }
            }

            let runner = CodexLoginRunner()
            cliLoginHandle = try runner.startLogin(environment: env, codexHome: tempDir)
            Self.logger.info("CLI login process launched.")
            loginModeForSheet = "Direct OAuth"

            cliLoginStatus = NSLocalizedString("codex.accounts.add.cli.waiting", value: "Waiting for auth.json…", comment: "CLI login waiting status")

            let fileManager = FileManager.default
            let authFile = tempDir.appendingPathComponent("auth.json")
            let deadline = Date().addingTimeInterval(cliLoginTimeoutSeconds)
            let processExitGraceSeconds: TimeInterval = 4
            var processExitedAt: Date?
            while !Task.isCancelled {
                guard cliLoginSessionId == sessionId else { return }
                if fileManager.fileExists(atPath: authFile.path),
                   let data = try? Data(contentsOf: authFile),
                   !data.isEmpty {
                    break
                }

                if let urlRaw = cliLoginHandle?.loginURL, let url = URL(string: urlRaw) {
                    if loginURLForSheet?.absoluteString != url.absoluteString {
                        loginURLForSheet = url
                        isShowingLoginURLSheet = true
                    }
                }

                if let handle = cliLoginHandle, !handle.isRunning {
                    if processExitedAt == nil {
                        processExitedAt = Date()
                        Self.logger.info("CLI login process exited; waiting for auth.json grace period.")
                    } else if Date().timeIntervalSince(processExitedAt!) >= processExitGraceSeconds {
                        Self.logger.info("CLI login exited before auth.json was created.")
                        alertTitle = NSLocalizedString("codex.cli_login.title", value: "CLI Login", comment: "CLI login title")
                        alertMessage = NSLocalizedString(
                            "codex.accounts.add.cli.error.no_auth",
                            value: "Login did not create auth.json.",
                            comment: "CLI login did not create auth.json"
                        )
                        return
                    }
                }

                if Date() >= deadline {
                    Self.logger.info("CLI login timed out waiting for auth.json.")
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

            let data = try Data(contentsOf: authFile)
            guard let raw = String(data: data, encoding: .utf8) else {
                alertTitle = NSLocalizedString("codex.cli_login.title", value: "CLI Login", comment: "CLI login title")
                alertMessage = NSLocalizedString("codex.accounts.add.cli.error.no_auth", value: "Login did not create auth.json.", comment: "CLI login did not create auth.json")
                return
            }

            let account = try await codexAuthManager.recordCLILoginSnapshot(
                authJSONString: raw,
                preferredAccountID: cliLoginPreferredAccountId,
                loginAt: Date()
            )
            Self.logger.info("CLI login completed; account updated without activation. accountId=\(account.id.uuidString, privacy: .public)")

            cliLoginHandle?.cancel()
            cliLoginHandle = nil
            if let tempDir = cliLoginTempDir {
                try? FileManager.default.removeItem(at: tempDir)
                cliLoginTempDir = nil
            }

            await load()
        } catch {
            if error is CancellationError {
                Self.logger.info("CLI login task cancelled.")
                return
            }
            guard cliLoginSessionId == sessionId else { return }
            alertTitle = NSLocalizedString("codex.cli_login.title", value: "CLI Login", comment: "CLI login title")
            alertMessage = error.localizedDescription
        }
    }

    func requestActivateCodexAccount(id: UUID) {
        guard let account = codexAccounts.first(where: { $0.id == id }) else { return }
        pendingActivateCodexAccount = account
        isShowingActivateConfirm = true
    }

    func requestDeleteCodexAccount(id: UUID) {
        guard let account = codexAccounts.first(where: { $0.id == id }) else { return }
        pendingDeleteCodexAccount = account
        isShowingDeleteConfirm = true
    }

    func requestLoginForCodexAccount(id: UUID) {
        if isRunningCLILogin {
            Self.logger.info("CLI login restart requested for account \(id.uuidString, privacy: .public).")
            cancelCLILoginIfNeeded()
        }
        startCLILoginFlow(preferredAccountId: id)
    }

    func confirmActivate() async {
        guard let account = pendingActivateCodexAccount else { return }
        do {
            let activation = try await codexActivateAction(account, provider)
            if let runtimeError = activation.runtimeErrorDescription {
                Self.logger.error("Codex runtime switch after activation failed: \(runtimeError, privacy: .public)")
            }
            pendingActivateCodexAccount = nil
            if let postActivationLoadAction {
                await postActivationLoadAction()
            } else {
                await load()
            }
        } catch {
            alertTitle = NSLocalizedString("codex.accounts.title", value: "Accounts", comment: "Codex accounts title")
            alertMessage = NSLocalizedString("codex.accounts.error.activate", value: "Failed to activate this account.", comment: "Error message")
        }
    }

    func confirmDeleteCodexAccount() async {
        guard let account = pendingDeleteCodexAccount else { return }
        do {
            if let codexDeleteAction {
                try await codexDeleteAction(account.id)
            } else {
                try await codexAuthManager.deleteAccount(id: account.id)
            }

            pendingDeleteCodexAccount = nil
            isShowingDeleteConfirm = false

            if let postDeleteLoadAction {
                await postDeleteLoadAction()
            } else {
                await load()
            }
        } catch {
            let fallback = NSLocalizedString("codex.accounts.error.delete", value: "Failed to delete this account.", comment: "Error message")
            let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            alertTitle = NSLocalizedString("codex.accounts.title", value: "Accounts", comment: "Codex accounts title")
            alertMessage = message.isEmpty ? fallback : message
        }
    }

    func isActiveCodexAccount(_ account: CodexAuthAccount) -> Bool {
        if let activeCodexAccountId {
            return account.id == activeCodexAccountId
        }
        guard let currentCodexAuthHashHex else { return false }
        let file = codexAuthManager.accountAuthFile(relativeAuthPath: account.relativeAuthPath)
        guard let data = try? file.data(),
              let raw = String(data: data, encoding: .utf8)
        else { return false }
        return CodexAuthAccount.hashHex(for: raw) == currentCodexAuthHashHex
    }

    private func loadCodexAccountSummaries(accounts: [CodexAuthAccount]) -> [UUID: CodexAuthSummary] {
        var summaries: [UUID: CodexAuthSummary] = [:]
        summaries.reserveCapacity(accounts.count)
        for account in accounts {
            let file = codexAuthManager.accountAuthFile(relativeAuthPath: account.relativeAuthPath)
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
        let file = codexAuthManager.accountAuthFile(relativeAuthPath: account.relativeAuthPath)
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

        let authURL = codexAuthManager.accountAuthFile(relativeAuthPath: account.relativeAuthPath).url
        let outcome = await Self.fetchCodexOutcomeDetached(
            for: account,
            settings: settings,
            authSourceURL: authURL
        )
        await applyRefreshedCodexOutcome(outcome, for: account)
    }

    private func refreshCodexAccountsOnInitialLoad(activeId: UUID?, summaries: [UUID: CodexAuthSummary]) async {
        let targets = orderedAccounts(activeId: activeId).filter { account in
            if shouldSkipRefresh(accountID: account.id, summaries: summaries) {
                return false
            }
            return true
        }
        await refreshCodexAccountsInParallel(targets)
    }

    private func refreshCodexAccountsInParallel(_ accounts: [CodexAuthAccount]) async {
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
            let authURL = codexAuthManager.accountAuthFile(relativeAuthPath: account.relativeAuthPath).url
            tasks[account.id] = Task.detached(priority: .userInitiated) {
                await Self.fetchCodexOutcomeDetached(
                    for: account,
                    settings: settingsSnapshot,
                    authSourceURL: authURL
                )
            }
        }

        for account in targets {
            guard let task = tasks[account.id] else { continue }
            let outcome = await task.value
            await applyRefreshedCodexOutcome(outcome, for: account)
        }
    }

    private func applyRefreshedCodexOutcome(_ outcome: ProviderAccountUsageOutcome, for account: CodexAuthAccount) async {
        let accountId = account.id
        updateCodexOutcome(outcome, for: account)
        lastUsageRefreshAt = Date()

        if case let .success(result) = outcome.outcome.result {
            let now = Date()
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
                let targetFile = codexAuthManager.accountAuthFile(relativeAuthPath: account.relativeAuthPath)
                markAuthCacheWrite(at: targetFile.url)
                codexUsageCacheWriteCount += 1
                defer { codexUsageCacheWriteCount = max(0, codexUsageCacheWriteCount - 1) }
                try await codexAuthManager.storeUsageCache(cache, for: account)
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
                summary.lastSyncSucceededAt = now
                summary.lastSyncFailedAt = nil
                summary.lastSyncFailureMessage = nil
                codexAccountSummaries[accountId] = summary
            }
        } else if case let .failure(error) = outcome.outcome.result {
            let now = Date()
            codexRefreshedAccountIdsInSession.remove(accountId)
            let message = error.localizedDescription
            try? await codexAuthManager.updateSyncFailure(for: account, message: message, date: now)
            var summary = codexAccountSummaries[accountId] ?? CodexAuthSummary()
            summary.lastSyncFailedAt = now
            summary.lastSyncFailureMessage = message
            codexAccountSummaries[accountId] = summary
        }
    }

    private func orderedAccounts(activeId: UUID?) -> [CodexAuthAccount] {
        guard !codexAccounts.isEmpty else { return [] }
        let resolvedActiveID: UUID? = {
            if let activeId { return activeId }
            if let active = activeCodexAccountForRefresh() { return active.id }
            return nil
        }()
        guard let resolvedActiveID else { return codexAccounts }

        var ordered: [CodexAuthAccount] = []
        ordered.reserveCapacity(codexAccounts.count)
        if let active = codexAccounts.first(where: { $0.id == resolvedActiveID }) {
            ordered.append(active)
        }
        ordered.append(contentsOf: codexAccounts.filter { $0.id != resolvedActiveID })
        return ordered
    }

    private func shouldSkipRefresh(accountID: UUID, summaries: [UUID: CodexAuthSummary]) -> Bool {
        guard let summary = summaries[accountID] else { return false }
        return CodexAuthFailureClassifier.shouldSkipRefresh(summary: summary)
    }

    private func persistCurrentCodexOutcomeIfPossible(
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
            let targetFile = codexAuthManager.accountAuthFile(relativeAuthPath: activeAccount.relativeAuthPath)
            markAuthCacheWrite(at: targetFile.url)
            codexUsageCacheWriteCount += 1
            defer { codexUsageCacheWriteCount = max(0, codexUsageCacheWriteCount - 1) }
            try await codexAuthManager.storeUsageCache(cache, for: activeAccount)
        } catch {
            // Best-effort cache write; ignore.
        }
    }

    private func markAuthCacheWrite(at url: URL) {
        let filePath = url.standardizedFileURL.path
        let folderPath = codexAuthManager.nolonCodexAuthFolder().url.standardizedFileURL.path
        codexAuthChangeSuppressor.mark(
            filePath: filePath,
            folderPath: folderPath,
            ttl: codexAuthChangeSuppressionWindow
        )

        Self.logger.debug("Auth cache write suppression set. file=\(filePath, privacy: .public)")
    }

    private func shouldIgnoreAuthChange(path: String, kind: STPathChangeKind) -> Bool {
        let authFolderPath = codexAuthManager.nolonCodexAuthFolder().url.standardizedFileURL.path
        let isAuthFolderChange = path == authFolderPath || path.hasPrefix(authFolderPath + "/")
        if isAuthFolderChange {
            if codexUsageCacheWriteCount > 0 {
                Self.logger.debug("Ignoring auth change during cache write. kind=\(String(describing: kind), privacy: .public) path=\(path, privacy: .public)")
                return true
            }
            if !codexRefreshingAccountIds.isEmpty {
                Self.logger.debug("Ignoring auth change during refresh. kind=\(String(describing: kind), privacy: .public) path=\(path, privacy: .public)")
                return true
            }
        }

        if codexAuthChangeSuppressor.shouldSuppress(path: path) {
            Self.logger.debug("Ignoring auth change (suppressed). kind=\(String(describing: kind), privacy: .public) path=\(path, privacy: .public)")
            return true
        }

        return false
    }

    private func updateCodexOutcome(_ outcome: ProviderAccountUsageOutcome, for account: CodexAuthAccount) {
        replaceCodexOutcome(outcome, for: account.id)
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

        let ordered = codexAccounts.compactMap { byAccountID[$0.id] }
        let unknowns = codexAccountOutcomes.filter { outcome in
            switch outcome.account {
            case let .tokenAccount(account):
                return !codexAccounts.contains(where: { $0.id == account.id })
            case .default:
                return true
            }
        }

        codexAccountOutcomes = ordered + unknowns
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

    func displayState(
        accountID: UUID?,
        outcome: ProviderAccountUsageOutcome,
        summary: CodexAuthSummary?
    ) -> CodexAccountDisplayState {
        if case let .failure(error) = outcome.outcome.result {
            return CodexAuthFailureClassifier.isAuthFailure(errorText: Self.errorDetailText(error: error))
            ? .needsReauth
            : .failed
        }

        let persistedFailureText = summary?.lastSyncFailureMessage?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let persistedFailureText, !persistedFailureText.isEmpty {
            return CodexAuthFailureClassifier.isAuthFailure(errorText: persistedFailureText)
            ? .needsReauth
            : .failed
        }
        if summary?.lastSyncFailedAt != nil {
            return .failed
        }

        guard let accountID else { return .pending }
        return codexRefreshedAccountIdsInSession.contains(accountID) ? .healthy : .pending
    }

    nonisolated private static func fetchCodexOutcomeDetached(
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

    private func createCLILoginTempDir() throws -> URL {
        let base = FileManager.default.temporaryDirectory
        cleanupExpiredLoginTempDirs(base: base)
        let dir = base.appendingPathComponent("nolon-codex-login-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        return dir
    }

    private func cleanupExpiredLoginTempDirs(base: URL) {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: base, includingPropertiesForKeys: [.creationDateKey], options: []) else {
            return
        }
        let cutoff = Date().addingTimeInterval(-24 * 60 * 60)
        for entry in entries where entry.lastPathComponent.hasPrefix("nolon-codex-login-") {
            let created = (try? entry.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
            if created < cutoff {
                try? fm.removeItem(at: entry)
            }
        }
    }
}
