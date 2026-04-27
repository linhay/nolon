import Foundation
import Testing
import ProviderCatalog
import CodexProvider
import STFilePath
import STJSON
import SQLite3
@testable import ProviderUsage

@Suite("CodexAuthManager")
struct CodexAuthManagerTests {
    func makeTempRoot(_ prefix: String) throws -> STFolder {
        let root = STFolder("/tmp").folder("\(prefix)-\(UUID().uuidString)")
        _ = root.createIfNotExists()
        return root
    }

    func makeCodexProvider(
        root: STFolder,
        id: String = "codex",
        templateID: String = "codex"
    ) -> Provider {
        let providerRoot = root.folder("provider")
        _ = providerRoot.createIfNotExists()
        return Provider(
            id: id,
            name: "Codex",
            defaultSkillsPath: providerRoot.folder("skills").url.path,
            workflowPath: providerRoot.folder("prompts").url.path,
            installMethod: .symlink,
            templateId: templateID
        )
    }

    static func makeJWT(payload: String) -> String {
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

    func sqliteCount(databaseURL: URL, sql: String, bind: String) throws -> Int {
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

    func sqliteCount(databaseURL: URL, sql: String) throws -> Int {
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

    func sqliteString(databaseURL: URL, sql: String, bind: String) throws -> String? {
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

    func sqliteExecute(databaseURL: URL, sql: String, bindings: [String] = []) throws {
        var db: OpaquePointer?
        guard sqlite3_open_v2(
            databaseURL.path,
            &db,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX,
            nil
        ) == SQLITE_OK else {
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

    func writeRolloutSessionMeta(
        codexHome: STFolder,
        threadID: String,
        modelProvider: String,
        archived: Bool = false,
        timestamp: String = "2026-04-10T10-00-00"
    ) throws -> STFile {
        let rootFolder = archived ? codexHome.folder("archived_sessions") : codexHome.folder("sessions")
        let dayFolder = rootFolder.folder("2026").folder("04").folder("10")
        _ = dayFolder.createIfNotExists()

        let file = dayFolder.file("rollout-\(timestamp)-\(threadID).jsonl")
        let sessionMeta = """
        {"timestamp":"2026-04-10T10:00:00Z","type":"session_meta","payload":{"id":"\(threadID)","timestamp":"2026-04-10T10:00:00Z","cwd":"/tmp/project","source":"cli","model_provider":"\(modelProvider)"}}
        """
        let userEvent = """
        {"timestamp":"2026-04-10T10:00:01Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"hello"}]}}
        """
        try file.overlay(with: sessionMeta + "\n" + userEvent + "\n")
        return file
    }

    func rolloutSessionMetaProvider(file: STFile) throws -> String? {
        let content = try file.read()
        for rawLine in content.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty,
                  let data = line.data(using: .utf8),
                  let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  (object["type"] as? String) == "session_meta",
                  let payload = object["payload"] as? [String: Any]
            else {
                continue
            }
            return payload["model_provider"] as? String
        }
        return nil
    }

    func createCodexStateDatabase(
        codexHome: STFolder,
        threads: [(id: String, rolloutPath: String, modelProvider: String, archived: Bool)]
    ) throws -> URL {
        _ = codexHome.createIfNotExists()
        let databaseURL = codexHome.file("state_4.sqlite").url
        try sqliteExecute(
            databaseURL: databaseURL,
            sql: """
            CREATE TABLE threads (
                id TEXT PRIMARY KEY,
                rollout_path TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL,
                source TEXT NOT NULL,
                model_provider TEXT NOT NULL,
                cwd TEXT NOT NULL,
                title TEXT NOT NULL,
                sandbox_policy TEXT NOT NULL,
                approval_mode TEXT NOT NULL,
                tokens_used INTEGER NOT NULL DEFAULT 0,
                has_user_event INTEGER NOT NULL DEFAULT 0,
                archived INTEGER NOT NULL DEFAULT 0,
                archived_at INTEGER,
                git_sha TEXT,
                git_branch TEXT,
                git_origin_url TEXT
            );
            """
        )

        for thread in threads {
            try sqliteExecute(
                databaseURL: databaseURL,
                sql: """
                INSERT INTO threads (
                    id, rollout_path, created_at, updated_at, source, model_provider, cwd, title,
                    sandbox_policy, approval_mode, tokens_used, has_user_event, archived
                ) VALUES (?, ?, 1712743200, 1712743200, 'cli', ?, '/tmp/project', 'Existing thread',
                          'workspace-write', 'on-request', 0, 1, ?);
                """,
                bindings: [
                    thread.id,
                    thread.rolloutPath,
                    thread.modelProvider,
                    thread.archived ? "1" : "0",
                ]
            )
        }

        return databaseURL
    }

    func accountAuthDataFromSQLite(
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

    @Test("Given sqlite-backed metadata fields, when materializing account auth, then auth json keeps only runtime-required fields")
    func accountAuthMaterializationOmitsSQLiteManagedMetadata() async throws {
        let root = try makeTempRoot("codex-auth-minimal-materialization")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let account = try await manager.addAccount(
            name: "minimal",
            authJSONString: #"""
            {
              "auth_mode": "chatgpt",
              "tokens": {
                "id_token": "id-token",
                "access_token": "access-token"
              },
              "email": "minimal@example.com",
              "nolon": {
                "account": {
                  "id": "11111111-1111-1111-1111-111111111111",
                  "kind": "chatgptAccount",
                  "relativeAuthPath": "auth/minimal.json",
                  "email": "minimal@example.com"
                },
                "custom_group_name": "Work",
                "usage_cache": {
                  "fetch_kind": "api"
                },
                "usage_query": {
                  "enabled": true,
                  "request": {
                    "method": "GET",
                    "url": "https://api.example.com/usage"
                  }
                }
              }
            }
            """#
        )

        let materializedData = try #require(manager.accountAuthData(for: account))
        let json = try #require(try? JSON(data: materializedData))

        #expect(json["auth_mode"].string == "chatgpt")
        #expect(json["email"].string == "minimal@example.com")
        #expect(json["nolon"]["account"] == JSON.null)
        #expect(json["nolon"]["custom_group_name"] == JSON.null)
        #expect(json["nolon"]["usage_cache"] == JSON.null)
        #expect(json["nolon"]["usage_query"]["enabled"].boolValue == true)
        #expect(json["nolon"]["usage_query"]["request"]["url"].string == "https://api.example.com/usage")

        let storedData = try #require(manager.accountAuthDataWithoutMaterialization(for: account))
        let storedJSON = try #require(try? JSON(data: storedData))
        #expect(storedJSON["nolon"]["account"]["id"].string == account.id.uuidString)
        #expect(storedJSON["nolon"]["account"]["kind"].string == "chatgptAccount")
        #expect(storedJSON["nolon"]["custom_group_name"].string == "Work")
        #expect(storedJSON["nolon"]["usage_cache"]["fetch_kind"].string == "api")
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
        let providerAuth = try #require(await manager.authFile(for: provider))
        let activeFile = STFile(try providerAuth.destinationOfSymbolicLink().url.path)
        try activeFile.overlay(with: Data(driftedRaw.utf8))

        _ = try await manager.preflightManagedAuthIfNeeded(
            for: provider,
            forceBackup: false,
            reason: "post_activate_detect_drift"
        )

        let restoredActiveID = try #require(await manager.activeAccountId(for: provider))
        let restoredActive = try #require((try await manager.loadAccounts()).first(where: { $0.id == restoredActiveID }))
        let restoredSummary = CodexAuthSummary.fromJSONData(try #require(manager.accountAuthData(for: restoredActive)))
        #expect(restoredSummary.email == "active@example.com")

        let accounts = try await manager.loadAccounts()
        var driftedFound = false
        for account in accounts where account.id != restoredActiveID {
            let summary = CodexAuthSummary.fromJSONData(manager.accountAuthData(for: account) ?? Data())
            if summary.email == "drift-after-activate@example.com" {
                driftedFound = true
                break
            }
        }
        #expect(driftedFound == true)
    }

    @Test("Given relay profile activation followed by oauth activation, when account switching syncs auth, then config.toml patches to relay provider and restores original config")
    func relayActivationPatchesConfigAndOAuthActivationRestoresOriginalConfig() async throws {
        let root = try makeTempRoot("codex-auth-relay-config-switch")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let provider = makeCodexProvider(root: root)
        let configFile = root.folder("provider").file("config.toml")
        let originalConfig = """
        model = "o3"
        approval_policy = "on-request"

        [features]
        web_search = true
        """
        try configFile.overlay(with: originalConfig + "\n")

        let relay = try await manager.addConfiguredAccount(
            name: "Relay",
            apiKey: "rk-live-12345678",
            relay: .init(
                baseURL: "https://relay.example.com/v1",
                modelProvider: "provider-relay",
                queryParams: ["api-version": "2025-01-01-preview"],
                headers: ["X-Workspace": "ios"]
            )
        )
        let oauth = try await manager.addAccount(
            name: "oauth",
            authJSONString: #"{"auth_mode":"chatgpt","tokens":{"id_token":"id-oauth","access_token":"access-oauth"},"email":"oauth@example.com"}"#
        )

        try await manager.activateAccountAndMarkActive(relay, for: provider)

        let patched = try configFile.read()
        #expect(patched.contains(#"model = "gpt-5.4""#))
        #expect(patched.contains(#"model_reasoning_effort = "xhigh""#))
        #expect(patched.contains(#"model_provider = "provider-relay""#))
        #expect(patched.contains(#"[model_providers.provider-relay]"#))
        #expect(patched.contains(#"name = "provider-relay""#))
        #expect(patched.contains(#"base_url = "https://relay.example.com/v1""#))
        #expect(patched.contains(#"wire_api = "responses""#))
        #expect(patched.contains(#"requires_openai_auth = true"#))
        #expect(patched.contains(#"query_params = { "api-version" = "2025-01-01-preview" }"#))
        #expect(patched.contains(#"http_headers = { "X-Workspace" = "ios" }"#))

        try await manager.activateAccountAndMarkActive(oauth, for: provider)

        let restored = try configFile.read()
        #expect(restored == originalConfig + "\n")
    }

    @Test("Given relay config is active and app later updates config.toml, when switching back to oauth, then later app-owned config fragments are preserved")
    func oauthRestorePreservesConfigFragmentsWrittenWhileRelayWasActive() async throws {
        let root = try makeTempRoot("codex-auth-relay-config-preserve-later-app-writes")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let provider = makeCodexProvider(root: root)
        let configFile = root.folder("provider").file("config.toml")
        let originalConfig = """
        approval_policy = "on-request"

        [features]
        web_search = true
        """
        try configFile.overlay(with: originalConfig + "\n")

        let relay = try await manager.addConfiguredAccount(
            name: "Relay",
            apiKey: "rk-live-12345678",
            relay: .init(
                baseURL: "https://relay.example.com/v1",
                modelProvider: "provider-relay"
            )
        )
        let oauth = try await manager.addAccount(
            name: "oauth",
            authJSONString: #"{"auth_mode":"chatgpt","tokens":{"id_token":"id-oauth","access_token":"access-oauth"},"email":"oauth@example.com"}"#
        )

        try await manager.activateAccountAndMarkActive(relay, for: provider)

        _ = try CodexConfigStore(file: configFile).update { current in
            let rendered = """
            [mcp_servers.context7]
            command = "node"
            """
            return current + (current.hasSuffix("\n") ? "" : "\n") + rendered + "\n"
        }

        try await manager.activateAccountAndMarkActive(oauth, for: provider)

        let restored = try configFile.read()
        #expect(restored.contains(#"approval_policy = "on-request""#))
        #expect(restored.contains(#"[features]"#))
        #expect(restored.contains(#"[mcp_servers.context7]"#))
        #expect(restored.contains(#"command = "node""#))
        #expect(restored.contains(#"[model_providers.provider-relay]"#) == false)
        #expect(restored.contains(#"model_provider = "provider-relay""#) == false)
    }

    @Test("Given active oauth with stale managed relay config and missing state, when refreshing active provider config, then config.toml self-heals by removing managed relay patch")
    func refreshActiveProviderConfigRestoresPatchedConfigWhenManagedStateIsMissing() async throws {
        let root = try makeTempRoot("codex-auth-preflight-missing-managed-state")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let provider = makeCodexProvider(root: root)
        let configFile = root.folder("provider").file("config.toml")
        let originalConfig = """
        approval_policy = "on-request"

        [features]
        web_search = true
        """
        try configFile.overlay(with: originalConfig + "\n")

        let relay = try await manager.addConfiguredAccount(
            name: "Relay",
            apiKey: "rk-live-12345678",
            relay: .init(
                baseURL: "https://relay.example.com/v1",
                modelProvider: "provider-relay"
            )
        )
        let oauth = try await manager.addAccount(
            name: "oauth",
            authJSONString: #"{"auth_mode":"chatgpt","tokens":{"id_token":"id-oauth","access_token":"access-oauth"},"email":"oauth@example.com"}"#
        )

        try await manager.activateAccountAndMarkActive(relay, for: provider)

        let stateFile = manager
            .nolonCodexRootFolder()
            .folder("active-provider-config")
            .file("config.json")
        _ = stateFile.parentFolder()?.createIfNotExists()
        try stateFile.overlay(with: "{}\n")

        try await manager.setActiveAccount(oauth, for: provider)

        try await manager.refreshActiveProviderConfigIfNeeded(for: oauth, provider: provider)

        let restored = try configFile.read()
        #expect(restored == originalConfig + "\n")
    }

    @Test("Given managed relay config loses restore state, when switching to another relay and back to oauth, then original config is preserved")
    func relayActivationRecoversBaselineWhenManagedStateIsMissing() async throws {
        let root = try makeTempRoot("codex-auth-recover-missing-managed-state")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let provider = makeCodexProvider(root: root)
        let configFile = root.folder("provider").file("config.toml")
        let originalConfig = """
        approval_policy = "on-request"

        [features]
        web_search = true
        """
        try configFile.overlay(with: originalConfig + "\n")

        let relayOne = try await manager.addConfiguredAccount(
            name: "Relay One",
            apiKey: "rk-live-11111111",
            relay: .init(
                baseURL: "https://relay-one.example.com/v1",
                modelProvider: "provider-one"
            )
        )
        let relayTwo = try await manager.addConfiguredAccount(
            name: "Relay Two",
            apiKey: "rk-live-22222222",
            relay: .init(
                baseURL: "https://relay-two.example.com/v1",
                modelProvider: "provider-two"
            )
        )
        let oauth = try await manager.addAccount(
            name: "oauth",
            authJSONString: #"{"auth_mode":"chatgpt","tokens":{"id_token":"id-oauth","access_token":"access-oauth"},"email":"oauth@example.com"}"#
        )

        try await manager.activateAccountAndMarkActive(relayOne, for: provider)

        let stateFile = manager
            .nolonCodexRootFolder()
            .folder("active-provider-config")
            .file("config.json")
        _ = stateFile.parentFolder()?.createIfNotExists()
        try stateFile.overlay(with: "{}\n")

        try await manager.activateAccountAndMarkActive(relayTwo, for: provider)

        let repatched = try configFile.read()
        #expect(repatched.contains(#"model_provider = "provider-two""#))
        #expect(repatched.contains(#"[model_providers.provider-two]"#))
        #expect(repatched.contains(#"[model_providers.provider-one]"#) == false)

        try await manager.activateAccountAndMarkActive(oauth, for: provider)

        let restored = try configFile.read()
        #expect(restored == originalConfig + "\n")
    }

    @Test("Given active relay profile is updated, when refreshing active provider config, then config.toml rewrites managed relay fields")
    func refreshActiveRelayConfigUpdatesManagedProviderSection() async throws {
        let root = try makeTempRoot("codex-auth-refresh-active-relay")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let provider = makeCodexProvider(root: root)
        let configFile = root.folder("provider").file("config.toml")
        try configFile.overlay(with: "approval_policy = \"on-request\"\n")

        let relay = try await manager.addConfiguredAccount(
            name: "Relay One",
            apiKey: "rk-live-12345678",
            relay: .init(
                baseURL: "https://relay-one.example.com/v1",
                modelProvider: "provider-one",
                queryParams: ["api-version": "2025-01-01-preview"],
                headers: ["X-Workspace": "ios"]
            )
        )
        try await manager.activateAccountAndMarkActive(relay, for: provider)

        try await manager.updateConfiguredAccount(
            relay,
            name: "Relay Two",
            apiKey: "rk-live-87654321",
            relay: .init(
                baseURL: "https://relay-two.example.com/v1",
                modelProvider: "provider-two",
                queryParams: ["api-version": "2025-04-01-preview"],
                headers: ["X-Workspace": "mac"]
            )
        )
        let refreshed = try #require((try await manager.loadAccounts()).first(where: { $0.id == relay.id }))

        try await manager.refreshActiveProviderConfigIfNeeded(for: refreshed, provider: provider)

        let rewritten = try configFile.read()
        #expect(rewritten.contains(#"model_provider = "provider-two""#))
        #expect(rewritten.contains(#"[model_providers.provider-two]"#))
        #expect(rewritten.contains(#"base_url = "https://relay-two.example.com/v1""#))
        #expect(rewritten.contains(#"query_params = { "api-version" = "2025-04-01-preview" }"#))
        #expect(rewritten.contains(#"http_headers = { "X-Workspace" = "mac" }"#))
        #expect(rewritten.contains(#"[model_providers.provider-one]"#) == false)
    }

    @Test("Given active configured relay account is edited, when refreshing active provider config, then provider auth json is rematerialized with latest payload")
    func refreshActiveRelayConfigRematerializesProviderAuthJSON() async throws {
        let root = try makeTempRoot("codex-auth-refresh-active-relay-auth-json")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let provider = makeCodexProvider(root: root)
        let configFile = root.folder("provider").file("config.toml")
        try configFile.overlay(with: "approval_policy = \"on-request\"\n")

        let relay = try await manager.addConfiguredAccount(
            name: "Relay One",
            apiKey: "rk-live-12345678",
            relay: .init(
                baseURL: "https://relay-one.example.com/v1",
                modelProvider: "provider-one",
                queryParams: ["api-version": "2025-01-01-preview"],
                headers: ["X-Workspace": "ios"]
            )
        )
        try await manager.activateAccountAndMarkActive(relay, for: provider)

        try await manager.updateConfiguredAccount(
            relay,
            name: "Relay Two",
            apiKey: "rk-live-87654321",
            relay: .init(
                baseURL: "https://relay-two.example.com/v1",
                modelProvider: "provider-two",
                queryParams: ["api-version": "2025-04-01-preview"],
                headers: ["X-Workspace": "mac"]
            )
        )
        let refreshed = try #require((try await manager.loadAccounts()).first(where: { $0.id == relay.id }))

        try await manager.refreshActiveProviderConfigIfNeeded(for: refreshed, provider: provider)

        let providerAuth = try #require(await manager.authFile(for: provider))
        #expect(providerAuth.isSymbolicLink == true)

        let syncedRaw = try #require(await manager.readAuthJSONString(from: provider))
        let syncedJSON = try #require(try? JSON(data: Data(syncedRaw.utf8)))
        let syncedSummary = CodexAuthSummary.fromJSONString(syncedRaw)

        #expect(syncedJSON["OPENAI_API_KEY"].string == "rk-live-87654321")
        #expect(syncedSummary.relayBaseURL == "https://relay-two.example.com/v1")
        #expect(syncedSummary.relayModelProvider == "provider-two")
    }

    @Test("Given openai history exists, when relay activation and oauth restoration switch active provider, then rollout files and state db migrate with the visible provider")
    func relayActivationMigratesHistoryProviderMetadataAndOAuthRestoresIt() async throws {
        let root = try makeTempRoot("codex-auth-history-provider-migration")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let provider = makeCodexProvider(root: root)
        let codexHome = root.folder("provider")
        let configFile = codexHome.file("config.toml")
        let originalConfig = """
        model = "o3"
        approval_policy = "on-request"
        """
        try configFile.overlay(with: originalConfig + "\n")

        let liveThreadID = UUID().uuidString.lowercased()
        let archivedThreadID = UUID().uuidString.lowercased()
        let liveRollout = try writeRolloutSessionMeta(
            codexHome: codexHome,
            threadID: liveThreadID,
            modelProvider: "openai",
            archived: false,
            timestamp: "2026-04-10T10-00-00"
        )
        let archivedRollout = try writeRolloutSessionMeta(
            codexHome: codexHome,
            threadID: archivedThreadID,
            modelProvider: "openai",
            archived: true,
            timestamp: "2026-04-10T09-00-00"
        )
        let stateDBURL = try createCodexStateDatabase(
            codexHome: codexHome,
            threads: [
                (id: liveThreadID, rolloutPath: "sessions/2026/04/10/\(liveRollout.attributes.name)", modelProvider: "openai", archived: false),
                (id: archivedThreadID, rolloutPath: "archived_sessions/2026/04/10/\(archivedRollout.attributes.name)", modelProvider: "openai", archived: true),
            ]
        )

        let relay = try await manager.addConfiguredAccount(
            name: "Relay",
            apiKey: "rk-live-12345678",
            relay: .init(
                baseURL: "https://relay.example.com/v1",
                modelProvider: "provider-relay",
                queryParams: ["api-version": "2025-01-01-preview"],
                headers: ["X-Workspace": "ios"]
            )
        )
        let oauth = try await manager.addAccount(
            name: "oauth",
            authJSONString: #"{"auth_mode":"chatgpt","tokens":{"id_token":"id-oauth","access_token":"access-oauth"},"email":"oauth@example.com"}"#
        )

        try await manager.activateAccountAndMarkActive(relay, for: provider)

        #expect(try rolloutSessionMetaProvider(file: liveRollout) == "provider-relay")
        #expect(try rolloutSessionMetaProvider(file: archivedRollout) == "provider-relay")
        #expect(try sqliteString(databaseURL: stateDBURL, sql: "SELECT model_provider FROM threads WHERE id = ?;", bind: liveThreadID) == "provider-relay")
        #expect(try sqliteString(databaseURL: stateDBURL, sql: "SELECT model_provider FROM threads WHERE id = ?;", bind: archivedThreadID) == "provider-relay")

        try await manager.activateAccountAndMarkActive(oauth, for: provider)

        #expect(try rolloutSessionMetaProvider(file: liveRollout) == "openai")
        #expect(try rolloutSessionMetaProvider(file: archivedRollout) == "openai")
        #expect(try sqliteString(databaseURL: stateDBURL, sql: "SELECT model_provider FROM threads WHERE id = ?;", bind: liveThreadID) == "openai")
        #expect(try sqliteString(databaseURL: stateDBURL, sql: "SELECT model_provider FROM threads WHERE id = ?;", bind: archivedThreadID) == "openai")
        #expect(try configFile.read() == originalConfig + "\n")
    }

    @Test("Given historical threads already belong to an older relay provider, when the active relay provider id changes, then rollout files and state db migrate to the new relay provider")
    func refreshActiveRelayConfigMigratesHistoricalProviderMetadata() async throws {
        let root = try makeTempRoot("codex-auth-refresh-history-provider-migration")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let provider = makeCodexProvider(root: root)
        let codexHome = root.folder("provider")
        try codexHome.file("config.toml").overlay(with: "approval_policy = \"on-request\"\n")

        let liveThreadID = UUID().uuidString.lowercased()
        let liveRollout = try writeRolloutSessionMeta(
            codexHome: codexHome,
            threadID: liveThreadID,
            modelProvider: "provider-one"
        )
        let stateDBURL = try createCodexStateDatabase(
            codexHome: codexHome,
            threads: [
                (id: liveThreadID, rolloutPath: "sessions/2026/04/10/\(liveRollout.attributes.name)", modelProvider: "provider-one", archived: false),
            ]
        )

        let relay = try await manager.addConfiguredAccount(
            name: "Relay One",
            apiKey: "rk-live-12345678",
            relay: .init(
                baseURL: "https://relay-one.example.com/v1",
                modelProvider: "provider-one",
                queryParams: ["api-version": "2025-01-01-preview"],
                headers: ["X-Workspace": "ios"]
            )
        )
        try await manager.activateAccountAndMarkActive(relay, for: provider)

        try await manager.updateConfiguredAccount(
            relay,
            name: "Relay Two",
            apiKey: "rk-live-87654321",
            relay: .init(
                baseURL: "https://relay-two.example.com/v1",
                modelProvider: "provider-two",
                queryParams: ["api-version": "2025-04-01-preview"],
                headers: ["X-Workspace": "mac"]
            )
        )
        let refreshed = try #require((try await manager.loadAccounts()).first(where: { $0.id == relay.id }))

        try await manager.refreshActiveProviderConfigIfNeeded(for: refreshed, provider: provider)

        #expect(try rolloutSessionMetaProvider(file: liveRollout) == "provider-two")
        #expect(try sqliteString(databaseURL: stateDBURL, sql: "SELECT model_provider FROM threads WHERE id = ?;", bind: liveThreadID) == "provider-two")
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
