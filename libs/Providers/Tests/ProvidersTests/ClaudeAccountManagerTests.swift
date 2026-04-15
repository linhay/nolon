import Foundation
import Testing
import ProviderCatalog
import STFilePath
@testable import ProviderUsage

@Suite("ClaudeAccountManager")
struct ClaudeAccountManagerTests {
    private struct WrappedUnderlyingError: LocalizedError, CustomNSError {
        let underlying: Error

        static var errorDomain: String {
            "ClaudeAccountManagerTests.WrappedUnderlyingError"
        }

        var errorCode: Int {
            1
        }

        var errorUserInfo: [String: Any] {
            [
                NSLocalizedDescriptionKey: "request failed",
                NSUnderlyingErrorKey: underlying
            ]
        }

        var errorDescription: String? {
            "request failed"
        }
    }

    private func makeTempRoot(_ prefix: String) -> STFolder {
        let root = STFolder("/tmp").folder("\(prefix)-\(UUID().uuidString)")
        _ = root.createIfNotExists()
        return root
    }

    private func makeClaudeProvider(root: STFolder) -> Provider {
        Provider(
            name: "Claude Code",
            defaultSkillsPath: root.folder("provider").folder("skills").url.path,
            workflowPath: root.folder("provider").folder("workflows").url.path,
            installMethod: .symlink,
            templateId: ProviderTemplate.claudeCode.rawValue
        )
    }

    private func runSQLite(databaseURL: URL, sql: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [databaseURL.path, sql]

        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: errorData, encoding: .utf8) ?? "sqlite3 failed"
            throw NSError(
                domain: "ClaudeAccountManagerTests.sqlite",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }
    }

    private func runSQLiteJSON(databaseURL: URL, sql: String) throws -> [[String: String]] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = ["-json", databaseURL.path, sql]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: errorData, encoding: .utf8) ?? "sqlite3 failed"
            throw NSError(
                domain: "ClaudeAccountManagerTests.sqlite",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }

        let outputData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        guard !outputData.isEmpty else { return [] }
        return try JSONDecoder().decode([[String: String]].self, from: outputData)
    }

    @Test("Given account activation, when writing settings, then env and active-account snapshot are updated without implicit model defaults")
    func activateAccountWritesSettingsAndActiveID() async throws {
        let root = makeTempRoot("claude-account-activate")
        defer { try? root.delete() }

        let manager = ClaudeAccountManager(
            rootURL: root.url,
            validationAction: { _ in
                ClaudeAccountValidationResult(isEffective: true, statusCode: 200, message: "ok")
            }
        )
        let provider = makeClaudeProvider(root: root)
        let settingsFile = try #require(manager.settingsFile(for: provider))
        _ = settingsFile.parentFolder()?.createIfNotExists()
        try settingsFile.overlay(with: Data(#"{"env":{"FOO":"bar","ANTHROPIC_API_KEY":"legacy"},"other":1}"#.utf8))

        let account = try await manager.addAccount(
            name: "work",
            credentialType: .authToken,
            credentialValue: "test-token",
            baseURL: "https://api.anthropic.com",
            source: .manual
        )

        let activated = try await manager.activateAccount(id: account.id, provider: provider)
        let activeID = try await manager.activeAccountID()
        #expect(activeID == account.id)
        #expect(activated.lastValidationStatus == true)

        let data = try settingsFile.data()
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let env = try #require(json["env"] as? [String: Any])
        #expect(env["FOO"] as? String == "bar")
        #expect(env["ANTHROPIC_AUTH_TOKEN"] as? String == "test-token")
        #expect(env["ANTHROPIC_API_KEY"] == nil)
        #expect(env["ANTHROPIC_MODEL"] == nil)
        #expect(env["ANTHROPIC_REASONING_MODEL"] == nil)
        #expect(env["ANTHROPIC_DEFAULT_HAIKU_MODEL"] == nil)
        #expect(env["ANTHROPIC_DEFAULT_SONNET_MODEL"] == nil)
        #expect(env["ANTHROPIC_DEFAULT_OPUS_MODEL"] == nil)
        #expect(json["other"] as? Int == 1)
    }

    @Test("Given current claude settings, when importing, then account is migrated and deduplicated")
    func importFromCurrentSettings() async throws {
        let root = makeTempRoot("claude-account-migrate")
        defer { try? root.delete() }

        let manager = ClaudeAccountManager(rootURL: root.url)
        let provider = makeClaudeProvider(root: root)
        let settingsFile = try #require(manager.settingsFile(for: provider))
        _ = settingsFile.parentFolder()?.createIfNotExists()
        try settingsFile.overlay(with: Data(#"{"env":{"ANTHROPIC_API_KEY":"api-key-1","ANTHROPIC_BASE_URL":"https://relay.example.com/v1"}}"#.utf8))

        let imported1 = try await manager.importFromCurrentSettings(provider: provider)
        let imported2 = try await manager.importFromCurrentSettings(provider: provider)
        let accounts = try await manager.loadAccounts()

        #expect(imported1 != nil)
        #expect(imported2 != nil)
        #expect(accounts.count == 1)
        #expect(accounts[0].credentialType == .apiKey)
        #expect(accounts[0].source == .migrated)
        #expect(accounts[0].normalizedBaseURL == "https://relay.example.com/v1")
        #expect(accounts[0].anthropicModel == "")
        #expect(accounts[0].anthropicReasoningModel == "")
        #expect(accounts[0].anthropicDefaultHaikuModel == "")
        #expect(accounts[0].anthropicDefaultSonnetModel == "")
        #expect(accounts[0].anthropicDefaultOpusModel == "")
    }

    @Test("Given current claude settings with reasoning model, when importing, then reasoning model is parsed into account")
    func importFromCurrentSettingsParsesReasoningModel() async throws {
        let root = makeTempRoot("claude-account-migrate-reasoning")
        defer { try? root.delete() }

        let manager = ClaudeAccountManager(rootURL: root.url)
        let provider = makeClaudeProvider(root: root)
        let settingsFile = try #require(manager.settingsFile(for: provider))
        _ = settingsFile.parentFolder()?.createIfNotExists()
        try settingsFile.overlay(with: Data(#"{"env":{"ANTHROPIC_AUTH_TOKEN":"token-1","ANTHROPIC_BASE_URL":"https://relay.example.com/v1","ANTHROPIC_MODEL":"gpt-5","ANTHROPIC_REASONING_MODEL":"gpt-5(high)"}}"#.utf8))

        _ = try await manager.importFromCurrentSettings(provider: provider)
        let accounts = try await manager.loadAccounts()
        let account = try #require(accounts.first)

        #expect(account.anthropicModel == "gpt-5")
        #expect(account.anthropicReasoningModel == "gpt-5(high)")
    }

    @Test("Given active account with reasoning model, when activating, then settings env contains ANTHROPIC_REASONING_MODEL")
    func activateAccountWritesReasoningModelToSettings() async throws {
        let root = makeTempRoot("claude-account-activate-reasoning")
        defer { try? root.delete() }

        let manager = ClaudeAccountManager(
            rootURL: root.url,
            validationAction: { _ in
                ClaudeAccountValidationResult(isEffective: true, statusCode: 200, message: "ok")
            }
        )
        let provider = makeClaudeProvider(root: root)

        let account = ClaudeAccount(
            name: "reasoning",
            credentialType: .authToken,
            credentialValue: "reasoning-token",
            baseURL: "https://api.anthropic.com",
            anthropicModel: "gpt-5",
            anthropicReasoningModel: "gpt-5(high)",
            anthropicDefaultHaikuModel: "gpt-5(minimal)",
            anthropicDefaultSonnetModel: "gpt-5(medium)",
            anthropicDefaultOpusModel: "gpt-5(high)",
            source: .manual
        )
        try await manager.saveAccounts([account])
        _ = try await manager.activateAccount(id: account.id, provider: provider)

        let settingsFile = try #require(manager.settingsFile(for: provider))
        let data = try settingsFile.data()
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let env = try #require(json["env"] as? [String: Any])
        #expect(env["ANTHROPIC_REASONING_MODEL"] as? String == "gpt-5(high)")
    }

    @Test("Given active account with empty model mapping, when activating, then legacy model env keys are removed from settings")
    func activateAccountRemovesEmptyModelMappingKeys() async throws {
        let root = makeTempRoot("claude-account-activate-empty-models")
        defer { try? root.delete() }

        let manager = ClaudeAccountManager(
            rootURL: root.url,
            validationAction: { _ in
                ClaudeAccountValidationResult(isEffective: true, statusCode: 200, message: "ok")
            }
        )
        let provider = makeClaudeProvider(root: root)
        let settingsFile = try #require(manager.settingsFile(for: provider))
        _ = settingsFile.parentFolder()?.createIfNotExists()
        try settingsFile.overlay(with: Data(#"{"env":{"ANTHROPIC_MODEL":"legacy-model","ANTHROPIC_REASONING_MODEL":"legacy-reasoning","ANTHROPIC_DEFAULT_HAIKU_MODEL":"legacy-haiku","ANTHROPIC_DEFAULT_SONNET_MODEL":"legacy-sonnet","ANTHROPIC_DEFAULT_OPUS_MODEL":"legacy-opus","ANTHROPIC_SMALL_FAST_MODEL":"legacy-small-fast"}}"#.utf8))

        let account = ClaudeAccount(
            name: "empty-models",
            credentialType: .authToken,
            credentialValue: "token-empty-models",
            baseURL: "https://api.anthropic.com",
            anthropicModel: "",
            anthropicReasoningModel: "",
            anthropicDefaultHaikuModel: "",
            anthropicDefaultSonnetModel: "",
            anthropicDefaultOpusModel: "",
            source: .manual
        )
        try await manager.saveAccounts([account])
        _ = try await manager.activateAccount(id: account.id, provider: provider)

        let data = try settingsFile.data()
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let env = try #require(json["env"] as? [String: Any])
        #expect(env["ANTHROPIC_MODEL"] == nil)
        #expect(env["ANTHROPIC_REASONING_MODEL"] == nil)
        #expect(env["ANTHROPIC_DEFAULT_HAIKU_MODEL"] == nil)
        #expect(env["ANTHROPIC_DEFAULT_SONNET_MODEL"] == nil)
        #expect(env["ANTHROPIC_DEFAULT_OPUS_MODEL"] == nil)
        #expect(env["ANTHROPIC_SMALL_FAST_MODEL"] == nil)
        #expect(env["ANTHROPIC_AUTH_TOKEN"] as? String == "token-empty-models")
    }

    @Test("Given Claude account storage initialization, when loading accounts, then SQLite schema tables are created")
    func ensureSQLiteSchemaCreatedForClaudeAccounts() async throws {
        let root = makeTempRoot("claude-account-schema")
        defer { try? root.delete() }

        let manager = ClaudeAccountManager(rootURL: root.url)
        _ = try await manager.loadAccounts()

        let dbURL = root.file("nolon.sqlite3").url
        #expect(FileManager.default.fileExists(atPath: dbURL.path))

        let tables = try runSQLiteJSON(
            databaseURL: dbURL,
            sql: """
            SELECT name
            FROM sqlite_master
            WHERE type = 'table' AND name IN ('claude_accounts', 'claude_active_accounts')
            ORDER BY name;
            """
        )
        #expect(tables.map { $0["name"] ?? "" } == ["claude_accounts", "claude_active_accounts"])

        let accountColumns = try runSQLiteJSON(
            databaseURL: dbURL,
            sql: """
            SELECT name
            FROM pragma_table_info('claude_accounts')
            WHERE name IN (
              'anthropic_model',
              'anthropic_reasoning_model',
              'anthropic_default_haiku_model',
              'anthropic_default_sonnet_model',
              'anthropic_default_opus_model'
            )
            ORDER BY name;
            """
        )
        #expect(accountColumns.map { $0["name"] ?? "" } == [
            "anthropic_default_haiku_model",
            "anthropic_default_opus_model",
            "anthropic_default_sonnet_model",
            "anthropic_model",
            "anthropic_reasoning_model",
        ])

        let activeScopes = try runSQLiteJSON(
            databaseURL: dbURL,
            sql: """
            SELECT scope
            FROM claude_active_accounts
            ORDER BY scope;
            """
        )
        #expect(activeScopes.map { $0["scope"] ?? "" } == ["default"])
    }

    @Test("Given legacy JSON snapshots, when loading accounts, then records are backfilled to SQLite")
    func migrateLegacyJSONSnapshotsIntoSQLiteOnFirstLoad() async throws {
        let root = makeTempRoot("claude-account-json-backfill")
        defer { try? root.delete() }

        let manager = ClaudeAccountManager(rootURL: root.url)
        _ = manager.claudeDataFolder().createIfNotExists()

        let accountID = UUID(uuidString: "bbbbbbbb-2222-2222-2222-222222222222")!
        let now = Date()
        let legacyAccount = ClaudeAccount(
            id: accountID,
            name: "legacy-json",
            credentialType: .authToken,
            credentialValue: "legacy-token",
            baseURL: "https://api.anthropic.com",
            source: .manual,
            createdAt: now,
            updatedAt: now
        )

        let accountsPayload = """
        {
          "schemaVersion" : 1,
          "accounts" : [
            {
              "id" : "\(legacyAccount.id.uuidString)",
              "name" : "\(legacyAccount.name)",
              "credentialType" : "\(legacyAccount.credentialType.rawValue)",
              "credentialValue" : "\(legacyAccount.credentialValue)",
              "baseURL" : "\(legacyAccount.baseURL)",
              "source" : "\(legacyAccount.source.rawValue)",
              "createdAt" : \(legacyAccount.createdAt.timeIntervalSince1970),
              "updatedAt" : \(legacyAccount.updatedAt.timeIntervalSince1970)
            }
          ]
        }
        """
        try manager.accountsFile().overlay(with: Data(accountsPayload.utf8))
        try manager.activeAccountFile().overlay(with: Data("{\"accountID\":\"\(legacyAccount.id.uuidString)\"}".utf8))

        let loaded = try await manager.loadAccounts()
        #expect(loaded.count == 1)
        #expect(loaded.first?.id == legacyAccount.id)

        let dbURL = root.file("nolon.sqlite3").url
        let rows = try runSQLiteJSON(
            databaseURL: dbURL,
            sql: """
            SELECT id, name
            FROM claude_accounts
            ORDER BY id;
            """
        )
        #expect(rows.count == 1)
        #expect(rows.first?["id"] == legacyAccount.id.uuidString)
        #expect(rows.first?["name"] == legacyAccount.name)

        let activeRows = try runSQLiteJSON(
            databaseURL: dbURL,
            sql: """
            SELECT scope, account_id
            FROM claude_active_accounts
            WHERE scope = 'default';
            """
        )
        #expect(activeRows.first?["scope"] == "default")
        #expect(activeRows.first?["account_id"] == legacyAccount.id.uuidString)
    }

    @Test("Given fresh storage, when adding and activating account, then legacy JSON snapshots are not generated anymore")
    func doesNotGenerateLegacyJSONSnapshotsAfterSQLiteCutover() async throws {
        let root = makeTempRoot("claude-account-no-json-mirror")
        defer { try? root.delete() }

        let manager = ClaudeAccountManager(
            rootURL: root.url,
            validationAction: { _ in
                ClaudeAccountValidationResult(isEffective: true, statusCode: 200, message: "ok")
            }
        )
        let provider = makeClaudeProvider(root: root)

        let account = try await manager.addAccount(
            name: "sqlite-only",
            credentialType: .apiKey,
            credentialValue: "sk-ant-sqlite",
            baseURL: "https://api.anthropic.com",
            source: .manual
        )
        _ = try await manager.activateAccount(id: account.id, provider: provider)

        #expect(manager.accountsFile().isExists == false)
        #expect(manager.activeAccountFile().isExists == false)

        let dbURL = root.file("nolon.sqlite3").url
        let rows = try runSQLiteJSON(
            databaseURL: dbURL,
            sql: """
            SELECT id
            FROM claude_accounts
            WHERE id = '\(account.id.uuidString)';
            """
        )
        #expect(rows.count == 1)
    }

    @Test("Given existing ineffective account, when importing same key from cc-switch and candidate is effective, then existing snapshot is replaced")
    func importFromCCSwitchReplacesIneffectiveDuplicate() async throws {
        let root = makeTempRoot("claude-account-cc-switch")
        defer { try? root.delete() }

        let manager = ClaudeAccountManager(
            rootURL: root.url,
            validationAction: { account in
                ClaudeAccountValidationResult(
                    isEffective: account.source == .ccSwitch,
                    statusCode: 200,
                    message: account.source.rawValue
                )
            }
        )

        let existing = try await manager.addAccount(
            name: "legacy",
            credentialType: .authToken,
            credentialValue: "candidate-token",
            baseURL: "https://api.anthropic.com",
            source: .manual
        )

        let dbURL = root.file("cc-switch.db").url
        try runSQLite(
            databaseURL: dbURL,
            sql: """
            CREATE TABLE providers (
              id TEXT PRIMARY KEY,
              app_type TEXT,
              name TEXT,
              settings_config TEXT,
              created_at INTEGER
            );
            INSERT INTO providers (id, app_type, name, settings_config, created_at)
            VALUES (
              'p1',
              'claude',
              'from-switch',
              '{"env":{"ANTHROPIC_AUTH_TOKEN":"candidate-token","ANTHROPIC_BASE_URL":"https://api.anthropic.com"}}',
              1700000000000
            );
            """
        )

        let report = try await manager.importFromCCSwitch(dbURL: dbURL)
        let accounts = try await manager.loadAccounts()
        let updated = try #require(accounts.first)

        #expect(report.totalCandidates == 1)
        #expect(report.replacedCount == 1)
        #expect(report.importedCount == 0)
        #expect(report.skippedCount == 0)
        #expect(accounts.count == 1)
        #expect(updated.id == existing.id)
        #expect(updated.source == .ccSwitch)
        #expect(updated.name == "from-switch")
    }

    @Test("Given cc-switch provider with top-level key fields, when importing, then account is parsed and saved")
    func importFromCCSwitchSupportsTopLevelKeys() async throws {
        let root = makeTempRoot("claude-account-cc-switch-top-level")
        defer { try? root.delete() }

        let manager = ClaudeAccountManager(rootURL: root.url)
        let dbURL = root.file("cc-switch.db").url
        try runSQLite(
            databaseURL: dbURL,
            sql: """
            CREATE TABLE providers (
              id TEXT PRIMARY KEY,
              app_type TEXT,
              name TEXT,
              settings_config TEXT,
              created_at INTEGER
            );
            INSERT INTO providers (id, app_type, name, settings_config, created_at)
            VALUES (
              'p1',
              'claude',
              'top-level',
              '{"apiKey":"candidate-key","baseURL":"https://relay.example.com/v1"}',
              1700000000000
            );
            """
        )

        let report = try await manager.importFromCCSwitch(dbURL: dbURL)
        let accounts = try await manager.loadAccounts()
        let account = try #require(accounts.first)

        #expect(report.totalCandidates == 1)
        #expect(report.importedCount == 1)
        #expect(report.replacedCount == 0)
        #expect(report.skippedCount == 0)
        #expect(account.name == "top-level")
        #expect(account.credentialType == .apiKey)
        #expect(account.credentialValue == "candidate-key")
        #expect(account.normalizedBaseURL == "https://relay.example.com/v1")
    }

    @Test("Given direct invalid reuse message, detector returns true")
    func invalidReuseDetectorMatchesDirectMessage() {
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorUnknown,
            userInfo: [NSLocalizedDescriptionKey: "invalid reuse after initialization failure"]
        )

        #expect(ClaudeAccountManager.isInvalidReuseAfterInitializationFailure(error: error))
    }

    @Test("Given wrapped invalid reuse message, detector returns true")
    func invalidReuseDetectorMatchesWrappedUnderlyingError() {
        let underlying = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorUnknown,
            userInfo: [NSLocalizedDescriptionKey: "invalid reuse after initialization failure"]
        )
        let error = WrappedUnderlyingError(underlying: underlying)

        #expect(ClaudeAccountManager.isInvalidReuseAfterInitializationFailure(error: error))
    }
}
