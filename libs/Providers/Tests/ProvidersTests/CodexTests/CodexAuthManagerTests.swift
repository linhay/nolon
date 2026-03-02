import Foundation
import Testing
import ProviderCatalog
import STFilePath
@testable import ProviderUsage

@Suite("CodexAuthManager")
struct CodexAuthManagerTests {
    private func makeTempRoot(_ prefix: String) throws -> STFolder {
        let root = STFolder("/tmp").folder("\(prefix)-\(UUID().uuidString)")
        _ = root.createIfNotExists()
        return root
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
        let raw = #"{"tokens":{"id_token":"id-2","access_token":"access-2"},"user":{"email":"cli@example.com"}}"#
        try raw.write(to: authURL, atomically: true, encoding: .utf8)

        let account = try await manager.finalizeCLILogin(provider: provider, newAccountName: "cli")
        let activeId = await manager.activeAccountId(for: provider)
        let syncedRaw = try #require(await manager.readAuthJSONString(from: provider))

        #expect(activeId == account.id)
        #expect(syncedRaw.contains("\"id_token\":\"id-2\""))
        #expect(syncedRaw.contains("\"access_token\":\"access-2\""))
    }

    @Test("Given preferred snapshot and CLI login payload, when recording login snapshot, then preferred snapshot is updated and sync metadata is refreshed")
    func recordCLILoginSnapshotUpdatesPreferredAndMetadata() async throws {
        let root = try makeTempRoot("codex-auth-record-cli")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let preferred = try await manager.addAccount(
            name: "preferred",
            authJSONString: #"{"tokens":{"id_token":"old-id","access_token":"old-access"},"user":{"email":"preferred@example.com"}}"#
        )
        _ = try await manager.addAccount(
            name: "other",
            authJSONString: #"{"tokens":{"id_token":"other-id","access_token":"other-access"},"user":{"email":"other@example.com"}}"#
        )
        try await manager.updateSyncFailure(
            for: preferred,
            message: "previous failure",
            date: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let loginAt = Date(timeIntervalSince1970: 1_700_000_100)
        let updated = try await manager.recordCLILoginSnapshot(
            authJSONString: #"{"tokens":{"id_token":"new-id","access_token":"new-access"},"user":{"email":"other@example.com"}}"#,
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

    @Test("Given existing snapshot with same email, when recording CLI login snapshot, then account is overwritten in-place")
    func recordCLILoginSnapshotOverwritesByEmail() async throws {
        let root = try makeTempRoot("codex-auth-record-email")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let existing = try await manager.addAccount(
            name: "existing",
            authJSONString: #"{"tokens":{"id_token":"old-id","access_token":"old-access"},"user":{"email":"same@example.com"}}"#
        )

        let updated = try await manager.recordCLILoginSnapshot(
            authJSONString: #"{"tokens":{"id_token":"new-id","access_token":"new-access"},"user":{"email":"same@example.com"}}"#,
            preferredAccountID: nil
        )

        #expect(updated.id == existing.id)
        let tokenPair = try await manager.readTokenPair(for: updated)
        #expect(tokenPair?.idToken == "new-id")
        #expect(tokenPair?.accessToken == "new-access")
    }

    @Test("Given detached provider auth file with same email, when reconciling detached auth, then matching snapshot is overwritten, relinked, and marked active")
    func reconcileDetachedProviderAuthOverwritesByEmail() async throws {
        let root = try makeTempRoot("codex-auth-reconcile-detached")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let existing = try await manager.addAccount(
            name: "existing",
            authJSONString: #"{"tokens":{"id_token":"old-id","access_token":"old-access"},"user":{"email":"same@example.com"}}"#
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
        let detachedRaw = #"{"tokens":{"id_token":"new-id","access_token":"new-access"},"user":{"email":"same@example.com"}}"#
        try detachedRaw.write(to: detachedAuthURL, atomically: true, encoding: .utf8)

        let reconciled = try await manager.reconcileDetachedProviderAuthIfNeeded(for: provider)
        #expect(reconciled?.id == existing.id)

        let tokenPair = try await manager.readTokenPair(for: existing)
        #expect(tokenPair?.idToken == "new-id")
        #expect(tokenPair?.accessToken == "new-access")

        let providerAuth = try #require(await manager.authFile(for: provider))
        #expect(providerAuth.isSymbolicLink == true)
        let destination = try providerAuth.destinationOfSymbolicLink()
        let snapshotPath = await manager.accountAuthFile(existing).url.path
        #expect(STPath.standardizedPath(destination.url.path).path == STPath.standardizedPath(snapshotPath).path)

        let activeId = await manager.activeAccountId(for: provider)
        #expect(activeId == existing.id)
    }

    @Test("Given detached provider auth without matching snapshot, when reconciling detached auth, then migrate to new snapshot and relink provider auth")
    func reconcileDetachedProviderAuthMigratesAndRelinks() async throws {
        let root = try makeTempRoot("codex-auth-reconcile-migrate")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        _ = try await manager.addAccount(
            name: "existing",
            authJSONString: #"{"tokens":{"id_token":"old-id","access_token":"old-access"},"user":{"email":"existing@example.com"}}"#
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
        let detachedRaw = #"{"tokens":{"id_token":"new-id","access_token":"new-access"},"user":{"email":"fresh@example.com"}}"#
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
        try #"{"tokens":{"id_token":"id-valid","access_token":"access-valid"},"user":{"email":"valid@example.com"}}"#
            .write(to: validURL, atomically: true, encoding: .utf8)
        try #"{"user":{"email":"invalid@example.com"}}"#
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
            authJSONString: #"{"OPENAI_API_KEY":"sk-email-1111","user":{"email":"email-match@example.com"}}"#
        )
        _ = try await manager.addAccount(
            name: "key-match",
            authJSONString: #"{"OPENAI_API_KEY":"sk-key-9999","user":{"email":"other@example.com"}}"#
        )
        let payload = Data(#"{"OPENAI_API_KEY":"sk-any-9999","user":{"email":"email-match@example.com"}}"#.utf8)

        let matched = try await manager.matchAccountByAuthData(payload)
        #expect(matched?.id == emailMatch.id)
    }

    @Test("Given auth payload missing email but containing account id, when matching snapshot then account id wins over api key")
    func matchAccountPrioritizesAccountIDOverApiKey() async throws {
        let root = try makeTempRoot("codex-auth-match-accountid")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let accountIDMatch = try await manager.addAccount(
            name: "accountid-match",
            authJSONString: #"{"tokens":{"account_id":"acct-123"},"OPENAI_API_KEY":"sk-one-1111"}"#
        )
        _ = try await manager.addAccount(
            name: "suffix-match",
            authJSONString: #"{"OPENAI_API_KEY":"sk-two-7777"}"#
        )
        let payload = Data(#"{"tokens":{"account_id":"acct-123"},"OPENAI_API_KEY":"sk-other-7777"}"#.utf8)

        let matched = try await manager.matchAccountByAuthData(payload)
        #expect(matched?.id == accountIDMatch.id)
    }

    @Test("Given detached provider auth with invalid json and healthy snapshot, when preflight runs then snapshot is kept as source of truth")
    func preflightPrefersHealthySnapshotWhenProviderAuthBroken() async throws {
        let root = try makeTempRoot("codex-auth-preflight-prefer-snapshot")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let snapshot = try await manager.addAccount(
            name: "stable",
            authJSONString: #"{"tokens":{"id_token":"id-stable","access_token":"access-stable"},"user":{"email":"stable@example.com"}}"#
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
        if providerAuth.isExists {
            try providerAuth.delete()
        }
        try "not-json".write(to: providerAuth.url, atomically: true, encoding: .utf8)

        let affected = try await manager.preflightManagedAuthIfNeeded(for: provider, forceBackup: true, reason: "test")
        #expect(affected?.id == snapshot.id)
        #expect(providerAuth.isSymbolicLink == true)
    }

    @Test("Given active snapshot drifted by external write, when preflight runs then active snapshot is restored and drifted auth is preserved separately")
    func preflightRestoresActiveSnapshotAfterExternalDrift() async throws {
        let root = try makeTempRoot("codex-auth-preflight-drift")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let active = try await manager.addAccount(
            name: "active",
            authJSONString: #"{"tokens":{"id_token":"id-active","access_token":"access-active"},"user":{"email":"active@example.com"}}"#
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

        let driftedRaw = #"{"tokens":{"id_token":"id-drift","access_token":"access-drift"},"user":{"email":"drift@example.com"}}"#
        let activeFile = await manager.accountAuthFile(active)
        try activeFile.overlay(with: Data(driftedRaw.utf8))

        _ = try await manager.preflightManagedAuthIfNeeded(for: provider, forceBackup: false, reason: "detect_drift")

        let restoredSummary = CodexAuthSummary.fromJSONData(try activeFile.data())
        #expect(restoredSummary.email == "active@example.com")

        let accounts = try await manager.loadAccounts()
        var driftedFound = false
        for account in accounts where account.id != active.id {
            let file = await manager.accountAuthFile(account)
            let summary = CodexAuthSummary.fromJSONData((try? file.data()) ?? Data())
            if summary.email == "drift@example.com" {
                driftedFound = true
                break
            }
        }
        #expect(driftedFound == true)
    }
}
