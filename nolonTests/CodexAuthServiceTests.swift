import XCTest
import AppKit
import STJSON
import ProviderUsage
import STFilePath
import ProviderCatalog
import CodexBarProviderCatalog
import NolonResourceKit
@testable import nolon

actor AsyncGate {
    private var continuation: CheckedContinuation<Void, Never>?

    func wait() async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func open() {
        continuation?.resume()
        continuation = nil
    }
}

@MainActor
final class CodexAuthManagerTests: XCTestCase {
    func testBDD_GivenIsolatedCodexAccount_WhenStoringUsageCache_ThenUsageCacheIsPersisted() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-auth-usage-cache-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let service = CodexAuthManager(rootURL: root)
        let account = try await service.addAccount(
            name: "isolated",
            authJSONString: #"{"tokens":{"id_token":"id-token","access_token":"access-token"},"user":{"email":"isolated@example.com"}}"#
        )
        let usage = UsageSnapshot(
            identity: UsageIdentity(accountEmail: "bdd@example.com", accountOrganization: nil, loginMethod: "oauth", plan: "plus"),
            primary: nil,
            secondary: nil,
            tertiary: nil,
            updatedAt: Date()
        )
        let credits = CreditsSnapshot(remaining: 42, updatedAt: Date())
        let cache = CodexAuthUsageCache(
            cachedAt: Date(),
            creditsRefreshedAt: credits.updatedAt,
            fetchKind: .cli,
            strategyKind: .direct,
            sourceLabel: "CLI",
            usage: usage,
            credits: credits,
            cost: nil
        )

        try await service.storeUsageCache(cache, for: account)

        let loaded = try await service.loadUsageCache(for: account)
        XCTAssertEqual(loaded, cache)

        let data = try XCTUnwrap(service.accountAuthData(for: account))
        let json = try JSON(data: data)
        XCTAssertNotEqual(json["nolon"]["usage_cache"], JSON.null)
    }

    func testBDD_GivenAuthFolderContainsTransientArtifacts_WhenLoadingAccounts_ThenOnlyStableJSONSnapshotsAreReturned() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-auth-folder-reload-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let service = CodexAuthManager(rootURL: root)
        let account = try await service.addAccount(
            name: "stable",
            authJSONString: #"{"tokens":{"id_token":"id","access_token":"access"},"user":{"email":"stable@example.com"}}"#
        )

        let authFolder = service.nolonCodexAuthFolder().url
        try FileManager.default.createDirectory(at: authFolder, withIntermediateDirectories: true)
        let tempArtifactURL = authFolder.appendingPathComponent(".dat.nosync2F9A.Hb0Ce3")
        let orphanedJSONURL = authFolder.appendingPathComponent("orphaned.json")
        try Data("temp".utf8).write(to: tempArtifactURL)
        try Data("not-json".utf8).write(to: orphanedJSONURL)

        let loadedAccounts = try await service.loadAccounts()

        XCTAssertEqual(loadedAccounts.map(\.id), [account.id])
        XCTAssertEqual(loadedAccounts.map(\.name), [account.name])
    }
}


final class CodexAuthChangeSuppressionStoreTests: XCTestCase {
    func testBDD_GivenUnseenEvent_WhenCheckingSuppression_ThenEventIsNotSuppressed() {
        // Given
        var store = CodexAuthChangeSuppressionStore()
        let now = Date()

        // When
        let suppressed = store.shouldSuppress(path: "/tmp/auth/modified.json", now: now)

        // Then
        XCTAssertFalse(suppressed)
    }

    func testBDD_GivenMarkedEventWithinWindow_WhenCheckingSuppression_ThenEventIsSuppressed() {
        // Given
        var store = CodexAuthChangeSuppressionStore()
        let now = Date()
        store.mark(filePath: "/tmp/auth/auth.json", folderPath: "/tmp/auth", ttl: 1.0, now: now)

        // When
        let suppressed = store.shouldSuppress(path: "/tmp/auth/auth.json", now: now.addingTimeInterval(0.2))

        // Then
        XCTAssertTrue(suppressed)
    }

    func testBDD_GivenMarkedEventAfterWindow_WhenCheckingSuppression_ThenEventIsNotSuppressed() {
        // Given
        var store = CodexAuthChangeSuppressionStore()
        let now = Date()
        store.mark(filePath: "/tmp/auth/auth.json", folderPath: "/tmp/auth", ttl: 0.5, now: now)

        // When
        let suppressed = store.shouldSuppress(path: "/tmp/auth/auth.json", now: now.addingTimeInterval(0.6))

        // Then
        XCTAssertFalse(suppressed)
    }

    func testBDD_GivenTwoDifferentEvents_WhenCheckingSuppression_ThenOnlyMarkedEventIsSuppressed() {
        // Given
        var store = CodexAuthChangeSuppressionStore()
        let now = Date()
        store.mark(filePath: "/tmp/auth/a.json", folderPath: "/tmp/auth", ttl: 1.0, now: now)

        // When
        let suppressedMarked = store.shouldSuppress(path: "/tmp/auth/a.json", now: now.addingTimeInterval(0.1))
        let suppressedUnmarked = store.shouldSuppress(path: "/tmp/other/b.json", now: now.addingTimeInterval(0.1))

        // Then
        XCTAssertTrue(suppressedMarked)
        XCTAssertFalse(suppressedUnmarked)
    }
}


@MainActor
final class CodexAuthTokenExtractionTests: XCTestCase {
    func testBDD_GivenAccountSnapshot_WhenReadingTokenPair_ThenReturnsIdAndAccessToken() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-auth-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let service = CodexAuthManager(rootURL: root)
        let raw = """
        {
          "tokens": {
            "id_token": "id-token-value",
            "access_token": "access-token-value"
          }
        }
        """
        let account = try await service.addAccount(name: "test", authJSONString: raw)

        let pair = try await service.readTokenPair(for: account)

        XCTAssertEqual(pair?.idToken, "id-token-value")
        XCTAssertEqual(pair?.accessToken, "access-token-value")
    }
}


@MainActor
final class CodexAuthActiveAccountRegistryTests: XCTestCase {
    func testBDD_GivenRuntimeActivatedAccount_WhenAuthFileMissing_ThenActiveAccountIdUsesRegistry() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-active-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let service = CodexAuthManager(rootURL: root)
        let account = try await service.addAccount(
            name: "runtime",
            authJSONString: #"{"tokens":{"id_token":"id","access_token":"access"}}"#
        )
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: root.appendingPathComponent("provider/skills").path,
            workflowPath: root.appendingPathComponent("provider/prompts").path,
            installMethod: .symlink,
            templateId: "codex"
        )

        try await service.setActiveAccount(account, for: provider)
        let active = await service.activeAccountId(for: provider)

        XCTAssertEqual(active, account.id)
    }
}
