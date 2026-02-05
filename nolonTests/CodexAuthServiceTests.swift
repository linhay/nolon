import XCTest
import STJSON
import ProviderUsage
import STFilePath
@testable import nolon

@MainActor
final class CodexAuthServiceTests: XCTestCase {
    func testBDD_GivenRealCodexAccount_WhenStoringUsageCache_ThenUsageCacheIsPersisted() async throws {
        let service = CodexAuthService()
        let accounts = try await service.loadAccounts()
        if accounts.isEmpty {
            throw XCTSkip("No codex accounts found under ~/.nolon/codex/auth")
        }

        let account = accounts[0]
        let file = await service.accountAuthFile(account)
        let fileURL = file.url
        let originalData = try Data(contentsOf: fileURL)
        defer {
            try? originalData.write(to: fileURL, options: [.atomic])
        }

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

        let data = try Data(contentsOf: fileURL)
        let json = try JSON(data: data)
        XCTAssertNotEqual(json["nolon"]["usage_cache"], JSON.null)
    }
}
