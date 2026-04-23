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
    static let codexDefaultModelProvider = "nolon"
    let usageMonitor: ProviderUsageMonitorService
    let codexTokenTrendService: CodexTokenTrendService
    let codexModelPreferenceService: CodexModelPreferenceService
    let settingsStore = UsageMonitorSettingsStore.shared
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
    var codexImportOpenPanelAction: CodexImportOpenPanelAction { actions.codexImportOpenPanel }
    var codexExportSavePanelAction: CodexExportSavePanelAction { actions.codexExportSavePanel }
    var codexImportExportArchiveAction: CodexImportExportArchiveAction { actions.codexImportExportArchive }
    var codexCachedTokenTrendFetchAction: CodexCachedTokenTrendFetchAction { actions.codexCachedTokenTrendFetch }
    var codexTokenTrendFetchAction: CodexTokenTrendFetchAction { actions.codexTokenTrendFetch }
    var claudeTokenTrendFetchAction: ClaudeTokenTrendFetchAction { actions.claudeTokenTrendFetch }
    var geminiTokenTrendFetchAction: GeminiTokenTrendFetchAction { actions.geminiTokenTrendFetch }
    var providerIntradayFetchAction: ProviderIntradayFetchAction { actions.providerIntradayFetch }
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
    var tokenTrendRefreshStatus: ProviderTokenTrendRefreshStatusData?
    var tokenTrendErrorMessage: String?
    var isLoadingTokenTrend = false
    var tokenTrendCapability: ProviderUsageCurveCapability = .dailyOnly
    var selectedTokenTrendDayKey: String?
    var intradayBucket: ProviderIntradayBucket = .minute30
    var intradaySnapshot: ProviderIntradayUsageSnapshot?
    var intradayErrorMessage: String?
    var isLoadingIntraday = false
    @ObservationIgnored private var hasUserAdjustedIntradaySelection = false
    @ObservationIgnored private var codexTokenTrendPerformanceObserver: NSObjectProtocol?
    @ObservationIgnored private var activeTokenTrendRefreshTraceID: String?
    @ObservationIgnored private var latestIntradayRefreshRequestID: UUID?
    var shouldShowTokenTrendLoadingSkeleton: Bool {
        guard usageProvider == .codex || usageProvider == .claude || usageProvider == .gemini || usageProvider == .antigravity else { return false }
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
    var activatingCodexAccountId: UUID?
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
    var isSavingCodexConfigEditor = false
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
    var codexDiskReloadCountForTesting = 0
    var hasTriggeredAppearRefresh = false
    var didStartAccountsInitialLoad = false
    var didStartUsageInitialLoad = false
    var didStartInitialLoad: Bool {
        get { didStartAccountsInitialLoad }
        set { didStartAccountsInitialLoad = newValue }
    }
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
        let accountRowCount: Int
        let credentialsRowCount: Int
        let metadataRowCount: Int
        let activeRowCount: Int
        let accountsUpdatedAt: String?
        let metadataUpdatedAt: String?
        let activeUpdatedAt: String?
    }

    enum RefreshPolicyProfile: Equatable {
        case balanced
    }

    struct RefreshDecision: Equatable {
        let shouldRefresh: Bool
        let nextEligibleAt: Date
        let reason: String
    }

    struct PersistedCodexSyncFailureError: LocalizedError {
        let message: String

        var errorDescription: String? { message }
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
        codexImportOpenPanelAction: CodexImportOpenPanelAction? = nil,
        codexExportSavePanelAction: CodexExportSavePanelAction? = nil,
        codexImportExportArchiveAction: CodexImportExportArchiveAction? = nil,
        codexCachedTokenTrendFetchAction: CodexCachedTokenTrendFetchAction? = nil,
        codexTokenTrendFetchAction: CodexTokenTrendFetchAction? = nil,
        claudeTokenTrendFetchAction: ClaudeTokenTrendFetchAction? = nil,
        geminiTokenTrendFetchAction: GeminiTokenTrendFetchAction? = nil,
        providerIntradayFetchAction: ProviderIntradayFetchAction? = nil,
        postDeleteLoadAction: AsyncVoidAction? = nil,
        codexRefreshTimeoutGraceSeconds: TimeInterval = 5,
        initialSettingsOverride: UsageMonitorProviderSettings? = nil,
        codexModelPreferenceService: CodexModelPreferenceService = CodexModelPreferenceService()
    ) {
        let tokenStore = FileTokenAccountStore(fileURL: ProviderUsagePaths.defaultTokenAccountsFileURL())
        self.usageMonitor = usageMonitor ?? ProviderUsageMonitorService(tokenAccountStore: tokenStore)
        self.codexAuthManager = codexAuthManager
        self.provider = provider
        let resolvedCodexTokenTrendService = CodexTokenTrendService()
        self.codexTokenTrendService = resolvedCodexTokenTrendService
        self.codexModelPreferenceService = codexModelPreferenceService
        self.usageProvider = ProviderUsageEngine.mapToUsageProvider(provider)
        self.tokenTrendCapability = Self.tokenTrendCapability(for: self.usageProvider)
        self.codexRefreshTimeoutGraceSeconds = codexRefreshTimeoutGraceSeconds
        let initialSettings = initialSettingsOverride ?? settingsStore.settings(for: provider)
        self.settings = initialSettings
        self.codexHideZeroQuotaAccounts = initialSettings.codexHideZeroQuotaAccounts
        self.codexHideErroredAccounts = initialSettings.codexHideErroredAccounts
        self.accountLayoutMode = initialSettings.codexUseListLayout ? .list : .cards
        self.codexAccountGroupingOption = Self.codexGroupingOption(
            rawValue: initialSettings.codexAccountGroupingOptionRawValue
        )
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
        let resolvedCodexCachedTokenTrendFetchAction = codexCachedTokenTrendFetchAction ?? { trailingDays in
            resolvedCodexTokenTrendService.fetchCachedGlobalSnapshot(
                trailingDays: trailingDays,
                environment: ProcessInfo.processInfo.environment
            )
        }
        let resolvedCodexTokenTrendFetchAction = codexTokenTrendFetchAction ?? { trailingDays in
            try await resolvedCodexTokenTrendService.fetchRefreshedGlobalSnapshot(
                trailingDays: trailingDays,
                environment: ProcessInfo.processInfo.environment
            )
        }
        let resolvedClaudeTokenTrendFetchAction = claudeTokenTrendFetchAction ?? { trailingDays in
            try await ProviderUsageRegistry.fetchTokenTrendSnapshot(
                for: .claude,
                trailingDays: trailingDays
            )
        }
        let resolvedGeminiTokenTrendFetchAction = geminiTokenTrendFetchAction ?? { provider, trailingDays in
            try await GeminiTokenTrendService().fetchActiveSnapshot(provider: provider, trailingDays: trailingDays)
        }
        let resolvedProviderIntradayFetchAction = providerIntradayFetchAction ?? { provider, dayKey, bucket in
            switch provider {
            case .codex:
                return try await ProviderUsageRegistry.fetchIntradaySnapshot(
                    for: .codex,
                    dayKey: dayKey,
                    bucket: bucket,
                    environment: ProcessInfo.processInfo.environment
                )
            case .claude:
                return try await ProviderUsageRegistry.fetchIntradaySnapshot(
                    for: .claude,
                    dayKey: dayKey,
                    bucket: bucket
                )
            case .gemini, .antigravity:
                return try await ProviderUsageRegistry.fetchIntradaySnapshot(
                    for: provider,
                    dayKey: dayKey,
                    bucket: bucket
                )
            default:
                return nil
            }
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
            codexImportOpenPanel: resolvedCodexImportOpenPanelAction,
            codexExportSavePanel: resolvedCodexExportSavePanelAction,
            codexImportExportArchive: resolvedCodexImportExportArchiveAction,
            codexCachedTokenTrendFetch: resolvedCodexCachedTokenTrendFetchAction,
            codexTokenTrendFetch: resolvedCodexTokenTrendFetchAction,
            claudeTokenTrendFetch: resolvedClaudeTokenTrendFetchAction,
            geminiTokenTrendFetch: resolvedGeminiTokenTrendFetchAction,
            providerIntradayFetch: resolvedProviderIntradayFetchAction
        )
        self.updateSupportedModes()
        self.configureCodexAuthReloadPipeline()
        self.configureCodexSQLiteObservationIfNeeded()
        self.configureCodexTokenTrendDiagnosticsIfNeeded()
        let watcher = UsageMonitorFileWatcher { [weak self] change in
            Task { await self?.handleUsageFileChange(change) }
        }
        self.usageWatcher = watcher
    }

    deinit {
        copyToastTask?.cancel()
        codexAuthReloadSignalCancellable?.cancel()
        codexSQLiteObservationCancellable?.cancel()
        if let codexTokenTrendPerformanceObserver {
            NotificationCenter.default.removeObserver(codexTokenTrendPerformanceObserver)
        }
        codexReloadTask?.cancel()
        codexHeaderRefreshTask?.cancel()
        let watcher = usageWatcher
        Task { @MainActor in
            watcher?.stop()
        }
    }

    private func configureCodexTokenTrendDiagnosticsIfNeeded() {
        guard usageProvider == .codex else { return }
        guard codexTokenTrendPerformanceObserver == nil else { return }

        codexTokenTrendPerformanceObserver = NotificationCenter.default.addObserver(
            forName: CodexSessionStore.performanceNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated { [weak self] in
                self?.handleCodexTokenTrendPerformanceNotification(notification)
            }
        }
    }

    private func handleCodexTokenTrendPerformanceNotification(_ notification: Notification) {
        guard isLoadingTokenTrend else { return }
        guard let userInfo = notification.userInfo, matchesCodexStoreNotification(userInfo) else {
            return
        }
        guard let operation = userInfo["operation"] as? String,
              operation == "refresh_projected_usage_day_keys"
                || operation == "prepare_projected_usage_index"
        else {
            return
        }

        let traceID = (userInfo["trace_id"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let activeTokenTrendRefreshTraceID,
           let traceID,
           activeTokenTrendRefreshTraceID != traceID
        {
            return
        }
        if activeTokenTrendRefreshTraceID == nil,
           let traceID,
           !traceID.isEmpty
        {
            activeTokenTrendRefreshTraceID = traceID
        }

        tokenTrendRefreshStatus = Self.makeTokenTrendRefreshStatusData(from: userInfo)
    }

    private func matchesCodexStoreNotification(_ userInfo: [AnyHashable: Any]) -> Bool {
        guard let path = userInfo["codex_home_path"] as? String else { return false }
        let normalizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
        return normalizedPath == Self.resolveCodexHomePath(environment: ProcessInfo.processInfo.environment)
    }

    static func makeTokenTrendRefreshStatusData(
        from userInfo: [AnyHashable: Any]
    ) -> ProviderTokenTrendRefreshStatusData? {
        let operation = ((userInfo["operation"] as? String) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let isInitialBuild = operation == "prepare_projected_usage_index"
        let phase = ((userInfo["phase"] as? String) ?? "completed")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let detailPhase = ((userInfo["detail_phase"] as? String) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let scannedFileCount = integerValue(userInfo["scanned_file_count"])
        let cachedEntryCount = integerValue(userInfo["cached_entry_count"])
        let dirtyRolloutCount = integerValue(userInfo["dirty_rollout_count"])
        let processedRolloutCount = integerValue(userInfo["processed_rollout_count"])
        let refreshedLiveRolloutCount = integerValue(userInfo["refreshed_live_rollout_count"])
        let refreshedArchivedRolloutCount = integerValue(userInfo["refreshed_archived_rollout_count"])
        let skippedRolloutCount = integerValue(userInfo["skipped_rollout_count"])
        let removedRolloutCount = integerValue(userInfo["removed_rollout_count"])
        let affectedDayKeyCount = integerValue(userInfo["affected_day_key_count"])
        let currentRolloutPath = displayRolloutPath(userInfo["current_rollout_path"] as? String)
        let currentDatabaseName = displayDatabaseName(
            databaseName: userInfo["current_database_name"] as? String,
            databasePath: userInfo["current_database_path"] as? String
        )
        let refreshReasonDescription = localizedRefreshReason(
            rawValue: userInfo["current_refresh_reason"] as? String
        )

        switch phase {
        case "started":
            switch detailPhase {
            case "scan_inventory":
                return ProviderTokenTrendRefreshStatusData(
                    title: NSLocalizedString(
                        isInitialBuild
                            ? "usage.token_trend.prepare.scan_inventory.title"
                            : "usage.token_trend.refresh.scan_inventory.title",
                        value: isInitialBuild ? "正在扫描历史会话文件" : "正在扫描会话文件",
                        comment: "Codex token trend refresh scan inventory title"
                    ),
                    detail: NSLocalizedString(
                        isInitialBuild
                            ? "usage.token_trend.prepare.scan_inventory.detail"
                            : "usage.token_trend.refresh.scan_inventory.detail",
                        value: isInitialBuild
                            ? "正在遍历 sessions 与 archived_sessions，准备建立本地 minute 索引。"
                            : "正在遍历 sessions 与 archived_sessions，准备核对本地 rollout 清单。",
                        comment: "Codex token trend refresh scan inventory detail"
                    ),
                    progressLabel: nil,
                    fractionCompleted: nil
                )

            case "read_usage_index":
                let detail = String(
                    format: NSLocalizedString(
                        isInitialBuild
                            ? "usage.token_trend.prepare.read_usage_index.detail"
                            : "usage.token_trend.refresh.read_usage_index.detail",
                        value: isInitialBuild
                            ? "正在读取 %@，准备为 %d 个会话文件建立本地 minute 索引。"
                            : "正在读取 %@，准备比对 %d 个会话文件与本地 minute 索引。",
                        comment: "Codex token trend refresh read usage index detail"
                    ),
                    currentDatabaseName,
                    scannedFileCount
                )
                return ProviderTokenTrendRefreshStatusData(
                    title: NSLocalizedString(
                        "usage.token_trend.refresh.read_usage_index.title",
                        value: "正在读取用量索引数据库",
                        comment: "Codex token trend refresh read usage index title"
                    ),
                    detail: detail,
                    progressLabel: nil,
                    fractionCompleted: nil
                )

            case "reconcile_rollouts":
                let detail = String(
                    format: NSLocalizedString(
                        isInitialBuild
                            ? "usage.token_trend.prepare.reconcile_rollouts.detail"
                            : "usage.token_trend.refresh.reconcile_rollouts.detail",
                        value: isInitialBuild
                            ? "已扫描 %d 个会话文件，命中 %d 条缓存记录，准备建立 %d 个本地索引条目。"
                            : "已扫描 %d 个会话文件，命中 %d 条缓存记录，发现 %d 个待回填会话。",
                        comment: "Codex token trend refresh reconcile rollouts detail"
                    ),
                    scannedFileCount,
                    cachedEntryCount,
                    dirtyRolloutCount
                )
                return ProviderTokenTrendRefreshStatusData(
                    title: NSLocalizedString(
                        isInitialBuild
                            ? "usage.token_trend.prepare.reconcile_rollouts.title"
                            : "usage.token_trend.refresh.reconcile_rollouts.title",
                        value: isInitialBuild ? "正在准备建立索引" : "正在比对待刷新文件",
                        comment: "Codex token trend refresh reconcile rollouts title"
                    ),
                    detail: detail,
                    progressLabel: progressLabel(processed: 0, total: dirtyRolloutCount),
                    fractionCompleted: dirtyRolloutCount > 0 ? 0 : 1
                )

            default:
                break
            }
            let detail = String(
                format: NSLocalizedString(
                    isInitialBuild
                        ? "usage.token_trend.prepare.started.detail"
                        : "usage.token_trend.refresh.started.detail",
                    value: isInitialBuild
                        ? "已扫描 %d 个会话文件，命中 %d 条缓存记录，准备建立 %d 个本地索引条目。"
                        : "已扫描 %d 个会话文件，命中 %d 条缓存记录，发现 %d 个待回填会话。",
                    comment: "Codex token trend refresh started detail"
                ),
                scannedFileCount,
                cachedEntryCount,
                dirtyRolloutCount
            )
            return ProviderTokenTrendRefreshStatusData(
                title: NSLocalizedString(
                    isInitialBuild
                        ? "usage.token_trend.prepare.started.title"
                        : "usage.token_trend.refresh.started.title",
                    value: isInitialBuild ? "正在建立历史用量索引" : "正在扫描会话用量",
                    comment: "Codex token trend refresh started title"
                ),
                detail: detail,
                progressLabel: progressLabel(processed: 0, total: dirtyRolloutCount),
                fractionCompleted: dirtyRolloutCount > 0 ? 0 : 1
            )

        case "progress", "completed":
            let safeProcessedRolloutCount = phase == "completed"
                ? max(dirtyRolloutCount, processedRolloutCount)
                : processedRolloutCount

            switch detailPhase {
            case "read_previous_minutes":
                let detail = String(
                    format: NSLocalizedString(
                        "usage.token_trend.refresh.read_previous_minutes.detail",
                        value: "正在从 %@ 读取 %@ 的旧分钟桶，准备计算受影响日期。",
                        comment: "Codex token trend refresh read previous minutes detail"
                    ),
                    currentDatabaseName,
                    currentRolloutPath
                )
                return ProviderTokenTrendRefreshStatusData(
                    title: NSLocalizedString(
                        "usage.token_trend.refresh.read_previous_minutes.title",
                        value: "正在读取旧分钟索引",
                        comment: "Codex token trend refresh read previous minutes title"
                    ),
                    detail: detail,
                    progressLabel: progressLabel(
                        processed: safeProcessedRolloutCount,
                        total: dirtyRolloutCount
                    ),
                    fractionCompleted: progressFraction(
                        processed: safeProcessedRolloutCount,
                        total: dirtyRolloutCount
                    )
                )

            case "analyze_rollout":
                let detail: String
                if let refreshReasonDescription {
                    detail = String(
                        format: NSLocalizedString(
                            isInitialBuild
                                ? "usage.token_trend.prepare.analyze_rollout.detail_with_reason"
                                : "usage.token_trend.refresh.analyze_rollout.detail_with_reason",
                            value: isInitialBuild
                                ? "正在解析 %@ 并写入本地索引，原因：%@。"
                                : "正在解析 %@，原因：%@。",
                            comment: "Codex token trend refresh analyze rollout detail with reason"
                        ),
                        currentRolloutPath,
                        refreshReasonDescription
                    )
                } else {
                    detail = String(
                        format: NSLocalizedString(
                            isInitialBuild
                                ? "usage.token_trend.prepare.analyze_rollout.detail"
                                : "usage.token_trend.refresh.analyze_rollout.detail",
                            value: isInitialBuild
                                ? "正在解析 %@，并写入它的本地 minute 索引。"
                                : "正在解析 %@，并重算它的派生 minute 用量。",
                            comment: "Codex token trend refresh analyze rollout detail"
                        ),
                        currentRolloutPath
                    )
                }
                return ProviderTokenTrendRefreshStatusData(
                    title: NSLocalizedString(
                        isInitialBuild
                            ? "usage.token_trend.prepare.analyze_rollout.title"
                            : "usage.token_trend.refresh.analyze_rollout.title",
                        value: isInitialBuild ? "正在建立文件索引" : "正在分析会话文件",
                        comment: "Codex token trend refresh analyze rollout title"
                    ),
                    detail: detail,
                    progressLabel: progressLabel(
                        processed: safeProcessedRolloutCount,
                        total: dirtyRolloutCount
                    ),
                    fractionCompleted: progressFraction(
                        processed: safeProcessedRolloutCount,
                        total: dirtyRolloutCount
                    )
                )

            case "read_updated_minutes":
                let detail = String(
                    format: NSLocalizedString(
                        "usage.token_trend.refresh.read_updated_minutes.detail",
                        value: "正在从 %@ 回读 %@ 的最新分钟桶，准备更新受影响日期。",
                        comment: "Codex token trend refresh read updated minutes detail"
                    ),
                    currentDatabaseName,
                    currentRolloutPath
                )
                return ProviderTokenTrendRefreshStatusData(
                    title: NSLocalizedString(
                        "usage.token_trend.refresh.read_updated_minutes.title",
                        value: "正在回读刷新结果",
                        comment: "Codex token trend refresh read updated minutes title"
                    ),
                    detail: detail,
                    progressLabel: progressLabel(
                        processed: safeProcessedRolloutCount,
                        total: dirtyRolloutCount
                    ),
                    fractionCompleted: progressFraction(
                        processed: safeProcessedRolloutCount,
                        total: dirtyRolloutCount
                    )
                )

            case "purge_stale_entries":
                let detail = String(
                    format: NSLocalizedString(
                        "usage.token_trend.refresh.purge_stale_entries.detail",
                        value: "正在从 %@ 清理已删除 rollout 的旧 minute 索引。",
                        comment: "Codex token trend refresh purge stale entries detail"
                    ),
                    currentDatabaseName
                )
                return ProviderTokenTrendRefreshStatusData(
                    title: NSLocalizedString(
                        "usage.token_trend.refresh.purge_stale_entries.title",
                        value: "正在清理旧索引记录",
                        comment: "Codex token trend refresh purge stale entries title"
                    ),
                    detail: detail,
                    progressLabel: progressLabel(
                        processed: safeProcessedRolloutCount,
                        total: dirtyRolloutCount
                    ),
                    fractionCompleted: progressFraction(
                        processed: safeProcessedRolloutCount,
                        total: dirtyRolloutCount
                    )
                )

            default:
                break
            }

            var detailParts: [String] = [
                String(
                    format: NSLocalizedString(
                        "usage.token_trend.refresh.progress.refreshed",
                        value: "已刷新 live %d 个、archived %d 个",
                        comment: "Codex token trend refresh progress refreshed detail"
                    ),
                    refreshedLiveRolloutCount,
                    refreshedArchivedRolloutCount
                )
            ]
            if skippedRolloutCount > 0 {
                detailParts.append(
                    String(
                        format: NSLocalizedString(
                            "usage.token_trend.refresh.progress.skipped",
                            value: "跳过 %d 个",
                            comment: "Codex token trend refresh skipped rollouts detail"
                        ),
                        skippedRolloutCount
                    )
                )
            }
            if removedRolloutCount > 0 {
                detailParts.append(
                    String(
                        format: NSLocalizedString(
                            "usage.token_trend.refresh.progress.removed",
                            value: "待移除 %d 个旧 rollout",
                            comment: "Codex token trend refresh removed rollouts detail"
                        ),
                        removedRolloutCount
                    )
                )
            }
            if affectedDayKeyCount > 0 {
                detailParts.append(
                    String(
                        format: NSLocalizedString(
                            "usage.token_trend.refresh.progress.affected_days",
                            value: "当前影响 %d 天",
                            comment: "Codex token trend refresh affected days detail"
                        ),
                        affectedDayKeyCount
                    )
                )
            }
            if detailPhase == "rollout_completed", !currentRolloutPath.isEmpty {
                detailParts.append(
                    String(
                        format: NSLocalizedString(
                            "usage.token_trend.refresh.progress.latest_rollout",
                            value: "刚完成 %@",
                            comment: "Codex token trend refresh latest rollout detail"
                        ),
                        currentRolloutPath
                    )
                )
            }
            return ProviderTokenTrendRefreshStatusData(
                title: NSLocalizedString(
                    isInitialBuild
                        ? "usage.token_trend.prepare.progress.title"
                        : "usage.token_trend.refresh.progress.title",
                    value: isInitialBuild ? "正在建立派生用量索引" : "正在回填派生用量",
                    comment: "Codex token trend refresh progress title"
                ),
                detail: detailParts.joined(separator: "，") + "。",
                progressLabel: progressLabel(
                    processed: safeProcessedRolloutCount,
                    total: dirtyRolloutCount
                ),
                fractionCompleted: progressFraction(
                    processed: safeProcessedRolloutCount,
                    total: dirtyRolloutCount
                )
            )

        default:
            return nil
        }
    }

    private static func progressLabel(processed: Int, total: Int) -> String {
        guard total > 0 else {
            return NSLocalizedString(
                "usage.token_trend.refresh.progress.none",
                value: "无需回填",
                comment: "Codex token trend refresh no work needed"
            )
        }
        return "\(min(max(processed, 0), total)) / \(total)"
    }

    private static func progressFraction(processed: Int, total: Int) -> Double {
        guard total > 0 else { return 1 }
        let boundedProcessed = min(max(processed, 0), total)
        return Double(boundedProcessed) / Double(total)
    }

    private static func integerValue(_ value: Any?) -> Int {
        if let intValue = value as? Int {
            return intValue
        }
        if let number = value as? NSNumber {
            return number.intValue
        }
        return 0
    }

    private static func displayRolloutPath(_ value: String?) -> String {
        let normalizedValue = (value ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedValue.isEmpty else {
            return NSLocalizedString(
                "usage.token_trend.refresh.rollout.unknown",
                value: "当前 rollout",
                comment: "Codex token trend refresh unknown rollout label"
            )
        }

        let components = normalizedValue.split(separator: "/")
        guard components.count > 3 else { return normalizedValue }
        return components.suffix(3).joined(separator: "/")
    }

    private static func displayDatabaseName(
        databaseName: String?,
        databasePath: String?
    ) -> String {
        let normalizedName = (databaseName ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedName.isEmpty {
            return normalizedName
        }

        let normalizedPath = (databasePath ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedPath.isEmpty {
            return (normalizedPath as NSString).lastPathComponent
        }

        return NSLocalizedString(
            "usage.token_trend.refresh.database.unknown",
            value: "usage-index-v1.sqlite",
            comment: "Codex token trend refresh unknown database name"
        )
    }

    private static func localizedRefreshReason(rawValue: String?) -> String? {
        let normalizedValue = (rawValue ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalizedValue.isEmpty else { return nil }

        switch normalizedValue {
        case "new_rollout":
            return NSLocalizedString(
                "usage.token_trend.refresh.reason.new_rollout",
                value: "发现新 rollout",
                comment: "Codex token trend refresh reason new rollout"
            )
        case "live_fingerprint_changed":
            return NSLocalizedString(
                "usage.token_trend.refresh.reason.live_fingerprint_changed",
                value: "live rollout 指纹变化",
                comment: "Codex token trend refresh reason live fingerprint changed"
            )
        case "archived_hash_missing":
            return NSLocalizedString(
                "usage.token_trend.refresh.reason.archived_hash_missing",
                value: "archived rollout 缺少内容哈希",
                comment: "Codex token trend refresh reason archived hash missing"
            )
        case "archived_state_changed":
            return NSLocalizedString(
                "usage.token_trend.refresh.reason.archived_state_changed",
                value: "archived 状态发生变化",
                comment: "Codex token trend refresh reason archived state changed"
            )
        case "fingerprint_unavailable":
            return NSLocalizedString(
                "usage.token_trend.refresh.reason.fingerprint_unavailable",
                value: "无法读取文件指纹",
                comment: "Codex token trend refresh reason fingerprint unavailable"
            )
        default:
            return normalizedValue.replacingOccurrences(of: "_", with: " ")
        }
    }

    private static func resolveCodexHomePath(environment: [String: String]) -> String {
        if let override = environment["CODEX_HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !override.isEmpty
        {
            return URL(fileURLWithPath: override, isDirectory: true).standardizedFileURL.path
        }

        return URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            .appendingPathComponent(".codex", isDirectory: true)
            .standardizedFileURL
            .path
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

    static func tokenTrendCapability(for usageProvider: UsageProvider?) -> ProviderUsageCurveCapability {
        switch usageProvider {
        case .codex, .claude, .gemini, .antigravity:
            return .dailyWithIntradayDrilldown
        default:
            return .dailyOnly
        }
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
        guard !didStartAccountsInitialLoad else { return false }
        await hydrateCachedStateForInitialLoadIfNeeded()
        didStartAccountsInitialLoad = true
        await load()
        return true
    }

    @discardableResult
    func loadUsageIfNeeded() async -> Bool {
        guard tokenTrendCapability == .dailyWithIntradayDrilldown || usageProvider == .codex || usageProvider == .gemini else {
            return false
        }
        guard !didStartUsageInitialLoad else { return false }
        if usageProvider == .codex {
            tokenTrendSnapshot = codexCachedTokenTrendFetchAction(tokenTrendRange.trailingDays)
            let shouldRefreshIntraday = reconcileIntradayDrilldownSelection(
                with: tokenTrendSnapshot,
                allowAutomaticSelection: true
            )
            if shouldRefreshIntraday {
                refreshIntradayNow()
            }
        }
        didStartUsageInitialLoad = true
        await loadUsage()
        return true
    }

    func hydrateCachedStateForInitialLoadIfNeeded() async {
        guard usageProvider == .codex, isMultiAccountEnabled else { return }
        do {
            codexAuthFilePath = await codexAuthManager.authFile(for: provider)?.url.path
            currentCodexAuthHashHex = await codexAuthManager.currentAuthHashHex(for: provider)
            let loadedAccounts = try await codexAuthManager.loadAccounts()
            await applyCodexAccountsForDisplay(loadedAccounts)
        } catch {
            Self.logger.error("Failed to hydrate cached codex state before initial load: \(String(describing: error), privacy: .public)")
        }
    }

    func handleUsageViewAppear() async {
        // Tab switching should not implicitly refresh usage cards.
    }

    func load() async {
        guard let usageProvider else { return }
        if usageProvider == .codex {
            configureCodexSQLiteObservationIfNeeded()
        }

        didStartAccountsInitialLoad = true
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

        await loadCodexManagementStatus()
        await updateUsageFileWatcher()
    }

    func loadUsage() async {
        guard let usageProvider else { return }
        guard usageProvider == .codex || usageProvider == .claude || usageProvider == .gemini || usageProvider == .antigravity else { return }

        didStartUsageInitialLoad = true
        await refreshTokenTrend()
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
                await refreshCodexAccountsInParallel(targets, forceIncludeCredits: true)
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

    func selectTokenTrendDay(_ dayKey: String?) {
        guard tokenTrendCapability == .dailyWithIntradayDrilldown else { return }
        guard selectedTokenTrendDayKey != dayKey else { return }

        hasUserAdjustedIntradaySelection = true
        selectedTokenTrendDayKey = dayKey
        intradayErrorMessage = nil

        guard let dayKey else {
            intradaySnapshot = nil
            isLoadingIntraday = false
            latestIntradayRefreshRequestID = nil
            return
        }

        if intradaySnapshot?.dayKey != dayKey {
            intradaySnapshot = nil
        }
        refreshIntradayNow()
    }

    func setIntradayBucket(_ bucket: ProviderIntradayBucket) {
        guard intradayBucket != bucket else { return }
        intradayBucket = bucket
        guard selectedTokenTrendDayKey != nil else { return }
        refreshIntradayNow()
    }

    func refreshTokenTrendNow() {
        Task { [weak self] in
            await self?.refreshTokenTrend()
        }
    }

    func refreshIntradayNow() {
        Task { [weak self] in
            await self?.refreshIntraday()
        }
    }

    func refreshIntradayPanelNow() {
        Task { [weak self] in
            await self?.refreshIntradayPanel()
        }
    }

    func refreshTokenTrendForTesting() async {
        await refreshTokenTrend()
    }

    func refreshIntradayForTesting() async {
        await refreshIntraday()
    }

    func refreshIntradayPanelForTesting() async {
        await refreshIntradayPanel()
    }

    func refreshTokenTrend() async {
        guard let usageProvider else { return }
        guard usageProvider == .codex || usageProvider == .claude || usageProvider == .gemini || usageProvider == .antigravity else { return }

        let existingSnapshot = tokenTrendSnapshot
        if usageProvider == .codex {
            activeTokenTrendRefreshTraceID = nil
            tokenTrendRefreshStatus = ProviderTokenTrendRefreshStatusData(
                title: NSLocalizedString(
                    "usage.token_trend.refresh.preparing.title",
                    value: "正在准备刷新本地用量",
                    comment: "Codex token trend refresh preparing title"
                ),
                detail: NSLocalizedString(
                    "usage.token_trend.refresh.preparing.detail",
                    value: "正在读取缓存并核对会话派生用量，请稍候。",
                    comment: "Codex token trend refresh preparing detail"
                ),
                progressLabel: nil,
                fractionCompleted: nil
            )
        } else {
            tokenTrendRefreshStatus = nil
        }
        isLoadingTokenTrend = true
        tokenTrendErrorMessage = nil
        defer {
            isLoadingTokenTrend = false
            tokenTrendRefreshStatus = nil
            activeTokenTrendRefreshTraceID = nil
        }
        do {
            let snapshot: ProviderTokenTrendSnapshot?
            switch usageProvider {
            case .codex:
                snapshot = try await codexTokenTrendFetchAction(tokenTrendRange.trailingDays)
            case .claude:
                snapshot = try await claudeTokenTrendFetchAction(
                    tokenTrendRange.trailingDays
                )
            case .gemini, .antigravity:
                snapshot = try await geminiTokenTrendFetchAction(
                    usageProvider,
                    tokenTrendRange.trailingDays
                )
            default:
                snapshot = nil
            }
            tokenTrendSnapshot = snapshot
            let shouldRefreshIntraday = reconcileIntradayDrilldownSelection(
                with: snapshot,
                allowAutomaticSelection: true
            )
            if shouldRefreshIntraday {
                await refreshIntraday()
            }
        } catch {
            tokenTrendSnapshot = existingSnapshot
            tokenTrendErrorMessage = error.localizedDescription
        }
    }

    func refreshIntraday() async {
        guard let usageProvider else { return }
        guard tokenTrendCapability == .dailyWithIntradayDrilldown else { return }
        guard let dayKey = selectedTokenTrendDayKey else {
            intradaySnapshot = nil
            intradayErrorMessage = nil
            latestIntradayRefreshRequestID = nil
            return
        }

        let requestedBucket = intradayBucket
        let requestID = UUID()
        latestIntradayRefreshRequestID = requestID
        isLoadingIntraday = true
        intradayErrorMessage = nil
        defer {
            if latestIntradayRefreshRequestID == requestID {
                isLoadingIntraday = false
                latestIntradayRefreshRequestID = nil
            }
        }

        do {
            let snapshot = try await providerIntradayFetchAction(
                usageProvider,
                dayKey,
                requestedBucket
            )
            guard latestIntradayRefreshRequestID == requestID,
                  selectedTokenTrendDayKey == dayKey,
                  intradayBucket == requestedBucket
            else {
                return
            }
            intradaySnapshot = snapshot
        } catch {
            guard latestIntradayRefreshRequestID == requestID else { return }
            intradaySnapshot = nil
            intradayErrorMessage = error.localizedDescription
        }
    }

    private func refreshIntradayPanel() async {
        guard tokenTrendCapability == .dailyWithIntradayDrilldown,
              selectedTokenTrendDayKey != nil
        else {
            await refreshIntraday()
            return
        }

        await refreshTokenTrend()
    }

    @discardableResult
    private func reconcileIntradayDrilldownSelection(
        with snapshot: ProviderTokenTrendSnapshot?,
        allowAutomaticSelection: Bool
    ) -> Bool {
        guard tokenTrendCapability == .dailyWithIntradayDrilldown else {
            selectedTokenTrendDayKey = nil
            intradaySnapshot = nil
            intradayErrorMessage = nil
            latestIntradayRefreshRequestID = nil
            return false
        }

        let availableDayKeys = snapshot?.points.map(\.date) ?? []
        guard !availableDayKeys.isEmpty else {
            selectedTokenTrendDayKey = nil
            intradaySnapshot = nil
            intradayErrorMessage = nil
            latestIntradayRefreshRequestID = nil
            return false
        }

        if let selectedTokenTrendDayKey,
           availableDayKeys.contains(selectedTokenTrendDayKey) {
            return true
        }

        guard let fallbackDayKey = Self.preferredIntradayDayKey(from: availableDayKeys) else {
            selectedTokenTrendDayKey = nil
            intradaySnapshot = nil
            intradayErrorMessage = nil
            latestIntradayRefreshRequestID = nil
            return false
        }

        if selectedTokenTrendDayKey != nil {
            selectedTokenTrendDayKey = fallbackDayKey
            if intradaySnapshot?.dayKey != fallbackDayKey {
                intradaySnapshot = nil
            }
            intradayErrorMessage = nil
            return true
        }

        guard allowAutomaticSelection, !hasUserAdjustedIntradaySelection else {
            return false
        }

        selectedTokenTrendDayKey = fallbackDayKey
        if intradaySnapshot?.dayKey != fallbackDayKey {
            intradaySnapshot = nil
        }
        intradayErrorMessage = nil
        return true
    }

    private static func preferredIntradayDayKey(from availableDayKeys: [String]) -> String? {
        guard !availableDayKeys.isEmpty else { return nil }
        let todayKey = Self.dayKey(for: Date(), timezone: .current)
        if availableDayKeys.contains(todayKey) {
            return todayKey
        }
        return availableDayKeys.max()
    }

    private static func dayKey(for date: Date, timezone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar(timezone: timezone)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timezone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func calendar(timezone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        return calendar
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
                let sqlitePath = codexAuthManager.accountsSQLiteFile().url.path
                paths.append(URL(fileURLWithPath: sqlitePath).deletingLastPathComponent().path)
                paths.append(sqlitePath)
                paths.append(sqlitePath + "-wal")
                paths.append(sqlitePath + "-shm")
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
        let sqliteStorePath = codexAuthManager.accountsSQLiteFile().url.standardizedFileURL.path
        let sqliteFolderPath = URL(fileURLWithPath: sqliteStorePath).deletingLastPathComponent().path
        let sqliteFilePrefix = (sqliteStorePath as NSString).lastPathComponent

        let isAuthFolderChange = changedPath == authFolderPath || changedPath.hasPrefix(authFolderPath + "/")
        let isAuthFileChange: Bool = {
            guard let codexAuthFilePath else { return false }
            return changedPath == normalizedPath(codexAuthFilePath)
        }()
        let sqliteWALPath = sqliteStorePath + "-wal"
        let sqliteSHMPath = sqliteStorePath + "-shm"
        let isSQLiteStoreChange =
            changedPath == sqliteStorePath ||
            changedPath == sqliteWALPath ||
            changedPath == sqliteSHMPath ||
            (changedPath.hasPrefix(sqliteFolderPath + "/") &&
             (changedPath as NSString).lastPathComponent.hasPrefix(sqliteFilePrefix))

        Self.logger.debug(
            "Codex auth change. isAuthFolder=\(isAuthFolderChange, privacy: .public) isAuthFile=\(isAuthFileChange, privacy: .public) isSQLiteStore=\(isSQLiteStoreChange, privacy: .public) path=\(changedPath, privacy: .public)"
        )
        guard isAuthFolderChange || isAuthFileChange || isSQLiteStoreChange else { return }

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

            codexAccounts = try await codexAuthManager.loadAccounts()
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

            Self.logger.debug(
                "Codex disk reload complete. accounts=\(self.codexAccounts.count, privacy: .public) refreshUsage=\(refreshUsage, privacy: .public)"
            )
            if refreshUsage {
                await refreshCodexAccountsIfNeeded(
                    activeId: activeCodexAccountId,
                    summaries: codexAccountSummaries
                )
            }
            await updateUsageFileWatcher()
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
                let accountRowCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM codex_accounts;") ?? 0
                let credentialsRowCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM codex_account_credentials;") ?? 0
                let metadataRowCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM codex_account_metadata;") ?? 0
                let activeRowCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM codex_active_accounts;") ?? 0
                let accountsUpdatedAt = try String.fetchOne(db, sql: "SELECT MAX(updated_at) FROM codex_accounts;")
                let metadataUpdatedAt = try String.fetchOne(db, sql: "SELECT MAX(updated_at) FROM codex_account_metadata;")
                let activeUpdatedAt = try String.fetchOne(db, sql: "SELECT MAX(updated_at) FROM codex_active_accounts;")
                return CodexSQLiteObservationSnapshot(
                    accountRowCount: accountRowCount,
                    credentialsRowCount: credentialsRowCount,
                    metadataRowCount: metadataRowCount,
                    activeRowCount: activeRowCount,
                    accountsUpdatedAt: accountsUpdatedAt,
                    metadataUpdatedAt: metadataUpdatedAt,
                    activeUpdatedAt: activeUpdatedAt
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
                            "GRDB sqlite change detected. accounts=\(snapshot.accountRowCount, privacy: .public) credentials=\(snapshot.credentialsRowCount, privacy: .public) metadata=\(snapshot.metadataRowCount, privacy: .public) active=\(snapshot.activeRowCount, privacy: .public) metadataUpdatedAt=\(snapshot.metadataUpdatedAt ?? "-", privacy: .public)"
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

}
