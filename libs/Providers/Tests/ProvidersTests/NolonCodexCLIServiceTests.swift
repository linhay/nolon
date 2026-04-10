import Foundation
import SQLite3
import Testing
import STFilePath
@testable import NolonCoreCLIKit
@testable import CodexCLIKit
@testable import ProviderCatalog
@testable import ProviderUsage
@testable import CodexProvider
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

@Suite("Nolon Codex CLI Service", .serialized)
struct NolonCodexCLIServiceTests {
    private func writeSessionMeta(
        codexHome: STFolder,
        threadID: String,
        modelProvider: String,
        archived: Bool = false
    ) throws {
        let rootFolder = archived ? codexHome.folder("archived_sessions") : codexHome.folder("sessions")
        let dayFolder = rootFolder.folder("2026").folder("04").folder("11")
        _ = dayFolder.createIfNotExists()

        let file = dayFolder.file("rollout-\(threadID).jsonl")
        let sessionMetaData = try JSONSerialization.data(withJSONObject: [
            "timestamp": "2026-04-11T10:00:00Z",
            "type": "session_meta",
            "payload": [
                "id": threadID,
                "timestamp": "2026-04-11T10:00:00Z",
                "cwd": "/tmp/project",
                "source": "cli",
                "model_provider": modelProvider,
            ],
        ])
        let content = String(decoding: sessionMetaData, as: UTF8.self) + "\n"
        try file.overlay(with: content)
    }

    private func sqliteExecute(databaseURL: URL, sql: String, bindings: [SQLiteBinding] = []) throws {
        var db: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            throw NSError(domain: "NolonCodexCLIServiceTests.sqlite", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        }
        defer { sqlite3_close(db) }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "NolonCodexCLIServiceTests.sqlite", code: 2, userInfo: [NSLocalizedDescriptionKey: message])
        }
        defer { sqlite3_finalize(statement) }

        for (index, binding) in bindings.enumerated() {
            let parameterIndex = Int32(index + 1)
            switch binding {
            case let .text(value):
                sqlite3_bind_text(statement, parameterIndex, value, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            case let .int64(value):
                sqlite3_bind_int64(statement, parameterIndex, value)
            case .null:
                sqlite3_bind_null(statement, parameterIndex)
            }
        }

        let result = sqlite3_step(statement)
        guard result == SQLITE_DONE || result == SQLITE_ROW else {
            let message = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "NolonCodexCLIServiceTests.sqlite", code: 3, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    private func createStateDatabase(
        codexHome: STFolder,
        threads: [(id: String, title: String, modelProvider: String, updatedAt: Int64, archived: Bool)]
    ) throws {
        let databaseURL = codexHome.file("state_4.sqlite").url
        try sqliteExecute(
            databaseURL: databaseURL,
            sql: """
            CREATE TABLE threads (
                id TEXT PRIMARY KEY,
                title TEXT,
                model_provider TEXT NOT NULL,
                updated_at INTEGER,
                archived INTEGER NOT NULL DEFAULT 0
            );
            """
        )

        for thread in threads {
            try sqliteExecute(
                databaseURL: databaseURL,
                sql: """
                INSERT INTO threads (id, title, model_provider, updated_at, archived)
                VALUES (?, ?, ?, ?, ?);
                """,
                bindings: [
                    .text(thread.id),
                    .text(thread.title),
                    .text(thread.modelProvider),
                    .int64(thread.updatedAt),
                    .int64(thread.archived ? 1 : 0),
                ]
            )
        }
    }

    private func withTemporaryHome<T>(_ root: STFolder, operation: () async throws -> T) async rethrows -> T {
        let previousHome = getenv("HOME").map { String(cString: $0) }
        setenv("HOME", root.url.path, 1)
        defer {
            if let previousHome {
                setenv("HOME", previousHome, 1)
            } else {
                unsetenv("HOME")
            }
        }
        return try await operation()
    }

    @Test("auth list canonicalizes codexxcode provider id")
    func authListCanonicalProviderID() async throws {
        let root = try makeTempRoot("nolon-codex-cli")
        defer { try? root.delete() }

        let service = NolonLiveCodexCLIService(
            authManager: CodexAuthManager(rootURL: root.url),
            binaryManager: CodexBinaryManager(homeURL: root.url),
            loginRunner: .init(),
            environment: [:]
        )

        let payload = try await service.authList(providerID: "codexxcode")
        #expect(payload.providerID == "codex-xcode")
    }

    @Test("status probe rejects unsupported provider in service")
    func statusProbeRejectsUnsupportedProvider() async throws {
        let root = try makeTempRoot("nolon-codex-cli")
        defer { try? root.delete() }

        let service = NolonLiveCodexCLIService(
            authManager: CodexAuthManager(rootURL: root.url),
            binaryManager: CodexBinaryManager(homeURL: root.url),
            loginRunner: .init(),
            environment: [:]
        )

        do {
            _ = try await service.statusProbe(providerID: "claude")
            Issue.record("Expected invalidArguments error")
        } catch let error as NolonCoreCLIError {
            guard case .invalidArguments = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("auth delete returns domain error when account is missing")
    func authDeleteMissingAccount() async throws {
        let root = try makeTempRoot("nolon-codex-cli")
        defer { try? root.delete() }

        let service = NolonLiveCodexCLIService(
            authManager: CodexAuthManager(rootURL: root.url),
            binaryManager: CodexBinaryManager(homeURL: root.url),
            loginRunner: .init(),
            environment: [:]
        )

        do {
            _ = try await service.authDelete(
                providerID: "codex",
                accountID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
            )
            Issue.record("Expected codex_auth_account_not_found error")
        } catch let error as NolonCoreCLIError {
            guard case let .domainFailed(code, _) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(code == "codex_auth_account_not_found")
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("auth list includes email usage display and refreshed time from local cache")
    func authListIncludesEmailUsageAndRefresh() async throws {
        let root = try makeTempRoot("nolon-codex-cli")
        defer { try? root.delete() }

        let authManager = CodexAuthManager(rootURL: root.url)
        let account = try await authManager.addAccount(
            name: "demo",
            authJSONString: #"{"email":"dev@example.com"}"#
        )

        let cache = CodexAuthUsageCache(
            cachedAt: Date(timeIntervalSince1970: 1_733_000_000),
            creditsRefreshedAt: Date(timeIntervalSince1970: 1_734_000_000),
            fetchKind: .cli,
            strategyKind: .direct,
            sourceLabel: "CLI",
            usage: UsageSnapshot(
                identity: nil,
                primary: RateWindow(usedPercent: 17),
                secondary: RateWindow(usedPercent: 50),
                tertiary: nil,
                updatedAt: Date(timeIntervalSince1970: 1_733_500_000)
            ),
            credits: nil,
            cost: nil
        )
        try await authManager.storeUsageCache(cache, for: account)

        let service = NolonLiveCodexCLIService(
            authManager: authManager,
            binaryManager: CodexBinaryManager(homeURL: root.url),
            loginRunner: .init(),
            environment: [:]
        )

        let payload = try await service.authList(providerID: "codex")
        #expect(payload.accounts.count == 1)
        #expect(payload.accounts[0].email == "dev@example.com")
        #expect(payload.accounts[0].usageDisplay == "5h 83% / 7d 50%")
        #expect(payload.accounts[0].refreshedAt == Date(timeIntervalSince1970: 1_734_000_000))
    }

    @Test("auth list usage display keeps slash-aligned template when only weekly window exists")
    func authListUsageDisplayWeeklyOnly() async throws {
        let root = try makeTempRoot("nolon-codex-cli")
        defer { try? root.delete() }

        let authManager = CodexAuthManager(rootURL: root.url)
        let account = try await authManager.addAccount(
            name: "demo",
            authJSONString: #"{"email":"weekly@example.com"}"#
        )

        let cache = CodexAuthUsageCache(
            cachedAt: Date(timeIntervalSince1970: 1_733_000_000),
            creditsRefreshedAt: nil,
            fetchKind: .cli,
            strategyKind: .direct,
            sourceLabel: "CLI",
            usage: UsageSnapshot(
                identity: nil,
                primary: nil,
                secondary: RateWindow(usedPercent: 13.4),
                tertiary: nil,
                updatedAt: Date(timeIntervalSince1970: 1_733_500_000)
            ),
            credits: nil,
            cost: nil
        )
        try await authManager.storeUsageCache(cache, for: account)

        let service = NolonLiveCodexCLIService(
            authManager: authManager,
            binaryManager: CodexBinaryManager(homeURL: root.url),
            loginRunner: .init(),
            environment: [:]
        )

        let payload = try await service.authList(providerID: "codex")
        #expect(payload.accounts.count == 1)
        #expect(payload.accounts[0].usageDisplay == "5h - / 7d 87%")
        #expect(payload.accounts[0].refreshedAt == Date(timeIntervalSince1970: 1_733_500_000))
    }

    @Test("auth usage returns per-account rows and summary aggregation")
    func authUsageReturnsRowsAndSummary() async throws {
        let root = try makeTempRoot("nolon-codex-cli")
        defer { try? root.delete() }

        let authManager = CodexAuthManager(rootURL: root.url)
        let accountA = try await authManager.addAccount(
            name: "a",
            authJSONString: #"{"email":"a@example.com","expires_at":"2026-12-31T08:00:00Z","tokens":{"refresh_token":"rt_demo"}}"#
        )
        let accountB = try await authManager.addAccount(
            name: "b",
            authJSONString: #"{"email":"b@example.com"}"#
        )

        let cacheA = CodexAuthUsageCache(
            cachedAt: Date(timeIntervalSince1970: 1_733_100_000),
            creditsRefreshedAt: Date(timeIntervalSince1970: 1_733_300_000),
            fetchKind: .cli,
            strategyKind: .direct,
            sourceLabel: "CLI",
            usage: UsageSnapshot(
                identity: nil,
                primary: RateWindow(usedPercent: 20),
                secondary: RateWindow(usedPercent: 45),
                tertiary: nil,
                updatedAt: Date(timeIntervalSince1970: 1_733_200_000)
            ),
            credits: nil,
            cost: nil
        )
        try await authManager.storeUsageCache(cacheA, for: accountA)

        let cacheB = CodexAuthUsageCache(
            cachedAt: Date(timeIntervalSince1970: 1_733_110_000),
            creditsRefreshedAt: Date(timeIntervalSince1970: 1_733_350_000),
            fetchKind: .cli,
            strategyKind: .direct,
            sourceLabel: "CLI",
            usage: UsageSnapshot(
                identity: nil,
                primary: RateWindow(usedPercent: 50),
                secondary: nil,
                tertiary: nil,
                updatedAt: Date(timeIntervalSince1970: 1_733_220_000)
            ),
            credits: nil,
            cost: nil
        )
        try await authManager.storeUsageCache(cacheB, for: accountB)

        let service = NolonLiveCodexCLIService(
            authManager: authManager,
            binaryManager: CodexBinaryManager(homeURL: root.url),
            loginRunner: .init(),
            environment: [:]
        )

        let payload = try await service.authUsage(providerID: "codex")
        #expect(payload.accounts.count == 2)
        #expect(payload.accounts.map(\.email).contains("a@example.com"))
        #expect(payload.accounts.map(\.email).contains("b@example.com"))
        #expect(payload.summary.accountCount == 2)
        #expect(payload.summary.cachedCount == 2)
        #expect(payload.summary.avgFiveHourRemainingPercent == 65)
        #expect(payload.summary.avgWeeklyRemainingPercent == 55)
        #expect(payload.summary.totalToken1dCount == nil)
        #expect(payload.summary.totalToken30dCount == nil)
        #expect(payload.summary.totalTokenAllCount == nil)
        #expect(payload.accounts.allSatisfy { $0.token1dCount == nil })
        #expect(payload.accounts.allSatisfy { $0.token30dCount == nil })
        #expect(payload.accounts.allSatisfy { $0.tokenAllCount == nil })
        #expect(payload.summary.latestRefreshedAt == Date(timeIntervalSince1970: 1_733_350_000))
        #expect(payload.accounts.first(where: { $0.email == "a@example.com" })?.expiresAt == Date(timeIntervalSince1970: 1_798_704_000))
        #expect(payload.accounts.first(where: { $0.email == "a@example.com" })?.hasRefreshToken == true)
    }

    @Test("auth usage refresh writes back usage cache per account")
    func authUsageRefreshWritesBackPerAccount() async throws {
        let root = try makeTempRoot("nolon-codex-cli-usage-refresh")
        defer { try? root.delete() }

        let authManager = CodexAuthManager(rootURL: root.url)
        let accountA = try await authManager.addAccount(
            name: "a",
            authJSONString: #"{"email":"a@example.com"}"#
        )
        _ = try await authManager.addAccount(
            name: "b",
            authJSONString: #"{"email":"b@example.com"}"#
        )

        let service = NolonLiveCodexCLIService(
            authManager: authManager,
            binaryManager: CodexBinaryManager(homeURL: root.url),
            loginRunner: .init(),
            environment: [:],
            usageOutcomeFetcher: { _ in
                let result = ProviderFetchResult(
                    usage: UsageSnapshot(
                        identity: UsageIdentity(
                            accountEmail: "a@example.com",
                            accountOrganization: nil,
                            loginMethod: "oauth",
                            plan: "plus"
                        ),
                        primary: RateWindow(usedPercent: 22),
                        secondary: RateWindow(usedPercent: 33),
                        tertiary: nil,
                        updatedAt: Date(timeIntervalSince1970: 1_734_200_000)
                    ),
                    credits: nil,
                    cost: nil,
                    sourceLabel: "CLI",
                    fetchKind: .cli,
                    strategyKind: .direct
                )
                return ProviderFetchOutcome(fetchKind: .cli, result: .success(result))
            },
            runtimeProcessInspector: StubRuntimeProcessInspector(snapshots: []),
            runtimeSignalController: StubRuntimeSignalController(),
            currentPIDProvider: { 999_999 },
            sleep: { _ in }
        )

        _ = try await service.authUsageRefresh(providerID: "codex", accountID: accountA.id)

        let refreshedAccountA = try #require((try await authManager.loadAccounts()).first(where: { $0.id == accountA.id }))
        let cacheA = try await authManager.loadUsageCache(for: refreshedAccountA)
        #expect(cacheA?.cost == nil)

        let runtimeSkills = STPath(authManager.runtimeHomeFolder(accountID: accountA.id).folder("skills").url)
        let template = authManager.runtimeSkillsTemplateFolder()
        #expect(runtimeSkills.isSymbolicLink == true)
        let linkedTo = try runtimeSkills.destinationOfSymbolicLink()
        #expect(STPath.standardizedPath(linkedTo.url.path).path == STPath.standardizedPath(template.url.path).path)
    }

    @Test("auth usage refresh invalidates stale cache and exposes sync failure metadata")
    func authUsageRefreshInvalidatesStaleCacheOnFailure() async throws {
        let root = try makeTempRoot("nolon-codex-cli-usage-refresh-failure")
        defer { try? root.delete() }

        let authManager = CodexAuthManager(rootURL: root.url)
        let accountA = try await authManager.addAccount(
            name: "a",
            authJSONString: #"{"email":"a@example.com"}"#
        )
        let accountB = try await authManager.addAccount(
            name: "b",
            authJSONString: #"{"email":"b@example.com"}"#
        )

        let staleCacheA = CodexAuthUsageCache(
            cachedAt: Date(timeIntervalSince1970: 1_733_000_000),
            creditsRefreshedAt: Date(timeIntervalSince1970: 1_733_000_100),
            fetchKind: .cli,
            strategyKind: .direct,
            sourceLabel: "CLI",
            usage: UsageSnapshot(
                identity: nil,
                primary: RateWindow(usedPercent: 12),
                secondary: RateWindow(usedPercent: 24),
                tertiary: nil,
                updatedAt: Date(timeIntervalSince1970: 1_733_000_200)
            ),
            credits: nil,
            cost: nil
        )
        try await authManager.storeUsageCache(staleCacheA, for: accountA)

        let validCacheB = CodexAuthUsageCache(
            cachedAt: Date(timeIntervalSince1970: 1_733_100_000),
            creditsRefreshedAt: Date(timeIntervalSince1970: 1_733_100_200),
            fetchKind: .cli,
            strategyKind: .direct,
            sourceLabel: "CLI",
            usage: UsageSnapshot(
                identity: nil,
                primary: RateWindow(usedPercent: 40),
                secondary: RateWindow(usedPercent: 50),
                tertiary: nil,
                updatedAt: Date(timeIntervalSince1970: 1_733_100_400)
            ),
            credits: nil,
            cost: nil
        )
        try await authManager.storeUsageCache(validCacheB, for: accountB)

        let service = NolonLiveCodexCLIService(
            authManager: authManager,
            binaryManager: CodexBinaryManager(homeURL: root.url),
            loginRunner: .init(),
            environment: [:],
            usageOutcomeFetcher: { _ in
                ProviderFetchOutcome(
                    fetchKind: .cli,
                    result: .failure(CodexCLIError.protocolError("401 Unauthorized"))
                )
            },
            runtimeProcessInspector: StubRuntimeProcessInspector(snapshots: []),
            runtimeSignalController: StubRuntimeSignalController(),
            currentPIDProvider: { 999_999 },
            sleep: { _ in }
        )

        let payload = try await service.authUsageRefresh(providerID: "codex", accountID: accountA.id)

        let accountARow = payload.accounts.first { $0.id == accountA.id }
        let accountBRow = payload.accounts.first { $0.id == accountB.id }
        #expect(accountARow?.fiveHourRemainingPercent == nil)
        #expect(accountARow?.weeklyRemainingPercent == nil)
        #expect(accountARow?.syncFailedAt != nil)
        #expect(accountARow?.syncFailureMessage?.contains("401 Unauthorized") == true)
        #expect(accountBRow?.fiveHourRemainingPercent == 60)
        #expect(accountBRow?.weeklyRemainingPercent == 50)
        #expect(payload.summary.cachedCount == 1)
        #expect(payload.summary.avgFiveHourRemainingPercent == 60)
        #expect(payload.summary.avgWeeklyRemainingPercent == 50)
    }

    @Test("auth usage refresh retries chatgpt accounts even when they have prior sync failure metadata")
    func authUsageRefreshRetriesChatGPTAccountsAfterPreviousFailure() async throws {
        let root = try makeTempRoot("nolon-codex-cli-refresh-chatgpt-retry")
        defer { try? root.delete() }

        let authManager = CodexAuthManager(rootURL: root.url)
        let account = try await authManager.addAccount(
            name: "chatgpt",
            authJSONString: #"""
            {
              "auth_mode": "chatgpt",
              "email": "chatgpt@example.com",
              "tokens": {
                "access_token": "access-token",
                "account_id": "acct-chatgpt"
              },
              "nolon": {
                "account": {
                  "lastSyncFailedAt": "2026-03-09T03:48:26.705Z",
                  "lastSyncFailureMessage": "Codex 刷新在 35 秒后超时。"
                }
              }
            }
            """#
        )

        let service = NolonLiveCodexCLIService(
            authManager: authManager,
            binaryManager: CodexBinaryManager(homeURL: root.url),
            loginRunner: .init(),
            environment: [:],
            usageOutcomeFetcher: { _ in
                let result = ProviderFetchResult(
                    usage: UsageSnapshot(
                        identity: UsageIdentity(
                            accountEmail: "chatgpt@example.com",
                            accountOrganization: nil,
                            loginMethod: "oauth",
                            plan: "free"
                        ),
                        primary: RateWindow(usedPercent: 100),
                        secondary: nil,
                        tertiary: nil,
                        updatedAt: Date(timeIntervalSince1970: 1_741_492_800)
                    ),
                    credits: nil,
                    cost: nil,
                    sourceLabel: "HTTP",
                    fetchKind: .web,
                    strategyKind: .direct
                )
                return ProviderFetchOutcome(fetchKind: .web, result: .success(result))
            },
            runtimeProcessInspector: StubRuntimeProcessInspector(snapshots: []),
            runtimeSignalController: StubRuntimeSignalController(),
            currentPIDProvider: { 999_999 },
            sleep: { _ in }
        )

        let payload = try await service.authUsageRefresh(providerID: "codex", accountID: account.id)

        let row = try #require(payload.accounts.first(where: { $0.id == account.id }))
        #expect(row.isSkipped == false)
        #expect(row.status == .healthy)
        #expect(row.usageSource == "HTTP")

        let refreshedAccount = try #require((try await authManager.loadAccounts()).first(where: { $0.id == account.id }))
        let cache = try #require(try await authManager.loadUsageCache(for: refreshedAccount))
        #expect(cache.fetchKind == .web)
        #expect(cache.sourceLabel == "HTTP")
    }

    @Test("auth usage refresh still skips configured accounts after previous sync failure")
    func authUsageRefreshStillSkipsConfiguredAccountsAfterPreviousFailure() async throws {
        let root = try makeTempRoot("nolon-codex-cli-refresh-configured-skip")
        defer { try? root.delete() }

        let authManager = CodexAuthManager(rootURL: root.url)
        let account = try await authManager.addConfiguredAccount(
            name: "OpenAI Direct",
            apiKey: "sk-live-12345678",
            relay: nil
        )
        try await authManager.updateSyncFailure(
            for: account,
            message: "401 Unauthorized",
            date: Date(timeIntervalSince1970: 1_741_492_706)
        )

        let service = NolonLiveCodexCLIService(
            authManager: authManager,
            binaryManager: CodexBinaryManager(homeURL: root.url),
            loginRunner: .init(),
            environment: [:],
            usageOutcomeFetcher: { _ in
                Issue.record("Configured account should remain skipped after previous failure")
                return ProviderFetchOutcome(fetchKind: .web, result: .failure(CodexHTTPUsageQueryError.httpStatus(401, message: "unauthorized")))
            },
            runtimeProcessInspector: StubRuntimeProcessInspector(snapshots: []),
            runtimeSignalController: StubRuntimeSignalController(),
            currentPIDProvider: { 999_999 },
            sleep: { _ in }
        )

        let payload = try await service.authUsageRefresh(providerID: "codex", accountID: account.id)

        let row = try #require(payload.accounts.first(where: { $0.id == account.id }))
        #expect(row.isSkipped == true)
        #expect(row.status == .skipped)
        #expect(payload.skippedAccounts.contains(where: { $0.accountID == account.id && $0.reason == "failed_before" }))
    }

    @Test("auth status includes usage summary fields")
    func authStatusIncludesUsageSummary() async throws {
        let root = try makeTempRoot("nolon-codex-cli")
        defer { try? root.delete() }

        let authManager = CodexAuthManager(rootURL: root.url)
        let account = try await authManager.addAccount(
            name: "demo",
            authJSONString: #"{"email":"status@example.com"}"#
        )

        let cache = CodexAuthUsageCache(
            cachedAt: Date(timeIntervalSince1970: 1_733_100_000),
            creditsRefreshedAt: Date(timeIntervalSince1970: 1_733_360_000),
            fetchKind: .cli,
            strategyKind: .direct,
            sourceLabel: "CLI",
            usage: UsageSnapshot(
                identity: nil,
                primary: RateWindow(usedPercent: 20),
                secondary: RateWindow(usedPercent: 10),
                tertiary: nil,
                updatedAt: Date(timeIntervalSince1970: 1_733_200_000)
            ),
            credits: nil,
            cost: nil
        )
        try await authManager.storeUsageCache(cache, for: account)

        let service = NolonLiveCodexCLIService(
            authManager: authManager,
            binaryManager: CodexBinaryManager(homeURL: root.url),
            loginRunner: .init(),
            environment: [:]
        )

        let payload = try await service.authStatus(providerID: "codex")
        #expect(payload.accountCount == 1)
        #expect(payload.usageCachedAccountCount == 1)
        #expect(payload.usageAvgFiveHourRemainingPercent == 80)
        #expect(payload.usageAvgWeeklyRemainingPercent == 90)
        #expect(payload.usageLatestRefreshedAt == Date(timeIntervalSince1970: 1_733_360_000))
    }

    @Test("auth refresh performs silent token refresh and does not return login URL")
    func authRefreshSilentTokenRefresh() async throws {
        let root = try makeTempRoot("nolon-codex-cli-refresh")
        defer { try? root.delete() }

        let authManager = CodexAuthManager(rootURL: root.url)
        let account = try await authManager.addAccount(
            name: "demo",
            authJSONString: #"{"email":"refresh@example.com","tokens":{"refresh_token":"rt_demo"}}"#
        )

        let refreshCounter = Counter()
        let service = NolonLiveCodexCLIService(
            authManager: authManager,
            binaryManager: CodexBinaryManager(homeURL: root.url),
            loginRunner: .init(),
            environment: [:],
            authActivator: { account, provider in
                try await authManager.setActiveAccount(account, for: provider)
                return CodexAuthActivationResult(runtimeSwitched: true, runtimeErrorDescription: nil)
            },
            authRefreshRunner: { _, _, _ in
                await refreshCounter.increment()
            }
        )

        let payload = try await service.authRefresh(providerID: "codex", accountID: account.id)
        #expect(payload.items.count == 1)
        #expect(payload.items.first?.accountID == account.id)
        #expect(payload.items.first?.isActive == true)
        #expect(payload.items.first?.success == true)
        #expect(payload.summary.totalCount == 1)
        #expect(payload.summary.successCount == 1)
        #expect(payload.summary.failureCount == 0)
        #expect(await refreshCounter.value() == 1)
    }

    @Test("auth refresh maps refresh-token expired failure to stable domain code")
    func authRefreshMapsExpiredFailure() async throws {
        let root = try makeTempRoot("nolon-codex-cli-refresh-failed")
        defer { try? root.delete() }

        let authManager = CodexAuthManager(rootURL: root.url)
        let account = try await authManager.addAccount(
            name: "demo",
            authJSONString: #"{"email":"expired@example.com","tokens":{"refresh_token":"rt_demo"}}"#
        )

        let service = NolonLiveCodexCLIService(
            authManager: authManager,
            binaryManager: CodexBinaryManager(homeURL: root.url),
            loginRunner: .init(),
            environment: [:],
            authActivator: { _, _ in
                CodexAuthActivationResult(runtimeSwitched: true, runtimeErrorDescription: nil)
            },
            authRefreshRunner: { _, _, _ in
                throw CodexCLIError.recoverableFallback("refresh_token_expired")
            }
        )

        let payload = try await service.authRefresh(providerID: "codex", accountID: account.id)
        #expect(payload.items.count == 1)
        #expect(payload.items.first?.success == false)
        #expect(payload.items.first?.errorCode == "codex_auth_refresh_token_expired")
        #expect(payload.summary.failureCount == 1)
    }

    @Test("auth refresh without account id refreshes all accounts serially")
    func authRefreshWithoutTargetRefreshesAll() async throws {
        let root = try makeTempRoot("nolon-codex-cli-refresh-all")
        defer { try? root.delete() }

        let authManager = CodexAuthManager(rootURL: root.url)
        let accountA = try await authManager.addAccount(
            name: "a",
            authJSONString: #"{"email":"a@example.com","tokens":{"refresh_token":"rt_a"}}"#
        )
        _ = try await authManager.addAccount(
            name: "b",
            authJSONString: #"{"email":"b@example.com","tokens":{"refresh_token":"rt_b"}}"#
        )
        let codexProvider = ProviderTemplate.codex.createProvider()
        try await authManager.setActiveAccount(accountA, for: codexProvider)
        let refreshCounter = Counter()

        let service = NolonLiveCodexCLIService(
            authManager: authManager,
            binaryManager: CodexBinaryManager(homeURL: root.url),
            loginRunner: .init(),
            environment: [:],
            authActivator: { account, provider in
                try await authManager.setActiveAccount(account, for: provider)
                return CodexAuthActivationResult(runtimeSwitched: true, runtimeErrorDescription: nil)
            },
            authRefreshRunner: { _, _, _ in
                await refreshCounter.increment()
            }
        )

        let payload = try await service.authRefresh(providerID: "codex", accountID: nil)
        #expect(payload.summary.totalCount == 2)
        #expect(payload.summary.successCount == 2)
        #expect(payload.summary.failureCount == 0)
        #expect(await refreshCounter.value() == 2)
        #expect(await authManager.activeAccountId(for: codexProvider) == accountA.id)
        #expect(payload.items.filter(\.isActive).count == 1)
        #expect(payload.items.first(where: { $0.isActive })?.accountID == accountA.id)
    }

    @Test("session list groups sessions by provider and exposes available targets")
    func sessionListGroupsSessionsByProvider() async throws {
        let root = try makeTempRoot("nolon-codex-cli-session-list")
        defer { try? root.delete() }

        try await withTemporaryHome(root) {
            let codexHome = root.folder(".codex")
            _ = codexHome.createIfNotExists()

            try writeSessionMeta(codexHome: codexHome, threadID: "thread-live", modelProvider: "openai")
            try writeSessionMeta(codexHome: codexHome, threadID: "thread-archived", modelProvider: "azure", archived: true)
            try createStateDatabase(
                codexHome: codexHome,
                threads: [
                    (id: "thread-live", title: "Live Session", modelProvider: "openai", updatedAt: 1000, archived: false),
                    (id: "thread-archived", title: "Archived Session", modelProvider: "azure", updatedAt: 900, archived: true),
                ]
            )

            let service = NolonLiveCodexCLIService(
                authManager: CodexAuthManager(rootURL: root.url),
                binaryManager: CodexBinaryManager(homeURL: root.url),
                loginRunner: .init(),
                environment: [:]
            )

            let payload = try await service.sessionList(providerID: "codex")
            #expect(payload.providerID == "codex")
            #expect(payload.totalSessionCount == 2)
            #expect(payload.totalLiveCount == 1)
            #expect(payload.totalArchivedCount == 1)
            #expect(payload.availableTargetProviderIDs.contains("openai"))
            #expect(payload.availableTargetProviderIDs.contains("azure"))
            #expect(payload.sections.map(\.modelProvider) == ["azure", "openai"])
        }
    }

    @Test("session preview rewrite returns no-op error when source provider has no editable sessions")
    func sessionPreviewRewriteRejectsNoopSelection() async throws {
        let root = try makeTempRoot("nolon-codex-cli-session-preview")
        defer { try? root.delete() }

        try await withTemporaryHome(root) {
            let codexHome = root.folder(".codex")
            _ = codexHome.createIfNotExists()

            try writeSessionMeta(codexHome: codexHome, threadID: "thread-live", modelProvider: "openai")
            try createStateDatabase(
                codexHome: codexHome,
                threads: [
                    (id: "thread-live", title: "Live Session", modelProvider: "openai", updatedAt: 1000, archived: false),
                ]
            )

            let service = NolonLiveCodexCLIService(
                authManager: CodexAuthManager(rootURL: root.url),
                binaryManager: CodexBinaryManager(homeURL: root.url),
                loginRunner: .init(),
                environment: [:]
            )

            do {
                _ = try await service.sessionPreviewRewrite(
                    providerID: "codex",
                    requestSource: .modelProvider("azure"),
                    targetProviderID: "provider-relay"
                )
                Issue.record("Expected codex_session_not_found error")
            } catch let error as NolonCoreCLIError {
                guard case let .domainFailed(code, message) = error else {
                    Issue.record("Unexpected error: \(error)")
                    return
                }
                #expect(code == "codex_session_not_found")
                #expect(message.contains("No matching sessions"))
            }
        }
    }

    @Test("session rewrite surfaces partial failures from store result")
    func sessionRewriteSurfacesPartialFailures() async throws {
        let root = try makeTempRoot("nolon-codex-cli-session-rewrite")
        defer { try? root.delete() }

        try await withTemporaryHome(root) {
            let codexHome = root.folder(".codex")
            _ = codexHome.createIfNotExists()

            try writeSessionMeta(codexHome: codexHome, threadID: "thread-live", modelProvider: "openai")
            try createStateDatabase(
                codexHome: codexHome,
                threads: [
                    (id: "thread-live", title: "Live Session", modelProvider: "openai", updatedAt: 1000, archived: false),
                ]
            )

            let databaseURL = codexHome.file("state_4.sqlite").url
            try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: databaseURL.path)
            defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: databaseURL.path) }

            let service = NolonLiveCodexCLIService(
                authManager: CodexAuthManager(rootURL: root.url),
                binaryManager: CodexBinaryManager(homeURL: root.url),
                loginRunner: .init(),
                environment: [:]
            )

            let payload = try await service.sessionRewrite(
                providerID: "codex",
                requestSource: .threadIDs(["thread-live"]),
                targetProviderID: "provider-relay"
            )
            #expect(payload.result.preview.sessionCount == 1)
            #expect(payload.result.liveRolloutFilesUpdated == 1)
            #expect(payload.result.stateRowsUpdated == 0)
            #expect(payload.result.failures.isEmpty == false)
        }
    }

    @Test("runtime list filters codex processes and sorts by pid asc")
    func runtimeListFiltersAndSorts() async throws {
        let root = try makeTempRoot("nolon-codex-cli")
        defer { try? root.delete() }

        let service = NolonLiveCodexCLIService(
            authManager: CodexAuthManager(rootURL: root.url),
            binaryManager: CodexBinaryManager(homeURL: root.url),
            loginRunner: .init(),
            environment: [:],
            runtimeProcessInspector: StubRuntimeProcessInspector(
                snapshots: [
                    NolonRuntimeProcessSnapshot(pid: 400, ppid: 1, elapsed: "00:00:05", command: "/bin/zsh"),
                    NolonRuntimeProcessSnapshot(
                        pid: 220,
                        ppid: 1,
                        elapsed: "00:01:10",
                        command: "/opt/homebrew/bin/codex",
                        workingDirectory: "/tmp/project-a"
                    ),
                    NolonRuntimeProcessSnapshot(pid: 180, ppid: 1, elapsed: "00:03:00", command: "/usr/local/bin/codex-app-server --provider codex-xcode"),
                    NolonRuntimeProcessSnapshot(pid: 181, ppid: 1, elapsed: "00:00:01", command: "/bin/zsh -lc nolon codex runtime list"),
                ]
            ),
            runtimeSignalController: StubRuntimeSignalController(),
            currentPIDProvider: { 999_999 },
            sleep: { _ in }
        )

        let payload = try await service.runtimeList(providerID: nil)
        #expect(payload.processes.map(\.pid) == [180, 220])
        #expect(payload.processes[0].providerHint == "codex-xcode")
        #expect(payload.processes[1].providerHint == "codex")
        #expect(payload.processes[1].workingDirectory == "/tmp/project-a")
    }

    @Test("runtime stop escalates to kill when process does not exit after term")
    func runtimeStopEscalatesToKill() async throws {
        let root = try makeTempRoot("nolon-codex-cli")
        defer { try? root.delete() }

        let signalController = StubRuntimeSignalController(
            aliveSequenceByPID: [
                12345: Array(repeating: true, count: 20),
            ]
        )
        let service = NolonLiveCodexCLIService(
            authManager: CodexAuthManager(rootURL: root.url),
            binaryManager: CodexBinaryManager(homeURL: root.url),
            loginRunner: .init(),
            environment: [:],
            runtimeProcessInspector: StubRuntimeProcessInspector(snapshots: []),
            runtimeSignalController: signalController,
            currentPIDProvider: { 999_999 },
            sleep: { _ in }
        )

        let payload = try await service.runtimeStop(pid: 12345, force: false, timeoutSeconds: 1)
        #expect(payload.requestedSignal == "term")
        #expect(payload.didEscalateToKill == true)
        #expect(payload.exited == true)
        #expect(signalController.signals.map(\.pid) == [12345, 12345])
        #expect(signalController.signals.map(\.signal) == [SIGTERM, SIGKILL])
    }

    @Test("provider discover returns codex providers and auth symlink state")
    func providerDiscoverReturnsCodexProviders() async throws {
        let root = try makeTempRoot("nolon-codex-provider-discover")
        defer { try? root.delete() }

        let service = NolonLiveCodexCLIService(
            authManager: CodexAuthManager(rootURL: root.url),
            binaryManager: CodexBinaryManager(homeURL: root.url),
            loginRunner: .init(),
            environment: [:]
        )

        let payload = try await service.providerDiscover()
        #expect(payload.providers.map(\.providerID) == ["codex", "codex-xcode"])
        #expect(payload.providers.count == 2)
        #expect(payload.providers.first?.providerID == "codex")
        #expect(payload.providers.last?.providerID == "codex-xcode")
        #expect(payload.providers.first?.authPath.isEmpty == false)
    }

    @Test("provider list returns installed providers only")
    func providerListReturnsInstalledOnly() async throws {
        let root = try makeTempRoot("nolon-provider-list")
        defer { try? root.delete() }

        let service = NolonLiveCodexCLIService(
            authManager: CodexAuthManager(rootURL: root.url),
            binaryManager: CodexBinaryManager(homeURL: root.url),
            loginRunner: .init(),
            environment: [:]
        )

        let payload = try await service.providerList()
        #expect(payload.providers.allSatisfy { $0.installed })
        #expect(payload.providers.allSatisfy { !($0.executablePath?.isEmpty ?? true) })
        let expectedCLIByProviderID = Dictionary(
            uniqueKeysWithValues: ProviderTemplate.allCases.map { ($0.providerID, $0.cliName) }
        )
        #expect(payload.providers.allSatisfy { expectedCLIByProviderID[$0.providerID] == $0.cli })
    }

    @Test("prepare isolated login home enforces file store config and clears stale auth")
    func prepareIsolatedLoginHomeEnforcesFileStoreAndClearsStaleAuth() throws {
        let root = try makeTempRoot("nolon-codex-cli-login-home")
        defer { try? root.delete() }

        let codexHome = root
            .folder("codex")
            .folder("cli-login-home")
            .folder("codex")
        _ = codexHome.createIfNotExists()

        let authFile = codexHome.file("auth.json")
        try authFile.overlay(with: #"{"tokens":{"id_token":"old","access_token":"old"}}"#)
        #expect(authFile.isExists)

        let configFile = codexHome.file("config.toml")
        try configFile.overlay(with: #"cli_auth_credentials_store = "keyring""# + "\n")

        try NolonLiveCodexCLIService.prepareIsolatedLoginHome(codexHome: codexHome)

        #expect(!authFile.isExists)
        #expect((try? configFile.read()) == #"cli_auth_credentials_store = "file""# + "\n")
    }
}

private enum SQLiteBinding {
    case text(String)
    case int64(Int64)
    case null
}

private func makeCodexProvider() -> Provider {
    Provider(
        id: "codex",
        name: "Codex",
        defaultSkillsPath: "/tmp/codex/skills",
        workflowPath: "/tmp/codex/prompts",
        installMethod: .symlink,
        templateId: "codex"
    )
}

private actor Counter {
    private var rawValue: Int = 0

    func increment() {
        rawValue += 1
    }

    func value() -> Int {
        rawValue
    }
}

private final class LockedValue<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Value

    init(_ value: Value) {
        storage = value
    }

    func set(_ value: Value) {
        lock.lock()
        defer { lock.unlock() }
        storage = value
    }

    var value: Value {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

private func makeTempRoot(_ prefix: String) throws -> STFolder {
    let root = STFolder("/tmp").folder("\(prefix)-\(UUID().uuidString)")
    _ = root.createIfNotExists()
    return root
}

private struct StubRuntimeProcessInspector: NolonCodexRuntimeProcessInspecting {
    let snapshots: [NolonRuntimeProcessSnapshot]

    func listProcesses() throws -> [NolonRuntimeProcessSnapshot] {
        snapshots
    }
}

private struct SentSignal: Equatable {
    let pid: Int32
    let signal: Int32
}

private final class StubRuntimeSignalController: NolonCodexRuntimeSignalControlling, @unchecked Sendable {
    private let lock = NSLock()
    private var signalStorage: [SentSignal] = []
    private var aliveSequences: [Int32: [Bool]]
    private var killedPIDs: Set<Int32> = []

    init(aliveSequenceByPID: [Int32: [Bool]] = [:]) {
        self.aliveSequences = aliveSequenceByPID
    }

    var signals: [SentSignal] {
        lock.lock()
        defer { lock.unlock() }
        return signalStorage
    }

    func send(signal: Int32, to pid: Int32) throws {
        lock.lock()
        defer { lock.unlock() }
        signalStorage.append(SentSignal(pid: pid, signal: signal))
        if signal == SIGKILL {
            killedPIDs.insert(pid)
            aliveSequences[pid] = [false]
        }
    }

    func isRunning(pid: Int32) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard var sequence = aliveSequences[pid] else {
            return false
        }
        guard !sequence.isEmpty else {
            if killedPIDs.contains(pid) {
                return false
            }
            return true
        }
        let current = sequence.removeFirst()
        aliveSequences[pid] = sequence
        return current
    }
}
