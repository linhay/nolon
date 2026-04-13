import Foundation
import Testing
@testable import NolonCoreCLIKit
@testable import CodexProvider

@Suite("Nolon Codex CLI Entrypoint")
struct NolonCodexCLIEntrypointTests {
































































































































}

extension String {
    func indicesOfPipes() -> [Int] {
        enumerated().compactMap { index, char in char == "|" ? index : nil }
    }
}

actor MockCodexCLIService: NolonCodexCLIServing {
    private var call: String?
    private var sessionRequestSource: NolonCodexSessionSelectionSource?
    private var sessionListGrouping: NolonCodexSessionListGrouping?

    func lastCall() -> String? { call }
    func lastSessionRequestSource() -> NolonCodexSessionSelectionSource? { sessionRequestSource }
    func lastSessionListGrouping() -> NolonCodexSessionListGrouping? { sessionListGrouping }

    func authList(providerID: String) async throws -> NolonCodexAuthListPayload {
        call = "authList"
        return NolonCodexAuthListPayload(
            providerID: providerID,
            activeAccountID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            accounts: [
                NolonCodexAuthAccountView(
                    id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                    name: "mock",
                    createdAt: Date(timeIntervalSince1970: 0),
                    relativeAuthPath: "auth/mock.json",
                    isActive: true,
                    email: "mock@example.com",
                    usageDisplay: nil,
                    refreshedAt: nil
                )
            ]
        )
    }

    func authStatus(providerID: String) async throws -> NolonCodexAuthStatusPayload {
        call = "authStatus"
        return NolonCodexAuthStatusPayload(providerID: providerID, activeAccountID: nil, accountCount: 0, authHashHex: nil)
    }

    func authUsage(providerID: String) async throws -> NolonCodexAuthUsagePayload {
        call = "authUsage"
        return NolonCodexAuthUsagePayload(
            providerID: providerID,
            accounts: [
                NolonCodexAuthUsageAccountView(
                    id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                    email: "mock@example.com",
                    isActive: true,
                    fiveHourRemainingPercent: 75,
                    weeklyRemainingPercent: 44,
                    token1dCount: 1_200_000,
                    token30dCount: 24_000_000,
                    tokenAllCount: 50_000_000,
                    expiresAt: Date(timeIntervalSince1970: 1_798_704_000),
                    refreshedAt: Date(timeIntervalSince1970: 1_734_000_000)
                )
            ],
            summary: NolonCodexAuthUsageSummaryView(
                accountCount: 1,
                cachedCount: 1,
                avgFiveHourRemainingPercent: 75,
                avgWeeklyRemainingPercent: 44,
                totalToken1dCount: 1_200_000,
                totalToken30dCount: 24_000_000,
                totalTokenAllCount: 50_000_000,
                earliestExpiresAt: Date(timeIntervalSince1970: 1_798_704_000),
                latestRefreshedAt: Date(timeIntervalSince1970: 1_734_000_000)
            )
        )
    }

    func authUsageTrend(providerID: String, range: NolonCodexUsageTrendRange) async throws -> NolonCodexAuthUsageTrendPayload {
        call = "authUsageTrend"
        return NolonCodexAuthUsageTrendPayload(
            providerID: providerID,
            range: range,
            sourceLabel: "global",
            updatedAt: Date(timeIntervalSince1970: 0),
            points: [
                NolonCodexAuthUsageTrendPointView(
                    date: "2026-02-26",
                    totalTokens: 2_500_000,
                    inputTokens: 1_200_000,
                    outputTokens: 800_000,
                    cacheReadTokens: 500_000
                ),
                NolonCodexAuthUsageTrendPointView(
                    date: "2026-02-25",
                    totalTokens: 1_950_000,
                    inputTokens: 1_000_000,
                    outputTokens: 600_000,
                    cacheReadTokens: 350_000
                ),
            ],
            summary: NolonCodexAuthUsageTrendSummaryView(
                todayTokens: 120_000_000,
                last7DaysTokens: 124_450_000,
                last30DaysTokens: 124_450_000
            )
        )
    }

    func authUsageRefresh(providerID: String, accountID: UUID?) async throws -> NolonCodexAuthUsagePayload {
        _ = accountID
        call = "authUsageRefresh"
        return NolonCodexAuthUsagePayload(
            providerID: providerID,
            accounts: [
                NolonCodexAuthUsageAccountView(
                    id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                    email: "mock@example.com",
                    isActive: true,
                    fiveHourRemainingPercent: 75,
                    weeklyRemainingPercent: 44,
                    token1dCount: 1_200_000,
                    token30dCount: 24_000_000,
                    tokenAllCount: 50_000_000,
                    expiresAt: Date(timeIntervalSince1970: 1_798_704_000),
                    refreshedAt: Date(timeIntervalSince1970: 1_734_000_000)
                )
            ],
            summary: NolonCodexAuthUsageSummaryView(
                accountCount: 1,
                cachedCount: 1,
                avgFiveHourRemainingPercent: 75,
                avgWeeklyRemainingPercent: 44,
                totalToken1dCount: 1_200_000,
                totalToken30dCount: 24_000_000,
                totalTokenAllCount: 50_000_000,
                earliestExpiresAt: Date(timeIntervalSince1970: 1_798_704_000),
                latestRefreshedAt: Date(timeIntervalSince1970: 1_734_000_000)
            )
        )
    }

    func authActivate(providerID: String, accountID: UUID) async throws -> NolonCodexAuthActivatePayload {
        call = "authActivate"
        return NolonCodexAuthActivatePayload(
            providerID: providerID,
            accountID: accountID
        )
    }

    func authLogin(providerID: String, preferredAccountID: UUID?) async throws -> NolonCodexAuthLoginPayload {
        call = "authLogin"
        return NolonCodexAuthLoginPayload(
            providerID: providerID,
            accountID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            accountName: "mock",
            loginURL: "https://auth.example.com/device"
        )
    }

    func authRefresh(providerID: String, accountID: UUID?) async throws -> NolonCodexAuthRefreshPayload {
        call = "authRefresh"
        let resolvedID = accountID ?? UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        return NolonCodexAuthRefreshPayload(
            providerID: providerID,
            items: [
                NolonCodexAuthRefreshItemView(
                    accountID: resolvedID,
                    accountName: "mock-refresh",
                    email: "mock@example.com",
                    isActive: true,
                    success: true,
                    errorCode: nil,
                    errorMessage: nil
                ),
            ],
            summary: NolonCodexAuthRefreshSummaryView(totalCount: 1, successCount: 1, failureCount: 0)
        )
    }

    func authDelete(providerID: String, accountID: UUID) async throws -> NolonCodexAuthDeletePayload {
        call = "authDelete"
        return NolonCodexAuthDeletePayload(
            providerID: providerID,
            accountID: accountID,
            wasActive: false
        )
    }

    func binaryList() async throws -> NolonCodexBinaryListPayload {
        call = "binaryList"
        return NolonCodexBinaryListPayload(selectedVersionID: nil, versions: [])
    }

    func binaryAvailable() async throws -> NolonCodexBinaryAvailablePayload {
        call = "binaryAvailable"
        return NolonCodexBinaryAvailablePayload(versions: [])
    }

    func binaryCurrent() async throws -> NolonCodexBinaryCurrentPayload {
        call = "binaryCurrent"
        return NolonCodexBinaryCurrentPayload(selectedVersionID: nil, currentVersion: nil, activeCLIPath: nil)
    }

    func binaryInstall(version: String, setDefault: Bool) async throws -> NolonCodexBinaryInstallPayload {
        call = "binaryInstall"
        return NolonCodexBinaryInstallPayload(
            requestedVersion: version,
            installedVersionID: "v\(version)-mock",
            installedDetectedVersion: version,
            activated: setDefault
        )
    }

    func binaryUse(version: String) async throws -> NolonCodexBinaryUsePayload {
        call = "binaryUse"
        return NolonCodexBinaryUsePayload(selectedVersionID: version)
    }

    func binaryDoctor() async throws -> NolonCodexBinaryDoctorPayload {
        call = "binaryDoctor"
        return NolonCodexBinaryDoctorPayload(
            selectedVersionID: nil,
            currentVersion: nil,
            activeCLIPath: nil,
            managedVersionCount: 0,
            pathConfigured: false,
            pathActive: false,
            profilePath: "~/.zshrc"
        )
    }

    func statusProbe(providerID: String?) async throws -> NolonCodexStatusProbePayload {
        call = "statusProbe"
        return NolonCodexStatusProbePayload(
            providerID: providerID,
            resolvedExecutable: "/opt/homebrew/bin/codex",
            credits: nil,
            fiveHourPercentLeft: nil,
            weeklyPercentLeft: nil,
            fiveHourResetDescription: nil,
            weeklyResetDescription: nil,
            probeWarning: nil,
            probeHint: nil
        )
    }

    func sessionList(
        providerID: String,
        groupBy: NolonCodexSessionListGrouping
    ) async throws -> NolonCodexSessionListPayload {
        call = "sessionList"
        sessionListGrouping = groupBy
        let section: NolonCodexSessionSectionView
        switch groupBy {
        case .provider:
            section = NolonCodexSessionSectionView(
                modelProvider: "openai",
                sessions: [
                    NolonCodexSessionRowView(
                        id: "sessions/live.jsonl",
                        threadID: "thread-1",
                        title: "Live Session",
                        summary: "hello",
                        modelProvider: "openai",
                        archived: false,
                        rolloutPath: "sessions/live.jsonl",
                        cwd: "/tmp/demo",
                        updatedAt: Date(timeIntervalSince1970: 0),
                        stateRowCount: 1,
                        editable: true
                    )
                ],
                totalSessionCount: 1,
                editableThreadIDs: ["thread-1"],
                liveCount: 1,
                archivedCount: 0
            )
        case .timeProject:
            section = NolonCodexSessionSectionView(
                id: "time-project:2026-04-11|/tmp/demo",
                modelProvider: "openai",
                title: "2026-04-11 · demo",
                sourceProviderID: "openai",
                providerIDs: ["openai"],
                sessions: [
                    NolonCodexSessionRowView(
                        id: "sessions/live.jsonl",
                        threadID: "thread-1",
                        title: "Live Session",
                        summary: "hello",
                        modelProvider: "openai",
                        archived: false,
                        rolloutPath: "sessions/live.jsonl",
                        cwd: "/tmp/demo",
                        updatedAt: Date(timeIntervalSince1970: 0),
                        stateRowCount: 1,
                        editable: true
                    )
                ],
                totalSessionCount: 1,
                editableThreadIDs: ["thread-1"],
                liveCount: 1,
                archivedCount: 0
            )
        }
        return NolonCodexSessionListPayload(
            providerID: providerID,
            groupBy: groupBy,
            availableTargetProviderIDs: ["openai", "azure"],
            sections: [section],
            totalSessionCount: 1,
            totalLiveCount: 1,
            totalArchivedCount: 0
        )
    }

    func sessionPreviewRewrite(
        providerID: String,
        requestSource: NolonCodexSessionSelectionSource,
        targetProviderID: String
    ) async throws -> NolonCodexSessionRewritePreviewPayload {
        sessionRequestSource = requestSource
        call = "sessionPreviewRewrite"
        return NolonCodexSessionRewritePreviewPayload(
            providerID: providerID,
            sourceLabel: "Live Session",
            targetProviderID: targetProviderID,
            threadIDs: ["thread-1"],
            preview: NolonCodexSessionRewritePreviewView(
                sessionCount: 1,
                liveSessionCount: 1,
                archivedSessionCount: 0,
                stateRowCount: 1
            )
        )
    }

    func sessionRewrite(
        providerID: String,
        requestSource: NolonCodexSessionSelectionSource,
        targetProviderID: String
    ) async throws -> NolonCodexSessionRewritePayload {
        sessionRequestSource = requestSource
        call = "sessionRewrite"
        return NolonCodexSessionRewritePayload(
            providerID: providerID,
            sourceLabel: "Live Session",
            targetProviderID: targetProviderID,
            threadIDs: ["thread-1"],
            result: NolonCodexSessionRewriteResultView(
                preview: NolonCodexSessionRewritePreviewView(
                    sessionCount: 1,
                    liveSessionCount: 1,
                    archivedSessionCount: 0,
                    stateRowCount: 1
                ),
                liveRolloutFilesUpdated: 1,
                archivedRolloutFilesUpdated: 0,
                stateRowsUpdated: 1,
                failures: []
            )
        )
    }

    func runtimeList(providerID: String?) async throws -> NolonCodexRuntimeListPayload {
        call = "runtimeList"
        return NolonCodexRuntimeListPayload(
            processes: [
                NolonCodexRuntimeProcessView(
                    pid: 12345,
                    ppid: 1,
                    elapsed: "00:01:02",
                    providerHint: "codex",
                    command: "/opt/homebrew/bin/codex"
                )
            ]
        )
    }

    func runtimeStop(pid: Int32, force: Bool, timeoutSeconds: Int) async throws -> NolonCodexRuntimeStopPayload {
        call = "runtimeStop"
        return NolonCodexRuntimeStopPayload(
            pid: pid,
            requestedSignal: force ? "kill" : "term",
            didEscalateToKill: false,
            exited: true
        )
    }

    func providerList() async throws -> NolonProviderListPayload {
        call = "providerList"
        return NolonProviderListPayload(
            providers: [
                NolonProviderCLIView(
                    providerID: "codex",
                    name: "Codex",
                    cli: "codex",
                    installed: true,
                    executablePath: "/opt/homebrew/bin/codex"
                ),
            ]
        )
    }

    func providerDiscover() async throws -> NolonCodexProviderDiscoverPayload {
        call = "providerDiscover"
        return NolonCodexProviderDiscoverPayload(
            providers: [
                NolonCodexProviderDiscoverView(
                    providerID: "codex",
                    name: "Codex",
                    templateID: "codex",
                    codexHomePath: "/tmp/.codex",
                    authPath: "/tmp/.codex/auth.json",
                    authExists: true,
                    authIsSymlink: true,
                    authSymlinkTargetPath: "/tmp/.nolon/codex/auth/codex.json"
                ),
            ]
        )
    }

}

actor DomainErrorCodexCLIService: NolonCodexCLIServing {
    func authList(providerID: String) async throws -> NolonCodexAuthListPayload { throw makeError() }
    func authStatus(providerID: String) async throws -> NolonCodexAuthStatusPayload { throw makeError() }
    func authActivate(providerID: String, accountID: UUID) async throws -> NolonCodexAuthActivatePayload { throw makeError() }
    func authLogin(providerID: String, preferredAccountID: UUID?) async throws -> NolonCodexAuthLoginPayload { throw makeError() }
    func authDelete(providerID: String, accountID: UUID) async throws -> NolonCodexAuthDeletePayload { throw makeError() }
    func binaryList() async throws -> NolonCodexBinaryListPayload { throw makeError() }
    func binaryAvailable() async throws -> NolonCodexBinaryAvailablePayload { throw makeError() }
    func binaryCurrent() async throws -> NolonCodexBinaryCurrentPayload { throw makeError() }
    func binaryInstall(version: String, setDefault: Bool) async throws -> NolonCodexBinaryInstallPayload { throw makeError() }
    func binaryUse(version: String) async throws -> NolonCodexBinaryUsePayload { throw makeError() }
    func binaryDoctor() async throws -> NolonCodexBinaryDoctorPayload { throw makeError() }
    func statusProbe(providerID: String?) async throws -> NolonCodexStatusProbePayload { throw makeError() }
    func sessionList(
        providerID: String,
        groupBy: NolonCodexSessionListGrouping
    ) async throws -> NolonCodexSessionListPayload {
        _ = providerID
        _ = groupBy
        throw makeError()
    }
    func sessionPreviewRewrite(providerID: String, requestSource: NolonCodexSessionSelectionSource, targetProviderID: String) async throws -> NolonCodexSessionRewritePreviewPayload { throw makeError() }
    func sessionRewrite(providerID: String, requestSource: NolonCodexSessionSelectionSource, targetProviderID: String) async throws -> NolonCodexSessionRewritePayload { throw makeError() }
    func runtimeList(providerID: String?) async throws -> NolonCodexRuntimeListPayload { throw makeError() }
    func runtimeStop(pid: Int32, force: Bool, timeoutSeconds: Int) async throws -> NolonCodexRuntimeStopPayload { throw makeError() }
    func providerList() async throws -> NolonProviderListPayload { throw makeError() }
    func providerDiscover() async throws -> NolonCodexProviderDiscoverPayload { throw makeError() }

    private func makeError() -> NolonCoreCLIError {
        .domainFailed(code: "codex_binary_not_found", message: "missing")
    }
}

actor CancellationErrorCodexCLIService: NolonCodexCLIServing {
    func authList(providerID: String) async throws -> NolonCodexAuthListPayload { throw CancellationError() }
    func authStatus(providerID: String) async throws -> NolonCodexAuthStatusPayload { throw CancellationError() }
    func authActivate(providerID: String, accountID: UUID) async throws -> NolonCodexAuthActivatePayload { throw CancellationError() }
    func authLogin(providerID: String, preferredAccountID: UUID?) async throws -> NolonCodexAuthLoginPayload { throw CancellationError() }
    func authDelete(providerID: String, accountID: UUID) async throws -> NolonCodexAuthDeletePayload { throw CancellationError() }
    func binaryList() async throws -> NolonCodexBinaryListPayload { throw CancellationError() }
    func binaryAvailable() async throws -> NolonCodexBinaryAvailablePayload { throw CancellationError() }
    func binaryCurrent() async throws -> NolonCodexBinaryCurrentPayload { throw CancellationError() }
    func binaryInstall(version: String, setDefault: Bool) async throws -> NolonCodexBinaryInstallPayload { throw CancellationError() }
    func binaryUse(version: String) async throws -> NolonCodexBinaryUsePayload { throw CancellationError() }
    func binaryDoctor() async throws -> NolonCodexBinaryDoctorPayload { throw CancellationError() }
    func statusProbe(providerID: String?) async throws -> NolonCodexStatusProbePayload { throw CancellationError() }
    func sessionList(
        providerID: String,
        groupBy: NolonCodexSessionListGrouping
    ) async throws -> NolonCodexSessionListPayload {
        _ = providerID
        _ = groupBy
        throw CancellationError()
    }
    func sessionPreviewRewrite(providerID: String, requestSource: NolonCodexSessionSelectionSource, targetProviderID: String) async throws -> NolonCodexSessionRewritePreviewPayload { throw CancellationError() }
    func sessionRewrite(providerID: String, requestSource: NolonCodexSessionSelectionSource, targetProviderID: String) async throws -> NolonCodexSessionRewritePayload { throw CancellationError() }
    func runtimeList(providerID: String?) async throws -> NolonCodexRuntimeListPayload { throw CancellationError() }
    func runtimeStop(pid: Int32, force: Bool, timeoutSeconds: Int) async throws -> NolonCodexRuntimeStopPayload { throw CancellationError() }
    func providerList() async throws -> NolonProviderListPayload { throw CancellationError() }
    func providerDiscover() async throws -> NolonCodexProviderDiscoverPayload { throw CancellationError() }
}

actor EmailActivateCodexCLIService: NolonCodexCLIServing {
    private let accountID = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!

    func authList(providerID: String) async throws -> NolonCodexAuthListPayload {
        NolonCodexAuthListPayload(
            providerID: providerID,
            activeAccountID: nil,
            accounts: [
                NolonCodexAuthAccountView(
                    id: accountID,
                    name: "A",
                    createdAt: .distantPast,
                    relativeAuthPath: "a/auth.json",
                    isActive: false,
                    email: "a@example.com",
                    usageDisplay: nil,
                    refreshedAt: nil
                ),
            ]
        )
    }

    func authStatus(providerID: String) async throws -> NolonCodexAuthStatusPayload {
        NolonCodexAuthStatusPayload(providerID: providerID, activeAccountID: nil, accountCount: 1, authHashHex: nil)
    }

    func authActivate(providerID: String, accountID: UUID) async throws -> NolonCodexAuthActivatePayload {
        NolonCodexAuthActivatePayload(providerID: providerID, accountID: accountID)
    }

    func authLogin(providerID: String, preferredAccountID: UUID?) async throws -> NolonCodexAuthLoginPayload {
        NolonCodexAuthLoginPayload(providerID: providerID, accountID: accountID, accountName: "A", loginURL: nil)
    }

    func authDelete(providerID: String, accountID: UUID) async throws -> NolonCodexAuthDeletePayload {
        NolonCodexAuthDeletePayload(providerID: providerID, accountID: accountID, wasActive: false)
    }

    func binaryList() async throws -> NolonCodexBinaryListPayload {
        NolonCodexBinaryListPayload(selectedVersionID: nil, versions: [])
    }

    func binaryAvailable() async throws -> NolonCodexBinaryAvailablePayload {
        NolonCodexBinaryAvailablePayload(versions: [])
    }

    func binaryCurrent() async throws -> NolonCodexBinaryCurrentPayload {
        NolonCodexBinaryCurrentPayload(selectedVersionID: nil, currentVersion: nil, activeCLIPath: nil)
    }

    func binaryInstall(version: String, setDefault: Bool) async throws -> NolonCodexBinaryInstallPayload {
        NolonCodexBinaryInstallPayload(requestedVersion: version, installedVersionID: version, installedDetectedVersion: version, activated: setDefault)
    }

    func binaryUse(version: String) async throws -> NolonCodexBinaryUsePayload {
        NolonCodexBinaryUsePayload(selectedVersionID: version)
    }

    func binaryDoctor() async throws -> NolonCodexBinaryDoctorPayload {
        NolonCodexBinaryDoctorPayload(selectedVersionID: nil, currentVersion: nil, activeCLIPath: nil, managedVersionCount: 0, pathConfigured: false, pathActive: false, profilePath: "~/.zshrc")
    }

    func statusProbe(providerID: String?) async throws -> NolonCodexStatusProbePayload {
        NolonCodexStatusProbePayload(providerID: providerID, resolvedExecutable: nil, credits: nil, fiveHourPercentLeft: nil, weeklyPercentLeft: nil, fiveHourResetDescription: nil, weeklyResetDescription: nil, probeWarning: nil, probeHint: nil)
    }

    func runtimeList(providerID: String?) async throws -> NolonCodexRuntimeListPayload {
        NolonCodexRuntimeListPayload(processes: [])
    }

    func runtimeStop(pid: Int32, force: Bool, timeoutSeconds: Int) async throws -> NolonCodexRuntimeStopPayload {
        NolonCodexRuntimeStopPayload(pid: pid, requestedSignal: "term", didEscalateToKill: false, exited: true)
    }

    func providerList() async throws -> NolonProviderListPayload {
        NolonProviderListPayload(providers: [])
    }

    func providerDiscover() async throws -> NolonCodexProviderDiscoverPayload {
        NolonCodexProviderDiscoverPayload(providers: [])
    }
}

actor StatusProbeParseErrorCodexCLIService: NolonCodexCLIServing {
    func authList(providerID: String) async throws -> NolonCodexAuthListPayload { NolonCodexAuthListPayload(providerID: providerID, activeAccountID: nil, accounts: []) }
    func authStatus(providerID: String) async throws -> NolonCodexAuthStatusPayload { NolonCodexAuthStatusPayload(providerID: providerID, activeAccountID: nil, accountCount: 0, authHashHex: nil) }
    func authActivate(providerID: String, accountID: UUID) async throws -> NolonCodexAuthActivatePayload { NolonCodexAuthActivatePayload(providerID: providerID, accountID: accountID) }
    func authLogin(providerID: String, preferredAccountID: UUID?) async throws -> NolonCodexAuthLoginPayload { NolonCodexAuthLoginPayload(providerID: providerID, accountID: UUID(), accountName: "-", loginURL: nil) }
    func authDelete(providerID: String, accountID: UUID) async throws -> NolonCodexAuthDeletePayload { NolonCodexAuthDeletePayload(providerID: providerID, accountID: accountID, wasActive: false) }
    func binaryList() async throws -> NolonCodexBinaryListPayload { NolonCodexBinaryListPayload(selectedVersionID: nil, versions: []) }
    func binaryAvailable() async throws -> NolonCodexBinaryAvailablePayload { NolonCodexBinaryAvailablePayload(versions: []) }
    func binaryCurrent() async throws -> NolonCodexBinaryCurrentPayload { NolonCodexBinaryCurrentPayload(selectedVersionID: nil, currentVersion: nil, activeCLIPath: nil) }
    func binaryInstall(version: String, setDefault: Bool) async throws -> NolonCodexBinaryInstallPayload { NolonCodexBinaryInstallPayload(requestedVersion: version, installedVersionID: version, installedDetectedVersion: version, activated: setDefault) }
    func binaryUse(version: String) async throws -> NolonCodexBinaryUsePayload { NolonCodexBinaryUsePayload(selectedVersionID: version) }
    func binaryDoctor() async throws -> NolonCodexBinaryDoctorPayload { NolonCodexBinaryDoctorPayload(selectedVersionID: nil, currentVersion: nil, activeCLIPath: nil, managedVersionCount: 0, pathConfigured: false, pathActive: false, profilePath: "~/.zshrc") }
    func statusProbe(providerID: String?) async throws -> NolonCodexStatusProbePayload {
        throw NolonCoreCLIError.invalidArguments("Could not parse Codex status; will retry shortly.")
    }
    func runtimeList(providerID: String?) async throws -> NolonCodexRuntimeListPayload { NolonCodexRuntimeListPayload(processes: []) }
    func runtimeStop(pid: Int32, force: Bool, timeoutSeconds: Int) async throws -> NolonCodexRuntimeStopPayload { NolonCodexRuntimeStopPayload(pid: pid, requestedSignal: "term", didEscalateToKill: false, exited: true) }
    func providerList() async throws -> NolonProviderListPayload { NolonProviderListPayload(providers: []) }
    func providerDiscover() async throws -> NolonCodexProviderDiscoverPayload { NolonCodexProviderDiscoverPayload(providers: []) }
}

actor BinarySwitchCodexCLIService: NolonCodexCLIServing {
    private let installed: NolonCodexBinaryListPayload
    private let available: NolonCodexBinaryAvailablePayload
    private var call: String?

    init(installed: NolonCodexBinaryListPayload, available: NolonCodexBinaryAvailablePayload) {
        self.installed = installed
        self.available = available
    }

    func lastCall() -> String? { call }

    func authList(providerID: String) async throws -> NolonCodexAuthListPayload { throw unsupported() }
    func authStatus(providerID: String) async throws -> NolonCodexAuthStatusPayload { throw unsupported() }
    func authActivate(providerID: String, accountID: UUID) async throws -> NolonCodexAuthActivatePayload { throw unsupported() }
    func authLogin(providerID: String, preferredAccountID: UUID?) async throws -> NolonCodexAuthLoginPayload { throw unsupported() }
    func authDelete(providerID: String, accountID: UUID) async throws -> NolonCodexAuthDeletePayload { throw unsupported() }
    func binaryList() async throws -> NolonCodexBinaryListPayload { installed }
    func binaryAvailable() async throws -> NolonCodexBinaryAvailablePayload { available }
    func binaryCurrent() async throws -> NolonCodexBinaryCurrentPayload { throw unsupported() }
    func binaryInstall(version: String, setDefault: Bool) async throws -> NolonCodexBinaryInstallPayload {
        call = "binaryInstall"
        return NolonCodexBinaryInstallPayload(
            requestedVersion: version,
            installedVersionID: "v\(version)-mock",
            installedDetectedVersion: version,
            activated: setDefault
        )
    }
    func binaryUse(version: String) async throws -> NolonCodexBinaryUsePayload {
        call = "binaryUse"
        return NolonCodexBinaryUsePayload(selectedVersionID: version)
    }
    func binaryDoctor() async throws -> NolonCodexBinaryDoctorPayload { throw unsupported() }
    func statusProbe(providerID: String?) async throws -> NolonCodexStatusProbePayload { throw unsupported() }
    func runtimeList(providerID: String?) async throws -> NolonCodexRuntimeListPayload { throw unsupported() }
    func runtimeStop(pid: Int32, force: Bool, timeoutSeconds: Int) async throws -> NolonCodexRuntimeStopPayload { throw unsupported() }
    func providerList() async throws -> NolonProviderListPayload { throw unsupported() }
    func providerDiscover() async throws -> NolonCodexProviderDiscoverPayload { throw unsupported() }

    private func unsupported() -> NolonCoreCLIError {
        .invalidArguments("unsupported")
    }
}

actor BinaryListPlainTextCodexCLIService: NolonCodexCLIServing {
    func authList(providerID: String) async throws -> NolonCodexAuthListPayload { throw unsupported() }
    func authStatus(providerID: String) async throws -> NolonCodexAuthStatusPayload { throw unsupported() }
    func authActivate(providerID: String, accountID: UUID) async throws -> NolonCodexAuthActivatePayload { throw unsupported() }
    func authLogin(providerID: String, preferredAccountID: UUID?) async throws -> NolonCodexAuthLoginPayload { throw unsupported() }
    func authDelete(providerID: String, accountID: UUID) async throws -> NolonCodexAuthDeletePayload { throw unsupported() }
    func binaryAvailable() async throws -> NolonCodexBinaryAvailablePayload { throw unsupported() }
    func binaryCurrent() async throws -> NolonCodexBinaryCurrentPayload { throw unsupported() }
    func binaryInstall(version: String, setDefault: Bool) async throws -> NolonCodexBinaryInstallPayload { throw unsupported() }
    func binaryUse(version: String) async throws -> NolonCodexBinaryUsePayload { throw unsupported() }
    func binaryDoctor() async throws -> NolonCodexBinaryDoctorPayload { throw unsupported() }
    func statusProbe(providerID: String?) async throws -> NolonCodexStatusProbePayload { throw unsupported() }
    func runtimeList(providerID: String?) async throws -> NolonCodexRuntimeListPayload { throw unsupported() }
    func runtimeStop(pid: Int32, force: Bool, timeoutSeconds: Int) async throws -> NolonCodexRuntimeStopPayload { throw unsupported() }
    func providerList() async throws -> NolonProviderListPayload { throw unsupported() }
    func providerDiscover() async throws -> NolonCodexProviderDiscoverPayload { throw unsupported() }

    func binaryList() async throws -> NolonCodexBinaryListPayload {
        NolonCodexBinaryListPayload(
            selectedVersionID: "v0.26.0",
            versions: [
                NolonCodexManagedVersionView(
                    id: "v0.26.0",
                    displayName: "Codex 0.26.0",
                    detectedVersion: "0.26.0",
                    source: "release",
                    importedAt: .distantPast,
                    isSelected: true
                ),
                NolonCodexManagedVersionView(
                    id: "v0.9.0",
                    displayName: "X",
                    detectedVersion: "0.9.0",
                    source: "release",
                    importedAt: .distantPast,
                    isSelected: false
                ),
            ]
        )
    }

    private func unsupported() -> NolonCoreCLIError {
        .invalidArguments("unsupported")
    }
}

actor JSONContractCodexCLIService: NolonCodexCLIServing {
    func authList(providerID: String) async throws -> NolonCodexAuthListPayload {
        NolonCodexAuthListPayload(
            providerID: providerID,
            activeAccountID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            accounts: [
                NolonCodexAuthAccountView(
                    id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                    name: "json-account",
                    createdAt: Date(timeIntervalSince1970: 0),
                    relativeAuthPath: "accounts/json/auth.json",
                    isActive: true,
                    email: "json@example.com",
                    usageDisplay: "5h 80% / 7d 60%",
                    refreshedAt: Date(timeIntervalSince1970: 60)
                )
            ]
        )
    }
    func authStatus(providerID: String) async throws -> NolonCodexAuthStatusPayload {
        NolonCodexAuthStatusPayload(
            providerID: providerID,
            activeAccountID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            accountCount: 2,
            authHashHex: "abc123",
            usageCachedAccountCount: 2,
            usageAvgFiveHourRemainingPercent: 70,
            usageAvgWeeklyRemainingPercent: 55,
            usageLatestRefreshedAt: Date(timeIntervalSince1970: 60)
        )
    }
    func authActivate(providerID: String, accountID: UUID) async throws -> NolonCodexAuthActivatePayload {
        NolonCodexAuthActivatePayload(
            providerID: providerID,
            accountID: accountID
        )
    }
    func authLogin(providerID: String, preferredAccountID: UUID?) async throws -> NolonCodexAuthLoginPayload {
        NolonCodexAuthLoginPayload(
            providerID: providerID,
            accountID: preferredAccountID ?? UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            accountName: "json-login",
            loginURL: "https://auth.example.com/device"
        )
    }
    func authRefresh(providerID: String, accountID: UUID?) async throws -> NolonCodexAuthRefreshPayload {
        NolonCodexAuthRefreshPayload(
            providerID: providerID,
            items: [
                NolonCodexAuthRefreshItemView(
                    accountID: accountID ?? UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
                    accountName: "json-refresh",
                    email: "json@example.com",
                    isActive: true,
                    success: true,
                    errorCode: nil,
                    errorMessage: nil
                ),
            ],
            summary: NolonCodexAuthRefreshSummaryView(totalCount: 1, successCount: 1, failureCount: 0)
        )
    }
    func authDelete(providerID: String, accountID: UUID) async throws -> NolonCodexAuthDeletePayload {
        NolonCodexAuthDeletePayload(
            providerID: providerID,
            accountID: accountID,
            wasActive: true
        )
    }
    func binaryAvailable() async throws -> NolonCodexBinaryAvailablePayload { throw unsupported() }
    func binaryCurrent() async throws -> NolonCodexBinaryCurrentPayload { throw unsupported() }
    func binaryInstall(version: String, setDefault: Bool) async throws -> NolonCodexBinaryInstallPayload { throw unsupported() }
    func binaryUse(version: String) async throws -> NolonCodexBinaryUsePayload { throw unsupported() }
    func binaryDoctor() async throws -> NolonCodexBinaryDoctorPayload { throw unsupported() }
    func statusProbe(providerID: String?) async throws -> NolonCodexStatusProbePayload { throw unsupported() }
    func runtimeList(providerID: String?) async throws -> NolonCodexRuntimeListPayload { throw unsupported() }
    func runtimeStop(pid: Int32, force: Bool, timeoutSeconds: Int) async throws -> NolonCodexRuntimeStopPayload { throw unsupported() }
    func providerList() async throws -> NolonProviderListPayload { throw unsupported() }
    func providerDiscover() async throws -> NolonCodexProviderDiscoverPayload { throw unsupported() }

    func binaryList() async throws -> NolonCodexBinaryListPayload {
        NolonCodexBinaryListPayload(
            selectedVersionID: "v1",
            versions: [
                NolonCodexManagedVersionView(
                    id: "v1",
                    displayName: "Codex 1.0.0",
                    detectedVersion: "1.0.0",
                    source: "download",
                    importedAt: Date(timeIntervalSince1970: 0),
                    isSelected: true
                )
            ]
        )
    }

    func authUsage(providerID: String) async throws -> NolonCodexAuthUsagePayload {
        NolonCodexAuthUsagePayload(
            providerID: providerID,
            accounts: [
                NolonCodexAuthUsageAccountView(
                    id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                    email: "json@example.com",
                    isActive: true,
                    status: .healthy,
                    fiveHourRemainingPercent: 80,
                    weeklyRemainingPercent: 60,
                    token1dCount: 1_200_000,
                    token30dCount: 24_000_000,
                    tokenAllCount: 50_000_000,
                    expiresAt: Date(timeIntervalSince1970: 1_798_704_000),
                    refreshedAt: Date(timeIntervalSince1970: 0)
                )
            ],
            summary: NolonCodexAuthUsageSummaryView(
                accountCount: 1,
                cachedCount: 1,
                avgFiveHourRemainingPercent: 80,
                avgWeeklyRemainingPercent: 60,
                totalToken1dCount: 1_200_000,
                totalToken30dCount: 24_000_000,
                totalTokenAllCount: 50_000_000,
                earliestExpiresAt: Date(timeIntervalSince1970: 1_798_704_000),
                latestRefreshedAt: Date(timeIntervalSince1970: 0)
            )
        )
    }

    func authUsageTrend(providerID: String, range: NolonCodexUsageTrendRange) async throws -> NolonCodexAuthUsageTrendPayload {
        NolonCodexAuthUsageTrendPayload(
            providerID: providerID,
            range: range,
            sourceLabel: "global",
            updatedAt: Date(timeIntervalSince1970: 0),
            points: [
                NolonCodexAuthUsageTrendPointView(
                    date: "2026-02-26",
                    totalTokens: 2_500_000,
                    inputTokens: 1_200_000,
                    outputTokens: 800_000,
                    cacheReadTokens: 500_000
                ),
                NolonCodexAuthUsageTrendPointView(
                    date: "2026-02-25",
                    totalTokens: 1_950_000,
                    inputTokens: 1_000_000,
                    outputTokens: 600_000,
                    cacheReadTokens: 350_000
                ),
            ],
            summary: NolonCodexAuthUsageTrendSummaryView(
                todayTokens: 2_500_000,
                last7DaysTokens: 4_450_000,
                last30DaysTokens: 4_450_000
            )
        )
    }

    private func unsupported() -> NolonCoreCLIError {
        .invalidArguments("unsupported")
    }
}

actor AuthListTableCodexCLIService: NolonCodexCLIServing {
    func authStatus(providerID: String) async throws -> NolonCodexAuthStatusPayload {
        NolonCodexAuthStatusPayload(
            providerID: providerID,
            activeAccountID: UUID(uuidString: "11111111-1111-1111-1111-111111111111"),
            accountCount: 2,
            authHashHex: "tablehash"
        )
    }
    func authActivate(providerID: String, accountID: UUID) async throws -> NolonCodexAuthActivatePayload { throw unsupported() }
    func authLogin(providerID: String, preferredAccountID: UUID?) async throws -> NolonCodexAuthLoginPayload { throw unsupported() }
    func authDelete(providerID: String, accountID: UUID) async throws -> NolonCodexAuthDeletePayload { throw unsupported() }
    func binaryList() async throws -> NolonCodexBinaryListPayload { throw unsupported() }
    func binaryAvailable() async throws -> NolonCodexBinaryAvailablePayload { throw unsupported() }
    func binaryCurrent() async throws -> NolonCodexBinaryCurrentPayload { throw unsupported() }
    func binaryInstall(version: String, setDefault: Bool) async throws -> NolonCodexBinaryInstallPayload { throw unsupported() }
    func binaryUse(version: String) async throws -> NolonCodexBinaryUsePayload { throw unsupported() }
    func binaryDoctor() async throws -> NolonCodexBinaryDoctorPayload { throw unsupported() }
    func statusProbe(providerID: String?) async throws -> NolonCodexStatusProbePayload { throw unsupported() }
    func runtimeList(providerID: String?) async throws -> NolonCodexRuntimeListPayload { throw unsupported() }
    func runtimeStop(pid: Int32, force: Bool, timeoutSeconds: Int) async throws -> NolonCodexRuntimeStopPayload { throw unsupported() }
    func providerList() async throws -> NolonProviderListPayload { throw unsupported() }
    func providerDiscover() async throws -> NolonCodexProviderDiscoverPayload { throw unsupported() }

    func authUsage(providerID: String) async throws -> NolonCodexAuthUsagePayload {
        NolonCodexAuthUsagePayload(
            providerID: providerID,
            accounts: [],
            summary: NolonCodexAuthUsageSummaryView(
                accountCount: 0,
                cachedCount: 0,
                avgFiveHourRemainingPercent: nil,
                avgWeeklyRemainingPercent: nil,
                totalToken1dCount: nil,
                totalToken30dCount: nil,
                totalTokenAllCount: nil,
                earliestExpiresAt: nil,
                latestRefreshedAt: nil
            )
        )
    }

    func authList(providerID: String) async throws -> NolonCodexAuthListPayload {
        NolonCodexAuthListPayload(
            providerID: providerID,
            activeAccountID: UUID(uuidString: "11111111-1111-1111-1111-111111111111"),
            accounts: [
                NolonCodexAuthAccountView(
                    id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                    name: "long-account-name",
                    createdAt: .distantPast,
                    relativeAuthPath: "accounts/long-name/auth.json",
                    isActive: true,
                    email: "long-account@example.com",
                    usageDisplay: "5h 81% / 7d 55%",
                    refreshedAt: Date(timeIntervalSince1970: 1_734_000_000)
                ),
                NolonCodexAuthAccountView(
                    id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                    name: "x",
                    createdAt: .distantPast,
                    relativeAuthPath: "a.json",
                    isActive: false,
                    email: "x@example.com",
                    usageDisplay: "5h 40%",
                    refreshedAt: Date(timeIntervalSince1970: 1_733_900_000)
                ),
            ]
        )
    }

    private func unsupported() -> NolonCoreCLIError {
        .invalidArguments("unsupported")
    }
}

actor AuthUsageExpiryLabelCodexCLIService: NolonCodexCLIServing {
    func authList(providerID: String) async throws -> NolonCodexAuthListPayload {
        NolonCodexAuthListPayload(providerID: providerID, activeAccountID: nil, accounts: [])
    }
    func authStatus(providerID: String) async throws -> NolonCodexAuthStatusPayload {
        NolonCodexAuthStatusPayload(providerID: providerID, activeAccountID: nil, accountCount: 2, authHashHex: "expiryhash")
    }
    func authActivate(providerID: String, accountID: UUID) async throws -> NolonCodexAuthActivatePayload { throw unsupported() }
    func authLogin(providerID: String, preferredAccountID: UUID?) async throws -> NolonCodexAuthLoginPayload { throw unsupported() }
    func authDelete(providerID: String, accountID: UUID) async throws -> NolonCodexAuthDeletePayload { throw unsupported() }
    func binaryList() async throws -> NolonCodexBinaryListPayload { throw unsupported() }
    func binaryAvailable() async throws -> NolonCodexBinaryAvailablePayload { throw unsupported() }
    func binaryCurrent() async throws -> NolonCodexBinaryCurrentPayload { throw unsupported() }
    func binaryInstall(version: String, setDefault: Bool) async throws -> NolonCodexBinaryInstallPayload { throw unsupported() }
    func binaryUse(version: String) async throws -> NolonCodexBinaryUsePayload { throw unsupported() }
    func binaryDoctor() async throws -> NolonCodexBinaryDoctorPayload { throw unsupported() }
    func statusProbe(providerID: String?) async throws -> NolonCodexStatusProbePayload { throw unsupported() }
    func runtimeList(providerID: String?) async throws -> NolonCodexRuntimeListPayload { throw unsupported() }
    func runtimeStop(pid: Int32, force: Bool, timeoutSeconds: Int) async throws -> NolonCodexRuntimeStopPayload { throw unsupported() }
    func providerList() async throws -> NolonProviderListPayload { throw unsupported() }
    func providerDiscover() async throws -> NolonCodexProviderDiscoverPayload { throw unsupported() }

    func authUsage(providerID: String) async throws -> NolonCodexAuthUsagePayload {
        NolonCodexAuthUsagePayload(
            providerID: providerID,
            accounts: [
                NolonCodexAuthUsageAccountView(
                    id: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
                    email: "future@example.com",
                    isActive: true,
                    fiveHourRemainingPercent: 80,
                    weeklyRemainingPercent: 60,
                    token1dCount: 1_000_000,
                    token30dCount: 10_000_000,
                    tokenAllCount: 20_000_000,
                    expiresAt: Date().addingTimeInterval(26 * 3600),
                    refreshedAt: Date()
                ),
                NolonCodexAuthUsageAccountView(
                    id: UUID(uuidString: "88888888-8888-8888-8888-888888888888")!,
                    email: "expired@example.com",
                    isActive: false,
                    fiveHourRemainingPercent: 20,
                    weeklyRemainingPercent: 30,
                    token1dCount: 500_000,
                    token30dCount: 5_000_000,
                    tokenAllCount: 8_000_000,
                    expiresAt: Date().addingTimeInterval(-3 * 3600),
                    hasRefreshToken: true,
                    refreshedAt: Date()
                ),
            ],
            summary: NolonCodexAuthUsageSummaryView(
                accountCount: 2,
                cachedCount: 2,
                avgFiveHourRemainingPercent: 50,
                avgWeeklyRemainingPercent: 45,
                totalToken1dCount: 1_500_000,
                totalToken30dCount: 15_000_000,
                totalTokenAllCount: 28_000_000,
                earliestExpiresAt: Date().addingTimeInterval(-3 * 3600),
                latestRefreshedAt: Date()
            )
        )
    }

    private func unsupported() -> NolonCoreCLIError {
        .invalidArguments("unsupported")
    }
}

actor AuthUsageGlobalFallbackCodexCLIService: NolonCodexCLIServing {
    func authList(providerID: String) async throws -> NolonCodexAuthListPayload {
        NolonCodexAuthListPayload(providerID: providerID, activeAccountID: nil, accounts: [])
    }
    func authStatus(providerID: String) async throws -> NolonCodexAuthStatusPayload {
        NolonCodexAuthStatusPayload(providerID: providerID, activeAccountID: nil, accountCount: 1, authHashHex: "fallbackhash")
    }
    func authActivate(providerID: String, accountID: UUID) async throws -> NolonCodexAuthActivatePayload { throw unsupported() }
    func authLogin(providerID: String, preferredAccountID: UUID?) async throws -> NolonCodexAuthLoginPayload { throw unsupported() }
    func authDelete(providerID: String, accountID: UUID) async throws -> NolonCodexAuthDeletePayload { throw unsupported() }
    func binaryList() async throws -> NolonCodexBinaryListPayload { throw unsupported() }
    func binaryAvailable() async throws -> NolonCodexBinaryAvailablePayload { throw unsupported() }
    func binaryCurrent() async throws -> NolonCodexBinaryCurrentPayload { throw unsupported() }
    func binaryInstall(version: String, setDefault: Bool) async throws -> NolonCodexBinaryInstallPayload { throw unsupported() }
    func binaryUse(version: String) async throws -> NolonCodexBinaryUsePayload { throw unsupported() }
    func binaryDoctor() async throws -> NolonCodexBinaryDoctorPayload { throw unsupported() }
    func statusProbe(providerID: String?) async throws -> NolonCodexStatusProbePayload { throw unsupported() }
    func runtimeList(providerID: String?) async throws -> NolonCodexRuntimeListPayload { throw unsupported() }
    func runtimeStop(pid: Int32, force: Bool, timeoutSeconds: Int) async throws -> NolonCodexRuntimeStopPayload { throw unsupported() }
    func providerList() async throws -> NolonProviderListPayload { throw unsupported() }
    func providerDiscover() async throws -> NolonCodexProviderDiscoverPayload { throw unsupported() }

    func authUsage(providerID: String) async throws -> NolonCodexAuthUsagePayload {
        NolonCodexAuthUsagePayload(
            providerID: providerID,
            accounts: [
                NolonCodexAuthUsageAccountView(
                    id: UUID(uuidString: "99999999-9999-9999-9999-999999999999")!,
                    email: "fallback@example.com",
                    isActive: true,
                    usageSource: "CLI(global)",
                    fiveHourRemainingPercent: 80,
                    weeklyRemainingPercent: 60,
                    token1dCount: 1_000_000,
                    token30dCount: 10_000_000,
                    tokenAllCount: 20_000_000,
                    expiresAt: Date().addingTimeInterval(-3600),
                    hasRefreshToken: true,
                    refreshedAt: Date()
                )
            ],
            summary: NolonCodexAuthUsageSummaryView(
                accountCount: 1,
                cachedCount: 1,
                avgFiveHourRemainingPercent: 80,
                avgWeeklyRemainingPercent: 60,
                totalToken1dCount: 1_000_000,
                totalToken30dCount: 10_000_000,
                totalTokenAllCount: 20_000_000,
                earliestExpiresAt: Date().addingTimeInterval(-3600),
                latestRefreshedAt: Date()
            )
        )
    }

    private func unsupported() -> NolonCoreCLIError {
        .invalidArguments("unsupported")
    }
}

actor AuthUsageUndistinguishableTokensCodexCLIService: NolonCodexCLIServing {
    func authList(providerID: String) async throws -> NolonCodexAuthListPayload {
        NolonCodexAuthListPayload(providerID: providerID, activeAccountID: nil, accounts: [])
    }
    func authStatus(providerID: String) async throws -> NolonCodexAuthStatusPayload {
        NolonCodexAuthStatusPayload(providerID: providerID, activeAccountID: nil, accountCount: 2, authHashHex: "same-token")
    }
    func authActivate(providerID: String, accountID: UUID) async throws -> NolonCodexAuthActivatePayload { throw unsupported() }
    func authLogin(providerID: String, preferredAccountID: UUID?) async throws -> NolonCodexAuthLoginPayload { throw unsupported() }
    func authDelete(providerID: String, accountID: UUID) async throws -> NolonCodexAuthDeletePayload { throw unsupported() }
    func binaryList() async throws -> NolonCodexBinaryListPayload { throw unsupported() }
    func binaryAvailable() async throws -> NolonCodexBinaryAvailablePayload { throw unsupported() }
    func binaryCurrent() async throws -> NolonCodexBinaryCurrentPayload { throw unsupported() }
    func binaryInstall(version: String, setDefault: Bool) async throws -> NolonCodexBinaryInstallPayload { throw unsupported() }
    func binaryUse(version: String) async throws -> NolonCodexBinaryUsePayload { throw unsupported() }
    func binaryDoctor() async throws -> NolonCodexBinaryDoctorPayload { throw unsupported() }
    func statusProbe(providerID: String?) async throws -> NolonCodexStatusProbePayload { throw unsupported() }
    func runtimeList(providerID: String?) async throws -> NolonCodexRuntimeListPayload { throw unsupported() }
    func runtimeStop(pid: Int32, force: Bool, timeoutSeconds: Int) async throws -> NolonCodexRuntimeStopPayload { throw unsupported() }
    func providerList() async throws -> NolonProviderListPayload { throw unsupported() }
    func providerDiscover() async throws -> NolonCodexProviderDiscoverPayload { throw unsupported() }

    func authUsage(providerID: String) async throws -> NolonCodexAuthUsagePayload {
        NolonCodexAuthUsagePayload(
            providerID: providerID,
            accounts: [
                NolonCodexAuthUsageAccountView(
                    id: UUID(uuidString: "12121212-1212-1212-1212-121212121212")!,
                    email: "a@example.com",
                    isActive: true,
                    usageSource: "CLI(global)",
                    fiveHourRemainingPercent: 90,
                    weeklyRemainingPercent: 50,
                    token1dCount: 125_600_000,
                    token30dCount: 4_674_400_000,
                    tokenAllCount: 4_674_400_000,
                    refreshedAt: Date()
                ),
                NolonCodexAuthUsageAccountView(
                    id: UUID(uuidString: "34343434-3434-3434-3434-343434343434")!,
                    email: "b@example.com",
                    isActive: false,
                    usageSource: "CLI(global)",
                    fiveHourRemainingPercent: 88,
                    weeklyRemainingPercent: 49,
                    token1dCount: 125_600_000,
                    token30dCount: 4_674_400_000,
                    tokenAllCount: 4_674_400_000,
                    refreshedAt: Date()
                ),
            ],
            summary: NolonCodexAuthUsageSummaryView(
                accountCount: 2,
                cachedCount: 2,
                avgFiveHourRemainingPercent: 89,
                avgWeeklyRemainingPercent: 49,
                totalToken1dCount: 251_200_000,
                totalToken30dCount: 9_348_800_000,
                totalTokenAllCount: 9_348_800_000,
                latestRefreshedAt: Date()
            )
        )
    }

    private func unsupported() -> NolonCoreCLIError {
        .invalidArguments("unsupported")
    }
}

actor AuthUsageRefreshFailureCodexCLIService: NolonCodexCLIServing {
    func authList(providerID: String) async throws -> NolonCodexAuthListPayload {
        NolonCodexAuthListPayload(providerID: providerID, activeAccountID: nil, accounts: [])
    }
    func authStatus(providerID: String) async throws -> NolonCodexAuthStatusPayload {
        NolonCodexAuthStatusPayload(providerID: providerID, activeAccountID: nil, accountCount: 1, authHashHex: "refresh-failure")
    }
    func authActivate(providerID: String, accountID: UUID) async throws -> NolonCodexAuthActivatePayload { throw unsupported() }
    func authLogin(providerID: String, preferredAccountID: UUID?) async throws -> NolonCodexAuthLoginPayload { throw unsupported() }
    func authDelete(providerID: String, accountID: UUID) async throws -> NolonCodexAuthDeletePayload { throw unsupported() }
    func binaryList() async throws -> NolonCodexBinaryListPayload { throw unsupported() }
    func binaryAvailable() async throws -> NolonCodexBinaryAvailablePayload { throw unsupported() }
    func binaryCurrent() async throws -> NolonCodexBinaryCurrentPayload { throw unsupported() }
    func binaryInstall(version: String, setDefault: Bool) async throws -> NolonCodexBinaryInstallPayload { throw unsupported() }
    func binaryUse(version: String) async throws -> NolonCodexBinaryUsePayload { throw unsupported() }
    func binaryDoctor() async throws -> NolonCodexBinaryDoctorPayload { throw unsupported() }
    func statusProbe(providerID: String?) async throws -> NolonCodexStatusProbePayload { throw unsupported() }
    func runtimeList(providerID: String?) async throws -> NolonCodexRuntimeListPayload { throw unsupported() }
    func runtimeStop(pid: Int32, force: Bool, timeoutSeconds: Int) async throws -> NolonCodexRuntimeStopPayload { throw unsupported() }
    func providerList() async throws -> NolonProviderListPayload { throw unsupported() }
    func providerDiscover() async throws -> NolonCodexProviderDiscoverPayload { throw unsupported() }

    func authUsage(providerID: String) async throws -> NolonCodexAuthUsagePayload {
        NolonCodexAuthUsagePayload(
            providerID: providerID,
            accounts: [
                NolonCodexAuthUsageAccountView(
                    id: UUID(uuidString: "56565656-5656-5656-5656-565656565656")!,
                    email: "broken@example.com",
                    isActive: true,
                    status: .failed,
                    failureType: .other,
                    fiveHourRemainingPercent: nil,
                    weeklyRemainingPercent: nil,
                    refreshedAt: nil,
                    syncFailedAt: Date(timeIntervalSince1970: 1_740_000_000),
                    syncFailureMessage: "Codex protocol error: 401 Unauthorized"
                )
            ],
            summary: NolonCodexAuthUsageSummaryView(
                accountCount: 1,
                cachedCount: 0,
                avgFiveHourRemainingPercent: nil,
                avgWeeklyRemainingPercent: nil,
                latestRefreshedAt: nil
            )
        )
    }

    private func unsupported() -> NolonCoreCLIError {
        .invalidArguments("unsupported")
    }
}

actor AuthUsageActiveConsistencyCodexCLIService: NolonCodexCLIServing {
    func authList(providerID: String) async throws -> NolonCodexAuthListPayload {
        NolonCodexAuthListPayload(
            providerID: providerID,
            activeAccountID: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"),
            accounts: [
                NolonCodexAuthAccountView(
                    id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
                    name: "first",
                    createdAt: .distantPast,
                    relativeAuthPath: "a/auth.json",
                    isActive: true,
                    email: "first@example.com",
                    usageDisplay: "5h 90% / 7d 60%",
                    refreshedAt: Date(timeIntervalSince1970: 1_733_900_000)
                ),
                NolonCodexAuthAccountView(
                    id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
                    name: "second",
                    createdAt: .distantPast,
                    relativeAuthPath: "b/auth.json",
                    isActive: false,
                    email: "second@example.com",
                    usageDisplay: "5h 30% / 7d 20%",
                    refreshedAt: Date(timeIntervalSince1970: 1_733_900_000)
                ),
            ]
        )
    }

    func authUsage(providerID: String) async throws -> NolonCodexAuthUsagePayload {
        NolonCodexAuthUsagePayload(
            providerID: providerID,
            accounts: [
                NolonCodexAuthUsageAccountView(
                    id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
                    email: "first@example.com",
                    isActive: true,
                    fiveHourRemainingPercent: 90,
                    weeklyRemainingPercent: 60,
                    token1dCount: 100_000,
                    token30dCount: 200_000,
                    tokenAllCount: 300_000,
                    refreshedAt: Date(timeIntervalSince1970: 1_733_900_000)
                ),
                NolonCodexAuthUsageAccountView(
                    id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
                    email: "second@example.com",
                    isActive: false,
                    fiveHourRemainingPercent: 30,
                    weeklyRemainingPercent: 20,
                    token1dCount: 110_000,
                    token30dCount: 220_000,
                    tokenAllCount: 330_000,
                    refreshedAt: Date(timeIntervalSince1970: 1_733_900_000)
                ),
            ],
            summary: NolonCodexAuthUsageSummaryView(
                accountCount: 2,
                cachedCount: 2,
                avgFiveHourRemainingPercent: 60,
                avgWeeklyRemainingPercent: 40,
                totalToken1dCount: 210_000,
                totalToken30dCount: 420_000,
                totalTokenAllCount: 630_000,
                latestRefreshedAt: Date(timeIntervalSince1970: 1_733_900_000)
            )
        )
    }

    func authStatus(providerID: String) async throws -> NolonCodexAuthStatusPayload {
        NolonCodexAuthStatusPayload(
            providerID: providerID,
            activeAccountID: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB"),
            accountCount: 2,
            authHashHex: "consistency"
        )
    }

    func authActivate(providerID: String, accountID: UUID) async throws -> NolonCodexAuthActivatePayload { throw unsupported() }
    func authLogin(providerID: String, preferredAccountID: UUID?) async throws -> NolonCodexAuthLoginPayload { throw unsupported() }
    func authDelete(providerID: String, accountID: UUID) async throws -> NolonCodexAuthDeletePayload { throw unsupported() }
    func binaryList() async throws -> NolonCodexBinaryListPayload { throw unsupported() }
    func binaryAvailable() async throws -> NolonCodexBinaryAvailablePayload { throw unsupported() }
    func binaryCurrent() async throws -> NolonCodexBinaryCurrentPayload { throw unsupported() }
    func binaryInstall(version: String, setDefault: Bool) async throws -> NolonCodexBinaryInstallPayload { throw unsupported() }
    func binaryUse(version: String) async throws -> NolonCodexBinaryUsePayload { throw unsupported() }
    func binaryDoctor() async throws -> NolonCodexBinaryDoctorPayload { throw unsupported() }
    func statusProbe(providerID: String?) async throws -> NolonCodexStatusProbePayload { throw unsupported() }
    func runtimeList(providerID: String?) async throws -> NolonCodexRuntimeListPayload { throw unsupported() }
    func runtimeStop(pid: Int32, force: Bool, timeoutSeconds: Int) async throws -> NolonCodexRuntimeStopPayload { throw unsupported() }
    func providerList() async throws -> NolonProviderListPayload { throw unsupported() }
    func providerDiscover() async throws -> NolonCodexProviderDiscoverPayload { throw unsupported() }

    private func unsupported() -> NolonCoreCLIError {
        .invalidArguments("unsupported")
    }
}

actor AuthListMissingFieldsCodexCLIService: NolonCodexCLIServing {
    func authStatus(providerID: String) async throws -> NolonCodexAuthStatusPayload {
        NolonCodexAuthStatusPayload(providerID: providerID, activeAccountID: nil, accountCount: 1, authHashHex: nil)
    }
    func authActivate(providerID: String, accountID: UUID) async throws -> NolonCodexAuthActivatePayload { throw unsupported() }
    func authLogin(providerID: String, preferredAccountID: UUID?) async throws -> NolonCodexAuthLoginPayload { throw unsupported() }
    func authDelete(providerID: String, accountID: UUID) async throws -> NolonCodexAuthDeletePayload { throw unsupported() }
    func binaryList() async throws -> NolonCodexBinaryListPayload { throw unsupported() }
    func binaryAvailable() async throws -> NolonCodexBinaryAvailablePayload { throw unsupported() }
    func binaryCurrent() async throws -> NolonCodexBinaryCurrentPayload { throw unsupported() }
    func binaryInstall(version: String, setDefault: Bool) async throws -> NolonCodexBinaryInstallPayload { throw unsupported() }
    func binaryUse(version: String) async throws -> NolonCodexBinaryUsePayload { throw unsupported() }
    func binaryDoctor() async throws -> NolonCodexBinaryDoctorPayload { throw unsupported() }
    func statusProbe(providerID: String?) async throws -> NolonCodexStatusProbePayload { throw unsupported() }
    func runtimeList(providerID: String?) async throws -> NolonCodexRuntimeListPayload { throw unsupported() }
    func runtimeStop(pid: Int32, force: Bool, timeoutSeconds: Int) async throws -> NolonCodexRuntimeStopPayload { throw unsupported() }
    func providerList() async throws -> NolonProviderListPayload { throw unsupported() }
    func providerDiscover() async throws -> NolonCodexProviderDiscoverPayload { throw unsupported() }

    func authUsage(providerID: String) async throws -> NolonCodexAuthUsagePayload {
        NolonCodexAuthUsagePayload(
            providerID: providerID,
            accounts: [],
            summary: NolonCodexAuthUsageSummaryView(
                accountCount: 0,
                cachedCount: 0,
                avgFiveHourRemainingPercent: nil,
                avgWeeklyRemainingPercent: nil,
                totalToken1dCount: nil,
                totalToken30dCount: nil,
                totalTokenAllCount: nil,
                earliestExpiresAt: nil,
                latestRefreshedAt: nil
            )
        )
    }

    func authList(providerID: String) async throws -> NolonCodexAuthListPayload {
        NolonCodexAuthListPayload(
            providerID: providerID,
            activeAccountID: nil,
            accounts: [
                NolonCodexAuthAccountView(
                    id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                    name: "unknown",
                    createdAt: .distantPast,
                    relativeAuthPath: "auth/missing.json",
                    isActive: false,
                    email: nil,
                    usageDisplay: nil,
                    refreshedAt: nil
                ),
            ]
        )
    }

    private func unsupported() -> NolonCoreCLIError {
        .invalidArguments("unsupported")
    }
}

    @Test("gemini auth commands route to core cli")
    func geminiAuthCommandsRouteToCoreCLI() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["gemini", "auth", "status", "--provider", "gemini", "--json"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("\"command\":\"gemini.auth.status\""))
        #expect(result.stdout.contains("\"provider\":\"gemini\""))
    }
    @Test("no arguments prints help instead of JSON error")
    func noArgumentsPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(arguments: [], codexService: mock)

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("USAGE: nolon"))
        #expect(result.stdout.contains("SUBCOMMANDS"))
        #expect(result.stdout.contains("skills"))
        #expect(result.stdout.contains("workflow"))
        #expect(result.stdout.contains("mcp"))
        #expect(result.stdout.contains("remote"))
    }
    @Test("leading help command resolves codex action help")
    func leadingHelpCommandResolvesCodexActionHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["help", "codex", "auth", "refresh"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex auth refresh"))
        #expect(result.stdout.contains("切换为活跃账号"))
    }
    @Test("codex --help prints codex help")
    func codexHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon <provider> <group> <action> [options]"))
        #expect(result.stdout.contains("Groups:"))
        #expect(result.stdout.contains("auth"))
        #expect(result.stdout.contains("binary"))
    }
    @Test("skills --help includes task-oriented examples")
    func skillsHelpIncludesExamples() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["skills", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("场景: 搜索技能"))
        #expect(result.stdout.contains("场景: 安装技能"))
        #expect(result.stdout.contains("场景: 修复异常"))
        #expect(result.stdout.contains("nolon skills search xcode"))
        #expect(result.stdout.contains("<keyword> | --query <query>"))
        #expect(result.stdout.contains("--query <query>"))
        #expect(result.stdout.contains("--pick <index>"))
        #expect(result.stdout.contains("nolon skills add xcode --provider codex"))
        #expect(result.stdout.contains("省略 --provider 可能触发多 provider 批量写入/覆盖"))
    }
    @Test("skills search --help explains install and pick relation")
    func skillsSearchHelpExplainsInstallPickRelation() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["skills", "search", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Install matched skill(s);"))
        #expect(result.stdout.contains("Pick one search result by 1-based index"))
        #expect(result.stdout.contains("Target provider ID. Omit to distribute to all"))
        #expect(result.stdout.contains("nolon skills search \"swiftui\" --install --pick 1 --provider codex --dry-run"))
    }
    @Test("skills add --help warns about provider omission scope")
    func skillsAddHelpWarnsAboutProviderOmissionScope() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["skills", "add", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Target provider ID. Omit to distribute to all"))
        #expect(result.stdout.contains("nolon skills add swift-concurrency-expert --provider codex --dry-run"))
    }
    @Test("skills remove --help shows safety note and example")
    func skillsRemoveHelpShowsSafetyNoteAndExample() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["skills", "remove", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("该操作会直接移除 provider 下的技能链接/目录"))
        #expect(result.stdout.contains("nolon skills list --provider <id>"))
        #expect(result.stdout.contains("nolon skills remove --skill-id xcode --provider codex"))
    }
    @Test("codex without group action prints codex help")
    func codexWithoutActionPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon <provider> <group> <action> [options]"))
        #expect(result.stdout.contains("Groups:"))
    }
    @Test("codex auth --help prints auth help")
    func codexAuthHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "auth", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex auth"))
        #expect(result.stdout.contains("Actions:"))
    }
    @Test("codex auth without action prints auth help")
    func codexAuthWithoutActionPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "auth"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex auth"))
        #expect(result.stdout.contains("Actions:"))
    }
    @Test("codex binary --help prints binary help")
    func codexBinaryHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "binary", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex binary"))
        #expect(result.stdout.contains("Actions:"))
        #expect(result.stdout.contains("install"))
        #expect(result.stdout.contains("available"))
    }
    @Test("codex binary without action prints binary help")
    func codexBinaryWithoutActionPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "binary"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex binary"))
        #expect(result.stdout.contains("Actions:"))
    }
    @Test("codex status --help prints status help")
    func codexStatusHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "status", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex status"))
        #expect(result.stdout.contains("Actions:"))
        #expect(result.stdout.contains("probe"))
        #expect(result.stdout.contains("doctor"))
    }
    @Test("codex status without action prints status help")
    func codexStatusWithoutActionPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "status"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex status"))
        #expect(result.stdout.contains("Actions:"))
    }
    @Test("codex runtime --help prints runtime help")
    func codexRuntimeHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "runtime", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex runtime"))
        #expect(result.stdout.contains("Actions:"))
        #expect(result.stdout.contains("list"))
        #expect(result.stdout.contains("stop"))
    }
    @Test("codex provider --help prints provider help")
    func codexProviderHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "provider", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex provider"))
        #expect(result.stdout.contains("Actions:"))
        #expect(result.stdout.contains("discover"))
    }
