import Foundation
import STFilePath
import Testing
import CopilotProvider
@testable import NolonCoreCLIKit
@testable import ProviderUsage

extension NolonCoreCLIKitTests {
    @Test("parse copilot auth login command")
    func parseCopilotAuthLogin() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "copilot", "auth", "login",
                "--token", "ghu_test_token",
                "--label", "Work",
            ]
        )

        guard case let .copilotAuthLogin(provider, token, label) = command else {
            Issue.record("Expected .copilotAuthLogin")
            return
        }
        #expect(provider == "copilot")
        #expect(token == "ghu_test_token")
        #expect(label == "Work")
    }

    @Test("parse copilot auth usage command")
    func parseCopilotAuthUsage() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "copilot", "auth", "usage",
            ]
        )

        guard case let .copilotAuthUsage(provider) = command else {
            Issue.record("Expected .copilotAuthUsage")
            return
        }
        #expect(provider == "copilot")
    }

    @Test("runner login, status, usage and delete work for copilot token auth")
    func runnerSupportsCopilotAuthLifecycle() async throws {
        let root = STFolder("/tmp").folder("nolon-copilot-cli-tests-\(UUID().uuidString)")
        _ = root.createIfNotExists()
        defer { try? root.delete() }

        let tokenStore = FileTokenAccountStore(file: root.file("token-accounts.json"))
        let now = Date(timeIntervalSince1970: 1_776_000_000)
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" },
            tokenAccountStore: tokenStore,
            copilotUsageFetchAction: { token in
                #expect(token == "ghu_test_token")
                return CopilotUsageSnapshot(
                    plan: "copilot-pro",
                    viewer: CopilotViewerProfile(login: "linhay", name: "Lin Hay", email: nil),
                    premiumQuota: CopilotQuota(
                        feature: "premium_interactions",
                        total: 100,
                        remaining: 75,
                        percentRemaining: 75
                    ),
                    chatQuota: CopilotQuota(
                        feature: "chat",
                        total: 100,
                        remaining: 55,
                        percentRemaining: 55
                    ),
                    quotaResetDate: "2026-04-16T00:00:00Z",
                    updatedAt: now
                )
            },
            copilotTokenResolver: { nil }
        )

        let login = await runner.execute(
            arguments: [
                "copilot", "auth", "login",
                "--token", "ghu_test_token",
                "--label", "Work",
            ]
        )
        #expect(login.exitCode == 0)
        #expect(login.stderr.isEmpty)
        #expect(login.stdout.contains("\"command\":\"copilot.auth.login\""))
        #expect(login.stdout.contains("\"provider\":\"copilot\""))
        #expect(login.stdout.contains("\"label\":\"Work\""))
        #expect(login.stdout.contains("\"plan\":\"Copilot Pro\""))

        let status = await runner.execute(
            arguments: [
                "copilot", "auth", "status",
            ]
        )
        #expect(status.exitCode == 0)
        #expect(status.stderr.isEmpty)
        #expect(status.stdout.contains("\"command\":\"copilot.auth.status\""))
        #expect(status.stdout.contains("\"account_count\":1"))
        #expect(status.stdout.contains("\"source\":\"token_account\""))

        let usage = await runner.execute(
            arguments: [
                "copilot", "auth", "usage",
            ],
            outputMode: .text
        )
        #expect(usage.exitCode == 0)
        #expect(usage.stderr.isEmpty)
        #expect(usage.stdout.contains("provider: copilot"))
        #expect(usage.stdout.contains("label: Work"))
        #expect(usage.stdout.contains("plan: Copilot Pro"))
        #expect(usage.stdout.contains("Chat"))
        #expect(usage.stdout.contains("Premium"))

        let delete = await runner.execute(
            arguments: [
                "copilot", "auth", "delete",
            ]
        )
        #expect(delete.exitCode == 0)
        #expect(delete.stderr.isEmpty)
        #expect(delete.stdout.contains("\"command\":\"copilot.auth.delete\""))
        #expect(delete.stdout.contains("\"account_count\":0"))
    }

    @Test("runner status and usage fall back to GitHub CLI token for copilot")
    func runnerSupportsCopilotGitHubCLIFallback() async throws {
        let root = STFolder("/tmp").folder("nolon-copilot-cli-gh-tests-\(UUID().uuidString)")
        _ = root.createIfNotExists()
        defer { try? root.delete() }

        let tokenStore = FileTokenAccountStore(file: root.file("token-accounts.json"))
        let now = Date(timeIntervalSince1970: 1_776_100_000)
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" },
            tokenAccountStore: tokenStore,
            copilotUsageFetchAction: { token in
                #expect(token == "ghu_cli_token")
                return CopilotUsageSnapshot(
                    plan: "copilot-pro",
                    viewer: CopilotViewerProfile(login: "linhay", name: "Lin Hay", email: nil),
                    premiumQuota: nil,
                    chatQuota: CopilotQuota(
                        feature: "chat",
                        total: 100,
                        remaining: 88,
                        percentRemaining: 88
                    ),
                    quotaResetDate: "2026-04-16T00:00:00Z",
                    updatedAt: now
                )
            },
            copilotTokenResolver: {
                "ghu_cli_token"
            }
        )

        let status = await runner.execute(
            arguments: [
                "copilot", "auth", "status",
            ]
        )
        #expect(status.exitCode == 0)
        #expect(status.stdout.contains("\"account_count\":1"))
        #expect(status.stdout.contains("\"label\":\"GitHub CLI\""))
        #expect(status.stdout.contains("\"source\":\"gh\""))

        let usage = await runner.execute(
            arguments: [
                "copilot", "auth", "usage",
            ],
            outputMode: .text
        )
        #expect(usage.exitCode == 0)
        #expect(usage.stdout.contains("label: linhay"))
        #expect(usage.stdout.contains("source: gh"))
        #expect(usage.stdout.contains("plan: Copilot Pro"))
    }
}
