import XCTest
import AppKit
import STJSON
import ProviderUsage
import STFilePath
import ProviderCatalog
import CodexBarProviderCatalog
import NolonResourceKit
@testable import nolon

@MainActor
final class ProviderUsageEngineManualRefreshTests: XCTestCase {
    private func makeAuthJSON(email: String) -> String {
        """
        {"tokens":{"id_token":"id-\(UUID().uuidString)","access_token":"access-\(UUID().uuidString)"},"user":{"email":"\(email)"}}
        """
    }

    private func makeStoredAccount(
        name: String,
        manager: CodexAuthManager
    ) async throws -> CodexAuthAccount {
        try await manager.addAccount(name: name, authJSONString: makeAuthJSON(email: "\(name)@example.com"))
    }

    func testBDD_GivenConfiguredAPIKeyAccount_WhenLoadingCodexSummaries_ThenKeepsOfficialAPIKeyCardKind() async throws {
        let isolatedRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("nolon-codex-summary-card-kind-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: isolatedRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: isolatedRoot) }

        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: isolatedRoot.appendingPathComponent("provider/skills").path,
            workflowPath: isolatedRoot.appendingPathComponent("provider/prompts").path,
            installMethod: .symlink,
            templateId: "codex"
        )
        let authManager = CodexAuthManager(rootURL: isolatedRoot)
        let account = try await authManager.addConfiguredAccount(
            name: "direct",
            apiKey: "sk-live-12345678",
            relay: nil
        )
        let viewModel = ProviderUsageEngine(
            provider: provider,
            codexAuthManager: authManager
        )

        let summaries = viewModel.loadCodexAccountSummaries(accounts: [account])

        XCTAssertEqual(summaries[account.id]?.cardKind, .officialAPIKey)
        XCTAssertFalse(viewModel.codexAccountSupportsLogin(accountID: account.id))
    }

    func testBDD_GivenCachedCodexUsage_WhenLoadStarts_ThenCachedCardsAppearBeforePreflightFinishes() async throws {
        let isolatedRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("nolon-codex-cached-load-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: isolatedRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: isolatedRoot) }

        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: isolatedRoot.appendingPathComponent("provider/skills").path,
            workflowPath: isolatedRoot.appendingPathComponent("provider/prompts").path,
            installMethod: .symlink,
            templateId: "codex"
        )
        let service = CodexAuthManager(rootURL: isolatedRoot)
        let added = try await service.addAccount(
            name: "cached",
            authJSONString: #"{"tokens":{"id_token":"cached-id","access_token":"cached-access"},"user":{"email":"cached@example.com"}}"#
        )
        let loadedAccounts = try await service.loadAccounts()
        let account = try XCTUnwrap(loadedAccounts.first(where: { $0.id == added.id }))
        let cache = CodexAuthUsageCache(
            cachedAt: Date(),
            creditsRefreshedAt: nil,
            fetchKind: .web,
            strategyKind: .direct,
            sourceLabel: "HTTP",
            usage: UsageSnapshot(
                identity: UsageIdentity(
                    accountEmail: "cached@example.com",
                    accountOrganization: nil,
                    loginMethod: "oauth",
                    plan: "free"
                ),
                primary: RateWindow(usedPercent: 30, windowMinutes: 60),
                secondary: nil,
                tertiary: nil,
                updatedAt: Date()
            ),
            credits: CreditsSnapshot(remaining: 12, updatedAt: Date()),
            cost: nil
        )
        try await service.storeUsageCache(cache, for: account)

        let gate = AsyncGate()
        let viewModel = ProviderUsageEngine(
            provider: provider,
            codexAuthManager: service,
            codexPreflightAction: { _, forceBackup, reason in
                XCTAssertTrue(forceBackup)
                XCTAssertEqual(reason, "usage_load")
                await gate.wait()
                return nil
            },
            codexOutcomeFetchAction: { account, _, _ in
                ProviderAccountUsageOutcome(
                    provider: .codex,
                    account: .tokenAccount(
                        .init(
                            id: account.id,
                            label: account.name,
                            token: "",
                            addedAt: account.createdAt.timeIntervalSince1970,
                            lastUsed: nil
                        )
                    ),
                    outcome: ProviderFetchOutcome(
                        fetchKind: .web,
                        result: .success(
                            .init(
                                usage: UsageSnapshot(
                                    identity: UsageIdentity(
                                        accountEmail: "fresh@example.com",
                                        accountOrganization: nil,
                                        loginMethod: "oauth",
                                        plan: "free"
                                    ),
                                    primary: RateWindow(usedPercent: 10, windowMinutes: 60),
                                    secondary: nil,
                                    tertiary: nil,
                                    updatedAt: Date()
                                ),
                                credits: CreditsSnapshot(remaining: 24, updatedAt: Date()),
                                cost: nil,
                                sourceLabel: "HTTP",
                                fetchKind: .web,
                                strategyKind: .direct
                            )
                        )
                    )
                )
            }
        )

        let loadTask = Task { await viewModel.load() }

        try await waitUntil { !viewModel.codexAccountOutcomes.isEmpty }
        XCTAssertTrue(viewModel.isLoading)
        let cachedOutcome = try XCTUnwrap(viewModel.codexAccountOutcomes.first)
        guard case let .success(cachedResult) = cachedOutcome.outcome.result else {
            return XCTFail("Expected cached success outcome before preflight finished")
        }
        XCTAssertEqual(cachedResult.usage.identity?.accountEmail, "cached@example.com")
        XCTAssertEqual(cachedResult.credits?.remaining, 12)
        XCTAssertEqual(cachedResult.fetchKind, .web)

        await gate.open()
        await loadTask.value

        let refreshedOutcome = try XCTUnwrap(viewModel.codexAccountOutcomes.first)
        guard case let .success(refreshedResult) = refreshedOutcome.outcome.result else {
            return XCTFail("Expected refreshed success outcome after load finished")
        }
        XCTAssertEqual(refreshedResult.usage.identity?.accountEmail, "fresh@example.com")
        XCTAssertEqual(refreshedResult.credits?.remaining, 24)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testBDD_GivenCachedCodexUsage_WhenInitialLoadIfNeededStarts_ThenCachedCardsAppearBeforePreflightFinishes() async throws {
        let isolatedRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("nolon-codex-cached-load-if-needed-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: isolatedRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: isolatedRoot) }

        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: isolatedRoot.appendingPathComponent("provider/skills").path,
            workflowPath: isolatedRoot.appendingPathComponent("provider/prompts").path,
            installMethod: .symlink,
            templateId: "codex"
        )
        let service = CodexAuthManager(rootURL: isolatedRoot)
        let added = try await service.addAccount(
            name: "cached",
            authJSONString: #"{"tokens":{"id_token":"cached-id","access_token":"cached-access"},"user":{"email":"cached@example.com"}}"#
        )
        let loadedAccounts = try await service.loadAccounts()
        let account = try XCTUnwrap(loadedAccounts.first(where: { $0.id == added.id }))
        let cache = CodexAuthUsageCache(
            cachedAt: Date(),
            creditsRefreshedAt: nil,
            fetchKind: .web,
            strategyKind: .direct,
            sourceLabel: "HTTP",
            usage: UsageSnapshot(
                identity: UsageIdentity(
                    accountEmail: "cached@example.com",
                    accountOrganization: nil,
                    loginMethod: "oauth",
                    plan: "free"
                ),
                primary: RateWindow(usedPercent: 30, windowMinutes: 60),
                secondary: nil,
                tertiary: nil,
                updatedAt: Date()
            ),
            credits: CreditsSnapshot(remaining: 12, updatedAt: Date()),
            cost: nil
        )
        try await service.storeUsageCache(cache, for: account)

        let gate = AsyncGate()
        let viewModel = ProviderUsageEngine(
            provider: provider,
            codexAuthManager: service,
            codexPreflightAction: { _, _, _ in
                await gate.wait()
                return nil
            },
            codexOutcomeFetchAction: { account, _, _ in
                ProviderAccountUsageOutcome(
                    provider: .codex,
                    account: .tokenAccount(
                        .init(
                            id: account.id,
                            label: account.name,
                            token: "",
                            addedAt: account.createdAt.timeIntervalSince1970,
                            lastUsed: nil
                        )
                    ),
                    outcome: ProviderFetchOutcome(
                        fetchKind: .web,
                        result: .success(
                            .init(
                                usage: UsageSnapshot(
                                    identity: UsageIdentity(
                                        accountEmail: "fresh@example.com",
                                        accountOrganization: nil,
                                        loginMethod: "oauth",
                                        plan: "free"
                                    ),
                                    primary: RateWindow(usedPercent: 10, windowMinutes: 60),
                                    secondary: nil,
                                    tertiary: nil,
                                    updatedAt: Date()
                                ),
                                credits: CreditsSnapshot(remaining: 24, updatedAt: Date()),
                                cost: nil,
                                sourceLabel: "HTTP",
                                fetchKind: .web,
                                strategyKind: .direct
                            )
                        )
                    )
                )
            }
        )

        let loadTask = Task { await viewModel.loadIfNeeded() }

        try await waitUntil {
            guard let first = viewModel.codexAccountOutcomes.first,
                  case let .success(result) = first.outcome.result
            else { return false }
            return result.usage.identity?.accountEmail == "cached@example.com"
                && result.credits?.remaining == 12
        }
        let cachedOutcome = try XCTUnwrap(viewModel.codexAccountOutcomes.first)
        guard case let .success(cachedResult) = cachedOutcome.outcome.result else {
            return XCTFail("Expected cached success outcome before preflight finished")
        }
        XCTAssertEqual(cachedResult.usage.identity?.accountEmail, "cached@example.com")
        XCTAssertEqual(cachedResult.credits?.remaining, 12)

        await gate.open()
        _ = await loadTask.value
    }

    func testBDD_GivenInactiveCodexAccountHasPersistedFailure_WhenInitialLoadRuns_ThenInitialRefreshStillFetchesAllAccounts() async throws {
        let isolatedRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("nolon-codex-initial-refresh-all-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: isolatedRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: isolatedRoot) }

        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: isolatedRoot.appendingPathComponent("provider/skills").path,
            workflowPath: isolatedRoot.appendingPathComponent("provider/prompts").path,
            installMethod: .symlink,
            templateId: "codex"
        )
        let service = CodexAuthManager(rootURL: isolatedRoot)
        let active = try await service.addAccount(
            name: "active",
            authJSONString: #"{"tokens":{"id_token":"id-active","access_token":"access-active"},"user":{"email":"active@example.com"}}"#
        )
        let failed = try await service.addAccount(
            name: "failed",
            authJSONString: #"{"tokens":{"id_token":"id-failed","access_token":"access-failed"},"user":{"email":"failed@example.com"}}"#
        )
        try await service.setActiveAccount(active, for: provider)
        try await service.updateSyncFailure(for: failed, message: "401 unauthorized")

        let refreshedIDs = LockedBox<[UUID]>([])
        let viewModel = ProviderUsageEngine(
            provider: provider,
            codexAuthManager: service,
            codexPreflightAction: { _, _, _ in nil },
            codexOutcomeFetchAction: { account, _, _ in
                await refreshedIDs.set((await refreshedIDs.value()) + [account.id])
                return ProviderAccountUsageOutcome(
                    provider: .codex,
                    account: .tokenAccount(
                        .init(
                            id: account.id,
                            label: account.name,
                            token: "",
                            addedAt: account.createdAt.timeIntervalSince1970,
                            lastUsed: nil
                        )
                    ),
                    outcome: ProviderFetchOutcome(
                        fetchKind: .web,
                        result: .success(
                            .init(
                                usage: UsageSnapshot(
                                    identity: UsageIdentity(
                                        accountEmail: "\(account.name)@example.com",
                                        accountOrganization: nil,
                                        loginMethod: "oauth",
                                        plan: "free"
                                    ),
                                    primary: RateWindow(usedPercent: 10, windowMinutes: 60),
                                    secondary: nil,
                                    tertiary: nil,
                                    updatedAt: Date()
                                ),
                                credits: nil,
                                cost: nil,
                                sourceLabel: "HTTP",
                                fetchKind: .web,
                                strategyKind: .direct
                            )
                        )
                    )
                )
            }
        )

        await viewModel.load()

        let refreshed = await refreshedIDs.value()
        XCTAssertEqual(Set(refreshed), Set([active.id, failed.id]))
    }

    func testBDD_GivenExistingCodexQuota_WhenRefreshFails_ThenInvalidatesPreviousSuccessOutcomeAndClearsUsageCache() async throws {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let authManager = CodexAuthManager(
            rootURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("nolon-invalidate-quota-on-failure-\(UUID().uuidString)", isDirectory: true)
        )
        let account = try await makeStoredAccount(name: "retain", manager: authManager)
        let cache = CodexAuthUsageCache(
            cachedAt: Date(),
            creditsRefreshedAt: Date(),
            fetchKind: .web,
            strategyKind: .direct,
            sourceLabel: "HTTP",
            usage: UsageSnapshot(
                identity: UsageIdentity(
                    accountEmail: "retain@example.com",
                    accountOrganization: nil,
                    loginMethod: "oauth",
                    plan: "plus"
                ),
                primary: RateWindow(usedPercent: 20, windowMinutes: 60),
                secondary: nil,
                tertiary: nil,
                updatedAt: Date()
            ),
            credits: CreditsSnapshot(remaining: 18, updatedAt: Date()),
            cost: nil
        )
        try await authManager.storeUsageCache(cache, for: account)
        let viewModel = ProviderUsageEngine(
            provider: provider,
            codexAuthManager: authManager,
            codexOutcomeFetchAction: { account, _, _ in
                ProviderAccountUsageOutcome(
                    provider: .codex,
                    account: .tokenAccount(
                        .init(
                            id: account.id,
                            label: account.name,
                            token: "",
                            addedAt: account.createdAt.timeIntervalSince1970,
                            lastUsed: nil
                        )
                    ),
                    outcome: ProviderFetchOutcome(
                        fetchKind: .cli,
                        result: .failure(UsageViewModelTestError(message: "request timed out"))
                    )
                )
            }
        )

        viewModel.codexAccounts = [account]
        viewModel.codexAccountOutcomes = [
            ProviderAccountUsageOutcome(
                provider: .codex,
                account: .tokenAccount(
                    .init(
                        id: account.id,
                        label: account.name,
                        token: "",
                        addedAt: account.createdAt.timeIntervalSince1970,
                        lastUsed: nil
                    )
                ),
                outcome: ProviderFetchOutcome(
                    fetchKind: .web,
                    result: .success(
                        .init(
                            usage: UsageSnapshot(
                                identity: UsageIdentity(
                                    accountEmail: "retain@example.com",
                                    accountOrganization: nil,
                                    loginMethod: "oauth",
                                    plan: "plus"
                                ),
                                primary: RateWindow(usedPercent: 20, windowMinutes: 60),
                                secondary: nil,
                                tertiary: nil,
                                updatedAt: Date()
                            ),
                            credits: CreditsSnapshot(remaining: 18, updatedAt: Date()),
                            cost: nil,
                            sourceLabel: "HTTP",
                            fetchKind: .web,
                            strategyKind: .direct
                        )
                    )
                )
            )
        ]

        await viewModel.refreshCodexAccountImmediately(id: account.id)

        let refreshed = try XCTUnwrap(viewModel.codexAccountOutcomes.first)
        guard case let .failure(error) = refreshed.outcome.result else {
            return XCTFail("Expected failure outcome to replace stale success")
        }
        XCTAssertEqual(error.localizedDescription, "request timed out")
        XCTAssertEqual(viewModel.codexAccountSummaries[account.id]?.lastSyncFailureMessage, "request timed out")
        let persistedCache = try await authManager.loadUsageCache(for: account)
        XCTAssertNil(persistedCache)
        XCTAssertNil(viewModel.codexAccountCreditsRefreshedAt[account.id])
    }

    func testBDD_GivenPersistedUsageCacheAndFailureMetadata_WhenReloadingFromDisk_ThenDoesNotRestoreStaleQuotaAsSuccess() async throws {
        let isolatedRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("nolon-codex-stale-cache-reload-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: isolatedRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: isolatedRoot) }

        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: isolatedRoot.appendingPathComponent("provider/skills").path,
            workflowPath: isolatedRoot.appendingPathComponent("provider/prompts").path,
            installMethod: .symlink,
            templateId: "codex"
        )
        let authManager = CodexAuthManager(rootURL: isolatedRoot)
        let account = try await makeStoredAccount(name: "stale", manager: authManager)
        let staleCache = CodexAuthUsageCache(
            cachedAt: Date(),
            creditsRefreshedAt: Date(),
            fetchKind: .web,
            strategyKind: .direct,
            sourceLabel: "HTTP",
            usage: UsageSnapshot(
                identity: UsageIdentity(
                    accountEmail: "stale@example.com",
                    accountOrganization: nil,
                    loginMethod: "oauth",
                    plan: "plus"
                ),
                primary: RateWindow(usedPercent: 20, windowMinutes: 60),
                secondary: nil,
                tertiary: nil,
                updatedAt: Date()
            ),
            credits: CreditsSnapshot(remaining: 18, updatedAt: Date()),
            cost: nil
        )
        try await authManager.storeUsageCache(staleCache, for: account)
        try await authManager.updateSyncFailure(
            for: account,
            message: "Authentication expired. Please sign in again.",
            date: Date()
        )

        let viewModel = ProviderUsageEngine(
            provider: provider,
            codexAuthManager: authManager
        )

        await viewModel.reloadCodexFromDisk(refreshUsage: false)

        let restored = try XCTUnwrap(viewModel.codexAccountOutcomes.first)
        guard case let .failure(error) = restored.outcome.result else {
            return XCTFail("Expected persisted failure metadata to invalidate stale cache outcome")
        }
        XCTAssertEqual(error.localizedDescription, "Authentication expired. Please sign in again.")
        XCTAssertNil(viewModel.codexAccountCreditsRefreshedAt[account.id])
    }

    func testBDD_GivenExternalSQLiteMetadataOnlyUpdate_WhenObservationActive_ThenReloadsCachedOutcomes() async throws {
        let isolatedRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("nolon-codex-sqlite-metadata-observation-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: isolatedRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: isolatedRoot) }

        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: isolatedRoot.appendingPathComponent("provider/skills").path,
            workflowPath: isolatedRoot.appendingPathComponent("provider/prompts").path,
            installMethod: .symlink,
            templateId: "codex"
        )
        let authManager = CodexAuthManager(rootURL: isolatedRoot)
        let added = try await authManager.addAccount(
            name: "observed",
            authJSONString: #"{"tokens":{"id_token":"initial-id","access_token":"initial-access"},"user":{"email":"initial@example.com"}}"#
        )
        let loadedAccounts = try await authManager.loadAccounts()
        let account = try XCTUnwrap(loadedAccounts.first(where: { $0.id == added.id }))
        let initialCache = CodexAuthUsageCache(
            cachedAt: Date(),
            creditsRefreshedAt: Date(),
            fetchKind: .web,
            strategyKind: .direct,
            sourceLabel: "HTTP",
            usage: UsageSnapshot(
                identity: UsageIdentity(
                    accountEmail: "initial@example.com",
                    accountOrganization: nil,
                    loginMethod: "oauth",
                    plan: "plus"
                ),
                primary: RateWindow(usedPercent: 10, windowMinutes: 60),
                secondary: nil,
                tertiary: nil,
                updatedAt: Date()
            ),
            credits: CreditsSnapshot(remaining: 12, updatedAt: Date()),
            cost: nil
        )
        try await authManager.storeUsageCache(initialCache, for: account)

        let viewModel = ProviderUsageEngine(
            provider: provider,
            codexAuthManager: authManager
        )

        await viewModel.reloadCodexFromDisk(refreshUsage: false)
        XCTAssertEqual(viewModel.codexDiskReloadCountForTesting, 1)
        let watchedPaths = await MainActor.run { viewModel.watchedPathsForTesting() }
        XCTAssertTrue(watchedPaths.contains(authManager.accountsSQLiteFile().url.path))
        XCTAssertTrue(watchedPaths.contains(authManager.accountsSQLiteFile().url.deletingLastPathComponent().path))
        let initialOutcome = try XCTUnwrap(viewModel.codexAccountOutcomes.first)
        guard case let .success(initialResult) = initialOutcome.outcome.result else {
            return XCTFail("Expected initial cached outcome to load as success")
        }
        XCTAssertEqual(initialResult.usage.identity?.accountEmail, "initial@example.com")
        XCTAssertEqual(initialResult.credits?.remaining, 12)

        let externalManager = CodexAuthManager(rootURL: isolatedRoot)
        let externalAccounts = try await externalManager.loadAccounts()
        let externalAccount = try XCTUnwrap(externalAccounts.first(where: { $0.id == account.id }))
        let refreshedCache = CodexAuthUsageCache(
            cachedAt: Date(),
            creditsRefreshedAt: Date(),
            fetchKind: .web,
            strategyKind: .direct,
            sourceLabel: "HTTP",
            usage: UsageSnapshot(
                identity: UsageIdentity(
                    accountEmail: "external@example.com",
                    accountOrganization: nil,
                    loginMethod: "oauth",
                    plan: "pro"
                ),
                primary: RateWindow(usedPercent: 40, windowMinutes: 60),
                secondary: nil,
                tertiary: nil,
                updatedAt: Date()
            ),
            credits: CreditsSnapshot(remaining: 30, updatedAt: Date()),
            cost: nil
        )

        try await externalManager.storeUsageCache(refreshedCache, for: externalAccount)

        try await waitUntil(timeout: 3.0) {
            guard viewModel.codexDiskReloadCountForTesting >= 2,
                  let reloadedOutcome = viewModel.codexAccountOutcomes.first,
                  case let .success(reloadedResult) = reloadedOutcome.outcome.result
            else {
                return false
            }
            return reloadedResult.usage.identity?.accountEmail == "external@example.com"
                && reloadedResult.credits?.remaining == 30
        }

        let reloadedOutcome = try XCTUnwrap(viewModel.codexAccountOutcomes.first)
        guard case let .success(reloadedResult) = reloadedOutcome.outcome.result else {
            return XCTFail("Expected SQLite metadata update to reload cached outcome")
        }
        XCTAssertEqual(reloadedResult.usage.identity?.accountEmail, "external@example.com")
        XCTAssertEqual(reloadedResult.credits?.remaining, 30)
    }

    func testBDD_GivenOfficialAPIKeyRefreshFails_WhenRefreshing_ThenClearsFailureMetadata() async throws {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let authManager = CodexAuthManager(
            rootURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("nolon-official-api-key-refresh-failure-\(UUID().uuidString)", isDirectory: true)
        )
        let account = try await makeStoredAccount(name: "self-managed", manager: authManager)
        try await authManager.updateSyncFailure(for: account, message: "OpenAI API key rejected")

        let viewModel = ProviderUsageEngine(
            provider: provider,
            codexAuthManager: authManager,
            codexOutcomeFetchAction: { account, _, _ in
                ProviderAccountUsageOutcome(
                    provider: .codex,
                    account: .tokenAccount(
                        .init(
                            id: account.id,
                            label: account.name,
                            token: "",
                            addedAt: account.createdAt.timeIntervalSince1970,
                            lastUsed: nil
                        )
                    ),
                    outcome: ProviderFetchOutcome(
                        fetchKind: .web,
                        result: .failure(UsageViewModelTestError(message: "OpenAI API key rejected"))
                    )
                )
            }
        )

        viewModel.codexAccounts = [account]
        viewModel.codexAccountSummaries[account.id] = CodexAuthSummary(
            cardKind: .officialAPIKey,
            lastSyncFailedAt: Date(),
            lastSyncFailureMessage: "OpenAI API key rejected"
        )

        await viewModel.refreshCodexAccountImmediately(id: account.id)

        XCTAssertNil(viewModel.codexAccountSummaries[account.id]?.lastSyncFailedAt)
        XCTAssertNil(viewModel.codexAccountSummaries[account.id]?.lastSyncFailureMessage)
        let persisted = CodexAuthSummary.fromJSONData(try XCTUnwrap(authManager.accountAuthData(for: account)))
        XCTAssertNil(persisted.lastSyncFailedAt)
        XCTAssertNil(persisted.lastSyncFailureMessage)
    }

    func testBDD_GivenUsageViewAppearsAgain_WhenHandlingAppear_ThenDoesNotTriggerCodexRefresh() async {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )

        let account = CodexAuthAccount(name: "test", relativeAuthPath: "auth/test.json")
        let refreshCount = LockedBox<Int>(0)
        let viewModel = ProviderUsageEngine(
            provider: provider,
            codexOutcomeFetchAction: { account, _, _ in
                await refreshCount.set((await refreshCount.value()) + 1)
                return ProviderAccountUsageOutcome(
                    provider: .codex,
                    account: .tokenAccount(
                        .init(
                            id: account.id,
                            label: account.name,
                            token: "",
                            addedAt: account.createdAt.timeIntervalSince1970,
                            lastUsed: nil
                        )
                    ),
                    outcome: ProviderFetchOutcome(
                        fetchKind: .cli,
                        result: .failure(UsageViewModelTestError(message: "should not refresh on appear"))
                    )
                )
            }
        )
        viewModel.codexAccounts = [account]
        viewModel.activeCodexAccountId = account.id

        await viewModel.handleUsageViewAppear()

        let count = await refreshCount.value()
        XCTAssertEqual(count, 0)
        XCTAssertTrue(viewModel.codexRefreshingAccountIds.isEmpty)
    }

    func testBDD_GivenCodexActiveAccount_WhenEvaluatingScheduledRefreshDecision_ThenUses5MinuteWindow() async throws {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let authManager = CodexAuthManager(
            rootURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("nolon-active-window-\(UUID().uuidString)", isDirectory: true)
        )
        let account = try await makeStoredAccount(name: "active", manager: authManager)
        let viewModel = ProviderUsageEngine(
            provider: provider,
            codexAuthManager: authManager,
            codexPreflightAction: { _, _, _ in nil },
            codexOutcomeFetchAction: { account, _, _ in
                ProviderAccountUsageOutcome(
                    provider: .codex,
                    account: .tokenAccount(.init(id: account.id, label: account.name, token: "", addedAt: account.createdAt.timeIntervalSince1970, lastUsed: nil)),
                    outcome: ProviderFetchOutcome(
                        fetchKind: .cli,
                        result: .success(
                            .init(
                                usage: UsageSnapshot(
                                    identity: UsageIdentity(accountEmail: "active@example.com", accountOrganization: nil, loginMethod: "oauth", plan: "plus"),
                                    primary: nil,
                                    secondary: nil,
                                    tertiary: nil,
                                    updatedAt: Date()
                                ),
                                credits: nil,
                                cost: nil,
                                sourceLabel: "CLI",
                                fetchKind: .cli,
                                strategyKind: .direct
                            )
                        )
                    )
                )
            }
        )
        viewModel.codexAccounts = [account]
        viewModel.activeCodexAccountId = account.id
        viewModel.codexAccountSummaries[account.id] = CodexAuthSummary(lastSyncSucceededAt: Date())

        await viewModel.refreshCodexAccountImmediately(id: account.id)

        let waitDecision = viewModel.codexScheduledRefreshDecision(for: account, now: Date().addingTimeInterval(4 * 60))
        XCTAssertFalse(waitDecision.shouldRefresh)
        XCTAssertEqual(waitDecision.reason, "codex_active_wait")

        let dueDecision = viewModel.codexScheduledRefreshDecision(for: account, now: Date().addingTimeInterval(6 * 60))
        XCTAssertTrue(dueDecision.shouldRefresh)
        XCTAssertEqual(dueDecision.reason, "codex_active_due")
    }

    func testBDD_GivenCodexRecentAccount_WhenEvaluatingScheduledRefreshDecision_ThenUses15MinuteWindow() {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let account = CodexAuthAccount(name: "recent", relativeAuthPath: "auth/recent.json")
        let viewModel = ProviderUsageEngine(provider: provider)
        viewModel.codexAccounts = [account]
        viewModel.activeCodexAccountId = nil
        viewModel.codexAccountSummaries[account.id] = CodexAuthSummary(lastSyncSucceededAt: Date().addingTimeInterval(-10 * 60))

        let dueDecision = viewModel.codexScheduledRefreshDecision(for: account, now: Date())
        XCTAssertTrue(dueDecision.shouldRefresh)
        XCTAssertEqual(dueDecision.reason, "codex_recent_due")
    }

    func testBDD_GivenCodexActiveAccountWithShortestWindowHighUsage_WhenEvaluatingDecision_ThenUsesTiered3MinuteInterval() async throws {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let authManager = CodexAuthManager(
            rootURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("nolon-active-tier-\(UUID().uuidString)", isDirectory: true)
        )
        let account = try await makeStoredAccount(name: "active-tier", manager: authManager)
        let viewModel = ProviderUsageEngine(
            provider: provider,
            codexAuthManager: authManager,
            codexOutcomeFetchAction: { account, _, _ in
                Self.makeScheduledRefreshOutcome(
                    account: account,
                    windows: [
                        ("short", "Short", 300, 95),
                        ("weekly", "Weekly", 10_080, 40)
                    ]
                )
            }
        )
        viewModel.codexAccounts = [account]
        viewModel.activeCodexAccountId = account.id
        viewModel.codexAccountSummaries[account.id] = CodexAuthSummary(lastSyncSucceededAt: Date())

        await viewModel.refreshCodexAccountImmediately(id: account.id)

        let waitDecision = viewModel.codexScheduledRefreshDecision(for: account, now: Date().addingTimeInterval(2 * 60))
        XCTAssertFalse(waitDecision.shouldRefresh)
        XCTAssertTrue(waitDecision.reason.hasPrefix("codex_active_tier_ge90_w300_u95_"))

        let dueDecision = viewModel.codexScheduledRefreshDecision(for: account, now: Date().addingTimeInterval(4 * 60))
        XCTAssertTrue(dueDecision.shouldRefresh)
        XCTAssertTrue(dueDecision.reason.hasPrefix("codex_active_tier_ge90_w300_u95_"))
    }

    func testBDD_GivenCodexRecentAccountWithShortestWindowMediumUsage_WhenEvaluatingDecision_ThenUsesTiered10MinuteInterval() async throws {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let authManager = CodexAuthManager(
            rootURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("nolon-recent-tier-\(UUID().uuidString)", isDirectory: true)
        )
        let account = try await makeStoredAccount(name: "recent-tier", manager: authManager)
        let viewModel = ProviderUsageEngine(
            provider: provider,
            codexAuthManager: authManager,
            codexOutcomeFetchAction: { account, _, _ in
                Self.makeScheduledRefreshOutcome(
                    account: account,
                    windows: [
                        ("short", "Short", 300, 55),
                        ("weekly", "Weekly", 10_080, 20)
                    ]
                )
            }
        )
        viewModel.codexAccounts = [account]
        viewModel.activeCodexAccountId = nil
        viewModel.codexAccountSummaries[account.id] = CodexAuthSummary(lastSyncSucceededAt: Date())

        await viewModel.refreshCodexAccountImmediately(id: account.id)

        let waitDecision = viewModel.codexScheduledRefreshDecision(for: account, now: Date().addingTimeInterval(9 * 60))
        XCTAssertFalse(waitDecision.shouldRefresh)
        XCTAssertTrue(waitDecision.reason.hasPrefix("codex_recent_tier_ge50_w300_u55_"))

        let dueDecision = viewModel.codexScheduledRefreshDecision(for: account, now: Date().addingTimeInterval(11 * 60))
        XCTAssertTrue(dueDecision.shouldRefresh)
        XCTAssertTrue(dueDecision.reason.hasPrefix("codex_recent_tier_ge50_w300_u55_"))
    }

    func testBDD_GivenCodexLongestWindowZeroQuota_WhenEvaluatingDecision_ThenUses60MinuteThrottleAndRecoversToTiered() async throws {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let authManager = CodexAuthManager(
            rootURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("nolon-zero-long-\(UUID().uuidString)", isDirectory: true)
        )
        let account = try await makeStoredAccount(name: "zero-long", manager: authManager)
        let viewModel = ProviderUsageEngine(
            provider: provider,
            codexAuthManager: authManager,
            codexOutcomeFetchAction: { account, _, _ in
                Self.makeScheduledRefreshOutcome(
                    account: account,
                    windows: [
                        ("short", "Short", 300, 95),
                        ("weekly", "Weekly", 10_080, 100)
                    ]
                )
            }
        )
        viewModel.codexAccounts = [account]
        viewModel.activeCodexAccountId = account.id
        viewModel.codexAccountSummaries[account.id] = CodexAuthSummary(lastSyncSucceededAt: Date())

        await viewModel.refreshCodexAccountImmediately(id: account.id)

        let throttledWait = viewModel.codexScheduledRefreshDecision(for: account, now: Date().addingTimeInterval(10 * 60))
        XCTAssertFalse(throttledWait.shouldRefresh)
        XCTAssertTrue(throttledWait.reason.hasPrefix("codex_longest_zero_quota_w10080_r0_"))

        let throttledDue = viewModel.codexScheduledRefreshDecision(for: account, now: Date().addingTimeInterval(61 * 60))
        XCTAssertTrue(throttledDue.shouldRefresh)
        XCTAssertTrue(throttledDue.reason.hasPrefix("codex_longest_zero_quota_w10080_r0_"))

        viewModel.codexAccountOutcomes = [
            Self.makeScheduledRefreshOutcome(
                account: account,
                windows: [
                    ("short", "Short", 300, 95),
                    ("weekly", "Weekly", 10_080, 40)
                ]
            )
        ]

        let recoveredTier = viewModel.codexScheduledRefreshDecision(for: account, now: Date().addingTimeInterval(4 * 60))
        XCTAssertTrue(recoveredTier.shouldRefresh)
        XCTAssertTrue(recoveredTier.reason.hasPrefix("codex_active_tier_ge90_w300_u95_"))
    }

    func testBDD_GivenShortestWindowResetReachedAtZero_WhenEvaluatingDecision_ThenTriggersOneImmediateRefresh() async throws {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let authManager = CodexAuthManager(
            rootURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("nolon-short-reset-\(UUID().uuidString)", isDirectory: true)
        )
        let account = try await makeStoredAccount(name: "short-reset", manager: authManager)
        let resetAt = Date().addingTimeInterval(-5)
        let viewModel = ProviderUsageEngine(
            provider: provider,
            codexAuthManager: authManager,
            codexOutcomeFetchAction: { account, _, _ in
                let usage = UsageSnapshot(
                    identity: UsageIdentity(accountEmail: "short-reset@example.com", accountOrganization: nil, loginMethod: "oauth", plan: "plus"),
                    windows: [
                        UsageWindow(
                            id: "short",
                            title: "Short",
                            window: RateWindow(usedPercent: 100, resetsAt: resetAt, windowMinutes: 300)
                        ),
                        UsageWindow(
                            id: "weekly",
                            title: "Weekly",
                            window: RateWindow(usedPercent: 60, windowMinutes: 10_080)
                        ),
                    ],
                    primary: nil,
                    secondary: nil,
                    tertiary: nil,
                    updatedAt: Date()
                )
                let result = ProviderFetchResult(
                    usage: usage,
                    credits: nil,
                    cost: nil,
                    sourceLabel: "CLI",
                    fetchKind: .cli,
                    strategyKind: .direct
                )
                return ProviderAccountUsageOutcome(
                    provider: .codex,
                    account: .tokenAccount(
                        .init(
                            id: account.id,
                            label: account.name,
                            token: "",
                            addedAt: account.createdAt.timeIntervalSince1970,
                            lastUsed: nil
                        )
                    ),
                    outcome: ProviderFetchOutcome(fetchKind: .cli, result: .success(result))
                )
            }
        )
        viewModel.codexAccounts = [account]
        viewModel.activeCodexAccountId = account.id
        viewModel.codexAccountSummaries[account.id] = CodexAuthSummary(lastSyncSucceededAt: Date())
        viewModel.codexAccountOutcomes = [
            ProviderAccountUsageOutcome(
                provider: .codex,
                account: .tokenAccount(
                    .init(
                        id: account.id,
                        label: account.name,
                        token: "",
                        addedAt: account.createdAt.timeIntervalSince1970,
                        lastUsed: nil
                    )
                ),
                outcome: ProviderFetchOutcome(
                    fetchKind: .cli,
                    result: .success(
                        .init(
                            usage: UsageSnapshot(
                                identity: UsageIdentity(accountEmail: "short-reset@example.com", accountOrganization: nil, loginMethod: "oauth", plan: "plus"),
                                windows: [
                                    UsageWindow(
                                        id: "short",
                                        title: "Short",
                                        window: RateWindow(usedPercent: 100, resetsAt: resetAt, windowMinutes: 300)
                                    ),
                                    UsageWindow(
                                        id: "weekly",
                                        title: "Weekly",
                                        window: RateWindow(usedPercent: 60, windowMinutes: 10_080)
                                    ),
                                ],
                                primary: nil,
                                secondary: nil,
                                tertiary: nil,
                                updatedAt: Date()
                            ),
                            credits: nil,
                            cost: nil,
                            sourceLabel: "CLI",
                            fetchKind: .cli,
                            strategyKind: .direct
                        )
                    )
                )
            )
        ]

        let immediateDecision = viewModel.codexScheduledRefreshDecision(for: account, now: Date())
        XCTAssertTrue(immediateDecision.shouldRefresh)
        XCTAssertTrue(immediateDecision.reason.hasPrefix("codex_shortest_reset_w300_r0_"))

        await viewModel.refreshCodexAccountImmediately(id: account.id)

        let duplicateDecision = viewModel.codexScheduledRefreshDecision(for: account, now: Date().addingTimeInterval(1))
        XCTAssertFalse(duplicateDecision.shouldRefresh)
        XCTAssertTrue(duplicateDecision.reason.hasPrefix("codex_shortest_reset_w300_r0_"))
        XCTAssertTrue(duplicateDecision.reason.hasSuffix("_already_refreshed"))
    }

    func testBDD_GivenSingleWindowResetReachedAtZero_WhenEvaluatingDecision_ThenStillTriggersImmediateRefresh() async throws {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let authManager = CodexAuthManager(
            rootURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("nolon-single-short-reset-\(UUID().uuidString)", isDirectory: true)
        )
        let account = try await makeStoredAccount(name: "single-short-reset", manager: authManager)
        let resetAt = Date().addingTimeInterval(-5)
        let viewModel = ProviderUsageEngine(provider: provider, codexAuthManager: authManager)
        viewModel.codexAccounts = [account]
        viewModel.activeCodexAccountId = account.id
        viewModel.codexAccountSummaries[account.id] = CodexAuthSummary(lastSyncSucceededAt: Date())
        viewModel.codexAccountOutcomes = [
            ProviderAccountUsageOutcome(
                provider: .codex,
                account: .tokenAccount(
                    .init(
                        id: account.id,
                        label: account.name,
                        token: "",
                        addedAt: account.createdAt.timeIntervalSince1970,
                        lastUsed: nil
                    )
                ),
                outcome: ProviderFetchOutcome(
                    fetchKind: .cli,
                    result: .success(
                        .init(
                            usage: UsageSnapshot(
                                identity: UsageIdentity(accountEmail: "single-short-reset@example.com", accountOrganization: nil, loginMethod: "oauth", plan: "plus"),
                                windows: [
                                    UsageWindow(
                                        id: "short",
                                        title: "Short",
                                        window: RateWindow(usedPercent: 100, resetsAt: resetAt, windowMinutes: 300)
                                    ),
                                ],
                                primary: nil,
                                secondary: nil,
                                tertiary: nil,
                                updatedAt: Date()
                            ),
                            credits: nil,
                            cost: nil,
                            sourceLabel: "CLI",
                            fetchKind: .cli,
                            strategyKind: .direct
                        )
                    )
                )
            )
        ]

        let decision = viewModel.codexScheduledRefreshDecision(for: account, now: Date())
        XCTAssertTrue(decision.shouldRefresh)
        XCTAssertTrue(decision.reason.hasPrefix("codex_shortest_reset_w300_r0_"))
    }

    func testBDD_GivenCodexFailureStreak_WhenEvaluatingScheduledRefreshDecision_ThenBackoffEscalatesFrom30To60Minutes() async throws {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let authManager = CodexAuthManager(
            rootURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("nolon-failure-streak-\(UUID().uuidString)", isDirectory: true)
        )
        let account = try await makeStoredAccount(name: "failed", manager: authManager)
        let viewModel = ProviderUsageEngine(
            provider: provider,
            codexAuthManager: authManager,
            codexOutcomeFetchAction: { account, _, _ in
                ProviderAccountUsageOutcome(
                    provider: .codex,
                    account: .tokenAccount(.init(id: account.id, label: account.name, token: "", addedAt: account.createdAt.timeIntervalSince1970, lastUsed: nil)),
                    outcome: ProviderFetchOutcome(fetchKind: .cli, result: .failure(UsageViewModelTestError(message: "failed refresh")))
                )
            }
        )
        viewModel.codexAccounts = [account]
        viewModel.activeCodexAccountId = account.id
        viewModel.codexAccountSummaries[account.id] = CodexAuthSummary(
            lastSyncSucceededAt: Date().addingTimeInterval(-3_600),
            lastSyncFailedAt: Date(),
            lastSyncFailureMessage: "failed"
        )

        await viewModel.refreshCodexAccountImmediately(id: account.id)
        await viewModel.refreshCodexAccountImmediately(id: account.id)

        let decisionAt31m = viewModel.codexScheduledRefreshDecision(for: account, now: Date().addingTimeInterval(31 * 60))
        XCTAssertFalse(decisionAt31m.shouldRefresh)
        XCTAssertEqual(decisionAt31m.reason, "codex_backoff_wait_2")

        let decisionAt61m = viewModel.codexScheduledRefreshDecision(for: account, now: Date().addingTimeInterval(61 * 60))
        XCTAssertTrue(decisionAt61m.shouldRefresh)
        XCTAssertEqual(decisionAt61m.reason, "codex_backoff_due_2")

        viewModel.codexAccountOutcomes = [
            Self.makeScheduledRefreshOutcome(
                account: account,
                windows: [
                    ("short", "Short", 300, 95),
                    ("weekly", "Weekly", 10_080, 100)
                ]
            )
        ]

        let precedenceDecision = viewModel.codexScheduledRefreshDecision(for: account, now: Date().addingTimeInterval(31 * 60))
        XCTAssertFalse(precedenceDecision.shouldRefresh)
        XCTAssertEqual(precedenceDecision.reason, "codex_backoff_wait_2")
    }

    func testBDD_GivenBalancedProfile_WhenResolvingNonCodexInterval_ThenUses15Minutes() {
        let provider = Provider(
            name: "Claude",
            defaultSkillsPath: "/tmp/claude-skills",
            workflowPath: "/tmp/claude-prompts",
            installMethod: .symlink,
            templateId: "claudeCode"
        )
        let viewModel = ProviderUsageEngine(provider: provider)
        let interval = viewModel.refreshInterval(for: .balanced, role: .nonCodex)
        XCTAssertEqual(interval, 15 * 60)
    }

    func testBDD_GivenHeaderRefresh_WhenCodexMultiAccount_ThenRefreshActionRunsForAllAccounts() async {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )

        let failed = CodexAuthAccount(name: "failed", relativeAuthPath: "auth/failed.json")
        let healthy = CodexAuthAccount(name: "healthy", relativeAuthPath: "auth/healthy.json")
        let refreshedIDs = LockedBox<[UUID]>([])

        let viewModel = ProviderUsageEngine(
            provider: provider,
            codexRefreshAllAction: { accounts in
                await refreshedIDs.set(accounts.map(\.id))
            }
        )
        viewModel.codexAccounts = [failed, healthy]
        viewModel.activeCodexAccountId = healthy.id
        viewModel.codexAccountSummaries = [
            failed.id: CodexAuthSummary(lastSyncFailedAt: Date(), lastSyncFailureMessage: "401 Unauthorized"),
            healthy.id: CodexAuthSummary(lastSyncSucceededAt: Date())
        ]

        await viewModel.refreshFromHeader()

        let ids = await refreshedIDs.value()
        XCTAssertEqual(ids, [healthy.id, failed.id])
    }

    func testBDD_GivenCodexXcodeProvider_WhenCreatingUsageViewModel_ThenItMapsToCodexUsageProvider() {
        let provider = Provider(
            name: "Codex (Xcode)",
            defaultSkillsPath: "/tmp/codex-xcode/skills",
            workflowPath: "/tmp/codex-xcode/prompts",
            installMethod: .symlink,
            templateId: "codexXcode"
        )

        let viewModel = ProviderUsageEngine(provider: provider)

        XCTAssertEqual(viewModel.usageProvider, .codex)
        XCTAssertTrue(viewModel.isMultiAccountEnabled)
    }

    func testBDD_GivenAccountRefreshCompletes_WhenRefreshingCodexAccount_ThenRefreshingStateClears() async throws {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let authManager = CodexAuthManager(
            rootURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("nolon-refresh-complete-\(UUID().uuidString)", isDirectory: true)
        )
        let account = try await makeStoredAccount(name: "test", manager: authManager)
        let viewModel = ProviderUsageEngine(
            provider: provider,
            codexAuthManager: authManager,
            codexOutcomeFetchAction: { account, _, _ in
                try? await Task.sleep(nanoseconds: 80_000_000)
                let outcome = ProviderFetchOutcome(fetchKind: .cli, result: .failure(UsageViewModelTestError(message: "network done")))
                return ProviderAccountUsageOutcome(
                    provider: .codex,
                    account: .tokenAccount(
                        .init(
                            id: account.id,
                            label: account.name,
                            token: "",
                            addedAt: account.createdAt.timeIntervalSince1970,
                            lastUsed: nil
                        )
                    ),
                    outcome: outcome
                )
            }
        )
        viewModel.codexAccounts = [account]

        viewModel.refreshCodexAccount(id: account.id)

        try await waitUntil { viewModel.codexRefreshingAccountIds.contains(account.id) }
        try await waitUntil { !viewModel.codexRefreshingAccountIds.contains(account.id) }
        XCTAssertFalse(viewModel.codexRefreshingAccountIds.contains(account.id))
    }

    func testBDD_GivenAccountRefreshHangs_WhenRefreshingCodexAccount_ThenRefreshingStateClearsAfterTimeout() async throws {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let authManager = CodexAuthManager(
            rootURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("nolon-refresh-timeout-\(UUID().uuidString)", isDirectory: true)
        )
        let account = try await makeStoredAccount(name: "test", manager: authManager)
        let viewModel = ProviderUsageEngine(
            provider: provider,
            codexAuthManager: authManager,
            codexOutcomeFetchAction: { account, _, _ in
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                let outcome = ProviderFetchOutcome(fetchKind: .cli, result: .failure(UsageViewModelTestError(message: "late result")))
                return ProviderAccountUsageOutcome(
                    provider: .codex,
                    account: .tokenAccount(
                        .init(
                            id: account.id,
                            label: account.name,
                            token: "",
                            addedAt: account.createdAt.timeIntervalSince1970,
                            lastUsed: nil
                        )
                    ),
                    outcome: outcome
                )
            },
            codexRefreshTimeoutGraceSeconds: 0,
            initialSettingsOverride: UsageMonitorProviderSettings(
                sourceMode: .auto,
                includeCredits: false,
                webTimeoutSeconds: 1,
                autoRefreshIntervalMinutes: 0,
                costWindowDays: 30
            )
        )
        viewModel.codexAccounts = [account]

        await viewModel.refreshCodexAccountImmediately(id: account.id)

        XCTAssertFalse(viewModel.codexRefreshingAccountIds.contains(account.id))

        let refreshed: ProviderAccountUsageOutcome = try XCTUnwrap(
            viewModel.codexAccountOutcomes.first(where: {
                if case let .tokenAccount(tokenAccount) = $0.account {
                    return tokenAccount.id == account.id
                }
                return false
            })
        )
        if case let .failure(error) = refreshed.outcome.result {
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, "ProviderUsageEngine.CodexRefresh")
            XCTAssertEqual(nsError.code, 408)
        } else {
            XCTFail("Expected timeout failure outcome")
        }
    }

    func testBDD_GivenManualSingleRefresh_WhenInitialSettingsDisableCredits_ThenRefreshStillForcesCredits() async throws {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let authManager = CodexAuthManager(
            rootURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("nolon-refresh-credits-single-\(UUID().uuidString)", isDirectory: true)
        )
        let account = try await makeStoredAccount(name: "single-refresh", manager: authManager)
        let includeCreditsValues = AsyncBoolArrayBox()
        let viewModel = ProviderUsageEngine(
            provider: provider,
            codexAuthManager: authManager,
            codexOutcomeFetchAction: { account, settings, _ in
                await includeCreditsValues.append(settings.includeCredits)
                return Self.makeScheduledRefreshOutcome(account: account, windows: [
                    ("short", "Short", 300, 20)
                ])
            },
            initialSettingsOverride: UsageMonitorProviderSettings(
                sourceMode: .auto,
                includeCredits: false,
                webTimeoutSeconds: 30,
                autoRefreshIntervalMinutes: 0,
                costWindowDays: 30
            )
        )
        viewModel.codexAccounts = [account]

        await viewModel.refreshCodexAccountImmediately(id: account.id)

        let values = await includeCreditsValues.values()
        XCTAssertEqual(values, [true])
    }

    func testBDD_GivenHeaderRefreshAll_WhenInitialSettingsDisableCredits_ThenAllRefreshesStillForceCredits() async throws {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let authManager = CodexAuthManager(
            rootURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("nolon-refresh-credits-all-\(UUID().uuidString)", isDirectory: true)
        )
        let first = try await makeStoredAccount(name: "all-refresh-1", manager: authManager)
        let second = try await makeStoredAccount(name: "all-refresh-2", manager: authManager)
        let includeCreditsValues = AsyncBoolArrayBox()
        let viewModel = ProviderUsageEngine(
            provider: provider,
            codexAuthManager: authManager,
            codexOutcomeFetchAction: { account, settings, _ in
                await includeCreditsValues.append(settings.includeCredits)
                return Self.makeScheduledRefreshOutcome(account: account, windows: [
                    ("short", "Short", 300, 20)
                ])
            },
            initialSettingsOverride: UsageMonitorProviderSettings(
                sourceMode: .auto,
                includeCredits: false,
                webTimeoutSeconds: 30,
                autoRefreshIntervalMinutes: 0,
                costWindowDays: 30
            )
        )
        viewModel.codexAccounts = [first, second]
        viewModel.activeCodexAccountId = first.id

        await viewModel.refreshFromHeader()

        let values = await includeCreditsValues.values()
        XCTAssertEqual(values.count, 2)
        XCTAssertTrue(values.allSatisfy { $0 })
    }

    func testBDD_GivenHeaderRefreshInProgress_WhenTappingRefreshAgain_ThenCanInterruptAndRefreshAgain() async throws {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let account = CodexAuthAccount(name: "test", relativeAuthPath: "auth/test.json")
        let startedCount = AsyncIntBox(0)
        let viewModel = ProviderUsageEngine(
            provider: provider,
            codexRefreshAllAction: { _ in
                await startedCount.increment()
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 20_000_000)
                }
            }
        )
        viewModel.codexAccounts = [account]

        viewModel.handleHeaderRefreshButtonTap()
        try await waitUntilAsync { await startedCount.value() >= 1 }
        try await waitUntil { viewModel.isCodexHeaderRefreshing }

        viewModel.handleHeaderRefreshButtonTap()
        try await waitUntil { !viewModel.isCodexHeaderRefreshing }

        viewModel.handleHeaderRefreshButtonTap()
        try await waitUntilAsync { await startedCount.value() >= 2 }
        try await waitUntil { viewModel.isCodexHeaderRefreshing }
        XCTAssertTrue(viewModel.isCodexHeaderRefreshing)

        viewModel.handleHeaderRefreshButtonTap()
        try await waitUntil { !viewModel.isCodexHeaderRefreshing }
    }

    @MainActor
    private func waitUntil(
        timeout: TimeInterval = 2.0,
        pollIntervalNanoseconds: UInt64 = 20_000_000,
        condition: () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            try await Task.sleep(nanoseconds: pollIntervalNanoseconds)
        }
        XCTFail("Condition was not met before timeout")
    }

    private func waitUntilAsync(
        timeout: TimeInterval = 2.0,
        pollIntervalNanoseconds: UInt64 = 20_000_000,
        condition: () async -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await condition() { return }
            try await Task.sleep(nanoseconds: pollIntervalNanoseconds)
        }
        XCTFail("Condition was not met before timeout")
    }

    nonisolated private static func makeScheduledRefreshOutcome(
        account: CodexAuthAccount,
        windows: [(id: String, title: String, minutes: Int, used: Double)]
    ) -> ProviderAccountUsageOutcome {
        let usageWindows = windows.map { item in
            UsageWindow(
                id: item.id,
                title: item.title,
                window: RateWindow(
                    usedPercent: item.used,
                    windowMinutes: item.minutes
                )
            )
        }
        let usage = UsageSnapshot(
            identity: UsageIdentity(accountEmail: "\(account.name)@example.com", accountOrganization: nil, loginMethod: "oauth", plan: "plus"),
            windows: usageWindows,
            primary: nil,
            secondary: nil,
            tertiary: nil,
            updatedAt: Date()
        )
        let result = ProviderFetchResult(
            usage: usage,
            credits: nil,
            cost: nil,
            sourceLabel: "CLI",
            fetchKind: .cli,
            strategyKind: .direct
        )
        return ProviderAccountUsageOutcome(
            provider: .codex,
            account: .tokenAccount(
                .init(
                    id: account.id,
                    label: account.name,
                    token: "",
                    addedAt: account.createdAt.timeIntervalSince1970,
                    lastUsed: nil
                )
            ),
            outcome: ProviderFetchOutcome(fetchKind: .cli, result: .success(result))
        )
    }
}

private actor AsyncBoolArrayBox {
    private var storage: [Bool] = []

    func append(_ value: Bool) {
        storage.append(value)
    }

    func values() -> [Bool] {
        storage
    }
}
