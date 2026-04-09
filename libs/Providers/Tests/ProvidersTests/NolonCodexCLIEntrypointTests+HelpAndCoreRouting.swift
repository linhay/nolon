import Foundation
import Testing
import CodexGatewayKit
@testable import NolonCoreCLIKit

extension NolonCodexCLIEntrypointTests {
    @Test("codex gateway stop routes successfully")
    func codexGatewayStopRoutesSuccessfully() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "gateway", "stop", "--json"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("\"command\":\"codex.gateway.stop\""))
        #expect(result.stdout.contains("\"status\":\"stopped\""))
        #expect(await mock.lastCall() == "gatewayStop")
    }
    @Test("codex runtime list --help prints action help")
    func codexRuntimeListHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "runtime", "list", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex runtime list"))
    }
    @Test("codex runtime stop --help prints action help")
    func codexRuntimeStopHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "runtime", "stop", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex runtime stop"))
        #expect(result.stdout.contains("--pid"))
    }
    @Test("codex provider discover --help prints action help")
    func codexProviderDiscoverHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "provider", "discover", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex provider discover"))
    }
    @Test("provider --help prints provider root help")
    func providerHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["provider", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon provider"))
        #expect(result.stdout.contains("Actions:"))
        #expect(result.stdout.contains("list"))
        #expect(result.stdout.contains("discover"))
    }
    @Test("provider discover --help prints action help")
    func providerDiscoverHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["provider", "discover", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon provider discover"))
    }
    @Test("skills --help prints skills help")
    func skillsHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["skills", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon skills"))
        #expect(result.stdout.contains("Subcommands:"))
        #expect(result.stdout.contains("list"))
        #expect(result.stdout.contains("sync"))
        #expect(result.stdout.contains("remove"))
    }
    @Test("skills repo without action returns missing subcommand error")
    func skillsRepoWithoutActionReturnsMissingSubcommandError() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["skills", "repo"],
            codexService: mock
        )

        #expect(result.exitCode == 2)
        #expect(result.stdout.isEmpty)
        #expect(result.stderr.contains("\"code\":\"invalid_arguments\""))
        #expect(result.stderr.contains("Missing command. Expected: skills repo <action> ..."))
    }
    @Test("skills migrate without action returns missing subcommand error")
    func skillsMigrateWithoutActionReturnsMissingSubcommandError() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["skills", "migrate"],
            codexService: mock
        )

        #expect(result.exitCode == 2)
        #expect(result.stdout.isEmpty)
        #expect(result.stderr.contains("\"code\":\"invalid_arguments\""))
        #expect(result.stderr.contains("Missing command. Expected: skills migrate <action> ..."))
    }
    @Test("workflow --help prints workflow help")
    func workflowHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["workflow", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon workflow"))
        #expect(result.stdout.contains("Subcommands:"))
        #expect(result.stdout.contains("list"))
    }
    @Test("mcp --help prints mcp help")
    func mcpHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["mcp", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon mcp"))
        #expect(result.stdout.contains("Subcommands:"))
        #expect(result.stdout.contains("list"))
    }
    @Test("remote --help prints remote help")
    func remoteHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["remote", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon remote"))
        #expect(result.stdout.contains("Actions:"))
        #expect(result.stdout.contains("download"))
        #expect(result.stdout.contains("install"))
    }
    @Test("provider list routes successfully")
    func providerListRoutesSuccessfully() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["provider", "list"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("provider"))
        #expect(result.stdout.contains("installed"))
        #expect(await mock.lastCall() == "providerList")
    }
    @Test("provider discover routes successfully")
    func providerDiscoverRoutesSuccessfully() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["provider", "discover"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("provider"))
        #expect(result.stdout.contains("installed"))
        #expect(await mock.lastCall() == "providerList")
    }
    @Test("remote root routes through core runner parser")
    func remoteRoutesThroughCoreRunnerParser() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "remote", "list",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("\"code\":\"invalid_arguments\""))
        #expect(result.stderr.contains("--kind"))
        #expect(await mock.lastCall() == nil)
    }
    @Test("skills repo plan routes through core runner")
    func skillsRepoPlanRoutesThroughCoreRunner() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "skills", "repo", "plan",
                "--source", "vercel/agent-skills",
                "--repositories-root", "/tmp/repos",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("\"command\":\"skills.repo.plan\""))
        #expect(await mock.lastCall() == nil)
    }
    @Test("skills search positional query is parsed by core runner")
    func skillsSearchPositionalQueryParsedByCoreRunner() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "skills", "search", "xcode",
                "--limit", "0",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("\"code\":\"invalid_arguments\""))
        #expect(result.stderr.contains("--limit"))
        #expect(await mock.lastCall() == nil)
    }
    @Test("skills add routes through core runner parser")
    func skillsAddRoutesThroughCoreRunnerParser() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "skills", "add", "xcode",
                "--provider", "codex",
                "--provider-id", "opencode",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("\"code\":\"invalid_arguments\""))
        #expect(result.stderr.contains("--provider"))
        #expect(await mock.lastCall() == nil)
    }
    @Test("skills list defaults to text output")
    func skillsListDefaultsToTextOutput() async throws {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "skills", "list",
                "--provider", "codex",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("providers_scanned:"))
        #expect(result.stdout.contains("skills_total:"))
        #expect(await mock.lastCall() == nil)
    }
    @Test("skills list without provider does not fail")
    func skillsListWithoutProviderDoesNotFail() async throws {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "skills", "list",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("providers_scanned:"))
        #expect(result.stdout.contains("skills_total:"))
        #expect(await mock.lastCall() == nil)
    }
    @Test("skills list supports json output")
    func skillsListSupportsJSONOutput() async throws {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "skills", "list",
                "--provider", "codex",
                "--json",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("\"command\":\"skills.list\""))
        #expect(await mock.lastCall() == nil)
    }
    @Test("skills list supports state filter")
    func skillsListSupportsStateFilter() async throws {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "skills", "list",
                "--provider", "codex",
                "--state", "orphaned",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("筛选-状态: 失效链接"))
        #expect(await mock.lastCall() == nil)
    }
    @Test("skills remove supports provider selector")
    func skillsRemoveSupportsProviderSelector() async throws {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "skills", "remove",
                "--skill-id", "react-best-practices",
                "--provider", "codex",
                "--json",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("\"command\":\"skills.uninstall\""))
        #expect(result.stdout.contains("\"skill_id\":\"react-best-practices\""))
        #expect(await mock.lastCall() == nil)
    }
    @Test("codex auth list --help prints action help")
    func codexAuthListHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "auth", "list", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex auth list"))
        #expect(result.stdout.contains("--provider"))
    }
    @Test("codex auth status --help prints action help")
    func codexAuthStatusHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "auth", "status", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex auth status"))
        #expect(result.stdout.contains("--provider"))
    }
    @Test("codex auth usage --help uses expanded custom help template")
    func codexAuthUsageHelpUsesExpandedCustomHelpTemplate() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "auth", "usage", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex auth usage [options]"))
        #expect(result.stdout.contains("--provider <id>                             # 指定 provider（可选"))
        #expect(result.stdout.contains("Options:") == false)
    }
    @Test("codex auth usage-trend --help prints action help")
    func codexAuthUsageTrendHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "auth", "usage-trend", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex auth usage-trend [options]"))
        #expect(result.stdout.contains("--range 7d|30d|all"))
    }
    @Test("codex auth refresh --help prints action help")
    func codexAuthRefreshHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "auth", "refresh", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex auth refresh"))
        #expect(result.stdout.contains("--account-id"))
        #expect(result.stdout.contains("切换为活跃账号"))
        #expect(result.stdout.contains("保持当前活跃账号不变"))
    }
    @Test("codex auth activate --help prints action help")
    func codexAuthActivateHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "auth", "activate", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex auth activate"))
        #expect(result.stdout.contains("--account-id"))
    }
    @Test("codex auth login --help prints action help")
    func codexAuthLoginHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "auth", "login", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex auth login"))
        #expect(result.stdout.contains("--preferred-account-id"))
    }
    @Test("codex auth delete --help prints action help")
    func codexAuthDeleteHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "auth", "delete", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex auth delete"))
        #expect(result.stdout.contains("--account-id"))
    }
    @Test("codex binary install --help prints action help")
    func codexBinaryInstallHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "binary", "install", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex binary install"))
        #expect(result.stdout.contains("--set-default"))
    }
    @Test("codex binary use --help prints action help")
    func codexBinaryUseHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "binary", "use", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex binary use"))
        #expect(result.stdout.contains("--version"))
    }
    @Test("codex binary list --help prints action help")
    func codexBinaryListHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "binary", "list", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex binary list"))
    }
    @Test("codex binary available --help prints action help")
    func codexBinaryAvailableHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "binary", "available", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex binary available"))
    }
    @Test("codex binary switch --help prints action help")
    func codexBinarySwitchHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "binary", "switch", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex binary switch"))
    }
    @Test("codex binary current --help prints action help")
    func codexBinaryCurrentHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "binary", "current", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex binary current"))
    }
}
