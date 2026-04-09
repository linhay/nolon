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
    func providerList() async throws -> NolonProviderListPayload
    func providerDiscover() async throws -> NolonCodexProviderDiscoverPayload
    func runtimeList(providerID: String?) async throws -> NolonCodexRuntimeListPayload
    func runtimeStop(pid: Int32, force: Bool, timeoutSeconds: Int) async throws -> NolonCodexRuntimeStopPayload
    func gatewayStatus(providerID: String) async throws -> NolonCodexGatewayStatusPayload
    func gatewayStart(providerID: String, host: String, port: Int) async throws -> NolonCodexGatewaySetPayload
    func gatewayStop(providerID: String) async throws -> NolonCodexGatewaySetPayload
    func gatewayServe(providerID: String, host: String, port: Int) async throws
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

    func gatewayStatus(providerID: String) async throws -> NolonCodexGatewayStatusPayload {
        let canonicalProviderID = providerID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return NolonCodexGatewayStatusPayload(
            providerID: canonicalProviderID,
            status: .stopped,
            host: "127.0.0.1",
            port: 8080,
            startedAt: nil
        )
    }

    func gatewayStart(providerID: String, host: String, port: Int) async throws -> NolonCodexGatewaySetPayload {
        let canonicalProviderID = providerID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return NolonCodexGatewaySetPayload(
            providerID: canonicalProviderID,
            status: .running,
            host: host,
            port: port,
            startedAt: Date()
        )
    }

    func gatewayStop(providerID: String) async throws -> NolonCodexGatewaySetPayload {
        let canonicalProviderID = providerID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return NolonCodexGatewaySetPayload(
            providerID: canonicalProviderID,
            status: .stopped,
            host: "127.0.0.1",
            port: 8080,
            startedAt: nil
        )
    }

    func gatewayServe(providerID: String, host: String, port: Int) async throws {
        _ = providerID
        _ = host
        _ = port
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

public struct NolonCodexGatewayStatusPayload: Codable, Sendable, Equatable {
    public let providerID: String
    public let status: CodexGatewayRuntimeStatus
    public let host: String
    public let port: Int
    public let startedAt: Date?
}

public struct NolonCodexGatewaySetPayload: Codable, Sendable, Equatable {
    public let providerID: String
    public let status: CodexGatewayRuntimeStatus
    public let host: String
    public let port: Int
    public let startedAt: Date?
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
