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
@preconcurrency import STFilePath
import STJSON
import UniformTypeIdentifiers

@MainActor
@Observable
final class ProviderUsageViewModel {
    private static let logger = Logger(subsystem: "com.nolon", category: "ProviderUsageViewModel")
    private static var codexInitialFullRefreshProviderIDs: Set<String> = []
    private static let codexOfficialAPIBaseURL = "https://api.openai.com/v1"
    typealias CodexActivateAction = @MainActor @Sendable (CodexAuthAccount, Provider) async throws -> CodexAuthActivationResult
    typealias CodexDeleteAction = @MainActor @Sendable (UUID) async throws -> Void
    typealias CodexRefreshAllAction = @MainActor @Sendable ([CodexAuthAccount]) async -> Void
    typealias CodexPreflightAction = @MainActor @Sendable (Provider, Bool, String) async throws -> CodexAuthAccount?
    typealias CodexOutcomeFetchAction = @Sendable (CodexAuthAccount, UsageMonitorProviderSettings, URL) async -> ProviderAccountUsageOutcome
    typealias CodexUsageQueryTestAction = @MainActor @Sendable (CodexHTTPUsageQueryResolvedConfiguration, Bool) async throws -> ProviderFetchResult
    typealias CodexImportConnectionTestAction = @Sendable (CodexAuthManager.CodexImportValidationResult, UsageMonitorProviderSettings) async -> ProviderAccountUsageOutcome
    typealias GeminiTokenTrendFetchAction = @Sendable (UsageProvider, Int?) async throws -> ProviderTokenTrendSnapshot?
    typealias AsyncVoidAction = @MainActor @Sendable () async -> Void

    private let usageMonitor: ProviderUsageMonitorService
    private let codexTokenTrendService = CodexTokenTrendService()
    private let geminiTokenTrendFetchAction: GeminiTokenTrendFetchAction
    private let settingsStore = UsageMonitorSettingsStore.shared
    private let codexAuthManager = CodexAuthManager()
    private let geminiAuthStore = GeminiAuthStore.shared
    private let codexActivateAction: CodexActivateAction
    private let postActivationLoadAction: AsyncVoidAction?
    private let codexDeleteAction: CodexDeleteAction?
    private let postDeleteLoadAction: AsyncVoidAction?
    private let codexRefreshAllAction: CodexRefreshAllAction?
    private let codexPreflightAction: CodexPreflightAction?
    private let codexOutcomeFetchAction: CodexOutcomeFetchAction
    private let codexUsageQueryTestAction: CodexUsageQueryTestAction
    private let codexImportConnectionTestAction: CodexImportConnectionTestAction
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
    var tokenTrendRange: TokenTrendRange = .days30
    var tokenTrendSnapshot: ProviderTokenTrendSnapshot?
    var tokenTrendErrorMessage: String?
    var isLoadingTokenTrend = false
    var codexAccountGroupingOption: CodexAccountGroupingOption = .typeInfo
    var codexAccountSortOption: CodexAccountSortOption = .remainingCredits
    var codexCurrentSortDirection: CodexSortDirection = .descending
    var collapsedCodexSectionIDs: Set<String> = []
    var isCodexMultiSelectionEnabled = false
    var selectedCodexAccountIDs: Set<UUID> = []

    var addAccountSource: CodexAddSource = .current
    var importedAuthFileURL: URL?
    var importedAuthFileURLs: [URL] = []
    var isShowingAuthFileImporter = false
    var isShowingCodexImportSheet = false
    var isRunningCodexImportValidation = false
    var isRunningCodexImportConnectionTests = false
    var isTargetingCodexImportDropZone = false
    var codexImportGlobalErrorMessage: String?
    var codexImportCandidates: [CodexImportCandidate] = []
    var isRunningCLILogin = false
    var cliLoginStatus: String?
    var cliLoginPreferredAccountId: UUID?
    @ObservationIgnored private var cliLoginHandle: CodexLoginHandle?
    @ObservationIgnored private var geminiLoginHandle: GeminiLoginHandle?
    @ObservationIgnored private var cliLoginHomeDir: URL?

    var isShowingActivateConfirm = false
    var pendingActivateCodexAccount: CodexAuthAccount?
    var isShowingDeleteConfirm = false
    var pendingDeleteCodexAccount: CodexAuthAccount?
    var isShowingImportValidationConfirm = false
    var importValidationSummaryMessage: String?
    var pendingImportValidationResults: [CodexAuthManager.CodexImportValidationResult] = []
    var isShowingGeminiImportConfirm = false
    var detectedGeminiImportCandidate: GeminiCLIGlobalSessionImportCandidate?
    var pendingGeminiImportCandidate: GeminiCLIGlobalSessionImportCandidate?
    var isShowingLoginURLSheet = false
    var loginURLForSheet: URL?
    var loginModeForSheet: String?
    var isShowingCodexConfigEditor = false
    var codexConfigEditorDraft: CodexConfigEditorDraft?
    var codexConfigEditorErrorMessage: String?
    var isTestingCodexUsageQuery = false
    var codexUsageQueryTestSuccessMessage: String?
    var codexUsageQueryTestErrorMessage: String?

    var alertTitle: String?
    var alertMessage: String?
    var isShowingCopyToast = false
    var copyToastMessage = NSLocalizedString("remote.error.copied", value: "Copied", comment: "Copied tooltip")

    private var cliLoginTask: Task<Void, Never>?
    private var cliLoginSessionId: UUID?
    @ObservationIgnored private var copyToastTask: Task<Void, Never>?
    @ObservationIgnored private var codexAuthReloadSignalCancellable: AnyCancellable?
    @ObservationIgnored private var codexReloadTask: Task<Void, Never>?
    @ObservationIgnored private let codexAuthReloadSignal = PassthroughSubject<Void, Never>()
    private var codexReloadPending = false
    private var codexReloadPendingRefreshUsage = false
    private var codexUsageCacheWriteCount = 0
    private(set) var codexDiskReloadCountForTesting = 0
    private var hasTriggeredAppearRefresh = false
    private var didStartInitialLoad = false
    private var lastUsageRefreshAt: Date?
    private let cliLoginTimeoutSeconds: TimeInterval = 10 * 60
    private let codexRefreshTimeoutGraceSeconds: TimeInterval = 5
    @ObservationIgnored private var codexHeaderRefreshTask: Task<Void, Never>?
    private var codexHeaderRefreshSessionID: UUID?
    var isCodexHeaderRefreshing = false

    enum CodexAccountDisplayState: String, Sendable {
        case pending
        case healthy
        case failed
        case needsReauth
    }

    enum CodexAccountGroupingOption: String, CaseIterable, Identifiable {
        case none
        case typeInfo

        var id: String { rawValue }
    }

    enum CodexAccountSortOption: Hashable, Identifiable {
        case remainingCredits
        case expiryTime
        case name
        case quotaWindowRemaining(windowMinutes: Int)

        var id: String {
            switch self {
            case .remainingCredits:
                return "remainingCredits"
            case .expiryTime:
                return "expiryTime"
            case .name:
                return "name"
            case let .quotaWindowRemaining(windowMinutes):
                return "quotaWindowRemaining-\(windowMinutes)"
            }
        }
    }

    enum CodexSortDirection: String, CaseIterable, Identifiable {
        case descending
        case ascending

        var id: String { rawValue }
    }

    enum CodexPrimaryHeaderAction: String, CaseIterable, Identifiable {
        case refreshAll
        case login
        case importAuth
        case editConfig
        case validateConfig

        var id: String { rawValue }
    }

    struct CodexAccountDisplaySection: Identifiable {
        let id: String
        let title: String?
        let items: [ProviderAccountUsageOutcome]
    }

    enum CodexConfigEditorMode: Equatable {
        case newAPIKey
        case newRelay
        case edit(accountID: UUID)
    }

    struct CodexConfigEditorDraft: Equatable {
        var mode: CodexConfigEditorMode
        var name: String
        var apiKey: String
        var baseURL: String
        var modelProvider: String
        var queryParamsText: String
        var headersText: String
        var httpUsageEnabled: Bool
        var httpUsageMethod: CodexHTTPMethod
        var httpUsageURL: String
        var httpUsageHeadersText: String
        var httpUsageBody: String
        var httpUsageTimeoutSeconds: String
        var httpUsageOverrideBaseURL: String
        var httpUsageOverrideAPIKey: String
        var httpUsageOverrideAccessToken: String
        var httpUsageOverrideUserID: String
        var httpUsagePlanPath: String
        var httpUsageCreditsRemainingPath: String
        var httpUsageUsedPath: String
        var httpUsageTotalPath: String
        var httpUsageCostTodayPath: String
        var httpUsageCostLast30DaysPath: String
        var httpUsageErrorMessagePath: String

        var isRelay: Bool {
            switch mode {
            case .newRelay, .edit:
                return !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || !modelProvider.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case .newAPIKey:
                return false
            }
        }
    }

    struct CodexImportCandidate: Identifiable, Equatable {
        let id: UUID
        let sourceFileURL: URL
        let validation: CodexAuthManager.CodexImportValidationResult
        var isSelected: Bool
        var testStatus: CodexImportConnectionTestStatus
        var testSummary: String?
        var testDetail: String?

        init(
            id: UUID = UUID(),
            sourceFileURL: URL,
            validation: CodexAuthManager.CodexImportValidationResult,
            isSelected: Bool,
            testStatus: CodexImportConnectionTestStatus,
            testSummary: String?,
            testDetail: String?
        ) {
            self.id = id
            self.sourceFileURL = sourceFileURL
            self.validation = validation
            self.isSelected = isSelected
            self.testStatus = testStatus
            self.testSummary = testSummary
            self.testDetail = testDetail
        }
    }

    enum CodexImportConnectionTestStatus: Equatable {
        case idle
        case testing
        case success
        case failure
    }

    struct CodexImportCandidateSection: Identifiable, Equatable {
        let id: String
        let title: String
        let items: [CodexImportCandidate]

        var selectableItemCount: Int {
            items.filter(\.validation.isValid).count
        }

        var selectedItemCount: Int {
            items.filter { $0.validation.isValid && $0.isSelected }.count
        }
    }

    var usageAggregate: ProviderUsageAggregate {
        usageSnapshotService.aggregate(items: currentSnapshotItems())
    }

    var codexAccountDisplaySections: [CodexAccountDisplaySection] {
        Self.makeCodexAccountDisplaySections(
            accounts: uniqueCodexAccountsInDisplayOrder(),
            outcomes: codexAccountOutcomes,
            summaries: codexAccountSummaries,
            grouping: codexAccountGroupingOption,
            sorting: codexAccountSortOption,
            sortDirection: codexCurrentSortDirection
        )
    }

    var codexSortMenuOptions: [CodexAccountSortOption] {
        Self.codexSortMenuOptions(from: codexAccountOutcomes)
    }

    var activeCodexCardKind: CodexAuthSummary.CardKind? {
        codexCardKind(accountID: activeCodexAccountId)
    }

    var codexPrimaryHeaderActions: [CodexPrimaryHeaderAction] {
        Self.codexPrimaryHeaderActions(for: activeCodexCardKind)
    }

    var codexSelectedAccountCount: Int {
        selectedCodexAccountIDs.count
    }

    var canExportSelectedCodexAccounts: Bool {
        isCodexMultiSelectionEnabled && !selectedCodexAccountIDs.isEmpty
    }

    var codexSelectedImportCandidateCount: Int {
        codexImportCandidates.filter { $0.validation.isValid && $0.isSelected }.count
    }

    var canImportSelectedCodexCandidates: Bool {
        codexSelectedImportCandidateCount > 0
    }

    var codexImportCandidateSections: [CodexImportCandidateSection] {
        let grouped = Dictionary(grouping: codexImportCandidates, by: { $0.validation.sourceGroupID })
        return grouped.keys.sorted { lhs, rhs in
            let leftTitle = grouped[lhs]?.first?.validation.sourceGroupLabel ?? lhs
            let rightTitle = grouped[rhs]?.first?.validation.sourceGroupLabel ?? rhs
            return leftTitle.localizedCaseInsensitiveCompare(rightTitle) == .orderedAscending
        }.map { key in
            let items = (grouped[key] ?? []).sorted {
                $0.sourceFileURL.lastPathComponent.localizedCaseInsensitiveCompare($1.sourceFileURL.lastPathComponent) == .orderedAscending
            }
            return CodexImportCandidateSection(
                id: key,
                title: items.first?.validation.sourceGroupLabel ?? key,
                items: items
            )
        }
    }

    init(
        provider: Provider,
        usageMonitor: ProviderUsageMonitorService? = nil,
        codexActivateAction: CodexActivateAction? = nil,
        postActivationLoadAction: AsyncVoidAction? = nil,
        codexDeleteAction: CodexDeleteAction? = nil,
        codexRefreshAllAction: CodexRefreshAllAction? = nil,
        codexPreflightAction: CodexPreflightAction? = nil,
        codexOutcomeFetchAction: CodexOutcomeFetchAction? = nil,
        codexUsageQueryTestAction: CodexUsageQueryTestAction? = nil,
        codexImportConnectionTestAction: CodexImportConnectionTestAction? = nil,
        geminiTokenTrendFetchAction: GeminiTokenTrendFetchAction? = nil,
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
        self.codexPreflightAction = codexPreflightAction
        self.codexOutcomeFetchAction = codexOutcomeFetchAction ?? { account, settings, authSourceURL in
            await Self.fetchCodexOutcomeDetached(for: account, settings: settings, authSourceURL: authSourceURL)
        }
        self.codexUsageQueryTestAction = codexUsageQueryTestAction ?? { resolved, includeCredits in
            try await CodexHTTPUsageQueryExecutor().execute(resolved, includeCredits: includeCredits)
        }
        self.codexImportConnectionTestAction = codexImportConnectionTestAction ?? { validationResult, settings in
            await Self.testCodexImportConnectionDetached(validationResult: validationResult, settings: settings)
        }
        self.geminiTokenTrendFetchAction = geminiTokenTrendFetchAction ?? { provider, trailingDays in
            try await GeminiTokenTrendService().fetchActiveSnapshot(provider: provider, trailingDays: trailingDays)
        }
        self.postDeleteLoadAction = postDeleteLoadAction
        self.updateSupportedModes()
        self.configureCodexAuthReloadPipeline()
        let watcher = UsageMonitorFileWatcher { [weak self] change in
            Task { await self?.handleUsageFileChange(change) }
        }
        self.usageWatcher = watcher
    }

    deinit {
        copyToastTask?.cancel()
        codexAuthReloadSignalCancellable?.cancel()
        codexReloadTask?.cancel()
        codexHeaderRefreshTask?.cancel()
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

    enum TokenTrendRange: String, CaseIterable, Identifiable {
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
        // Tab switching should not implicitly refresh usage cards.
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
            outcomes = await usageMonitor.fetchOutcomes(
                provider: usageProvider,
                settings: settings,
                costWindowDays: nil
            )
            await refreshGeminiImportCandidateAvailabilityIfNeeded(for: usageProvider)
            lastUsageRefreshAt = Date()
        }

        guard usageProvider == .codex || usageProvider == .gemini else {
            await updateUsageFileWatcher()
            return
        }
        let trendRefreshTask = Task { [weak self] in
            await self?.refreshTokenTrend()
        }

        guard usageProvider == .codex else {
            await trendRefreshTask.value
            await updateUsageFileWatcher()
            return
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

            await applyCodexAccountsForDisplay(loadedAccounts)

            do {
                _ = try await runCodexPreflight(forceBackup: true, reason: "usage_load")
                let refreshedAccounts = try await codexAuthManager.loadAccounts()
                await applyCodexAccountsForDisplay(refreshedAccounts)
            } catch {
                Self.logger.error("Codex preflight failed on load: \(String(describing: error), privacy: .public)")
            }

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
                _ = try await runCodexPreflight(forceBackup: false, reason: "usage_auto_refresh")
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
                _ = try await runCodexPreflight(forceBackup: true, reason: "header_refresh")
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

    func handleHeaderRefreshButtonTap() {
        guard usageProvider == .codex, isMultiAccountEnabled else {
            Task { [weak self] in
                await self?.refreshFromHeader()
            }
            return
        }

        if isCodexHeaderRefreshing {
            let task = codexHeaderRefreshTask
            codexHeaderRefreshTask = nil
            codexHeaderRefreshSessionID = nil
            isCodexHeaderRefreshing = false
            task?.cancel()
            return
        }

        isCodexHeaderRefreshing = true
        let sessionID = UUID()
        codexHeaderRefreshSessionID = sessionID
        codexHeaderRefreshTask = Task { [weak self] in
            guard let self else { return }
            await self.refreshFromHeader()
            await MainActor.run {
                guard self.codexHeaderRefreshSessionID == sessionID else { return }
                self.isCodexHeaderRefreshing = false
                self.codexHeaderRefreshTask = nil
                self.codexHeaderRefreshSessionID = nil
            }
        }
    }

    func codexHeaderRefreshTargets() -> [CodexAuthAccount] {
        orderedAccounts(activeId: activeCodexAccountId)
    }

    func setTokenTrendRange(_ range: TokenTrendRange) {
        guard tokenTrendRange != range else { return }
        tokenTrendRange = range
        refreshTokenTrendNow()
    }

    func refreshTokenTrendNow() {
        Task { [weak self] in
            await self?.refreshTokenTrend()
        }
    }

    func refreshTokenTrendForTesting() async {
        await refreshTokenTrend()
    }

    private func refreshTokenTrend() async {
        guard let usageProvider else { return }
        guard usageProvider == .codex || usageProvider == .gemini else { return }

        isLoadingTokenTrend = true
        tokenTrendErrorMessage = nil
        defer { isLoadingTokenTrend = false }
        do {
            let snapshot: ProviderTokenTrendSnapshot?
            switch usageProvider {
            case .codex:
                snapshot = try await codexTokenTrendService.fetchGlobalSnapshot(
                    trailingDays: tokenTrendRange.trailingDays,
                    environment: ProcessInfo.processInfo.environment
                )
            case .gemini:
                snapshot = try await geminiTokenTrendFetchAction(
                    usageProvider,
                    tokenTrendRange.trailingDays
                )
            default:
                snapshot = nil
            }
            tokenTrendSnapshot = snapshot
        } catch {
            tokenTrendSnapshot = nil
            tokenTrendErrorMessage = error.localizedDescription
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

    func emitCodexAuthReloadSignalForTesting() {
        codexAuthReloadSignal.send()
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

        guard isMultiAccountEnabled else {
            await load()
            return
        }

        Self.logger.info(
            "Queueing Codex auth reload signal. kind=\(String(describing: change.kind), privacy: .public) path=\(changedPath, privacy: .public)"
        )
        codexAuthReloadSignal.send()
    }

    private func reloadCodexFromDisk(refreshUsage: Bool) async {
        codexDiskReloadCountForTesting += 1
        do {
            codexAuthFilePath = await codexAuthManager.authFile(for: provider)?.url.path
            currentCodexAuthHashHex = await codexAuthManager.currentAuthHashHex(for: provider)

            let loadedAccounts = try await codexAuthManager.loadAccounts()
            codexAccounts = loadedAccounts
            reconcileCodexSelections()
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

    private func enqueueCodexReload(refreshUsage: Bool, reason: String) {
        codexReloadPending = true
        codexReloadPendingRefreshUsage = codexReloadPendingRefreshUsage || refreshUsage

        guard codexReloadTask == nil else {
            Self.logger.debug(
                "Coalesced Codex disk reload. pendingRefreshUsage=\(self.codexReloadPendingRefreshUsage, privacy: .public) reason=\(reason, privacy: .public)"
            )
            return
        }

        codexReloadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.codexReloadTask = nil }

            while self.codexReloadPending {
                let shouldRefreshUsage = self.codexReloadPendingRefreshUsage
                self.codexReloadPending = false
                self.codexReloadPendingRefreshUsage = false
                await self.reloadCodexFromDisk(refreshUsage: shouldRefreshUsage)
            }
        }
    }

    private func configureCodexAuthReloadPipeline() {
        guard usageProvider == .codex else { return }
        codexAuthReloadSignalCancellable = codexAuthReloadSignal
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.enqueueCodexReload(refreshUsage: false, reason: "combine_debounced_auth_change")
                }
            }
    }

    private func normalizedPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }

    private func runCodexPreflight(forceBackup: Bool, reason: String) async throws -> CodexAuthAccount? {
        if let codexPreflightAction {
            return try await codexPreflightAction(provider, forceBackup, reason)
        }
        return try await codexAuthManager.preflightManagedAuthIfNeeded(
            for: provider,
            forceBackup: forceBackup,
            reason: reason
        )
    }

    private func applyCodexAccountsForDisplay(_ accounts: [CodexAuthAccount]) async {
        codexAccounts = accounts
        reconcileCodexSelections()
        codexAccountSummaries = loadCodexAccountSummaries(accounts: codexAccounts)
        activeCodexAccountId = await codexAuthManager.activeAccountId(for: provider)
        codexAccountOutcomes = await loadCachedCodexAccountOutcomes(accounts: codexAccounts)
        reorderCodexAccountOutcomesForDisplay()
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
        codexImportGlobalErrorMessage = nil
        codexImportCandidates = []
        isTargetingCodexImportDropZone = false
        isRunningCodexImportValidation = false
        isRunningCodexImportConnectionTests = false
        isShowingCodexImportSheet = true
    }

    func dismissCodexImportSheet() {
        isShowingCodexImportSheet = false
        isTargetingCodexImportDropZone = false
        isRunningCodexImportValidation = false
        isRunningCodexImportConnectionTests = false
        codexImportGlobalErrorMessage = nil
        codexImportCandidates = []
        importedAuthFileURL = nil
        importedAuthFileURLs = []
        pendingImportValidationResults = []
        importValidationSummaryMessage = nil
        isShowingImportValidationConfirm = false
    }

    func presentCodexImportFilePicker() {
        importedAuthFileURL = nil
        importedAuthFileURLs = []
        isShowingAuthFileImporter = true
    }

    func pasteCodexImportFromClipboard() async {
        guard let raw = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty
        else {
            codexImportGlobalErrorMessage = NSLocalizedString(
                "codex.import.sheet.error.empty_pasteboard",
                value: "剪贴板里没有可解析的账号数据。",
                comment: "Empty clipboard import error"
            )
            return
        }
        await handleCodexImportText(raw)
    }

    func handleCodexImportText(_ raw: String, preferredSourceURL: URL? = nil) async {
        guard usageProvider == .codex else { return }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            let normalized = try normalizeCodexImportText(trimmed)
            let sourceURL = preferredSourceURL ?? makePastedCodexImportURL(for: normalized.fileExtension)
            try Data(normalized.authJSONString.utf8).write(to: sourceURL, options: .atomic)
            await handleCodexImportURLs([sourceURL])
        } catch {
            codexImportGlobalErrorMessage = error.localizedDescription
        }
    }

    func setCodexImportCandidateSelected(_ selected: Bool, id: UUID) {
        guard let index = codexImportCandidates.firstIndex(where: { $0.id == id }) else { return }
        guard codexImportCandidates[index].validation.isValid else { return }
        codexImportCandidates[index].isSelected = selected
    }

    func setAllCodexImportCandidatesSelected(_ selected: Bool) {
        codexImportCandidates = codexImportCandidates.map { candidate in
            guard candidate.validation.isValid else { return candidate }
            var updated = candidate
            updated.isSelected = selected
            return updated
        }
    }

    func setCodexImportCandidatesSelected(_ selected: Bool, sourceGroupID: String) {
        codexImportCandidates = codexImportCandidates.map { candidate in
            guard candidate.validation.sourceGroupID == sourceGroupID, candidate.validation.isValid else { return candidate }
            var updated = candidate
            updated.isSelected = selected
            return updated
        }
    }

    func removeCodexImportCandidate(id: UUID) {
        codexImportCandidates.removeAll { $0.id == id }
    }

    func handleCodexImportURLs(_ urls: [URL]) async {
        guard usageProvider == .codex else { return }
        guard !urls.isEmpty else { return }

        importedAuthFileURLs = urls
        codexImportGlobalErrorMessage = nil
        isRunningCodexImportValidation = true
        let results = await codexAuthManager.validateImportAuthFiles(urls: urls)
        isRunningCodexImportValidation = false

        mergeCodexImportCandidates(results: results)
        await runCodexImportConnectionTests(for: codexImportCandidates.compactMap { candidate in
            guard candidate.validation.isValid, candidate.testStatus != .success else { return nil }
            return candidate.id
        })
    }

    func setCodexMultiSelectionEnabled(_ enabled: Bool) {
        isCodexMultiSelectionEnabled = enabled
        if !enabled {
            selectedCodexAccountIDs.removeAll()
        }
    }

    func toggleCodexMultiSelectionMode() {
        setCodexMultiSelectionEnabled(!isCodexMultiSelectionEnabled)
    }

    func toggleCodexAccountSelection(id: UUID) {
        guard isCodexMultiSelectionEnabled else { return }
        if selectedCodexAccountIDs.contains(id) {
            selectedCodexAccountIDs.remove(id)
        } else {
            selectedCodexAccountIDs.insert(id)
        }
    }

    func isCodexAccountSelected(id: UUID?) -> Bool {
        guard let id else { return false }
        return selectedCodexAccountIDs.contains(id)
    }

    func beginNewCodexAPIKeyAccount() {
        codexConfigEditorDraft = CodexConfigEditorDraft(
            mode: .newAPIKey,
            name: "",
            apiKey: "",
            baseURL: Self.codexOfficialAPIBaseURL,
            modelProvider: "",
            queryParamsText: "",
            headersText: "",
            httpUsageEnabled: false,
            httpUsageMethod: .get,
            httpUsageURL: "",
            httpUsageHeadersText: "",
            httpUsageBody: "",
            httpUsageTimeoutSeconds: "15",
            httpUsageOverrideBaseURL: "",
            httpUsageOverrideAPIKey: "",
            httpUsageOverrideAccessToken: "",
            httpUsageOverrideUserID: "",
            httpUsagePlanPath: "",
            httpUsageCreditsRemainingPath: "",
            httpUsageUsedPath: "",
            httpUsageTotalPath: "",
            httpUsageCostTodayPath: "",
            httpUsageCostLast30DaysPath: "",
            httpUsageErrorMessagePath: ""
        )
        codexConfigEditorErrorMessage = nil
        codexUsageQueryTestSuccessMessage = nil
        codexUsageQueryTestErrorMessage = nil
        isShowingCodexConfigEditor = true
    }

    func beginNewCodexRelayAccount() {
        codexConfigEditorDraft = CodexConfigEditorDraft(
            mode: .newRelay,
            name: "",
            apiKey: "",
            baseURL: "",
            modelProvider: "",
            queryParamsText: "",
            headersText: "",
            httpUsageEnabled: false,
            httpUsageMethod: .get,
            httpUsageURL: "",
            httpUsageHeadersText: "",
            httpUsageBody: "",
            httpUsageTimeoutSeconds: "15",
            httpUsageOverrideBaseURL: "",
            httpUsageOverrideAPIKey: "",
            httpUsageOverrideAccessToken: "",
            httpUsageOverrideUserID: "",
            httpUsagePlanPath: "",
            httpUsageCreditsRemainingPath: "",
            httpUsageUsedPath: "",
            httpUsageTotalPath: "",
            httpUsageCostTodayPath: "",
            httpUsageCostLast30DaysPath: "",
            httpUsageErrorMessagePath: ""
        )
        codexConfigEditorErrorMessage = nil
        codexUsageQueryTestSuccessMessage = nil
        codexUsageQueryTestErrorMessage = nil
        isShowingCodexConfigEditor = true
    }

    func beginEditCodexConfiguredAccount(id: UUID) {
        guard let account = codexAccounts.first(where: { $0.id == id }),
              let summary = codexAccountSummaries[id]
        else { return }

        let file = codexAuthManager.accountAuthFile(relativeAuthPath: account.relativeAuthPath)
        let rawJSON: JSON? = {
            guard let data = try? file.data() else { return nil }
            return try? JSON(data: data)
        }()
        let relayObject: [String: String] = Self.stringDictionary(from: rawJSON?["nolon"]["relay"]["query_params"])
        let headerObject: [String: String] = Self.stringDictionary(from: rawJSON?["nolon"]["relay"]["headers"])
        let usageQuery: CodexHTTPUsageQuery? = {
            guard let usageObject = rawJSON?["nolon"]["usage_query"].dictionaryObject,
                  let data = try? JSONSerialization.data(withJSONObject: usageObject)
            else {
                return nil
            }
            return try? JSONDecoder().decode(CodexHTTPUsageQuery.self, from: data)
        }()

        codexConfigEditorDraft = CodexConfigEditorDraft(
            mode: .edit(accountID: id),
            name: account.name,
            apiKey: rawJSON?["OPENAI_API_KEY"].string ?? "",
            baseURL: summary.relayBaseURL ?? "",
            modelProvider: summary.relayModelProvider ?? "",
            queryParamsText: Self.serializeKeyValueLines(relayObject),
            headersText: Self.serializeKeyValueLines(headerObject),
            httpUsageEnabled: usageQuery?.enabled ?? false,
            httpUsageMethod: usageQuery?.request?.method ?? .get,
            httpUsageURL: usageQuery?.request?.url ?? "",
            httpUsageHeadersText: Self.serializeKeyValueLines(usageQuery?.request?.headers ?? [:]),
            httpUsageBody: usageQuery?.request?.body ?? "",
            httpUsageTimeoutSeconds: usageQuery?.timeoutSeconds.map { Self.formatTimeoutSeconds($0) } ?? "15",
            httpUsageOverrideBaseURL: usageQuery?.credentials?.baseURL ?? "",
            httpUsageOverrideAPIKey: usageQuery?.credentials?.apiKey ?? "",
            httpUsageOverrideAccessToken: usageQuery?.credentials?.accessToken ?? "",
            httpUsageOverrideUserID: usageQuery?.credentials?.userID ?? "",
            httpUsagePlanPath: usageQuery?.mapping?.planPath ?? "",
            httpUsageCreditsRemainingPath: usageQuery?.mapping?.creditsRemainingPath ?? "",
            httpUsageUsedPath: usageQuery?.mapping?.usageUsedPath ?? "",
            httpUsageTotalPath: usageQuery?.mapping?.usageTotalPath ?? "",
            httpUsageCostTodayPath: usageQuery?.mapping?.costTodayUSDPath ?? "",
            httpUsageCostLast30DaysPath: usageQuery?.mapping?.costLast30DaysUSDPath ?? "",
            httpUsageErrorMessagePath: usageQuery?.mapping?.errorMessagePath ?? ""
        )
        codexConfigEditorErrorMessage = nil
        codexUsageQueryTestSuccessMessage = nil
        codexUsageQueryTestErrorMessage = nil
        isShowingCodexConfigEditor = true
    }

    func dismissCodexConfigEditor() {
        codexConfigEditorErrorMessage = nil
        codexUsageQueryTestSuccessMessage = nil
        codexUsageQueryTestErrorMessage = nil
        isTestingCodexUsageQuery = false
        codexConfigEditorDraft = nil
        isShowingCodexConfigEditor = false
    }

    func saveCodexConfigEditor() async {
        guard let draft = codexConfigEditorDraft else { return }

        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            codexConfigEditorErrorMessage = NSLocalizedString(
                "codex.accounts.config.error.name_required",
                value: "Name is required.",
                comment: "Codex config missing name"
            )
            return
        }

        let apiKey = draft.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            codexConfigEditorErrorMessage = NSLocalizedString(
                "codex.accounts.config.error.api_key_required",
                value: "API Key is required.",
                comment: "Codex config missing API key"
            )
            return
        }

        let relay: CodexAuthManager.ConfiguredRelay?
        if draft.isRelay || {
            if case .newRelay = draft.mode { return true }
            return false
        }() {
            let baseURL = draft.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            let modelProvider = draft.modelProvider.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !baseURL.isEmpty, !modelProvider.isEmpty else {
                codexConfigEditorErrorMessage = NSLocalizedString(
                    "codex.accounts.config.error.relay_required",
                    value: "Relay requires both Base URL and Model Provider.",
                    comment: "Codex relay required fields"
                )
                return
            }
            do {
                relay = try .init(
                    baseURL: baseURL,
                    modelProvider: modelProvider,
                    queryParams: Self.parseKeyValueLines(draft.queryParamsText),
                    headers: Self.parseKeyValueLines(draft.headersText)
                )
            } catch {
                codexConfigEditorErrorMessage = error.localizedDescription
                return
            }
        } else {
            relay = nil
        }

        let usageQuery: CodexHTTPUsageQuery?
        do {
            usageQuery = try makeCodexUsageQuery(from: draft)
        } catch {
            codexConfigEditorErrorMessage = error.localizedDescription
            return
        }

        do {
            switch draft.mode {
            case .newAPIKey, .newRelay:
                _ = try await codexAuthManager.addConfiguredAccount(
                    name: name,
                    apiKey: apiKey,
                    relay: relay,
                    usageQuery: usageQuery
                )
            case let .edit(accountID):
                guard let account = codexAccounts.first(where: { $0.id == accountID }) else { return }
                try await codexAuthManager.updateConfiguredAccount(
                    account,
                    name: name,
                    apiKey: apiKey,
                    relay: relay,
                    usageQuery: usageQuery
                )
            }
            dismissCodexConfigEditor()
            await reloadCodexFromDisk(refreshUsage: false)
        } catch {
            codexConfigEditorErrorMessage = error.localizedDescription
        }
    }

    func testCodexUsageQueryDraft() async {
        guard let draft = codexConfigEditorDraft else { return }
        codexConfigEditorErrorMessage = nil
        codexUsageQueryTestSuccessMessage = nil
        codexUsageQueryTestErrorMessage = nil

        let resolved: CodexHTTPUsageQueryResolvedConfiguration
        do {
            guard let query = try makeCodexUsageQuery(from: draft) else {
                throw NSError(
                    domain: "ProviderUsageViewModel.CodexUsageQuery",
                    code: 3,
                    userInfo: [NSLocalizedDescriptionKey: NSLocalizedString(
                        "codex.accounts.http_usage.test.missing",
                        value: "Enable HTTP usage query and fill the request before testing.",
                        comment: "Missing HTTP usage query test config"
                    )]
                )
            }
            resolved = try makeCodexUsageQueryResolvedConfiguration(from: draft, query: query)
        } catch {
            codexUsageQueryTestErrorMessage = error.localizedDescription
            return
        }

        isTestingCodexUsageQuery = true
        defer { isTestingCodexUsageQuery = false }

        do {
            let result = try await codexUsageQueryTestAction(resolved, settings.includeCredits)
            codexUsageQueryTestSuccessMessage = Self.codexUsageQueryTestSummary(result: result)
        } catch {
            codexUsageQueryTestErrorMessage = Self.errorSummaryText(error: error, maxLength: 220)
        }
    }

    func validateImportedAuthFiles(_ urls: [URL]) async {
        await handleCodexImportURLs(urls)
    }

    func applyValidatedImports() async {
        await applySelectedCodexImports()
    }

    func retryAllCodexImportConnectionTests() async {
        await runCodexImportConnectionTests(for: codexImportCandidates.compactMap { candidate in
            candidate.validation.isValid ? candidate.id : nil
        })
    }

    func retryCodexImportConnectionTest(id: UUID) async {
        await runCodexImportConnectionTests(for: [id])
    }

    func applySelectedCodexImports() async {
        guard usageProvider == .codex else { return }
        let selectedResults = codexImportCandidates
            .filter { $0.validation.isValid && $0.isSelected }
            .map(\.validation)

        guard !selectedResults.isEmpty else {
            codexImportGlobalErrorMessage = NSLocalizedString(
                "codex.import.sheet.error.none_selected",
                value: "请先选择至少一个可导入的账号。",
                comment: "No selected import candidates"
            )
            return
        }

        do {
            _ = try await codexAuthManager.importValidatedAuthFiles(results: selectedResults)
            dismissCodexImportSheet()
            await load()
        } catch {
            codexImportGlobalErrorMessage = error.localizedDescription
        }
    }

    func exportSelectedCodexAccountsAsZIP() async {
        guard canExportSelectedCodexAccounts else {
            alertTitle = NSLocalizedString("codex.accounts.title", value: "Accounts", comment: "Codex accounts title")
            alertMessage = NSLocalizedString(
                "codex.accounts.export.error.no_selection",
                value: "请先选择要导出的账号卡片。",
                comment: "No selected Codex accounts for export"
            )
            return
        }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.zip]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.nameFieldStringValue = Self.defaultCodexExportArchiveName()

        guard savePanel.runModal() == .OK, let destinationURL = savePanel.url else { return }

        do {
            let exportedCount = try await codexAuthManager.exportAccountsArchive(
                accountIDs: Array(selectedCodexAccountIDs),
                destinationURL: destinationURL
            )
            setCodexMultiSelectionEnabled(false)
            alertTitle = NSLocalizedString("codex.accounts.title", value: "Accounts", comment: "Codex accounts title")
            alertMessage = String(
                format: NSLocalizedString(
                    "codex.accounts.export.success",
                    value: "已导出 %d 个账号到 ZIP。",
                    comment: "Codex export success"
                ),
                exportedCount
            )
        } catch {
            alertTitle = NSLocalizedString("codex.accounts.title", value: "Accounts", comment: "Codex accounts title")
            alertMessage = error.localizedDescription
        }
    }

    func startLoginFlow() {
        if isRunningCLILogin {
            cancelCLILoginIfNeeded()
        }
        if usageProvider == .codex {
            startCLILoginFlow()
            return
        }
        if usageProvider == .gemini || usageProvider == .antigravity {
            Task { [weak self] in
                await self?.startGeminiLoginFlowAfterImportCheck()
            }
        }
    }

    func presentGeminiImportConfirmation() {
        guard let candidate = detectedGeminiImportCandidate else { return }
        pendingGeminiImportCandidate = candidate
        isShowingGeminiImportConfirm = true
    }

    func continueGeminiOAuthLoginWithoutImport() {
        isShowingGeminiImportConfirm = false
        pendingGeminiImportCandidate = nil
        startGeminiOAuthLoginFlow()
    }

    func importGeminiGlobalSessionAfterConfirmation() async {
        guard let usageProvider, usageProvider == .gemini || usageProvider == .antigravity else { return }
        isShowingGeminiImportConfirm = false
        pendingGeminiImportCandidate = nil

        do {
            let imported = try await geminiAuthStore.importFromCLIGlobalSession(
                provider: usageProvider,
                environment: ProcessInfo.processInfo.environment
            )
            if imported != nil {
                detectedGeminiImportCandidate = nil
                await load()
                return
            }
            startGeminiOAuthLoginFlow()
        } catch {
            alertTitle = NSLocalizedString("codex.cli_login.title", value: "CLI Login", comment: "CLI login title")
            alertMessage = error.localizedDescription
        }
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

    func copyCodexAccountAuthJSON(id: UUID) {
        guard let account = codexAccounts.first(where: { $0.id == id }) else { return }
        let file = codexAuthManager.accountAuthFile(relativeAuthPath: account.relativeAuthPath)
        guard let raw = try? file.read(),
              !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return }
        copyText(raw)
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
        isShowingGeminiImportConfirm = false
        pendingGeminiImportCandidate = nil
    }

    func closeCLILoginSheet() {
        cancelCLILoginIfNeeded()
    }

    func handleLoginURLSheetDismissed() {
        guard isRunningCLILogin else { return }
        cancelCLILoginIfNeeded()
    }

    private func cleanupCLILoginArtifacts() {
        cliLoginHandle?.cancel()
        cliLoginHandle = nil
        geminiLoginHandle?.cancel()
        geminiLoginHandle = nil
        cliLoginHomeDir = nil
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
        isCodexMultiSelectionEnabled = false
        selectedCodexAccountIDs = []
        dismissCodexImportSheet()
    }

    var shouldShowGeminiImportAction: Bool {
        Self.shouldShowGeminiImportAction(
            usageProvider: usageProvider,
            outcomes: outcomes,
            candidateAvailable: detectedGeminiImportCandidate != nil
        )
    }

    static func shouldShowGeminiImportAction(
        usageProvider: UsageProvider?,
        outcomes: [ProviderAccountUsageOutcome],
        candidateAvailable: Bool
    ) -> Bool {
        _ = outcomes
        return usageProvider == .gemini && candidateAvailable
    }

    static func shouldForceRefreshOnAppearForFailedOutcomes(
        _ outcomes: [ProviderAccountUsageOutcome]
    ) -> Bool {
        outcomes.contains { outcome in
            if case .failure = outcome.outcome.result {
                return true
            }
            return false
        }
    }

    static func makeCodexAccountDisplaySections(
        accounts: [CodexAuthAccount],
        outcomes: [ProviderAccountUsageOutcome],
        summaries: [UUID: CodexAuthSummary],
        grouping: CodexAccountGroupingOption,
        sorting: CodexAccountSortOption,
        sortDirection: CodexSortDirection = .descending
    ) -> [CodexAccountDisplaySection] {
        let outcomeByID = Dictionary(
            outcomes.compactMap { outcome -> (UUID, ProviderAccountUsageOutcome)? in
                guard case let .tokenAccount(account) = outcome.account else { return nil }
                return (account.id, outcome)
            },
            uniquingKeysWith: { current, _ in current }
        )

        let items = accounts.compactMap { account -> (CodexAuthAccount, ProviderAccountUsageOutcome, CodexAuthSummary?)? in
            guard let outcome = outcomeByID[account.id] else { return nil }
            return (account, outcome, summaries[account.id])
        }
        .sorted { lhs, rhs in
            compareCodexDisplayItems(
                lhs,
                rhs,
                sorting: sorting,
                sortDirection: sortDirection
            )
        }

        switch grouping {
        case .none:
            return [.init(id: "all", title: nil, items: items.map(\.1))]
        case .typeInfo:
            let grouped = Dictionary(grouping: items) { item in
                codexGroupingKey(account: item.0, summary: item.2)
            }
            return grouped.keys.sorted().map { key in
                let items = grouped[key, default: []]
                let title = items.first.map { codexGroupingTitle(account: $0.0, summary: $0.2) } ?? key
                return .init(id: key, title: title, items: items.map(\.1))
            }
        }
    }

    static func codexSortMenuOptions(from outcomes: [ProviderAccountUsageOutcome]) -> [CodexAccountSortOption] {
        let windows = availableQuotaWindowSortOptions(from: outcomes)
        return [.remainingCredits, .expiryTime, .name] + windows
    }

    static func codexSortMenuItemTitle(
        for option: CodexAccountSortOption,
        direction: CodexSortDirection?
    ) -> String {
        let base: String
        switch option {
        case .remainingCredits:
            base = NSLocalizedString("codex.accounts.sorting.remaining_credits", value: "按剩余额度", comment: "Sort by remaining credits")
        case .expiryTime:
            base = NSLocalizedString("codex.accounts.sorting.expiry_time", value: "按到期时间", comment: "Sort by expiry time")
        case .name:
            base = NSLocalizedString("codex.accounts.sorting.name", value: "按名称", comment: "Sort by name")
        case let .quotaWindowRemaining(windowMinutes):
            let period = codexWindowSortPeriodText(windowMinutes: windowMinutes)
            base = String(
                format: NSLocalizedString("codex.accounts.sorting.window_remaining", value: "按 %@ 剩余比例", comment: "Sort by remaining percent in a quota window"),
                period
            )
        }

        guard let direction else {
            return base
        }

        let indicator = switch direction {
        case .ascending: "↑"
        case .descending: "↓"
        }
        return "\(base) \(indicator)"
    }

    static func defaultCodexSortDirection(for option: CodexAccountSortOption) -> CodexSortDirection {
        switch option {
        case .remainingCredits, .quotaWindowRemaining:
            return .descending
        case .expiryTime, .name:
            return .ascending
        }
    }

    static func codexPrimaryHeaderActions(
        for activeCardKind: CodexAuthSummary.CardKind?
    ) -> [CodexPrimaryHeaderAction] {
        switch activeCardKind {
        case .officialAPIKey, .relayProfile:
            return [.refreshAll, .login, .importAuth, .editConfig, .validateConfig]
        case .chatgptAccount, .none:
            return [.refreshAll, .login, .importAuth]
        }
    }

    static func codexConfigEditorTitle(
        for mode: CodexConfigEditorMode
    ) -> String {
        switch mode {
        case .newAPIKey:
            return NSLocalizedString("codex.accounts.config.new_api_key", value: "New API Key", comment: "New API key title")
        case .newRelay:
            return NSLocalizedString("codex.accounts.config.new_relay", value: "New Relay", comment: "New relay title")
        case .edit:
            return NSLocalizedString("codex.accounts.config.edit", value: "Edit Config", comment: "Edit config title")
        }
    }

    static func codexConfigEditorSubtitle(
        for mode: CodexConfigEditorMode
    ) -> String {
        switch mode {
        case .newAPIKey:
            return NSLocalizedString(
                "codex.accounts.config.subtitle.api_key",
                value: "先填名称和 API Key。Base URL 默认官方地址，其他配置都是可选的。",
                comment: "API key config subtitle"
            )
        case .newRelay:
            return NSLocalizedString(
                "codex.accounts.config.subtitle.relay",
                value: "先填名称、API Key、Base URL 和 Provider。HTTP 用量查询与高级项都是可选的。",
                comment: "Relay config subtitle"
            )
        case .edit:
            return NSLocalizedString(
                "codex.accounts.config.subtitle.edit",
                value: "优先修改基础连接信息，HTTP 用量查询和高级项按需展开。",
                comment: "Edit config subtitle"
            )
        }
    }

    static func codexConfigEditorPrimaryActionTitle(
        for mode: CodexConfigEditorMode
    ) -> String {
        switch mode {
        case .newAPIKey, .newRelay:
            return NSLocalizedString("generic.create", value: "Create", comment: "Create")
        case .edit:
            return NSLocalizedString("generic.save", value: "Save", comment: "Save")
        }
    }

    static func parseKeyValueLines(_ text: String) throws -> [String: String] {
        var result: [String: String] = [:]
        let lines = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0) }

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else {
                throw NSError(
                    domain: "ProviderUsageViewModel.CodexConfig",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid key=value line: \(line)"]
                )
            }
            let key = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
            let value = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else {
                throw NSError(
                    domain: "ProviderUsageViewModel.CodexConfig",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Key cannot be empty."]
                )
            }
            result[key] = value
        }
        return result
    }

    static func serializeKeyValueLines(_ values: [String: String]) -> String {
        values.keys.sorted().compactMap { key in
            guard let value = values[key] else { return nil }
            return "\(key)=\(value)"
        }
        .joined(separator: "\n")
    }

    static func formatTimeoutSeconds(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }

    static func stringDictionary(from json: JSON?) -> [String: String] {
        guard let dictionary = json?.dictionaryObject else { return [:] }
        var result: [String: String] = [:]
        for (key, value) in dictionary {
            result[key] = String(describing: value)
        }
        return result
    }

    private func makeCodexUsageQuery(from draft: CodexConfigEditorDraft) throws -> CodexHTTPUsageQuery? {
        let hasAnyHTTPField =
            draft.httpUsageEnabled
            || !draft.httpUsageURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !draft.httpUsageHeadersText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !draft.httpUsageBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !draft.httpUsagePlanPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !draft.httpUsageCreditsRemainingPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !draft.httpUsageUsedPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !draft.httpUsageTotalPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !draft.httpUsageCostTodayPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !draft.httpUsageCostLast30DaysPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !draft.httpUsageErrorMessagePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !draft.httpUsageOverrideBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !draft.httpUsageOverrideAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !draft.httpUsageOverrideAccessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !draft.httpUsageOverrideUserID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        guard hasAnyHTTPField else { return nil }

        let timeoutSeconds: Double?
        let rawTimeout = draft.httpUsageTimeoutSeconds.trimmingCharacters(in: .whitespacesAndNewlines)
        if rawTimeout.isEmpty {
            timeoutSeconds = nil
        } else if let value = Double(rawTimeout) {
            timeoutSeconds = value
        } else {
            throw NSError(
                domain: "ProviderUsageViewModel.CodexUsageQuery",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: NSLocalizedString(
                    "codex.accounts.http_usage.error.timeout",
                    value: "HTTP usage timeout must be a number.",
                    comment: "HTTP usage timeout validation"
                )]
            )
        }

        let requestURL = draft.httpUsageURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if draft.httpUsageEnabled, requestURL.isEmpty {
            throw NSError(
                domain: "ProviderUsageViewModel.CodexUsageQuery",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: NSLocalizedString(
                    "codex.accounts.http_usage.error.url_required",
                    value: "HTTP usage request URL is required.",
                    comment: "HTTP usage URL required"
                )]
            )
        }

        let query = CodexHTTPUsageQuery(
            enabled: draft.httpUsageEnabled,
            timeoutSeconds: timeoutSeconds,
            request: .init(
                method: draft.httpUsageMethod,
                url: requestURL,
                headers: try Self.parseKeyValueLines(draft.httpUsageHeadersText),
                body: draft.httpUsageBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : draft.httpUsageBody
            ),
            credentials: .init(
                baseURL: emptyToNil(draft.httpUsageOverrideBaseURL),
                apiKey: emptyToNil(draft.httpUsageOverrideAPIKey),
                accessToken: emptyToNil(draft.httpUsageOverrideAccessToken),
                userID: emptyToNil(draft.httpUsageOverrideUserID)
            ),
            mapping: .init(
                planPath: emptyToNil(draft.httpUsagePlanPath),
                creditsRemainingPath: emptyToNil(draft.httpUsageCreditsRemainingPath),
                usageUsedPath: emptyToNil(draft.httpUsageUsedPath),
                usageTotalPath: emptyToNil(draft.httpUsageTotalPath),
                costTodayUSDPath: emptyToNil(draft.httpUsageCostTodayPath),
                costLast30DaysUSDPath: emptyToNil(draft.httpUsageCostLast30DaysPath),
                errorMessagePath: emptyToNil(draft.httpUsageErrorMessagePath)
            )
        )

        if query.mapping?.planPath == nil,
           query.mapping?.creditsRemainingPath == nil,
           query.mapping?.usageUsedPath == nil,
           query.mapping?.usageTotalPath == nil,
           query.mapping?.costTodayUSDPath == nil,
           query.mapping?.costLast30DaysUSDPath == nil
        {
            throw NSError(
                domain: "ProviderUsageViewModel.CodexUsageQuery",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: NSLocalizedString(
                    "codex.accounts.http_usage.error.mapping_required",
                    value: "At least one HTTP usage mapping path is required.",
                    comment: "HTTP usage mapping required"
                )]
            )
        }

        return query
    }

    private func makeCodexUsageQueryResolvedConfiguration(
        from draft: CodexConfigEditorDraft,
        query: CodexHTTPUsageQuery
    ) throws -> CodexHTTPUsageQueryResolvedConfiguration {
        let defaultCredentials = CodexHTTPUsageQueryCredentials(
            baseURL: emptyToNil(draft.baseURL),
            apiKey: emptyToNil(draft.apiKey),
            accessToken: nil,
            userID: nil
        )
        let cardKind: CodexAuthSummary.CardKind? = {
            switch draft.mode {
            case .newAPIKey:
                return .officialAPIKey
            case .newRelay:
                return .relayProfile
            case let .edit(accountID):
                return codexAccountSummaries[accountID]?.cardKind ?? (draft.isRelay ? .relayProfile : .officialAPIKey)
            }
        }()

        return CodexHTTPUsageQueryResolvedConfiguration(
            query: query,
            defaultCredentials: defaultCredentials,
            cardKind: cardKind,
            source: .explicit
        )
    }

    private static func codexUsageQueryTestSummary(result: ProviderFetchResult) -> String {
        var parts: [String] = []
        if let plan = result.usage.identity?.plan, !plan.isEmpty {
            parts.append("Plan: \(plan)")
        }
        if let credits = result.credits?.remaining, !credits.isNaN {
            parts.append("Credits: \(credits)")
        }
        if let usedPercent = result.usage.primary?.usedPercent {
            parts.append("Used: \(Int(usedPercent.rounded()))%")
        }
        if let todayCost = result.cost?.todayCostUSD {
            parts.append("Today: $\(todayCost)")
        }
        if let last30Days = result.cost?.last30DaysCostUSD {
            parts.append("30D: $\(last30Days)")
        }
        if parts.isEmpty {
            return NSLocalizedString(
                "codex.accounts.http_usage.test.success",
                value: "HTTP usage query succeeded.",
                comment: "HTTP usage test success"
            )
        }
        return parts.joined(separator: " · ")
    }

    private func emptyToNil(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func mergeCodexImportCandidates(results: [CodexAuthManager.CodexImportValidationResult]) {
        var mergedByPath: [String: CodexImportCandidate] = Dictionary(
            uniqueKeysWithValues: codexImportCandidates.map { candidate in
                (candidate.sourceFileURL.standardizedFileURL.path, candidate)
            }
        )

        for result in results {
            let candidate = makeCodexImportCandidate(result: result)
            mergedByPath[candidate.sourceFileURL.standardizedFileURL.path] = candidate
        }

        codexImportCandidates = mergedByPath.values.sorted {
            $0.sourceFileURL.lastPathComponent.localizedCaseInsensitiveCompare($1.sourceFileURL.lastPathComponent) == .orderedAscending
        }
        pendingImportValidationResults = codexImportCandidates.map(\.validation)
        importValidationSummaryMessage = codexImportCandidates
            .filter { !$0.validation.isValid }
            .compactMap { candidate in
                guard let reason = candidate.validation.reason else { return nil }
                return "\(candidate.sourceFileURL.lastPathComponent): \(reason)"
            }
            .joined(separator: "\n")
    }

    private func normalizeCodexImportText(_ raw: String) throws -> (authJSONString: String, fileExtension: String) {
        if let authJSONString = try? CodexLoginRunner.authJSONString(fromSuccessCallbackURLString: raw) {
            return (authJSONString, "json")
        }
        return (raw, "json")
    }

    private func makePastedCodexImportURL(for fileExtension: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("nolon-codex-import-pasted-\(UUID().uuidString)")
            .appendingPathExtension(fileExtension)
    }

    private func makeCodexImportCandidate(
        result: CodexAuthManager.CodexImportValidationResult
    ) -> CodexImportCandidate {
        let failureSummary = result.reason?.trimmingCharacters(in: .whitespacesAndNewlines)
        return CodexImportCandidate(
            sourceFileURL: result.fileURL,
            validation: result,
            isSelected: result.isValid,
            testStatus: result.isValid ? .idle : .failure,
            testSummary: result.isValid ? nil : failureSummary,
            testDetail: result.isValid ? nil : failureSummary
        )
    }

    private func runCodexImportConnectionTests(for ids: [UUID]) async {
        let validIDs = Set(ids)
        guard !validIDs.isEmpty else { return }
        isRunningCodexImportConnectionTests = true
        defer { isRunningCodexImportConnectionTests = false }

        codexImportCandidates = codexImportCandidates.map { candidate in
            guard validIDs.contains(candidate.id), candidate.validation.isValid else { return candidate }
            var updated = candidate
            updated.testStatus = .testing
            updated.testSummary = nil
            updated.testDetail = nil
            return updated
        }

        await withTaskGroup(of: (UUID, ProviderAccountUsageOutcome).self) { group in
            for candidate in codexImportCandidates where validIDs.contains(candidate.id) && candidate.validation.isValid {
                let validation = candidate.validation
                let settingsSnapshot = settings
                group.addTask { [codexImportConnectionTestAction] in
                    let outcome = await codexImportConnectionTestAction(validation, settingsSnapshot)
                    return (candidate.id, outcome)
                }
            }

            for await (id, outcome) in group {
                applyCodexImportConnectionTestResult(outcome, for: id)
            }
        }
    }

    private func applyCodexImportConnectionTestResult(_ outcome: ProviderAccountUsageOutcome, for id: UUID) {
        guard let index = codexImportCandidates.firstIndex(where: { $0.id == id }) else { return }
        var candidate = codexImportCandidates[index]
        switch outcome.outcome.result {
        case let .success(result):
            candidate.testStatus = .success
            candidate.testSummary = Self.codexImportTestSummary(result: result)
            candidate.testDetail = nil
        case let .failure(error):
            candidate.testStatus = .failure
            candidate.testSummary = Self.errorSummaryText(error: error)
            candidate.testDetail = Self.errorDetailText(error: error)
        }
        codexImportCandidates[index] = candidate
    }

    private static func codexImportTestSummary(result: ProviderFetchResult) -> String {
        var parts: [String] = []
        let source = result.sourceLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        if !source.isEmpty {
            parts.append(source)
        }
        if let plan = result.usage.identity?.plan?.trimmingCharacters(in: .whitespacesAndNewlines), !plan.isEmpty {
            parts.append(plan)
        }
        if let remaining = result.credits?.remaining, !remaining.isNaN {
            parts.append("Credits \(Int(remaining.rounded()))")
        } else if let usedPercent = result.usage.primary?.usedPercent {
            parts.append("Used \(Int(usedPercent.rounded()))%")
        }
        return parts.isEmpty ? NSLocalizedString("usage.monitor.refreshing", value: "Refreshing…", comment: "Refreshing status") : parts.joined(separator: " · ")
    }

    private func refreshGeminiImportCandidateAvailabilityIfNeeded(for usageProvider: UsageProvider) async {
        guard usageProvider == .gemini else {
            detectedGeminiImportCandidate = nil
            return
        }

        do {
            detectedGeminiImportCandidate = try await geminiAuthStore.globalSessionImportCandidate(
                provider: usageProvider,
                environment: ProcessInfo.processInfo.environment
            )
        } catch {
            detectedGeminiImportCandidate = nil
            Self.logger.error("Gemini import candidate refresh failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func startGeminiLoginFlowAfterImportCheck() async {
        guard let usageProvider, usageProvider == .gemini || usageProvider == .antigravity else { return }
        guard !isRunningCLILogin else { return }

        guard usageProvider == .gemini else {
            startGeminiOAuthLoginFlow()
            return
        }

        if let candidate = detectedGeminiImportCandidate {
            pendingGeminiImportCandidate = candidate
            isShowingGeminiImportConfirm = true
            return
        }

        do {
            if let candidate = try await geminiAuthStore.globalSessionImportCandidate(
                provider: usageProvider,
                environment: ProcessInfo.processInfo.environment
            ) {
                detectedGeminiImportCandidate = candidate
                pendingGeminiImportCandidate = candidate
                isShowingGeminiImportConfirm = true
                return
            }
            detectedGeminiImportCandidate = nil
        } catch {
            detectedGeminiImportCandidate = nil
            Self.logger.error("Gemini import candidate check failed: \(String(describing: error), privacy: .public)")
        }

        startGeminiOAuthLoginFlow()
    }

    private func startGeminiOAuthLoginFlow() {
        guard let usageProvider, usageProvider == .gemini || usageProvider == .antigravity else { return }
        guard !isRunningCLILogin else { return }

        let sessionID = UUID()
        cliLoginSessionId = sessionID
        isRunningCLILogin = true
        cliLoginStatus = NSLocalizedString("codex.accounts.add.cli.running", value: "Logging in…", comment: "CLI login running status")

        cliLoginTask?.cancel()
        cliLoginTask = Task { [weak self] in
            guard let self else { return }
            await self.runGeminiLoginFlow(sessionId: sessionID, usageProvider: usageProvider)
        }
    }

    private func runGeminiLoginFlow(sessionId: UUID, usageProvider: UsageProvider) async {
        defer {
            finalizeCLILoginSessionIfNeeded(sessionId: sessionId)
        }

        do {
            let accountID = UUID()
            let runtimeHome = try await geminiAuthStore.runtimeHomeURL(provider: usageProvider, accountID: accountID)
            let runner = GeminiLoginRunner()
            let handle = try runner.startOAuthLogin(
                provider: usageProvider,
                accountID: accountID,
                runtimeHomeURL: runtimeHome
            )
            geminiLoginHandle = handle
            loginModeForSheet = "Gemini OAuth"
            cliLoginStatus = NSLocalizedString(
                "codex.accounts.add.cli.waiting",
                value: "Waiting for auth.json…",
                comment: "CLI login waiting status"
            )

            let tokenFile = runtimeHome
                .appendingPathComponent(".gemini", isDirectory: true)
                .appendingPathComponent("mcp-oauth-tokens-v2.json")
            let deadline = Date().addingTimeInterval(cliLoginTimeoutSeconds)
            let processExitGraceSeconds: TimeInterval = 4
            var processExitedAt: Date?

            while !Task.isCancelled {
                guard cliLoginSessionId == sessionId else { return }

                if FileManager.default.fileExists(atPath: tokenFile.path),
                   let data = try? Data(contentsOf: tokenFile),
                   !data.isEmpty {
                    break
                }

                if let urlRaw = handle.loginURL, let url = URL(string: urlRaw) {
                    if loginURLForSheet?.absoluteString != url.absoluteString {
                        loginURLForSheet = url
                        isShowingLoginURLSheet = true
                    }
                }

                if !handle.isRunning {
                    if processExitedAt == nil {
                        processExitedAt = Date()
                    } else if Date().timeIntervalSince(processExitedAt!) >= processExitGraceSeconds {
                        throw GeminiLoginError.authNotCompleted
                    }
                }

                if Date() >= deadline {
                    throw GeminiLoginError.loginTimedOut
                }

                try await Task.sleep(nanoseconds: 250_000_000)
            }

            guard !Task.isCancelled else { return }

            let defaultName = usageProvider == .antigravity ? "Antigravity OAuth" : "Gemini OAuth"
            _ = try await geminiAuthStore.upsertAccount(
                provider: usageProvider,
                accountID: accountID,
                name: defaultName,
                method: .oauthPersonal,
                markActive: true,
                updateLastLoginAt: true
            )

            await load()
        } catch {
            if error is CancellationError { return }
            guard cliLoginSessionId == sessionId else { return }
            alertTitle = NSLocalizedString("codex.cli_login.title", value: "CLI Login", comment: "CLI login title")
            alertMessage = error.localizedDescription
        }
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
            guard cliLoginSessionId == sessionId else { return }
            Self.logger.error("App-server login failed without fallback. error=\(String(describing: error), privacy: .public)")
            handleAppServerLoginFailure(error)
        }
    }

    func handleAppServerLoginFailure(_ error: Error) {
        alertTitle = NSLocalizedString("codex.cli_login.title", value: "CLI Login", comment: "CLI login title")
        alertMessage = error.localizedDescription
    }

    private func runAppServerLoginFlow(sessionId: UUID) async throws {
        guard cliLoginSessionId == sessionId else { return }
        let loginHome = try prepareCLILoginHomeDirectory()
        cliLoginHomeDir = loginHome
        var env = ProcessInfo.processInfo.environment
        if let managedEnv = try? await CodexBinaryManager.shared.launchEnvironmentVariables() {
            env.merge(managedEnv) { _, new in new }
        }
        env["CODEX_HOME"] = loginHome.path
        let service = CodexAccountRuntimeService(
            executable: env["CODEX_CLI_PATH"] ?? "codex",
            environment: env
        )
        defer { Task { await service.shutdown() } }

        try await service.initialize(clientName: "codex", clientVersion: "1.0.0")
        let started = try await service.startChatGPTLogin()
        loginURLForSheet = started.authURL
        loginModeForSheet = "CLI(AppServer)"
        isShowingLoginURLSheet = true
        cliLoginStatus = NSLocalizedString("codex.accounts.add.cli.waiting", value: "Waiting for auth.json…", comment: "CLI login waiting status")
        let authResult = try await CodexLoginRunner.awaitAuthResultPreferFile(
            codexHome: STFolder(loginHome),
            timeoutSeconds: cliLoginTimeoutSeconds,
            pollIntervalSeconds: 0.2,
            completionWaiter: {
                try await service.awaitChatGPTLoginCompletion(loginID: started.loginID, timeout: self.cliLoginTimeoutSeconds)
            }
        )
        let account = try await codexAuthManager.recordCLILoginSnapshot(
            authJSONString: authResult.authJSONString,
            preferredAccountID: cliLoginPreferredAccountId,
            loginAt: Date()
        )
        schedulePostLoginReload(preferredBackfillAccount: account)
    }

    private func runCLILoginFlow(sessionId: UUID) async {
        defer {
            finalizeCLILoginSessionIfNeeded(sessionId: sessionId)
        }

        do {
            let loginHome = try prepareCLILoginHomeDirectory()
            cliLoginHomeDir = loginHome
            Self.logger.info("CLI login started. home=\(loginHome.path, privacy: .public)")

            var env = ProcessInfo.processInfo.environment
            if let managedEnv = try? await CodexBinaryManager.shared.launchEnvironmentVariables() {
                env.merge(managedEnv) { _, new in new }
            }

            let runner = CodexLoginRunner()
            cliLoginHandle = try runner.startLogin(environment: env, codexHome: loginHome)
            Self.logger.info("CLI login process launched.")
            loginModeForSheet = "Direct OAuth"

            cliLoginStatus = NSLocalizedString("codex.accounts.add.cli.waiting", value: "Waiting for auth.json…", comment: "CLI login waiting status")

            let fileManager = FileManager.default
            let authFile = loginHome.appendingPathComponent("auth.json")
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
            cliLoginHomeDir = nil

            schedulePostLoginReload(preferredBackfillAccount: account)
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

    private func schedulePostLoginReload(preferredBackfillAccount account: CodexAuthAccount? = nil) {
        Task { [weak self] in
            guard let self else { return }
            if let account {
                _ = await self.probeLoginSnapshotUsageAndBackfillEmailIfMissing(account: account)
            }
            await self.load()
            guard let accountID = account?.id,
                  let refreshedAccount = self.codexAccounts.first(where: { $0.id == accountID })
            else { return }
            // Force one immediate usage refresh for the newly logged-in snapshot.
            await self.refreshCodexAccountOutcome(refreshedAccount)
        }
    }

    private func probeLoginSnapshotUsageAndBackfillEmailIfMissing(account: CodexAuthAccount) async -> ProviderAccountUsageOutcome {
        let authURL = codexAuthManager.accountAuthFile(relativeAuthPath: account.relativeAuthPath).url
        let outcome = await codexOutcomeFetchAction(account, settings, authURL)

        if case let .success(result) = outcome.outcome.result,
           let email = result.usage.identity?.accountEmail?.trimmingCharacters(in: .whitespacesAndNewlines),
           !email.isEmpty
        {
            _ = try? await codexAuthManager.backfillEmailIfMissing(for: account, email: email)
        }
        return outcome
    }

    func requestActivateCodexAccount(id: UUID) {
        guard let account = codexAccounts.first(where: { $0.id == id }) else { return }
        pendingActivateCodexAccount = account
        isShowingActivateConfirm = true
    }

    func codexCardKind(accountID: UUID?) -> CodexAuthSummary.CardKind? {
        guard let accountID else { return nil }
        return codexAccountSummaries[accountID]?.cardKind
    }

    func codexAccountSupportsLogin(accountID: UUID?) -> Bool {
        codexCardKind(accountID: accountID) == .chatgptAccount
    }

    func codexAccountSupportsEditing(accountID: UUID?) -> Bool {
        switch codexCardKind(accountID: accountID) {
        case .officialAPIKey, .relayProfile:
            return true
        default:
            return false
        }
    }

    func beginEditActiveCodexConfiguredAccount() {
        guard let activeCodexAccountId else { return }
        beginEditCodexConfiguredAccount(id: activeCodexAccountId)
    }

    func validateActiveCodexConfiguredAccount() {
        guard let activeCodexAccountId else { return }
        refreshCodexAccount(id: activeCodexAccountId)
    }

    private func reconcileCodexSelections() {
        let validIDs = Set(codexAccounts.map(\.id))
        selectedCodexAccountIDs = selectedCodexAccountIDs.intersection(validIDs)
        if selectedCodexAccountIDs.isEmpty, isCodexMultiSelectionEnabled == false {
            return
        }
        if validIDs.isEmpty {
            setCodexMultiSelectionEnabled(false)
        }
    }

    func isCodexSectionCollapsed(_ sectionID: String) -> Bool {
        collapsedCodexSectionIDs.contains(sectionID)
    }

    func toggleCodexSection(_ sectionID: String) {
        if collapsedCodexSectionIDs.contains(sectionID) {
            collapsedCodexSectionIDs.remove(sectionID)
        } else {
            collapsedCodexSectionIDs.insert(sectionID)
        }
    }

    func selectCodexSortOption(_ option: CodexAccountSortOption) {
        if codexAccountSortOption == option {
            codexCurrentSortDirection = codexCurrentSortDirection == .ascending ? .descending : .ascending
            return
        }

        codexAccountSortOption = option
        codexCurrentSortDirection = Self.defaultCodexSortDirection(for: option)
    }

    func codexDirection(for option: CodexAccountSortOption) -> CodexSortDirection {
        option == codexAccountSortOption ? codexCurrentSortDirection : Self.defaultCodexSortDirection(for: option)
    }

    func requestDeleteCodexAccount(id: UUID) {
        guard let account = codexAccounts.first(where: { $0.id == id }) else {
            codexAccountOutcomes.removeAll { outcome in
                switch outcome.account {
                case let .tokenAccount(account):
                    return account.id == id
                case .default:
                    return false
                }
            }
            return
        }
        pendingDeleteCodexAccount = account
        isShowingDeleteConfirm = true
    }

    private static func defaultCodexExportArchiveName(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "codex-accounts-\(formatter.string(from: now)).zip"
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
                try await codexAuthManager.deleteAccount(id: account.id, provider: provider)
            }

            pendingDeleteCodexAccount = nil
            isShowingDeleteConfirm = false

            if let postDeleteLoadAction {
                await postDeleteLoadAction()
            } else {
                await reloadCodexFromDisk(refreshUsage: false)
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

    private func mergeUsageWindows(live: UsageSnapshot, cached: UsageSnapshot) -> [UsageWindow] {
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
        var isRefreshingCleared = false
        defer {
            if !isRefreshingCleared {
                codexRefreshingAccountIds.remove(accountId)
            }
        }

        let authURL = codexAuthManager.accountAuthFile(relativeAuthPath: account.relativeAuthPath).url
        let outcome = await fetchCodexOutcomeWithTimeout(account: account, settings: settings, authURL: authURL)
        codexRefreshingAccountIds.remove(accountId)
        isRefreshingCleared = true
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
            tasks[account.id] = Task(priority: .userInitiated) {
                await self.fetchCodexOutcomeWithTimeout(account: account, settings: settingsSnapshot, authURL: authURL)
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

    private func applyRefreshedCodexOutcome(_ outcome: ProviderAccountUsageOutcome, for account: CodexAuthAccount) async {
        let accountId = account.id
        lastUsageRefreshAt = Date()

        if case let .success(result) = outcome.outcome.result {
            updateCodexOutcome(outcome, for: account)
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
            codexUsageCacheWriteCount += 1
            defer { codexUsageCacheWriteCount = max(0, codexUsageCacheWriteCount - 1) }
            try await codexAuthManager.storeUsageCache(cache, for: account)
            } catch {
                // Best-effort cache write; ignore.
            }

            if let identity = result.usage.identity {
                var summary = codexAccountSummaries[accountId] ?? CodexAuthSummary()
                if let email = identity.accountEmail?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !email.isEmpty
                {
                    if summary.email == nil {
                        _ = try? await codexAuthManager.backfillEmailIfMissing(for: account, email: email)
                    }
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
            if !shouldRetainExistingCodexSuccessResult(for: accountId, error: error) {
                updateCodexOutcome(outcome, for: account)
            }
            try? await codexAuthManager.updateSyncFailure(for: account, message: message, date: now)
            var summary = codexAccountSummaries[accountId] ?? CodexAuthSummary()
            summary.lastSyncFailedAt = now
            summary.lastSyncFailureMessage = message
            codexAccountSummaries[accountId] = summary
        }
    }

    private func shouldRetainExistingCodexSuccessResult(for accountID: UUID, error: Error) -> Bool {
        guard error is CodexHTTPUsageQueryError else { return false }
        guard let existing = codexAccountOutcomes.first(where: { outcome in
            if case let .tokenAccount(account) = outcome.account {
                return account.id == accountID
            }
            return false
        }) else {
            return false
        }
        if case .success = existing.outcome.result {
            return true
        }
        return false
    }

    private func orderedAccounts(activeId: UUID?) -> [CodexAuthAccount] {
        guard !codexAccounts.isEmpty else { return [] }
        let uniqueAccounts = uniqueCodexAccountsInDisplayOrder()
        let resolvedActiveID: UUID? = {
            if let activeId { return activeId }
            if let active = uniqueAccounts.first(where: { account in
                if let current = activeCodexAccountForRefresh() {
                    return account.id == current.id
                }
                return false
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
            codexUsageCacheWriteCount += 1
            defer { codexUsageCacheWriteCount = max(0, codexUsageCacheWriteCount - 1) }
            try await codexAuthManager.storeUsageCache(cache, for: activeAccount)
        } catch {
            // Best-effort cache write; ignore.
        }
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

        return false
    }

    private func updateCodexOutcome(_ outcome: ProviderAccountUsageOutcome, for account: CodexAuthAccount) {
        replaceCodexOutcome(outcome, for: account.id)
    }

    private func fetchCodexOutcomeWithTimeout(
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

    nonisolated private static func codexTimedOutOutcome(
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
            domain: "ProviderUsageViewModel.CodexRefresh",
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

    private func uniqueCodexAccountIDsInDisplayOrder() -> [UUID] {
        var seen: Set<UUID> = []
        return codexAccounts.compactMap { account in
            if seen.insert(account.id).inserted {
                return account.id
            }
            return nil
        }
    }

    private func uniqueCodexAccountsInDisplayOrder() -> [CodexAuthAccount] {
        var seen: Set<UUID> = []
        return codexAccounts.compactMap { account in
            if seen.insert(account.id).inserted {
                return account
            }
            return nil
        }
    }

    private static func compareCodexDisplayItems(
        _ lhs: (CodexAuthAccount, ProviderAccountUsageOutcome, CodexAuthSummary?),
        _ rhs: (CodexAuthAccount, ProviderAccountUsageOutcome, CodexAuthSummary?),
        sorting: CodexAccountSortOption,
        sortDirection: CodexSortDirection = .descending
    ) -> Bool {
        switch sorting {
        case .remainingCredits:
            let lhsAmount = creditsRemaining(from: lhs.1)
            let rhsAmount = creditsRemaining(from: rhs.1)
            switch (lhsAmount, rhsAmount) {
            case let (lhs?, rhs?) where lhs != rhs:
                switch sortDirection {
                case .descending:
                    return lhs > rhs
                case .ascending:
                    return lhs < rhs
                }
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            default:
                break
            }
        case .expiryTime:
            let lhsExpiry = expirySortDate(from: lhs.1)
            let rhsExpiry = expirySortDate(from: rhs.1)
            switch (lhsExpiry, rhsExpiry) {
            case let (lhs?, rhs?) where lhs != rhs:
                switch sortDirection {
                case .descending:
                    return lhs > rhs
                case .ascending:
                    return lhs < rhs
                }
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            default:
                break
            }
        case let .quotaWindowRemaining(windowMinutes):
            let lhsAmount = quotaWindowRemainingPercent(from: lhs.1, windowMinutes: windowMinutes)
            let rhsAmount = quotaWindowRemainingPercent(from: rhs.1, windowMinutes: windowMinutes)
            switch (lhsAmount, rhsAmount) {
            case let (lhs?, rhs?) where lhs != rhs:
                switch sortDirection {
                case .descending:
                    return lhs > rhs
                case .ascending:
                    return lhs < rhs
                }
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            default:
                break
            }
        case .name:
            let lhsName = codexDisplayName(account: lhs.0, outcome: lhs.1, summary: lhs.2)
            let rhsName = codexDisplayName(account: rhs.0, outcome: rhs.1, summary: rhs.2)
            let compare = lhsName.localizedCaseInsensitiveCompare(rhsName)
            if compare != .orderedSame {
                switch sortDirection {
                case .descending:
                    return compare == .orderedDescending
                case .ascending:
                    return compare == .orderedAscending
                }
            }
            return lhs.0.id.uuidString < rhs.0.id.uuidString
        }

        let lhsName = codexDisplayName(account: lhs.0, outcome: lhs.1, summary: lhs.2)
        let rhsName = codexDisplayName(account: rhs.0, outcome: rhs.1, summary: rhs.2)
        let compare = lhsName.localizedCaseInsensitiveCompare(rhsName)
        if compare != .orderedSame {
            return compare == .orderedAscending
        }
        return lhs.0.id.uuidString < rhs.0.id.uuidString
    }

    private static func codexDisplayName(
        account: CodexAuthAccount,
        outcome: ProviderAccountUsageOutcome,
        summary: CodexAuthSummary?
    ) -> String {
        let outcomeName = outcome.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !outcomeName.isEmpty {
            return outcomeName
        }
        let email = summary?.email?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !email.isEmpty {
            return email
        }
        let accountName = account.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !accountName.isEmpty {
            return accountName
        }
        return account.id.uuidString
    }

    private static func codexGroupingKey(account: CodexAuthAccount, summary: CodexAuthSummary?) -> String {
        codexGroupingTitle(account: account, summary: summary).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private static func codexGroupingTitle(account: CodexAuthAccount, summary: CodexAuthSummary?) -> String {
        switch summary?.cardKind {
        case .officialAPIKey:
            return "OpenAI"
        case .relayProfile:
            let provider = summary?.relayModelProvider?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !provider.isEmpty {
                return normalizedRelayProviderTitle(provider)
            }
            let baseURL = summary?.relayBaseURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if let host = URL(string: baseURL)?.host, !host.isEmpty {
                return host
            }
            return NSLocalizedString("codex.accounts.group.unknown", value: "Unknown", comment: "Unknown codex account group")
        case .chatgptAccount, .none:
            let plan = summary?.plan?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !plan.isEmpty {
                return plan
            }
            if let explicitKind = summary?.cardKind, explicitKind == .officialAPIKey {
                return "OpenAI"
            }
            return NSLocalizedString("codex.accounts.group.unknown", value: "Unknown", comment: "Unknown codex account group")
        }
    }

    private static func creditsRemaining(from outcome: ProviderAccountUsageOutcome) -> Double? {
        guard case let .success(result) = outcome.outcome.result else { return nil }
        return result.credits?.remaining
    }

    private static func quotaWindowRemainingPercent(
        from outcome: ProviderAccountUsageOutcome,
        windowMinutes: Int
    ) -> Double? {
        guard case let .success(result) = outcome.outcome.result else { return nil }
        let windows = result.usage.allWindows.map(\.window)
        return windows
            .first(where: { $0.windowMinutes == windowMinutes })?
            .remainingPercent
    }

    private static func expirySortDate(from outcome: ProviderAccountUsageOutcome) -> Date? {
        guard case let .success(result) = outcome.outcome.result else { return nil }
        let windows = result.usage.allWindows.map(\.window)
        return windows.compactMap(\.resetsAt).min()
    }

    private static func availableQuotaWindowSortOptions(
        from outcomes: [ProviderAccountUsageOutcome]
    ) -> [CodexAccountSortOption] {
        let values = outcomes.compactMap { outcome -> [Int]? in
            guard case let .success(result) = outcome.outcome.result else { return nil }
            return result.usage.allWindows
                .map(\.window.windowMinutes)
                .compactMap { $0 }
                .filter { $0 > 0 }
        }

        return Array(Set(values.flatMap { $0 })).sorted().map { .quotaWindowRemaining(windowMinutes: $0) }
    }

    private static func normalizedRelayProviderTitle(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        let lowercased = trimmed.lowercased()
        if trimmed == lowercased || trimmed == trimmed.uppercased() {
            return lowercased.localizedCapitalized
        }
        return trimmed
    }

    private static func codexWindowSortPeriodText(windowMinutes: Int) -> String {
        let weekMinutes = 7 * 24 * 60
        let dayMinutes = 24 * 60
        if windowMinutes % weekMinutes == 0 {
            return "\(windowMinutes / weekMinutes)w"
        }
        if windowMinutes % dayMinutes == 0 {
            return "\(windowMinutes / dayMinutes)d"
        }
        if windowMinutes % 60 == 0 {
            return "\(windowMinutes / 60)h"
        }
        return "\(windowMinutes)m"
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

    nonisolated private static func testCodexImportConnectionDetached(
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
            return await fetchCodexOutcomeDetached(for: account, settings: settings, authSourceURL: authURL)
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

    func prepareCLILoginHomeDirectory() throws -> URL {
        let providerID = Self.canonicalCodexProviderID(for: provider)
        let codexHome = codexAuthManager.cliLoginCodexHomeFolder(providerID: providerID)
        _ = codexHome.createIfNotExists()
        try writeCLILoginConfig(codexHome: codexHome)
        try removeCLILoginAuthFileIfPresent(codexHome: codexHome)
        return codexHome.url.standardizedFileURL
    }

    private static func canonicalCodexProviderID(for provider: Provider) -> String {
        let normalized = provider.templateId?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        switch normalized {
        case "codex":
            return "codex"
        case "codexxcode", "codex-xcode":
            return "codex-xcode"
        default:
            return "codex"
        }
    }

    private func writeCLILoginConfig(codexHome: STFolder) throws {
        let configFile = codexHome.file("config.toml")
        let content = "cli_auth_credentials_store = \"file\"\n"
        if configFile.isExists,
           let existing = try? configFile.read(),
           existing == content {
            return
        }
        try configFile.overlay(with: content)
    }

    private func removeCLILoginAuthFileIfPresent(codexHome: STFolder) throws {
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
