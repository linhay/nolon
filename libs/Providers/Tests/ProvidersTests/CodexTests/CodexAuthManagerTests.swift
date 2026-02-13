import Foundation
import Testing
import ProviderCatalog
import STFilePath
@testable import ProviderUsage

@Suite("CodexAuthManager")
struct CodexAuthManagerTests {
    @Test("Given NOLON_HOME env, when manager uses default root, then snapshots root is isolated to env path")
    func defaultRootRespectsNolonHomeEnv() async throws {
        let isolatedRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("nolon-home-auth-\(UUID().uuidString)", isDirectory: true)
            .standardizedFileURL

        let manager = CodexAuthManager(
            environment: ["NOLON_HOME": isolatedRoot.path]
        )

        let codexRoot = manager.nolonCodexRootFolder()
        let expected = STFolder(isolatedRoot).folder("codex")
        #expect(codexRoot == expected)
    }

    @Test("Given account snapshot, when reading token pair, then returns id/access token")
    func readTokenPairFromSnapshot() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-auth-manager-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = CodexAuthManager(rootURL: root)
        let account = try await manager.addAccount(
            name: "test",
            authJSONString: #"{"tokens":{"id_token":"id-token-value","access_token":"access-token-value"}}"#
        )

        let pair = try await manager.readTokenPair(for: account)
        #expect(pair?.idToken == "id-token-value")
        #expect(pair?.accessToken == "access-token-value")
    }

    @Test("Given selected snapshot, when activating account, then provider auth is cleaned and synced")
    func activateAccountWritesCleanProviderAuth() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-auth-clean-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = CodexAuthManager(rootURL: root)
        let account = try await manager.addAccount(
            name: "work",
            authJSONString: #"{"tokens":{"id_token":"id-1","access_token":"access-1"},"nolon":{"usage_cache":{"fetch_kind":"api"}}}"#
        )
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: root.appendingPathComponent("provider/skills").path,
            workflowPath: root.appendingPathComponent("provider/prompts").path,
            installMethod: .symlink,
            templateId: "codex"
        )

        try await manager.activateAccount(account, for: provider)
        let raw = try #require(await manager.readAuthJSONString(from: provider))
        let data = try #require(raw.data(using: .utf8))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let tokens = try #require(object["tokens"] as? [String: Any])

        #expect(tokens["id_token"] as? String == "id-1")
        #expect(tokens["access_token"] as? String == "access-1")
        #expect(object["nolon"] == nil)
    }

    @Test("Given activated snapshot via unified activation, when provider auth is deleted, then active account still resolves from registry")
    func activateAccountAndMarkActivePersistsRegistry() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-auth-activate-mark-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = CodexAuthManager(rootURL: root)
        let account = try await manager.addAccount(
            name: "work",
            authJSONString: #"{"tokens":{"id_token":"id-1","access_token":"access-1"}}"#
        )
        let providerRoot = root.appendingPathComponent("provider", isDirectory: true)
        try FileManager.default.createDirectory(at: providerRoot, withIntermediateDirectories: true)
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: providerRoot.appendingPathComponent("skills").path,
            workflowPath: providerRoot.appendingPathComponent("prompts").path,
            installMethod: .symlink,
            templateId: "codex"
        )

        try await manager.activateAccountAndMarkActive(account, for: provider)
        try FileManager.default.removeItem(at: providerRoot.appendingPathComponent("auth.json"))

        let activeId = await manager.activeAccountId(for: provider)
        #expect(activeId == account.id)
    }

    @Test("Given fresh CLI login, when finalizing, then account is active and provider auth contains new token")
    func finalizeCLILoginSyncsAndMarksActive() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-auth-finalize-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = CodexAuthManager(rootURL: root)
        let providerRoot = root.appendingPathComponent("provider", isDirectory: true)
        try FileManager.default.createDirectory(at: providerRoot, withIntermediateDirectories: true)

        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: providerRoot.appendingPathComponent("skills").path,
            workflowPath: providerRoot.appendingPathComponent("prompts").path,
            installMethod: .symlink,
            templateId: "codex"
        )

        let authURL = providerRoot.appendingPathComponent("auth.json")
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
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-auth-record-cli-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = CodexAuthManager(rootURL: root)
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
}
