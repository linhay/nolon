import Foundation
import Testing
@testable import ProviderUsage

@Suite("GeminiAuthStore")
struct GeminiAuthStoreTests {
    @Test("stores gemini and antigravity accounts in isolated buckets")
    func providerIsolation() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("gemini-auth-store-\(UUID().uuidString)", isDirectory: true)
        let store = GeminiAuthStore(rootDirectory: root)

        let gemini = try await store.upsertAccount(
            provider: .gemini,
            name: "Gemini A",
            method: .oauthPersonal,
            email: "gemini@example.com",
            markActive: true,
            updateLastLoginAt: true
        )
        let antigravity = try await store.upsertAccount(
            provider: .antigravity,
            name: "AG A",
            method: .oauthPersonal,
            email: "ag@example.com",
            markActive: true,
            updateLastLoginAt: true
        )

        let geminiAccounts = try await store.listAccounts(provider: .gemini)
        let antigravityAccounts = try await store.listAccounts(provider: .antigravity)
        let geminiActive = try await store.activeAccount(provider: .gemini)
        let antigravityActive = try await store.activeAccount(provider: .antigravity)

        #expect(geminiAccounts.map(\.id) == [gemini.id])
        #expect(antigravityAccounts.map(\.id) == [antigravity.id])
        #expect(geminiActive?.id == gemini.id)
        #expect(antigravityActive?.id == antigravity.id)
    }

    @Test("delete promotes a new active account when deleting current active")
    func deletePromotesNewActive() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("gemini-auth-store-\(UUID().uuidString)", isDirectory: true)
        let store = GeminiAuthStore(rootDirectory: root)

        let first = try await store.upsertAccount(
            provider: .gemini,
            name: "A",
            method: .oauthPersonal,
            markActive: true
        )
        let second = try await store.upsertAccount(
            provider: .gemini,
            name: "B",
            method: .geminiAPIKey,
            markActive: true
        )
        #expect((try await store.activeAccount(provider: .gemini))?.id == second.id)

        try await store.delete(provider: .gemini, accountID: second.id)
        #expect((try await store.activeAccount(provider: .gemini))?.id == first.id)
    }

    @Test("runtimeHomeURL is deterministic and provider-scoped")
    func runtimeHomePathIsDeterministic() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("gemini-auth-store-\(UUID().uuidString)", isDirectory: true)
        let store = GeminiAuthStore(rootDirectory: root)
        let id = UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")!

        let geminiHome = try await store.runtimeHomeURL(provider: .gemini, accountID: id)
        let agHome = try await store.runtimeHomeURL(provider: .antigravity, accountID: id)

        #expect(geminiHome.path.contains("/gemini/accounts/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee/home"))
        #expect(agHome.path.contains("/antigravity/accounts/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee/home"))
    }

    @Test("detects import candidate from existing Gemini CLI login cache")
    func detectsImportCandidateFromGlobalGeminiLogin() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("gemini-auth-store-\(UUID().uuidString)", isDirectory: true)
        let home = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("gemini-auth-home-\(UUID().uuidString)", isDirectory: true)
        let globalGemini = home.appendingPathComponent(".gemini", isDirectory: true)
        try FileManager.default.createDirectory(at: globalGemini, withIntermediateDirectories: true)
        try Data("{\"access_token\":\"token\"}".utf8)
            .write(to: globalGemini.appendingPathComponent("oauth_creds.json"), options: .atomic)
        try Data("{\"active\":\"dev@example.com\",\"old\":[]}".utf8)
            .write(to: globalGemini.appendingPathComponent("google_accounts.json"), options: .atomic)

        let store = GeminiAuthStore(rootDirectory: root)
        let candidate = try await store.globalSessionImportCandidate(
            provider: .gemini,
            environment: ["HOME": home.path]
        )

        let resolved = try #require(candidate)
        #expect(resolved.provider == .gemini)
        #expect(resolved.email == "dev@example.com")
        #expect(resolved.geminiDirectoryPath.hasSuffix("/.gemini"))
        #expect(try await store.activeAccount(provider: .gemini) == nil)
        #expect(try await store.listAccounts(provider: .gemini).isEmpty)
    }

    @Test("imports only after explicit confirmation call")
    func importsOnlyAfterExplicitCall() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("gemini-auth-store-\(UUID().uuidString)", isDirectory: true)
        let home = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("gemini-auth-home-\(UUID().uuidString)", isDirectory: true)
        let globalGemini = home.appendingPathComponent(".gemini", isDirectory: true)
        try FileManager.default.createDirectory(at: globalGemini, withIntermediateDirectories: true)
        try Data("{\"access_token\":\"token\"}".utf8)
            .write(to: globalGemini.appendingPathComponent("oauth_creds.json"), options: .atomic)
        try Data("{\"active\":\"dev@example.com\",\"old\":[]}".utf8)
            .write(to: globalGemini.appendingPathComponent("google_accounts.json"), options: .atomic)

        let store = GeminiAuthStore(rootDirectory: root)
        #expect(try await store.activeAccount(provider: .gemini) == nil)
        let imported = try await store.importFromCLIGlobalSession(
            provider: .gemini,
            environment: ["HOME": home.path]
        )

        let account = try #require(imported)
        #expect(account.providerID == .gemini)
        #expect(account.email == "dev@example.com")
        #expect(try await store.activeAccount(provider: .gemini)?.id == account.id)

        let runtimeHome = try await store.runtimeHomeURL(provider: .gemini, accountID: account.id)
        let mirrored = runtimeHome
            .appendingPathComponent(".gemini", isDirectory: true)
            .appendingPathComponent("oauth_creds.json", isDirectory: false)
        #expect(FileManager.default.fileExists(atPath: mirrored.path))
    }

    @Test("import candidate keeps antigravity isolated from global gemini cache")
    func importCandidateDoesNotApplyToAntigravity() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("gemini-auth-store-\(UUID().uuidString)", isDirectory: true)
        let home = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("gemini-auth-home-\(UUID().uuidString)", isDirectory: true)
        let globalGemini = home.appendingPathComponent(".gemini", isDirectory: true)
        try FileManager.default.createDirectory(at: globalGemini, withIntermediateDirectories: true)
        try Data("{\"access_token\":\"token\"}".utf8)
            .write(to: globalGemini.appendingPathComponent("oauth_creds.json"), options: .atomic)

        let store = GeminiAuthStore(rootDirectory: root)
        let candidate = try await store.globalSessionImportCandidate(
            provider: .antigravity,
            environment: ["HOME": home.path]
        )
        let imported = try await store.importFromCLIGlobalSession(
            provider: .antigravity,
            environment: ["HOME": home.path]
        )

        #expect(candidate == nil)
        #expect(imported == nil)
        #expect(try await store.activeAccount(provider: .antigravity) == nil)
        #expect(try await store.listAccounts(provider: .antigravity).isEmpty)
    }
}
