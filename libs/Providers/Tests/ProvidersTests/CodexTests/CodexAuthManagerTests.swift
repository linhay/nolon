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
}
