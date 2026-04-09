import Foundation
import ArgumentParser
import STFilePath
import Testing
@testable import NolonCoreCLIKit
@testable import ProviderUsage

extension NolonCoreCLIKitTests {
    @Test("runner renders remote install workflow result with provider id")
    func runnerRendersRemoteInstallWorkflowResultWithProviderID() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "remote", "install",
                "--kind", "workflow",
                "--slug", "daily-review",
                "--provider-id", "opencode",
            ]
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("\"command\":\"remote.install\""))
        #expect(result.stdout.contains("\"kind\":\"workflow\""))
        #expect(result.stdout.contains("\"installed_path\""))
        #expect(result.stdout.contains("opencode\\/commands"))
        #expect(result.stdout.contains("\"resource_name\":\"daily-review.bin\""))
    }
    @Test("runner renders remote install mcp result with provider id")
    func runnerRendersRemoteInstallMCPResultWithProviderID() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "remote", "install",
                "--kind", "mcp",
                "--slug", "cursor-mcp",
                "--provider-id", "codex",
            ]
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("\"command\":\"remote.install\""))
        #expect(result.stdout.contains("\"kind\":\"mcp\""))
        #expect(result.stdout.contains("\"installed_path\""))
        #expect(result.stdout.contains(".codex"))
        #expect(result.stdout.contains("\"resource_name\":\"cursor-mcp.bin\""))
    }
    @Test("runner rejects unsupported provider id for remote install skill")
    func runnerRejectsUnsupportedProviderIDForRemoteInstallSkill() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "remote", "install",
                "--kind", "skill",
                "--slug", "react-best-practices",
                "--provider-id", "unknown-provider",
            ]
        )
        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("\"code\":\"invalid_arguments\""))
        #expect(result.stderr.contains("Unsupported --provider-id"))
    }
}
}
