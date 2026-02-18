import ArgumentParser
import CodexAppServerKit
import CodexCLIKit
import CodexProvider
import Foundation
import ProviderCatalog
import ProviderUsage
import SKProcessRunner
import STFilePath
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public protocol NolonCodexCLIServing: Sendable {
    func authList(providerID: String) async throws -> NolonCodexAuthListPayload
    func authUsage(providerID: String) async throws -> NolonCodexAuthUsagePayload
    func authUsageRefresh(providerID: String, accountID: UUID?) async throws -> NolonCodexAuthUsagePayload
    func authStatus(providerID: String) async throws -> NolonCodexAuthStatusPayload
    func authRefresh(providerID: String, accountID: UUID?) async throws -> NolonCodexAuthRefreshPayload
    func authActivate(providerID: String, accountID: UUID) async throws -> NolonCodexAuthActivatePayload
    func authLogin(providerID: String, preferredAccountID: UUID?) async throws -> NolonCodexAuthLoginPayload
    func authDelete(providerID: String, accountID: UUID) async throws -> NolonCodexAuthDeletePayload
    func binaryList() async throws -> NolonCodexBinaryListPayload
    func binaryAvailable() async throws -> NolonCodexBinaryAvailablePayload
    func binaryCurrent() async throws -> NolonCodexBinaryCurrentPayload
    func binaryInstall(version: String, setDefault: Bool) async throws -> NolonCodexBinaryInstallPayload
    func binaryUse(version: String) async throws -> NolonCodexBinaryUsePayload
    func binaryDoctor() async throws -> NolonCodexBinaryDoctorPayload
    func statusProbe(providerID: String?) async throws -> NolonCodexStatusProbePayload
    func providerList() async throws -> NolonProviderListPayload
    func providerDiscover() async throws -> NolonCodexProviderDiscoverPayload
    func runtimeList(providerID: String?) async throws -> NolonCodexRuntimeListPayload
    func runtimeStop(pid: Int32, force: Bool, timeoutSeconds: Int) async throws -> NolonCodexRuntimeStopPayload
}

public extension NolonCodexCLIServing {
    func authUsageRefresh(providerID: String, accountID: UUID?) async throws -> NolonCodexAuthUsagePayload {
        _ = accountID
        return try await authUsage(providerID: providerID)
    }

    func authRefresh(providerID: String, accountID: UUID?) async throws -> NolonCodexAuthRefreshPayload {
        let login = try await authLogin(providerID: providerID, preferredAccountID: accountID)
        let item = NolonCodexAuthRefreshItemView(
            accountID: login.accountID,
            accountName: login.accountName,
            email: nil,
            isActive: false,
            success: true,
            runtimeSwitched: login.runtimeSwitched,
            runtimeErrorDescription: login.runtimeErrorDescription,
            errorCode: nil,
            errorMessage: nil
        )
        return NolonCodexAuthRefreshPayload(
            providerID: login.providerID,
            items: [item],
            summary: NolonCodexAuthRefreshSummaryView(totalCount: 1, successCount: 1, failureCount: 0)
        )
    }

    func authUsage(providerID: String) async throws -> NolonCodexAuthUsagePayload {
        let list = try await authList(providerID: providerID)
        return NolonCodexAuthUsagePayload(
            providerID: list.providerID,
            accounts: list.accounts.map { account in
                NolonCodexAuthUsageAccountView(
                    id: account.id,
                    email: account.email,
                    isActive: account.isActive,
                    usageSource: nil,
                    fiveHourRemainingPercent: nil,
                    weeklyRemainingPercent: nil,
                    token1dCount: nil,
                    token30dCount: nil,
                    tokenAllCount: nil,
                    expiresAt: nil,
                    hasRefreshToken: nil,
                    refreshedAt: account.refreshedAt
                )
            },
            summary: NolonCodexAuthUsageSummaryView(
                accountCount: list.accounts.count,
                cachedCount: 0,
                avgFiveHourRemainingPercent: nil,
                avgWeeklyRemainingPercent: nil,
                totalToken1dCount: nil,
                totalToken30dCount: nil,
                totalTokenAllCount: nil,
                earliestExpiresAt: nil,
                latestRefreshedAt: list.accounts.compactMap(\.refreshedAt).max()
            )
        )
    }
}

public struct NolonCodexAuthAccountView: Codable, Sendable, Equatable {
    public let id: UUID
    public let name: String
    public let createdAt: Date
    public let relativeAuthPath: String
    public let isActive: Bool
    public let email: String?
    public let usageDisplay: String?
    public let refreshedAt: Date?
}

public struct NolonCodexAuthListPayload: Codable, Sendable, Equatable {
    public let providerID: String
    public let activeAccountID: UUID?
    public let accounts: [NolonCodexAuthAccountView]
}

public struct NolonCodexAuthUsageAccountView: Codable, Sendable, Equatable {
    public let id: UUID
    public let email: String?
    public let isActive: Bool
    public let usageSource: String?
    public let fiveHourRemainingPercent: Int?
    public let weeklyRemainingPercent: Int?
    public let token1dCount: Int?
    public let token7dCount: Int?
    public let token14dCount: Int?
    public let token30dCount: Int?
    public let tokenAllCount: Int?
    public let expiresAt: Date?
    public let hasRefreshToken: Bool?
    public let refreshedAt: Date?

    public init(
        id: UUID,
        email: String?,
        isActive: Bool,
        usageSource: String? = nil,
        fiveHourRemainingPercent: Int?,
        weeklyRemainingPercent: Int?,
        token1dCount: Int? = nil,
        token7dCount: Int? = nil,
        token14dCount: Int? = nil,
        token30dCount: Int? = nil,
        tokenAllCount: Int? = nil,
        expiresAt: Date? = nil,
        hasRefreshToken: Bool? = nil,
        refreshedAt: Date?
    ) {
        self.id = id
        self.email = email
        self.isActive = isActive
        self.usageSource = usageSource
        self.fiveHourRemainingPercent = fiveHourRemainingPercent
        self.weeklyRemainingPercent = weeklyRemainingPercent
        self.token1dCount = token1dCount
        self.token7dCount = token7dCount
        self.token14dCount = token14dCount
        self.token30dCount = token30dCount
        self.tokenAllCount = tokenAllCount
        self.expiresAt = expiresAt
        self.hasRefreshToken = hasRefreshToken
        self.refreshedAt = refreshedAt
    }
}

public struct NolonCodexAuthUsageSummaryView: Codable, Sendable, Equatable {
    public let accountCount: Int
    public let cachedCount: Int
    public let avgFiveHourRemainingPercent: Int?
    public let avgWeeklyRemainingPercent: Int?
    public let totalToken1dCount: Int?
    public let totalToken7dCount: Int?
    public let totalToken14dCount: Int?
    public let totalToken30dCount: Int?
    public let totalTokenAllCount: Int?
    public let earliestExpiresAt: Date?
    public let latestRefreshedAt: Date?

    public init(
        accountCount: Int,
        cachedCount: Int,
        avgFiveHourRemainingPercent: Int?,
        avgWeeklyRemainingPercent: Int?,
        totalToken1dCount: Int? = nil,
        totalToken7dCount: Int? = nil,
        totalToken14dCount: Int? = nil,
        totalToken30dCount: Int? = nil,
        totalTokenAllCount: Int? = nil,
        earliestExpiresAt: Date? = nil,
        latestRefreshedAt: Date?
    ) {
        self.accountCount = accountCount
        self.cachedCount = cachedCount
        self.avgFiveHourRemainingPercent = avgFiveHourRemainingPercent
        self.avgWeeklyRemainingPercent = avgWeeklyRemainingPercent
        self.totalToken1dCount = totalToken1dCount
        self.totalToken7dCount = totalToken7dCount
        self.totalToken14dCount = totalToken14dCount
        self.totalToken30dCount = totalToken30dCount
        self.totalTokenAllCount = totalTokenAllCount
        self.earliestExpiresAt = earliestExpiresAt
        self.latestRefreshedAt = latestRefreshedAt
    }
}

public struct NolonCodexAuthUsagePayload: Codable, Sendable, Equatable {
    public let providerID: String
    public let accounts: [NolonCodexAuthUsageAccountView]
    public let summary: NolonCodexAuthUsageSummaryView
}

public struct NolonCodexAuthStatusPayload: Codable, Sendable, Equatable {
    public let providerID: String
    public let activeAccountID: UUID?
    public let accountCount: Int
    public let authHashHex: String?
    public let usageCachedAccountCount: Int
    public let usageAvgFiveHourRemainingPercent: Int?
    public let usageAvgWeeklyRemainingPercent: Int?
    public let usageLatestRefreshedAt: Date?

    public init(
        providerID: String,
        activeAccountID: UUID?,
        accountCount: Int,
        authHashHex: String?,
        usageCachedAccountCount: Int = 0,
        usageAvgFiveHourRemainingPercent: Int? = nil,
        usageAvgWeeklyRemainingPercent: Int? = nil,
        usageLatestRefreshedAt: Date? = nil
    ) {
        self.providerID = providerID
        self.activeAccountID = activeAccountID
        self.accountCount = accountCount
        self.authHashHex = authHashHex
        self.usageCachedAccountCount = usageCachedAccountCount
        self.usageAvgFiveHourRemainingPercent = usageAvgFiveHourRemainingPercent
        self.usageAvgWeeklyRemainingPercent = usageAvgWeeklyRemainingPercent
        self.usageLatestRefreshedAt = usageLatestRefreshedAt
    }
}

public struct NolonCodexAuthActivatePayload: Codable, Sendable, Equatable {
    public let providerID: String
    public let accountID: UUID
    public let runtimeSwitched: Bool
    public let runtimeErrorDescription: String?
}

public struct NolonCodexAuthLoginPayload: Codable, Sendable, Equatable {
    public let providerID: String
    public let accountID: UUID
    public let accountName: String
    public let runtimeSwitched: Bool
    public let runtimeErrorDescription: String?
    public let loginURL: String?
}

public struct NolonCodexAuthRefreshItemView: Codable, Sendable, Equatable {
    public let accountID: UUID
    public let accountName: String
    public let email: String?
    public let isActive: Bool
    public let success: Bool
    public let runtimeSwitched: Bool
    public let runtimeErrorDescription: String?
    public let errorCode: String?
    public let errorMessage: String?
}

public struct NolonCodexAuthRefreshSummaryView: Codable, Sendable, Equatable {
    public let totalCount: Int
    public let successCount: Int
    public let failureCount: Int
}

public struct NolonCodexAuthRefreshPayload: Codable, Sendable, Equatable {
    public let providerID: String
    public let items: [NolonCodexAuthRefreshItemView]
    public let summary: NolonCodexAuthRefreshSummaryView
}

public struct NolonCodexAuthDeletePayload: Codable, Sendable, Equatable {
    public let providerID: String
    public let accountID: UUID
    public let wasActive: Bool
}

public struct NolonCodexManagedVersionView: Codable, Sendable, Equatable {
    public let id: String
    public let displayName: String
    public let detectedVersion: String
    public let source: String
    public let importedAt: Date
    public let isSelected: Bool
}

public struct NolonCodexRemoteVersionView: Codable, Sendable, Equatable {
    public let version: String
    public let tag: String
    public let downloadURL: String
    public let isPrerelease: Bool
}

public struct NolonCodexBinaryListPayload: Codable, Sendable, Equatable {
    public let selectedVersionID: String?
    public let versions: [NolonCodexManagedVersionView]
}

public struct NolonCodexBinaryAvailablePayload: Codable, Sendable, Equatable {
    public let versions: [NolonCodexRemoteVersionView]
}

public struct NolonCodexBinaryCurrentPayload: Codable, Sendable, Equatable {
    public let selectedVersionID: String?
    public let currentVersion: String?
    public let activeCLIPath: String?
}

public struct NolonCodexBinaryInstallPayload: Codable, Sendable, Equatable {
    public let requestedVersion: String
    public let installedVersionID: String
    public let installedDetectedVersion: String
    public let activated: Bool
}

public struct NolonCodexBinaryUsePayload: Codable, Sendable, Equatable {
    public let selectedVersionID: String
}

public struct NolonCodexBinarySwitchPayload: Codable, Sendable, Equatable {
    public let action: String
    public let requestedVersion: String
    public let selectedVersionID: String
}

public struct NolonCodexBinaryDoctorPayload: Codable, Sendable, Equatable {
    public let selectedVersionID: String?
    public let currentVersion: String?
    public let activeCLIPath: String?
    public let managedVersionCount: Int
    public let pathConfigured: Bool
    public let pathActive: Bool
    public let profilePath: String
}

public struct NolonCodexStatusProbePayload: Codable, Sendable, Equatable {
    public let providerID: String?
    public let resolvedExecutable: String?
    public let credits: Double?
    public let fiveHourPercentLeft: Int?
    public let weeklyPercentLeft: Int?
    public let fiveHourResetDescription: String?
    public let weeklyResetDescription: String?
    public let probeWarning: String?
    public let probeHint: String?
}

public struct NolonCodexRuntimeProcessView: Codable, Sendable, Equatable {
    public let pid: Int32
    public let ppid: Int32?
    public let elapsed: String
    public let providerHint: String?
    public let command: String
}

public struct NolonProviderCLIView: Codable, Sendable, Equatable {
    public let providerID: String
    public let name: String
    public let cli: String
    public let installed: Bool
    public let executablePath: String?
}

public struct NolonProviderListPayload: Codable, Sendable, Equatable {
    public let providers: [NolonProviderCLIView]
}

public struct NolonCodexProviderDiscoverView: Codable, Sendable, Equatable {
    public let providerID: String
    public let name: String
    public let templateID: String
    public let codexHomePath: String
    public let authPath: String
    public let authExists: Bool
    public let authIsSymlink: Bool
    public let authSymlinkTargetPath: String?
}

public struct NolonCodexProviderDiscoverPayload: Codable, Sendable, Equatable {
    public let providers: [NolonCodexProviderDiscoverView]
}

public struct NolonCodexRuntimeListPayload: Codable, Sendable, Equatable {
    public let processes: [NolonCodexRuntimeProcessView]
}

public struct NolonCodexRuntimeStopPayload: Codable, Sendable, Equatable {
    public let pid: Int32
    public let requestedSignal: String
    public let didEscalateToKill: Bool
    public let exited: Bool
}

public struct NolonLiveCodexCLIService: NolonCodexCLIServing {
    typealias AuthActivator = @Sendable (CodexAuthAccount, Provider) async throws -> CodexAuthActivationResult
    typealias AuthRefreshRunner = @Sendable (_ providerID: String, _ accountID: UUID, _ environment: [String: String]) async throws -> Void
    typealias UsageOutcomeFetcher = @Sendable (_ environment: [String: String], _ costWindowDays: Int?) async -> ProviderFetchOutcome

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
            }
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
            }
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
        sleep: @escaping @Sendable (UInt64) async throws -> Void
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
        let accounts = try await authManager.loadAccounts()
        if refreshBeforeRead {
            try await refreshUsageCaches(
                accounts: accounts,
                targetAccountID: refreshTargetAccountID
            )
        }
        let activeID = await authManager.activeAccountId(for: provider)

        var views: [NolonCodexAuthUsageAccountView] = []
        views.reserveCapacity(accounts.count)

        for account in accounts {
            let email = Self.loadEmail(for: account, authManager: authManager)
            let usageCache = try? await authManager.loadUsageCache(for: account)
            let authInfo = Self.resolveAuthTokenInfo(for: account, authManager: authManager)
            views.append(
                NolonCodexAuthUsageAccountView(
                    id: account.id,
                    email: email,
                    isActive: account.id == activeID,
                    usageSource: usageCache?.sourceLabel,
                    fiveHourRemainingPercent: Self.remainingPercent(usageCache?.usage.primary),
                    weeklyRemainingPercent: Self.remainingPercent(usageCache?.usage.secondary),
                    token1dCount: Self.resolve1dTokenCount(from: usageCache),
                    token7dCount: Self.resolve7dTokenCount(from: usageCache),
                    token14dCount: Self.resolve14dTokenCount(from: usageCache),
                    token30dCount: Self.resolve30dTokenCount(from: usageCache),
                    tokenAllCount: Self.resolveAllTokenCount(from: usageCache),
                    expiresAt: authInfo.expiresAt,
                    hasRefreshToken: authInfo.hasRefreshToken,
                    refreshedAt: Self.resolveRefreshTime(from: usageCache)
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
            summary: summary
        )
    }

    private func refreshUsageCaches(
        accounts: [CodexAuthAccount],
        targetAccountID: UUID?
    ) async throws {
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
            targets = accounts
        }

        guard !targets.isEmpty else { return }

        var mergedEnvironment = environment
        if let managed = try? await binaryManager.launchEnvironmentVariables() {
            mergedEnvironment.merge(managed) { _, new in new }
        }

        for account in targets {
            let runtimeHome = authManager.runtimeHomeFolder(accountID: account.id)
            _ = runtimeHome.createIfNotExists()
            let runtimeAuth = runtimeHome.file("auth.json")
            let sourceAuth = authManager.accountAuthFile(relativeAuthPath: account.relativeAuthPath)
            let authData = try sourceAuth.data()
            try runtimeAuth.overlay(with: authData)

            var accountEnvironment = mergedEnvironment
            accountEnvironment["CODEX_HOME"] = runtimeHome.url.standardizedFileURL.path

            let outcome = await usageOutcomeFetcher(accountEnvironment, 30)
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
                    cost: result.cost
                )
                try await authManager.storeUsageCache(cache, for: account)
                try await authManager.updateSyncSuccess(for: account, date: now)
            case let .failure(error):
                try await authManager.updateSyncFailure(for: account, message: error.localizedDescription, date: Date())
            }
        }

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
        _ = codexHome.createIfNotExists()
        let isolatedAuthFile = codexHome.file("auth.json")
        if isolatedAuthFile.isExists {
            try isolatedAuthFile.delete()
        }

        let loginResult = try await loginRunner.loginAndAwaitAuthResult(
            binary: "codex",
            environment: environment,
            codexHome: codexHome
        )

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
        try await authManager.deleteAccount(id: accountID)
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
                    command: snapshot.command
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

    private static func liveAuthRefreshRunner(providerID: String, accountID: UUID, environment: [String: String]) async throws {
        _ = providerID
        var runtimeEnvironment = environment
        let runtimeHome = CodexAuthManager(environment: environment).runtimeHomeFolder(accountID: accountID)
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

    private static func liveUsageOutcomeFetcher(environment: [String: String], costWindowDays: Int?) async -> ProviderFetchOutcome {
        let context = ProviderFetchContext(
            provider: .codex,
            sourceMode: .auto,
            includeCredits: true,
            timeout: 20,
            costWindowDays: costWindowDays,
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
        guard let data = try? authManager.accountAuthFile(relativeAuthPath: account.relativeAuthPath).data(), !data.isEmpty else { return nil }
        let summary = CodexAuthSummary.fromJSONData(data)
        return summary.email
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

    private static func resolve1dTokenCount(from cache: CodexAuthUsageCache?) -> Int? {
        cache?.cost?.todayTokens
    }

    private static func resolve30dTokenCount(from cache: CodexAuthUsageCache?) -> Int? {
        cache?.cost?.last30DaysTokens
    }

    private static func resolve7dTokenCount(from cache: CodexAuthUsageCache?) -> Int? {
        resolveWindowTokenCount(days: 7, from: cache)
    }

    private static func resolve14dTokenCount(from cache: CodexAuthUsageCache?) -> Int? {
        resolveWindowTokenCount(days: 14, from: cache)
    }

    private static func resolveAllTokenCount(from cache: CodexAuthUsageCache?) -> Int? {
        guard let cost = cache?.cost else { return nil }
        let fromDaily = cost.dailyCosts?.compactMap(\.tokens).reduce(0, +)
        if let fromDaily, fromDaily > 0 {
            return fromDaily
        }
        return cost.last30DaysTokens
    }

    private static func resolveWindowTokenCount(days: Int, from cache: CodexAuthUsageCache?) -> Int? {
        guard days > 0,
              let daily = cache?.cost?.dailyCosts,
              !daily.isEmpty
        else { return nil }
        let sorted = daily.sorted { $0.date > $1.date }
        let slice = sorted.prefix(days)
        let values = slice.compactMap(\.tokens)
        guard values.count == slice.count, !values.isEmpty else { return nil }
        return values.reduce(0, +)
    }

    private static func resolveAuthTokenInfo(for account: CodexAuthAccount, authManager: CodexAuthManager) -> (expiresAt: Date?, hasRefreshToken: Bool?) {
        guard let data = try? authManager.accountAuthFile(relativeAuthPath: account.relativeAuthPath).data(),
              !data.isEmpty
        else { return (nil, nil) }
        return parseAuthTokenInfo(fromAuthData: data)
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

public enum NolonCLIEntrypoint {
    public static func execute(
        arguments: [String],
        codexService: any NolonCodexCLIServing = NolonLiveCodexCLIService()
    ) async -> NolonCLIExecutionResult {
        let normalizedArguments = normalizeHelpArguments(arguments)
        if let helpText = resolveHelp(arguments: normalizedArguments) {
            return NolonCLIExecutionResult(exitCode: 0, stdout: helpText, stderr: "")
        }

        if shouldRouteToCoreCLI(arguments: normalizedArguments) {
            return await NolonCoreCLIRunner().execute(arguments: normalizedArguments)
        }

        let context = NolonCLIExecutionContext(service: codexService)
        do {
            let output = try await NolonCodexCLIExecutor.execute(arguments: normalizedArguments, context: context)
            return NolonCLIExecutionResult(exitCode: 0, stdout: output, stderr: "")
        } catch is CancellationError {
            let wrapped = NolonCoreCLIError.domainFailed(code: "interrupted", message: "Operation cancelled")
            return NolonCLIExecutionResult(exitCode: 130, stdout: "", stderr: context.errorJSON(for: wrapped))
        } catch let error as NolonCoreCLIError {
            return NolonCLIExecutionResult(exitCode: 2, stdout: "", stderr: context.errorJSON(for: error))
        } catch {
            let message = NolonRootCommand.message(for: error)
            let wrapped = NolonCoreCLIError.invalidArguments(message)
            return NolonCLIExecutionResult(exitCode: 2, stdout: "", stderr: context.errorJSON(for: wrapped))
        }
    }

    private static func shouldRouteToCoreCLI(arguments: [String]) -> Bool {
        guard let root = arguments.first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        else {
            return false
        }
        return root == "skills" || root == "workflow" || root == "mcp" || root == "remote"
    }

    private static func normalizeHelpArguments(_ arguments: [String]) -> [String] {
        guard !arguments.isEmpty else { return [] }
        if arguments[0].lowercased() == "help" {
            if arguments.count == 1 { return [] }
            var forwarded = Array(arguments.dropFirst())
            if forwarded.last == "help" {
                forwarded[forwarded.count - 1] = "--help"
            }
            if !forwarded.contains("--help"), !forwarded.contains("-h") {
                forwarded.append("--help")
            }
            return forwarded
        }
        var normalized = arguments
        if normalized.last == "help" {
            normalized[normalized.count - 1] = "--help"
        }
        if normalized.contains("--help") || normalized.contains("-h") {
            return normalized
        }
        let root = normalized[0].lowercased()
        let groupsNeedingHelp: [String: Set<String>] = [
            "codex": ["auth", "binary", "status", "runtime", "provider"],
            "skills": ["repo", "migrate"],
        ]
        let rootCommands = Set(["codex", "provider", "skills", "workflow", "mcp", "remote"])
        if normalized.count == 1, rootCommands.contains(root) {
            return normalized + ["--help"]
        }
        if normalized.count == 2, let groups = groupsNeedingHelp[root] {
            let group = normalized[1].lowercased()
            if groups.contains(group) {
                return normalized + ["--help"]
            }
        }
        return normalized
    }

    private static func resolveHelp(arguments: [String]) -> String? {
        if arguments.isEmpty {
            return NolonRootCommand.helpMessage()
        }
        let hasHelpFlag = arguments.contains("--help") || arguments.contains("-h")
        guard hasHelpFlag else {
            return nil
        }
        let cleaned = arguments.filter { $0 != "--help" && $0 != "-h" }
        guard let target = helpTargetType(for: cleaned) else {
            return nil
        }
        return NolonRootCommand.message(for: CleanExit.helpRequest(target))
    }

    private static func helpTargetType(for arguments: [String]) -> ParsableCommand.Type? {
        guard let root = arguments.first?.lowercased() else {
            return NolonRootCommand.self
        }
        switch root {
        case "codex":
            guard arguments.count >= 2 else { return NolonCodexRootCommand.self }
            let group = arguments[1].lowercased()
            switch group {
            case "auth":
                guard arguments.count >= 3 else { return NolonCodexAuthGroupCommand.self }
                return codexAuthCommandType(action: arguments[2])
            case "binary":
                guard arguments.count >= 3 else { return NolonCodexBinaryGroupCommand.self }
                return codexBinaryCommandType(action: arguments[2])
            case "status":
                guard arguments.count >= 3 else { return NolonCodexStatusGroupCommand.self }
                return codexStatusCommandType(action: arguments[2])
            case "runtime":
                guard arguments.count >= 3 else { return NolonCodexRuntimeGroupCommand.self }
                return codexRuntimeCommandType(action: arguments[2])
            case "provider":
                guard arguments.count >= 3 else { return NolonCodexProviderGroupCommand.self }
                return codexProviderCommandType(action: arguments[2])
            default:
                return NolonCodexRootCommand.self
            }
        case "provider":
            guard arguments.count >= 2 else { return NolonProviderRootCommand.self }
            return NolonProviderListCommand.self
        case "skills":
            guard arguments.count >= 2 else { return NolonSkillsRootCommand.self }
            let action = arguments[1].lowercased()
            switch action {
            case "repo":
                guard arguments.count >= 3 else { return NolonSkillsRepoGroupCommand.self }
                return skillsRepoCommandType(action: arguments[2])
            case "migrate":
                guard arguments.count >= 3 else { return NolonSkillsMigrateGroupCommand.self }
                return skillsMigrateCommandType(action: arguments[2])
            case "discover":
                return NolonSkillsDiscoverCommand.self
            case "parse":
                return NolonSkillsParseCommand.self
            case "install":
                return NolonSkillsInstallCommand.self
            case "uninstall":
                return NolonSkillsUninstallCommand.self
            default:
                return NolonSkillsRootCommand.self
            }
        case "workflow":
            guard arguments.count >= 2 else { return NolonWorkflowRootCommand.self }
            return workflowCommandType(action: arguments[1])
        case "mcp":
            guard arguments.count >= 2 else { return NolonMcpRootCommand.self }
            return mcpCommandType(action: arguments[1])
        case "remote":
            guard arguments.count >= 2 else { return NolonRemoteRootCommand.self }
            return remoteCommandType(action: arguments[1])
        default:
            return NolonRootCommand.self
        }
    }

    private static func codexAuthCommandType(action: String) -> ParsableCommand.Type? {
        switch action.lowercased() {
        case "list":
            return NolonCodexAuthListCommand.self
        case "usage":
            return NolonCodexAuthUsageCommand.self
        case "status":
            return NolonCodexAuthStatusCommand.self
        case "refresh":
            return NolonCodexAuthRefreshCommand.self
        case "activate":
            return NolonCodexAuthActivateCommand.self
        case "login":
            return NolonCodexAuthLoginCommand.self
        case "delete":
            return NolonCodexAuthDeleteCommand.self
        default:
            return NolonCodexAuthGroupCommand.self
        }
    }

    private static func codexBinaryCommandType(action: String) -> ParsableCommand.Type? {
        switch action.lowercased() {
        case "list":
            return NolonCodexBinaryListCommand.self
        case "current":
            return NolonCodexBinaryCurrentCommand.self
        case "install":
            return NolonCodexBinaryInstallCommand.self
        case "use":
            return NolonCodexBinaryUseCommand.self
        case "available":
            return NolonCodexBinaryAvailableCommand.self
        case "switch":
            return NolonCodexBinarySwitchCommand.self
        case "doctor":
            return NolonCodexBinaryDoctorCommand.self
        default:
            return NolonCodexBinaryGroupCommand.self
        }
    }

    private static func codexStatusCommandType(action: String) -> ParsableCommand.Type? {
        switch action.lowercased() {
        case "probe":
            return NolonCodexStatusProbeCommand.self
        case "doctor":
            return NolonCodexStatusDoctorCommand.self
        default:
            return NolonCodexStatusGroupCommand.self
        }
    }

    private static func codexRuntimeCommandType(action: String) -> ParsableCommand.Type? {
        switch action.lowercased() {
        case "list":
            return NolonCodexRuntimeListCommand.self
        case "stop":
            return NolonCodexRuntimeStopCommand.self
        default:
            return NolonCodexRuntimeGroupCommand.self
        }
    }

    private static func codexProviderCommandType(action: String) -> ParsableCommand.Type? {
        switch action.lowercased() {
        case "discover":
            return NolonCodexProviderDiscoverCommand.self
        default:
            return NolonCodexProviderGroupCommand.self
        }
    }

    private static func skillsRepoCommandType(action: String) -> ParsableCommand.Type? {
        switch action.lowercased() {
        case "plan":
            return NolonSkillsRepoPlanCommand.self
        case "preflight":
            return NolonSkillsRepoPreflightCommand.self
        case "sync":
            return NolonSkillsRepoSyncCommand.self
        default:
            return NolonSkillsRepoGroupCommand.self
        }
    }

    private static func skillsMigrateCommandType(action: String) -> ParsableCommand.Type? {
        switch action.lowercased() {
        case "scan":
            return NolonSkillsMigrateScanCommand.self
        case "apply":
            return NolonSkillsMigrateApplyCommand.self
        default:
            return NolonSkillsMigrateGroupCommand.self
        }
    }

    private static func workflowCommandType(action: String) -> ParsableCommand.Type? {
        switch action.lowercased() {
        case "discover":
            return NolonWorkflowDiscoverCommand.self
        case "install":
            return NolonWorkflowInstallCommand.self
        case "uninstall":
            return NolonWorkflowUninstallCommand.self
        default:
            return NolonWorkflowRootCommand.self
        }
    }

    private static func mcpCommandType(action: String) -> ParsableCommand.Type? {
        switch action.lowercased() {
        case "discover":
            return NolonMcpDiscoverCommand.self
        case "install":
            return NolonMcpInstallCommand.self
        case "uninstall":
            return NolonMcpUninstallCommand.self
        default:
            return NolonMcpRootCommand.self
        }
    }

    private static func remoteCommandType(action: String) -> ParsableCommand.Type? {
        switch action.lowercased() {
        case "list":
            return NolonRemoteListCommand.self
        case "download":
            return NolonRemoteDownloadCommand.self
        case "sync":
            return NolonRemoteSyncCommand.self
        case "install":
            return NolonRemoteInstallCommand.self
        case "sync-install":
            return NolonRemoteSyncInstallCommand.self
        default:
            return NolonRemoteRootCommand.self
        }
    }
}

struct NolonRuntimeProcessSnapshot: Sendable, Equatable {
    let pid: Int32
    let ppid: Int32?
    let elapsed: String
    let command: String
}

protocol NolonCodexRuntimeProcessInspecting: Sendable {
    func listProcesses() throws -> [NolonRuntimeProcessSnapshot]
}

protocol NolonCodexRuntimeSignalControlling: Sendable {
    func send(signal: Int32, to pid: Int32) throws
    func isRunning(pid: Int32) -> Bool
}

struct NolonCodexRuntimeProcessInspector: NolonCodexRuntimeProcessInspecting {
    func listProcesses() throws -> [NolonRuntimeProcessSnapshot] {
        var payload = SKProcessPayload.executableURL(STPath("/bin/ps").url)
        payload.arguments = ["-axo", "pid=,ppid=,etime=,command="]
        payload.throwOnNonZeroExit = false
        payload.timeoutMs = 10_000
        let result = try SKProcessRunner.runSync(payload)

        guard result.exitCode == 0 else {
            let stderr = result.stderr.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            let stdout = result.stdout.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            let message = stderr.isEmpty ? (stdout.isEmpty ? "ps command failed" : stdout) : stderr
            throw NolonCoreCLIError.domainFailed(code: "runtime_ps_failed", message: message)
        }
        let content = result.stdout

        return content
            .split(separator: "\n")
            .compactMap { line in
                let parts = line.split(omittingEmptySubsequences: true, whereSeparator: { $0.isWhitespace })
                guard parts.count >= 4, let pid = Int32(parts[0]), let ppid = Int32(parts[1]) else {
                    return nil
                }
                let elapsed = String(parts[2])
                let command = parts.dropFirst(3).joined(separator: " ")
                return NolonRuntimeProcessSnapshot(pid: pid, ppid: ppid, elapsed: elapsed, command: command)
            }
    }
}

struct NolonCodexRuntimeSignalController: NolonCodexRuntimeSignalControlling {
    func send(signal: Int32, to pid: Int32) throws {
        if kill(pid, signal) != 0 {
            let code = errno
            throw NolonCoreCLIError.domainFailed(
                code: "runtime_signal_failed",
                message: "Failed to send signal \(signal) to pid \(pid), errno=\(code)"
            )
        }
    }

    func isRunning(pid: Int32) -> Bool {
        if kill(pid, 0) == 0 {
            return true
        }
        return errno == EPERM
    }
}
