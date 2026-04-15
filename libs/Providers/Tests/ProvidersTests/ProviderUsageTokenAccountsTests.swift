import Foundation
import Testing
@testable import ProviderUsage
import STFilePath

@Suite("ProviderUsage TokenAccounts")
struct ProviderUsageTokenAccountsTests {
    @Test("ProviderUsage default token accounts file path uses Nolon layout")
    func defaultTokenAccountsFilePathLayout() {
        let base = STFolder("/tmp").folder("provider-usage-base")
        let fileURL = ProviderUsagePaths.defaultTokenAccountsFileURL(baseDirectory: base.url)
        #expect(fileURL.path == "/tmp/provider-usage-base/Nolon/token-accounts.json")
    }

    @Test("FileTokenAccountStore supports STFile")
    func fileTokenAccountStoreSupportsSTFile() throws {
        let root = STFolder("/tmp")
            .folder("provider-token-accounts-\(UUID().uuidString)")
        _ = root.createIfNotExists()
        defer { try? root.delete() }

        let storeFile = root.folder("nested").file("token-accounts.json")
        let store = FileTokenAccountStore(file: storeFile)

        let account = ProviderTokenAccount(
            id: UUID(),
            label: "token-a",
            token: "tok-value",
            addedAt: 1_739_000_000,
            lastUsed: nil
        )
        let payload = ProviderTokenAccountData(version: 1, accounts: [account], activeIndex: 0)
        try store.storeAccounts([.codex: payload])

        let reloaded = try store.loadAccounts()
        #expect(storeFile.isExists == true)
        #expect(reloaded[.codex]?.accounts.first?.token == "tok-value")
    }

    @Test("GitHub CLI resolver prefers shell lookup when app PATH is incomplete")
    func gitHubCLITokenResolverPrefersShellLookup() {
        let payload = GitHubCLITokenResolver.makePayload(
            environment: ["PATH": "/usr/bin:/bin"],
            shellResolver: { binary, environment in
                #expect(binary == "gh")
                #expect(environment["PATH"]?.contains("/opt/homebrew/bin") == true)
                return URL(fileURLWithPath: "/opt/homebrew/bin/gh")
            },
            pathResolver: { _, _ in
                Issue.record("PATH resolver should not be used when shell resolver succeeds")
                return nil
            },
            shellEnvironmentLoader: { _ in
                [
                    "GH_CONFIG_DIR": "/Users/test/.config/gh",
                    "SHELL_ONLY_FLAG": "1",
                ]
            }
        )

        if case let .url(executableURL)? = payload?.executable {
            #expect(executableURL.path == "/opt/homebrew/bin/gh")
        } else {
            Issue.record("Expected GitHub CLI payload to resolve to a concrete executable URL")
        }
        #expect(payload?.environment?.values["PATH"]?.contains("/opt/homebrew/bin") == true)
        #expect(payload?.environment?.values["GH_CONFIG_DIR"] == "/Users/test/.config/gh")
        #expect(payload?.environment?.values["SHELL_ONLY_FLAG"] == "1")
    }

    @Test("GitHub CLI resolver supplements PATH with common binary locations")
    func gitHubCLITokenResolverSupplementsPATH() {
        let environment = GitHubCLITokenResolver.mergedEnvironment(["PATH": "/usr/bin:/bin"])
        let path = environment["PATH"] ?? ""

        #expect(path.contains("/usr/bin"))
        #expect(path.contains("/bin"))
        #expect(path.contains("/usr/local/bin"))
        #expect(path.contains("/opt/homebrew/bin"))
        #expect(path.contains("/usr/sbin"))
        #expect(path.contains("/sbin"))
    }

    @Test("GitHub CLI resolver merges user shell environment before explicit overrides")
    func gitHubCLITokenResolverMergesUserShellEnvironment() {
        let environment = GitHubCLITokenResolver.mergedEnvironment(
            [
                "GH_CONFIG_DIR": "/custom/gh",
                "EXPLICIT_FLAG": "1",
            ],
            shellEnvironmentLoader: { _ in
                [
                    "GH_CONFIG_DIR": "/shell/gh",
                    "SHELL_FLAG": "1",
                ]
            }
        )

        #expect(environment["GH_CONFIG_DIR"] == "/custom/gh")
        #expect(environment["SHELL_FLAG"] == "1")
        #expect(environment["EXPLICIT_FLAG"] == "1")
    }
}
