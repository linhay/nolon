import Foundation
import Testing
import ProviderCatalog
import STFilePath
import STJSON
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

    @Test("Given detached provider auth file with same email, when reconciling detached auth, then matching snapshot is overwritten, relinked, and marked active")
    func reconcileDetachedProviderAuthOverwritesByEmail() async throws {
        let root = try makeTempRoot("codex-auth-reconcile-detached")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let existing = try await manager.addAccount(
            name: "existing",
            authJSONString: #"{"tokens":{"id_token":"old-id","access_token":"old-access"},"email":"same@example.com"}"#
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
        let detachedRaw = #"{"tokens":{"id_token":"new-id","access_token":"new-access"},"email":"same@example.com"}"#
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
        #expect(newerRaw.contains("\"OPENAI_API_KEY\":\"sk-beta-1234\""))
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

    @Test("Given active snapshot drifted by external write, when preflight runs then active snapshot is restored and drifted auth is preserved separately")
    func preflightRestoresActiveSnapshotAfterExternalDrift() async throws {
        let root = try makeTempRoot("codex-auth-preflight-drift")
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
        _ = try await manager.preflightManagedAuthIfNeeded(for: provider, forceBackup: true, reason: "seed_backup")

        let driftedRaw = #"{"tokens":{"id_token":"id-drift","access_token":"access-drift"},"email":"drift@example.com"}"#
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

}
