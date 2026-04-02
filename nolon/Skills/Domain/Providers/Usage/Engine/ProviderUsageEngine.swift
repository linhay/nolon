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

@MainActor
@Observable
final class ProviderUsageEngine {
    static let logger = Logger(subsystem: "com.nolon", category: "ProviderUsageEngine")
    private static var codexInitialFullRefreshProviderIDs: Set<String> = []
    private static let codexOfficialAPIBaseURL = "https://api.openai.com/v1"
    private static let codexGatewayDefaultHost = "127.0.0.1"
    private static let codexGatewayDefaultPort = 8080
    private let usageMonitor: ProviderUsageMonitorService
    private let codexTokenTrendService = CodexTokenTrendService()
    private let codexModelPreferenceService: CodexModelPreferenceService
    private let settingsStore = UsageMonitorSettingsStore.shared
    private let codexGatewayCardsStore: CodexGatewayCardsStore
    private let codexAuthManager: CodexAuthManager
    let claudeAccountManager = ClaudeAccountManager()
    let geminiAuthStore = GeminiAuthStore.shared
    private let actions: ActionDependencies
    private var codexActivateAction: CodexActivateAction { actions.codexActivate }
    private var postActivationLoadAction: AsyncVoidAction? { actions.postActivationLoad }
    private var codexDeleteAction: CodexDeleteAction? { actions.codexDelete }
    private var postDeleteLoadAction: AsyncVoidAction? { actions.postDeleteLoad }
    private var codexRefreshAllAction: CodexRefreshAllAction? { actions.codexRefreshAll }
    private var codexPreflightAction: CodexPreflightAction? { actions.codexPreflight }
    private var codexOutcomeFetchAction: CodexOutcomeFetchAction { actions.codexOutcomeFetch }
    private var codexUsageQueryTestAction: CodexUsageQueryTestAction { actions.codexUsageQueryTest }
    private var codexConfiguredAccountValidateAction: CodexConfiguredAccountValidateAction { actions.codexConfiguredAccountValidate }
    var codexImportConnectionTestAction: CodexImportConnectionTestAction { actions.codexImportConnectionTest }
    private var codexGatewayStartAction: CodexGatewayStartAction { actions.codexGatewayStart }
    private var codexGatewayStopAction: CodexGatewayStopAction { actions.codexGatewayStop }
    private var codexImportOpenPanelAction: CodexImportOpenPanelAction { actions.codexImportOpenPanel }
    private var codexExportSavePanelAction: CodexExportSavePanelAction { actions.codexExportSavePanel }
    private var codexImportExportArchiveAction: CodexImportExportArchiveAction { actions.codexImportExportArchive }
    private var geminiTokenTrendFetchAction: GeminiTokenTrendFetchAction { actions.geminiTokenTrendFetch }
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
    var codexAccountCustomGroupNames: [UUID: String] = [:]
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
    var shouldShowTokenTrendLoadingSkeleton: Bool {
        guard usageProvider == .codex || usageProvider == .gemini else { return false }
        guard tokenTrendSnapshot == nil else { return false }
        guard tokenTrendErrorMessage?.isEmpty != false else { return false }
        return isLoading || isLoadingTokenTrend
    }
    var codexAccountGroupingOption: CodexAccountGroupingOption = .typeInfo
    var codexAccountSortOption: CodexAccountSortOption = .remainingCredits
    var codexCurrentSortDirection: CodexSortDirection = .descending
    var codexHideZeroQuotaAccounts = false
    var codexHideErroredAccounts = false
    var accountLayoutMode: UsageAccountLayoutMode = .cards
    var collapsedCodexSectionIDs: Set<String> = []
    var isCodexMultiSelectionEnabled = false
    var selectedCodexAccountIDs: Set<UUID> = []
    var gatewayCardsState = CodexGatewayCardsState()
    var isGatewayCardsSectionCollapsed = false
    var isShowingGatewayCardPicker = false
    var pendingGatewaySelectionAccountIDs: [UUID] = []
    var claudeAccounts: [ClaudeAccount] = []
    var activeClaudeAccountId: UUID?
    var geminiAccounts: [GeminiAuthAccount] = []
    var activeGeminiAccountId: UUID?

    var addAccountSource: CodexAddSource = .current
    var importedAuthFileURL: URL?
    var importedAuthFileURLs: [URL] = []
    var isShowingAuthFileImporter = false
    var isShowingCodexImportSheet = false
    var isRunningCodexImportValidation = false
    var isRunningCodexImportConnectionTests = false
    var isTargetingCodexImportDropZone = false
    var codexImportGlobalErrorMessage: String?
    var codexImportSearchText = ""
    var codexImportCandidates: [CodexImportCandidate] = []
    var codexImportDestinationOption: CodexImportDestinationOption = .managedSnapshots
    var codexImportCustomGroupName = ""
    var isRunningCLILogin = false
    var cliLoginStatus: String?
    var cliLoginPreferredAccountId: UUID?
    @ObservationIgnored private var cliLoginHandle: CodexLoginHandle?
    @ObservationIgnored var geminiLoginHandle: GeminiLoginHandle?
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
    var codexConfigEditorModelProviderOptions: [String] = []
    var codexConfigEditorErrorMessage: String?
    var isTestingCodexUsageQuery = false
    var codexUsageQueryTestSuccessMessage: String?
    var codexUsageQueryTestErrorMessage: String?

    var alertTitle: String?
    var alertMessage: String?
    var isShowingCopyToast = false
    var copyToastMessage = NSLocalizedString("remote.error.copied", value: "Copied", comment: "Copied tooltip")

    var cliLoginTask: Task<Void, Never>?
    var cliLoginSessionId: UUID?
    @ObservationIgnored private var codexImportConnectionTestsTask: Task<Void, Never>?
    @ObservationIgnored private var copyToastTask: Task<Void, Never>?
    @ObservationIgnored private var codexAuthReloadSignalCancellable: AnyCancellable?
    @ObservationIgnored private var codexReloadTask: Task<Void, Never>?
    @ObservationIgnored private let codexAuthReloadSignal = PassthroughSubject<Void, Never>()
    @ObservationIgnored private var codexSQLiteObservationDatabaseQueue: DatabaseQueue?
    @ObservationIgnored private var codexSQLiteObservationCancellable: AnyDatabaseCancellable?
    @ObservationIgnored private var codexSQLiteObservationLastSnapshot: CodexSQLiteObservationSnapshot?
    private var codexReloadPending = false
    private var codexReloadPendingRefreshUsage = false
    private var codexUsageCacheWriteCount = 0
    private var gatewaySwitchInProgressTokens: Set<UUID> = []
    private(set) var codexDiskReloadCountForTesting = 0
    private var hasTriggeredAppearRefresh = false
    private var didStartInitialLoad = false
    private var lastUsageRefreshAt: Date?
    let cliLoginTimeoutSeconds: TimeInterval = 10 * 60
    private let codexRefreshTimeoutGraceSeconds: TimeInterval
    @ObservationIgnored private var codexHeaderRefreshTask: Task<Void, Never>?
    private var codexHeaderRefreshSessionID: UUID?
    var isCodexHeaderRefreshing = false

    private struct CodexSQLiteObservationSnapshot: Equatable {
        let accountsCount: Int
        let credentialsCount: Int
        let metadataCount: Int
        let activeCount: Int
    }

    private struct CodexValidationTarget {
        let baseURL: URL
        let headers: [String: String]
        let queryParams: [String: String]
    }

    var usageAggregate: ProviderUsageAggregate {
        usageSnapshotService.aggregate(items: currentSnapshotItems())
    }

    init(
        provider: Provider,
        codexAuthManager: CodexAuthManager = .shared,
        usageMonitor: ProviderUsageMonitorService? = nil,
        codexActivateAction: CodexActivateAction? = nil,
        postActivationLoadAction: AsyncVoidAction? = nil,
        codexDeleteAction: CodexDeleteAction? = nil,
        codexRefreshAllAction: CodexRefreshAllAction? = nil,
        codexPreflightAction: CodexPreflightAction? = nil,
        codexOutcomeFetchAction: CodexOutcomeFetchAction? = nil,
        codexUsageQueryTestAction: CodexUsageQueryTestAction? = nil,
        codexConfiguredAccountValidateAction: CodexConfiguredAccountValidateAction? = nil,
        codexImportConnectionTestAction: CodexImportConnectionTestAction? = nil,
        codexGatewayStartAction: CodexGatewayStartAction? = nil,
        codexGatewayStopAction: CodexGatewayStopAction? = nil,
        codexImportOpenPanelAction: CodexImportOpenPanelAction? = nil,
        codexExportSavePanelAction: CodexExportSavePanelAction? = nil,
        codexImportExportArchiveAction: CodexImportExportArchiveAction? = nil,
        geminiTokenTrendFetchAction: GeminiTokenTrendFetchAction? = nil,
        postDeleteLoadAction: AsyncVoidAction? = nil,
        codexRefreshTimeoutGraceSeconds: TimeInterval = 5,
        initialSettingsOverride: UsageMonitorProviderSettings? = nil,
        codexGatewayCardsStore: CodexGatewayCardsStore? = nil,
        codexModelPreferenceService: CodexModelPreferenceService = CodexModelPreferenceService()
    ) {
        let tokenStore = FileTokenAccountStore(fileURL: ProviderUsagePaths.defaultTokenAccountsFileURL())
        let resolvedCodexGatewayCardsStore = codexGatewayCardsStore ?? .shared
        self.usageMonitor = usageMonitor ?? ProviderUsageMonitorService(tokenAccountStore: tokenStore)
        self.codexGatewayCardsStore = resolvedCodexGatewayCardsStore
        self.codexAuthManager = codexAuthManager
        self.provider = provider
        self.codexModelPreferenceService = codexModelPreferenceService
        self.usageProvider = ProviderUsageEngine.mapToUsageProvider(provider)
        self.codexRefreshTimeoutGraceSeconds = codexRefreshTimeoutGraceSeconds
        let initialSettings = initialSettingsOverride ?? settingsStore.settings(for: provider)
        self.settings = initialSettings
        self.codexHideZeroQuotaAccounts = initialSettings.codexHideZeroQuotaAccounts
        self.codexHideErroredAccounts = initialSettings.codexHideErroredAccounts
        self.accountLayoutMode = initialSettings.codexUseListLayout ? .list : .cards
        self.gatewayCardsState = resolvedCodexGatewayCardsStore.load(for: provider)
        if ProviderUsageEngine.mapToUsageProvider(provider) == .codex {
            self.isMultiAccountEnabled = true
        } else {
            self.isMultiAccountEnabled = settingsStore.isMultiAccountEnabled(for: provider)
        }
        let resolvedCodexActivateAction = codexActivateAction ?? { account, provider in
            try await CodexAuthActivationCoordinator.shared.activate(account: account, provider: provider)
        }
        let resolvedCodexOutcomeFetchAction = codexOutcomeFetchAction ?? { account, settings, authSourceURL in
            await Self.fetchCodexOutcomeDetached(for: account, settings: settings, authSourceURL: authSourceURL)
        }
        let resolvedCodexUsageQueryTestAction = codexUsageQueryTestAction ?? { resolved, includeCredits in
            try await CodexHTTPUsageQueryExecutor().execute(resolved, includeCredits: includeCredits)
        }
        let resolvedCodexConfiguredAccountValidateAction = codexConfiguredAccountValidateAction ?? { account in
            try await Self.validateCodexConfiguredAccountDetached(account: account)
        }
        let resolvedCodexImportConnectionTestAction = codexImportConnectionTestAction ?? { validationResult, settings in
            await Self.testCodexImportConnectionDetached(validationResult: validationResult, settings: settings)
        }
        let resolvedCodexGatewayStartAction = codexGatewayStartAction ?? { providerID, host, port in
            _ = try await NolonLiveCodexCLIService().gatewayStart(providerID: providerID, host: host, port: port)
        }
        let resolvedCodexGatewayStopAction = codexGatewayStopAction ?? { providerID in
            _ = try await NolonLiveCodexCLIService().gatewayStop(providerID: providerID)
        }
        let resolvedCodexImportOpenPanelAction = codexImportOpenPanelAction ?? {
            let panel = NSOpenPanel()
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            panel.allowsMultipleSelection = true
            panel.allowedContentTypes = [.json, .data, .zip]
            panel.message = NSLocalizedString(
                "codex.import.sheet.open_panel.message",
                value: "选择要导入的 auth.json 或 ZIP 文件。",
                comment: "Codex import open panel message"
            )
            panel.prompt = NSLocalizedString("select", comment: "Select")
            return panel.runModal() == .OK ? panel.urls : []
        }
        let resolvedCodexExportSavePanelAction = codexExportSavePanelAction ?? { contentType, defaultName in
            let panel = NSSavePanel()
            panel.allowedContentTypes = [contentType]
            panel.canCreateDirectories = true
            panel.isExtensionHidden = false
            panel.nameFieldStringValue = defaultName
            return panel.runModal() == .OK ? panel.url : nil
        }
        let resolvedCodexImportExportArchiveAction = codexImportExportArchiveAction ?? { [codexAuthManager] results, destinationURL in
            try await codexAuthManager.exportValidatedAuthFilesArchive(results: results, destinationURL: destinationURL)
        }
        let resolvedGeminiTokenTrendFetchAction = geminiTokenTrendFetchAction ?? { provider, trailingDays in
            try await GeminiTokenTrendService().fetchActiveSnapshot(provider: provider, trailingDays: trailingDays)
        }
        self.actions = ActionDependencies(
            codexActivate: resolvedCodexActivateAction,
            postActivationLoad: postActivationLoadAction,
            codexDelete: codexDeleteAction,
            postDeleteLoad: postDeleteLoadAction,
            codexRefreshAll: codexRefreshAllAction,
            codexPreflight: codexPreflightAction,
            codexOutcomeFetch: resolvedCodexOutcomeFetchAction,
            codexUsageQueryTest: resolvedCodexUsageQueryTestAction,
            codexConfiguredAccountValidate: resolvedCodexConfiguredAccountValidateAction,
            codexImportConnectionTest: resolvedCodexImportConnectionTestAction,
            codexGatewayStart: resolvedCodexGatewayStartAction,
            codexGatewayStop: resolvedCodexGatewayStopAction,
            codexImportOpenPanel: resolvedCodexImportOpenPanelAction,
            codexExportSavePanel: resolvedCodexExportSavePanelAction,
            codexImportExportArchive: resolvedCodexImportExportArchiveAction,
            geminiTokenTrendFetch: resolvedGeminiTokenTrendFetchAction
        )
        self.updateSupportedModes()
        self.configureCodexAuthReloadPipeline()
        self.configureCodexSQLiteObservationIfNeeded()
        let watcher = UsageMonitorFileWatcher { [weak self] change in
            Task { await self?.handleUsageFileChange(change) }
        }
        self.usageWatcher = watcher
    }

    deinit {
        copyToastTask?.cancel()
        codexAuthReloadSignalCancellable?.cancel()
        codexSQLiteObservationCancellable?.cancel()
        codexReloadTask?.cancel()
        codexHeaderRefreshTask?.cancel()
        let watcher = usageWatcher
        Task { @MainActor in
            watcher?.stop()
        }
    }

    enum TokenTrendRange: String, CaseIterable, Identifiable {
        case days1
        case days7
        case days30
        case all

        var id: String { rawValue }

        var title: String {
            switch self {
            case .days1:
                return NSLocalizedString("codex.usage.range.1d", value: "1D", comment: "Codex usage trend range 1 day")
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
            case .days1: 1
            case .days7: 7
            case .days30: 30
            case .all: nil
            }
        }
    }

    func updateSettings(_ newSettings: UsageMonitorProviderSettings) {
        settings = newSettings
        codexHideZeroQuotaAccounts = newSettings.codexHideZeroQuotaAccounts
        codexHideErroredAccounts = newSettings.codexHideErroredAccounts
        accountLayoutMode = newSettings.codexUseListLayout ? .list : .cards
        settingsStore.update(settings: newSettings, for: provider)
    }

    func setCodexHideZeroQuotaAccounts(_ hidden: Bool) {
        guard codexHideZeroQuotaAccounts != hidden || settings.codexHideZeroQuotaAccounts != hidden else { return }
        var updated = settings
        updated.codexHideZeroQuotaAccounts = hidden
        updateSettings(updated)
    }

    func setCodexHideErroredAccounts(_ hidden: Bool) {
        guard codexHideErroredAccounts != hidden || settings.codexHideErroredAccounts != hidden else { return }
        var updated = settings
        updated.codexHideErroredAccounts = hidden
        updateSettings(updated)
    }

    func setAccountLayoutMode(_ mode: UsageAccountLayoutMode) {
        let useListLayout = mode == .list
        guard accountLayoutMode != mode || settings.codexUseListLayout != useListLayout else { return }
        var updated = settings
        updated.codexUseListLayout = useListLayout
        updateSettings(updated)
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
        if usageProvider == .codex {
            configureCodexSQLiteObservationIfNeeded()
        }

        didStartInitialLoad = true
        isLoading = true
        defer { isLoading = false }
        let trendRefreshTask: Task<Void, Never>? = if usageProvider == .codex || usageProvider == .gemini {
            Task { [weak self] in
                await self?.refreshTokenTrend()
            }
        } else {
            nil
        }

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

        if usageProvider == .claude {
            await reloadClaudeAccountsState()
        }
        if usageProvider == .gemini || usageProvider == .antigravity {
            await reloadGeminiAccountsState(for: usageProvider)
        }

        guard usageProvider == .codex || usageProvider == .gemini else {
            await updateUsageFileWatcher()
            return
        }

        guard usageProvider == .codex else {
            await trendRefreshTask?.value
            await updateUsageFileWatcher()
            return
        }
        do {
            codexAuthFilePath = await codexAuthManager.authFile(for: provider)?.url.path
            currentCodexAuthHashHex = await codexAuthManager.currentAuthHashHex(for: provider)

            let loadedAccounts = try await codexAuthManager.loadAccounts()

            guard isMultiAccountEnabled else {
                if let outcome = outcomes.first(where: { outcome in
                    guard case .default = outcome.account else { return false }
                    return true
                }) {
                    let merged = await mergeCachedCodexUsageIfNeeded(outcome: outcome, accounts: loadedAccounts)
                    outcomes = outcomes.map { item in
                        item.id == outcome.id ? merged : item
                    }
                    await persistCurrentCodexOutcomeIfPossible(outcome: merged, accounts: loadedAccounts)
                }
                resetCodexMultiAccountState()
                await trendRefreshTask?.value
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

        await trendRefreshTask?.value
        await loadCodexManagementStatus()
        await updateUsageFileWatcher()
    }

    private func reloadClaudeAccountsState() async {
        do {
            let accounts = try await claudeAccountManager.loadAccounts()
            let activeID = try await claudeAccountManager.activeAccountID()
            activeClaudeAccountId = activeID
            claudeAccounts = accounts.sorted { lhs, rhs in
                let lhsActive = lhs.id == activeID
                let rhsActive = rhs.id == activeID
                if lhsActive != rhsActive { return lhsActive }
                return lhs.updatedAt > rhs.updatedAt
            }
        } catch {
            Self.logger.error("Failed to load claude accounts: \(String(describing: error), privacy: .public)")
            activeClaudeAccountId = nil
            claudeAccounts = []
        }
    }

    private func reloadGeminiAccountsState(for usageProvider: UsageProvider) async {
        do {
            let accounts = try await geminiAuthStore.listAccounts(provider: usageProvider)
            let activeID = try await geminiAuthStore.activeAccount(provider: usageProvider)?.id
            activeGeminiAccountId = activeID
            geminiAccounts = accounts.sorted { lhs, rhs in
                let lhsActive = lhs.id == activeID
                let rhsActive = rhs.id == activeID
                if lhsActive != rhsActive { return lhsActive }
                return lhs.createdAt > rhs.createdAt
            }
        } catch {
            Self.logger.error("Failed to load gemini accounts: \(String(describing: error), privacy: .public)")
            activeGeminiAccountId = nil
            geminiAccounts = []
        }
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

            let targets = orderedAccounts(activeId: activeCodexAccountId)
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
            codexAccounts = filterGatewayVirtualCodexAccounts(loadedAccounts)
            reconcileCodexSelections()
            reconcileGatewayCardsWithCurrentAccounts()
            codexAccountSummaries = loadCodexAccountSummaries(accounts: codexAccounts)
            codexAccountCustomGroupNames = (try? await codexAuthManager.loadCustomGroupNamesByAccountID()) ?? [:]
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

    private func configureCodexSQLiteObservationIfNeeded() {
        guard usageProvider == .codex else {
            codexSQLiteObservationCancellable?.cancel()
            codexSQLiteObservationCancellable = nil
            codexSQLiteObservationDatabaseQueue = nil
            codexSQLiteObservationLastSnapshot = nil
            return
        }
        guard codexSQLiteObservationCancellable == nil else { return }

        let dbURL = codexAuthManager.accountsSQLiteFile().url
        guard FileManager.default.fileExists(atPath: dbURL.path) else {
            Self.logger.debug("Skipped GRDB sqlite observation because db does not exist yet. path=\(dbURL.path, privacy: .public)")
            return
        }

        do {
            var configuration = Configuration()
            configuration.readonly = true
            let dbQueue = try DatabaseQueue(path: dbURL.path, configuration: configuration)
            codexSQLiteObservationDatabaseQueue = dbQueue

            let observation = ValueObservation.tracking { db -> CodexSQLiteObservationSnapshot in
                let accountsCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM codex_accounts;") ?? 0
                let credentialsCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM codex_account_credentials;") ?? 0
                let metadataCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM codex_account_metadata;") ?? 0
                let activeCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM codex_active_accounts;") ?? 0
                return CodexSQLiteObservationSnapshot(
                    accountsCount: accountsCount,
                    credentialsCount: credentialsCount,
                    metadataCount: metadataCount,
                    activeCount: activeCount
                )
            }

            codexSQLiteObservationCancellable = observation.start(
                in: dbQueue,
                scheduling: .immediate,
                onError: { [weak self] error in
                    Self.logger.error("GRDB sqlite observation failed: \(String(describing: error), privacy: .public)")
                    Task { @MainActor [weak self] in
                        self?.codexSQLiteObservationCancellable?.cancel()
                        self?.codexSQLiteObservationCancellable = nil
                        self?.codexSQLiteObservationDatabaseQueue = nil
                        self?.codexSQLiteObservationLastSnapshot = nil
                    }
                },
                onChange: { [weak self] snapshot in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        if self.codexSQLiteObservationLastSnapshot == nil {
                            self.codexSQLiteObservationLastSnapshot = snapshot
                            return
                        }
                        guard self.codexSQLiteObservationLastSnapshot != snapshot else { return }
                        self.codexSQLiteObservationLastSnapshot = snapshot
                        Self.logger.debug(
                            "GRDB sqlite change detected. accounts=\(snapshot.accountsCount, privacy: .public) credentials=\(snapshot.credentialsCount, privacy: .public) metadata=\(snapshot.metadataCount, privacy: .public) active=\(snapshot.activeCount, privacy: .public)"
                        )
                        self.enqueueCodexReload(refreshUsage: false, reason: "grdb_sqlite_observation")
                    }
                }
            )
            Self.logger.info("Started GRDB sqlite observation for codex accounts. db=\(dbURL.path, privacy: .public)")
        } catch {
            Self.logger.error("Failed to start GRDB sqlite observation: \(String(describing: error), privacy: .public)")
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
        codexAccounts = filterGatewayVirtualCodexAccounts(accounts)
        reconcileCodexSelections()
        reconcileGatewayCardsWithCurrentAccounts()
        codexAccountSummaries = loadCodexAccountSummaries(accounts: codexAccounts)
        codexAccountCustomGroupNames = (try? await codexAuthManager.loadCustomGroupNamesByAccountID()) ?? [:]
        activeCodexAccountId = await codexAuthManager.activeAccountId(for: provider)
        codexAccountOutcomes = await loadCachedCodexAccountOutcomes(accounts: codexAccounts)
        reorderCodexAccountOutcomesForDisplay()
    }

    private func filterGatewayVirtualCodexAccounts(_ accounts: [CodexAuthAccount]) -> [CodexAuthAccount] {
        accounts.filter { account in
            let data = codexAuthManager.accountAuthData(for: account)
            return !Self.isGatewayVirtualCodexAccount(
                relativeAuthPath: account.relativeAuthPath,
                authData: data
            )
        }
    }

    static func isGatewayVirtualCodexAccount(relativeAuthPath: String, authData: Data?) -> Bool {
        let normalizedPath = relativeAuthPath.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalizedPath.hasPrefix("gateway/virtual-auth/") || normalizedPath.contains("/__gateway_reply__-") {
            return true
        }
        guard let authData,
              let object = try? JSONSerialization.jsonObject(with: authData) as? [String: Any]
        else {
            return false
        }
        if let apiKey = object["OPENAI_API_KEY"] as? String {
            let normalizedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if normalizedAPIKey == "nolon-gateway-virtual-api-key" {
                return true
            }
        }
        guard let nolon = object["nolon"] as? [String: Any],
              let relay = nolon["relay"] as? [String: Any],
              let params = relay["query_params"] as? [String: Any]
        else {
            return false
        }
        return (params["nolon_gateway_virtual"] as? String) == "1"
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
                costWindowDays: settings.costWindowDays,
                codexHideZeroQuotaAccounts: settings.codexHideZeroQuotaAccounts,
                codexHideErroredAccounts: settings.codexHideErroredAccounts,
                codexUseListLayout: settings.codexUseListLayout))
        }
    }

    private static func mapToUsageProvider(_ provider: Provider) -> UsageProvider? {
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
        codexImportConnectionTestsTask?.cancel()
        codexImportConnectionTestsTask = nil
        importedAuthFileURL = nil
        importedAuthFileURLs = []
        codexImportGlobalErrorMessage = nil
        codexImportSearchText = ""
        codexImportCandidates = []
        codexImportDestinationOption = .managedSnapshots
        codexImportCustomGroupName = ""
        isTargetingCodexImportDropZone = false
        isRunningCodexImportValidation = false
        isRunningCodexImportConnectionTests = false
        isShowingCodexImportSheet = true
    }

    func dismissCodexImportSheet() {
        codexImportConnectionTestsTask?.cancel()
        codexImportConnectionTestsTask = nil
        isShowingCodexImportSheet = false
        isTargetingCodexImportDropZone = false
        isRunningCodexImportValidation = false
        isRunningCodexImportConnectionTests = false
        codexImportGlobalErrorMessage = nil
        codexImportSearchText = ""
        codexImportCandidates = []
        codexImportDestinationOption = .managedSnapshots
        codexImportCustomGroupName = ""
        importedAuthFileURL = nil
        importedAuthFileURLs = []
        pendingImportValidationResults = []
        importValidationSummaryMessage = nil
        isShowingImportValidationConfirm = false
    }

    func presentCodexImportFilePicker() async {
        importedAuthFileURL = nil
        importedAuthFileURLs = []
        let urls = codexImportOpenPanelAction()
        guard !urls.isEmpty else { return }
        await handleCodexImportURLs(urls)
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
        let trimmed = Self.trimmed(raw)
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

        codexImportConnectionTestsTask?.cancel()
        codexImportConnectionTestsTask = nil
        importedAuthFileURLs = urls
        codexImportGlobalErrorMessage = nil
        isRunningCodexImportValidation = true
        let results = await codexAuthManager.validateImportAuthFiles(urls: urls)
        isRunningCodexImportValidation = false

        mergeCodexImportCandidates(results: results)
        let pendingTestIDs: [UUID] = codexImportCandidates.compactMap { candidate -> UUID? in
            guard candidate.validation.isValid, candidate.testStatus != .success else { return nil }
            return candidate.id
        }
        guard !pendingTestIDs.isEmpty else { return }

        // Show validated list immediately, then fill usage details one by one in the background.
        codexImportConnectionTestsTask = Task { [weak self] in
            guard let self else { return }
            await self.runCodexImportConnectionTests(for: pendingTestIDs)
            self.codexImportConnectionTestsTask = nil
        }
    }

    func setCodexMultiSelectionEnabled(_ enabled: Bool) {
        isCodexMultiSelectionEnabled = enabled
        if !enabled {
            selectedCodexAccountIDs.removeAll()
        }
    }

    func toggleCodexAccountSelection(id: UUID) {
        guard isCodexMultiSelectionEnabled else { return }
        selectedCodexAccountIDs = GenericSelectionStateResolver.resolveMultiSelection(
            current: selectedCodexAccountIDs,
            tapped: id
        )
    }

    func isCodexAccountSelected(id: UUID?) -> Bool {
        guard let id else { return false }
        return selectedCodexAccountIDs.contains(id)
    }

    func isCodexSectionFullySelected(_ section: CodexAccountDisplaySection) -> Bool {
        guard isCodexMultiSelectionEnabled else { return false }
        let sectionIDs = codexSectionAccountIDs(from: section.items)
        guard !sectionIDs.isEmpty else { return false }
        return sectionIDs.isSubset(of: selectedCodexAccountIDs)
    }

    func toggleCodexSectionSelection(_ section: CodexAccountDisplaySection) {
        guard isCodexMultiSelectionEnabled else { return }
        let sectionIDs = codexSectionAccountIDs(from: section.items)
        selectedCodexAccountIDs = GenericSelectionStateResolver.resolveBatchMultiSelection(
            current: selectedCodexAccountIDs,
            toggledValues: sectionIDs
        )
    }

    func codexSectionAccountIDs(from items: [ProviderAccountUsageOutcome]) -> Set<UUID> {
        Set(items.compactMap { outcome in
            guard case let .tokenAccount(account) = outcome.account else { return nil }
            return account.id
        })
    }

    @discardableResult
    func createGatewayCard(name: String) -> CodexGatewayCard? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var state = codexGatewayCardsStore.normalized(
            gatewayCardsState,
            validAccountIDs: Set(codexAccounts.map(\.id))
        )
        let card = CodexGatewayCard(name: trimmed)
        state.cards.append(card)
        state.lastUsedCardID = card.id
        updateGatewayCardsState(state)
        return card
    }

    func renameGatewayCard(cardID: UUID, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var state = codexGatewayCardsStore.normalized(
            gatewayCardsState,
            validAccountIDs: Set(codexAccounts.map(\.id))
        )
        guard let index = state.cards.firstIndex(where: { $0.id == cardID }) else { return }
        guard state.cards[index].name != trimmed else { return }
        state.cards[index].name = trimmed
        state.cards[index].updatedAt = Date()
        updateGatewayCardsState(state)
    }

    func deleteGatewayCard(cardID: UUID) {
        var state = codexGatewayCardsStore.normalized(
            gatewayCardsState,
            validAccountIDs: Set(codexAccounts.map(\.id))
        )
        let originalCount = state.cards.count
        state.cards.removeAll { $0.id == cardID }
        guard state.cards.count != originalCount else { return }
        if state.lastUsedCardID == cardID {
            state.lastUsedCardID = nil
        }
        updateGatewayCardsState(state)
    }

    func addAccountsToGatewayCard(accountIDs: [UUID], cardID: UUID) {
        let validAccountIDs = Set(codexAccounts.map(\.id))
        let uniqueValidTargets = accountIDs.filter { validAccountIDs.contains($0) }
        guard !uniqueValidTargets.isEmpty else { return }

        var state = codexGatewayCardsStore.normalized(
            gatewayCardsState,
            validAccountIDs: validAccountIDs
        )
        guard let index = state.cards.firstIndex(where: { $0.id == cardID }) else { return }

        var mergedMembers = state.cards[index].memberAccountIDs
        for id in uniqueValidTargets where !mergedMembers.contains(id) {
            mergedMembers.append(id)
        }

        guard mergedMembers != state.cards[index].memberAccountIDs else {
            state.lastUsedCardID = cardID
            updateGatewayCardsState(state)
            return
        }

        state.cards[index].memberAccountIDs = mergedMembers
        state.cards[index].updatedAt = Date()
        state.lastUsedCardID = cardID
        updateGatewayCardsState(state)
    }

    func removeAccountFromGatewayCard(accountID: UUID, cardID: UUID) {
        var state = codexGatewayCardsStore.normalized(
            gatewayCardsState,
            validAccountIDs: Set(codexAccounts.map(\.id))
        )
        guard let index = state.cards.firstIndex(where: { $0.id == cardID }) else { return }
        let originalCount = state.cards[index].memberAccountIDs.count
        state.cards[index].memberAccountIDs.removeAll { $0 == accountID }
        guard state.cards[index].memberAccountIDs.count != originalCount else { return }
        state.cards[index].updatedAt = Date()
        updateGatewayCardsState(state)
    }

    @discardableResult
    func activateGatewayCard(cardID: UUID) -> Bool {
        var state = codexGatewayCardsStore.normalized(
            gatewayCardsState,
            validAccountIDs: Set(codexAccounts.map(\.id))
        )
        guard let index = state.cards.firstIndex(where: { $0.id == cardID }) else { return false }
        let shouldPromptAddAccounts = state.cards[index].memberAccountIDs.isEmpty
        state.lastUsedCardID = cardID
        updateGatewayCardsState(state)
        return shouldPromptAddAccounts
    }

    func startGatewayForCardSelection(cardID: UUID) async {
        guard usageProvider == .codex else { return }
        var normalizedState = codexGatewayCardsStore.normalized(
            gatewayCardsState,
            validAccountIDs: Set(codexAccounts.map(\.id))
        )
        guard let card = normalizedState.cards.first(where: { $0.id == cardID }) else { return }
        if normalizedState.lastUsedCardID != cardID {
            normalizedState.lastUsedCardID = cardID
            updateGatewayCardsState(normalizedState)
        }
        guard !card.memberAccountIDs.isEmpty else { return }
        guard let gatewayProviderID = resolvedGatewayProviderIDForCLI() else { return }

        await withGatewaySwitchInProgress {
            do {
                try await codexGatewayStartAction(
                    gatewayProviderID,
                    Self.codexGatewayDefaultHost,
                    Self.codexGatewayDefaultPort
                )
                await ensureGatewayVirtualAccountActivatedForCurrentProviderIfNeeded()
                selectedCodexAccountIDs.removeAll()
                codexAuthReloadSignal.send()
            } catch let cliError as NolonCoreCLIError {
                guard gatewayCardsState.lastUsedCardID == cardID else { return }
                if case let .domainFailed(code, _) = cliError, code == "codex_gateway_already_running" {
                    do {
                        try await codexGatewayStopAction(gatewayProviderID)
                        try await codexGatewayStartAction(
                            gatewayProviderID,
                            Self.codexGatewayDefaultHost,
                            Self.codexGatewayDefaultPort
                        )
                        await ensureGatewayVirtualAccountActivatedForCurrentProviderIfNeeded()
                        selectedCodexAccountIDs.removeAll()
                        codexAuthReloadSignal.send()
                        return
                    } catch {
                        alertTitle = NSLocalizedString("codex.gateway.cards.title", value: "网关卡片", comment: "Gateway cards section title")
                        alertMessage = Self.errorSummaryText(error: error, maxLength: 220)
                        return
                    }
                }
                alertTitle = NSLocalizedString("codex.gateway.cards.title", value: "网关卡片", comment: "Gateway cards section title")
                alertMessage = Self.errorSummaryText(error: cliError, maxLength: 220)
            } catch {
                guard gatewayCardsState.lastUsedCardID == cardID else { return }
                alertTitle = NSLocalizedString("codex.gateway.cards.title", value: "网关卡片", comment: "Gateway cards section title")
                alertMessage = Self.errorSummaryText(error: error, maxLength: 220)
            }
        }
    }

    func clearActiveGatewayCardSelection() {
        var state = codexGatewayCardsStore.normalized(
            gatewayCardsState,
            validAccountIDs: Set(codexAccounts.map(\.id))
        )
        guard state.lastUsedCardID != nil else { return }
        state.lastUsedCardID = nil
        updateGatewayCardsState(state)
    }

    func gatewayMembers(for card: CodexGatewayCard) -> [CodexGatewayMemberDisplay] {
        let accountByID = Dictionary(uniqueKeysWithValues: codexAccounts.map { ($0.id, $0) })
        let summaryByID = codexAccountSummaries
        return card.memberAccountIDs.compactMap { id in
            guard let account = accountByID[id] else { return nil }
            let summary = summaryByID[id]
            let title = ProviderUsageAccountDisplayNameResolver.resolve(
                email: summary?.email,
                summaryAccountID: summary?.accountID,
                cardKind: summary?.cardKind?.rawValue,
                apiKeySuffix: summary?.apiKeySuffix,
                relayModelProvider: summary?.relayModelProvider,
                relayBaseURL: summary?.relayBaseURL,
                relativeAuthPath: account.relativeAuthPath,
                defaultName: account.name,
                accountID: id
            )
            let subtitle: String? = {
                guard let raw = summary?.email?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !raw.isEmpty
                else { return nil }
                return raw == title ? nil : raw
            }()
            let plan = summary?.plan?.trimmingCharacters(in: .whitespacesAndNewlines)
            return CodexGatewayMemberDisplay(
                id: id,
                title: title,
                subtitle: subtitle,
                plan: (plan?.isEmpty == false) ? plan : nil
            )
        }
    }

    func gatewayCandidateAccounts(for cardID: UUID) -> [CodexAuthAccount] {
        guard let card = gatewayCards.first(where: { $0.id == cardID }) else {
            return codexAccounts
        }
        let memberIDs = Set(card.memberAccountIDs)
        guard !memberIDs.isEmpty else { return codexAccounts }
        return codexAccounts.filter { !memberIDs.contains($0.id) }
    }

    func gatewayCandidateSections(for cardID: UUID) -> [CodexGatewayCandidateSection] {
        let candidates = gatewayCandidateAccounts(for: cardID)
        guard !candidates.isEmpty else { return [] }

        var grouped: [String: [CodexAuthAccount]] = [:]
        var titleByKey: [String: String] = [:]

        for account in candidates {
            let title = Self.codexGroupingTitle(account: account, summary: codexAccountSummaries[account.id])
            let key = title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            titleByKey[key] = title
            grouped[key, default: []].append(account)
        }

        return grouped
            .keys
            .sorted()
            .map { key in
                CodexGatewayCandidateSection(
                    id: key,
                    title: titleByKey[key] ?? key,
                    items: grouped[key] ?? []
                )
            }
    }

    func addSelectedToGatewayCard() {
        presentGatewayCardPicker(
            accountIDs: selectedCodexAccountIDsInDisplayOrder()
        )
    }

    func presentGatewayCardPicker(accountIDs: [UUID]) {
        let valid = Set(codexAccounts.map(\.id))
        let unique = orderedUniqueValidAccountIDs(accountIDs, validAccountIDs: valid)
        guard !unique.isEmpty, !gatewayCards.isEmpty else { return }
        pendingGatewaySelectionAccountIDs = unique
        isShowingGatewayCardPicker = true
    }

    func confirmAddPendingAccounts(to cardID: UUID) {
        addAccountsToGatewayCard(accountIDs: pendingGatewaySelectionAccountIDs, cardID: cardID)
        pendingGatewaySelectionAccountIDs = []
        isShowingGatewayCardPicker = false
    }

    func dismissGatewayCardPicker() {
        pendingGatewaySelectionAccountIDs = []
        isShowingGatewayCardPicker = false
    }

    private func loadCodexConfigEditorModelProviderOptions(current: String) -> [String] {
        guard codexModelPreferenceService.supports(provider: provider) else { return [] }
        var options = codexModelPreferenceService.loadVisibleModelSlugs(for: provider)
        let normalizedCurrent = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedCurrent.isEmpty && !options.contains(normalizedCurrent) {
            options.insert(normalizedCurrent, at: 0)
        }
        return options
    }

    func beginNewCodexAPIKeyAccount() {
        let draft = CodexConfigEditorDraft(
            mode: .newAPIKey,
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
        codexConfigEditorDraft = draft
        codexConfigEditorModelProviderOptions = loadCodexConfigEditorModelProviderOptions(
            current: draft.modelProvider
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

        let rawJSON: JSON? = {
            guard let data = codexAuthManager.accountAuthData(for: account) else { return nil }
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

        let draft = CodexConfigEditorDraft(
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
        codexConfigEditorDraft = draft
        codexConfigEditorModelProviderOptions = loadCodexConfigEditorModelProviderOptions(
            current: draft.modelProvider
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
        codexConfigEditorModelProviderOptions = []
        isShowingCodexConfigEditor = false
    }

    func saveCodexConfigEditor() async {
        guard let draft = codexConfigEditorDraft else { return }

        let apiKey = Self.trimmed(draft.apiKey)
        guard !apiKey.isEmpty else {
            codexConfigEditorErrorMessage = NSLocalizedString(
                "codex.accounts.config.error.api_key_required",
                value: "API Key is required.",
                comment: "Codex config missing API key"
            )
            return
        }

        let relay: CodexAuthManager.ConfiguredRelay?
        if draft.isRelay {
            let baseURL = Self.trimmed(draft.baseURL)
            guard !baseURL.isEmpty else {
                codexConfigEditorErrorMessage = NSLocalizedString(
                    "codex.accounts.config.error.relay_required",
                    value: "Relay requires Base URL.",
                    comment: "Codex relay required fields"
                )
                return
            }
            do {
                relay = try .init(
                    baseURL: baseURL,
                    modelProvider: Self.trimmed(draft.modelProvider),
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
            let preferredName = resolvedConfiguredAccountName(
                userInputName: draft.name,
                baseURLText: draft.baseURL,
                apiKey: apiKey,
                editingAccountID: {
                    if case let .edit(accountID) = draft.mode { return accountID }
                    return nil
                }()
            )
            switch draft.mode {
            case .newAPIKey:
                _ = try await codexAuthManager.addConfiguredAccount(
                    name: preferredName,
                    apiKey: apiKey,
                    relay: relay,
                    usageQuery: usageQuery
                )
            case let .edit(accountID):
                guard let account = codexAccounts.first(where: { $0.id == accountID }) else { return }
                try await codexAuthManager.updateConfiguredAccount(
                    account,
                    name: preferredName,
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

    private func resolvedConfiguredAccountName(
        userInputName: String,
        baseURLText: String,
        apiKey: String,
        editingAccountID: UUID?
    ) -> String {
        let explicitName = Self.trimmed(userInputName)
        if !explicitName.isEmpty {
            return explicitName
        }

        let baseURLHost = Self.hostFromBaseURLText(baseURLText) ?? "api.openai.com"
        let existingNames = Set(
            codexAccounts
                .filter { account in
                    if let editingAccountID {
                        return account.id != editingAccountID
                    }
                    return true
                }
                .map { Self.trimmed($0.name).lowercased() }
        )

        if !existingNames.contains(baseURLHost.lowercased()) {
            return baseURLHost
        }

        let suffix = Self.apiKeySuffix(apiKey)
        var candidate = "\(baseURLHost)-\(suffix)"
        var counter = 2
        while existingNames.contains(candidate.lowercased()) {
            candidate = "\(baseURLHost)-\(suffix)-\(counter)"
            counter += 1
        }
        return candidate
    }

    private static func hostFromBaseURLText(_ baseURLText: String) -> String? {
        let raw = trimmed(baseURLText)
        guard !raw.isEmpty else { return nil }
        guard let host = URL(string: raw)?.host else { return nil }
        let normalized = trimmed(host).lowercased()
        return normalized.isEmpty ? nil : normalized
    }

    private static func apiKeySuffix(_ apiKey: String) -> String {
        let normalized = trimmed(apiKey)
        guard normalized.count >= 4 else { return "key" }
        return String(normalized.suffix(4)).lowercased()
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
                    domain: "ProviderUsageEngine.CodexUsageQuery",
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

    func validateCodexConnectionDraft() async {
        guard let draft = codexConfigEditorDraft else { return }

        let apiKey = Self.trimmed(draft.apiKey)
        guard !apiKey.isEmpty else {
            codexConfigEditorErrorMessage = NSLocalizedString(
                "codex.accounts.config.error.api_key_required",
                value: "API Key is required.",
                comment: "Codex config missing API key"
            )
            return
        }

        do {
            var authObject: [String: Any] = ["OPENAI_API_KEY": apiKey]
            if draft.isRelay {
                let baseURL = Self.trimmed(draft.baseURL)
                guard !baseURL.isEmpty else {
                    codexConfigEditorErrorMessage = NSLocalizedString(
                        "codex.accounts.config.error.relay_required",
                        value: "Relay requires Base URL.",
                        comment: "Codex relay required fields"
                    )
                    return
                }
                var relay: [String: Any] = ["base_url": baseURL]
                let modelProvider = Self.trimmed(draft.modelProvider)
                if !modelProvider.isEmpty {
                    relay["model_provider"] = modelProvider
                }
                let queryParams = try Self.parseKeyValueLines(draft.queryParamsText)
                if !queryParams.isEmpty {
                    relay["query_params"] = queryParams
                }
                let headers = try Self.parseKeyValueLines(draft.headersText)
                if !headers.isEmpty {
                    relay["headers"] = headers
                }
                authObject["nolon"] = ["relay": relay]
            }

            let authData = try JSONSerialization.data(withJSONObject: authObject, options: [])
            let target = try Self.resolveCodexValidationTarget(from: authData)
            let message = try await Self.executeCodexValidationRequest(target: target)
            alertTitle = NSLocalizedString("codex.accounts.action.validate", value: "Validate", comment: "Validate configured account")
            alertMessage = message
        } catch {
            codexConfigEditorErrorMessage = Self.errorSummaryText(error: error)
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

        if codexImportDestinationOption == .customSQLiteGroup,
           !Self.isNotBlank(codexImportCustomGroupName)
        {
            codexImportGlobalErrorMessage = NSLocalizedString(
                "codex.import.sheet.error.custom_group_required",
                value: "请先填写自定义分组名称。",
                comment: "Custom SQLite group name required"
            )
            return
        }

        let destination: CodexAuthManager.ImportDestination = {
            switch codexImportDestinationOption {
            case .managedSnapshots:
                return .managedSnapshots
            case .customSQLiteGroup:
                return .customSQLiteGroup(name: Self.trimmed(codexImportCustomGroupName))
            }
        }()

        do {
            _ = try await codexAuthManager.importValidatedAuthFiles(
                results: selectedResults,
                destination: destination
            )
            dismissCodexImportSheet()
            await load()
        } catch {
            codexImportGlobalErrorMessage = error.localizedDescription
        }
    }

    func exportSelectedCodexImportCandidatesAsZIP() async {
        guard canExportSelectedCodexImportCandidates else {
            alertTitle = NSLocalizedString("codex.import.sheet.title", value: "导入账号", comment: "Codex import sheet title")
            alertMessage = NSLocalizedString(
                "codex.import.sheet.export.error.none_selected",
                value: "请先选择至少一个可导出的账号。",
                comment: "No selected import candidates for export"
            )
            return
        }

        guard let destinationURL = codexExportSavePanelAction(.zip, Self.defaultCodexImportExportArchiveName()) else { return }
        let selectedResults = codexImportCandidates
            .filter { $0.validation.isValid && $0.isSelected }
            .map(\.validation)

        do {
            let exportedCount = try await codexImportExportArchiveAction(selectedResults, destinationURL)
            alertTitle = NSLocalizedString("codex.import.sheet.title", value: "导入账号", comment: "Codex import sheet title")
            alertMessage = String(
                format: NSLocalizedString(
                    "codex.import.sheet.export_zip.success",
                    value: "已导出 %d 个候选账号到 ZIP。",
                    comment: "Codex import ZIP export success"
                ),
                exportedCount
            )
        } catch {
            alertTitle = NSLocalizedString("codex.import.sheet.title", value: "导入账号", comment: "Codex import sheet title")
            alertMessage = error.localizedDescription
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

    func copyLoginURL() {
        guard let raw = loginURLForSheet?.absoluteString, !raw.isEmpty else { return }
        copyText(raw)
    }

    func copyErrorText(_ raw: String) {
        let trimmed = Self.trimmed(raw)
        guard Self.isNotBlank(raw) else { return }
        copyText(trimmed)
    }

    func copyCodexAccountPath(id: UUID) {
        guard let account = codexAccounts.first(where: { $0.id == id }) else { return }
        let file = codexAuthManager.accountAuthFile(relativeAuthPath: account.relativeAuthPath)
        copyText(file.url.path)
    }

    func copyCodexAccountAuthJSON(id: UUID) {
        guard let account = codexAccounts.first(where: { $0.id == id }) else { return }
        guard let data = codexAuthManager.accountAuthDataWithoutMaterialization(for: account),
              let raw = String(data: data, encoding: .utf8),
              Self.isNotBlank(raw)
        else { return }
        copyText(raw)
    }

    func editCodexAccountAuthJSON(id: UUID) {
        guard let account = codexAccounts.first(where: { $0.id == id }) else { return }
        let file = codexAuthManager.accountAuthFile(relativeAuthPath: account.relativeAuthPath)
        NSWorkspace.shared.open(file.url)
    }

    func copyText(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        showCopyToast()
    }

    func showCopyToast() {
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
        let detail = errorDetailText(error: error)
        return ProviderUsageErrorTextFormatter.summaryText(
            errorDetail: detail,
            isAuthFailure: CodexAuthFailureClassifier.isAuthFailure(errorText: detail),
            maxLength: maxLength
        )
    }

    static func errorDetailText(error: Error) -> String {
        ProviderUsageErrorTextFormatter.detailText(
            localizedDescription: error.localizedDescription,
            fallbackDescription: String(describing: error)
        )
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
            let message = Self.trimmed(error.localizedDescription)
            alertMessage = Self.isNotBlank(message) ? message : fallback
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

    func handleLoginURLSheetDismissed() {
        guard isRunningCLILogin else { return }
        cancelCLILoginIfNeeded()
    }

    func cleanupCLILoginArtifacts() {
        cliLoginHandle?.cancel()
        cliLoginHandle = nil
        geminiLoginHandle?.cancel()
        geminiLoginHandle = nil
        cliLoginHomeDir = nil
    }

    func finalizeCLILoginSessionIfNeeded(sessionId: UUID) {
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

    func resetCodexMultiAccountState() {
        codexAccounts = []
        codexAccountOutcomes = []
        codexAccountSummaries = [:]
        codexAccountCustomGroupNames = [:]
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
        dismissGatewayCardPicker()
        dismissCodexImportSheet()
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

    func runUnifiedLoginFlow(sessionId: UUID) async {
        defer {
            finalizeCLILoginSessionIfNeeded(sessionId: sessionId)
        }
        do {
            try await prepareGatewayModeForCLILoginIfNeeded()
            try await runAppServerLoginFlow(sessionId: sessionId)
            return
        } catch {
            guard cliLoginSessionId == sessionId else { return }
            Self.logger.error("App-server login failed. Falling back to direct CLI login. error=\(String(describing: error), privacy: .public)")
            await runCLILoginFlow(sessionId: sessionId, shouldFinalizeSession: false)
        }
    }

    func prepareGatewayModeForCLILoginIfNeeded() async throws {
        guard usageProvider == .codex else { return }
        guard gatewayCardsState.lastUsedCardID != nil else { return }
        clearActiveGatewayCardSelection()
        guard let gatewayProviderID = resolvedGatewayProviderIDForCLI() else { return }

        var capturedStopError: Error?
        await withGatewaySwitchInProgress {
            do {
                try await codexGatewayStopAction(gatewayProviderID)
            } catch {
                capturedStopError = error
            }
        }

        if let capturedStopError {
            throw capturedStopError
        }
        codexAuthReloadSignal.send()
    }

    func handleAppServerLoginFailure(_ error: Error) {
        alertTitle = NSLocalizedString("codex.cli_login.title", value: "CLI Login", comment: "CLI login title")
        alertMessage = error.localizedDescription
    }

    func runAppServerLoginFlow(sessionId: UUID) async throws {
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

    func runCLILoginFlow(sessionId: UUID, shouldFinalizeSession: Bool = true) async {
        defer {
            if shouldFinalizeSession {
                finalizeCLILoginSessionIfNeeded(sessionId: sessionId)
            }
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

    func schedulePostLoginReload(preferredBackfillAccount account: CodexAuthAccount? = nil) {
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

    func probeLoginSnapshotUsageAndBackfillEmailIfMissing(account: CodexAuthAccount) async -> ProviderAccountUsageOutcome {
        let authURL = codexAuthManager.accountAuthFile(relativeAuthPath: account.relativeAuthPath).url
        let outcome = await codexOutcomeFetchAction(account, settings, authURL)

        if case let .success(result) = outcome.outcome.result,
           let email = result.usage.identity?.accountEmail?.trimmingCharacters(in: .whitespacesAndNewlines),
           Self.isNotBlank(email)
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

    func activateCodexAccountImmediately(id: UUID) async {
        guard let account = codexAccounts.first(where: { $0.id == id }) else { return }
        pendingActivateCodexAccount = nil
        isShowingActivateConfirm = false
        await performCodexActivation(account)
    }

    func shouldActivateCodexAccountOnTap(id: UUID, hasActiveGatewayCardSelection: Bool) -> Bool {
        guard let account = codexAccounts.first(where: { $0.id == id }) else { return false }
        if hasActiveGatewayCardSelection { return true }
        return !isActiveCodexAccount(account)
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
        guard let activeCodexAccountId,
              let account = codexAccounts.first(where: { $0.id == activeCodexAccountId }),
              codexAccountSupportsEditing(accountID: activeCodexAccountId),
              !codexRefreshingAccountIds.contains(activeCodexAccountId)
        else {
            return
        }

        codexRefreshingAccountIds.insert(activeCodexAccountId)
        Task { [weak self] in
            guard let self else { return }
            defer { self.codexRefreshingAccountIds.remove(activeCodexAccountId) }

            do {
                let validationMessage = try await self.codexConfiguredAccountValidateAction(account)
                self.alertTitle = NSLocalizedString("codex.accounts.action.validate", value: "Validate", comment: "Validate configured account")
                self.alertMessage = validationMessage
            } catch {
                self.alertTitle = NSLocalizedString("codex.accounts.action.validate", value: "Validate", comment: "Validate configured account")
                self.alertMessage = Self.errorSummaryText(error: error)
            }
        }
    }

    func reconcileCodexSelections() {
        let validIDs = Set(codexAccounts.map(\.id))
        selectedCodexAccountIDs = selectedCodexAccountIDs.intersection(validIDs)
        if selectedCodexAccountIDs.isEmpty, !isCodexMultiSelectionEnabled {
            return
        }
        if validIDs.isEmpty {
            setCodexMultiSelectionEnabled(false)
        }
    }

    func orderedUniqueValidAccountIDs(_ accountIDs: [UUID], validAccountIDs: Set<UUID>) -> [UUID] {
        var seen: Set<UUID> = []
        var result: [UUID] = []
        for id in accountIDs {
            if !validAccountIDs.contains(id) { continue }
            if seen.contains(id) { continue }
            seen.insert(id)
            result.append(id)
        }
        return result
    }

    func selectedCodexAccountIDsInDisplayOrder() -> [UUID] {
        codexAccounts
            .map(\.id)
            .filter { selectedCodexAccountIDs.contains($0) }
    }

    func updateGatewayCardsState(_ state: CodexGatewayCardsState) {
        let validAccountIDs = Set(codexAccounts.map(\.id))
        let normalized = codexGatewayCardsStore.normalized(state, validAccountIDs: validAccountIDs)
        gatewayCardsState = normalized
        codexGatewayCardsStore.save(normalized, for: provider, validAccountIDs: validAccountIDs)
    }

    func reconcileGatewayCardsWithCurrentAccounts() {
        let validAccountIDs = Set(codexAccounts.map(\.id))
        let normalized = codexGatewayCardsStore.normalized(
            gatewayCardsState,
            validAccountIDs: validAccountIDs
        )
        if gatewayCardsState != normalized {
            gatewayCardsState = normalized
            codexGatewayCardsStore.save(normalized, for: provider, validAccountIDs: validAccountIDs)
        }
    }

    func isCodexSectionCollapsed(_ sectionID: String) -> Bool {
        collapsedCodexSectionIDs.contains(sectionID)
    }

    func toggleCodexSection(_ sectionID: String) {
        collapsedCodexSectionIDs = GenericSelectionStateResolver.resolveMultiSelection(
            current: collapsedCodexSectionIDs,
            tapped: sectionID
        )
    }

    func toggleGatewayCardsSectionCollapsed() {
        isGatewayCardsSectionCollapsed = GenericSelectionStateResolver.resolveBooleanToggle(
            current: isGatewayCardsSectionCollapsed
        )
    }

    func selectCodexSortOption(_ option: CodexAccountSortOption) {
        let next = GenericSelectionStateResolver.resolveSortSelection(
            currentKey: codexAccountSortOption,
            currentAscending: codexCurrentSortDirection == .ascending,
            tappedKey: option,
            defaultAscendingForTappedKey: Self.defaultCodexSortDirection(for: option) == .ascending
        )
        codexAccountSortOption = next.key
        codexCurrentSortDirection = next.ascending ? .ascending : .descending
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

    static func defaultCodexExportArchiveName(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "codex-accounts-\(formatter.string(from: now)).zip"
    }

    static func defaultCodexImportExportArchiveName(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "codex-import-\(formatter.string(from: now)).zip"
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
        await performCodexActivation(account)
    }

    func performCodexActivation(_ account: CodexAuthAccount) async {
        do {
            clearActiveGatewayCardSelection()
            if let gatewayProviderID = resolvedGatewayProviderIDForCLI() {
                try await codexGatewayStopAction(gatewayProviderID)
            }
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

    func resolvedGatewayProviderIDForCLI() -> String? {
        guard usageProvider == .codex else { return nil }
        return "codex"
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
            alertMessage = Self.isNotBlank(message) ? message : fallback
        }
    }

    func isActiveCodexAccount(_ account: CodexAuthAccount) -> Bool {
        if let activeCodexAccountId {
            return account.id == activeCodexAccountId
        }
        guard let currentCodexAuthHashHex else { return false }
        guard let data = codexAuthManager.accountAuthData(for: account),
              let raw = String(data: data, encoding: .utf8)
        else { return false }
        return CodexAuthAccount.hashHex(for: raw) == currentCodexAuthHashHex
    }

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

        let authURL = codexAuthManager.accountAuthFile(relativeAuthPath: account.relativeAuthPath).url
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

    func applyRefreshedCodexOutcome(_ outcome: ProviderAccountUsageOutcome, for account: CodexAuthAccount) async {
        let accountId = account.id
        lastUsageRefreshAt = Date()

        if case let .success(result) = outcome.outcome.result {
            replaceCodexOutcome(outcome, for: account.id)
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
                   Self.isNotBlank(email)
                {
                    if summary.email == nil {
                        _ = try? await codexAuthManager.backfillEmailIfMissing(for: account, email: email)
                    }
                    summary.email = email
                }
                if let plan = identity.plan?.trimmingCharacters(in: .whitespacesAndNewlines),
                   Self.isNotBlank(plan),
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

        let target = try resolveCodexValidationTarget(from: authData)
        return try await executeCodexValidationRequest(target: target, session: session)
    }

    nonisolated static func makeRandomCodexValidationInput() -> String {
        "nolon-connectivity-\(UUID().uuidString.lowercased())"
    }

    private nonisolated static func resolveCodexValidationTarget(from authData: Data) throws -> CodexValidationTarget {
        guard let object = try JSONSerialization.jsonObject(with: authData, options: []) as? [String: Any] else {
            throw NSError(
                domain: "ProviderUsageEngine.CodexValidate",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "auth.json is not a valid JSON object."]
            )
        }

        guard let apiKey = authStringValue(object["OPENAI_API_KEY"]) else {
            throw NSError(
                domain: "ProviderUsageEngine.CodexValidate",
                code: 5,
                userInfo: [NSLocalizedDescriptionKey: "OPENAI_API_KEY is missing in auth.json."]
            )
        }

        let relayObject = (object["nolon"] as? [String: Any])?["relay"] as? [String: Any]
        let relayBaseURLString = authStringValue(relayObject?["base_url"])
        let relayHeaders = authStringDictionary(relayObject?["headers"])
        let relayQueryParams = authStringDictionary(relayObject?["query_params"])

        let baseURL: URL
        if let relayBaseURLString {
            guard let relayURL = URL(string: relayBaseURLString) else {
                throw NSError(
                    domain: "ProviderUsageEngine.CodexValidate",
                    code: 6,
                    userInfo: [NSLocalizedDescriptionKey: "Relay base_url is invalid: \(relayBaseURLString)"]
                )
            }
            baseURL = relayURL
        } else {
            guard let officialURL = URL(string: codexOfficialAPIBaseURL) else {
                throw NSError(
                    domain: "ProviderUsageEngine.CodexValidate",
                    code: 7,
                    userInfo: [NSLocalizedDescriptionKey: "Official OpenAI base URL is invalid."]
                )
            }
            baseURL = officialURL
        }

        var headers = relayHeaders
        headers["Authorization"] = "Bearer \(apiKey)"
        return CodexValidationTarget(
            baseURL: baseURL,
            headers: headers,
            queryParams: relayQueryParams
        )
    }

    private nonisolated static func codexValidationResponsesURL(baseURL: URL, queryParams: [String: String]) -> URL? {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        let segments = (components?.path ?? "")
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)

        let pathSegments: [String]
        if segments.last?.lowercased() == "v1" {
            pathSegments = segments + ["responses"]
        } else {
            pathSegments = segments + ["v1", "responses"]
        }
        components?.path = "/" + pathSegments.joined(separator: "/")

        if !queryParams.isEmpty {
            var queryItems = components?.queryItems ?? []
            for key in queryParams.keys {
                queryItems.removeAll { $0.name == key }
            }
            for (key, value) in queryParams.sorted(by: { $0.key < $1.key }) {
                queryItems.append(URLQueryItem(name: key, value: value))
            }
            components?.queryItems = queryItems
        }

        return components?.url
    }

    private nonisolated static func executeCodexValidationRequest(
        target: CodexValidationTarget,
        session: URLSession = .shared
    ) async throws -> String {
        guard let requestURL = codexValidationResponsesURL(baseURL: target.baseURL, queryParams: target.queryParams) else {
            throw NSError(
                domain: "ProviderUsageEngine.CodexValidate",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Unable to build /v1/responses URL."]
            )
        }

        let randomInput = makeRandomCodexValidationInput()
        let requestBody: [String: Any] = [
            "model": "gpt-4.1-mini",
            "input": randomInput,
            "max_output_tokens": 1
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: requestBody, options: [])

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.httpBody = bodyData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (header, value) in target.headers {
            request.setValue(value, forHTTPHeaderField: header)
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(
                domain: "ProviderUsageEngine.CodexValidate",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Received an invalid HTTP response."]
            )
        }

        if (200 ... 299).contains(httpResponse.statusCode) {
            return "Connected (\(httpResponse.statusCode)). Input: \(randomInput)"
        }

        let serverMessage = codexValidationServerMessage(from: data) ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
        throw NSError(
            domain: "ProviderUsageEngine.CodexValidate",
            code: httpResponse.statusCode,
            userInfo: [NSLocalizedDescriptionKey: "Validation failed (\(httpResponse.statusCode)): \(serverMessage). Input: \(randomInput)"]
        )
    }

    private nonisolated static func codexValidationServerMessage(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data, options: []) else { return nil }
        if let root = object as? [String: Any] {
            if let errorObject = root["error"] as? [String: Any],
               let message = authStringValue(errorObject["message"]) {
                return message
            }
            if let message = authStringValue(root["message"]) {
                return message
            }
        }
        if let text = String(data: data, encoding: .utf8) {
            let trimmedText = nonisolatedTrimmed(text)
            return trimmedText.isEmpty ? nil : trimmedText
        }
        return nil
    }

    private nonisolated static func authStringValue(_ value: Any?) -> String? {
        guard let raw = value as? String else { return nil }
        let normalized = nonisolatedTrimmed(raw)
        return normalized.isEmpty ? nil : normalized
    }

    private nonisolated static func authStringDictionary(_ value: Any?) -> [String: String] {
        guard let raw = value as? [String: Any] else { return [:] }
        var result: [String: String] = [:]
        for (key, value) in raw {
            if let normalized = authStringValue(value) {
                result[key] = normalized
            }
        }
        return result
    }

    private nonisolated static func nonisolatedTrimmed(_ string: String) -> String {
        string.trimmingCharacters(in: .whitespacesAndNewlines)
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
        let providerID = Self.canonicalCodexProviderID(for: provider)
        let codexHome = codexAuthManager.cliLoginCodexHomeFolder(providerID: providerID)
        _ = codexHome.createIfNotExists()
        try writeCLILoginConfig(codexHome: codexHome)
        try removeCLILoginAuthFileIfPresent(codexHome: codexHome)
        return codexHome.url.standardizedFileURL
    }

    static func canonicalCodexProviderID(for provider: Provider) -> String {
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
    static func isNotBlank(_ string: String) -> Bool {
        !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func trimmed(_ string: String) -> String {
        string.trimmingCharacters(in: .whitespacesAndNewlines)
    }

}
