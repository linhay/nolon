import Foundation
import Testing
import CodexBarProviderCatalog
@testable import ProviderUsage

@Suite("ProviderUsageMonitorService")
struct ProviderUsageMonitorServiceTests {
    @Test("Resolve codex environment merges managed env and cli path")
    func resolveCodexEnvironmentMergesManagedValues() async {
        let service = ProviderUsageMonitorService(
            tokenAccountStore: EmptyTokenAccountStore(),
            baseEnvironment: [
                "PATH": "/usr/bin",
                "CODEX_CLI_PATH": "/base/codex",
                "KEEP": "1",
            ],
            codexManagedEnvironmentLoader: {
                [
                    "PATH": "/managed/bin",
                    "OPENAI_API_BASE": "https://api.example.com",
                ]
            },
            codexCLIPathLoader: {
                "/managed/codex"
            }
        )

        let env = await service.resolveEnvironmentForFetch(provider: .codex)

        #expect(env["KEEP"] == "1")
        #expect(env["PATH"] == "/managed/bin")
        #expect(env["OPENAI_API_BASE"] == "https://api.example.com")
        #expect(env["CODEX_CLI_PATH"] == "/managed/codex")
    }

    @Test("Resolve non-codex environment keeps base unchanged")
    func resolveNonCodexEnvironmentKeepsBase() async {
        let service = ProviderUsageMonitorService(
            tokenAccountStore: EmptyTokenAccountStore(),
            baseEnvironment: [
                "PATH": "/usr/bin",
                "KEEP": "1",
            ],
            codexManagedEnvironmentLoader: {
                ["PATH": "/managed/bin"]
            },
            codexCLIPathLoader: {
                "/managed/codex"
            }
        )

        let env = await service.resolveEnvironmentForFetch(provider: .copilot)

        #expect(env["PATH"] == "/usr/bin")
        #expect(env["KEEP"] == "1")
        #expect(env["CODEX_CLI_PATH"] == nil)
    }

    @Test("Resolve cost window falls back to settings when override missing")
    func resolveCostWindowFallsBackToSettings() async {
        let service = ProviderUsageMonitorService(
            tokenAccountStore: EmptyTokenAccountStore(),
            baseEnvironment: [:],
            codexManagedEnvironmentLoader: { [:] },
            codexCLIPathLoader: { nil }
        )
        let settings = ProviderUsageMonitorSettings(costWindowDays: 21)

        let window = await service.resolveCostWindowDaysForFetch(
            settings: settings,
            overrideCostWindowDays: nil
        )

        #expect(window == 21)
    }

    @Test("Resolve cost window prefers override value")
    func resolveCostWindowPrefersOverride() async {
        let service = ProviderUsageMonitorService(
            tokenAccountStore: EmptyTokenAccountStore(),
            baseEnvironment: [:],
            codexManagedEnvironmentLoader: { [:] },
            codexCLIPathLoader: { nil }
        )
        let settings = ProviderUsageMonitorSettings(costWindowDays: 21)

        let window = await service.resolveCostWindowDaysForFetch(
            settings: settings,
            overrideCostWindowDays: 7
        )

        #expect(window == 7)
    }
}

private struct EmptyTokenAccountStore: ProviderTokenAccountStoring {
    func loadAccounts() throws -> [UsageProvider: ProviderTokenAccountData] { [:] }
    func storeAccounts(_ accounts: [UsageProvider: ProviderTokenAccountData]) throws {}
}
