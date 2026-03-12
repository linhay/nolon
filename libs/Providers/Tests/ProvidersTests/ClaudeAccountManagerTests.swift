import Foundation
import Testing
import ProviderCatalog
import STFilePath
@testable import ProviderUsage

@Suite("ClaudeAccountManager")
struct ClaudeAccountManagerTests {
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

    @Test("Given account activation, when writing settings, then env and active-account snapshot are updated")
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
}
