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
final class ProviderUsageEngine: CopyToastPresenting {
    static let logger = Logger(subsystem: "com.nolon", category: "ProviderUsageEngine")
    static var codexInitialFullRefreshProviderIDs: Set<String> = []
    static let codexOfficialAPIBaseURL = "https://api.openai.com/v1"
    static let codexGatewayDefaultHost = "127.0.0.1"
    static let codexGatewayDefaultPort = 8080
    let usageMonitor: ProviderUsageMonitorService
    let codexTokenTrendService = CodexTokenTrendService()
    let codexModelPreferenceService: CodexModelPreferenceService
    let settingsStore = UsageMonitorSettingsStore.shared
    let codexGatewayCardsStore: CodexGatewayCardsStore
    let codexAuthManager: CodexAuthManager
    let claudeAccountManager = ClaudeAccountManager()
    let geminiAuthStore = GeminiAuthStore.shared
    let actions: ActionDependencies
    var codexActivateAction: CodexActivateAction { actions.codexActivate }
    var postActivationLoadAction: AsyncVoidAction? { actions.postActivationLoad }
    var codexDeleteAction: CodexDeleteAction? { actions.codexDelete }
    var postDeleteLoadAction: AsyncVoidAction? { actions.postDeleteLoad }
    var codexRefreshAllAction: CodexRefreshAllAction? { actions.codexRefreshAll }
    var codexPreflightAction: CodexPreflightAction? { actions.codexPreflight }
    var codexOutcomeFetchAction: CodexOutcomeFetchAction { actions.codexOutcomeFetch }
    var codexUsageQueryTestAction: CodexUsageQueryTestAction { actions.codexUsageQueryTest }
    var codexConfiguredAccountValidateAction: CodexConfiguredAccountValidateAction { actions.codexConfiguredAccountValidate }
    var codexImportConnectionTestAction: CodexImportConnectionTestAction { actions.codexImportConnectionTest }
    var codexGatewayStartAction: CodexGatewayStartAction { actions.codexGatewayStart }
    var codexGatewayStopAction: CodexGatewayStopAction { actions.codexGatewayStop }
    var codexImportOpenPanelAction: CodexImportOpenPanelAction { actions.codexImportOpenPanel }
    var codexExportSavePanelAction: CodexExportSavePanelAction { actions.codexExportSavePanel }
    var codexImportExportArchiveAction: CodexImportExportArchiveAction { actions.codexImportExportArchive }
    var geminiTokenTrendFetchAction: GeminiTokenTrendFetchAction { actions.geminiTokenTrendFetch }
    let usageSnapshotService = ProviderUsageSnapshotService()
    @ObservationIgnored var usageWatcher: UsageMonitorFileWatcher? = nil

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
    @ObservationIgnored var cliLoginHandle: CodexLoginHandle?
    @ObservationIgnored var geminiLoginHandle: GeminiLoginHandle?
    @ObservationIgnored var cliLoginHomeDir: URL?

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
    var copyToastMessage = CopyToastSupport.message

    var cliLoginTask: Task<Void, Never>?
    var cliLoginSessionId: UUID?
    @ObservationIgnored var codexImportConnectionTestsTask: Task<Void, Never>?
    @ObservationIgnored var copyToastTask: Task<Void, Never>?
    @ObservationIgnored var codexAuthReloadSignalCancellable: AnyCancellable?
    @ObservationIgnored var codexReloadTask: Task<Void, Never>?
    @ObservationIgnored let codexAuthReloadSignal = PassthroughSubject<Void, Never>()
    @ObservationIgnored var codexSQLiteObservationDatabaseQueue: DatabaseQueue?
    @ObservationIgnored var codexSQLiteObservationCancellable: AnyDatabaseCancellable?
    @ObservationIgnored var codexSQLiteObservationLastSnapshot: CodexSQLiteObservationSnapshot?
    var codexReloadPending = false
    var codexReloadPendingRefreshUsage = false
    var codexUsageCacheWriteCount = 0
    var gatewaySwitchInProgressTokens: Set<UUID> = []
    var codexDiskReloadCountForTesting = 0
    var hasTriggeredAppearRefresh = false
    var didStartInitialLoad = false
    var lastUsageRefreshAt: Date?
    let cliLoginTimeoutSeconds: TimeInterval = 10 * 60
    let codexRefreshTimeoutGraceSeconds: TimeInterval
    @ObservationIgnored var codexHeaderRefreshTask: Task<Void, Never>?
    var codexHeaderRefreshSessionID: UUID?
    var isCodexHeaderRefreshing = false
    var nonCodexScheduledRefreshLastAt: Date?
    var codexScheduledRefreshLastAt: [UUID: Date] = [:]
    var codexScheduledRefreshFailureStreak: [UUID: Int] = [:]
    let refreshPolicyProfile: RefreshPolicyProfile = .balanced

    struct CodexSQLiteObservationSnapshot: Equatable {
        let accountsCount: Int
        let credentialsCount: Int
        let metadataCount: Int
        let activeCount: Int
    }

    enum RefreshPolicyProfile: Equatable {
        case balanced
    }

    struct RefreshDecision: Equatable {
        let shouldRefresh: Bool
        let nextEligibleAt: Date
        let reason: String
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
        self.codexAccountGroupingOption = Self.codexGroupingOption(
            rawValue: initialSettings.codexAccountGroupingOptionRawValue
        )
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
        codexAccountGroupingOption = Self.codexGroupingOption(
            rawValue: newSettings.codexAccountGroupingOptionRawValue
        )
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

    func setCodexAccountGroupingOption(_ option: CodexAccountGroupingOption) {
        guard
            codexAccountGroupingOption != option
                || settings.codexAccountGroupingOptionRawValue != option.rawValue
        else { return }
        var updated = settings
        updated.codexAccountGroupingOptionRawValue = option.rawValue
        updateSettings(updated)
    }

    static func codexGroupingOption(rawValue: String) -> CodexAccountGroupingOption {
        CodexAccountGroupingOption(rawValue: rawValue) ?? .typeInfo
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

    func reloadClaudeAccountsState() async {
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

    func reloadGeminiAccountsState(for usageProvider: UsageProvider) async {
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
        await performScheduledRefresh(now: Date())
    }

    func performScheduledRefresh(now: Date) async {
        guard !isLoading else { return }
        guard let usageProvider else { return }

        if usageProvider == .codex, isMultiAccountEnabled {
            if codexAccounts.isEmpty {
                await load()
                return
            }

            let targets = codexAccounts.filter { account in
                guard !shouldSkipRefresh(accountID: account.id, summaries: codexAccountSummaries) else {
                    return false
                }
                let decision = codexScheduledRefreshDecision(for: account, now: now)
                Self.logger.debug(
                    "Codex scheduled refresh decision. provider=\(self.provider.id, privacy: .public) account=\(account.id.uuidString, privacy: .public) should=\(decision.shouldRefresh, privacy: .public) reason=\(decision.reason, privacy: .public) next=\(decision.nextEligibleAt.timeIntervalSince1970, privacy: .public)"
                )
                return decision.shouldRefresh
            }

            guard !targets.isEmpty else { return }

            do {
                _ = try await runCodexPreflight(forceBackup: false, reason: "usage_auto_refresh")
            } catch {
                Self.logger.error("Codex preflight failed on auto refresh: \(String(describing: error), privacy: .public)")
            }

            await refreshCodexAccountsInParallel(targets)
            return
        }

        let decision = nonCodexScheduledRefreshDecision(now: now)
        Self.logger.debug(
            "Scheduled refresh decision. provider=\(self.provider.id, privacy: .public) should=\(decision.shouldRefresh, privacy: .public) reason=\(decision.reason, privacy: .public) next=\(decision.nextEligibleAt.timeIntervalSince1970, privacy: .public)"
        )
        guard decision.shouldRefresh else { return }
        await load()
        nonCodexScheduledRefreshLastAt = now
    }

    func scheduledRefreshPollInterval(now: Date) -> TimeInterval {
        let minPollInterval: TimeInterval = 1
        let maxPollInterval: TimeInterval = 60

        guard !isLoading else { return minPollInterval }
        guard let usageProvider else { return maxPollInterval }

        if usageProvider == .codex, isMultiAccountEnabled {
            guard !codexAccounts.isEmpty else { return maxPollInterval }

            var nearestWait: TimeInterval = maxPollInterval
            var hasCandidate = false
            for account in codexAccounts {
                if shouldSkipRefresh(accountID: account.id, summaries: codexAccountSummaries) {
                    continue
                }
                hasCandidate = true
                let decision = codexScheduledRefreshDecision(for: account, now: now)
                if decision.shouldRefresh {
                    return minPollInterval
                }
                let wait = max(minPollInterval, decision.nextEligibleAt.timeIntervalSince(now))
                nearestWait = min(nearestWait, wait)
            }
            guard hasCandidate else { return maxPollInterval }
            return min(maxPollInterval, max(minPollInterval, nearestWait))
        }

        let decision = nonCodexScheduledRefreshDecision(now: now)
        if decision.shouldRefresh {
            return minPollInterval
        }
        let wait = max(minPollInterval, decision.nextEligibleAt.timeIntervalSince(now))
        return min(maxPollInterval, max(minPollInterval, wait))
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

    func refreshTokenTrend() async {
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

    func updateUsageFileWatcher() async {
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

    func handleUsageFileChange(_ change: STPathChanged) async {
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

    func handleCodexUsageFileChange(_ change: STPathChanged) async {
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

    func reloadCodexFromDisk(refreshUsage: Bool) async {
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
            normalizeCodexGroupingOptionIfNeeded()
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

    func enqueueCodexReload(refreshUsage: Bool, reason: String) {
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

    func configureCodexAuthReloadPipeline() {
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

    func configureCodexSQLiteObservationIfNeeded() {
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
        codexAccounts = filterGatewayVirtualCodexAccounts(accounts)
        let validIDs = Set(codexAccounts.map(\.id))
        codexScheduledRefreshLastAt = codexScheduledRefreshLastAt.filter { validIDs.contains($0.key) }
        codexScheduledRefreshFailureStreak = codexScheduledRefreshFailureStreak.filter { validIDs.contains($0.key) }
        reconcileCodexSelections()
        reconcileGatewayCardsWithCurrentAccounts()
        codexAccountSummaries = loadCodexAccountSummaries(accounts: codexAccounts)
        codexAccountCustomGroupNames = (try? await codexAuthManager.loadCustomGroupNamesByAccountID()) ?? [:]
        normalizeCodexGroupingOptionIfNeeded()
        activeCodexAccountId = await codexAuthManager.activeAccountId(for: provider)
        codexAccountOutcomes = await loadCachedCodexAccountOutcomes(accounts: codexAccounts)
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

    func filterGatewayVirtualCodexAccounts(_ accounts: [CodexAuthAccount]) -> [CodexAuthAccount] {
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

    func loadCachedCodexAccountOutcomes(accounts: [CodexAuthAccount]) async -> [ProviderAccountUsageOutcome] {
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
                codexUseListLayout: settings.codexUseListLayout))
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
