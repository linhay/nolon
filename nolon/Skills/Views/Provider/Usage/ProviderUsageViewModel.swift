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
@preconcurrency import STFilePath

@MainActor
@Observable
final class ProviderUsageViewModel {
    private static let logger = Logger(subsystem: "com.nolon", category: "ProviderUsageViewModel")

    private let service = UsageMonitorService()
    private let settingsStore = UsageMonitorSettingsStore.shared
    private let codexAuthService = CodexAuthService()
    @ObservationIgnored private var usageWatcher: UsageMonitorFileWatcher? = nil

    let provider: Provider
    let usageProvider: UsageProvider?

    var settings: UsageMonitorProviderSettings
    var supportedSourceModes: [ProviderSourceMode] = []
    var isMultiAccountEnabled: Bool
    var codexCostWindowDays: Int? = 30

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
    var cliLoginPreferredAccountId: UUID?
    @ObservationIgnored private var cliLoginHandle: CodexLoginHandle?
    @ObservationIgnored private var cliLoginTempDir: URL?

    var isShowingActivateConfirm = false
    var pendingActivateCodexAccount: CodexAuthAccount?

    var alertTitle: String?
    var alertMessage: String?

    private var cliLoginTask: Task<Void, Never>?
    private var cliLoginSessionId: UUID?
    private var codexAuthChangeSuppressions: [String: Date] = [:]
    private let codexAuthChangeSuppressionWindow: TimeInterval = 2.5
    private var codexUsageCacheWriteCount = 0
    private var hasTriggeredAppearRefresh = false
    private var didStartInitialLoad = false
    private var lastUsageRefreshAt: Date?
    private let cliLoginTimeoutSeconds: TimeInterval = 10 * 60

    init(provider: Provider) {
        self.provider = provider
        self.usageProvider = ProviderUsageViewModel.mapToUsageProvider(provider)
        let initialSettings = settingsStore.settings(for: provider)
        self.settings = initialSettings
        self.codexCostWindowDays = initialSettings.costWindowDays
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
        codexCostWindowDays = newSettings.costWindowDays
        settingsStore.update(settings: newSettings, for: provider)
    }

    func setCodexCostWindowDays(_ days: Int?) {
        guard codexCostWindowDays != days else { return }
        var newSettings = settings
        newSettings.costWindowDays = days
        updateSettings(newSettings)
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
            outcomes = []
        } else {
            outcomes = await service.fetchOutcomes(
                provider: usageProvider,
                settings: settings,
                costWindowDays: codexCostWindowDays
            )
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
            if !isMultiAccountEnabled,
               let authFile = await codexAuthService.authFile(for: provider) {
                paths.append(authFile.url.path)
            }
        }

        Self.logger.debug(
            "Updating usage watcher. provider=\(usageProvider.rawValue, privacy: .public) paths=\(paths.count, privacy: .public)"
        )
        usageWatcher?.startWatching(paths: paths)
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

        Self.logger.debug(
            "Codex auth change. isAuthFolder=\(isAuthFolderChange, privacy: .public) isAuthFile=\(isAuthFileChange, privacy: .public) path=\(changedPath, privacy: .public)"
        )
        guard isAuthFolderChange || isAuthFileChange else { return }

        if isAuthFolderChange, change.kind == .renamed, !isAuthFileChange {
            let fileName = (changedPath as NSString).lastPathComponent
            if isKnownCodexAuthFile(named: fileName) {
                Self.logger.debug("Ignored auth rename for known account file. path=\(changedPath, privacy: .public)")
                return
            }
        }

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
            codexAuthFilePath = await codexAuthService.authFile(for: provider)?.url.path
            currentCodexAuthHashHex = await codexAuthService.currentAuthHashHex(for: provider)

            let loadedAccounts = try await codexAuthService.loadAccounts()
            codexAccounts = loadedAccounts
            codexAccountSummaries = loadCodexAccountSummaries(accounts: codexAccounts)
            activeCodexAccountId = await codexAuthService.activeAccountId(for: provider)
            codexAccountOutcomes = await loadCachedCodexAccountOutcomes(accounts: codexAccounts)

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

    private func isKnownCodexAuthFile(named fileName: String) -> Bool {
        guard !fileName.isEmpty else { return false }
        let relative = "auth/\(fileName)"
        return codexAccounts.contains { $0.relativeAuthPath == relative }
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
                autoRefreshIntervalMinutes: settings.autoRefreshIntervalMinutes,
                costWindowDays: settings.costWindowDays))
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
        cliLoginSessionId = nil
        cliLoginTask?.cancel()
        cliLoginTask = nil
        cliLoginHandle?.cancel()
        cliLoginHandle = nil
        if let tempDir = cliLoginTempDir {
            try? FileManager.default.removeItem(at: tempDir)
            cliLoginTempDir = nil
        }
        isRunningCLILogin = false
        cliLoginStatus = nil
        cliLoginPreferredAccountId = nil
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
            await self.runCLILoginFlow(sessionId: sessionId)
        }
    }

    private func runCLILoginFlow(sessionId: UUID) async {
        defer {
            if cliLoginSessionId == sessionId {
                cliLoginTask = nil
                isRunningCLILogin = false
                cliLoginStatus = nil
                cliLoginSessionId = nil
                cliLoginPreferredAccountId = nil
                cliLoginHandle?.cancel()
                cliLoginHandle = nil
                if let tempDir = cliLoginTempDir {
                    try? FileManager.default.removeItem(at: tempDir)
                    cliLoginTempDir = nil
                }
            }
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

            let email = codexAuthService.deriveEmail(fromAuthJSONString: raw)
            var matched: CodexAuthAccount?
            if let email {
                matched = try await codexAuthService.findAccountByEmail(email)
            } else if let preferredId = cliLoginPreferredAccountId,
                      let preferred = codexAccounts.first(where: { $0.id == preferredId }) {
                matched = preferred
            } else {
                matched = try await codexAuthService.matchAccountByAuthData(data)
            }

            let account: CodexAuthAccount
            if let matched {
                try await codexAuthService.updateAccount(matched, authJSONString: raw)
                account = matched
            } else {
                let finalName = codexAuthService.deriveAccountName(fromAuthJSONString: raw)
                account = try await codexAuthService.addAccount(name: finalName, authJSONString: raw)
            }

            let loginAt = Date()
            try? await codexAuthService.updateLoginSuccess(for: account, date: loginAt)
            try? await codexAuthService.updateSyncSuccess(for: account, date: loginAt)
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
            try? await codexAuthService.updateSyncSuccess(for: account, date: now)
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
                summary.lastSyncSucceededAt = now
                summary.lastSyncFailedAt = nil
                summary.lastSyncFailureMessage = nil
                codexAccountSummaries[accountId] = summary
            }
        } else if case let .failure(error) = outcome.outcome.result {
            let now = Date()
            let message = error.localizedDescription
            try? await codexAuthService.updateSyncFailure(for: account, message: message, date: now)
            var summary = codexAccountSummaries[accountId] ?? CodexAuthSummary()
            summary.lastSyncFailedAt = now
            summary.lastSyncFailureMessage = message
            codexAccountSummaries[accountId] = summary
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

        Self.logger.debug("Auth cache write suppression set. file=\(filePath, privacy: .public) until=\(String(describing: expiry), privacy: .public)")
    }

    private func shouldIgnoreAuthChange(path: String, kind: STPathChangeKind) -> Bool {
        let now = Date()
        codexAuthChangeSuppressions = codexAuthChangeSuppressions.filter { $0.value > now }
        let authFolderPath = codexAuthService.nolonCodexAuthFolder().url.standardizedFileURL.path
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

        guard !codexAuthChangeSuppressions.isEmpty else { return false }

        if let expiry = codexAuthChangeSuppressions[path], expiry > now {
            Self.logger.debug("Ignoring auth change (suppressed). kind=\(String(describing: kind), privacy: .public) path=\(path, privacy: .public)")
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
            if let managedEnv = try? await CodexBinaryManager.shared.launchEnvironmentVariables() {
                environment.merge(managedEnv) { _, new in new }
            }
            environment["CODEX_HOME"] = tempRoot.path

            let context = ProviderFetchContext(
                provider: .codex,
                sourceMode: settings.sourceMode,
                includeCredits: settings.includeCredits,
                timeout: TimeInterval(settings.webTimeoutSeconds),
                costWindowDays: codexCostWindowDays,
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
