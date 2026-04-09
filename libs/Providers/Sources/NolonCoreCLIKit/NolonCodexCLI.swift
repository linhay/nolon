import ArgumentParser
import CodexAppServerKit
import CodexCLIKit
import CodexGatewayKit
import CodexProvider
import Foundation
import ProviderCatalog
import ProviderUsage
import SKProcessRunner
import STFilePath
import Vapor
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public struct NolonLiveCodexCLIService: NolonCodexCLIServing {
    typealias AuthActivator = @Sendable (CodexAuthAccount, Provider) async throws -> CodexAuthActivationResult
    typealias AuthRefreshRunner = @Sendable (_ providerID: String, _ accountID: UUID, _ environment: [String: String]) async throws -> Void
    typealias UsageOutcomeFetcher = @Sendable (_ environment: [String: String]) async -> ProviderFetchOutcome
    typealias GatewayDetachedProcessStarter = @Sendable (_ executablePath: String, _ arguments: [String]) throws -> Int32
    typealias GatewayHealthChecker = @Sendable (_ host: String, _ port: Int) async -> Bool
    typealias GatewayExecutablePathProvider = @Sendable () -> String?

    private let authManager: CodexAuthManager
    private let binaryManager: CodexBinaryManager
    private let loginRunner: CodexLoginRunner
    private let environment: [String: String]
    private let authActivator: AuthActivator
    private let authRefreshRunner: AuthRefreshRunner
    private let usageOutcomeFetcher: UsageOutcomeFetcher
    private let runtimeProcessInspector: any NolonCodexRuntimeProcessInspecting
    private let runtimeSignalController: any NolonCodexRuntimeSignalControlling
    private let currentPIDProvider: @Sendable () -> Int32
    private let sleep: @Sendable (UInt64) async throws -> Void
    private let gatewayControlService: CodexGatewayControlService
    private let gatewayConfigManager: any CodexGatewayConfigManaging
    private let gatewayPIDStore: any CodexGatewayPIDStoring
    private let gatewayConfigFileResolver: @Sendable (Provider) -> STFile?
    private let gatewayDetachedProcessStarter: GatewayDetachedProcessStarter
    private let gatewayHealthChecker: GatewayHealthChecker
    private let gatewayExecutablePathProvider: GatewayExecutablePathProvider
    private let gatewayVirtualAccountStateStore: any CodexGatewayVirtualAccountStateStoring

    private struct UsageRefreshReport: Sendable {
        var refreshOrder: [UUID] = []
        var skippedAccountIDs: Set<UUID> = []
        var skippedReasons: [UUID: String] = [:]
        var failedAccountIDs: Set<UUID> = []
    }

    private static let gatewayVirtualMarkerKey = "nolon_gateway_virtual"
    private static let gatewayVirtualNamePrefix = "__gateway_reply__"
    private static let gatewayVirtualAPIKey = "nolon-gateway-virtual-api-key"
    private static let gatewayHealthCheckMaxAttempts = 120
    private static let gatewayHealthCheckSleepNanoseconds: UInt64 = 100_000_000
    private static let gatewayHealthCheckRequestTimeout: TimeInterval = 1.0
    private static let embeddedGatewayRuntime = EmbeddedGatewayRuntime()

    enum GatewayDaemonLaunchMode: Equatable {
        case detached(executablePath: String)
        case embedded
    }

    private struct EmbeddedGatewayHandle: Sendable {
        let token: UUID
        let providerID: String
        let task: Task<Void, Never>
    }

    private actor EmbeddedGatewayRuntime {
        private var handle: EmbeddedGatewayHandle?

        func start(providerID: String, operation: @escaping @Sendable () async -> Void) -> Bool {
            if let handle, !handle.task.isCancelled {
                return false
            }
            let token = UUID()
            let task = Task.detached(priority: .utility) {
                await operation()
                await NolonLiveCodexCLIService.embeddedGatewayRuntime.clearIfCurrent(token: token)
            }
            handle = EmbeddedGatewayHandle(token: token, providerID: providerID, task: task)
            return true
        }

        func stop(providerID: String) async {
            guard let handle, handle.providerID == providerID else { return }
            handle.task.cancel()
            _ = await handle.task.result
            if self.handle?.token == handle.token {
                self.handle = nil
            }
        }

        func isRunning(providerID: String) -> Bool {
            guard let handle, handle.providerID == providerID else { return false }
            return !handle.task.isCancelled
        }

        private func clearIfCurrent(token: UUID) {
            if handle?.token == token {
                handle = nil
            }
        }
    }

    public init(
        authManager: CodexAuthManager = CodexAuthManager(),
        binaryManager: CodexBinaryManager = .shared,
        loginRunner: CodexLoginRunner = .init(),
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.init(
            authManager: authManager,
            binaryManager: binaryManager,
            loginRunner: loginRunner,
            environment: environment,
            authActivator: { account, provider in
                try await CodexAuthActivationCoordinator.shared.activate(account: account, provider: provider)
            },
            authRefreshRunner: Self.liveAuthRefreshRunner,
            usageOutcomeFetcher: Self.liveUsageOutcomeFetcher,
            runtimeProcessInspector: NolonCodexRuntimeProcessInspector(),
            runtimeSignalController: NolonCodexRuntimeSignalController(),
            currentPIDProvider: { getpid() },
            sleep: { nanoseconds in
                try await Task.sleep(nanoseconds: nanoseconds)
            },
            gatewayControlService: CodexGatewayControlService(
                statusStore: CodexGatewayStateStore(authManager: authManager)
            ),
            gatewayConfigManager: CodexGatewayConfigManager(
                stateStore: CodexGatewayManagedConfigStateStore(authManager: authManager)
            ),
            gatewayPIDStore: CodexGatewayPIDStore(authManager: authManager),
            gatewayConfigFileResolver: { provider in
                Self.defaultGatewayConfigFile(for: provider, environment: environment)
            },
            gatewayDetachedProcessStarter: Self.startDetachedProcess,
            gatewayHealthChecker: Self.healthCheck,
            gatewayExecutablePathProvider: Self.resolveCurrentExecutablePath,
            gatewayVirtualAccountStateStore: CodexGatewayVirtualAccountStateStore(authManager: authManager)
        )
    }

    init(
        authManager: CodexAuthManager,
        binaryManager: CodexBinaryManager,
        loginRunner: CodexLoginRunner,
        environment: [String: String],
        authActivator: @escaping AuthActivator,
        authRefreshRunner: @escaping AuthRefreshRunner
    ) {
        self.init(
            authManager: authManager,
            binaryManager: binaryManager,
            loginRunner: loginRunner,
            environment: environment,
            authActivator: authActivator,
            authRefreshRunner: authRefreshRunner,
            usageOutcomeFetcher: Self.liveUsageOutcomeFetcher,
            runtimeProcessInspector: NolonCodexRuntimeProcessInspector(),
            runtimeSignalController: NolonCodexRuntimeSignalController(),
            currentPIDProvider: { getpid() },
            sleep: { nanoseconds in
                try await Task.sleep(nanoseconds: nanoseconds)
            },
            gatewayControlService: CodexGatewayControlService(
                statusStore: CodexGatewayStateStore(authManager: authManager)
            ),
            gatewayConfigManager: CodexGatewayConfigManager(
                stateStore: CodexGatewayManagedConfigStateStore(authManager: authManager)
            ),
            gatewayPIDStore: CodexGatewayPIDStore(authManager: authManager),
            gatewayConfigFileResolver: { provider in
                Self.defaultGatewayConfigFile(for: provider, environment: environment)
            },
            gatewayDetachedProcessStarter: Self.startDetachedProcess,
            gatewayHealthChecker: Self.healthCheck,
            gatewayExecutablePathProvider: Self.resolveCurrentExecutablePath,
            gatewayVirtualAccountStateStore: CodexGatewayVirtualAccountStateStore(authManager: authManager)
        )
    }

    init(
        authManager: CodexAuthManager,
        binaryManager: CodexBinaryManager,
        loginRunner: CodexLoginRunner,
        environment: [String: String],
        authActivator: @escaping AuthActivator = { account, provider in
            try await CodexAuthActivationCoordinator.shared.activate(account: account, provider: provider)
        },
        authRefreshRunner: @escaping AuthRefreshRunner = Self.liveAuthRefreshRunner,
        usageOutcomeFetcher: @escaping UsageOutcomeFetcher = Self.liveUsageOutcomeFetcher,
        runtimeProcessInspector: any NolonCodexRuntimeProcessInspecting,
        runtimeSignalController: any NolonCodexRuntimeSignalControlling,
        currentPIDProvider: @escaping @Sendable () -> Int32,
        sleep: @escaping @Sendable (UInt64) async throws -> Void,
        gatewayControlService: CodexGatewayControlService = CodexGatewayControlService(),
        gatewayConfigManager: any CodexGatewayConfigManaging = CodexGatewayConfigManager(),
        gatewayPIDStore: any CodexGatewayPIDStoring = CodexGatewayPIDStore(),
        gatewayConfigFileResolver: @escaping @Sendable (Provider) -> STFile? = { _ in nil },
        gatewayDetachedProcessStarter: @escaping GatewayDetachedProcessStarter = Self.startDetachedProcess,
        gatewayHealthChecker: @escaping GatewayHealthChecker = Self.healthCheck,
        gatewayExecutablePathProvider: @escaping GatewayExecutablePathProvider = Self.resolveCurrentExecutablePath,
        gatewayVirtualAccountStateStore: any CodexGatewayVirtualAccountStateStoring = CodexGatewayVirtualAccountStateStore()
    ) {
        self.authManager = authManager
        self.binaryManager = binaryManager
        self.loginRunner = loginRunner
        self.environment = environment
        self.authActivator = authActivator
        self.authRefreshRunner = authRefreshRunner
        self.usageOutcomeFetcher = usageOutcomeFetcher
        self.runtimeProcessInspector = runtimeProcessInspector
        self.runtimeSignalController = runtimeSignalController
        self.currentPIDProvider = currentPIDProvider
        self.sleep = sleep
        self.gatewayControlService = gatewayControlService
        self.gatewayConfigManager = gatewayConfigManager
        self.gatewayPIDStore = gatewayPIDStore
        self.gatewayConfigFileResolver = gatewayConfigFileResolver
        self.gatewayDetachedProcessStarter = gatewayDetachedProcessStarter
        self.gatewayHealthChecker = gatewayHealthChecker
        self.gatewayExecutablePathProvider = gatewayExecutablePathProvider
        self.gatewayVirtualAccountStateStore = gatewayVirtualAccountStateStore
    }

    public func authList(providerID: String) async throws -> NolonCodexAuthListPayload {
        let canonicalProviderID = try Self.canonicalProviderID(providerID)
        let provider = try Self.provider(for: canonicalProviderID)
        let accounts = try await authManager.loadAccounts()
        let activeID = await authManager.activeAccountId(for: provider)
        var views: [NolonCodexAuthAccountView] = []
        views.reserveCapacity(accounts.count)
        for account in accounts {
            let email = Self.loadEmail(for: account, authManager: authManager)
            let usageCache = try? await authManager.loadUsageCache(for: account)
            views.append(
                NolonCodexAuthAccountView(
                    id: account.id,
                    name: account.name,
                    createdAt: account.createdAt,
                    relativeAuthPath: account.relativeAuthPath,
                    isActive: account.id == activeID,
                    email: email,
                    usageDisplay: Self.makeUsageDisplay(from: usageCache),
                    refreshedAt: Self.resolveRefreshTime(from: usageCache)
                )
            )
        }
        return NolonCodexAuthListPayload(
            providerID: canonicalProviderID,
            activeAccountID: activeID,
            accounts: views
        )
    }

    public func authUsage(providerID: String) async throws -> NolonCodexAuthUsagePayload {
        try await buildAuthUsagePayload(providerID: providerID, refreshTargetAccountID: nil, refreshBeforeRead: false)
    }

    public func authUsageTrend(providerID: String, range: NolonCodexUsageTrendRange) async throws -> NolonCodexAuthUsageTrendPayload {
        let canonicalProviderID = try Self.canonicalProviderID(providerID)
        let trailingDays: Int? = switch range {
        case .days7: 7
        case .days30: 30
        case .all: nil
        }
        let snapshot = try await CodexTokenTrendService().fetchGlobalSnapshot(
            trailingDays: trailingDays,
            environment: environment
        )
        return NolonCodexAuthUsageTrendPayload(
            providerID: canonicalProviderID,
            range: range,
            sourceLabel: snapshot.sourceLabel,
            updatedAt: snapshot.updatedAt,
            points: snapshot.points.map { point in
                NolonCodexAuthUsageTrendPointView(
                    date: point.date,
                    totalTokens: point.totalTokens,
                    inputTokens: point.inputTokens,
                    outputTokens: point.outputTokens,
                    cacheReadTokens: point.cacheReadTokens
                )
            },
            summary: NolonCodexAuthUsageTrendSummaryView(
                todayTokens: snapshot.todayTokens,
                last7DaysTokens: snapshot.last7DaysTokens,
                last30DaysTokens: snapshot.last30DaysTokens
            )
        )
    }

    public func authUsageRefresh(providerID: String, accountID: UUID?) async throws -> NolonCodexAuthUsagePayload {
        try await buildAuthUsagePayload(providerID: providerID, refreshTargetAccountID: accountID, refreshBeforeRead: true)
    }

    private func buildAuthUsagePayload(
        providerID: String,
        refreshTargetAccountID: UUID?,
        refreshBeforeRead: Bool
    ) async throws -> NolonCodexAuthUsagePayload {
        let canonicalProviderID = try Self.canonicalProviderID(providerID)
        let provider = try Self.provider(for: canonicalProviderID)
        var accounts = try await authManager.loadAccounts()
        let refreshReport: UsageRefreshReport
        if refreshBeforeRead {
            refreshReport = try await refreshUsageCaches(
                provider: provider,
                accounts: accounts,
                targetAccountID: refreshTargetAccountID
            )
            // Reload account metadata after refresh attempt so sync-failure flags are current.
            accounts = try await authManager.loadAccounts()
        } else {
            refreshReport = UsageRefreshReport()
        }
        let activeID = await authManager.activeAccountId(for: provider)

        var views: [NolonCodexAuthUsageAccountView] = []
        views.reserveCapacity(accounts.count)

        for account in accounts {
            let email = Self.loadEmail(for: account, authManager: authManager)
            let usageCache: CodexAuthUsageCache?
            if refreshReport.failedAccountIDs.contains(account.id) || refreshReport.skippedAccountIDs.contains(account.id) {
                usageCache = nil
            } else {
                usageCache = try? await authManager.loadUsageCache(for: account)
            }
            let authInfo = Self.resolveAuthTokenInfo(for: account, authManager: authManager)
            let syncFailure = Self.resolveSyncFailureInfo(for: account, authManager: authManager)
            let status = resolveUsageStatus(
                accountID: account.id,
                usageCache: usageCache,
                syncFailureMessage: syncFailure.message,
                refreshReport: refreshReport
            )
            let failureType: NolonCodexAuthUsageAccountView.FailureType? = {
                guard status == .failed || status == .needsReauth else { return nil }
                let text = syncFailure.message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return CodexAuthFailureClassifier.isAuthFailure(errorText: text) ? .auth : .other
            }()
            views.append(
                NolonCodexAuthUsageAccountView(
                    id: account.id,
                    email: email,
                    isActive: account.id == activeID,
                    status: status,
                    failureType: failureType,
                    isSkipped: refreshReport.skippedAccountIDs.contains(account.id),
                    usageSource: usageCache?.sourceLabel,
                    fiveHourRemainingPercent: Self.remainingPercent(usageCache?.usage.primary),
                    weeklyRemainingPercent: Self.remainingPercent(usageCache?.usage.secondary),
                    token1dCount: nil,
                    token7dCount: nil,
                    token14dCount: nil,
                    token30dCount: nil,
                    tokenAllCount: nil,
                    expiresAt: authInfo.expiresAt,
                    hasRefreshToken: authInfo.hasRefreshToken,
                    refreshedAt: Self.resolveRefreshTime(from: usageCache),
                    syncFailedAt: syncFailure.failedAt,
                    syncFailureMessage: syncFailure.message
                )
            )
        }

        let fiveHourValues = views.compactMap(\.fiveHourRemainingPercent)
        let weeklyValues = views.compactMap(\.weeklyRemainingPercent)
        let token1dValues = views.compactMap(\.token1dCount)
        let token7dValues = views.compactMap(\.token7dCount)
        let token14dValues = views.compactMap(\.token14dCount)
        let token30dValues = views.compactMap(\.token30dCount)
        let tokenAllValues = views.compactMap(\.tokenAllCount)
        let expiryValues = views.compactMap(\.expiresAt)
        let cachedCount = views.filter { $0.fiveHourRemainingPercent != nil || $0.weeklyRemainingPercent != nil }.count
        let latestRefreshedAt = views.compactMap(\.refreshedAt).max()

        let summary = NolonCodexAuthUsageSummaryView(
            accountCount: views.count,
            cachedCount: cachedCount,
            avgFiveHourRemainingPercent: Self.average(of: fiveHourValues),
            avgWeeklyRemainingPercent: Self.average(of: weeklyValues),
            totalToken1dCount: token1dValues.isEmpty ? nil : token1dValues.reduce(0, +),
            totalToken7dCount: token7dValues.isEmpty ? nil : token7dValues.reduce(0, +),
            totalToken14dCount: token14dValues.isEmpty ? nil : token14dValues.reduce(0, +),
            totalToken30dCount: token30dValues.isEmpty ? nil : token30dValues.reduce(0, +),
            totalTokenAllCount: tokenAllValues.isEmpty ? nil : tokenAllValues.reduce(0, +),
            earliestExpiresAt: expiryValues.min(),
            latestRefreshedAt: latestRefreshedAt
        )

        return NolonCodexAuthUsagePayload(
            providerID: canonicalProviderID,
            accounts: views,
            summary: summary,
            refreshOrder: refreshReport.refreshOrder.enumerated().map { idx, accountID in
                NolonCodexAuthUsagePayload.RefreshStep(accountID: accountID, order: idx + 1)
            },
            skippedAccounts: refreshReport.skippedAccountIDs.compactMap { accountID in
                let reason = refreshReport.skippedReasons[accountID] ?? "failed_before"
                return NolonCodexAuthUsagePayload.SkippedAccount(accountID: accountID, reason: reason)
            }
        )
    }

    private func refreshUsageCaches(
        provider: Provider,
        accounts: [CodexAuthAccount],
        targetAccountID: UUID?
    ) async throws -> UsageRefreshReport {
        let targets: [CodexAuthAccount]
        if let targetAccountID {
            guard let matched = accounts.first(where: { $0.id == targetAccountID }) else {
                throw NolonCoreCLIError.domainFailed(
                    code: "codex_auth_account_not_found",
                    message: "Codex account not found: \(targetAccountID.uuidString)"
                )
            }
            targets = [matched]
        } else {
            let activeID = await authManager.activeAccountId(for: provider)
            let activeAccount = activeID.flatMap { id in accounts.first(where: { $0.id == id }) }
            if let activeAccount {
                targets = [activeAccount] + accounts.filter { $0.id != activeAccount.id }
            } else {
                targets = accounts
            }
        }

        guard !targets.isEmpty else { return UsageRefreshReport() }
        var report = UsageRefreshReport()

        var mergedEnvironment = environment
        if let managed = try? await binaryManager.launchEnvironmentVariables() {
            mergedEnvironment.merge(managed) { _, new in new }
        }

        for account in targets {
            let summary = Self.loadSummary(for: account, authManager: authManager)
            if CodexAuthFailureClassifier.shouldSkipRefresh(summary: summary) {
                report.skippedAccountIDs.insert(account.id)
                report.skippedReasons[account.id] = "failed_before"
                continue
            }
            report.refreshOrder.append(account.id)
            try authManager.ensureRuntimeSkillsSymlink(accountID: account.id)
            let runtimeHome = authManager.runtimeHomeFolder(accountID: account.id)
            _ = runtimeHome.createIfNotExists()
            let runtimeAuth = runtimeHome.file("auth.json")
            guard let authData = authManager.accountAuthData(for: account) else {
                throw NolonCoreCLIError.domainFailed(
                    code: "codex_auth_payload_missing",
                    message: "Codex account auth payload is missing: \(account.id.uuidString)"
                )
            }
            try runtimeAuth.overlay(with: authData)

            var accountEnvironment = mergedEnvironment
            accountEnvironment["CODEX_HOME"] = runtimeHome.url.standardizedFileURL.path

            let outcome = await usageOutcomeFetcher(accountEnvironment)
            switch outcome.result {
            case let .success(result):
                let now = Date()
                let creditsRefreshedAt: Date? = {
                    guard let credits = result.credits, !credits.remaining.isNaN else { return nil }
                    return now
                }()
                let cache = CodexAuthUsageCache(
                    cachedAt: now,
                    creditsRefreshedAt: creditsRefreshedAt,
                    fetchKind: outcome.fetchKind,
                    strategyKind: result.strategyKind,
                    sourceLabel: result.sourceLabel,
                    usage: result.usage,
                    credits: result.credits,
                    cost: nil
                )
                try await authManager.storeUsageCache(cache, for: account)
                try await authManager.updateSyncSuccess(for: account, date: now)
                if let email = result.usage.identity?.accountEmail?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !email.isEmpty
                {
                    _ = try? await authManager.backfillEmailIfMissing(for: account, email: email)
                }
            case let .failure(error):
                // Refresh failure means current account's usage snapshot is stale;
                // remove cache to avoid showing outdated values as if they were fresh.
                try await authManager.clearUsageCache(for: account)
                try await authManager.updateSyncFailure(for: account, message: error.localizedDescription, date: Date())
                report.failedAccountIDs.insert(account.id)
            }
        }
        return report
    }

    private func resolveUsageStatus(
        accountID: UUID,
        usageCache: CodexAuthUsageCache?,
        syncFailureMessage: String?,
        refreshReport: UsageRefreshReport
    ) -> NolonCodexAuthUsageAccountView.Status {
        if refreshReport.skippedAccountIDs.contains(accountID) { return .skipped }
        if refreshReport.failedAccountIDs.contains(accountID) {
            let text = syncFailureMessage?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return CodexAuthFailureClassifier.isAuthFailure(errorText: text) ? .needsReauth : .failed
        }
        if let syncFailureMessage, !syncFailureMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return CodexAuthFailureClassifier.isAuthFailure(errorText: syncFailureMessage) ? .needsReauth : .failed
        }
        if usageCache != nil { return .healthy }
        return .pending
    }

    public func authStatus(providerID: String) async throws -> NolonCodexAuthStatusPayload {
        let canonicalProviderID = try Self.canonicalProviderID(providerID)
        let provider = try Self.provider(for: canonicalProviderID)
        let usagePayload = try await authUsage(providerID: canonicalProviderID)
        let activeID = usagePayload.accounts.first(where: { $0.isActive })?.id
        let authHashHex = await authManager.currentAuthHashHex(for: provider)
        return NolonCodexAuthStatusPayload(
            providerID: canonicalProviderID,
            activeAccountID: activeID,
            accountCount: usagePayload.summary.accountCount,
            authHashHex: authHashHex,
            usageCachedAccountCount: usagePayload.summary.cachedCount,
            usageAvgFiveHourRemainingPercent: usagePayload.summary.avgFiveHourRemainingPercent,
            usageAvgWeeklyRemainingPercent: usagePayload.summary.avgWeeklyRemainingPercent,
            usageLatestRefreshedAt: usagePayload.summary.latestRefreshedAt
        )
    }

    public func authActivate(providerID: String, accountID: UUID) async throws -> NolonCodexAuthActivatePayload {
        let canonicalProviderID = try Self.canonicalProviderID(providerID)
        let provider = try Self.provider(for: canonicalProviderID)
        let accounts = try await authManager.loadAccounts()
        guard let account = accounts.first(where: { $0.id == accountID }) else {
            throw NolonCoreCLIError.domainFailed(
                code: "codex_auth_account_not_found",
                message: "Codex account not found: \(accountID.uuidString)"
            )
        }

        let result = try await authActivator(account, provider)
        return NolonCodexAuthActivatePayload(
            providerID: canonicalProviderID,
            accountID: accountID,
            runtimeSwitched: result.runtimeSwitched,
            runtimeErrorDescription: result.runtimeErrorDescription
        )
    }

    public func authRefresh(providerID: String, accountID: UUID?) async throws -> NolonCodexAuthRefreshPayload {
        let canonicalProviderID = try Self.canonicalProviderID(providerID)
        let provider = try Self.provider(for: canonicalProviderID)
        let accounts = try await authManager.loadAccounts()
        let activeAccountID = await authManager.activeAccountId(for: provider)
        guard !accounts.isEmpty else {
            throw NolonCoreCLIError.domainFailed(
                code: "codex_auth_account_not_found",
                message: "No Codex accounts available for refresh."
            )
        }

        let targets: [CodexAuthAccount]
        if let accountID {
            guard let matched = accounts.first(where: { $0.id == accountID }) else {
                throw NolonCoreCLIError.domainFailed(
                    code: "codex_auth_account_not_found",
                    message: "Codex account not found: \(accountID.uuidString)"
                )
            }
            targets = [matched]
        } else {
            targets = accounts
        }
        let preservedActiveAccount: CodexAuthAccount? = {
            guard accountID == nil, let activeAccountID else { return nil }
            return accounts.first(where: { $0.id == activeAccountID })
        }()

        var items: [NolonCodexAuthRefreshItemView] = []
        items.reserveCapacity(targets.count)
        var successCount = 0

        for target in targets {
            let email = Self.loadEmail(for: target, authManager: authManager)
            let tokenInfo = Self.resolveAuthTokenInfo(for: target, authManager: authManager)
            guard tokenInfo.hasRefreshToken == true else {
                items.append(
                    NolonCodexAuthRefreshItemView(
                        accountID: target.id,
                        accountName: target.name,
                        email: email,
                        isActive: target.id == activeAccountID,
                        success: false,
                        runtimeSwitched: false,
                        runtimeErrorDescription: nil,
                        errorCode: "codex_auth_refresh_token_missing",
                        errorMessage: "Account does not contain refresh_token: \(target.id.uuidString)"
                    )
                )
                continue
            }

            do {
                let activation = try await authActivator(target, provider)
                try await authRefreshRunner(canonicalProviderID, target.id, environment)
                items.append(
                    NolonCodexAuthRefreshItemView(
                        accountID: target.id,
                        accountName: target.name,
                        email: email,
                        isActive: target.id == activeAccountID,
                        success: true,
                        runtimeSwitched: activation.runtimeSwitched,
                        runtimeErrorDescription: activation.runtimeErrorDescription,
                        errorCode: nil,
                        errorMessage: nil
                    )
                )
                successCount += 1
            } catch {
                let mapped = Self.mapRefreshError(error, accountID: target.id)
                let message = mapped.errorDescription ?? "Silent refresh failed"
                items.append(
                    NolonCodexAuthRefreshItemView(
                        accountID: target.id,
                        accountName: target.name,
                        email: email,
                        isActive: target.id == activeAccountID,
                        success: false,
                        runtimeSwitched: false,
                        runtimeErrorDescription: nil,
                        errorCode: mapped.code,
                        errorMessage: message
                    )
                )
            }
        }

        var restoredPreservedActive = false
        if let preservedActiveAccount {
            do {
                _ = try await authActivator(preservedActiveAccount, provider)
                restoredPreservedActive = true
            } catch {
                do {
                    try await authManager.activateAccountAndMarkActive(preservedActiveAccount, for: provider)
                    restoredPreservedActive = true
                } catch {
                    restoredPreservedActive = false
                }
            }
        }

        let finalActiveAccountID: UUID?
        if accountID == nil,
           restoredPreservedActive,
           let preservedActiveID = preservedActiveAccount?.id ?? activeAccountID {
            finalActiveAccountID = preservedActiveID
        } else {
            finalActiveAccountID = await authManager.activeAccountId(for: provider)
        }
        let resolvedItems = items.map { item in
            NolonCodexAuthRefreshItemView(
                accountID: item.accountID,
                accountName: item.accountName,
                email: item.email,
                isActive: item.accountID == finalActiveAccountID,
                success: item.success,
                runtimeSwitched: item.runtimeSwitched,
                runtimeErrorDescription: item.runtimeErrorDescription,
                errorCode: item.errorCode,
                errorMessage: item.errorMessage
            )
        }

        let summary = NolonCodexAuthRefreshSummaryView(
            totalCount: items.count,
            successCount: successCount,
            failureCount: items.count - successCount
        )
        return NolonCodexAuthRefreshPayload(providerID: canonicalProviderID, items: resolvedItems, summary: summary)
    }

    public func authLogin(providerID: String, preferredAccountID: UUID?) async throws -> NolonCodexAuthLoginPayload {
        let canonicalProviderID = try Self.canonicalProviderID(providerID)
        let provider = try Self.provider(for: canonicalProviderID)
        let codexHome = authManager.cliLoginCodexHomeFolder(providerID: canonicalProviderID)
        try Self.prepareIsolatedLoginHome(codexHome: codexHome)

        let loginResult: CodexLoginResult
        do {
            loginResult = try await Self.loginViaAppServer(
                environment: environment,
                codexHome: codexHome
            )
        } catch {
            loginResult = try await loginRunner.loginAndAwaitAuthResult(
                binary: "codex",
                environment: environment,
                codexHome: codexHome
            )
        }

        let account = try await authManager.recordCLILoginSnapshot(
            authJSONString: loginResult.authJSONString,
            preferredAccountID: preferredAccountID
        )
        let activation = try await authActivator(account, provider)
        return NolonCodexAuthLoginPayload(
            providerID: canonicalProviderID,
            accountID: account.id,
            accountName: account.name,
            runtimeSwitched: activation.runtimeSwitched,
            runtimeErrorDescription: activation.runtimeErrorDescription,
            loginURL: loginResult.loginURL
        )
    }

    public func authDelete(providerID: String, accountID: UUID) async throws -> NolonCodexAuthDeletePayload {
        let canonicalProviderID = try Self.canonicalProviderID(providerID)
        let provider = try Self.provider(for: canonicalProviderID)
        let accounts = try await authManager.loadAccounts()
        guard accounts.contains(where: { $0.id == accountID }) else {
            throw NolonCoreCLIError.domainFailed(
                code: "codex_auth_account_not_found",
                message: "Codex account not found: \(accountID.uuidString)"
            )
        }
        let activeID = await authManager.activeAccountId(for: provider)
        try await authManager.deleteAccount(id: accountID, provider: provider)
        return NolonCodexAuthDeletePayload(
            providerID: canonicalProviderID,
            accountID: accountID,
            wasActive: activeID == accountID
        )
    }

    public func binaryList() async throws -> NolonCodexBinaryListPayload {
        let manifest = try await binaryManager.loadManifest()
        let selected = manifest.selectedVersionId
        let versions = manifest.versions.map { version in
            NolonCodexManagedVersionView(
                id: version.id,
                displayName: version.displayName,
                detectedVersion: version.detectedVersion,
                source: version.source,
                importedAt: version.importedAt,
                isSelected: version.id == selected
            )
        }
        return NolonCodexBinaryListPayload(selectedVersionID: selected, versions: versions)
    }

    public func binaryAvailable() async throws -> NolonCodexBinaryAvailablePayload {
        let manifest = try await binaryManager.loadManifest()
        let releases = try await binaryManager.fetchRemoteReleases(includePrerelease: manifest.includeBetaVersions)
        let versions = releases.map { release in
            NolonCodexRemoteVersionView(
                version: release.version,
                tag: release.tag,
                downloadURL: release.assetURL.absoluteString,
                isPrerelease: release.isPrerelease
            )
        }
        return NolonCodexBinaryAvailablePayload(versions: versions)
    }

    public func binaryCurrent() async throws -> NolonCodexBinaryCurrentPayload {
        let manifest = try await binaryManager.loadManifest()
        let currentVersion = try await binaryManager.currentCLIVersion()
        let activePath = await binaryManager.activeCLIPathIfAvailable()
        return NolonCodexBinaryCurrentPayload(
            selectedVersionID: manifest.selectedVersionId,
            currentVersion: currentVersion,
            activeCLIPath: activePath
        )
    }

    public func binaryInstall(version: String, setDefault: Bool) async throws -> NolonCodexBinaryInstallPayload {
        let manifest = try await binaryManager.loadManifest()
        let releases = try await binaryManager.fetchRemoteReleases(includePrerelease: manifest.includeBetaVersions)
        guard let matched = releases.first(where: { $0.version == version || $0.tag == version }) else {
            throw NolonCoreCLIError.domainFailed(
                code: "codex_binary_not_found",
                message: "Requested Codex version not found: \(version)"
            )
        }
        let managed = try await binaryManager.downloadAndImport(from: matched.assetURL, displayName: "Codex \(matched.version)")
        if setDefault {
            try await binaryManager.activate(versionId: managed.id)
        }
        return NolonCodexBinaryInstallPayload(
            requestedVersion: version,
            installedVersionID: managed.id,
            installedDetectedVersion: managed.detectedVersion,
            activated: setDefault
        )
    }

    public func binaryUse(version: String) async throws -> NolonCodexBinaryUsePayload {
        let versions = try await binaryManager.listVersions()
        guard let target = versions.first(where: { $0.detectedVersion == version || $0.id == version }) else {
            throw NolonCoreCLIError.domainFailed(
                code: "codex_binary_not_found",
                message: "Managed Codex version not found: \(version)"
            )
        }
        try await binaryManager.activate(versionId: target.id)
        return NolonCodexBinaryUsePayload(selectedVersionID: target.id)
    }

    public func binaryDoctor() async throws -> NolonCodexBinaryDoctorPayload {
        let manifest = try await binaryManager.loadManifest()
        let currentVersion = try await binaryManager.currentCLIVersion()
        let activePath = await binaryManager.activeCLIPathIfAvailable()
        let pathStatus = await binaryManager.codexPathStatus()
        return NolonCodexBinaryDoctorPayload(
            selectedVersionID: manifest.selectedVersionId,
            currentVersion: currentVersion,
            activeCLIPath: activePath,
            managedVersionCount: manifest.versions.count,
            pathConfigured: pathStatus.configured,
            pathActive: pathStatus.active,
            profilePath: pathStatus.profilePath
        )
    }

    public func statusProbe(providerID: String?) async throws -> NolonCodexStatusProbePayload {
        let canonicalProviderID: String?
        if let providerID {
            canonicalProviderID = try Self.canonicalProviderID(providerID)
            _ = try Self.provider(for: providerID)
        } else {
            canonicalProviderID = nil
        }
        var env = environment
        if let codexPath = await binaryManager.activeCLIPathIfAvailable() {
            env["CODEX_CLI_PATH"] = codexPath
        }
        if let managed = try? await binaryManager.launchEnvironmentVariables() {
            env.merge(managed) { _, new in new }
        }

        let probe = CodexStatusProbe(environment: env)
        let snapshot = try await probe.fetch()
        let resolvedExecutable = CodexCommandExecutor(executable: "codex", environment: env).resolveExecutable()
        return NolonCodexStatusProbePayload(
            providerID: canonicalProviderID,
            resolvedExecutable: resolvedExecutable,
            credits: snapshot.credits,
            fiveHourPercentLeft: snapshot.fiveHourPercentLeft,
            weeklyPercentLeft: snapshot.weeklyPercentLeft,
            fiveHourResetDescription: snapshot.fiveHourResetDescription,
            weeklyResetDescription: snapshot.weeklyResetDescription,
            probeWarning: nil,
            probeHint: nil
        )
    }

    public func providerList() async throws -> NolonProviderListPayload {
        let templates = ProviderTemplate.allCases.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
        let providers: [NolonProviderCLIView] = templates.compactMap { template in
            let executable = template.cliName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !executable.isEmpty else { return nil }
            let resolved = Self.resolveCLIInOfficialPaths(named: executable)
            guard let resolved else { return nil }
            return NolonProviderCLIView(
                providerID: template.providerID,
                name: template.displayName,
                cli: executable,
                installed: true,
                executablePath: resolved
            )
        }
        return NolonProviderListPayload(providers: providers)
    }

    public func providerDiscover() async throws -> NolonCodexProviderDiscoverPayload {
        let providerIDs = ["codex", "codex-xcode"]
        var providers: [NolonCodexProviderDiscoverView] = []
        providers.reserveCapacity(providerIDs.count)

        for providerID in providerIDs {
            let provider = try Self.provider(for: providerID)
            let authFile = await authManager.authFile(for: provider)
            let targetPath: String?
            if let authFile, authFile.isSymbolicLink {
                targetPath = try? authFile.destinationOfSymbolicLink().url.standardizedFileURL.path
            } else {
                targetPath = nil
            }

            providers.append(
                NolonCodexProviderDiscoverView(
                    providerID: providerID,
                    name: provider.name,
                    templateID: provider.templateId ?? providerID,
                    codexHomePath: authFile?.parentFolder()?.url.standardizedFileURL.path ?? "-",
                    authPath: authFile?.url.standardizedFileURL.path ?? "-",
                    authExists: authFile?.isExists ?? false,
                    authIsSymlink: authFile?.isSymbolicLink ?? false,
                    authSymlinkTargetPath: targetPath
                )
            )
        }

        return NolonCodexProviderDiscoverPayload(providers: providers)
    }

    public func runtimeList(providerID: String?) async throws -> NolonCodexRuntimeListPayload {
        _ = providerID
        let currentPID = currentPIDProvider()
        let snapshots = try runtimeProcessInspector.listProcesses()
        let views = snapshots
            .filter { snapshot in
                snapshot.pid != currentPID && Self.isCodexRuntimeCommand(snapshot.command)
            }
            .sorted(by: { $0.pid < $1.pid })
            .map { snapshot in
                NolonCodexRuntimeProcessView(
                    pid: snapshot.pid,
                    ppid: snapshot.ppid,
                    elapsed: snapshot.elapsed,
                    providerHint: Self.providerHint(from: snapshot.command),
                    command: snapshot.command,
                    workingDirectory: snapshot.workingDirectory
                )
            }
        return NolonCodexRuntimeListPayload(processes: views)
    }

    public func runtimeStop(pid: Int32, force: Bool, timeoutSeconds: Int) async throws -> NolonCodexRuntimeStopPayload {
        guard pid > 1 else {
            throw NolonCoreCLIError.invalidArguments("Invalid --pid: \(pid)")
        }
        guard timeoutSeconds > 0 else {
            throw NolonCoreCLIError.invalidArguments("Invalid --timeout-seconds: \(timeoutSeconds)")
        }
        if pid == currentPIDProvider() {
            throw NolonCoreCLIError.invalidArguments("Refusing to stop current nolon process: \(pid)")
        }

        if force {
            try runtimeSignalController.send(signal: SIGKILL, to: pid)
            let exited = !runtimeSignalController.isRunning(pid: pid)
            return NolonCodexRuntimeStopPayload(
                pid: pid,
                requestedSignal: "kill",
                didEscalateToKill: false,
                exited: exited
            )
        }

        try runtimeSignalController.send(signal: SIGTERM, to: pid)
        let attempts = max(1, timeoutSeconds * 10)
        for _ in 0..<attempts {
            if !runtimeSignalController.isRunning(pid: pid) {
                return NolonCodexRuntimeStopPayload(
                    pid: pid,
                    requestedSignal: "term",
                    didEscalateToKill: false,
                    exited: true
                )
            }
            try await sleep(100_000_000)
        }

        try runtimeSignalController.send(signal: SIGKILL, to: pid)
        for _ in 0..<20 {
            if !runtimeSignalController.isRunning(pid: pid) {
                break
            }
            try await sleep(100_000_000)
        }
        let exited = !runtimeSignalController.isRunning(pid: pid)
        return NolonCodexRuntimeStopPayload(
            pid: pid,
            requestedSignal: "term",
            didEscalateToKill: true,
            exited: exited
        )
    }

    public func gatewayStatus(providerID: String) async throws -> NolonCodexGatewayStatusPayload {
        let canonicalProviderID = try Self.canonicalProviderID(providerID)
        var snapshot = await gatewayControlService.status()
        if snapshot.status == .running {
            if await Self.embeddedGatewayRuntime.isRunning(providerID: canonicalProviderID) {
                // Embedded daemon is alive in current app process.
            } else if let pid = await gatewayPIDStore.load() {
                if !runtimeSignalController.isRunning(pid: pid) {
                    snapshot = try await gatewayControlService.stop(config: CodexGatewayConfig(host: snapshot.host, port: snapshot.port))
                    try? await gatewayPIDStore.clear()
                }
            } else {
                let healthy = await gatewayHealthChecker(snapshot.host, snapshot.port)
                if !healthy {
                    snapshot = try await gatewayControlService.stop(config: CodexGatewayConfig(host: snapshot.host, port: snapshot.port))
                }
            }
        }
        return NolonCodexGatewayStatusPayload(
            providerID: canonicalProviderID,
            status: snapshot.status,
            host: snapshot.host,
            port: snapshot.port,
            startedAt: snapshot.startedAt
        )
    }

    public func gatewayStart(providerID: String, host: String, port: Int) async throws -> NolonCodexGatewaySetPayload {
        let canonicalProviderID = try Self.canonicalProviderID(providerID)
        let provider = try Self.provider(for: canonicalProviderID)
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHost.isEmpty else {
            throw NolonCoreCLIError.invalidArguments("Invalid --host: value cannot be empty")
        }
        guard (1...65535).contains(port) else {
            throw NolonCoreCLIError.invalidArguments("Invalid --port: \(port)")
        }
        let config = CodexGatewayConfig(host: trimmedHost, port: port)
        guard let configFile = gatewayConfigFileResolver(provider) else {
            throw NolonCoreCLIError.domainFailed(
                code: "codex_gateway_config_unavailable",
                message: "Codex config.toml is unavailable for provider: \(canonicalProviderID)"
            )
        }
        let gatewayAuthProvider = Self.gatewayAuthProvider(from: provider, configFile: configFile)
        if await Self.embeddedGatewayRuntime.isRunning(providerID: canonicalProviderID) {
            throw NolonCoreCLIError.domainFailed(
                code: "codex_gateway_already_running",
                message: "Codex gateway is already running. Stop it before starting again."
            )
        }
        if let existingPID = await gatewayPIDStore.load(),
           runtimeSignalController.isRunning(pid: existingPID) {
            throw NolonCoreCLIError.domainFailed(
                code: "codex_gateway_already_running",
                message: "Codex gateway is already running (pid=\(existingPID)). Stop it before starting again."
            )
        }
        guard let launchMode = Self.resolveGatewayDaemonLaunchMode(
            currentExecutablePath: gatewayExecutablePathProvider()
        ) else {
            throw NolonCoreCLIError.domainFailed(
                code: "codex_gateway_executable_unavailable",
                message: "Unable to resolve nolon executable path for gateway daemon startup."
            )
        }
        try await gatewayConfigManager.patchGatewayConfig(configFile: configFile, config: config)
        let detachedPID: Int32?
        do {
            switch launchMode {
            case .detached(let executablePath):
                let arguments = [
                    "codex", "gateway", "serve",
                    "--provider", canonicalProviderID,
                    "--host", trimmedHost,
                    "--port", "\(port)",
                ]
                let pid = try gatewayDetachedProcessStarter(executablePath, arguments)
                try await gatewayPIDStore.save(pid)
                detachedPID = pid
            case .embedded:
                let started = await Self.embeddedGatewayRuntime.start(providerID: canonicalProviderID) {
                    try? await self.gatewayServe(providerID: canonicalProviderID, host: trimmedHost, port: port)
                }
                guard started else {
                    throw NolonCoreCLIError.domainFailed(
                        code: "codex_gateway_already_running",
                        message: "Codex gateway is already running. Stop it before starting again."
                    )
                }
                try? await gatewayPIDStore.clear()
                detachedPID = nil
            }
        } catch {
            try? await gatewayConfigManager.restoreGatewayConfig(configFile: configFile)
            throw error
        }

        let healthy = await Self.waitForGatewayHealthy(
            host: trimmedHost,
            port: port,
            checker: gatewayHealthChecker,
            sleep: sleep
        )
        guard healthy else {
            if let detachedPID {
                _ = try? await stopGatewayProcess(pid: detachedPID)
            } else {
                await Self.embeddedGatewayRuntime.stop(providerID: canonicalProviderID)
            }
            try? await gatewayPIDStore.clear()
            try? await gatewayConfigManager.restoreGatewayConfig(configFile: configFile)
            throw NolonCoreCLIError.domainFailed(
                code: "codex_gateway_start_failed",
                message: "Codex gateway failed to become healthy at http://\(trimmedHost):\(port)/healthz"
            )
        }

        let previousActiveAccountID = await resolveGatewayPreviousActiveAccountID(provider: gatewayAuthProvider)
        do {
            let virtualAccount = try await upsertGatewayVirtualReplyAccount(
                providerID: canonicalProviderID,
                host: trimmedHost,
                port: port
            )
            try await authManager.activateAccountAndMarkActive(virtualAccount, for: gatewayAuthProvider)
            try await gatewayVirtualAccountStateStore.save(
                CodexGatewayVirtualAccountState(
                    providerID: canonicalProviderID,
                    previousActiveAccountID: previousActiveAccountID,
                    virtualAccountID: virtualAccount.id
                )
            )
        } catch {
            if let detachedPID {
                _ = try? await stopGatewayProcess(pid: detachedPID)
            } else {
                await Self.embeddedGatewayRuntime.stop(providerID: canonicalProviderID)
            }
            try? await gatewayPIDStore.clear()
            try? await gatewayConfigManager.restoreGatewayConfig(configFile: configFile)
            _ = try? await gatewayControlService.stop(config: config)
            if let previousActiveAccountID {
                try? await restoreGatewayActiveAccount(
                    provider: gatewayAuthProvider,
                    targetAccountID: previousActiveAccountID
                )
            } else {
                try? await authManager.clearActiveAccount(for: gatewayAuthProvider)
            }
            throw NolonCoreCLIError.domainFailed(
                code: "codex_gateway_virtual_account_failed",
                message: "Codex gateway failed to switch active account to gateway virtual reply account."
            )
        }

        var snapshot = await gatewayControlService.status(config: config)
        if snapshot.status != .running {
            snapshot = try await gatewayControlService.start(config: config)
        }
        return NolonCodexGatewaySetPayload(
            providerID: canonicalProviderID,
            status: snapshot.status,
            host: snapshot.host,
            port: snapshot.port,
            startedAt: snapshot.startedAt
        )
    }

    public func gatewayStop(providerID: String) async throws -> NolonCodexGatewaySetPayload {
        let canonicalProviderID = try Self.canonicalProviderID(providerID)
        let provider = try Self.provider(for: canonicalProviderID)
        guard let configFile = gatewayConfigFileResolver(provider) else {
            throw NolonCoreCLIError.domainFailed(
                code: "codex_gateway_config_unavailable",
                message: "Codex config.toml is unavailable for provider: \(canonicalProviderID)"
            )
        }
        let gatewayAuthProvider = Self.gatewayAuthProvider(from: provider, configFile: configFile)
        await Self.embeddedGatewayRuntime.stop(providerID: canonicalProviderID)
        if let pid = await gatewayPIDStore.load() {
            _ = try? await stopGatewayProcess(pid: pid)
            try? await gatewayPIDStore.clear()
        }
        try await gatewayConfigManager.restoreGatewayConfig(configFile: configFile)
        if let state = await gatewayVirtualAccountStateStore.load(providerID: canonicalProviderID) {
            if let previousActiveAccountID = state.previousActiveAccountID {
                try? await restoreGatewayActiveAccount(provider: gatewayAuthProvider, targetAccountID: previousActiveAccountID)
            } else {
                try? await authManager.clearActiveAccount(for: gatewayAuthProvider)
                try? await removeProviderAuthLinkIfPresent(for: gatewayAuthProvider)
            }
            try? await gatewayVirtualAccountStateStore.remove(providerID: canonicalProviderID)
        }
        let snapshot = try await gatewayControlService.stop()
        return NolonCodexGatewaySetPayload(
            providerID: canonicalProviderID,
            status: snapshot.status,
            host: snapshot.host,
            port: snapshot.port,
            startedAt: snapshot.startedAt
        )
    }

    public func gatewayServe(providerID: String, host: String, port: Int) async throws {
        let canonicalProviderID = try Self.canonicalProviderID(providerID)
        _ = try Self.provider(for: canonicalProviderID)
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHost.isEmpty else {
            throw NolonCoreCLIError.invalidArguments("Invalid --host: value cannot be empty")
        }
        guard (1...65535).contains(port) else {
            throw NolonCoreCLIError.invalidArguments("Invalid --port: \(port)")
        }

        let app = try await Application.make(.production)
        defer {
            Task {
                try? await app.asyncShutdown()
            }
        }
        app.http.server.configuration.hostname = trimmedHost
        app.http.server.configuration.port = port

        let config = CodexGatewayConfig(host: trimmedHost, port: port)
        let accountSource = CodexGatewayAccountSource(authManager: authManager)
        let routingService = CodexGatewayResponsesRoutingService(accountSource: accountSource)
        let statusSnapshot = CodexGatewayStatusSnapshot(
            status: .running,
            host: trimmedHost,
            port: port,
            startedAt: Date()
        )
        try CodexGatewayServer.configure(
            app: app,
            statusProvider: { statusSnapshot },
            responsesHandler: { context in
                try await routingService.handle(context)
            }
        )
        try await app.asyncBoot()
        try await app.server.start(address: .hostname(trimmedHost, port: port))
        _ = try await gatewayControlService.start(config: config)
        do {
            while !Task.isCancelled {
                try await sleep(250_000_000)
            }
        } catch is CancellationError {
        } catch {
            await app.server.shutdown()
            _ = try? await gatewayControlService.stop(config: config)
            throw error
        }
        await app.server.shutdown()
        _ = try? await gatewayControlService.stop(config: config)
    }

    private static func liveAuthRefreshRunner(providerID: String, accountID: UUID, environment: [String: String]) async throws {
        _ = providerID
        var runtimeEnvironment = environment
        let authManager = CodexAuthManager(environment: environment)
        try authManager.ensureRuntimeSkillsSymlink(accountID: accountID)
        let runtimeHome = authManager.runtimeHomeFolder(accountID: accountID)
        _ = runtimeHome.createIfNotExists()
        runtimeEnvironment["CODEX_HOME"] = runtimeHome.url.standardizedFileURL.path
        let service = CodexAccountRuntimeService(
            executable: environment["CODEX_CLI_PATH"] ?? "codex",
            environment: runtimeEnvironment
        )
        defer { Task { await service.shutdown() } }
        try await service.initialize(clientName: "nolon", clientVersion: "1.0.0")
        _ = try await service.readAccount(refreshToken: true)
    }

    private func stopGatewayProcess(pid: Int32) async throws -> Bool {
        try runtimeSignalController.send(signal: SIGTERM, to: pid)
        for _ in 0..<20 {
            if !runtimeSignalController.isRunning(pid: pid) {
                return true
            }
            try await sleep(100_000_000)
        }
        try runtimeSignalController.send(signal: SIGKILL, to: pid)
        for _ in 0..<20 {
            if !runtimeSignalController.isRunning(pid: pid) {
                return true
            }
            try await sleep(100_000_000)
        }
        return !runtimeSignalController.isRunning(pid: pid)
    }

    private func upsertGatewayVirtualReplyAccount(
        providerID: String,
        host: String,
        port: Int
    ) async throws -> CodexAuthAccount {
        let relay = CodexAuthManager.ConfiguredRelay(
            baseURL: "http://\(host):\(port)",
            modelProvider: "openai",
            queryParams: [
                Self.gatewayVirtualMarkerKey: "1",
                "provider_id": providerID,
            ]
        )
        let name = "\(Self.gatewayVirtualNamePrefix)-\(providerID)"
        return try await authManager.upsertGatewayVirtualAccount(
            providerID: providerID,
            name: name,
            apiKey: Self.gatewayVirtualAPIKey,
            relay: relay
        )
    }

    private func resolveGatewayPreviousActiveAccountID(provider: Provider) async -> UUID? {
        if let linkedSnapshot = await resolveSnapshotBackedActiveAccountIDFromProviderAuth(provider: provider) {
            return linkedSnapshot
        }

        guard let candidateID = await authManager.activeAccountId(for: provider) else {
            return nil
        }
        let accounts = (try? await authManager.loadAccounts()) ?? []
        guard let candidate = accounts.first(where: { $0.id == candidateID }) else {
            return nil
        }
        return await isGatewayVirtualMarkedAccount(candidate) ? nil : candidateID
    }

    private func resolveSnapshotBackedActiveAccountIDFromProviderAuth(provider: Provider) async -> UUID? {
        guard let providerAuthFile = await authManager.authFile(for: provider),
              providerAuthFile.isExists,
              providerAuthFile.isSymbolicLink,
              let destinationURL = Self.symlinkDestinationURL(for: providerAuthFile.url),
              let payloadData = try? Data(contentsOf: destinationURL),
              !payloadData.isEmpty
        else {
            return nil
        }

        let standardizedDestination = destinationURL.standardizedFileURL.path
        if Self.looksLikeGatewayVirtualPath(standardizedDestination) {
            return nil
        }

        if let accountID = Self.accountID(fromAuthPayloadData: payloadData) {
            let accounts = (try? await authManager.loadAccounts()) ?? []
            if let matched = accounts.first(where: { $0.id == accountID }) {
                return await isGatewayVirtualMarkedAccount(matched) ? nil : matched.id
            }
        }

        let accounts = (try? await authManager.loadAccounts()) ?? []
        for account in accounts where !(await isGatewayVirtualMarkedAccount(account)) {
            guard let data = authManager.accountAuthData(for: account),
                  data == payloadData
            else { continue }
            return account.id
        }
        return nil
    }

    private static func accountID(fromAuthPayloadData data: Data) -> UUID? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let nolon = object["nolon"] as? [String: Any],
              let account = nolon["account"] as? [String: Any],
              let accountIDRaw = account["id"] as? String
        else {
            return nil
        }
        return UUID(uuidString: accountIDRaw.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func symlinkDestinationURL(for fileURL: URL) -> URL? {
        guard let destination = try? FileManager.default.destinationOfSymbolicLink(atPath: fileURL.path) else {
            return nil
        }
        if destination.hasPrefix("/") {
            return URL(fileURLWithPath: destination)
        }
        return fileURL
            .deletingLastPathComponent()
            .appendingPathComponent(destination)
            .standardizedFileURL
    }

    private static func looksLikeGatewayVirtualPath(_ path: String) -> Bool {
        let lowered = path.lowercased()
        return lowered.contains("/gateway/virtual-auth/")
            || lowered.contains("/__gateway_reply__-")
    }

    private func isGatewayVirtualMarkedAccount(_ account: CodexAuthAccount) async -> Bool {
        if Self.looksLikeGatewayVirtualPath(account.relativeAuthPath) {
            return true
        }
        guard let data = authManager.accountAuthData(for: account),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let nolon = object["nolon"] as? [String: Any],
              let relay = nolon["relay"] as? [String: Any],
              let queryParams = relay["query_params"] as? [String: Any]
        else {
            return false
        }
        return (queryParams[Self.gatewayVirtualMarkerKey] as? String) == "1"
    }

    private func removeProviderAuthLinkIfPresent(for provider: Provider) async throws {
        guard let providerAuthFile = await authManager.authFile(for: provider),
              providerAuthFile.isExists || providerAuthFile.isSymbolicLink
        else {
            return
        }
        do {
            try FileManager.default.removeItem(at: providerAuthFile.url)
        } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileNoSuchFileError {
            return
        } catch let error as NSError where error.domain == NSPOSIXErrorDomain && error.code == ENOENT {
            return
        }
    }

    private func restoreGatewayActiveAccount(provider: Provider, targetAccountID: UUID) async throws {
        let accounts = try await authManager.loadAccounts()
        guard let account = accounts.first(where: { $0.id == targetAccountID }) else { return }
        try await authManager.activateAccountAndMarkActive(account, for: provider)
    }

    private static func waitForGatewayHealthy(
        host: String,
        port: Int,
        checker: @escaping GatewayHealthChecker,
        sleep: @escaping @Sendable (UInt64) async throws -> Void
    ) async -> Bool {
        for _ in 0..<Self.gatewayHealthCheckMaxAttempts {
            if await checker(host, port) {
                return true
            }
            do {
                try await sleep(Self.gatewayHealthCheckSleepNanoseconds)
            } catch {
                return false
            }
        }
        return false
    }

    private static func healthCheck(host: String, port: Int) async -> Bool {
        guard let url = URL(string: "http://\(host):\(port)/healthz") else {
            return false
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = Self.gatewayHealthCheckRequestTimeout
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            return httpResponse.statusCode == 200
        } catch {
            return false
        }
    }

    private static func startDetachedProcess(executablePath: String, arguments: [String]) throws -> Int32 {
        let commandLine = ([executablePath] + arguments)
            .map(shellEscaped)
            .joined(separator: " ")
        let script = "nohup \(commandLine) >/dev/null 2>&1 & echo $!"

        var payload = SKProcessPayload.executableURL(STPath("/bin/sh").url)
        payload.arguments = ["-lc", script]
        payload.throwOnNonZeroExit = false
        payload.timeoutMs = 5_000

        let result = try SKProcessRunner.runSync(payload)
        guard result.exitCode == 0 else {
            let stderr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw NolonCoreCLIError.executionFailed(stderr.isEmpty ? "failed to start detached process" : stderr)
        }
        let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let line = output.split(separator: "\n").last,
              let pid = Int32(line) else {
            throw NolonCoreCLIError.executionFailed("failed to parse detached process pid")
        }
        return pid
    }

    private static func shellEscaped(_ value: String) -> String {
        if value.isEmpty { return "''" }
        if value.range(of: #"^[A-Za-z0-9_@%+=:,./-]+$"#, options: .regularExpression) != nil {
            return value
        }
        return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static func resolveGatewayDaemonLaunchMode(
        currentExecutablePath: String?,
        fileManager: FileManager = .default
    ) -> GatewayDaemonLaunchMode? {
        guard let path = currentExecutablePath?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !path.isEmpty else {
            return nil
        }
        if isAppBundleExecutablePath(path) {
            if let companion = resolveCompanionCLIExecutablePath(
                forAppExecutablePath: path,
                fileManager: fileManager
            ) {
                return .detached(executablePath: companion)
            }
            return .embedded
        }
        return .detached(executablePath: path)
    }

    private static func isAppBundleExecutablePath(_ path: String) -> Bool {
        path.contains(".app/Contents/MacOS/")
    }

    private static func resolveCompanionCLIExecutablePath(
        forAppExecutablePath appExecutablePath: String,
        fileManager: FileManager
    ) -> String? {
        let appExecutableURL = URL(fileURLWithPath: appExecutablePath).standardizedFileURL
        let executableName = appExecutableURL.lastPathComponent
        let appRootURL = appExecutableURL
            .deletingLastPathComponent() // MacOS
            .deletingLastPathComponent() // Contents
            .deletingLastPathComponent() // *.app
        let siblingCandidates: [URL] = [
            appRootURL.deletingLastPathComponent().appendingPathComponent(executableName),
            appExecutableURL.deletingLastPathComponent().appendingPathComponent("\(executableName)-cli"),
            appExecutableURL
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Resources")
                .appendingPathComponent("\(executableName)-cli")
        ]
        for candidate in siblingCandidates {
            let candidatePath = candidate.standardizedFileURL.path
            if candidatePath == appExecutablePath { continue }
            if fileManager.isExecutableFile(atPath: candidatePath) {
                return candidatePath
            }
        }
        return nil
    }

    private static func resolveCurrentExecutablePath() -> String? {
        guard let rawExecutable = CommandLine.arguments.first?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !rawExecutable.isEmpty else {
            return nil
        }
        let fileManager = FileManager.default
        if rawExecutable.contains("/") {
            let path = rawExecutable.hasPrefix("/")
                ? rawExecutable
                : URL(fileURLWithPath: fileManager.currentDirectoryPath)
                    .appendingPathComponent(rawExecutable)
                    .standardizedFileURL
                    .path
            return fileManager.isExecutableFile(atPath: path) ? path : nil
        }

        let pathEnv = ProcessInfo.processInfo.environment["PATH"] ?? ""
        for rawPath in pathEnv.split(separator: ":") {
            let candidate = URL(fileURLWithPath: String(rawPath), isDirectory: true)
                .appendingPathComponent(rawExecutable)
                .path
            if fileManager.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    private static func loginViaAppServer(
        environment: [String: String],
        codexHome: STFolder
    ) async throws -> CodexLoginResult {
        var runtimeEnvironment = environment
        runtimeEnvironment["CODEX_HOME"] = codexHome.url.standardizedFileURL.path
        let service = CodexAccountRuntimeService(
            executable: environment["CODEX_CLI_PATH"] ?? "codex",
            environment: runtimeEnvironment
        )
        defer { Task { await service.shutdown() } }
        try await service.initialize(clientName: "codex", clientVersion: "1.0.0")
        let started = try await service.startChatGPTLogin()

        do {
            let authResult = try await CodexLoginRunner.awaitAuthResultPreferFile(
                codexHome: codexHome,
                timeoutSeconds: 10 * 60,
                pollIntervalSeconds: 0.2,
                completionWaiter: {
                    try await service.awaitChatGPTLoginCompletion(loginID: started.loginID, timeout: 10 * 60)
                }
            )
            return CodexLoginResult(authJSONString: authResult.authJSONString, loginURL: started.authURL.absoluteString)
        } catch let error as CodexLoginError {
            switch error {
            case .authInvalidUTF8:
                throw NolonCoreCLIError.domainFailed(
                    code: "codex_auth_login_invalid_auth_file",
                    message: "Login completed but auth.json is empty or invalid UTF-8."
                )
            default:
                throw NolonCoreCLIError.domainFailed(
                    code: "codex_auth_login_missing_auth_file",
                    message: "Login completed but auth.json was not created."
                )
            }
        }
    }

    static func prepareIsolatedLoginHome(codexHome: STFolder) throws {
        _ = codexHome.createIfNotExists()

        let configFile = codexHome.file("config.toml")
        let requiredConfig = "cli_auth_credentials_store = \"file\"\n"
        if !configFile.isExists || ((try? configFile.read()) != requiredConfig) {
            try configFile.overlay(with: requiredConfig)
        }

        let authFileURL = codexHome.file("auth.json").url
        do {
            try FileManager.default.removeItem(at: authFileURL)
        } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileNoSuchFileError {
            return
        } catch let error as NSError where error.domain == NSPOSIXErrorDomain && error.code == ENOENT {
            return
        }
    }

    private static func liveUsageOutcomeFetcher(environment: [String: String]) async -> ProviderFetchOutcome {
        let context = ProviderFetchContext(
            provider: .codex,
            sourceMode: .auto,
            includeCredits: true,
            timeout: 20,
            costWindowDays: nil,
            environment: environment,
            token: nil
        )
        return await CodexUsageDescriptor().fetchOutcome(context: context)
    }

    private static func mapRefreshError(_ error: Error, accountID: UUID) -> NolonCoreCLIError {
        let text = error.localizedDescription.lowercased()
        if text.contains("refresh_token_expired") {
            return .domainFailed(
                code: "codex_auth_refresh_token_expired",
                message: "Refresh token expired for account: \(accountID.uuidString)"
            )
        }
        if text.contains("refresh_token_reused") || text.contains("refresh_token_exhausted") {
            return .domainFailed(
                code: "codex_auth_refresh_token_exhausted",
                message: "Refresh token exhausted for account: \(accountID.uuidString)"
            )
        }
        if text.contains("refresh_token_invalidated") || text.contains("refresh_token_revoked") {
            return .domainFailed(
                code: "codex_auth_refresh_token_revoked",
                message: "Refresh token revoked for account: \(accountID.uuidString)"
            )
        }
        return .domainFailed(
            code: "codex_auth_refresh_failed",
            message: "Silent refresh failed for account \(accountID.uuidString): \(error.localizedDescription)"
        )
    }

    private static func provider(for providerID: String) throws -> Provider {
        let canonicalID = try canonicalProviderID(providerID)
        let template: ProviderTemplate
        switch canonicalID {
        case "codex":
            template = .codex
        case "codex-xcode":
            template = .codexXcode
        default:
            throw NolonCoreCLIError.invalidArguments("Unsupported --provider: \(providerID)")
        }

        let base = template.createProvider()
        return Provider(
            id: canonicalID,
            kind: base.kind,
            name: base.name,
            projectRootPath: base.projectRootPath,
            defaultSkillsPath: base.defaultSkillsPath,
            workflowPath: base.workflowPath,
            commandPath: base.commandPath,
            iconName: base.iconName,
            installMethod: base.installMethod,
            templateId: base.templateId,
            additionalSkillsPaths: base.additionalSkillsPaths,
            documentationURL: base.documentationURL
        )
    }

    static func defaultGatewayConfigFile(for provider: Provider, environment: [String: String]) -> STFile? {
        let rawSkillsPath = provider.defaultSkillsPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawSkillsPath.isEmpty else { return nil }

        let processHome = NSHomeDirectory()
        let environmentHome = environment["HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedSkillsPath: String
        if let environmentHome, !environmentHome.isEmpty,
           rawSkillsPath == processHome || rawSkillsPath.hasPrefix(processHome + "/") {
            resolvedSkillsPath = environmentHome + rawSkillsPath.dropFirst(processHome.count)
        } else {
            resolvedSkillsPath = rawSkillsPath
        }

        let skillsURL = URL(fileURLWithPath: resolvedSkillsPath, isDirectory: true)
        let configURL = skillsURL.deletingLastPathComponent().appendingPathComponent("config.toml")
        return STFile(configURL)
    }

    private static func gatewayAuthProvider(from provider: Provider, configFile: STFile) -> Provider {
        let codexHomePath = configFile
            .url
            .deletingLastPathComponent()
            .standardizedFileURL
            .path
        return Provider(
            id: provider.id,
            kind: provider.kind,
            name: provider.name,
            projectRootPath: provider.projectRootPath,
            defaultSkillsPath: URL(fileURLWithPath: codexHomePath, isDirectory: true)
                .appendingPathComponent("skills", isDirectory: true)
                .path,
            workflowPath: provider.workflowPath,
            commandPath: provider.commandPath,
            iconName: provider.iconName,
            installMethod: provider.installMethod,
            templateId: provider.templateId,
            additionalSkillsPaths: provider.additionalSkillsPaths,
            documentationURL: provider.documentationURL
        )
    }

    private static func canonicalProviderID(_ providerID: String) throws -> String {
        let normalized = providerID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "codex":
            return "codex"
        case "codexxcode", "codex-xcode":
            return "codex-xcode"
        default:
            throw NolonCoreCLIError.invalidArguments("Unsupported --provider: \(providerID)")
        }
    }

    private static func loadEmail(for account: CodexAuthAccount, authManager: CodexAuthManager) -> String? {
        guard let data = authManager.accountAuthData(for: account), !data.isEmpty else { return nil }
        let summary = CodexAuthSummary.fromJSONData(data)
        return summary.email
    }

    private static func loadSummary(for account: CodexAuthAccount, authManager: CodexAuthManager) -> CodexAuthSummary {
        guard let data = authManager.accountAuthData(for: account),
              !data.isEmpty
        else { return CodexAuthSummary() }
        return CodexAuthSummary.fromJSONData(data)
    }

    private static func makeUsageDisplay(from cache: CodexAuthUsageCache?) -> String? {
        guard let cache else { return nil }
        let primary = cache.usage.primary.map { Int($0.remainingPercent.rounded()) }
        let secondary = cache.usage.secondary.map { Int($0.remainingPercent.rounded()) }
        let left = primary.map { "\($0)%" } ?? "-"
        let right = secondary.map { "\($0)%" } ?? "-"
        return "5h \(left) / 7d \(right)"
    }

    private static func remainingPercent(_ window: RateWindow?) -> Int? {
        guard let window else { return nil }
        return Int(window.remainingPercent.rounded())
    }

    private static func average(of values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        let sum = values.reduce(0, +)
        return Int((Double(sum) / Double(values.count)).rounded())
    }

    private static func resolveRefreshTime(from cache: CodexAuthUsageCache?) -> Date? {
        guard let cache else { return nil }
        return cache.creditsRefreshedAt ?? cache.usage.updatedAt
    }

    private static func resolveAuthTokenInfo(for account: CodexAuthAccount, authManager: CodexAuthManager) -> (expiresAt: Date?, hasRefreshToken: Bool?) {
        guard let data = authManager.accountAuthData(for: account),
              !data.isEmpty
        else { return (nil, nil) }
        return parseAuthTokenInfo(fromAuthData: data)
    }

    private static func resolveSyncFailureInfo(for account: CodexAuthAccount, authManager: CodexAuthManager) -> (failedAt: Date?, message: String?) {
        guard let data = authManager.accountAuthData(for: account),
              !data.isEmpty
        else { return (nil, nil) }
        let summary = CodexAuthSummary.fromJSONData(data)
        return (summary.lastSyncFailedAt, summary.lastSyncFailureMessage)
    }

    private static func parseAuthTokenInfo(fromAuthData data: Data) -> (expiresAt: Date?, hasRefreshToken: Bool?) {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return (nil, nil) }
        let tokens = root["tokens"] as? [String: Any]
        let hasRefreshToken = parseString(tokens?["refresh_token"])
            ?? parseString(tokens?["refreshToken"])
            ?? parseString(root["refresh_token"])
            ?? parseString(root["refreshToken"])
        let expiry = parseExpiryDate(root: root, tokens: tokens)
        return (expiry, hasRefreshToken != nil)
    }

    private static func parseExpiryDate(root: [String: Any], tokens: [String: Any]?) -> Date? {
        let directCandidates: [Date?] = [
            parseDateCandidate(root["expires_at"]),
            parseDateCandidate(root["expiresAt"]),
            parseDateCandidate(tokens?["expires_at"]),
            parseDateCandidate(tokens?["expiresAt"]),
        ]
        if let direct = directCandidates.compactMap({ $0 }).first {
            return direct
        }

        let baseTime = parseDateCandidate(root["last_refresh"])
            ?? parseDateCandidate(root["lastRefresh"])
        let expiresIn = parseTimeIntervalSeconds(root["expires_in"])
            ?? parseTimeIntervalSeconds(root["expiresIn"])
            ?? parseTimeIntervalSeconds(tokens?["expires_in"])
            ?? parseTimeIntervalSeconds(tokens?["expiresIn"])
        if let baseTime, let expiresIn {
            return baseTime.addingTimeInterval(expiresIn)
        }

        let idToken = parseString(tokens?["id_token"])
            ?? parseString(tokens?["idToken"])
            ?? parseString(root["id_token"])
            ?? parseString(root["idToken"])
        if let idToken, let jwtExpiry = parseJWTExpiry(jwt: idToken) {
            return jwtExpiry
        }

        return nil
    }

    private static func parseJWTExpiry(jwt: String) -> Date? {
        let parts = jwt.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 2 else { return nil }
        guard let payloadData = base64URLDecode(String(parts[1])),
              let payload = (try? JSONSerialization.jsonObject(with: payloadData)) as? [String: Any]
        else { return nil }
        return parseDateCandidate(payload["exp"])
    }

    private static func base64URLDecode(_ raw: String) -> Data? {
        var normalized = raw
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = normalized.count % 4
        if remainder != 0 {
            normalized += String(repeating: "=", count: 4 - remainder)
        }
        return Data(base64Encoded: normalized)
    }

    private static func parseTimeIntervalSeconds(_ value: Any?) -> TimeInterval? {
        guard let number = parseNumber(value) else { return nil }
        return TimeInterval(number)
    }

    private static func parseDateCandidate(_ value: Any?) -> Date? {
        guard let value else { return nil }
        if let number = parseNumber(value) {
            let seconds: Double
            if number > 1_000_000_000_000 {
                seconds = number / 1_000
            } else {
                seconds = number
            }
            return Date(timeIntervalSince1970: seconds)
        }

        guard let raw = parseString(value) else { return nil }
        if let seconds = Double(raw) {
            return Date(timeIntervalSince1970: seconds)
        }
        if let date = parseISODate(raw, withFractionalSeconds: true) {
            return date
        }
        return parseISODate(raw, withFractionalSeconds: false)
    }

    private static func parseNumber(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber:
            return number.doubleValue
        case let string as String:
            return Double(string.trimmingCharacters(in: .whitespacesAndNewlines))
        default:
            return nil
        }
    }

    private static func parseString(_ value: Any?) -> String? {
        guard let raw = value as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func parseISODate(_ raw: String, withFractionalSeconds: Bool) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = withFractionalSeconds
            ? [.withInternetDateTime, .withFractionalSeconds]
            : [.withInternetDateTime]
        return formatter.date(from: raw)
    }

    private static func isCodexRuntimeCommand(_ command: String) -> Bool {
        if isNolonCodexCLICommand(command) {
            return false
        }
        let normalized = command.lowercased()
        return normalized.contains("codex-app-server") || normalized.contains("codex")
    }

    private static func isNolonCodexCLICommand(_ command: String) -> Bool {
        let normalized = command.lowercased()
        return normalized.contains("nolon codex ")
    }

    private static func providerHint(from command: String) -> String? {
        let normalized = command.lowercased()
        if normalized.contains("codex-xcode") || normalized.contains("codexxcode") {
            return "codex-xcode"
        }
        if normalized.contains("codex") {
            return "codex"
        }
        return nil
    }

    private static func resolveCLIInOfficialPaths(named executable: String) -> String? {
        let candidates = [
            "/opt/homebrew/bin/\(executable)",
            "/usr/local/bin/\(executable)",
            "/usr/bin/\(executable)",
        ]

        for path in candidates {
            let candidate = STPath(path)
            guard candidate.isExists, candidate.permission.contains(.executable) else { continue }
            return candidate.url.standardizedFileURL.path
        }
        return nil
    }
}
