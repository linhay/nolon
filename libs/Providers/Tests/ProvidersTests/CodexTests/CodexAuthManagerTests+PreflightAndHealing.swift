import Foundation
import Testing
import ProviderCatalog
import STFilePath
import STJSON
import SQLite3
@testable import ProviderUsage

extension CodexAuthManagerTests {
    @Test("Given detached apikey auth plus relay config without provenance, when preflight runs then snapshot stays official api key")
    func preflightKeepsOfficialAPIKeyWithoutRelayProvenance() async throws {
        let root = try makeTempRoot("codex-auth-preflight-dual-read-no-provenance")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let provider = makeCodexProvider(root: root)
        let providerRoot = root.folder("provider")
        let configFile = providerRoot.file("config.toml")
        try configFile.overlay(with: #"""
        model_provider = "provider-relay"

        [model_providers.provider-relay]
        name = "Relay"
        base_url = "https://relay.example.com/v1"
        """# + "\n")
        try providerRoot.file("auth.json").overlay(with: Data(#"""
        {
          "auth_mode": "apikey",
          "OPENAI_API_KEY": "sk-provenance-missing"
        }
        """#.utf8))

        let affected = try await manager.preflightManagedAuthIfNeeded(for: provider, forceBackup: false, reason: "test_no_provenance")
        let resolved = try #require(affected)
        let summary = CodexAuthSummary.fromJSONData(try #require(manager.accountAuthData(for: resolved)))

        #expect(summary.cardKind == .officialAPIKey)
        #expect(summary.relayBaseURL == nil)
    }

    @Test("Given detached apikey auth plus relay config with matching managed provenance, when preflight runs then matched snapshot upgrades to relay profile")
    func preflightUpgradesToRelayProfileWhenManagedRelayProvenanceMatches() async throws {
        let root = try makeTempRoot("codex-auth-preflight-dual-read-with-provenance")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let provider = makeCodexProvider(root: root)
        let providerRoot = root.folder("provider")
        let configFile = providerRoot.file("config.toml")
        try configFile.overlay(with: #"""
        model_provider = "provider-relay"

        [model_providers.provider-relay]
        name = "Relay"
        base_url = "https://relay.example.com/v1"
        query_params = { api-version = "2025-01-01-preview" }
        http_headers = { X-Workspace = "ios" }
        """# + "\n")

        let account = try await manager.addConfiguredAccount(
            name: "Direct",
            apiKey: "sk-managed-relay",
            relay: nil
        )
        try seedManagedRelayConfigState(
            manager: manager,
            configFile: configFile,
            accountID: account.id,
            providerID: "provider-relay"
        )
        try providerRoot.file("auth.json").overlay(with: Data(#"""
        {
          "auth_mode": "apikey",
          "OPENAI_API_KEY": "sk-managed-relay"
        }
        """#.utf8))

        let affected = try await manager.preflightManagedAuthIfNeeded(for: provider, forceBackup: false, reason: "test_with_provenance")
        let resolved = try #require(affected)
        let summary = CodexAuthSummary.fromJSONData(try #require(manager.accountAuthData(for: resolved)))

        #expect(resolved.id == account.id)
        #expect(summary.cardKind == .relayProfile)
        #expect(summary.relayBaseURL == "https://relay.example.com/v1")
        #expect(summary.relayModelProvider == "provider-relay")
    }

    @Test("Given detached apikey auth plus relay config, when preflight dual-reads provider state then config toml stays byte-for-byte untouched")
    func preflightDualReadLeavesConfigTomlUntouched() async throws {
        let root = try makeTempRoot("codex-auth-preflight-dual-read-readonly-config")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let provider = makeCodexProvider(root: root)
        let providerRoot = root.folder("provider")
        let configFile = providerRoot.file("config.toml")
        try configFile.overlay(with: #"""
        model_provider = "provider-relay"

        [model_providers.provider-relay]
        name = "Relay"
        base_url = "https://relay.example.com/v1"
        query_params = { api-version = "2025-01-01-preview" }
        http_headers = { X-Workspace = "ios" }
        """# + "\n")
        let before = try configSnapshot(for: configFile)

        let account = try await manager.addConfiguredAccount(
            name: "Direct",
            apiKey: "sk-readonly-relay",
            relay: nil
        )
        try seedManagedRelayConfigState(
            manager: manager,
            configFile: configFile,
            accountID: account.id,
            providerID: "provider-relay"
        )
        try providerRoot.file("auth.json").overlay(with: Data(#"""
        {
          "auth_mode": "apikey",
          "OPENAI_API_KEY": "sk-readonly-relay"
        }
        """#.utf8))

        _ = try await manager.preflightManagedAuthIfNeeded(for: provider, forceBackup: false, reason: "test_config_readonly")

        let after = try configSnapshot(for: configFile)
        #expect(after.raw == before.raw)
        #expect(after.modificationDate == before.modificationDate)
    }

    @Test("Given detached managed apikey auth keeps nolon account id but changes api key, when reconciling provider payload then existing snapshot is updated instead of creating a new account")
    func reconcileUpdatesExistingManagedAPIKeySnapshotWhenOnlyAPIKeyChanges() async throws {
        let root = try makeTempRoot("codex-auth-preflight-managed-apikey-rotate")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let provider = makeCodexProvider(root: root)
        let account = try await manager.addConfiguredAccount(
            name: "OpenAI Direct",
            apiKey: "sk-old-12345678",
            relay: nil
        )

        let originalData = try #require(manager.accountAuthDataWithoutMaterialization(for: account))
        var detachedObject = try #require(JSON(data: originalData).dictionaryObject)
        detachedObject["OPENAI_API_KEY"] = "sk-new-87654321"
        let detachedData = try JSONSerialization.data(withJSONObject: detachedObject, options: [])
        let snapshots = try await manager.loadAccounts()
        let affected = try await manager.upsertSnapshotFromProviderData(
            authData: detachedData,
            providerRaw: String(data: detachedData, encoding: .utf8),
            snapshots: snapshots,
            provider: provider,
            excludedAccountID: nil
        )

        let accounts = try await manager.loadAccounts()
        #expect(accounts.count == 1)
        #expect(affected.id == account.id)

        let updated = try #require(accounts.first(where: { $0.id == account.id }))
        let updatedData = try #require(manager.accountAuthDataWithoutMaterialization(for: updated))
        let updatedJSON = try JSON(data: updatedData)
        #expect(updatedJSON["OPENAI_API_KEY"].string == "sk-new-87654321")
    }

    @Test("Given active managed apikey auth file is externally replaced with a new api key, when preflight runs then the active snapshot is updated instead of creating a new account")
    func preflightUpdatesActiveManagedAPIKeySnapshotWhenProviderAuthFileReplaced() async throws {
        let root = try makeTempRoot("codex-auth-preflight-managed-apikey-provider-file")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let provider = makeCodexProvider(root: root)
        let account = try await manager.addConfiguredAccount(
            name: "OpenAI Direct",
            apiKey: "sk-old-provider-1234",
            relay: nil
        )
        do {
            try await manager.activateAccountAndMarkActive(account, for: provider)
        } catch {
            Issue.record("activateAccountAndMarkActive failed: \(error)")
            return
        }

        let providerAuth = try #require(await manager.authFile(for: provider))
        try? FileManager.default.removeItem(at: providerAuth.url)
        try providerAuth.overlay(with: Data(#"""
        {
          "auth_mode": "apikey",
          "OPENAI_API_KEY": "sk-new-provider-5678"
        }
        """#.utf8))

        let affected: CodexAuthAccount?
        do {
            affected = try await manager.preflightManagedAuthIfNeeded(
                for: provider,
                forceBackup: false,
                reason: "test_managed_apikey_provider_file_replace"
            )
        } catch {
            Issue.record("preflightManagedAuthIfNeeded failed: \(error)")
            return
        }

        let accounts = try await manager.loadAccounts()
        #expect(accounts.count == 1)
        #expect(affected?.id == account.id)

        let updated = try #require(accounts.first(where: { $0.id == account.id }))
        let updatedData = try #require(manager.accountAuthDataWithoutMaterialization(for: updated))
        let updatedJSON = try JSON(data: updatedData)
        #expect(updatedJSON["OPENAI_API_KEY"].string == "sk-new-provider-5678")
    }

    @Test("Given active managed apikey symlink target is externally replaced with a new api key, when preflight runs then the active snapshot is updated instead of creating a new account")
    func preflightUpdatesActiveManagedAPIKeySnapshotWhenSymlinkTargetReplaced() async throws {
        let root = try makeTempRoot("codex-auth-preflight-managed-apikey-symlink-target")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let provider = makeCodexProvider(root: root)
        let account = try await manager.addConfiguredAccount(
            name: "OpenAI Direct",
            apiKey: "sk-old-symlink-1234",
            relay: nil
        )
        try await manager.activateAccountAndMarkActive(account, for: provider)

        let providerAuth = try #require(await manager.authFile(for: provider))
        let activeManagedAuth = STFile(try providerAuth.destinationOfSymbolicLink().url.path)
        try activeManagedAuth.overlay(with: Data(#"""
        {
          "auth_mode": "apikey",
          "OPENAI_API_KEY": "sk-new-symlink-5678"
        }
        """#.utf8))

        let affected = try await manager.preflightManagedAuthIfNeeded(
            for: provider,
            forceBackup: false,
            reason: "test_managed_apikey_symlink_target_replace"
        )

        let accounts = try await manager.loadAccounts()
        #expect(accounts.count == 1)
        #expect(affected == nil)
        #expect(await manager.activeAccountId(for: provider) == account.id)

        let updated = try #require(accounts.first(where: { $0.id == account.id }))
        let updatedData = try #require(manager.accountAuthDataWithoutMaterialization(for: updated))
        let updatedJSON = try JSON(data: updatedData)
        #expect(updatedJSON["OPENAI_API_KEY"].string == "sk-new-symlink-5678")
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
        let validAccount = try #require(accounts.first)
        let validSummary = CodexAuthSummary.fromJSONData(try #require(manager.accountAuthData(for: validAccount)))
        #expect(validSummary.email == "valid@example.com")
        #expect(activeFile.isExists == false)
        #expect(testFile.isExists == false)
        #expect(validFile.isExists == false)
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
        let providerAuth = try #require(await manager.authFile(for: provider))
        let activeFile = STFile(try providerAuth.destinationOfSymbolicLink().url.path)
        try activeFile.overlay(with: Data(driftedRaw.utf8))

        _ = try await manager.preflightManagedAuthIfNeeded(for: provider, forceBackup: false, reason: "detect_drift")

        let restoredActiveID = try #require(await manager.activeAccountId(for: provider))
        let restoredActive = try #require((try await manager.loadAccounts()).first(where: { $0.id == restoredActiveID }))
        let restoredSummary = CodexAuthSummary.fromJSONData(try #require(manager.accountAuthData(for: restoredActive)))
        #expect(restoredSummary.email == "active@example.com")

        let accounts = try await manager.loadAccounts()
        var driftedFound = false
        for account in accounts where account.id != restoredActiveID {
            let summary = CodexAuthSummary.fromJSONData(manager.accountAuthData(for: account) ?? Data())
            if summary.email == "drift@example.com" {
                driftedFound = true
                break
            }
        }
        #expect(driftedFound == true)
    }
    @Test("Given active drift payload shares account id and email with an existing snapshot, when preflight runs then active snapshot is restored without mutating the existing peer snapshot")
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
        let providerAuth = try #require(await manager.authFile(for: provider))
        let activeFile = STFile(try providerAuth.destinationOfSymbolicLink().url.path)
        try activeFile.overlay(with: Data(driftedRaw.utf8))

        _ = try await manager.preflightManagedAuthIfNeeded(for: provider, forceBackup: false, reason: "detect_drift")

        let accounts = try await manager.loadAccounts()
        #expect(accounts.count == 2)

        let peerAfter = try #require(accounts.first(where: { $0.id == peer.id }))
        let peerPair = try await manager.readTokenPair(for: peerAfter)
        #expect(peerPair?.idToken == "id-peer-old")
        #expect(peerPair?.accessToken == "access-peer-old")

        let restoredActiveID = try #require(await manager.activeAccountId(for: provider))
        let restoredActive = try #require(accounts.first(where: { $0.id == restoredActiveID }))
        let restoredSummary = CodexAuthSummary.fromJSONData(try #require(manager.accountAuthData(for: restoredActive)))
        #expect(restoredSummary.email == "active@example.com")
    }

    @Test("Given startup preflight sees modified selected relay account, when usage load runs then active selection is cleared, managed config is not applied, and external auth is preserved")
    func startupPreflightClearsModifiedActiveAccountSelectionAndPreservesExternalAuth() async throws {
        let root = try makeTempRoot("codex-auth-startup-preflight-clear-drifted-active")
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
            apiKey: "rk-live-startup-1234",
            relay: .init(
                baseURL: "https://relay.example.com/v1",
                modelProvider: "provider-relay"
            )
        )

        try await manager.activateAccountAndMarkActive(relay, for: provider)

        let patched = try configFile.read()
        #expect(patched.contains(#"model_provider = "provider-relay""#))

        let driftedRaw = #"""
        {
          "auth_mode": "chatgpt",
          "email": "drifted@example.com",
          "tokens": {
            "id_token": "id-drifted",
            "access_token": "access-drifted",
            "account_id": "acct-drifted"
          }
        }
        """#
        let providerAuth = try #require(await manager.authFile(for: provider))
        let activeFile = STFile(try providerAuth.destinationOfSymbolicLink().url.path)
        try activeFile.overlay(with: Data(driftedRaw.utf8))

        _ = try await manager.preflightManagedAuthIfNeeded(for: provider, forceBackup: false, reason: "usage_load")

        #expect(await manager.activeAccountId(for: provider) == nil)
        #expect(try configFile.read() == originalConfig + "\n")
        #expect(providerAuth.isExists == true)
        let preservedAuthRaw = try providerAuth.read()
        #expect(preservedAuthRaw.contains(#""email": "drifted@example.com""#))

        _ = try await manager.preflightManagedAuthIfNeeded(for: provider, forceBackup: false, reason: "usage_load")
        #expect(await manager.activeAccountId(for: provider) == nil)
        #expect(try providerAuth.read() == preservedAuthRaw)

        let accounts = try await manager.loadAccounts()
        #expect(accounts.contains(where: { account in
            let data = manager.accountAuthData(for: account) ?? Data()
            let summary = CodexAuthSummary.fromJSONData(data)
            return summary.email == "drifted@example.com"
        }))
    }

    @Test("Given runtime auth json is modified externally, when background poll runs then active selection is cleared and future polling stops until app reselects")
    func backgroundPollClearsSelectionAndPausesAuthManagementAfterExternalChange() async throws {
        let root = try makeTempRoot("codex-auth-background-poll-pause-after-external-change")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let provider = makeCodexProvider(root: root)
        let configFile = root.folder("provider").file("config.toml")
        let originalConfig = """
        model = "o3"
        approval_policy = "on-request"
        """
        try configFile.overlay(with: originalConfig + "\n")

        let relay = try await manager.addConfiguredAccount(
            name: "Relay",
            apiKey: "rk-live-poll-1234",
            relay: .init(
                baseURL: "https://relay.example.com/v1",
                modelProvider: "provider-relay"
            )
        )
        try await manager.activateAccountAndMarkActive(relay, for: provider)

        let providerAuth = try #require(await manager.authFile(for: provider))
        let activeFile = STFile(try providerAuth.destinationOfSymbolicLink().url.path)
        let driftedRaw = #"""
        {
          "auth_mode": "chatgpt",
          "email": "poll-drifted@example.com",
          "tokens": {
            "id_token": "id-poll-drifted",
            "access_token": "access-poll-drifted",
            "account_id": "acct-poll-drifted"
          }
        }
        """#
        try activeFile.overlay(with: Data(driftedRaw.utf8))

        await manager.pollProviderAuthChange(for: provider, authFilePath: providerAuth.url.path)

        #expect(await manager.activeAccountId(for: provider) == nil)
        #expect(try configFile.read() == originalConfig + "\n")
        #expect(providerAuth.isExists == true)
        let preservedAuthRaw = try providerAuth.read()
        #expect(preservedAuthRaw.contains(#""email": "poll-drifted@example.com""#))

        await manager.pollProviderAuthChange(for: provider, authFilePath: providerAuth.url.path)
        #expect(await manager.activeAccountId(for: provider) == nil)
        #expect(try providerAuth.read() == preservedAuthRaw)
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
        let providerAuth = try #require(await manager.authFile(for: provider))
        let activeFile = STFile(try providerAuth.destinationOfSymbolicLink().url.path)
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
            guard let data = manager.accountAuthData(for: account) else { continue }
            let summary = CodexAuthSummary.fromJSONData(data)
            if summary.email == "newcomer@example.com" {
                newcomerCount += 1
            }
        }
        #expect(newcomerCount == 1)
    }
    @Test("Given duplicate snapshot ids and wrong relative path metadata, when loading accounts then id collision is healed and sqlite metadata stays consistent")
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

        let canonicalData = try #require(manager.accountAuthData(for: canonical))
        let canonicalRaw = try #require(String(data: canonicalData, encoding: .utf8))
        let polluted = canonicalRaw
            .replacingOccurrences(of: "canonical@example.com", with: "duplicate@example.com")
            .replacingOccurrences(of: "\"id-1\"", with: "\"id-2\"")
            .replacingOccurrences(of: "\"access-1\"", with: "\"access-2\"")
        try await manager.upsertCodexAccountInSQLite(duplicate, authData: Data(polluted.utf8))

        let accounts = try await manager.loadAccounts()
        #expect(accounts.count == 2)

        var accountByEmail: [String: CodexAuthAccount] = [:]
        for account in accounts {
            let summary = CodexAuthSummary.fromJSONData(manager.accountAuthData(for: account) ?? Data())
            if let email = summary.email?.lowercased() {
                accountByEmail[email] = account
            }
        }

        let canonicalAfter = try #require(accountByEmail["canonical@example.com"])
        let duplicateAfter = try #require(accountByEmail["duplicate@example.com"])
        #expect(canonicalAfter.id == canonical.id)
        #expect(duplicateAfter.id != canonical.id)

        let duplicateData = try #require(manager.accountAuthDataWithoutMaterialization(for: duplicateAfter))
        let duplicateJSON = try #require(try? JSON(data: duplicateData))
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

        let canonicalData = try #require(manager.accountAuthDataWithoutMaterialization(for: canonical))
        let canonicalRaw = try #require(String(data: canonicalData, encoding: .utf8))
        try await manager.updateAccount(duplicate, authJSONString: canonicalRaw)

        let accounts = try await manager.loadAccounts()
        #expect(accounts.count == 1)
        let kept = try #require(accounts.first)
        let keptSummary = CodexAuthSummary.fromJSONData(try #require(manager.accountAuthData(for: kept)))
        #expect(keptSummary.email?.lowercased() == "canonical@example.com")
        #expect(accounts.contains(where: { $0.id == duplicate.id }) == false)
    }
    @Test("Given sqlite-backed account metadata, when loading accounts then relative auth path remains stable and metadata stays normalized")
    func loadAccountsAlignsSnapshotFileNameWithEmailAndAccountID() async throws {
        let root = try makeTempRoot("codex-auth-align-file-name")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let account = try await manager.addAccount(
            name: "placeholder@example.com",
            authJSONString: #"{"email":"canonical@example.com","tokens":{"account_id":"acct-123","id_token":"id-1","access_token":"access-1"}}"#
        )

        let accounts = try await manager.loadAccounts()
        let aligned = try #require(accounts.first(where: { $0.id == account.id }))
        #expect(aligned.relativeAuthPath == account.relativeAuthPath)

        let alignedData = try #require(manager.accountAuthDataWithoutMaterialization(for: aligned))
        let json = try #require(try? JSON(data: alignedData))
        #expect(json["nolon"]["account"]["relativeAuthPath"].string == aligned.relativeAuthPath)
        #expect((json["email"].string ?? "").lowercased() == "canonical@example.com")
    }
    @Test("Given sqlite-backed account missing email, when backfilling email then relative auth path stays stable and payload email is updated")
    func backfillEmailEnablesEmailAccountIDAlignment() async throws {
        let root = try makeTempRoot("codex-auth-backfill-email-align")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let account = try await manager.addAccount(
            name: "account",
            authJSONString: #"{"tokens":{"account_id":"acct-raw","id_token":"id-raw","access_token":"access-raw"}}"#
        )
        try await manager.backfillEmailIfMissing(for: account, email: "fresh@example.com")

        let accounts = try await manager.loadAccounts()
        let aligned = try #require(accounts.first(where: { $0.id == account.id }))
        #expect(aligned.relativeAuthPath == account.relativeAuthPath)

        let alignedData = try #require(manager.accountAuthDataWithoutMaterialization(for: aligned))
        let json = try #require(try? JSON(data: alignedData))
        #expect((json["email"].string ?? "").lowercased() == "fresh@example.com")
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
            authJSONString: #"{"auth_mode":"chatgpt","email":"selected@example.com","tokens":{"account_id":"acct-selected","id_token":"id-selected","access_token":"access-selected"}}"#
        )
        let unselected = CodexAuthManager.CodexImportValidationResult(
            fileURL: unselectedURL,
            isValid: true,
            reason: nil,
            suggestedName: "Unselected",
            email: "unselected@example.com",
            authJSONString: #"{"auth_mode":"chatgpt","email":"unselected@example.com","tokens":{"account_id":"acct-unselected","id_token":"id-unselected","access_token":"access-unselected"}}"#
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

    private func configSnapshot(for file: STFile) throws -> (raw: String, modificationDate: Date?) {
        let values = try file.url.resourceValues(forKeys: [.contentModificationDateKey])
        return (try file.read(), values.contentModificationDate)
    }

    private func seedManagedRelayConfigState(
        manager: CodexAuthManager,
        configFile: STFile,
        accountID: UUID,
        providerID: String
    ) throws {
        let stateFile = manager
            .nolonCodexRootFolder()
            .folder("active-provider-config")
            .file("config.json")
        _ = stateFile.parentFolder()?.createIfNotExists()
        let state: [String: Any] = [
            configFile.url.standardizedFileURL.path: [
                "configFilePath": configFile.url.standardizedFileURL.path,
                "configExistedBeforePatch": true,
                "originalRawConfig": try configFile.read(),
                "managedProviderID": providerID,
                "managedAccountID": accountID.uuidString,
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: state, options: [.prettyPrinted, .sortedKeys])
        try stateFile.overlay(with: data)
    }
}
