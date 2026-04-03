import Foundation
import Testing
import ProviderCatalog
import STFilePath
import STJSON
import SQLite3
@testable import ProviderUsage

@Suite("CodexAuthManager")
struct CodexAuthManagerTests {
    private func makeTempRoot(_ prefix: String) throws -> STFolder {
        let root = STFolder("/tmp").folder("\(prefix)-\(UUID().uuidString)")
        _ = root.createIfNotExists()
        return root
    }

    private static func makeJWT(payload: String) -> String {
        func encode(_ string: String) -> String {
            Data(string.utf8)
                .base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }

        let header = #"{"alg":"RS256","typ":"JWT"}"#
        return "\(encode(header)).\(encode(payload)).signature"
    }

    private func sqliteCount(databaseURL: URL, sql: String, bind: String) throws -> Int {
        var db: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            throw NSError(domain: "CodexAuthManagerTests.sqlite", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        }
        defer { sqlite3_close(db) }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "CodexAuthManagerTests.sqlite", code: 2, userInfo: [NSLocalizedDescriptionKey: message])
        }
        defer { sqlite3_finalize(statement) }

        _ = sqlite3_bind_text(statement, 1, bind, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        guard sqlite3_step(statement) == SQLITE_ROW else {
            let message = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "CodexAuthManagerTests.sqlite", code: 3, userInfo: [NSLocalizedDescriptionKey: message])
        }
        return Int(sqlite3_column_int(statement, 0))
    }

    private func sqliteCount(databaseURL: URL, sql: String) throws -> Int {
        var db: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            throw NSError(domain: "CodexAuthManagerTests.sqlite", code: 11, userInfo: [NSLocalizedDescriptionKey: message])
        }
        defer { sqlite3_close(db) }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "CodexAuthManagerTests.sqlite", code: 12, userInfo: [NSLocalizedDescriptionKey: message])
        }
        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_ROW else {
            let message = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "CodexAuthManagerTests.sqlite", code: 13, userInfo: [NSLocalizedDescriptionKey: message])
        }
        return Int(sqlite3_column_int(statement, 0))
    }

    private func sqliteString(databaseURL: URL, sql: String, bind: String) throws -> String? {
        var db: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            throw NSError(domain: "CodexAuthManagerTests.sqlite", code: 21, userInfo: [NSLocalizedDescriptionKey: message])
        }
        defer { sqlite3_close(db) }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "CodexAuthManagerTests.sqlite", code: 22, userInfo: [NSLocalizedDescriptionKey: message])
        }
        defer { sqlite3_finalize(statement) }

        _ = sqlite3_bind_text(statement, 1, bind, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil
        }
        guard let value = sqlite3_column_text(statement, 0) else { return nil }
        return String(cString: value)
    }

    private func sqliteExecute(databaseURL: URL, sql: String, bindings: [String] = []) throws {
        var db: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            throw NSError(domain: "CodexAuthManagerTests.sqlite", code: 31, userInfo: [NSLocalizedDescriptionKey: message])
        }
        defer { sqlite3_close(db) }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "CodexAuthManagerTests.sqlite", code: 32, userInfo: [NSLocalizedDescriptionKey: message])
        }
        defer { sqlite3_finalize(statement) }

        for (index, value) in bindings.enumerated() {
            _ = sqlite3_bind_text(statement, Int32(index + 1), value, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        let result = sqlite3_step(statement)
        guard result == SQLITE_DONE || result == SQLITE_ROW else {
            let message = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "CodexAuthManagerTests.sqlite", code: 33, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    private func accountAuthDataFromSQLite(
        manager: CodexAuthManager,
        account: CodexAuthAccount
    ) throws -> Data {
        guard let data = manager.accountAuthDataWithoutMaterialization(for: account), !data.isEmpty else {
            throw NSError(
                domain: "CodexAuthManagerTests",
                code: 9001,
                userInfo: [NSLocalizedDescriptionKey: "Expected SQLite auth payload for account \(account.id.uuidString)"]
            )
        }
        return data
    }

    @Test("Given NOLON_HOME env, when manager uses default root, then snapshots root is isolated to env path")
    func defaultRootRespectsNolonHomeEnv() async throws {
        let isolatedRoot = STFolder("/tmp")
            .folder("nolon-home-auth-\(UUID().uuidString)")
            .url
            .standardizedFileURL

        let manager = CodexAuthManager(
            environment: ["NOLON_HOME": isolatedRoot.path]
        )

        let codexRoot = manager.nolonCodexRootFolder()
        let expected = STFolder(isolatedRoot).folder("codex")
        #expect(codexRoot == expected)
    }

    @Test("Given provider id, when resolving isolated CLI login home, then path stays in NOLON_HOME codex sandbox")
    func cliLoginCodexHomeFolderUsesNolonSandbox() async throws {
        let isolatedRoot = STFolder("/tmp")
            .folder("nolon-home-login-\(UUID().uuidString)")
            .url
            .standardizedFileURL

        let manager = CodexAuthManager(
            environment: ["NOLON_HOME": isolatedRoot.path]
        )

        let folder = manager.cliLoginCodexHomeFolder(providerID: "codex")
        let expected = STFolder(isolatedRoot).folder("codex").folder("cli-login-home").folder("codex")
        #expect(folder == expected)
    }

    @Test("Given runtime home without skills link, when ensuring runtime skills symlink, then template and symlink are created")
    func ensureRuntimeSkillsSymlinkCreatesTemplateAndLink() async throws {
        let root = try makeTempRoot("codex-auth-runtime-skills")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let accountID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

        try manager.ensureRuntimeSkillsSymlink(accountID: accountID)

        let template = manager.runtimeSkillsTemplateFolder()
        #expect(template.isExists)

        let runtimeSkills = STPath(manager.runtimeHomeFolder(accountID: accountID).folder("skills").url)
        #expect(runtimeSkills.isSymbolicLink == true)
        let destination = try runtimeSkills.destinationOfSymbolicLink()
        #expect(STPath.standardizedPath(destination.url.path).path == STPath.standardizedPath(template.url.path).path)
    }

    @Test("Given runtime skills directory already exists, when ensuring runtime skills symlink, then directory is replaced with symlink")
    func ensureRuntimeSkillsSymlinkReplacesExistingDirectory() async throws {
        let root = try makeTempRoot("codex-auth-runtime-skills-replace")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let accountID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

        let runtimeSkillsFolder = manager.runtimeHomeFolder(accountID: accountID).folder("skills")
        _ = runtimeSkillsFolder.createIfNotExists()
        let legacyFile = runtimeSkillsFolder.file("legacy.txt")
        try legacyFile.overlay(with: "legacy")
        #expect(legacyFile.isExists)

        try manager.ensureRuntimeSkillsSymlink(accountID: accountID)

        let runtimeSkills = STPath(runtimeSkillsFolder.url)
        #expect(runtimeSkills.isSymbolicLink == true)
        #expect(legacyFile.isExists == false)
    }

    @Test("Given runtime skills is already linked to template, when ensuring runtime skills symlink, then keeps existing link target")
    func ensureRuntimeSkillsSymlinkKeepsExistingLink() async throws {
        let root = try makeTempRoot("codex-auth-runtime-skills-keep")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let accountID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!

        try manager.ensureRuntimeSkillsSymlink(accountID: accountID)
        let runtimeSkills = STPath(manager.runtimeHomeFolder(accountID: accountID).folder("skills").url)
        let before = try runtimeSkills.destinationOfSymbolicLink()

        let template = manager.runtimeSkillsTemplateFolder()
        let marker = template.file("marker.txt")
        try marker.overlay(with: "ok")

        try manager.ensureRuntimeSkillsSymlink(accountID: accountID)
        let after = try runtimeSkills.destinationOfSymbolicLink()

        #expect(STPath.standardizedPath(before.url.path).path == STPath.standardizedPath(after.url.path).path)
        #expect(marker.isExists == true)
    }

    @Test("Given stale runtime homes, when cleanup runs, then active account runtime home is preserved while stale inactive homes are removed")
    func cleanupRuntimeHomesPreservesActiveRemovesStaleInactive() async throws {
        let root = try makeTempRoot("codex-runtime-home-cleanup-active")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: root.folder("provider").folder("skills").url.path,
            workflowPath: root.folder("provider").folder("prompts").url.path,
            installMethod: .symlink,
            templateId: "codex"
        )
        let activeAccount = try await manager.addAccount(
            name: "active",
            authJSONString: #"{"tokens":{"id_token":"id-active","access_token":"access-active"}}"#
        )
        try await manager.setActiveAccount(activeAccount, for: provider)

        let staleInactiveID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        let activeRuntime = await manager.runtimeHomeFolder(accountID: activeAccount.id)
        let staleRuntime = await manager.runtimeHomeFolder(accountID: staleInactiveID)
        _ = activeRuntime.createIfNotExists()
        _ = staleRuntime.createIfNotExists()

        let oldDate = Date(timeIntervalSince1970: 1_700_000_000)
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: activeRuntime.url.path)
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: staleRuntime.url.path)

        let report = try await manager.cleanupRuntimeHomesOnAppLaunch(maxAge: 60, now: oldDate.addingTimeInterval(3600))

        #expect(report.removedCount == 1)
        #expect(report.preservedActiveCount == 1)
        #expect(activeRuntime.isExists == true)
        #expect(staleRuntime.isExists == false)
    }

    @Test("Given recent inactive runtime home, when cleanup runs, then recent directory is kept")
    func cleanupRuntimeHomesKeepsRecentInactive() async throws {
        let root = try makeTempRoot("codex-runtime-home-cleanup-recent")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let inactiveID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
        let runtime = await manager.runtimeHomeFolder(accountID: inactiveID)
        _ = runtime.createIfNotExists()

        let now = Date(timeIntervalSince1970: 1_800_000_000)
        try FileManager.default.setAttributes(
            [.modificationDate: now.addingTimeInterval(-120)],
            ofItemAtPath: runtime.url.path
        )

        let report = try await manager.cleanupRuntimeHomesOnAppLaunch(maxAge: 3600, now: now)

        #expect(report.removedCount == 0)
        #expect(report.skippedRecentCount == 1)
        #expect(runtime.isExists == true)
    }

    @Test("Given account snapshot, when reading token pair, then returns id/access token and chatgpt account id")
    func readTokenPairFromSnapshot() async throws {
        let root = try makeTempRoot("codex-auth-manager")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let account = try await manager.addAccount(
            name: "test",
            authJSONString: #"{"tokens":{"id_token":"id-token-value","access_token":"access-token-value","account_id":"acct-123"}}"#
        )

        let pair = try await manager.readTokenPair(for: account)
        #expect(pair?.idToken == "id-token-value")
        #expect(pair?.accessToken == "access-token-value")
        #expect(pair?.chatgptAccountID == "acct-123")
    }

    @Test("Given unsorted auth json, when saving account, then persisted auth.json is pretty printed with sorted keys")
    func addAccountPersistsPrettySortedAuthJSON() async throws {
        let root = try makeTempRoot("codex-auth-format")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let account = try await manager.addAccount(
            name: "format-check",
            authJSONString: #"{"tokens":{"id_token":"id-token","access_token":"access-token"},"email":"pretty@example.com","auth_mode":"chatgpt","OPENAI_API_KEY":null}"#
        )

        let raw = try #require(String(data: accountAuthDataFromSQLite(manager: manager, account: account), encoding: .utf8))

        #expect(raw.contains("\n  \"auth_mode\""))
        let openAIKeyRange = try #require(raw.range(of: "\"OPENAI_API_KEY\""))
        let authModeRange = try #require(raw.range(of: "\"auth_mode\""))
        let emailRange = try #require(raw.range(of: "\"email\""))
        #expect(openAIKeyRange.lowerBound < authModeRange.lowerBound)
        #expect(authModeRange.lowerBound < emailRange.lowerBound)
    }

    @Test("Given legacy chatgptAuthTokens mode, when saving account, then auth_mode is canonicalized to chatgpt")
    func addAccountCanonicalizesLegacyChatGPTAuthMode() async throws {
        let root = try makeTempRoot("codex-auth-canonical-mode")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let account = try await manager.addAccount(
            name: "canonical-mode",
            authJSONString: #"{"auth_mode":"chatgptAuthTokens","tokens":{"id_token":"id-token","access_token":"access-token"}}"#
        )

        let json = try #require(try? JSON(data: accountAuthDataFromSQLite(manager: manager, account: account)))
        #expect(json["auth_mode"].string == "chatgpt")
    }

    @Test("Given sqlite-only account payload, when requesting account auth file path, then manager does not materialize legacy snapshot file")
    func accountAuthFileDoesNotMaterializeSQLiteMirror() async throws {
        let root = try makeTempRoot("codex-auth-no-mirror")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let account = try await manager.addAccount(
            name: "no-mirror",
            authJSONString: #"{"tokens":{"id_token":"id-token","access_token":"access-token"},"email":"sqlite-only@example.com"}"#
        )

        let sqliteData = try accountAuthDataFromSQLite(manager: manager, account: account)
        #expect(!sqliteData.isEmpty)

        let file = await manager.accountAuthFile(relativeAuthPath: account.relativeAuthPath)
        #expect(file.isExists == false)
    }

    @Test("Given selected snapshot, when activating account, then provider auth is symlinked to snapshot")
    func activateAccountCreatesProviderAuthSymlink() async throws {
        let root = try makeTempRoot("codex-auth-clean")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let account = try await manager.addAccount(
            name: "work",
            authJSONString: #"{"tokens":{"id_token":"id-1","access_token":"access-1"},"nolon":{"usage_cache":{"fetch_kind":"api"}}}"#
        )
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: root.folder("provider").folder("skills").url.path,
            workflowPath: root.folder("provider").folder("prompts").url.path,
            installMethod: .symlink,
            templateId: "codex"
        )

        try await manager.activateAccount(account, for: provider)
        let providerAuth = try #require(await manager.authFile(for: provider))
        #expect(providerAuth.isSymbolicLink == true)
        let destination = try providerAuth.destinationOfSymbolicLink()
        let snapshot = await manager.accountAuthFile(account)
        #expect(STPath.standardizedPath(destination.url.path).path == STPath.standardizedPath(snapshot.url.path).path)
    }

    @Test("Given active snapshot symlink, when deleting that account, then provider auth symlink is removed")
    func deleteAccountRemovesProviderAuthSymlinkForDeletedActiveAccount() async throws {
        let root = try makeTempRoot("codex-auth-delete-active-symlink")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let account = try await manager.addAccount(
            name: "active",
            authJSONString: #"{"tokens":{"id_token":"id-delete","access_token":"access-delete"},"email":"active-delete@example.com"}"#
        )
        let providerRoot = root.folder("provider")
        _ = providerRoot.createIfNotExists()
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: providerRoot.folder("skills").url.path,
            workflowPath: providerRoot.folder("prompts").url.path,
            installMethod: .symlink,
            templateId: "codex"
        )

        try await manager.activateAccountAndMarkActive(account, for: provider)
        let providerAuth = try #require(await manager.authFile(for: provider))
        #expect(providerAuth.isSymbolicLink == true)

        try await manager.deleteAccount(id: account.id, provider: provider)

        #expect(providerAuth.isExists == false)
        #expect(providerAuth.isSymbolicLink == false)
        let remaining = try await manager.loadAccounts()
        #expect(remaining.isEmpty)
        let activeID = await manager.activeAccountId(for: provider)
        #expect(activeID == nil)
    }

    @Test("Given activated snapshot via unified activation, when provider auth is deleted, then active account still resolves from registry")
    func activateAccountAndMarkActivePersistsRegistry() async throws {
        let root = try makeTempRoot("codex-auth-activate-mark")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let account = try await manager.addAccount(
            name: "work",
            authJSONString: #"{"tokens":{"id_token":"id-1","access_token":"access-1"}}"#
        )
        let providerRoot = root.folder("provider")
        _ = providerRoot.createIfNotExists()
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: providerRoot.folder("skills").url.path,
            workflowPath: providerRoot.folder("prompts").url.path,
            installMethod: .symlink,
            templateId: "codex"
        )

        try await manager.activateAccountAndMarkActive(account, for: provider)
        try providerRoot.file("auth.json").delete()

        let activeId = await manager.activeAccountId(for: provider)
        #expect(activeId == account.id)
    }

    @Test("Given provider auth still points to chatgpt snapshot, when registry switches to relay profile, then active account prefers relay registry")
    func activeAccountPrefersRelayRegistryOverProviderAuthSnapshot() async throws {
        let root = try makeTempRoot("codex-auth-relay-registry-priority")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let primary = try await manager.addAccount(
            name: "primary",
            authJSONString: #"{"tokens":{"id_token":"id-primary","access_token":"access-primary"},"email":"primary@example.com"}"#
        )
        let providerRoot = root.folder("provider")
        _ = providerRoot.createIfNotExists()
        let provider = Provider(
            id: "codex",
            name: "Codex",
            defaultSkillsPath: providerRoot.folder("skills").url.path,
            workflowPath: providerRoot.folder("prompts").url.path,
            installMethod: .symlink,
            templateId: "codex"
        )
        try await manager.activateAccountAndMarkActive(primary, for: provider)

        let relay = try await manager.addConfiguredAccount(
            name: "__gateway_reply__-codex",
            apiKey: "nolon-gateway-virtual-api-key",
            relay: .init(
                baseURL: "http://127.0.0.1:18083",
                modelProvider: "openai",
                queryParams: [
                    "nolon_gateway_virtual": "1",
                    "provider_id": "codex",
                ]
            )
        )
        try await manager.setActiveAccount(relay, for: provider)

        let activeID = await manager.activeAccountId(for: provider)
        #expect(activeID == relay.id)
    }

    @Test("Given snapshot drift right after activation, when preflight runs then active snapshot is restored from activation baseline")
    func activateAccountAndMarkActiveSeedsDriftRestoreBaseline() async throws {
        let root = try makeTempRoot("codex-auth-activate-drift-baseline")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let active = try await manager.addAccount(
            name: "active",
            authJSONString: #"{"tokens":{"id_token":"id-active","access_token":"access-active"},"email":"active@example.com"}"#
        )
        let providerRoot = root.folder("provider")
        _ = providerRoot.createIfNotExists()
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: providerRoot.folder("skills").url.path,
            workflowPath: providerRoot.folder("prompts").url.path,
            installMethod: .symlink,
            templateId: "codex"
        )

        try await manager.activateAccountAndMarkActive(active, for: provider)

        let driftedRaw = #"{"tokens":{"id_token":"id-drift","access_token":"access-drift"},"email":"drift-after-activate@example.com"}"#
        let activeID = try #require(await manager.activeAccountId(for: provider))
        let activeResolved = try #require((try await manager.loadAccounts()).first(where: { $0.id == activeID }))
        let activeFile = await manager.accountAuthFile(activeResolved)
        try activeFile.overlay(with: Data(driftedRaw.utf8))

        _ = try await manager.preflightManagedAuthIfNeeded(
            for: provider,
            forceBackup: false,
            reason: "post_activate_detect_drift"
        )

        let restoredActiveID = try #require(await manager.activeAccountId(for: provider))
        let restoredActive = try #require((try await manager.loadAccounts()).first(where: { $0.id == restoredActiveID }))
        let restoredSummary = CodexAuthSummary.fromJSONData(try await manager.accountAuthFile(restoredActive).data())
        #expect(restoredSummary.email == "active@example.com")

        let accounts = try await manager.loadAccounts()
        var driftedFound = false
        for account in accounts where account.id != restoredActiveID {
            let file = await manager.accountAuthFile(account)
            let summary = CodexAuthSummary.fromJSONData((try? file.data()) ?? Data())
            if summary.email == "drift-after-activate@example.com" {
                driftedFound = true
                break
            }
        }
        #expect(driftedFound == true)
    }

    @Test("Given fresh CLI login, when finalizing, then account is active and provider auth contains new token")
    func finalizeCLILoginSyncsAndMarksActive() async throws {
        let root = try makeTempRoot("codex-auth-finalize")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let providerRoot = root.folder("provider")
        _ = providerRoot.createIfNotExists()

        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: providerRoot.folder("skills").url.path,
            workflowPath: providerRoot.folder("prompts").url.path,
            installMethod: .symlink,
            templateId: "codex"
        )

        let authURL = providerRoot.file("auth.json").url
        let raw = #"{"tokens":{"id_token":"id-2","access_token":"access-2"},"email":"cli@example.com"}"#
        try raw.write(to: authURL, atomically: true, encoding: .utf8)

        let account = try await manager.finalizeCLILogin(provider: provider, newAccountName: "cli")
        let activeId = await manager.activeAccountId(for: provider)
        let syncedRaw = try #require(await manager.readAuthJSONString(from: provider))
        let syncedJSON = try #require(try? JSON(data: Data(syncedRaw.utf8)))

        #expect(activeId == account.id)
        #expect(syncedJSON["tokens"]["id_token"].string == "id-2")
        #expect(syncedJSON["tokens"]["access_token"].string == "access-2")
    }

    @Test("Given preferred snapshot and CLI login payload, when recording login snapshot, then preferred snapshot is updated and sync metadata is refreshed")
    func recordCLILoginSnapshotUpdatesPreferredAndMetadata() async throws {
        let root = try makeTempRoot("codex-auth-record-cli")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let preferred = try await manager.addAccount(
            name: "preferred",
            authJSONString: #"{"tokens":{"id_token":"old-id","access_token":"old-access"},"email":"preferred@example.com"}"#
        )
        _ = try await manager.addAccount(
            name: "other",
            authJSONString: #"{"tokens":{"id_token":"other-id","access_token":"other-access"},"email":"other@example.com"}"#
        )
        try await manager.updateSyncFailure(
            for: preferred,
            message: "previous failure",
            date: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let loginAt = Date(timeIntervalSince1970: 1_700_000_100)
        let updated = try await manager.recordCLILoginSnapshot(
            authJSONString: #"{"tokens":{"id_token":"new-id","access_token":"new-access"},"email":"other@example.com"}"#,
            preferredAccountID: preferred.id,
            loginAt: loginAt
        )

        #expect(updated.id == preferred.id)
        let tokenPair = try await manager.readTokenPair(for: updated)
        #expect(tokenPair?.idToken == "new-id")
        #expect(tokenPair?.accessToken == "new-access")

        let file = await manager.accountAuthFile(updated)
        let summary = CodexAuthSummary.fromJSONData(try file.data())
        #expect(summary.lastLoginAt == loginAt)
        #expect(summary.lastSyncSucceededAt == loginAt)
        #expect(summary.lastSyncFailedAt == nil)
        #expect(summary.lastSyncFailureMessage == nil)
    }

    @Test("Given existing snapshot with same email but different account id, when recording CLI login snapshot, then a new snapshot is created")
    func recordCLILoginSnapshotCreatesNewWhenEmailMatchesButAccountIDDiffers() async throws {
        let root = try makeTempRoot("codex-auth-record-email")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let existing = try await manager.addAccount(
            name: "existing",
            authJSONString: #"{"email":"same@example.com","tokens":{"account_id":"acct-old","id_token":"old-id","access_token":"old-access"}}"#
        )

        let created = try await manager.recordCLILoginSnapshot(
            authJSONString: #"{"email":"same@example.com","tokens":{"account_id":"acct-new","id_token":"new-id","access_token":"new-access"}}"#,
            preferredAccountID: nil
        )

        #expect(created.id != existing.id)
        let all = try await manager.loadAccounts()
        #expect(all.count == 2)
        let persistedExisting = try #require(all.first(where: { $0.id == existing.id }))
        let existingPair = try await manager.readTokenPair(for: persistedExisting)
        #expect(existingPair?.idToken == "old-id")
        #expect(existingPair?.accessToken == "old-access")
        let persistedCreated = try #require(all.first(where: { $0.id == created.id }))
        let createdPair = try await manager.readTokenPair(for: persistedCreated)
        #expect(createdPair?.idToken == "new-id")
        #expect(createdPair?.accessToken == "new-access")
    }

    @Test("Given long sync failure detail when persisting then lastSyncFailureMessage keeps full text")
    func updateSyncFailurePersistsFullMessage() async throws {
        let root = try makeTempRoot("codex-auth-sync-failure-full")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let account = try await manager.addAccount(
            name: "cli",
            authJSONString: #"{"tokens":{"id_token":"id","access_token":"access"},"email":"cli@example.com"}"#
        )

        let longMessage = String(repeating: "A", count: 500)
        try await manager.updateSyncFailure(for: account, message: longMessage, date: Date(timeIntervalSince1970: 1_700_000_000))

        let file = await manager.accountAuthFile(account)
        let summary = CodexAuthSummary.fromJSONData(try file.data())
        #expect(summary.lastSyncFailureMessage == longMessage)
    }

    @Test("Given existing snapshot with same email and same account id, when recording CLI login snapshot, then account is overwritten in-place")
    func recordCLILoginSnapshotOverwritesWhenEmailAndAccountIDMatch() async throws {
        let root = try makeTempRoot("codex-auth-record-email-accountid")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let existing = try await manager.addAccount(
            name: "existing",
            authJSONString: #"{"email":"same@example.com","tokens":{"account_id":"acct-same","id_token":"old-id","access_token":"old-access"}}"#
        )

        let updated = try await manager.recordCLILoginSnapshot(
            authJSONString: #"{"email":"same@example.com","tokens":{"account_id":"acct-same","id_token":"new-id","access_token":"new-access"}}"#,
            preferredAccountID: nil
        )

        #expect(updated.id == existing.id)
        let all = try await manager.loadAccounts()
        #expect(all.count == 1)
        let tokenPair = try await manager.readTokenPair(for: updated)
        #expect(tokenPair?.idToken == "new-id")
        #expect(tokenPair?.accessToken == "new-access")
    }

    @Test("Given detached provider auth file with same account id and same email, when reconciling detached auth, then matching snapshot is overwritten, relinked, and marked active")
    func reconcileDetachedProviderAuthOverwritesByEmail() async throws {
        let root = try makeTempRoot("codex-auth-reconcile-detached")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let existing = try await manager.addAccount(
            name: "existing",
            authJSONString: #"{"tokens":{"id_token":"old-id","access_token":"old-access","account_id":"acct-team"},"email":"same@example.com"}"#
        )
        let providerRoot = root.folder("provider")
        _ = providerRoot.createIfNotExists()
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: providerRoot.folder("skills").url.path,
            workflowPath: providerRoot.folder("prompts").url.path,
            installMethod: .symlink,
            templateId: "codex"
        )

        let detachedAuthURL = providerRoot.file("auth.json").url
        let detachedRaw = #"{"tokens":{"id_token":"new-id","access_token":"new-access","account_id":"acct-team"},"email":"same@example.com"}"#
        try detachedRaw.write(to: detachedAuthURL, atomically: true, encoding: .utf8)

        let reconciled = try await manager.reconcileDetachedProviderAuthIfNeeded(for: provider)
        let resolved = try #require(reconciled)
        #expect(resolved.id == existing.id)

        let tokenPair = try await manager.readTokenPair(for: resolved)
        #expect(tokenPair?.idToken == "new-id")
        #expect(tokenPair?.accessToken == "new-access")

        let providerAuth = try #require(await manager.authFile(for: provider))
        #expect(providerAuth.isSymbolicLink == true)
        let destination = try providerAuth.destinationOfSymbolicLink()
        let snapshotPath = await manager.accountAuthFile(resolved).url.path
        #expect(STPath.standardizedPath(destination.url.path).path == STPath.standardizedPath(snapshotPath).path)

        let activeId = await manager.activeAccountId(for: provider)
        #expect(activeId == resolved.id)
    }

    @Test("Given detached provider auth with same account id but different email, when reconciling detached auth, then a new snapshot is created instead of overwriting existing one")
    func reconcileDetachedProviderAuthCreatesNewWhenAccountIDMatchesButEmailDiffers() async throws {
        let root = try makeTempRoot("codex-auth-reconcile-accountid-email-diff")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let existing = try await manager.addAccount(
            name: "existing",
            authJSONString: #"{"tokens":{"id_token":"old-id","access_token":"old-access","account_id":"acct-shared"},"email":"existing@example.com"}"#
        )
        let existingPairBefore = try await manager.readTokenPair(for: existing)

        let providerRoot = root.folder("provider")
        _ = providerRoot.createIfNotExists()
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: providerRoot.folder("skills").url.path,
            workflowPath: providerRoot.folder("prompts").url.path,
            installMethod: .symlink,
            templateId: "codex"
        )

        let detachedAuthURL = providerRoot.file("auth.json").url
        let detachedRaw = #"{"tokens":{"id_token":"new-id","access_token":"new-access","account_id":"acct-shared"},"email":"fresh@example.com"}"#
        try detachedRaw.write(to: detachedAuthURL, atomically: true, encoding: .utf8)

        let reconciled = try await manager.reconcileDetachedProviderAuthIfNeeded(for: provider)
        let resolved = try #require(reconciled)
        #expect(resolved.id != existing.id)

        let all = try await manager.loadAccounts()
        #expect(all.count == 2)

        let existingAfter = try #require(all.first(where: { $0.id == existing.id }))
        let existingPairAfter = try await manager.readTokenPair(for: existingAfter)
        #expect(existingPairAfter?.idToken == existingPairBefore?.idToken)
        #expect(existingPairAfter?.accessToken == existingPairBefore?.accessToken)
    }

    @Test("Given detached provider auth without matching snapshot, when reconciling detached auth, then migrate to new snapshot and relink provider auth")
    func reconcileDetachedProviderAuthMigratesAndRelinks() async throws {
        let root = try makeTempRoot("codex-auth-reconcile-migrate")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        _ = try await manager.addAccount(
            name: "existing",
            authJSONString: #"{"tokens":{"id_token":"old-id","access_token":"old-access"},"email":"existing@example.com"}"#
        )
        let providerRoot = root.folder("provider")
        _ = providerRoot.createIfNotExists()
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: providerRoot.folder("skills").url.path,
            workflowPath: providerRoot.folder("prompts").url.path,
            installMethod: .symlink,
            templateId: "codex"
        )

        let detachedAuthURL = providerRoot.file("auth.json").url
        let detachedRaw = #"{"tokens":{"id_token":"new-id","access_token":"new-access"},"email":"fresh@example.com"}"#
        try detachedRaw.write(to: detachedAuthURL, atomically: true, encoding: .utf8)

        let reconciled = try await manager.reconcileDetachedProviderAuthIfNeeded(for: provider)
        let account = try #require(reconciled)
        let summary = CodexAuthSummary.fromJSONData(try await manager.accountAuthFile(account).data())
        #expect(summary.email == "fresh@example.com")

        let providerAuth = try #require(await manager.authFile(for: provider))
        #expect(providerAuth.isSymbolicLink == true)
        let destination = try providerAuth.destinationOfSymbolicLink()
        let snapshotPath = await manager.accountAuthFile(account).url.path
        #expect(STPath.standardizedPath(destination.url.path).path == STPath.standardizedPath(snapshotPath).path)

        let activeId = await manager.activeAccountId(for: provider)
        #expect(activeId == account.id)
    }

    @Test("Given detached provider auth and empty snapshots, when reading management status, then enable and migration are required")
    func managementStatusShowsEnableAndMigrationNeeded() async throws {
        let root = try makeTempRoot("codex-auth-management-status")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let providerRoot = root.folder("provider")
        _ = providerRoot.createIfNotExists()
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: providerRoot.folder("skills").url.path,
            workflowPath: providerRoot.folder("prompts").url.path,
            installMethod: .symlink,
            templateId: "codex"
        )

        try #"{"tokens":{"id_token":"id-1","access_token":"access-1"}}"#
            .write(to: providerRoot.file("auth.json").url, atomically: true, encoding: .utf8)

        let status = await manager.managementStatus(for: provider)
        #expect(status.hasProviderAuthFile == true)
        #expect(status.providerAuthIsSymlink == false)
        #expect(status.snapshotCount == 0)
        #expect(status.needsEnable == true)
        #expect(status.needsMigration == true)
    }

    @Test("Given mixed import files, when validating then importing, only valid auth files become snapshots")
    func validateAndImportAuthFilesOnlyImportsValidItems() async throws {
        let root = try makeTempRoot("codex-auth-import-validate")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let inputFolder = root.folder("input")
        _ = inputFolder.createIfNotExists()

        let validURL = inputFolder.file("valid.json").url
        let invalidURL = inputFolder.file("invalid.json").url
        try #"{"tokens":{"id_token":"id-valid","access_token":"access-valid"},"email":"valid@example.com"}"#
            .write(to: validURL, atomically: true, encoding: .utf8)
        try #"{"email":"invalid@example.com"}"#
            .write(to: invalidURL, atomically: true, encoding: .utf8)

        let results = await manager.validateImportAuthFiles(urls: [validURL, invalidURL])
        #expect(results.count == 2)
        #expect(results.filter(\.isValid).count == 1)
        #expect(results.filter { !$0.isValid }.count == 1)

        let imported = try await manager.importValidatedAuthFiles(results: results)
        #expect(imported.count == 1)
        let tokenPair = try await manager.readTokenPair(for: imported[0])
        #expect(tokenPair?.idToken == "id-valid")
        #expect(tokenPair?.accessToken == "access-valid")
    }

    @Test("Given auth payload with api_key plus email/account_id, when validating import then it is rejected as unsupported combination")
    func validateImportRejectsFourthIdentityCombination() async throws {
        let root = try makeTempRoot("codex-auth-identity-invalid")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let inputFolder = root.folder("input")
        _ = inputFolder.createIfNotExists()
        let invalidURL = inputFolder.file("invalid-combo.json").url
        try #"{"OPENAI_API_KEY":"sk-123","email":"user@example.com","tokens":{"account_id":"acct-1","id_token":"id-token","access_token":"access-token"}}"#
            .write(to: invalidURL, atomically: true, encoding: .utf8)

        let results = await manager.validateImportAuthFiles(urls: [invalidURL])
        #expect(results.count == 1)
        #expect(results[0].isValid == false)
        #expect((results[0].reason ?? "").contains("仅支持"))
    }

    @Test("Given auth payload with email/account_id only, when validating import then it is accepted")
    func validateImportAcceptsEmailAccountIDIdentityCombination() async throws {
        let root = try makeTempRoot("codex-auth-identity-email-account")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let inputFolder = root.folder("input")
        _ = inputFolder.createIfNotExists()
        let validURL = inputFolder.file("valid-combo.json").url
        try #"{"email":"user@example.com","tokens":{"account_id":"acct-1","id_token":"id-token","access_token":"access-token"}}"#
            .write(to: validURL, atomically: true, encoding: .utf8)

        let results = await manager.validateImportAuthFiles(urls: [validURL])
        #expect(results.count == 1)
        #expect(results[0].isValid == true)
    }

    @Test("Given legacy snapshot files and active account file, when loading accounts then manager migrates account system to sqlite")
    func migrateLegacyAccountSystemToSQLiteOnLoad() async throws {
        let root = try makeTempRoot("codex-auth-sqlite-migration")
        defer { try? root.delete() }

        let codexRoot = root.folder("codex")
        let authFolder = codexRoot.folder("auth")
        _ = authFolder.createIfNotExists()
        let authFile = authFolder.file("legacy.json")
        try #"{"tokens":{"id_token":"id-legacy","access_token":"access-legacy"},"email":"legacy@example.com"}"#
            .write(to: authFile.url, atomically: true, encoding: .utf8)

        let activeFile = codexRoot.file("active-accounts.json")
        try #"{"providers":{"codex":"00000000-0000-0000-0000-000000000001"}}"#
            .write(to: activeFile.url, atomically: true, encoding: .utf8)

        let manager = CodexAuthManager(rootURL: root.url)
        let accounts = try await manager.loadAccounts()
        #expect(accounts.count == 1)

        let dbURL = codexRoot.file("accounts.sqlite3").url
        #expect(FileManager.default.fileExists(atPath: dbURL.path))

        let accountCount = try sqliteCount(
            databaseURL: dbURL,
            sql: "SELECT COUNT(*) FROM codex_accounts;"
        )
        #expect(accountCount == 1)

        let activeCount = try sqliteCount(
            databaseURL: dbURL,
            sql: "SELECT COUNT(*) FROM codex_active_accounts;"
        )
        #expect(activeCount == 1)
    }

    @Test("Given custom SQLite group destination, when importing validated auth files then rows are upserted in sqlite group")
    func importValidatedAuthFilesToCustomSQLiteGroup() async throws {
        let root = try makeTempRoot("codex-auth-import-sqlite-group")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let inputFolder = root.folder("input")
        _ = inputFolder.createIfNotExists()

        let url = inputFolder.file("valid.json").url
        try #"{"tokens":{"id_token":"id-valid","access_token":"access-valid"},"email":"valid@example.com"}"#
            .write(to: url, atomically: true, encoding: .utf8)

        let results = await manager.validateImportAuthFiles(urls: [url])
        #expect(results.count == 1)
        #expect(results[0].isValid == true)

        _ = try await manager.importValidatedAuthFiles(
            results: results,
            destination: .customSQLiteGroup(name: "Team A")
        )
        _ = try await manager.importValidatedAuthFiles(
            results: results,
            destination: .customSQLiteGroup(name: "Team A")
        )

        let dbURL = root.folder("codex").file("imports.sqlite3").url
        #expect(FileManager.default.fileExists(atPath: dbURL.path))

        let groupCount = try sqliteCount(
            databaseURL: dbURL,
            sql: "SELECT COUNT(*) FROM custom_import_groups WHERE name = ?;",
            bind: "Team A"
        )
        #expect(groupCount == 1)

        let accountCount = try sqliteCount(
            databaseURL: dbURL,
            sql: """
                SELECT COUNT(*) FROM imported_codex_accounts
                WHERE group_id = (
                    SELECT id FROM custom_import_groups WHERE name = ?
                );
            """,
            bind: "Team A"
        )
        #expect(accountCount == 1)
    }

    @Test("Given new account creation, when adding account then sqlite index is updated")
    func addAccountAlsoPersistsSQLiteIndex() async throws {
        let root = try makeTempRoot("codex-auth-sqlite-add")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        _ = try await manager.addAccount(
            name: "A",
            authJSONString: #"{"tokens":{"id_token":"id-a","access_token":"access-a"},"email":"a@example.com"}"#
        )

        let dbURL = root.folder("codex").file("accounts.sqlite3").url
        let count = try sqliteCount(databaseURL: dbURL, sql: "SELECT COUNT(*) FROM codex_accounts;")
        #expect(count == 1)
    }

    @Test("Given auth json carries plan type, when persisting account then metadata stores plan_type and sqlite reconstruction keeps plan")
    func addAccountPersistsPlanTypeIntoMetadataAndReconstructsFromSQLite() async throws {
        let root = try makeTempRoot("codex-auth-sqlite-plan-type")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let account = try await manager.addAccount(
            name: "Plan",
            authJSONString: #"{"auth_mode":"chatgpt","email":"plan@example.com","plan_type":"pro","tokens":{"id_token":"id-pro","access_token":"access-pro","account_id":"acct-pro"}}"#
        )

        let dbURL = manager.accountsSQLiteFile().url
        let persistedPlanType = try sqliteString(
            databaseURL: dbURL,
            sql: "SELECT plan_type FROM codex_account_metadata WHERE account_id = ?;",
            bind: account.id.uuidString
        )
        #expect(persistedPlanType == "pro")

        let reconstructedData = try #require(manager.accountAuthDataWithoutMaterialization(for: account))
        let reconstructedJSON = try #require(try? JSON(data: reconstructedData))
        #expect(reconstructedJSON["plan_type"].string == "pro")
        #expect(reconstructedJSON["plan"].string == "pro")
    }

    @Test("Given refreshed plan from usage outcome, when upserting plan type then auth and metadata plan_type are both updated")
    func upsertPlanTypePersistsToAuthAndMetadata() async throws {
        let root = try makeTempRoot("codex-auth-upsert-plan-type")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let account = try await manager.addAccount(
            name: "Plan",
            authJSONString: #"{"auth_mode":"chatgpt","email":"plan@example.com","plan_type":"free","tokens":{"id_token":"id-pro","access_token":"access-pro","account_id":"acct-pro"}}"#
        )

        let changed = try await manager.upsertPlanType(for: account, plan: "pro")
        #expect(changed == true)

        let latest = try #require(manager.accountAuthDataWithoutMaterialization(for: account))
        let json = try #require(try? JSON(data: latest))
        #expect(json["plan_type"].string == "pro")
        #expect(json["plan"].string == "pro")

        let dbURL = manager.accountsSQLiteFile().url
        let persistedPlanType = try sqliteString(
            databaseURL: dbURL,
            sql: "SELECT plan_type FROM codex_account_metadata WHERE account_id = ?;",
            bind: account.id.uuidString
        )
        #expect(persistedPlanType == "pro")
    }

    @Test("Given two provider active rows, when updating one provider active account then unrelated provider updated_at remains unchanged")
    func setActiveAccountDoesNotRewriteUnchangedProviderRows() async throws {
        let root = try makeTempRoot("codex-auth-active-map-incremental")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let accountA = try await manager.addAccount(
            name: "A",
            authJSONString: #"{"tokens":{"id_token":"id-a","access_token":"access-a"},"email":"a@example.com"}"#
        )
        let accountB = try await manager.addAccount(
            name: "B",
            authJSONString: #"{"tokens":{"id_token":"id-b","access_token":"access-b"},"email":"b@example.com"}"#
        )

        let providerRoot = root.folder("provider")
        _ = providerRoot.createIfNotExists()
        let providerA = Provider(
            id: "codex-a",
            name: "Codex A",
            defaultSkillsPath: providerRoot.folder("skills-a").url.path,
            workflowPath: providerRoot.folder("prompts-a").url.path,
            installMethod: .symlink,
            templateId: "codex"
        )
        let providerB = Provider(
            id: "codex-b",
            name: "Codex B",
            defaultSkillsPath: providerRoot.folder("skills-b").url.path,
            workflowPath: providerRoot.folder("prompts-b").url.path,
            installMethod: .symlink,
            templateId: "codex"
        )

        try await manager.setActiveAccount(accountA, for: providerA)
        let dbURL = manager.accountsSQLiteFile().url
        let providerATimestampBeforeRaw = try sqliteString(
            databaseURL: dbURL,
            sql: "SELECT updated_at FROM codex_active_accounts WHERE provider_id = ?;",
            bind: providerA.id
        )
        let providerATimestampBefore = try #require(providerATimestampBeforeRaw)

        try await manager.setActiveAccount(accountB, for: providerB)
        let providerATimestampAfterRaw = try sqliteString(
            databaseURL: dbURL,
            sql: "SELECT updated_at FROM codex_active_accounts WHERE provider_id = ?;",
            bind: providerA.id
        )
        let providerATimestampAfter = try #require(providerATimestampAfterRaw)

        #expect(providerATimestampAfter == providerATimestampBefore)
    }

    @Test("Given stale legacy provider rows in active sqlite map, when setting active account for original codex vendor then stale rows are pruned")
    func setActiveAccountPrunesStaleLegacyProviderRows() async throws {
        let root = try makeTempRoot("codex-auth-active-map-prune")
        defer { try? root.delete() }

        let provider = Provider(
            id: "E7D873DA-5E19-44D2-A389-E995A4C0A223",
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: root.folder("skills").url.path,
            workflowPath: root.folder("workflows").url.path,
            iconName: "terminal",
            installMethod: .symlink,
            skillsLinkEnabled: false,
            vendorCategory: .original,
            templateId: ProviderTemplate.codex.rawValue
        )
        _ = try root.file("providers.json").overlay(with: JSONEncoder().encode([provider]))

        let manager = CodexAuthManager(rootURL: root.url)
        let account = try await manager.addAccount(
            name: "A",
            authJSONString: #"{"tokens":{"id_token":"id-a","access_token":"access-a"},"email":"a@example.com"}"#
        )

        try await manager.setActiveAccount(account, for: provider)
        let dbURL = manager.accountsSQLiteFile().url
        try sqliteExecute(
            databaseURL: dbURL,
            sql: "INSERT INTO codex_active_accounts (provider_id, account_id, updated_at) VALUES (?, ?, ?);",
            bindings: [
                "2113FA21-6970-4938-84A7-2A3B36B34DEE",
                account.id.uuidString,
                "2026-04-01T09:53:49.463Z",
            ]
        )
        let pollutedCount = try sqliteCount(databaseURL: dbURL, sql: "SELECT COUNT(*) FROM codex_active_accounts;")
        #expect(pollutedCount == 2)

        try await manager.setActiveAccount(account, for: provider)

        let count = try sqliteCount(databaseURL: dbURL, sql: "SELECT COUNT(*) FROM codex_active_accounts;")
        #expect(count == 1)
        let activeAccountRaw = try sqliteString(
            databaseURL: dbURL,
            sql: "SELECT account_id FROM codex_active_accounts WHERE provider_id = ?;",
            bind: "codex"
        )
        let activeAccount = try #require(activeAccountRaw)
        #expect(activeAccount == account.id.uuidString)
    }

    @Test("Given legacy original-vendor provider id row in sqlite, when loading accounts then active map migrates to canonical codex key")
    func loadAccountsMigratesLegacyOriginalVendorActiveKeyToCanonical() async throws {
        let root = try makeTempRoot("codex-auth-active-map-migrate")
        defer { try? root.delete() }

        let provider = Provider(
            id: "E7D873DA-5E19-44D2-A389-E995A4C0A223",
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: root.folder("skills").url.path,
            workflowPath: root.folder("workflows").url.path,
            iconName: "terminal",
            installMethod: .symlink,
            skillsLinkEnabled: false,
            vendorCategory: .original,
            templateId: ProviderTemplate.codex.rawValue
        )
        _ = try root.file("providers.json").overlay(with: JSONEncoder().encode([provider]))

        let manager = CodexAuthManager(rootURL: root.url)
        let account = try await manager.addAccount(
            name: "A",
            authJSONString: #"{"tokens":{"id_token":"id-a","access_token":"access-a"},"email":"a@example.com"}"#
        )

        let dbURL = manager.accountsSQLiteFile().url
        try sqliteExecute(
            databaseURL: dbURL,
            sql: "INSERT INTO codex_active_accounts (provider_id, account_id, updated_at) VALUES (?, ?, ?);",
            bindings: [
                provider.id,
                account.id.uuidString,
                "2026-04-01T09:53:49.463Z",
            ]
        )

        _ = try await manager.loadAccounts()

        let legacyCount = try sqliteCount(
            databaseURL: dbURL,
            sql: "SELECT COUNT(*) FROM codex_active_accounts WHERE provider_id = ?;",
            bind: provider.id
        )
        #expect(legacyCount == 0)

        let canonicalCount = try sqliteCount(
            databaseURL: dbURL,
            sql: "SELECT COUNT(*) FROM codex_active_accounts WHERE provider_id = ?;",
            bind: "codex"
        )
        #expect(canonicalCount == 1)
    }

    @Test("Given batch JSON array import file, when validating then importing, each element becomes a snapshot and top-level tokens are normalized into tokens.*")
    func validateAndImportAuthFilesExpandsJSONArrayFile() async throws {
        let root = try makeTempRoot("codex-auth-import-array")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let inputFolder = root.folder("input")
        _ = inputFolder.createIfNotExists()

        let batchURL = inputFolder.file("batch.json").url
        try """
        [
          {
            "type": "codex",
            "email": "a@example.com",
            "id_token": "id-a",
            "access_token": "access-a",
            "refresh_token": "refresh-a",
            "account_id": "acct-a",
            "expired": "2026-03-20T15:23:19Z"
          },
          {
            "type": "codex",
            "email": "b@example.com",
            "id_token": "id-b",
            "access_token": "access-b",
            "refresh_token": "refresh-b",
            "account_id": "acct-b"
          }
        ]
        """.write(to: batchURL, atomically: true, encoding: .utf8)

        let results = await manager.validateImportAuthFiles(urls: [batchURL])
        #expect(results.count == 2)
        #expect(results.filter(\.isValid).count == 2)

        let imported = try await manager.importValidatedAuthFiles(results: results)
        #expect(imported.count == 2)

        let accountA = try #require(imported.first)
        let accountB = try #require(imported.dropFirst().first)
        let pairA = try await manager.readTokenPair(for: accountA)
        let pairB = try await manager.readTokenPair(for: accountB)
        let pairs = [pairA, pairB].compactMap { $0 }
        #expect(pairs.count == 2)
        #expect(Set(pairs.map(\.idToken)) == ["id-a", "id-b"])
        #expect(Set(pairs.map(\.accessToken)) == ["access-a", "access-b"])
    }

    @Test("Given auth JSON contains type but not codex, when validating then candidate is rejected with a stable reason")
    func validateImportAuthFilesRejectsUnsupportedProviderType() async throws {
        let root = try makeTempRoot("codex-auth-import-type")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let inputFolder = root.folder("input")
        _ = inputFolder.createIfNotExists()

        let url = inputFolder.file("other.json").url
        try #"{"type":"other","id_token":"id","access_token":"access"}"#
            .write(to: url, atomically: true, encoding: .utf8)

        let results = await manager.validateImportAuthFiles(urls: [url])
        #expect(results.count == 1)
        #expect(results[0].isValid == false)
        #expect(results[0].reason?.lowercased().contains("type") == true)
    }

    @Test("Given oauth import only has access and refresh token, when validating then manager refreshes tokens and backfills account metadata")
    func validateImportAuthFilesRefreshesAndBackfillsMetadata() async throws {
        let root = try makeTempRoot("codex-auth-import-refresh")
        defer { try? root.delete() }

        let jwt = Self.makeJWT(payload: #"{"email":"refreshed@example.com","https://api.openai.com/auth":{"chatgpt_account_id":"acct-refreshed","chatgpt_plan_type":"pro"}}"#)
        let manager = CodexAuthManager(
            rootURL: root.url,
            refreshCodexTokenAction: { refreshToken in
                #expect(refreshToken == "refresh-only")
                return .init(
                    accessToken: "access-refreshed",
                    idToken: jwt,
                    refreshToken: "refresh-refreshed",
                    expiresIn: 3600
                )
            }
        )

        let inputFolder = root.folder("input")
        _ = inputFolder.createIfNotExists()
        let url = inputFolder.file("refresh-only.json").url
        try #"{"tokens":{"access_token":"access-only","refresh_token":"refresh-only"}}"#
            .write(to: url, atomically: true, encoding: .utf8)

        let results = await manager.validateImportAuthFiles(urls: [url])
        let result = try #require(results.first)
        #expect(results.count == 1)
        #expect(result.isValid == true)
        #expect(result.email == "refreshed@example.com")
        #expect(result.suggestedName == "refreshed@example.com")

        let raw = try #require(result.authJSONString)
        let json = try JSON(data: Data(raw.utf8))
        #expect(json["tokens"]["id_token"].string == jwt)
        #expect(json["tokens"]["access_token"].string == "access-refreshed")
        #expect(json["tokens"]["refresh_token"].string == "refresh-refreshed")
        #expect(json["tokens"]["account_id"].string == "acct-refreshed")
        #expect(json["chatgpt_account_id"].string == "acct-refreshed")
        #expect(json["email"].string == "refreshed@example.com")
        #expect(json["plan_type"].string == "pro")
        #expect(json["plan"].string == "pro")
    }

    @Test("Given oauth import has jwt tokens but missing profile fields, when validating then manager derives email account and plan from jwt")
    func validateImportAuthFilesDerivesMetadataFromJWTClaims() async throws {
        let root = try makeTempRoot("codex-auth-import-jwt-derive")
        defer { try? root.delete() }

        let jwt = Self.makeJWT(payload: #"{"email":"jwt-only@example.com","https://api.openai.com/auth":{"chatgpt_account_id":"acct-jwt","chatgpt_plan_type":"plus"}}"#)
        let manager = CodexAuthManager(
            rootURL: root.url,
            refreshCodexTokenAction: { _ in
                throw NSError(domain: "CodexAuthManagerTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "refresh should not be called"])
            }
        )

        let inputFolder = root.folder("input")
        _ = inputFolder.createIfNotExists()
        let url = inputFolder.file("jwt-only.json").url
        try #"{"tokens":{"id_token":"\#(jwt)","access_token":"access-jwt-only"}}"#
            .write(to: url, atomically: true, encoding: .utf8)

        let results = await manager.validateImportAuthFiles(urls: [url])
        let result = try #require(results.first)
        #expect(results.count == 1)
        #expect(result.isValid == true)
        #expect(result.email == "jwt-only@example.com")
        #expect(result.suggestedName == "jwt-only@example.com")

        let raw = try #require(result.authJSONString)
        let json = try JSON(data: Data(raw.utf8))
        #expect(json["email"].string == "jwt-only@example.com")
        #expect(json["tokens"]["account_id"].string == "acct-jwt")
        #expect(json["chatgpt_account_id"].string == "acct-jwt")
        #expect(json["plan_type"].string == "plus")
        #expect(json["plan"].string == "plus")
    }

    @Test("Given oauth import lacks profile fields and jwt hints, when validating then manager fetches resource account info with access token")
    func validateImportAuthFilesFetchesResourceAccountInfo() async throws {
        let root = try makeTempRoot("codex-auth-import-resource-info")
        defer { try? root.delete() }

        let manager = CodexAuthManager(
            rootURL: root.url,
            refreshCodexTokenAction: { _ in
                throw NSError(domain: "CodexAuthManagerTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "refresh should not be called"])
            },
            fetchCodexAccountInfoAction: { accessToken in
                #expect(accessToken == "access-resource")
                return .init(
                    email: "resource@example.com",
                    accountID: "acct-resource",
                    planType: "team"
                )
            }
        )

        let inputFolder = root.folder("input")
        _ = inputFolder.createIfNotExists()
        let url = inputFolder.file("resource-only.json").url
        try #"{"tokens":{"id_token":"header.payload.signature","access_token":"access-resource"}}"#
            .write(to: url, atomically: true, encoding: .utf8)

        let results = await manager.validateImportAuthFiles(urls: [url])
        let result = try #require(results.first)
        #expect(results.count == 1)
        #expect(result.isValid == true)
        #expect(result.email == "resource@example.com")
        #expect(result.suggestedName == "resource@example.com")

        let raw = try #require(result.authJSONString)
        let json = try JSON(data: Data(raw.utf8))
        #expect(json["email"].string == "resource@example.com")
        #expect(json["tokens"]["account_id"].string == "acct-resource")
        #expect(json["chatgpt_account_id"].string == "acct-resource")
        #expect(json["plan_type"].string == "team")
        #expect(json["plan"].string == "team")
    }

    @Test("Given codexXcode provider template, when resolving codex home, then auth manager returns valid home folder")
    func codexXcodeHomeFolderIsAvailable() async throws {
        let root = try makeTempRoot("codex-auth-codexxcode-home")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let providerRoot = root.folder("xcode-codex-home")
        let provider = Provider(
            name: "Codex (Xcode)",
            defaultSkillsPath: providerRoot.folder("skills").url.path,
            workflowPath: providerRoot.folder("prompts").url.path,
            installMethod: .symlink,
            templateId: "codexXcode"
        )

        let home = await manager.codexHomeFolder(for: provider)
        #expect(home == providerRoot)
    }

    @Test("Given auth payload with both email and api key suffix hints, when matching snapshot then email has highest priority")
    func matchAccountPrioritizesEmailOverApiKey() async throws {
        let root = try makeTempRoot("codex-auth-match-email")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let emailMatch = try await manager.addAccount(
            name: "email-match",
            authJSONString: #"{"OPENAI_API_KEY":"sk-email-1111","email":"email-match@example.com"}"#
        )
        _ = try await manager.addAccount(
            name: "key-match",
            authJSONString: #"{"OPENAI_API_KEY":"sk-key-9999","email":"other@example.com"}"#
        )
        let payload = Data(#"{"OPENAI_API_KEY":"sk-any-9999","email":"email-match@example.com"}"#.utf8)

        let matched = try await manager.matchAccountByAuthData(payload)
        #expect(matched?.id == emailMatch.id)
    }

    @Test("Given auth payload only contains account id, when matching snapshot then no snapshot is matched")
    func matchAccountDoesNotMatchWhenOnlyAccountIDIsPresent() async throws {
        let root = try makeTempRoot("codex-auth-match-accountid")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        _ = try await manager.addAccount(
            name: "accountid-match",
            authJSONString: #"{"tokens":{"account_id":"acct-123"},"OPENAI_API_KEY":"sk-one-1111"}"#
        )
        _ = try await manager.addAccount(
            name: "suffix-match",
            authJSONString: #"{"OPENAI_API_KEY":"sk-two-7777"}"#
        )
        let payload = Data(#"{"tokens":{"account_id":"acct-123"},"OPENAI_API_KEY":"sk-other-7777"}"#.utf8)

        let matched = try await manager.matchAccountByAuthData(payload)
        #expect(matched == nil)
    }

    @Test("Given same account id and missing email without nolon account id, when recording login snapshot then a new snapshot is created")
    func recordCLILoginSnapshotCreatesNewWhenMissingEmailAndNoNolonAccountID() async throws {
        let root = try makeTempRoot("codex-auth-record-accountid-only")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let existing = try await manager.addAccount(
            name: "existing",
            authJSONString: #"{"tokens":{"account_id":"acct-shared","id_token":"old-id","access_token":"old-access"},"email":"existing@example.com"}"#
        )

        let created = try await manager.recordCLILoginSnapshot(
            authJSONString: #"{"tokens":{"account_id":"acct-shared","id_token":"new-id","access_token":"new-access"}}"#,
            preferredAccountID: nil
        )

        #expect(created.id != existing.id)
        let all = try await manager.loadAccounts()
        #expect(all.count == 2)
    }

    @Test("Given same account id and same nolon account id with missing email, when recording login snapshot then existing snapshot is overwritten in place")
    func recordCLILoginSnapshotOverwritesWhenMissingEmailButNolonAccountIDMatches() async throws {
        let root = try makeTempRoot("codex-auth-record-accountid-nolon-id")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let existing = try await manager.addAccount(
            name: "existing",
            authJSONString: #"{"tokens":{"account_id":"acct-shared","id_token":"old-id","access_token":"old-access"},"email":"existing@example.com"}"#
        )

        let updated = try await manager.recordCLILoginSnapshot(
            authJSONString: #"""
            {
              "tokens": {
                "account_id": "acct-shared",
                "id_token": "new-id",
                "access_token": "new-access"
              },
              "nolon": {
                "account": {
                  "id": "\#(existing.id.uuidString)"
                }
              }
            }
            """#,
            preferredAccountID: nil
        )

        #expect(updated.id == existing.id)
        let all = try await manager.loadAccounts()
        #expect(all.count == 1)
        let pair = try await manager.readTokenPair(for: updated)
        #expect(pair?.idToken == "new-id")
        #expect(pair?.accessToken == "new-access")
    }

    @Test("Given same email and same JWT chatgpt account id but stale token account id, when recording login snapshot then updates existing snapshot instead of creating duplicate")
    func recordCLILoginSnapshotPrefersJWTAccountIDOverStaleTokenAccountID() async throws {
        let root = try makeTempRoot("codex-auth-login-jwt-account-id")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let canonicalJWT = Self.makeJWT(payload: """
        {
          "email": "same-user@example.com",
          "https://api.openai.com/auth": {
            "chatgpt_account_id": "acct-team"
          }
        }
        """)
        let staleJWT = Self.makeJWT(payload: """
        {
          "email": "same-user@example.com",
          "https://api.openai.com/auth": {
            "chatgpt_account_id": "acct-team"
          }
        }
        """)

        let existing = try await manager.addAccount(
            name: "team",
            authJSONString: #"""
            {
              "auth_mode": "chatgpt",
              "email": "same-user@example.com",
              "tokens": {
                "id_token": "\#(canonicalJWT)",
                "access_token": "access-old",
                "account_id": "acct-team"
              }
            }
            """#
        )

        let updated = try await manager.recordCLILoginSnapshot(
            authJSONString: #"""
            {
              "auth_mode": "chatgpt",
              "email": "same-user@example.com",
              "tokens": {
                "id_token": "\#(staleJWT)",
                "access_token": "access-new",
                "account_id": "acct-stale"
              }
            }
            """#,
            preferredAccountID: nil
        )

        let accounts = try await manager.loadAccounts()
        var matching: [CodexAuthAccount] = []
        for account in accounts {
            guard let data = try? await manager.accountAuthFile(account).data() else { continue }
            let summary = CodexAuthSummary.fromJSONData(data)
            if summary.email == "same-user@example.com" {
                matching.append(account)
            }
        }

        #expect(updated.id == existing.id)
        #expect(matching.count == 1)
        let updatedPair = try await manager.readTokenPair(for: updated)
        #expect(updatedPair?.chatgptAccountID == "acct-team")
        #expect(updatedPair?.accessToken == "access-new")
    }

    @Test("Given two snapshots share api key suffix, when recording login snapshot, then exact api key account is updated without drifting into newer file")
    func recordCLILoginSnapshotMatchesExactAPIKeyWithoutSuffixDrift() async throws {
        let root = try makeTempRoot("codex-auth-match-exact-api-key")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let older = try await manager.addAccount(
            name: "older",
            authJSONString: #"{"OPENAI_API_KEY":"sk-alpha-1234"}"#
        )
        let newer = try await manager.addAccount(
            name: "newer",
            authJSONString: #"{"OPENAI_API_KEY":"sk-beta-1234"}"#
        )

        let updated = try await manager.recordCLILoginSnapshot(
            authJSONString: #"{"OPENAI_API_KEY":"sk-alpha-1234"}"#,
            preferredAccountID: nil
        )
        #expect(updated.id == older.id)

        let newerRaw = try await manager.accountAuthFile(newer).read()
        let newerJSON = try #require(try? JSON(data: Data(newerRaw.utf8)))
        #expect(newerJSON["OPENAI_API_KEY"].string == "sk-beta-1234")
    }

    @Test("Given gateway virtual auth payload, when recording CLI login snapshot, then it is rejected to avoid polluting managed account snapshots")
    func recordCLILoginSnapshotRejectsGatewayVirtualPayload() async throws {
        let root = try makeTempRoot("codex-auth-record-gateway-virtual")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let existing = try await manager.addAccount(
            name: "existing",
            authJSONString: #"{"email":"existing@example.com","tokens":{"id_token":"id-old","access_token":"access-old"}}"#
        )
        let existingRawBefore = try await manager.accountAuthFile(existing).read()

        let gatewayVirtualPayload = #"""
        {
          "OPENAI_API_KEY": "nolon-gateway-virtual-api-key",
          "auth_mode": "apikey",
          "nolon": {
            "relay": {
              "base_url": "http://127.0.0.1:8080",
              "model_provider": "openai",
              "query_params": {
                "nolon_gateway_virtual": "1",
                "provider_id": "codex"
              }
            }
          },
          "tokens": null
        }
        """#

        await #expect(throws: CodexAuthManager.CLILoginError.gatewayVirtualAuthPayload) {
            _ = try await manager.recordCLILoginSnapshot(
                authJSONString: gatewayVirtualPayload,
                preferredAccountID: nil
            )
        }

        let accounts = try await manager.loadAccounts()
        #expect(accounts.count == 1)
        let existingRawAfter = try await manager.accountAuthFile(existing).read()
        #expect(existingRawAfter == existingRawBefore)
    }

    @Test("Given virtual api key payload without marker, when recording CLI login snapshot, then it is still rejected")
    func recordCLILoginSnapshotRejectsVirtualAPIKeyWithoutMarker() async throws {
        let root = try makeTempRoot("codex-auth-record-gateway-virtual-key")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let existing = try await manager.addAccount(
            name: "existing",
            authJSONString: #"{"email":"existing@example.com","tokens":{"id_token":"id-old","access_token":"access-old"}}"#
        )
        let existingRawBefore = try await manager.accountAuthFile(existing).read()

        let gatewayVirtualPayload = #"""
        {
          "OPENAI_API_KEY": "nolon-gateway-virtual-api-key",
          "auth_mode": "apikey",
          "tokens": null
        }
        """#

        await #expect(throws: CodexAuthManager.CLILoginError.gatewayVirtualAuthPayload) {
            _ = try await manager.recordCLILoginSnapshot(
                authJSONString: gatewayVirtualPayload,
                preferredAccountID: nil
            )
        }

        let accounts = try await manager.loadAccounts()
        #expect(accounts.count == 1)
        let existingRawAfter = try await manager.accountAuthFile(existing).read()
        #expect(existingRawAfter == existingRawBefore)
    }

    @Test("Given detached provider auth with invalid json and healthy snapshot, when preflight runs then snapshot is kept as source of truth")
    func preflightPrefersHealthySnapshotWhenProviderAuthBroken() async throws {
        let root = try makeTempRoot("codex-auth-preflight-prefer-snapshot")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let snapshot = try await manager.addAccount(
            name: "stable",
            authJSONString: #"{"tokens":{"id_token":"id-stable","access_token":"access-stable"},"email":"stable@example.com"}"#
        )

        let providerRoot = root.folder("provider")
        _ = providerRoot.createIfNotExists()
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: providerRoot.folder("skills").url.path,
            workflowPath: providerRoot.folder("prompts").url.path,
            installMethod: .symlink,
            templateId: "codex"
        )

        try await manager.activateAccountAndMarkActive(snapshot, for: provider)
        let providerAuth = try #require(await manager.authFile(for: provider))
        if providerAuth.isExists || providerAuth.isSymbolicLink {
            try providerAuth.delete()
        }
        try "not-json".write(to: providerAuth.url, atomically: true, encoding: .utf8)

        let affected = try await manager.preflightManagedAuthIfNeeded(for: provider, forceBackup: true, reason: "test")
        #expect(affected?.id == snapshot.id)
        #expect(providerAuth.isSymbolicLink == true)
    }

    @Test("Given snapshot folder contains non-importable files, when loading accounts then those files are pruned")
    func loadAccountsPrunesNonImportableSnapshotFiles() async throws {
        let root = try makeTempRoot("codex-auth-load-prune-non-importable")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let authFolder = manager.nolonCodexAuthFolder()
        _ = authFolder.createIfNotExists()

        let activeFile = authFolder.file("active.json")
        try #"{"email":"active@example.com","nolon":{"account":{"relativeAuthPath":"auth/active.json"}}}"#
            .write(to: activeFile.url, atomically: true, encoding: .utf8)
        let testFile = authFolder.file("test.json")
        try #"{"nolon":{"account":{"relativeAuthPath":"auth/test.json"}}}"#
            .write(to: testFile.url, atomically: true, encoding: .utf8)
        let validFile = authFolder.file("valid.json")
        try #"{"tokens":{"id_token":"id-valid","access_token":"access-valid"},"email":"valid@example.com"}"#
            .write(to: validFile.url, atomically: true, encoding: .utf8)

        let accounts = try await manager.loadAccounts()

        #expect(accounts.count == 1)
        #expect(accounts.first?.relativeAuthPath == "auth/valid.json")
        #expect(activeFile.isExists == false)
        #expect(testFile.isExists == false)
        #expect(validFile.isExists == true)
    }

    @Test("Given active snapshot drifted by external write, when preflight runs then active snapshot is restored and drifted auth is preserved separately")
    func preflightRestoresActiveSnapshotAfterExternalDrift() async throws {
        let root = try makeTempRoot("codex-auth-preflight-drift")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let active = try await manager.addAccount(
            name: "active",
            authJSONString: #"{"tokens":{"id_token":"id-active","access_token":"access-active","account_id":"acct-shared"},"email":"active@example.com"}"#
        )

        let providerRoot = root.folder("provider")
        _ = providerRoot.createIfNotExists()
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: providerRoot.folder("skills").url.path,
            workflowPath: providerRoot.folder("prompts").url.path,
            installMethod: .symlink,
            templateId: "codex"
        )

        try await manager.activateAccountAndMarkActive(active, for: provider)
        _ = try await manager.preflightManagedAuthIfNeeded(for: provider, forceBackup: true, reason: "seed_backup")

        let driftedRaw = #"{"tokens":{"id_token":"id-drift","access_token":"access-drift","account_id":"acct-shared"},"email":"drift@example.com"}"#
        let activeID = try #require(await manager.activeAccountId(for: provider))
        let activeResolved = try #require((try await manager.loadAccounts()).first(where: { $0.id == activeID }))
        let activeFile = await manager.accountAuthFile(activeResolved)
        try activeFile.overlay(with: Data(driftedRaw.utf8))

        _ = try await manager.preflightManagedAuthIfNeeded(for: provider, forceBackup: false, reason: "detect_drift")

        let restoredActiveID = try #require(await manager.activeAccountId(for: provider))
        let restoredActive = try #require((try await manager.loadAccounts()).first(where: { $0.id == restoredActiveID }))
        let restoredSummary = CodexAuthSummary.fromJSONData(try await manager.accountAuthFile(restoredActive).data())
        #expect(restoredSummary.email == "active@example.com")

        let accounts = try await manager.loadAccounts()
        var driftedFound = false
        for account in accounts where account.id != restoredActiveID {
            let file = await manager.accountAuthFile(account)
            let summary = CodexAuthSummary.fromJSONData((try? file.data()) ?? Data())
            if summary.email == "drift@example.com" {
                driftedFound = true
                break
            }
        }
        #expect(driftedFound == true)
    }

    @Test("Given active drift payload shares account id and email with an existing snapshot, when preflight runs then existing same-identity snapshot is overwritten")
    func preflightOverwritesExistingSnapshotWhenDriftIdentityMatchesStrictly() async throws {
        let root = try makeTempRoot("codex-auth-preflight-drift-strict-match")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let active = try await manager.addAccount(
            name: "active",
            authJSONString: #"{"tokens":{"id_token":"id-active","access_token":"access-active","account_id":"acct-shared"},"email":"active@example.com"}"#
        )
        let peer = try await manager.addAccount(
            name: "peer",
            authJSONString: #"{"tokens":{"id_token":"id-peer-old","access_token":"access-peer-old","account_id":"acct-shared"},"email":"peer@example.com"}"#
        )

        let providerRoot = root.folder("provider")
        _ = providerRoot.createIfNotExists()
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: providerRoot.folder("skills").url.path,
            workflowPath: providerRoot.folder("prompts").url.path,
            installMethod: .symlink,
            templateId: "codex"
        )

        try await manager.activateAccountAndMarkActive(active, for: provider)
        _ = try await manager.preflightManagedAuthIfNeeded(for: provider, forceBackup: true, reason: "seed_backup")

        let driftedRaw = #"""
        {
          "tokens": {
            "id_token": "id-peer-new",
            "access_token": "access-peer-new",
            "account_id": "acct-shared"
          },
          "email": "peer@example.com",
          "nolon": {
            "account": {
              "id": "\#(active.id.uuidString)"
            }
          }
        }
        """#
        let activeID = try #require(await manager.activeAccountId(for: provider))
        let activeResolved = try #require((try await manager.loadAccounts()).first(where: { $0.id == activeID }))
        let activeFile = await manager.accountAuthFile(activeResolved)
        try activeFile.overlay(with: Data(driftedRaw.utf8))

        _ = try await manager.preflightManagedAuthIfNeeded(for: provider, forceBackup: false, reason: "detect_drift")

        let accounts = try await manager.loadAccounts()
        #expect(accounts.count == 2)

        let peerAfter = try #require(accounts.first(where: { $0.id == peer.id }))
        let peerPair = try await manager.readTokenPair(for: peerAfter)
        #expect(peerPair?.idToken == "id-peer-new")
        #expect(peerPair?.accessToken == "access-peer-new")

        let restoredActiveID = try #require(await manager.activeAccountId(for: provider))
        let restoredActive = try #require(accounts.first(where: { $0.id == restoredActiveID }))
        let restoredSummary = CodexAuthSummary.fromJSONData(try await manager.accountAuthFile(restoredActive).data())
        #expect(restoredSummary.email == "active@example.com")
    }

    @Test("Given active drift payload shares account id but has different email from existing snapshots, when preflight runs then drift payload is saved as a new snapshot")
    func preflightCreatesNewSnapshotWhenDriftEmailDiffersUnderSameAccountID() async throws {
        let root = try makeTempRoot("codex-auth-preflight-drift-email-diff")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let active = try await manager.addAccount(
            name: "active",
            authJSONString: #"{"tokens":{"id_token":"id-active","access_token":"access-active","account_id":"acct-shared"},"email":"active@example.com"}"#
        )
        let peer = try await manager.addAccount(
            name: "peer",
            authJSONString: #"{"tokens":{"id_token":"id-peer-old","access_token":"access-peer-old","account_id":"acct-shared"},"email":"peer@example.com"}"#
        )

        let providerRoot = root.folder("provider")
        _ = providerRoot.createIfNotExists()
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: providerRoot.folder("skills").url.path,
            workflowPath: providerRoot.folder("prompts").url.path,
            installMethod: .symlink,
            templateId: "codex"
        )

        try await manager.activateAccountAndMarkActive(active, for: provider)
        _ = try await manager.preflightManagedAuthIfNeeded(for: provider, forceBackup: true, reason: "seed_backup")

        let driftedRaw = #"""
        {
          "tokens": {
            "id_token": "id-drift-new",
            "access_token": "access-drift-new",
            "account_id": "acct-shared"
          },
          "email": "newcomer@example.com",
          "nolon": {
            "account": {
              "id": "\#(active.id.uuidString)"
            }
          }
        }
        """#
        let activeID = try #require(await manager.activeAccountId(for: provider))
        let activeResolved = try #require((try await manager.loadAccounts()).first(where: { $0.id == activeID }))
        let activeFile = await manager.accountAuthFile(activeResolved)
        try activeFile.overlay(with: Data(driftedRaw.utf8))

        _ = try await manager.preflightManagedAuthIfNeeded(for: provider, forceBackup: false, reason: "detect_drift")

        let accounts = try await manager.loadAccounts()
        #expect(accounts.count == 3)

        let peerAfter = try #require(accounts.first(where: { $0.id == peer.id }))
        let peerPair = try await manager.readTokenPair(for: peerAfter)
        #expect(peerPair?.idToken == "id-peer-old")
        #expect(peerPair?.accessToken == "access-peer-old")

        var newcomerCount = 0
        for account in accounts {
            guard let data = try? await manager.accountAuthFile(account).data() else { continue }
            let summary = CodexAuthSummary.fromJSONData(data)
            if summary.email == "newcomer@example.com" {
                newcomerCount += 1
            }
        }
        #expect(newcomerCount == 1)
    }

    @Test("Given gateway virtual account is active, when preflight runs then it must not be restored back to normal snapshot")
    func preflightKeepsGatewayVirtualAccountActive() async throws {
        let root = try makeTempRoot("codex-auth-preflight-gateway-virtual")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let normal = try await manager.addAccount(
            name: "normal",
            authJSONString: #"{"tokens":{"id_token":"id-normal","access_token":"access-normal"},"email":"normal@example.com"}"#
        )

        let providerRoot = root.folder("provider")
        _ = providerRoot.createIfNotExists()
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: providerRoot.folder("skills").url.path,
            workflowPath: providerRoot.folder("prompts").url.path,
            installMethod: .symlink,
            templateId: "codex"
        )

        try await manager.activateAccountAndMarkActive(normal, for: provider)
        _ = try await manager.preflightManagedAuthIfNeeded(for: provider, forceBackup: true, reason: "seed_backup")

        let virtual = try await manager.upsertGatewayVirtualAccount(
            providerID: "codex",
            name: "__gateway_reply__-codex",
            apiKey: "nolon-gateway-virtual-api-key",
            relay: .init(
                baseURL: "http://127.0.0.1:18080",
                modelProvider: "openai",
                queryParams: [
                    "nolon_gateway_virtual": "1",
                    "provider_id": "codex",
                ]
            )
        )
        try await manager.activateAccountAndMarkActive(virtual, for: provider)

        _ = try await manager.preflightManagedAuthIfNeeded(for: provider, forceBackup: false, reason: "gateway_virtual_reload")

        let activeID = try #require(await manager.activeAccountId(for: provider))
        #expect(activeID == virtual.id)
        let authFile = try #require(await manager.authFile(for: provider))
        let destination = try authFile.destinationOfSymbolicLink()
        let virtualFile = await manager.accountAuthFile(virtual)
        #expect(STPath.standardizedPath(destination.url.path).path == STPath.standardizedPath(virtualFile.url.path).path)
    }

    @Test("Given gateway was activated via canonical codex provider, when custom codex provider preflight runs then auth symlink remains gateway virtual")
    func preflightKeepsGatewayVirtualWhenProviderIDDiffers() async throws {
        let root = try makeTempRoot("codex-auth-preflight-gateway-provider-id-mismatch")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let normal = try await manager.addAccount(
            name: "normal",
            authJSONString: #"{"tokens":{"id_token":"id-normal","access_token":"access-normal"},"email":"normal@example.com"}"#
        )

        let providerRoot = root.folder("provider")
        _ = providerRoot.createIfNotExists()
        let customProvider = Provider(
            id: "D3B087EE-4BBF-495E-BAC6-8FDEFB5B88B0",
            name: "Codex Custom",
            defaultSkillsPath: providerRoot.folder("skills").url.path,
            workflowPath: providerRoot.folder("prompts").url.path,
            installMethod: .symlink,
            templateId: "codex"
        )
        let canonicalProvider = Provider(
            id: "codex",
            name: "Codex",
            defaultSkillsPath: providerRoot.folder("skills").url.path,
            workflowPath: providerRoot.folder("prompts").url.path,
            installMethod: .symlink,
            templateId: "codex"
        )

        try await manager.activateAccountAndMarkActive(normal, for: customProvider)
        _ = try await manager.preflightManagedAuthIfNeeded(for: customProvider, forceBackup: true, reason: "seed_custom_backup")

        let virtual = try await manager.upsertGatewayVirtualAccount(
            providerID: "codex",
            name: "__gateway_reply__-codex",
            apiKey: "nolon-gateway-virtual-api-key",
            relay: .init(
                baseURL: "http://127.0.0.1:18081",
                modelProvider: "openai",
                queryParams: [
                    "nolon_gateway_virtual": "1",
                    "provider_id": "codex",
                ]
            )
        )
        try await manager.activateAccountAndMarkActive(virtual, for: canonicalProvider)

        _ = try await manager.preflightManagedAuthIfNeeded(for: customProvider, forceBackup: false, reason: "gateway_custom_reload")

        let authFile = try #require(await manager.authFile(for: customProvider))
        let destination = try authFile.destinationOfSymbolicLink()
        let virtualFile = await manager.accountAuthFile(virtual)
        let activeID = await manager.activeAccountId(for: customProvider)

        #expect(STPath.standardizedPath(destination.url.path).path == STPath.standardizedPath(virtualFile.url.path).path)
        #expect(activeID == virtual.id)
    }

    @Test("Given duplicate snapshot ids and wrong relative path metadata, when loading accounts then id collision is healed and relative path is corrected")
    func loadAccountsHealsDuplicateIDsAndWrongRelativePath() async throws {
        let root = try makeTempRoot("codex-auth-heal-duplicate-id")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let canonical = try await manager.addAccount(
            name: "linhan",
            authJSONString: #"{"tokens":{"id_token":"id-1","access_token":"access-1"},"email":"canonical@example.com"}"#
        )
        let duplicate = try await manager.addAccount(
            name: "robbins",
            authJSONString: #"{"tokens":{"id_token":"id-2","access_token":"access-2"},"email":"duplicate@example.com"}"#
        )

        let canonicalFile = await manager.accountAuthFile(canonical)
        let duplicateFile = await manager.accountAuthFile(duplicate)
        let canonicalRaw = try canonicalFile.read()
        let polluted = canonicalRaw
            .replacingOccurrences(of: "canonical@example.com", with: "duplicate@example.com")
            .replacingOccurrences(of: "\"id-1\"", with: "\"id-2\"")
            .replacingOccurrences(of: "\"access-1\"", with: "\"access-2\"")
        try duplicateFile.overlay(with: Data(polluted.utf8))

        let accounts = try await manager.loadAccounts()
        #expect(accounts.count == 2)

        var accountByEmail: [String: CodexAuthAccount] = [:]
        for account in accounts {
            let summary = CodexAuthSummary.fromJSONData((try? await manager.accountAuthFile(account).data()) ?? Data())
            if let email = summary.email?.lowercased() {
                accountByEmail[email] = account
            }
        }

        let canonicalAfter = try #require(accountByEmail["canonical@example.com"])
        let duplicateAfter = try #require(accountByEmail["duplicate@example.com"])
        #expect(canonicalAfter.id == canonical.id)
        #expect(duplicateAfter.id != canonical.id)

        let duplicateAfterFile = await manager.accountAuthFile(duplicateAfter)
        let duplicateJSON = try #require(try? JSON(data: duplicateAfterFile.data()))
        #expect(duplicateJSON["nolon"]["account"]["relativeAuthPath"].string == duplicateAfter.relativeAuthPath)
        #expect(duplicateJSON["nolon"]["account"]["id"].string == duplicateAfter.id.uuidString)
    }

    @Test("Given duplicated snapshot payload in another file, when loading accounts then duplicate file is pruned")
    func loadAccountsPrunesDuplicatedSnapshotPayloadFile() async throws {
        let root = try makeTempRoot("codex-auth-prune-duplicate-payload")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let canonical = try await manager.addAccount(
            name: "linhan",
            authJSONString: #"{"tokens":{"id_token":"id-1","access_token":"access-1"},"email":"canonical@example.com"}"#
        )
        let duplicate = try await manager.addAccount(
            name: "robbins",
            authJSONString: #"{"tokens":{"id_token":"id-2","access_token":"access-2"},"email":"duplicate@example.com"}"#
        )

        let canonicalFile = await manager.accountAuthFile(canonical)
        let duplicateFile = await manager.accountAuthFile(duplicate)
        try duplicateFile.overlay(with: Data(try canonicalFile.read().utf8))

        let accounts = try await manager.loadAccounts()
        #expect(accounts.count == 1)
        let kept = try #require(accounts.first)
        let keptSummary = CodexAuthSummary.fromJSONData((try? await manager.accountAuthFile(kept).data()) ?? Data())
        #expect(keptSummary.email?.lowercased() == "canonical@example.com")
        #expect(duplicateFile.isExists == false)
    }

    @Test("Given snapshot file name mismatched with email(account_id), when loading accounts then snapshot file is renamed to match email(account_id)")
    func loadAccountsAlignsSnapshotFileNameWithEmailAndAccountID() async throws {
        let root = try makeTempRoot("codex-auth-align-file-name")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let account = try await manager.addAccount(
            name: "placeholder@example.com",
            authJSONString: #"{"email":"canonical@example.com","tokens":{"account_id":"acct-123","id_token":"id-1","access_token":"access-1"}}"#
        )

        let oldPath = account.relativeAuthPath
        let oldFile = await manager.accountAuthFile(account)
        #expect(oldFile.isExists == true)

        let accounts = try await manager.loadAccounts()
        let aligned = try #require(accounts.first(where: { $0.id == account.id }))
        #expect(aligned.relativeAuthPath == "auth/canonical@example.com(acct-123).json")

        let newFile = await manager.accountAuthFile(aligned)
        #expect(newFile.isExists == true)
        #expect(oldFile.isExists == false)

        let json = try #require(try? JSON(data: newFile.data()))
        #expect(json["nolon"]["account"]["relativeAuthPath"].string == aligned.relativeAuthPath)
        #expect((json["email"].string ?? "").lowercased() == "canonical@example.com")
        #expect(oldPath != aligned.relativeAuthPath)
    }

    @Test("Given snapshot missing email and using account.json, when backfilling email then load accounts aligns file name to email(account_id)")
    func backfillEmailEnablesEmailAccountIDAlignment() async throws {
        let root = try makeTempRoot("codex-auth-backfill-email-align")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let account = try await manager.addAccount(
            name: "account",
            authJSONString: #"{"tokens":{"account_id":"acct-raw","id_token":"id-raw","access_token":"access-raw"}}"#
        )
        #expect(account.relativeAuthPath == "auth/account.json")

        try await manager.backfillEmailIfMissing(for: account, email: "fresh@example.com")

        let accounts = try await manager.loadAccounts()
        let aligned = try #require(accounts.first(where: { $0.id == account.id }))
        #expect(aligned.relativeAuthPath == "auth/fresh@example.com(acct-raw).json")

        let alignedFile = await manager.accountAuthFile(aligned)
        let json = try #require(try? JSON(data: alignedFile.data()))
        #expect((json["email"].string ?? "").lowercased() == "fresh@example.com")
        #expect((json["nolon"]["account"]["email"].string ?? "").lowercased() == "fresh@example.com")
    }

    @Test("Given selected validated import candidates, when exporting zip, then only selected valid candidates are archived")
    func exportSelectedValidatedImportCandidatesAsZip() async throws {
        let root = try makeTempRoot("codex-import-export-zip")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let selectedURL = root.url.appendingPathComponent("selected.json")
        let unselectedURL = root.url.appendingPathComponent("unselected.json")
        let invalidURL = root.url.appendingPathComponent("invalid.json")

        let selected = CodexAuthManager.CodexImportValidationResult(
            fileURL: selectedURL,
            isValid: true,
            reason: nil,
            suggestedName: "Selected",
            email: "selected@example.com",
            authJSONString: #"{"auth_mode":"chatgptAuthTokens","email":"selected@example.com","tokens":{"id_token":"id-selected","access_token":"access-selected"}}"#
        )
        let unselected = CodexAuthManager.CodexImportValidationResult(
            fileURL: unselectedURL,
            isValid: true,
            reason: nil,
            suggestedName: "Unselected",
            email: "unselected@example.com",
            authJSONString: #"{"auth_mode":"chatgptAuthTokens","email":"unselected@example.com","tokens":{"id_token":"id-unselected","access_token":"access-unselected"}}"#
        )
        let invalid = CodexAuthManager.CodexImportValidationResult(
            fileURL: invalidURL,
            isValid: false,
            reason: "Missing required credentials",
            suggestedName: nil,
            email: nil,
            authJSONString: nil
        )

        let destinationURL = root.url.appendingPathComponent("selected-imports.zip")
        let exportedCount = try await manager.exportValidatedAuthFilesArchive(
            results: [selected, invalid],
            destinationURL: destinationURL
        )
        let roundTripped = await manager.validateImportAuthFiles(urls: [destinationURL])

        #expect(exportedCount == 1)
        #expect(roundTripped.count == 1)
        #expect(roundTripped[0].isValid == true)
        #expect(roundTripped[0].email == "selected@example.com")
        #expect(roundTripped[0].fileURL.lastPathComponent.contains("selected"))
        #expect(roundTripped.allSatisfy { $0.email != unselected.email })
    }

}
