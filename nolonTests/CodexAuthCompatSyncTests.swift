import XCTest
import AppKit
import STJSON
import ProviderUsage
import STFilePath
import ProviderCatalog
import CodexBarProviderCatalog
import NolonResourceKit
@testable import nolon

@MainActor
final class CodexAuthCompatSyncTests: XCTestCase {
    func testBDD_GivenSelectedSnapshot_WhenActivating_ThenProviderAuthIsSymlinkedToSnapshot() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-compat-sync-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let service = CodexAuthManager(rootURL: root)
        let account = try await service.addAccount(
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

        try await service.activateAccount(account, for: provider)
        let maybeAuthFile = await service.authFile(for: provider)
        let authFile = try XCTUnwrap(maybeAuthFile)
        XCTAssertTrue(authFile.isSymbolicLink)
        let destination = try authFile.destinationOfSymbolicLink()
        let snapshotFile = service.nolonCodexRootFolder()
            .folder("active-auth")
            .folder("codex")
            .file("auth.json")
        XCTAssertEqual(
            STPath.standardizedPath(destination.url.path).path,
            STPath.standardizedPath(snapshotFile.url.path).path
        )
    }

    func testBDD_GivenFreshCLILogin_WhenFinalizing_ThenSyncsProviderAuthAndMarksActive() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-cli-finalize-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let service = CodexAuthManager(rootURL: root)
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

        let account = try await service.finalizeCLILogin(provider: provider, newAccountName: "cli")
        let active = await service.activeAccountId(for: provider)

        XCTAssertEqual(active, account.id)
        let authRawValue = try await service.readAuthJSONString(from: provider)
        let authRaw = try XCTUnwrap(authRawValue)
        let authJSON = try XCTUnwrap(try? JSON(data: Data(authRaw.utf8)))
        XCTAssertEqual(authJSON["tokens"]["id_token"].string, "id-2")
        XCTAssertEqual(authJSON["tokens"]["access_token"].string, "access-2")
    }

    func testBDD_GivenPreferredAccount_WhenUpsertingCLILogin_ThenUpdatesPreferredSnapshot() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-cli-upsert-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let service = CodexAuthManager(rootURL: root)
        let target = try await service.addAccount(
            name: "target",
            authJSONString: #"{"tokens":{"id_token":"old-id","access_token":"old-access"},"user":{"email":"a@example.com"}}"#
        )
        _ = try await service.addAccount(
            name: "other",
            authJSONString: #"{"tokens":{"id_token":"other","access_token":"other"},"user":{"email":"b@example.com"}}"#
        )

        let updated = try await service.upsertAccountFromCLILogin(
            authJSONString: #"{"tokens":{"id_token":"new-id","access_token":"new-access"},"user":{"email":"b@example.com"}}"#,
            preferredAccountID: target.id
        )

        XCTAssertEqual(updated.id, target.id)
        let pair = try await service.readTokenPair(for: updated)
        XCTAssertEqual(pair?.idToken, "new-id")
        XCTAssertEqual(pair?.accessToken, "new-access")
    }
}
