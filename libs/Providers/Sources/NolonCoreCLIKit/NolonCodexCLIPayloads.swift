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

public enum NolonCodexSessionListGrouping: String, Codable, Sendable, Equatable, CaseIterable, ExpressibleByArgument {
    case provider
    case timeProject = "time-project"
}

public protocol NolonCodexCLIServing: Sendable {
    func authList(providerID: String) async throws -> NolonCodexAuthListPayload
    func authUsage(providerID: String) async throws -> NolonCodexAuthUsagePayload
    func authUsageTrend(providerID: String, range: NolonCodexUsageTrendRange) async throws -> NolonCodexAuthUsageTrendPayload
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
    func sessionList(
        providerID: String,
        groupBy: NolonCodexSessionListGrouping
    ) async throws -> NolonCodexSessionListPayload
    func sessionBenchmark(providerID: String) async throws -> NolonCodexSessionBenchmarkPayload
    func sessionPreviewRewrite(
        providerID: String,
        requestSource: NolonCodexSessionSelectionSource,
        targetProviderID: String
    ) async throws -> NolonCodexSessionRewritePreviewPayload
    func sessionRewrite(
        providerID: String,
        requestSource: NolonCodexSessionSelectionSource,
        targetProviderID: String
    ) async throws -> NolonCodexSessionRewritePayload
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
                    status: .pending,
                    failureType: nil,
                    isSkipped: false,
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
            ),
            refreshOrder: [],
            skippedAccounts: []
        )
    }

    func authUsageTrend(providerID: String, range: NolonCodexUsageTrendRange) async throws -> NolonCodexAuthUsageTrendPayload {
        let trailingDays: Int? = switch range {
        case .days7: 7
        case .days30: 30
        case .all: nil
        }
        let snapshot = try await CodexTokenTrendService().fetchGlobalSnapshot(trailingDays: trailingDays)
        return NolonCodexAuthUsageTrendPayload(
            providerID: providerID,
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

    func sessionList(
        providerID: String,
        groupBy: NolonCodexSessionListGrouping
    ) async throws -> NolonCodexSessionListPayload {
        _ = groupBy
        throw NolonCoreCLIError.domainFailed(
            code: "unsupported_command",
            message: "Session list is not supported by this Codex CLI service."
        )
    }

    func sessionList(providerID: String) async throws -> NolonCodexSessionListPayload {
        try await sessionList(providerID: providerID, groupBy: .provider)
    }

    func sessionBenchmark(providerID: String) async throws -> NolonCodexSessionBenchmarkPayload {
        _ = providerID
        throw NolonCoreCLIError.domainFailed(
            code: "unsupported_command",
            message: "Session benchmark is not supported by this Codex CLI service."
        )
    }

    func sessionPreviewRewrite(
        providerID: String,
        requestSource: NolonCodexSessionSelectionSource,
        targetProviderID: String
    ) async throws -> NolonCodexSessionRewritePreviewPayload {
        _ = providerID
        _ = requestSource
        _ = targetProviderID
        throw NolonCoreCLIError.domainFailed(
            code: "unsupported_command",
            message: "Session preview rewrite is not supported by this Codex CLI service."
        )
    }

    func sessionRewrite(
        providerID: String,
        requestSource: NolonCodexSessionSelectionSource,
        targetProviderID: String
    ) async throws -> NolonCodexSessionRewritePayload {
        _ = providerID
        _ = requestSource
        _ = targetProviderID
        throw NolonCoreCLIError.domainFailed(
            code: "unsupported_command",
            message: "Session rewrite is not supported by this Codex CLI service."
        )
    }

}

public enum NolonCodexUsageTrendRange: String, Codable, Sendable, Equatable {
    case days7 = "7d"
    case days30 = "30d"
    case all = "all"
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
    public enum Status: String, Codable, Sendable, Equatable {
        case pending
        case healthy
        case failed
        case needsReauth = "needs_reauth"
        case skipped
    }

    public enum FailureType: String, Codable, Sendable, Equatable {
        case auth
        case other
    }

    public let id: UUID
    public let email: String?
    public let isActive: Bool
    public let status: Status
    public let failureType: FailureType?
    public let isSkipped: Bool
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
    public let syncFailedAt: Date?
    public let syncFailureMessage: String?

    public init(
        id: UUID,
        email: String?,
        isActive: Bool,
        status: Status = .pending,
        failureType: FailureType? = nil,
        isSkipped: Bool = false,
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
        refreshedAt: Date?,
        syncFailedAt: Date? = nil,
        syncFailureMessage: String? = nil
    ) {
        self.id = id
        self.email = email
        self.isActive = isActive
        self.status = status
        self.failureType = failureType
        self.isSkipped = isSkipped
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
        self.syncFailedAt = syncFailedAt
        self.syncFailureMessage = syncFailureMessage
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
    public struct RefreshStep: Codable, Sendable, Equatable {
        public let accountID: UUID
        public let order: Int
    }

    public struct SkippedAccount: Codable, Sendable, Equatable {
        public let accountID: UUID
        public let reason: String
    }

    public let providerID: String
    public let accounts: [NolonCodexAuthUsageAccountView]
    public let summary: NolonCodexAuthUsageSummaryView
    public let refreshOrder: [RefreshStep]
    public let skippedAccounts: [SkippedAccount]

    public init(
        providerID: String,
        accounts: [NolonCodexAuthUsageAccountView],
        summary: NolonCodexAuthUsageSummaryView,
        refreshOrder: [RefreshStep] = [],
        skippedAccounts: [SkippedAccount] = []
    ) {
        self.providerID = providerID
        self.accounts = accounts
        self.summary = summary
        self.refreshOrder = refreshOrder
        self.skippedAccounts = skippedAccounts
    }
}

public struct NolonCodexAuthUsageTrendPointView: Codable, Sendable, Equatable {
    public let date: String
    public let totalTokens: Int
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheReadTokens: Int
}

public struct NolonCodexAuthUsageTrendSummaryView: Codable, Sendable, Equatable {
    public let todayTokens: Int?
    public let last7DaysTokens: Int?
    public let last30DaysTokens: Int?
}

public struct NolonCodexAuthUsageTrendPayload: Codable, Sendable, Equatable {
    public let providerID: String
    public let range: NolonCodexUsageTrendRange
    public let sourceLabel: String
    public let updatedAt: Date
    public let points: [NolonCodexAuthUsageTrendPointView]
    public let summary: NolonCodexAuthUsageTrendSummaryView
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
}

public struct NolonCodexAuthLoginPayload: Codable, Sendable, Equatable {
    public let providerID: String
    public let accountID: UUID
    public let accountName: String
    public let loginURL: String?
}

public struct NolonCodexAuthRefreshItemView: Codable, Sendable, Equatable {
    public let accountID: UUID
    public let accountName: String
    public let email: String?
    public let isActive: Bool
    public let success: Bool
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

public enum NolonCodexSessionSelectionSource: Codable, Sendable, Equatable {
    case threadIDs([String])
    case modelProvider(String)
}

public struct NolonCodexSessionRowView: Codable, Sendable, Equatable {
    public let id: String
    public let threadID: String?
    public let title: String
    public let summary: String?
    public let modelProvider: String
    public let archived: Bool
    public let rolloutPath: String
    public let cwd: String?
    public let updatedAt: Date?
    public let stateRowCount: Int
    public let editable: Bool

    public init(
        id: String,
        threadID: String?,
        title: String,
        summary: String?,
        modelProvider: String,
        archived: Bool,
        rolloutPath: String,
        cwd: String?,
        updatedAt: Date?,
        stateRowCount: Int,
        editable: Bool
    ) {
        self.id = id
        self.threadID = threadID
        self.title = title
        self.summary = summary
        self.modelProvider = modelProvider
        self.archived = archived
        self.rolloutPath = rolloutPath
        self.cwd = cwd
        self.updatedAt = updatedAt
        self.stateRowCount = stateRowCount
        self.editable = editable
    }
}

public struct NolonCodexSessionSectionView: Codable, Sendable, Equatable {
    public let id: String
    public let modelProvider: String
    public let title: String
    public let sourceProviderID: String?
    public let providerIDs: [String]
    public let sessions: [NolonCodexSessionRowView]
    public let totalSessionCount: Int
    public let editableThreadIDs: [String]
    public let liveCount: Int
    public let archivedCount: Int

    public init(
        id: String? = nil,
        modelProvider: String,
        title: String? = nil,
        sourceProviderID: String? = nil,
        providerIDs: [String]? = nil,
        sessions: [NolonCodexSessionRowView],
        totalSessionCount: Int,
        editableThreadIDs: [String],
        liveCount: Int,
        archivedCount: Int
    ) {
        let resolvedTitle = title ?? modelProvider
        let resolvedProviderIDs = providerIDs ?? [modelProvider]
        self.id = id ?? resolvedTitle
        self.modelProvider = modelProvider
        self.title = resolvedTitle
        self.sourceProviderID = sourceProviderID ?? (resolvedProviderIDs.count == 1 ? resolvedProviderIDs.first : nil)
        self.providerIDs = resolvedProviderIDs
        self.sessions = sessions
        self.totalSessionCount = totalSessionCount
        self.editableThreadIDs = editableThreadIDs
        self.liveCount = liveCount
        self.archivedCount = archivedCount
    }
}

public struct NolonCodexSessionListPayload: Codable, Sendable, Equatable {
    public let providerID: String
    public let groupBy: NolonCodexSessionListGrouping
    public let availableTargetProviderIDs: [String]
    public let sections: [NolonCodexSessionSectionView]
    public let totalSessionCount: Int
    public let totalLiveCount: Int
    public let totalArchivedCount: Int

    public init(
        providerID: String,
        groupBy: NolonCodexSessionListGrouping = .provider,
        availableTargetProviderIDs: [String],
        sections: [NolonCodexSessionSectionView],
        totalSessionCount: Int,
        totalLiveCount: Int,
        totalArchivedCount: Int
    ) {
        self.providerID = providerID
        self.groupBy = groupBy
        self.availableTargetProviderIDs = availableTargetProviderIDs
        self.sections = sections
        self.totalSessionCount = totalSessionCount
        self.totalLiveCount = totalLiveCount
        self.totalArchivedCount = totalArchivedCount
    }
}

public struct NolonCodexSessionBenchmarkRunView: Codable, Sendable, Equatable {
    public let label: String
    public let inventoryCacheEnabled: Bool
    public let skeletonElapsedMs: Int
    public let streamElapsedMs: Int
    public let snapshotElapsedMs: Int
    public let totalElapsedMs: Int
    public let projectCount: Int
    public let streamedSessionCount: Int
    public let snapshotSessionCount: Int
}

public struct NolonCodexSessionBenchmarkPayload: Codable, Sendable, Equatable {
    public let providerID: String
    public let codexHomePath: String
    public let runs: [NolonCodexSessionBenchmarkRunView]
}

public struct NolonCodexSessionRewritePreviewView: Codable, Sendable, Equatable {
    public let sessionCount: Int
    public let liveSessionCount: Int
    public let archivedSessionCount: Int
    public let stateRowCount: Int
}

public struct NolonCodexSessionRewritePreviewPayload: Codable, Sendable, Equatable {
    public let providerID: String
    public let sourceLabel: String
    public let targetProviderID: String
    public let threadIDs: [String]
    public let preview: NolonCodexSessionRewritePreviewView
}

public struct NolonCodexSessionRewriteResultView: Codable, Sendable, Equatable {
    public let preview: NolonCodexSessionRewritePreviewView
    public let liveRolloutFilesUpdated: Int
    public let archivedRolloutFilesUpdated: Int
    public let stateRowsUpdated: Int
    public let failures: [String]
}

public struct NolonCodexSessionRewritePayload: Codable, Sendable, Equatable {
    public let providerID: String
    public let sourceLabel: String
    public let targetProviderID: String
    public let threadIDs: [String]
    public let result: NolonCodexSessionRewriteResultView
}

public struct NolonCodexRuntimeProcessView: Codable, Sendable, Equatable {
    public let pid: Int32
    public let ppid: Int32?
    public let elapsed: String
    public let providerHint: String?
    public let command: String
    public let workingDirectory: String?

    public init(
        pid: Int32,
        ppid: Int32?,
        elapsed: String,
        providerHint: String?,
        command: String,
        workingDirectory: String? = nil
    ) {
        self.pid = pid
        self.ppid = ppid
        self.elapsed = elapsed
        self.providerHint = providerHint
        self.command = command
        self.workingDirectory = workingDirectory
    }
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
