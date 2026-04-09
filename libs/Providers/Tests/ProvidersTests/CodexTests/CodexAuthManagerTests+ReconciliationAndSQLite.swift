import Foundation
import Testing
import ProviderCatalog
import STFilePath
import STJSON
import SQLite3
@testable import ProviderUsage

extension CodexAuthManagerTests {
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
}
