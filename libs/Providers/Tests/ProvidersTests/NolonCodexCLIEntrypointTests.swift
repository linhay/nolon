import Foundation
import Testing
@testable import NolonCoreCLIKit

@Suite("Nolon Codex CLI Entrypoint")
struct NolonCodexCLIEntrypointTests {
    @Test("no arguments prints help instead of JSON error")
    func noArgumentsPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(arguments: [], codexService: mock)

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("USAGE: nolon"))
        #expect(result.stdout.contains("SUBCOMMANDS"))
        #expect(result.stdout.contains("skills"))
        #expect(result.stdout.contains("workflow"))
        #expect(result.stdout.contains("mcp"))
        #expect(result.stdout.contains("remote"))
    }

    @Test("leading help command resolves codex action help")
    func leadingHelpCommandResolvesCodexActionHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["help", "codex", "auth", "refresh"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex auth refresh"))
        #expect(result.stdout.contains("切换为活跃账号"))
    }

    @Test("codex --help prints codex help")
    func codexHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon <provider> <group> <action> [options]"))
        #expect(result.stdout.contains("Groups:"))
        #expect(result.stdout.contains("auth"))
        #expect(result.stdout.contains("binary"))
    }

    @Test("skills --help includes task-oriented examples")
    func skillsHelpIncludesExamples() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["skills", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("场景: 搜索技能"))
        #expect(result.stdout.contains("场景: 安装技能"))
        #expect(result.stdout.contains("场景: 修复异常"))
        #expect(result.stdout.contains("nolon skills search xcode"))
        #expect(result.stdout.contains("<keyword> | --query <query>"))
        #expect(result.stdout.contains("--query <query>"))
        #expect(result.stdout.contains("--pick <index>"))
        #expect(result.stdout.contains("nolon skills add xcode --provider codex"))
        #expect(result.stdout.contains("省略 --provider 可能触发多 provider 批量写入/覆盖"))
    }

    @Test("skills search --help explains install and pick relation")
    func skillsSearchHelpExplainsInstallPickRelation() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["skills", "search", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Install matched skill(s);"))
        #expect(result.stdout.contains("Pick one search result by 1-based index"))
        #expect(result.stdout.contains("Target provider ID. Omit to distribute to all"))
        #expect(result.stdout.contains("nolon skills search \"swiftui\" --install --pick 1 --provider codex --dry-run"))
    }

    @Test("skills add --help warns about provider omission scope")
    func skillsAddHelpWarnsAboutProviderOmissionScope() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["skills", "add", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Target provider ID. Omit to distribute to all"))
        #expect(result.stdout.contains("nolon skills add swift-concurrency-expert --provider codex --dry-run"))
    }

    @Test("skills remove --help shows safety note and example")
    func skillsRemoveHelpShowsSafetyNoteAndExample() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["skills", "remove", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("该操作会直接移除 provider 下的技能链接/目录"))
        #expect(result.stdout.contains("nolon skills list --provider <id>"))
        #expect(result.stdout.contains("nolon skills remove --skill-id xcode --provider codex"))
    }

    @Test("codex without group action prints codex help")
    func codexWithoutActionPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon <provider> <group> <action> [options]"))
        #expect(result.stdout.contains("Groups:"))
    }

    @Test("codex auth --help prints auth help")
    func codexAuthHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "auth", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex auth"))
        #expect(result.stdout.contains("Actions:"))
    }

    @Test("codex auth without action prints auth help")
    func codexAuthWithoutActionPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "auth"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex auth"))
        #expect(result.stdout.contains("Actions:"))
    }

    @Test("codex binary --help prints binary help")
    func codexBinaryHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "binary", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex binary"))
        #expect(result.stdout.contains("Actions:"))
        #expect(result.stdout.contains("install"))
        #expect(result.stdout.contains("available"))
    }

    @Test("codex binary without action prints binary help")
    func codexBinaryWithoutActionPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "binary"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex binary"))
        #expect(result.stdout.contains("Actions:"))
    }

    @Test("codex status --help prints status help")
    func codexStatusHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "status", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex status"))
        #expect(result.stdout.contains("Actions:"))
        #expect(result.stdout.contains("probe"))
        #expect(result.stdout.contains("doctor"))
    }

    @Test("codex status without action prints status help")
    func codexStatusWithoutActionPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "status"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex status"))
        #expect(result.stdout.contains("Actions:"))
    }

    @Test("codex runtime --help prints runtime help")
    func codexRuntimeHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "runtime", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex runtime"))
        #expect(result.stdout.contains("Actions:"))
        #expect(result.stdout.contains("list"))
        #expect(result.stdout.contains("stop"))
    }

    @Test("codex provider --help prints provider help")
    func codexProviderHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "provider", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex provider"))
        #expect(result.stdout.contains("Actions:"))
        #expect(result.stdout.contains("discover"))
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

    @Test("codex binary doctor --help prints action help")
    func codexBinaryDoctorHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "binary", "doctor", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex binary doctor"))
    }

    @Test("codex status probe --help prints action help")
    func codexStatusProbeHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "status", "probe", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex status probe"))
        #expect(result.stdout.contains("--provider"))
    }

    @Test("codex status doctor --help prints action help")
    func codexStatusDoctorHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "status", "doctor", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex status doctor"))
    }

    @Test("routes auth list")
    func routesAuthList() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "auth", "list",
                "--provider", "codex",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("[账号]"))
        #expect(result.stdout.contains("[用量]"))
        #expect(result.stdout.contains("[状态]"))
        #expect(result.stdout.contains("邮箱"))
        #expect(result.stdout.contains("状态"))
        #expect(result.stdout.contains("令牌健康"))
        #expect(result.stdout.contains("5h剩余"))
    }

    @Test("routes auth usage per-account table")
    func routesAuthUsage() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "auth", "usage",
                "--provider", "codex",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("[账号]"))
        #expect(result.stdout.contains("[用量]"))
        #expect(result.stdout.contains("[状态]"))
        #expect(result.stdout.contains("5h剩余"))
        #expect(result.stdout.contains("7d剩余"))
        #expect(result.stdout.contains("Tokens汇总 | 1d"))
        #expect(result.stdout.contains("| all"))
        #expect(result.stdout.contains("Access:"))
        #expect(result.stdout.contains("Refresh:"))
    }

    @Test("routes auth usage refresh with summary")
    func routesAuthUsageRefreshSummary() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "auth", "usage",
                "--provider", "codex",
                "--summary",
                "--refresh",
                "--account-id", "11111111-1111-1111-1111-111111111111",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("账号总数"))
        #expect(await mock.lastCall() == "authUsageRefresh")
    }

    @Test("auth usage target requires refresh flag")
    func authUsageTargetRequiresRefreshFlag() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "auth", "usage",
                "--provider", "codex",
                "--account-id", "11111111-1111-1111-1111-111111111111",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("\"code\":\"invalid_arguments\""))
        #expect(result.stderr.contains("requires --refresh"))
    }

    @Test("auth usage summary renders aggregated rows")
    func authUsageSummaryRenders() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "auth", "usage",
                "--provider", "codex",
                "--summary",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("账号总数"))
        #expect(result.stdout.contains("已缓存用量"))
        #expect(result.stdout.contains("5h平均剩余"))
        #expect(result.stdout.contains("Tokens | 1d"))
        #expect(result.stdout.contains("| all"))
    }

    @Test("auth usage expiry shows relative remaining and expired labels")
    func authUsageExpiryShowsRelativeLabels() async {
        let service = AuthUsageExpiryLabelCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "auth", "usage", "--provider", "codex"],
            codexService: service
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("剩余"))
        #expect(result.stdout.contains("已过期"))
        #expect(result.stdout.contains("Refresh:可用"))
    }

    @Test("auth usage shows fallback hint when all token sources are global")
    func authUsageShowsGlobalFallbackHint() async {
        let service = AuthUsageGlobalFallbackCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "auth", "usage", "--provider", "codex"],
            codexService: service
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("提示: 当前 Tokens 来自全局回退"))
    }

    @Test("auth usage hides per-account tokens when source is not distinguishable")
    func authUsageHidesPerAccountTokensWhenNotDistinguishable() async {
        let service = AuthUsageUndistinguishableTokensCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "auth", "usage", "--provider", "codex"],
            codexService: service
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Tokens汇总 | 1d"))
        #expect(!result.stdout.contains("Tokens 当前无法按账号区分"))
    }

    @Test("auth usage overview resolves active account consistently by status")
    func authUsageOverviewResolvesActiveAccountByStatus() async {
        let service = AuthUsageActiveConsistencyCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "auth", "usage", "--provider", "codex"],
            codexService: service
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("激活账号"))
        #expect(result.stdout.contains("BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB"))
        #expect(result.stdout.contains("* second@example.com"))
        #expect(!result.stdout.contains("* first@example.com"))
    }

    @Test("auth list prints aligned table rows")
    func authListPrintsAlignedTableRows() async {
        let service = AuthListTableCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "auth", "list", "--provider", "codex"],
            codexService: service
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        let lines = result.stdout.split(separator: "\n").map(String.init)
        let headerIndex = lines.firstIndex { $0.contains("邮箱") && $0.contains("状态") && $0.contains("令牌健康") }
        #expect(headerIndex != nil)
        let rows = lines
            .dropFirst((headerIndex ?? 0) + 1)
            .prefix { !$0.hasPrefix("[用量]") && !$0.hasPrefix("[状态]") }
            .filter { $0.hasPrefix("* ") || ($0.hasPrefix("  ") && $0.contains(" | ")) }
        #expect(rows.count == 2)
        let firstPipeIndices = rows[0].indicesOfPipes()
        #expect(firstPipeIndices.count == 2)
        #expect(rows[1].indicesOfPipes() == firstPipeIndices)
    }

    @Test("auth list shows dash when email usage refresh are missing")
    func authListShowsDashForMissingFields() async {
        let service = AuthListMissingFieldsCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "auth", "list", "--provider", "codex"],
            codexService: service
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("| -"))
    }

    @Test("normalizes codexxcode provider alias")
    func normalizesCodexXcodeProviderAlias() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "auth", "list",
                "--provider", "codexxcode",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("邮箱"))
    }

    @Test("auth list rejects unsupported provider")
    func authListRejectsUnsupportedProvider() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "auth", "list",
                "--provider", "claude",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("\"code\":\"invalid_arguments\""))
    }

    @Test("routes auth status")
    func routesAuthStatus() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "auth", "status",
                "--provider", "codex",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("[账号]"))
        #expect(result.stdout.contains("[用量]"))
        #expect(result.stdout.contains("[状态]"))
        #expect(result.stdout.contains("账号总数"))
        #expect(result.stdout.contains("已缓存用量"))
    }

    @Test("auth status rejects unsupported provider")
    func authStatusRejectsUnsupportedProvider() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "auth", "status",
                "--provider", "cursor",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("\"code\":\"invalid_arguments\""))
    }

    @Test("routes auth activate via argument parser")
    func routesAuthActivate() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "auth", "activate",
                "--provider", "codex",
                "--account-id", "11111111-1111-1111-1111-111111111111",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("runtime_switched: true"))
        #expect(result.stderr.isEmpty)
        #expect(await mock.lastCall() == "authActivate")
    }

    @Test("routes auth refresh via account id")
    func routesAuthRefresh() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "auth", "refresh",
                "--provider", "codex",
                "--account-id", "11111111-1111-1111-1111-111111111111",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("* mock@example.com"))
        #expect(result.stdout.contains("| 已激活 | 成功"))
        #expect(result.stdout.contains("运行时切换"))
        #expect(result.stdout.contains("汇总-总数: 1"))
        #expect(await mock.lastCall() == "authRefresh")
    }

    @Test("auth activate supports tui selection by index")
    func authActivateSupportsTUISelection() async throws {
        let accounts: [NolonCodexAuthAccountView] = [
            NolonCodexAuthAccountView(
                id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
                name: "A",
                createdAt: .distantPast,
                relativeAuthPath: "a/auth.json",
                isActive: true,
                email: "a@example.com",
                usageDisplay: nil,
                refreshedAt: nil
            ),
            NolonCodexAuthAccountView(
                id: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
                name: "B",
                createdAt: .distantPast,
                relativeAuthPath: "b/auth.json",
                isActive: false,
                email: "b@example.com",
                usageDisplay: nil,
                refreshedAt: nil
            ),
        ]

        let selected = try NolonCodexCLIExecutor.parseActivateSelection(
            input: "2",
            accounts: accounts
        )
        #expect(selected == UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!)
    }

    @Test("auth activate supports tui selection by email")
    func authActivateSupportsTUISelectionByEmail() throws {
        let accounts: [NolonCodexAuthAccountView] = [
            NolonCodexAuthAccountView(
                id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
                name: "A",
                createdAt: .distantPast,
                relativeAuthPath: "a/auth.json",
                isActive: true,
                email: "a@example.com",
                usageDisplay: nil,
                refreshedAt: nil
            ),
            NolonCodexAuthAccountView(
                id: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
                name: "B",
                createdAt: .distantPast,
                relativeAuthPath: "b/auth.json",
                isActive: false,
                email: "b@example.com",
                usageDisplay: nil,
                refreshedAt: nil
            ),
        ]

        let selected = try NolonCodexCLIExecutor.parseActivateSelection(
            input: "B@Example.com",
            accounts: accounts
        )
        #expect(selected == UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!)
    }

    @Test("auth activate picker shows usage in table rows")
    func authActivatePickerShowsUsage() {
        let accounts: [NolonCodexAuthAccountView] = [
            NolonCodexAuthAccountView(
                id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
                name: "A",
                createdAt: .distantPast,
                relativeAuthPath: "a/auth.json",
                isActive: true,
                email: "a@example.com",
                usageDisplay: "5h 80% / 7d 50%",
                refreshedAt: nil
            ),
        ]

        let text = NolonCodexCLIExecutor.renderActivatePicker(accounts: accounts)
        #expect(text.contains("编号 | 状态 | 邮箱"))
        #expect(text.contains("5h 80% / 7d 50%"))
        #expect(text.contains("AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"))
    }

    @Test("auth activate tui selection rejects invalid index")
    func authActivateTUISelectionRejectsInvalidIndex() {
        let accounts: [NolonCodexAuthAccountView] = [
            NolonCodexAuthAccountView(
                id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
                name: "A",
                createdAt: .distantPast,
                relativeAuthPath: "a/auth.json",
                isActive: true,
                email: "a@example.com",
                usageDisplay: nil,
                refreshedAt: nil
            ),
        ]

        #expect(throws: NolonCoreCLIError.invalidArguments("Invalid selection")) {
            _ = try NolonCodexCLIExecutor.parseActivateSelection(input: "3", accounts: accounts)
        }
    }

    @Test("invalid UUID returns structured error")
    func invalidUUIDError() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "auth", "activate",
                "--account-id", "not-a-uuid",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 2)
        #expect(result.stdout.isEmpty)
        #expect(result.stderr.contains("\"code\":\"invalid_arguments\""))
    }

    @Test("auth activate without account id defaults to interactive flow")
    func authActivateDefaultsToInteractiveFlow() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "auth", "activate",
                "--provider", "codex",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("Interactive selection requires a TTY terminal. Use --account-id <uuid> or --email <email>."))
    }

    @Test("auth activate supports email option for non-interactive usage")
    func authActivateSupportsEmailOption() async {
        let mock = EmailActivateCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "auth", "activate",
                "--provider", "codex",
                "--email", "a@example.com",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("account_id: AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"))
    }

    @Test("invalid preferred account UUID returns structured error")
    func invalidPreferredUUIDError() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "auth", "login",
                "--preferred-account-id", "bad-uuid",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("\"code\":\"invalid_arguments\""))
    }

    @Test("routes auth login")
    func routesAuthLogin() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "auth", "login",
                "--provider", "codex",
                "--preferred-account-id", "11111111-1111-1111-1111-111111111111",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("account_name: mock"))
        #expect(result.stdout.contains("login_url: https://auth.example.com/device"))
        #expect(await mock.lastCall() == "authLogin")
    }

    @Test("routes auth delete")
    func routesAuthDelete() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "auth", "delete",
                "--provider", "codex",
                "--account-id", "11111111-1111-1111-1111-111111111111",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("was_active: false"))
        #expect(await mock.lastCall() == "authDelete")
    }

    @Test("routes binary install set-default")
    func routesBinaryInstall() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "binary", "install",
                "0.26.0",
                "--set-default",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("requested_version: 0.26.0"))
        #expect(await mock.lastCall() == "binaryInstall")
    }

    @Test("binary install rejects empty version")
    func binaryInstallRejectsEmptyVersion() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "binary", "install",
                "   ",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("\"code\":\"invalid_arguments\""))
    }

    @Test("routes binary current")
    func routesBinaryCurrent() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "binary", "current",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("current_version: -"))
        #expect(await mock.lastCall() == "binaryCurrent")
    }

    @Test("routes binary available")
    func routesBinaryAvailable() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "binary", "available",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(await mock.lastCall() == "binaryAvailable")
    }

    @Test("routes binary use")
    func routesBinaryUse() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "binary", "use",
                "--version", "0.26.0",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("selected_version_id: 0.26.0"))
        #expect(await mock.lastCall() == "binaryUse")
    }

    @Test("binary use rejects empty version")
    func binaryUseRejectsEmptyVersion() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "binary", "use",
                "--version", "\t",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("\"code\":\"invalid_arguments\""))
    }

    @Test("binary switch rejects non-tty")
    func binarySwitchRejectsNonTTY() async {
        let service = BinarySwitchCodexCLIService(
            installed: NolonCodexBinaryListPayload(selectedVersionID: nil, versions: []),
            available: NolonCodexBinaryAvailablePayload(versions: [])
        )
        let overrides = NolonCodexCLIExecutor.IOOverrides(
            isTTY: { false },
            readInputLine: { "1" },
            writePrompt: { _ in }
        )

        let result = await NolonCodexCLIExecutor.withIOOverrides(overrides) {
            await NolonCLIEntrypoint.execute(
                arguments: ["codex", "binary", "switch"],
                codexService: service
            )
        }

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("\"code\":\"invalid_arguments\""))
        #expect(result.stderr.contains("Interactive selection requires a TTY"))
    }

    @Test("binary switch activates installed version")
    func binarySwitchActivatesInstalledVersion() async {
        let service = BinarySwitchCodexCLIService(
            installed: NolonCodexBinaryListPayload(
                selectedVersionID: "v0.26.0",
                versions: [
                    NolonCodexManagedVersionView(
                        id: "v0.26.0",
                        displayName: "Codex 0.26.0",
                        detectedVersion: "0.26.0",
                        source: "release",
                        importedAt: .distantPast,
                        isSelected: true
                    )
                ]
            ),
            available: NolonCodexBinaryAvailablePayload(versions: [])
        )
        let overrides = NolonCodexCLIExecutor.IOOverrides(
            isTTY: { true },
            readInputLine: { "1" },
            writePrompt: { _ in }
        )

        let result = await NolonCodexCLIExecutor.withIOOverrides(overrides) {
            await NolonCLIEntrypoint.execute(
                arguments: ["codex", "binary", "switch"],
                codexService: service
            )
        }

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("action: activate"))
        #expect(result.stdout.contains("selected_version_id: v0.26.0"))
        #expect(await service.lastCall() == "binaryUse")
    }

    @Test("binary switch installs available version")
    func binarySwitchInstallsAvailableVersion() async {
        let service = BinarySwitchCodexCLIService(
            installed: NolonCodexBinaryListPayload(selectedVersionID: nil, versions: []),
            available: NolonCodexBinaryAvailablePayload(
                versions: [
                    NolonCodexRemoteVersionView(
                        version: "0.100.0",
                        tag: "rust-v0.100.0",
                        downloadURL: "https://example.com/codex.tar.gz",
                        isPrerelease: false
                    )
                ]
            )
        )
        let overrides = NolonCodexCLIExecutor.IOOverrides(
            isTTY: { true },
            readInputLine: { "1" },
            writePrompt: { _ in }
        )

        let result = await NolonCodexCLIExecutor.withIOOverrides(overrides) {
            await NolonCLIEntrypoint.execute(
                arguments: ["codex", "binary", "switch"],
                codexService: service
            )
        }

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("action: install"))
        #expect(result.stdout.contains("requested_version: 0.100.0"))
        #expect(await service.lastCall() == "binaryInstall")
    }

    @Test("routes binary doctor")
    func routesBinaryDoctor() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "binary", "doctor",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("profile_path: ~/.zshrc"))
        #expect(await mock.lastCall() == "binaryDoctor")
    }

    @Test("binary list prints concise one-line items instead of json")
    func binaryListPrintsConciseOneLineItems() async {
        let service = BinaryListPlainTextCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "binary", "list"],
            codexService: service
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        let lines = result.stdout.split(separator: "\n").map(String.init)
        #expect(lines.count == 2)
        #expect(lines[0].contains("* 0.26.0"))
        #expect(lines[1].contains("  0.9.0"))
        #expect(lines[0].contains("Codex 0.26.0"))
        #expect(lines[1].contains("X"))
        #expect(lines[0].contains("v0.26.0"))
        #expect(lines[1].contains("v0.9.0"))
        #expect(!result.stdout.contains("\"command\":\"codex.binary.list\""))
        #expect(!result.stdout.contains("\"ok\":true"))

        let firstPipeIndices = lines[0].indicesOfPipes()
        #expect(firstPipeIndices.count == 3)
        #expect(lines[1].indicesOfPipes() == firstPipeIndices)
    }

    @Test("routes status probe")
    func routesStatusProbe() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "status", "probe",
                "--provider", "codex",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("resolved_executable"))
        #expect(result.stdout.contains("| /opt/homebrew/bin/codex"))
        #expect(await mock.lastCall() == "statusProbe")
    }

    @Test("status probe degrades parse errors to warning output")
    func statusProbeDegradesParseErrorsToWarning() async {
        let mock = StatusProbeParseErrorCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "status", "probe", "--provider", "codex"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("probe_warning"))
        #expect(result.stdout.contains("Could not parse Codex status"))
        #expect(result.stdout.contains("probe_hint"))
        #expect(result.stdout.contains("nolon codex status doctor --json"))
    }

    @Test("routes runtime list")
    func routesRuntimeList() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "runtime", "list"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("PID"))
        #expect(result.stdout.contains("运行时长"))
        #expect(await mock.lastCall() == "runtimeList")
    }

    @Test("routes runtime stop")
    func routesRuntimeStop() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "runtime", "stop", "--pid", "12345"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("pid: 12345"))
        #expect(result.stdout.contains("signal: term"))
        #expect(await mock.lastCall() == "runtimeStop")
    }

    @Test("routes provider discover")
    func routesProviderDiscover() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "provider", "discover"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("provider"))
        #expect(result.stdout.contains("auth_state"))
        #expect(await mock.lastCall() == "providerDiscover")
    }

    @Test("runtime stop rejects invalid pid")
    func runtimeStopRejectsInvalidPID() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "runtime", "stop", "--pid", "0"],
            codexService: mock
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("\"code\":\"invalid_arguments\""))
    }

    @Test("status probe prints aligned table rows")
    func statusProbePrintsAlignedTableRows() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "status", "probe",
                "--provider", "codex",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        let rows = result.stdout.split(separator: "\n").map(String.init)
        #expect(rows.count >= 6)
        let firstPipeIndex = rows[0].firstIndex(of: "|")
        #expect(firstPipeIndex != nil)
        for row in rows {
            #expect(row.firstIndex(of: "|") == firstPipeIndex)
        }
    }

    @Test("normalizes provider alias in status probe")
    func normalizesProviderAliasInStatusProbe() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "status", "probe",
                "--provider", "codexxcode",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("| codex-xcode"))
    }

    @Test("routes status doctor")
    func routesStatusDoctor() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "status", "doctor"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("检查项"))
        #expect(result.stdout.contains("status_probe"))
    }

    @Test("status probe rejects unsupported provider")
    func statusProbeRejectsUnsupportedProvider() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "status", "probe",
                "--provider", "claude",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("\"code\":\"invalid_arguments\""))
    }

    @Test("unsupported command returns invalid arguments")
    func unsupportedCommandError() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "status", "unknown",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("\"code\":\"unsupported_command\""))
        #expect(result.stderr.contains("Available actions for status"))
    }

    @Test("unsupported runtime command returns invalid arguments")
    func unsupportedRuntimeCommandError() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "runtime", "unknown"],
            codexService: mock
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("\"code\":\"unsupported_command\""))
        #expect(result.stderr.contains("Available actions for runtime"))
    }

    @Test("unknown codex group returns actionable error")
    func unknownCodexGroupReturnsActionableError() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "unknown", "list"],
            codexService: mock
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("\"code\":\"invalid_arguments\""))
        #expect(result.stderr.contains("Unknown group 'unknown'"))
        #expect(result.stderr.contains("Available groups"))
    }

    @Test("json flag returns structured payload")
    func jsonFlagReturnsStructuredPayload() async {
        let service = BinaryListPlainTextCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "binary", "list", "--json"],
            codexService: service
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("\"ok\":true"))
        #expect(result.stdout.contains("\"command\":\"codex.binary.list\""))
        #expect(result.stdout.contains("\"versions\""))
    }

    @Test("json contract snapshot for codex binary list success")
    func jsonContractSnapshotBinaryListSuccess() async throws {
        let service = JSONContractCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "binary", "list", "--json"],
            codexService: service
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)

        let expected = #"{"command":"codex.binary.list","data":{"selectedVersionID":"v1","versions":[{"detectedVersion":"1.0.0","displayName":"Codex 1.0.0","id":"v1","importedAt":"1970-01-01T00:00:00Z","isSelected":true,"source":"download"}]},"ok":true}"#
        #expect(try canonicalJSON(result.stdout) == expected)
    }

    @Test("json contract snapshot for codex auth list success")
    func jsonContractSnapshotAuthListSuccess() async throws {
        let service = JSONContractCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "auth", "list", "--provider", "codex", "--json"],
            codexService: service
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)

        let expected = #"{"command":"codex.auth.list","data":{"accounts":[{"createdAt":"1970-01-01T00:00:00Z","email":"json@example.com","id":"11111111-1111-1111-1111-111111111111","isActive":true,"name":"json-account","refreshedAt":"1970-01-01T00:01:00Z","relativeAuthPath":"accounts\/json\/auth.json","usageDisplay":"5h 80% \/ 7d 60%"}],"activeAccountID":"11111111-1111-1111-1111-111111111111","providerID":"codex"},"ok":true}"#
        #expect(try canonicalJSON(result.stdout) == expected)
    }

    @Test("json contract snapshot for codex auth usage success")
    func jsonContractSnapshotAuthUsageSuccess() async throws {
        let service = JSONContractCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "auth", "usage", "--provider", "codex", "--json"],
            codexService: service
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)

        let expected = #"{"command":"codex.auth.usage","data":{"accounts":[{"email":"json@example.com","expiresAt":"2026-12-31T08:00:00Z","fiveHourRemainingPercent":80,"id":"11111111-1111-1111-1111-111111111111","isActive":true,"refreshedAt":"1970-01-01T00:00:00Z","token1dCount":1200000,"token30dCount":24000000,"tokenAllCount":50000000,"weeklyRemainingPercent":60}],"providerID":"codex","summary":{"accountCount":1,"avgFiveHourRemainingPercent":80,"avgWeeklyRemainingPercent":60,"cachedCount":1,"earliestExpiresAt":"2026-12-31T08:00:00Z","latestRefreshedAt":"1970-01-01T00:00:00Z","totalToken1dCount":1200000,"totalToken30dCount":24000000,"totalTokenAllCount":50000000}},"ok":true}"#
        #expect(try canonicalJSON(result.stdout) == expected)
    }

    @Test("json contract snapshot for codex auth status success")
    func jsonContractSnapshotAuthStatusSuccess() async throws {
        let service = JSONContractCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "auth", "status", "--provider", "codex", "--json"],
            codexService: service
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)

        let expected = #"{"command":"codex.auth.status","data":{"accountCount":2,"activeAccountID":"22222222-2222-2222-2222-222222222222","authHashHex":"abc123","providerID":"codex","usageAvgFiveHourRemainingPercent":70,"usageAvgWeeklyRemainingPercent":55,"usageCachedAccountCount":2,"usageLatestRefreshedAt":"1970-01-01T00:01:00Z"},"ok":true}"#
        #expect(try canonicalJSON(result.stdout) == expected)
    }

    @Test("json contract snapshot for codex auth activate success")
    func jsonContractSnapshotAuthActivateSuccess() async throws {
        let service = JSONContractCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "auth", "activate",
                "--provider", "codex",
                "--account-id", "33333333-3333-3333-3333-333333333333",
                "--json",
            ],
            codexService: service
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)

        let expected = #"{"command":"codex.auth.activate","data":{"accountID":"33333333-3333-3333-3333-333333333333","providerID":"codex","runtimeErrorDescription":"runtime restarted","runtimeSwitched":false},"ok":true}"#
        #expect(try canonicalJSON(result.stdout) == expected)
    }

    @Test("json contract snapshot for codex auth login success")
    func jsonContractSnapshotAuthLoginSuccess() async throws {
        let service = JSONContractCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "auth", "login",
                "--provider", "codex",
                "--preferred-account-id", "44444444-4444-4444-4444-444444444444",
                "--json",
            ],
            codexService: service
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)

        let expected = #"{"command":"codex.auth.login","data":{"accountID":"44444444-4444-4444-4444-444444444444","accountName":"json-login","loginURL":"https:\/\/auth.example.com\/device","providerID":"codex","runtimeSwitched":true},"ok":true}"#
        #expect(try canonicalJSON(result.stdout) == expected)
    }

    @Test("json contract snapshot for codex auth refresh success")
    func jsonContractSnapshotAuthRefreshSuccess() async throws {
        let service = JSONContractCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "auth", "refresh",
                "--provider", "codex",
                "--account-id", "44444444-4444-4444-4444-444444444444",
                "--json",
            ],
            codexService: service
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)

        let expected = #"{"command":"codex.auth.refresh","data":{"items":[{"accountID":"44444444-4444-4444-4444-444444444444","accountName":"json-refresh","email":"json@example.com","isActive":true,"runtimeSwitched":true,"success":true}],"providerID":"codex","summary":{"failureCount":0,"successCount":1,"totalCount":1}},"ok":true}"#
        #expect(try canonicalJSON(result.stdout) == expected)
    }

    @Test("json contract snapshot for codex auth delete success")
    func jsonContractSnapshotAuthDeleteSuccess() async throws {
        let service = JSONContractCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "auth", "delete",
                "--provider", "codex",
                "--account-id", "55555555-5555-5555-5555-555555555555",
                "--json",
            ],
            codexService: service
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)

        let expected = #"{"command":"codex.auth.delete","data":{"accountID":"55555555-5555-5555-5555-555555555555","providerID":"codex","wasActive":true},"ok":true}"#
        #expect(try canonicalJSON(result.stdout) == expected)
    }

    @Test("json contract snapshot for unknown codex group error")
    func jsonContractSnapshotUnknownGroupError() async throws {
        let service = JSONContractCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "oops", "list"],
            codexService: service
        )

        #expect(result.exitCode == 2)
        #expect(result.stdout.isEmpty)

        let expected = #"{"error":{"code":"invalid_arguments","message":"Unknown group 'oops'. Available groups: auth, binary, provider, runtime, status."},"ok":false}"#
        #expect(try canonicalJSON(result.stderr) == expected)
    }

    @Test("domain error keeps structured code")
    func domainErrorCode() async {
        let mock = DomainErrorCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "binary", "use",
                "--version", "missing",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("\"code\":\"codex_binary_not_found\""))
    }

    @Test("cancellation maps to interrupted structured error")
    func cancellationMapsToInterruptedError() async {
        let mock = CancellationErrorCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "binary", "use",
                "--version", "v0.1.0",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 130)
        #expect(result.stdout.isEmpty)
        #expect(result.stderr.contains("\"code\":\"interrupted\""))
        #expect(result.stderr.contains("Operation cancelled"))
    }
}

private extension String {
    func indicesOfPipes() -> [Int] {
        enumerated().compactMap { index, char in char == "|" ? index : nil }
    }
}

private func canonicalJSON(_ raw: String) throws -> String {
    let data = Data(raw.utf8)
    let object = try JSONSerialization.jsonObject(with: data)
    let normalized = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    guard let string = String(data: normalized, encoding: .utf8) else {
        throw NolonCoreCLIError.domainFailed(code: "json_encoding_failed", message: "Failed to encode canonical JSON")
    }
    return string
}

private actor MockCodexCLIService: NolonCodexCLIServing {
    private var call: String?

    func lastCall() -> String? { call }

    func authList(providerID: String) async throws -> NolonCodexAuthListPayload {
        call = "authList"
        return NolonCodexAuthListPayload(providerID: providerID, activeAccountID: nil, accounts: [])
    }

    func authStatus(providerID: String) async throws -> NolonCodexAuthStatusPayload {
        call = "authStatus"
        return NolonCodexAuthStatusPayload(providerID: providerID, activeAccountID: nil, accountCount: 0, authHashHex: nil)
    }

    func authUsage(providerID: String) async throws -> NolonCodexAuthUsagePayload {
        call = "authUsage"
        return NolonCodexAuthUsagePayload(
            providerID: providerID,
            accounts: [
                NolonCodexAuthUsageAccountView(
                    id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                    email: "mock@example.com",
                    isActive: true,
                    fiveHourRemainingPercent: 75,
                    weeklyRemainingPercent: 44,
                    token1dCount: 1_200_000,
                    token30dCount: 24_000_000,
                    tokenAllCount: 50_000_000,
                    expiresAt: Date(timeIntervalSince1970: 1_798_704_000),
                    refreshedAt: Date(timeIntervalSince1970: 1_734_000_000)
                )
            ],
            summary: NolonCodexAuthUsageSummaryView(
                accountCount: 1,
                cachedCount: 1,
                avgFiveHourRemainingPercent: 75,
                avgWeeklyRemainingPercent: 44,
                totalToken1dCount: 1_200_000,
                totalToken30dCount: 24_000_000,
                totalTokenAllCount: 50_000_000,
                earliestExpiresAt: Date(timeIntervalSince1970: 1_798_704_000),
                latestRefreshedAt: Date(timeIntervalSince1970: 1_734_000_000)
            )
        )
    }

    func authUsageRefresh(providerID: String, accountID: UUID?) async throws -> NolonCodexAuthUsagePayload {
        _ = accountID
        call = "authUsageRefresh"
        return NolonCodexAuthUsagePayload(
            providerID: providerID,
            accounts: [
                NolonCodexAuthUsageAccountView(
                    id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                    email: "mock@example.com",
                    isActive: true,
                    fiveHourRemainingPercent: 75,
                    weeklyRemainingPercent: 44,
                    token1dCount: 1_200_000,
                    token30dCount: 24_000_000,
                    tokenAllCount: 50_000_000,
                    expiresAt: Date(timeIntervalSince1970: 1_798_704_000),
                    refreshedAt: Date(timeIntervalSince1970: 1_734_000_000)
                )
            ],
            summary: NolonCodexAuthUsageSummaryView(
                accountCount: 1,
                cachedCount: 1,
                avgFiveHourRemainingPercent: 75,
                avgWeeklyRemainingPercent: 44,
                totalToken1dCount: 1_200_000,
                totalToken30dCount: 24_000_000,
                totalTokenAllCount: 50_000_000,
                earliestExpiresAt: Date(timeIntervalSince1970: 1_798_704_000),
                latestRefreshedAt: Date(timeIntervalSince1970: 1_734_000_000)
            )
        )
    }

    func authActivate(providerID: String, accountID: UUID) async throws -> NolonCodexAuthActivatePayload {
        call = "authActivate"
        return NolonCodexAuthActivatePayload(
            providerID: providerID,
            accountID: accountID,
            runtimeSwitched: true,
            runtimeErrorDescription: nil
        )
    }

    func authLogin(providerID: String, preferredAccountID: UUID?) async throws -> NolonCodexAuthLoginPayload {
        call = "authLogin"
        return NolonCodexAuthLoginPayload(
            providerID: providerID,
            accountID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            accountName: "mock",
            runtimeSwitched: true,
            runtimeErrorDescription: nil,
            loginURL: "https://auth.example.com/device"
        )
    }

    func authRefresh(providerID: String, accountID: UUID?) async throws -> NolonCodexAuthRefreshPayload {
        call = "authRefresh"
        let resolvedID = accountID ?? UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        return NolonCodexAuthRefreshPayload(
            providerID: providerID,
            items: [
                NolonCodexAuthRefreshItemView(
                    accountID: resolvedID,
                    accountName: "mock-refresh",
                    email: "mock@example.com",
                    isActive: true,
                    success: true,
                    runtimeSwitched: true,
                    runtimeErrorDescription: nil,
                    errorCode: nil,
                    errorMessage: nil
                ),
            ],
            summary: NolonCodexAuthRefreshSummaryView(totalCount: 1, successCount: 1, failureCount: 0)
        )
    }

    func authDelete(providerID: String, accountID: UUID) async throws -> NolonCodexAuthDeletePayload {
        call = "authDelete"
        return NolonCodexAuthDeletePayload(
            providerID: providerID,
            accountID: accountID,
            wasActive: false
        )
    }

    func binaryList() async throws -> NolonCodexBinaryListPayload {
        call = "binaryList"
        return NolonCodexBinaryListPayload(selectedVersionID: nil, versions: [])
    }

    func binaryAvailable() async throws -> NolonCodexBinaryAvailablePayload {
        call = "binaryAvailable"
        return NolonCodexBinaryAvailablePayload(versions: [])
    }

    func binaryCurrent() async throws -> NolonCodexBinaryCurrentPayload {
        call = "binaryCurrent"
        return NolonCodexBinaryCurrentPayload(selectedVersionID: nil, currentVersion: nil, activeCLIPath: nil)
    }

    func binaryInstall(version: String, setDefault: Bool) async throws -> NolonCodexBinaryInstallPayload {
        call = "binaryInstall"
        return NolonCodexBinaryInstallPayload(
            requestedVersion: version,
            installedVersionID: "v\(version)-mock",
            installedDetectedVersion: version,
            activated: setDefault
        )
    }

    func binaryUse(version: String) async throws -> NolonCodexBinaryUsePayload {
        call = "binaryUse"
        return NolonCodexBinaryUsePayload(selectedVersionID: version)
    }

    func binaryDoctor() async throws -> NolonCodexBinaryDoctorPayload {
        call = "binaryDoctor"
        return NolonCodexBinaryDoctorPayload(
            selectedVersionID: nil,
            currentVersion: nil,
            activeCLIPath: nil,
            managedVersionCount: 0,
            pathConfigured: false,
            pathActive: false,
            profilePath: "~/.zshrc"
        )
    }

    func statusProbe(providerID: String?) async throws -> NolonCodexStatusProbePayload {
        call = "statusProbe"
        return NolonCodexStatusProbePayload(
            providerID: providerID,
            resolvedExecutable: "/opt/homebrew/bin/codex",
            credits: nil,
            fiveHourPercentLeft: nil,
            weeklyPercentLeft: nil,
            fiveHourResetDescription: nil,
            weeklyResetDescription: nil,
            probeWarning: nil,
            probeHint: nil
        )
    }

    func runtimeList(providerID: String?) async throws -> NolonCodexRuntimeListPayload {
        call = "runtimeList"
        return NolonCodexRuntimeListPayload(
            processes: [
                NolonCodexRuntimeProcessView(
                    pid: 12345,
                    ppid: 1,
                    elapsed: "00:01:02",
                    providerHint: "codex",
                    command: "/opt/homebrew/bin/codex"
                )
            ]
        )
    }

    func runtimeStop(pid: Int32, force: Bool, timeoutSeconds: Int) async throws -> NolonCodexRuntimeStopPayload {
        call = "runtimeStop"
        return NolonCodexRuntimeStopPayload(
            pid: pid,
            requestedSignal: force ? "kill" : "term",
            didEscalateToKill: false,
            exited: true
        )
    }

    func providerList() async throws -> NolonProviderListPayload {
        call = "providerList"
        return NolonProviderListPayload(
            providers: [
                NolonProviderCLIView(
                    providerID: "codex",
                    name: "Codex",
                    cli: "codex",
                    installed: true,
                    executablePath: "/opt/homebrew/bin/codex"
                ),
            ]
        )
    }

    func providerDiscover() async throws -> NolonCodexProviderDiscoverPayload {
        call = "providerDiscover"
        return NolonCodexProviderDiscoverPayload(
            providers: [
                NolonCodexProviderDiscoverView(
                    providerID: "codex",
                    name: "Codex",
                    templateID: "codex",
                    codexHomePath: "/tmp/.codex",
                    authPath: "/tmp/.codex/auth.json",
                    authExists: true,
                    authIsSymlink: true,
                    authSymlinkTargetPath: "/tmp/.nolon/codex/auth/codex.json"
                ),
            ]
        )
    }
}

private actor DomainErrorCodexCLIService: NolonCodexCLIServing {
    func authList(providerID: String) async throws -> NolonCodexAuthListPayload { throw makeError() }
    func authStatus(providerID: String) async throws -> NolonCodexAuthStatusPayload { throw makeError() }
    func authActivate(providerID: String, accountID: UUID) async throws -> NolonCodexAuthActivatePayload { throw makeError() }
    func authLogin(providerID: String, preferredAccountID: UUID?) async throws -> NolonCodexAuthLoginPayload { throw makeError() }
    func authDelete(providerID: String, accountID: UUID) async throws -> NolonCodexAuthDeletePayload { throw makeError() }
    func binaryList() async throws -> NolonCodexBinaryListPayload { throw makeError() }
    func binaryAvailable() async throws -> NolonCodexBinaryAvailablePayload { throw makeError() }
    func binaryCurrent() async throws -> NolonCodexBinaryCurrentPayload { throw makeError() }
    func binaryInstall(version: String, setDefault: Bool) async throws -> NolonCodexBinaryInstallPayload { throw makeError() }
    func binaryUse(version: String) async throws -> NolonCodexBinaryUsePayload { throw makeError() }
    func binaryDoctor() async throws -> NolonCodexBinaryDoctorPayload { throw makeError() }
    func statusProbe(providerID: String?) async throws -> NolonCodexStatusProbePayload { throw makeError() }
    func runtimeList(providerID: String?) async throws -> NolonCodexRuntimeListPayload { throw makeError() }
    func runtimeStop(pid: Int32, force: Bool, timeoutSeconds: Int) async throws -> NolonCodexRuntimeStopPayload { throw makeError() }
    func providerList() async throws -> NolonProviderListPayload { throw makeError() }
    func providerDiscover() async throws -> NolonCodexProviderDiscoverPayload { throw makeError() }

    private func makeError() -> NolonCoreCLIError {
        .domainFailed(code: "codex_binary_not_found", message: "missing")
    }
}

private actor CancellationErrorCodexCLIService: NolonCodexCLIServing {
    func authList(providerID: String) async throws -> NolonCodexAuthListPayload { throw CancellationError() }
    func authStatus(providerID: String) async throws -> NolonCodexAuthStatusPayload { throw CancellationError() }
    func authActivate(providerID: String, accountID: UUID) async throws -> NolonCodexAuthActivatePayload { throw CancellationError() }
    func authLogin(providerID: String, preferredAccountID: UUID?) async throws -> NolonCodexAuthLoginPayload { throw CancellationError() }
    func authDelete(providerID: String, accountID: UUID) async throws -> NolonCodexAuthDeletePayload { throw CancellationError() }
    func binaryList() async throws -> NolonCodexBinaryListPayload { throw CancellationError() }
    func binaryAvailable() async throws -> NolonCodexBinaryAvailablePayload { throw CancellationError() }
    func binaryCurrent() async throws -> NolonCodexBinaryCurrentPayload { throw CancellationError() }
    func binaryInstall(version: String, setDefault: Bool) async throws -> NolonCodexBinaryInstallPayload { throw CancellationError() }
    func binaryUse(version: String) async throws -> NolonCodexBinaryUsePayload { throw CancellationError() }
    func binaryDoctor() async throws -> NolonCodexBinaryDoctorPayload { throw CancellationError() }
    func statusProbe(providerID: String?) async throws -> NolonCodexStatusProbePayload { throw CancellationError() }
    func runtimeList(providerID: String?) async throws -> NolonCodexRuntimeListPayload { throw CancellationError() }
    func runtimeStop(pid: Int32, force: Bool, timeoutSeconds: Int) async throws -> NolonCodexRuntimeStopPayload { throw CancellationError() }
    func providerList() async throws -> NolonProviderListPayload { throw CancellationError() }
    func providerDiscover() async throws -> NolonCodexProviderDiscoverPayload { throw CancellationError() }
}

private actor EmailActivateCodexCLIService: NolonCodexCLIServing {
    private let accountID = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!

    func authList(providerID: String) async throws -> NolonCodexAuthListPayload {
        NolonCodexAuthListPayload(
            providerID: providerID,
            activeAccountID: nil,
            accounts: [
                NolonCodexAuthAccountView(
                    id: accountID,
                    name: "A",
                    createdAt: .distantPast,
                    relativeAuthPath: "a/auth.json",
                    isActive: false,
                    email: "a@example.com",
                    usageDisplay: nil,
                    refreshedAt: nil
                ),
            ]
        )
    }

    func authStatus(providerID: String) async throws -> NolonCodexAuthStatusPayload {
        NolonCodexAuthStatusPayload(providerID: providerID, activeAccountID: nil, accountCount: 1, authHashHex: nil)
    }

    func authActivate(providerID: String, accountID: UUID) async throws -> NolonCodexAuthActivatePayload {
        NolonCodexAuthActivatePayload(providerID: providerID, accountID: accountID, runtimeSwitched: true, runtimeErrorDescription: nil)
    }

    func authLogin(providerID: String, preferredAccountID: UUID?) async throws -> NolonCodexAuthLoginPayload {
        NolonCodexAuthLoginPayload(providerID: providerID, accountID: accountID, accountName: "A", runtimeSwitched: false, runtimeErrorDescription: nil, loginURL: nil)
    }

    func authDelete(providerID: String, accountID: UUID) async throws -> NolonCodexAuthDeletePayload {
        NolonCodexAuthDeletePayload(providerID: providerID, accountID: accountID, wasActive: false)
    }

    func binaryList() async throws -> NolonCodexBinaryListPayload {
        NolonCodexBinaryListPayload(selectedVersionID: nil, versions: [])
    }

    func binaryAvailable() async throws -> NolonCodexBinaryAvailablePayload {
        NolonCodexBinaryAvailablePayload(versions: [])
    }

    func binaryCurrent() async throws -> NolonCodexBinaryCurrentPayload {
        NolonCodexBinaryCurrentPayload(selectedVersionID: nil, currentVersion: nil, activeCLIPath: nil)
    }

    func binaryInstall(version: String, setDefault: Bool) async throws -> NolonCodexBinaryInstallPayload {
        NolonCodexBinaryInstallPayload(requestedVersion: version, installedVersionID: version, installedDetectedVersion: version, activated: setDefault)
    }

    func binaryUse(version: String) async throws -> NolonCodexBinaryUsePayload {
        NolonCodexBinaryUsePayload(selectedVersionID: version)
    }

    func binaryDoctor() async throws -> NolonCodexBinaryDoctorPayload {
        NolonCodexBinaryDoctorPayload(selectedVersionID: nil, currentVersion: nil, activeCLIPath: nil, managedVersionCount: 0, pathConfigured: false, pathActive: false, profilePath: "~/.zshrc")
    }

    func statusProbe(providerID: String?) async throws -> NolonCodexStatusProbePayload {
        NolonCodexStatusProbePayload(providerID: providerID, resolvedExecutable: nil, credits: nil, fiveHourPercentLeft: nil, weeklyPercentLeft: nil, fiveHourResetDescription: nil, weeklyResetDescription: nil, probeWarning: nil, probeHint: nil)
    }

    func runtimeList(providerID: String?) async throws -> NolonCodexRuntimeListPayload {
        NolonCodexRuntimeListPayload(processes: [])
    }

    func runtimeStop(pid: Int32, force: Bool, timeoutSeconds: Int) async throws -> NolonCodexRuntimeStopPayload {
        NolonCodexRuntimeStopPayload(pid: pid, requestedSignal: "term", didEscalateToKill: false, exited: true)
    }

    func providerList() async throws -> NolonProviderListPayload {
        NolonProviderListPayload(providers: [])
    }

    func providerDiscover() async throws -> NolonCodexProviderDiscoverPayload {
        NolonCodexProviderDiscoverPayload(providers: [])
    }
}

private actor StatusProbeParseErrorCodexCLIService: NolonCodexCLIServing {
    func authList(providerID: String) async throws -> NolonCodexAuthListPayload { NolonCodexAuthListPayload(providerID: providerID, activeAccountID: nil, accounts: []) }
    func authStatus(providerID: String) async throws -> NolonCodexAuthStatusPayload { NolonCodexAuthStatusPayload(providerID: providerID, activeAccountID: nil, accountCount: 0, authHashHex: nil) }
    func authActivate(providerID: String, accountID: UUID) async throws -> NolonCodexAuthActivatePayload { NolonCodexAuthActivatePayload(providerID: providerID, accountID: accountID, runtimeSwitched: false, runtimeErrorDescription: nil) }
    func authLogin(providerID: String, preferredAccountID: UUID?) async throws -> NolonCodexAuthLoginPayload { NolonCodexAuthLoginPayload(providerID: providerID, accountID: UUID(), accountName: "-", runtimeSwitched: false, runtimeErrorDescription: nil, loginURL: nil) }
    func authDelete(providerID: String, accountID: UUID) async throws -> NolonCodexAuthDeletePayload { NolonCodexAuthDeletePayload(providerID: providerID, accountID: accountID, wasActive: false) }
    func binaryList() async throws -> NolonCodexBinaryListPayload { NolonCodexBinaryListPayload(selectedVersionID: nil, versions: []) }
    func binaryAvailable() async throws -> NolonCodexBinaryAvailablePayload { NolonCodexBinaryAvailablePayload(versions: []) }
    func binaryCurrent() async throws -> NolonCodexBinaryCurrentPayload { NolonCodexBinaryCurrentPayload(selectedVersionID: nil, currentVersion: nil, activeCLIPath: nil) }
    func binaryInstall(version: String, setDefault: Bool) async throws -> NolonCodexBinaryInstallPayload { NolonCodexBinaryInstallPayload(requestedVersion: version, installedVersionID: version, installedDetectedVersion: version, activated: setDefault) }
    func binaryUse(version: String) async throws -> NolonCodexBinaryUsePayload { NolonCodexBinaryUsePayload(selectedVersionID: version) }
    func binaryDoctor() async throws -> NolonCodexBinaryDoctorPayload { NolonCodexBinaryDoctorPayload(selectedVersionID: nil, currentVersion: nil, activeCLIPath: nil, managedVersionCount: 0, pathConfigured: false, pathActive: false, profilePath: "~/.zshrc") }
    func statusProbe(providerID: String?) async throws -> NolonCodexStatusProbePayload {
        throw NolonCoreCLIError.invalidArguments("Could not parse Codex status; will retry shortly.")
    }
    func runtimeList(providerID: String?) async throws -> NolonCodexRuntimeListPayload { NolonCodexRuntimeListPayload(processes: []) }
    func runtimeStop(pid: Int32, force: Bool, timeoutSeconds: Int) async throws -> NolonCodexRuntimeStopPayload { NolonCodexRuntimeStopPayload(pid: pid, requestedSignal: "term", didEscalateToKill: false, exited: true) }
    func providerList() async throws -> NolonProviderListPayload { NolonProviderListPayload(providers: []) }
    func providerDiscover() async throws -> NolonCodexProviderDiscoverPayload { NolonCodexProviderDiscoverPayload(providers: []) }
}

private actor BinarySwitchCodexCLIService: NolonCodexCLIServing {
    private let installed: NolonCodexBinaryListPayload
    private let available: NolonCodexBinaryAvailablePayload
    private var call: String?

    init(installed: NolonCodexBinaryListPayload, available: NolonCodexBinaryAvailablePayload) {
        self.installed = installed
        self.available = available
    }

    func lastCall() -> String? { call }

    func authList(providerID: String) async throws -> NolonCodexAuthListPayload { throw unsupported() }
    func authStatus(providerID: String) async throws -> NolonCodexAuthStatusPayload { throw unsupported() }
    func authActivate(providerID: String, accountID: UUID) async throws -> NolonCodexAuthActivatePayload { throw unsupported() }
    func authLogin(providerID: String, preferredAccountID: UUID?) async throws -> NolonCodexAuthLoginPayload { throw unsupported() }
    func authDelete(providerID: String, accountID: UUID) async throws -> NolonCodexAuthDeletePayload { throw unsupported() }
    func binaryList() async throws -> NolonCodexBinaryListPayload { installed }
    func binaryAvailable() async throws -> NolonCodexBinaryAvailablePayload { available }
    func binaryCurrent() async throws -> NolonCodexBinaryCurrentPayload { throw unsupported() }
    func binaryInstall(version: String, setDefault: Bool) async throws -> NolonCodexBinaryInstallPayload {
        call = "binaryInstall"
        return NolonCodexBinaryInstallPayload(
            requestedVersion: version,
            installedVersionID: "v\(version)-mock",
            installedDetectedVersion: version,
            activated: setDefault
        )
    }
    func binaryUse(version: String) async throws -> NolonCodexBinaryUsePayload {
        call = "binaryUse"
        return NolonCodexBinaryUsePayload(selectedVersionID: version)
    }
    func binaryDoctor() async throws -> NolonCodexBinaryDoctorPayload { throw unsupported() }
    func statusProbe(providerID: String?) async throws -> NolonCodexStatusProbePayload { throw unsupported() }
    func runtimeList(providerID: String?) async throws -> NolonCodexRuntimeListPayload { throw unsupported() }
    func runtimeStop(pid: Int32, force: Bool, timeoutSeconds: Int) async throws -> NolonCodexRuntimeStopPayload { throw unsupported() }
    func providerList() async throws -> NolonProviderListPayload { throw unsupported() }
    func providerDiscover() async throws -> NolonCodexProviderDiscoverPayload { throw unsupported() }

    private func unsupported() -> NolonCoreCLIError {
        .invalidArguments("unsupported")
    }
}

private actor BinaryListPlainTextCodexCLIService: NolonCodexCLIServing {
    func authList(providerID: String) async throws -> NolonCodexAuthListPayload { throw unsupported() }
    func authStatus(providerID: String) async throws -> NolonCodexAuthStatusPayload { throw unsupported() }
    func authActivate(providerID: String, accountID: UUID) async throws -> NolonCodexAuthActivatePayload { throw unsupported() }
    func authLogin(providerID: String, preferredAccountID: UUID?) async throws -> NolonCodexAuthLoginPayload { throw unsupported() }
    func authDelete(providerID: String, accountID: UUID) async throws -> NolonCodexAuthDeletePayload { throw unsupported() }
    func binaryAvailable() async throws -> NolonCodexBinaryAvailablePayload { throw unsupported() }
    func binaryCurrent() async throws -> NolonCodexBinaryCurrentPayload { throw unsupported() }
    func binaryInstall(version: String, setDefault: Bool) async throws -> NolonCodexBinaryInstallPayload { throw unsupported() }
    func binaryUse(version: String) async throws -> NolonCodexBinaryUsePayload { throw unsupported() }
    func binaryDoctor() async throws -> NolonCodexBinaryDoctorPayload { throw unsupported() }
    func statusProbe(providerID: String?) async throws -> NolonCodexStatusProbePayload { throw unsupported() }
    func runtimeList(providerID: String?) async throws -> NolonCodexRuntimeListPayload { throw unsupported() }
    func runtimeStop(pid: Int32, force: Bool, timeoutSeconds: Int) async throws -> NolonCodexRuntimeStopPayload { throw unsupported() }
    func providerList() async throws -> NolonProviderListPayload { throw unsupported() }
    func providerDiscover() async throws -> NolonCodexProviderDiscoverPayload { throw unsupported() }

    func binaryList() async throws -> NolonCodexBinaryListPayload {
        NolonCodexBinaryListPayload(
            selectedVersionID: "v0.26.0",
            versions: [
                NolonCodexManagedVersionView(
                    id: "v0.26.0",
                    displayName: "Codex 0.26.0",
                    detectedVersion: "0.26.0",
                    source: "release",
                    importedAt: .distantPast,
                    isSelected: true
                ),
                NolonCodexManagedVersionView(
                    id: "v0.9.0",
                    displayName: "X",
                    detectedVersion: "0.9.0",
                    source: "release",
                    importedAt: .distantPast,
                    isSelected: false
                ),
            ]
        )
    }

    private func unsupported() -> NolonCoreCLIError {
        .invalidArguments("unsupported")
    }
}

private actor JSONContractCodexCLIService: NolonCodexCLIServing {
    func authList(providerID: String) async throws -> NolonCodexAuthListPayload {
        NolonCodexAuthListPayload(
            providerID: providerID,
            activeAccountID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            accounts: [
                NolonCodexAuthAccountView(
                    id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                    name: "json-account",
                    createdAt: Date(timeIntervalSince1970: 0),
                    relativeAuthPath: "accounts/json/auth.json",
                    isActive: true,
                    email: "json@example.com",
                    usageDisplay: "5h 80% / 7d 60%",
                    refreshedAt: Date(timeIntervalSince1970: 60)
                )
            ]
        )
    }
    func authStatus(providerID: String) async throws -> NolonCodexAuthStatusPayload {
        NolonCodexAuthStatusPayload(
            providerID: providerID,
            activeAccountID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            accountCount: 2,
            authHashHex: "abc123",
            usageCachedAccountCount: 2,
            usageAvgFiveHourRemainingPercent: 70,
            usageAvgWeeklyRemainingPercent: 55,
            usageLatestRefreshedAt: Date(timeIntervalSince1970: 60)
        )
    }
    func authActivate(providerID: String, accountID: UUID) async throws -> NolonCodexAuthActivatePayload {
        NolonCodexAuthActivatePayload(
            providerID: providerID,
            accountID: accountID,
            runtimeSwitched: false,
            runtimeErrorDescription: "runtime restarted"
        )
    }
    func authLogin(providerID: String, preferredAccountID: UUID?) async throws -> NolonCodexAuthLoginPayload {
        NolonCodexAuthLoginPayload(
            providerID: providerID,
            accountID: preferredAccountID ?? UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            accountName: "json-login",
            runtimeSwitched: true,
            runtimeErrorDescription: nil,
            loginURL: "https://auth.example.com/device"
        )
    }
    func authRefresh(providerID: String, accountID: UUID?) async throws -> NolonCodexAuthRefreshPayload {
        NolonCodexAuthRefreshPayload(
            providerID: providerID,
            items: [
                NolonCodexAuthRefreshItemView(
                    accountID: accountID ?? UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
                    accountName: "json-refresh",
                    email: "json@example.com",
                    isActive: true,
                    success: true,
                    runtimeSwitched: true,
                    runtimeErrorDescription: nil,
                    errorCode: nil,
                    errorMessage: nil
                ),
            ],
            summary: NolonCodexAuthRefreshSummaryView(totalCount: 1, successCount: 1, failureCount: 0)
        )
    }
    func authDelete(providerID: String, accountID: UUID) async throws -> NolonCodexAuthDeletePayload {
        NolonCodexAuthDeletePayload(
            providerID: providerID,
            accountID: accountID,
            wasActive: true
        )
    }
    func binaryAvailable() async throws -> NolonCodexBinaryAvailablePayload { throw unsupported() }
    func binaryCurrent() async throws -> NolonCodexBinaryCurrentPayload { throw unsupported() }
    func binaryInstall(version: String, setDefault: Bool) async throws -> NolonCodexBinaryInstallPayload { throw unsupported() }
    func binaryUse(version: String) async throws -> NolonCodexBinaryUsePayload { throw unsupported() }
    func binaryDoctor() async throws -> NolonCodexBinaryDoctorPayload { throw unsupported() }
    func statusProbe(providerID: String?) async throws -> NolonCodexStatusProbePayload { throw unsupported() }
    func runtimeList(providerID: String?) async throws -> NolonCodexRuntimeListPayload { throw unsupported() }
    func runtimeStop(pid: Int32, force: Bool, timeoutSeconds: Int) async throws -> NolonCodexRuntimeStopPayload { throw unsupported() }
    func providerList() async throws -> NolonProviderListPayload { throw unsupported() }
    func providerDiscover() async throws -> NolonCodexProviderDiscoverPayload { throw unsupported() }

    func binaryList() async throws -> NolonCodexBinaryListPayload {
        NolonCodexBinaryListPayload(
            selectedVersionID: "v1",
            versions: [
                NolonCodexManagedVersionView(
                    id: "v1",
                    displayName: "Codex 1.0.0",
                    detectedVersion: "1.0.0",
                    source: "download",
                    importedAt: Date(timeIntervalSince1970: 0),
                    isSelected: true
                )
            ]
        )
    }

    func authUsage(providerID: String) async throws -> NolonCodexAuthUsagePayload {
        NolonCodexAuthUsagePayload(
            providerID: providerID,
            accounts: [
                NolonCodexAuthUsageAccountView(
                    id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                    email: "json@example.com",
                    isActive: true,
                    fiveHourRemainingPercent: 80,
                    weeklyRemainingPercent: 60,
                    token1dCount: 1_200_000,
                    token30dCount: 24_000_000,
                    tokenAllCount: 50_000_000,
                    expiresAt: Date(timeIntervalSince1970: 1_798_704_000),
                    refreshedAt: Date(timeIntervalSince1970: 0)
                )
            ],
            summary: NolonCodexAuthUsageSummaryView(
                accountCount: 1,
                cachedCount: 1,
                avgFiveHourRemainingPercent: 80,
                avgWeeklyRemainingPercent: 60,
                totalToken1dCount: 1_200_000,
                totalToken30dCount: 24_000_000,
                totalTokenAllCount: 50_000_000,
                earliestExpiresAt: Date(timeIntervalSince1970: 1_798_704_000),
                latestRefreshedAt: Date(timeIntervalSince1970: 0)
            )
        )
    }

    private func unsupported() -> NolonCoreCLIError {
        .invalidArguments("unsupported")
    }
}

private actor AuthListTableCodexCLIService: NolonCodexCLIServing {
    func authStatus(providerID: String) async throws -> NolonCodexAuthStatusPayload {
        NolonCodexAuthStatusPayload(
            providerID: providerID,
            activeAccountID: UUID(uuidString: "11111111-1111-1111-1111-111111111111"),
            accountCount: 2,
            authHashHex: "tablehash"
        )
    }
    func authActivate(providerID: String, accountID: UUID) async throws -> NolonCodexAuthActivatePayload { throw unsupported() }
    func authLogin(providerID: String, preferredAccountID: UUID?) async throws -> NolonCodexAuthLoginPayload { throw unsupported() }
    func authDelete(providerID: String, accountID: UUID) async throws -> NolonCodexAuthDeletePayload { throw unsupported() }
    func binaryList() async throws -> NolonCodexBinaryListPayload { throw unsupported() }
    func binaryAvailable() async throws -> NolonCodexBinaryAvailablePayload { throw unsupported() }
    func binaryCurrent() async throws -> NolonCodexBinaryCurrentPayload { throw unsupported() }
    func binaryInstall(version: String, setDefault: Bool) async throws -> NolonCodexBinaryInstallPayload { throw unsupported() }
    func binaryUse(version: String) async throws -> NolonCodexBinaryUsePayload { throw unsupported() }
    func binaryDoctor() async throws -> NolonCodexBinaryDoctorPayload { throw unsupported() }
    func statusProbe(providerID: String?) async throws -> NolonCodexStatusProbePayload { throw unsupported() }
    func runtimeList(providerID: String?) async throws -> NolonCodexRuntimeListPayload { throw unsupported() }
    func runtimeStop(pid: Int32, force: Bool, timeoutSeconds: Int) async throws -> NolonCodexRuntimeStopPayload { throw unsupported() }
    func providerList() async throws -> NolonProviderListPayload { throw unsupported() }
    func providerDiscover() async throws -> NolonCodexProviderDiscoverPayload { throw unsupported() }

    func authUsage(providerID: String) async throws -> NolonCodexAuthUsagePayload {
        NolonCodexAuthUsagePayload(
            providerID: providerID,
            accounts: [],
            summary: NolonCodexAuthUsageSummaryView(
                accountCount: 0,
                cachedCount: 0,
                avgFiveHourRemainingPercent: nil,
                avgWeeklyRemainingPercent: nil,
                totalToken1dCount: nil,
                totalToken30dCount: nil,
                totalTokenAllCount: nil,
                earliestExpiresAt: nil,
                latestRefreshedAt: nil
            )
        )
    }

    func authList(providerID: String) async throws -> NolonCodexAuthListPayload {
        NolonCodexAuthListPayload(
            providerID: providerID,
            activeAccountID: UUID(uuidString: "11111111-1111-1111-1111-111111111111"),
            accounts: [
                NolonCodexAuthAccountView(
                    id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                    name: "long-account-name",
                    createdAt: .distantPast,
                    relativeAuthPath: "accounts/long-name/auth.json",
                    isActive: true,
                    email: "long-account@example.com",
                    usageDisplay: "5h 81% / 7d 55%",
                    refreshedAt: Date(timeIntervalSince1970: 1_734_000_000)
                ),
                NolonCodexAuthAccountView(
                    id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                    name: "x",
                    createdAt: .distantPast,
                    relativeAuthPath: "a.json",
                    isActive: false,
                    email: "x@example.com",
                    usageDisplay: "5h 40%",
                    refreshedAt: Date(timeIntervalSince1970: 1_733_900_000)
                ),
            ]
        )
    }

    private func unsupported() -> NolonCoreCLIError {
        .invalidArguments("unsupported")
    }
}

private actor AuthUsageExpiryLabelCodexCLIService: NolonCodexCLIServing {
    func authList(providerID: String) async throws -> NolonCodexAuthListPayload {
        NolonCodexAuthListPayload(providerID: providerID, activeAccountID: nil, accounts: [])
    }
    func authStatus(providerID: String) async throws -> NolonCodexAuthStatusPayload {
        NolonCodexAuthStatusPayload(providerID: providerID, activeAccountID: nil, accountCount: 2, authHashHex: "expiryhash")
    }
    func authActivate(providerID: String, accountID: UUID) async throws -> NolonCodexAuthActivatePayload { throw unsupported() }
    func authLogin(providerID: String, preferredAccountID: UUID?) async throws -> NolonCodexAuthLoginPayload { throw unsupported() }
    func authDelete(providerID: String, accountID: UUID) async throws -> NolonCodexAuthDeletePayload { throw unsupported() }
    func binaryList() async throws -> NolonCodexBinaryListPayload { throw unsupported() }
    func binaryAvailable() async throws -> NolonCodexBinaryAvailablePayload { throw unsupported() }
    func binaryCurrent() async throws -> NolonCodexBinaryCurrentPayload { throw unsupported() }
    func binaryInstall(version: String, setDefault: Bool) async throws -> NolonCodexBinaryInstallPayload { throw unsupported() }
    func binaryUse(version: String) async throws -> NolonCodexBinaryUsePayload { throw unsupported() }
    func binaryDoctor() async throws -> NolonCodexBinaryDoctorPayload { throw unsupported() }
    func statusProbe(providerID: String?) async throws -> NolonCodexStatusProbePayload { throw unsupported() }
    func runtimeList(providerID: String?) async throws -> NolonCodexRuntimeListPayload { throw unsupported() }
    func runtimeStop(pid: Int32, force: Bool, timeoutSeconds: Int) async throws -> NolonCodexRuntimeStopPayload { throw unsupported() }
    func providerList() async throws -> NolonProviderListPayload { throw unsupported() }
    func providerDiscover() async throws -> NolonCodexProviderDiscoverPayload { throw unsupported() }

    func authUsage(providerID: String) async throws -> NolonCodexAuthUsagePayload {
        NolonCodexAuthUsagePayload(
            providerID: providerID,
            accounts: [
                NolonCodexAuthUsageAccountView(
                    id: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
                    email: "future@example.com",
                    isActive: true,
                    fiveHourRemainingPercent: 80,
                    weeklyRemainingPercent: 60,
                    token1dCount: 1_000_000,
                    token30dCount: 10_000_000,
                    tokenAllCount: 20_000_000,
                    expiresAt: Date().addingTimeInterval(26 * 3600),
                    refreshedAt: Date()
                ),
                NolonCodexAuthUsageAccountView(
                    id: UUID(uuidString: "88888888-8888-8888-8888-888888888888")!,
                    email: "expired@example.com",
                    isActive: false,
                    fiveHourRemainingPercent: 20,
                    weeklyRemainingPercent: 30,
                    token1dCount: 500_000,
                    token30dCount: 5_000_000,
                    tokenAllCount: 8_000_000,
                    expiresAt: Date().addingTimeInterval(-3 * 3600),
                    hasRefreshToken: true,
                    refreshedAt: Date()
                ),
            ],
            summary: NolonCodexAuthUsageSummaryView(
                accountCount: 2,
                cachedCount: 2,
                avgFiveHourRemainingPercent: 50,
                avgWeeklyRemainingPercent: 45,
                totalToken1dCount: 1_500_000,
                totalToken30dCount: 15_000_000,
                totalTokenAllCount: 28_000_000,
                earliestExpiresAt: Date().addingTimeInterval(-3 * 3600),
                latestRefreshedAt: Date()
            )
        )
    }

    private func unsupported() -> NolonCoreCLIError {
        .invalidArguments("unsupported")
    }
}

private actor AuthUsageGlobalFallbackCodexCLIService: NolonCodexCLIServing {
    func authList(providerID: String) async throws -> NolonCodexAuthListPayload {
        NolonCodexAuthListPayload(providerID: providerID, activeAccountID: nil, accounts: [])
    }
    func authStatus(providerID: String) async throws -> NolonCodexAuthStatusPayload {
        NolonCodexAuthStatusPayload(providerID: providerID, activeAccountID: nil, accountCount: 1, authHashHex: "fallbackhash")
    }
    func authActivate(providerID: String, accountID: UUID) async throws -> NolonCodexAuthActivatePayload { throw unsupported() }
    func authLogin(providerID: String, preferredAccountID: UUID?) async throws -> NolonCodexAuthLoginPayload { throw unsupported() }
    func authDelete(providerID: String, accountID: UUID) async throws -> NolonCodexAuthDeletePayload { throw unsupported() }
    func binaryList() async throws -> NolonCodexBinaryListPayload { throw unsupported() }
    func binaryAvailable() async throws -> NolonCodexBinaryAvailablePayload { throw unsupported() }
    func binaryCurrent() async throws -> NolonCodexBinaryCurrentPayload { throw unsupported() }
    func binaryInstall(version: String, setDefault: Bool) async throws -> NolonCodexBinaryInstallPayload { throw unsupported() }
    func binaryUse(version: String) async throws -> NolonCodexBinaryUsePayload { throw unsupported() }
    func binaryDoctor() async throws -> NolonCodexBinaryDoctorPayload { throw unsupported() }
    func statusProbe(providerID: String?) async throws -> NolonCodexStatusProbePayload { throw unsupported() }
    func runtimeList(providerID: String?) async throws -> NolonCodexRuntimeListPayload { throw unsupported() }
    func runtimeStop(pid: Int32, force: Bool, timeoutSeconds: Int) async throws -> NolonCodexRuntimeStopPayload { throw unsupported() }
    func providerList() async throws -> NolonProviderListPayload { throw unsupported() }
    func providerDiscover() async throws -> NolonCodexProviderDiscoverPayload { throw unsupported() }

    func authUsage(providerID: String) async throws -> NolonCodexAuthUsagePayload {
        NolonCodexAuthUsagePayload(
            providerID: providerID,
            accounts: [
                NolonCodexAuthUsageAccountView(
                    id: UUID(uuidString: "99999999-9999-9999-9999-999999999999")!,
                    email: "fallback@example.com",
                    isActive: true,
                    usageSource: "CLI(global)",
                    fiveHourRemainingPercent: 80,
                    weeklyRemainingPercent: 60,
                    token1dCount: 1_000_000,
                    token30dCount: 10_000_000,
                    tokenAllCount: 20_000_000,
                    expiresAt: Date().addingTimeInterval(-3600),
                    hasRefreshToken: true,
                    refreshedAt: Date()
                )
            ],
            summary: NolonCodexAuthUsageSummaryView(
                accountCount: 1,
                cachedCount: 1,
                avgFiveHourRemainingPercent: 80,
                avgWeeklyRemainingPercent: 60,
                totalToken1dCount: 1_000_000,
                totalToken30dCount: 10_000_000,
                totalTokenAllCount: 20_000_000,
                earliestExpiresAt: Date().addingTimeInterval(-3600),
                latestRefreshedAt: Date()
            )
        )
    }

    private func unsupported() -> NolonCoreCLIError {
        .invalidArguments("unsupported")
    }
}

private actor AuthUsageUndistinguishableTokensCodexCLIService: NolonCodexCLIServing {
    func authList(providerID: String) async throws -> NolonCodexAuthListPayload {
        NolonCodexAuthListPayload(providerID: providerID, activeAccountID: nil, accounts: [])
    }
    func authStatus(providerID: String) async throws -> NolonCodexAuthStatusPayload {
        NolonCodexAuthStatusPayload(providerID: providerID, activeAccountID: nil, accountCount: 2, authHashHex: "same-token")
    }
    func authActivate(providerID: String, accountID: UUID) async throws -> NolonCodexAuthActivatePayload { throw unsupported() }
    func authLogin(providerID: String, preferredAccountID: UUID?) async throws -> NolonCodexAuthLoginPayload { throw unsupported() }
    func authDelete(providerID: String, accountID: UUID) async throws -> NolonCodexAuthDeletePayload { throw unsupported() }
    func binaryList() async throws -> NolonCodexBinaryListPayload { throw unsupported() }
    func binaryAvailable() async throws -> NolonCodexBinaryAvailablePayload { throw unsupported() }
    func binaryCurrent() async throws -> NolonCodexBinaryCurrentPayload { throw unsupported() }
    func binaryInstall(version: String, setDefault: Bool) async throws -> NolonCodexBinaryInstallPayload { throw unsupported() }
    func binaryUse(version: String) async throws -> NolonCodexBinaryUsePayload { throw unsupported() }
    func binaryDoctor() async throws -> NolonCodexBinaryDoctorPayload { throw unsupported() }
    func statusProbe(providerID: String?) async throws -> NolonCodexStatusProbePayload { throw unsupported() }
    func runtimeList(providerID: String?) async throws -> NolonCodexRuntimeListPayload { throw unsupported() }
    func runtimeStop(pid: Int32, force: Bool, timeoutSeconds: Int) async throws -> NolonCodexRuntimeStopPayload { throw unsupported() }
    func providerList() async throws -> NolonProviderListPayload { throw unsupported() }
    func providerDiscover() async throws -> NolonCodexProviderDiscoverPayload { throw unsupported() }

    func authUsage(providerID: String) async throws -> NolonCodexAuthUsagePayload {
        NolonCodexAuthUsagePayload(
            providerID: providerID,
            accounts: [
                NolonCodexAuthUsageAccountView(
                    id: UUID(uuidString: "12121212-1212-1212-1212-121212121212")!,
                    email: "a@example.com",
                    isActive: true,
                    usageSource: "CLI(global)",
                    fiveHourRemainingPercent: 90,
                    weeklyRemainingPercent: 50,
                    token1dCount: 125_600_000,
                    token30dCount: 4_674_400_000,
                    tokenAllCount: 4_674_400_000,
                    refreshedAt: Date()
                ),
                NolonCodexAuthUsageAccountView(
                    id: UUID(uuidString: "34343434-3434-3434-3434-343434343434")!,
                    email: "b@example.com",
                    isActive: false,
                    usageSource: "CLI(global)",
                    fiveHourRemainingPercent: 88,
                    weeklyRemainingPercent: 49,
                    token1dCount: 125_600_000,
                    token30dCount: 4_674_400_000,
                    tokenAllCount: 4_674_400_000,
                    refreshedAt: Date()
                ),
            ],
            summary: NolonCodexAuthUsageSummaryView(
                accountCount: 2,
                cachedCount: 2,
                avgFiveHourRemainingPercent: 89,
                avgWeeklyRemainingPercent: 49,
                totalToken1dCount: 251_200_000,
                totalToken30dCount: 9_348_800_000,
                totalTokenAllCount: 9_348_800_000,
                latestRefreshedAt: Date()
            )
        )
    }

    private func unsupported() -> NolonCoreCLIError {
        .invalidArguments("unsupported")
    }
}

private actor AuthUsageActiveConsistencyCodexCLIService: NolonCodexCLIServing {
    func authList(providerID: String) async throws -> NolonCodexAuthListPayload {
        NolonCodexAuthListPayload(
            providerID: providerID,
            activeAccountID: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"),
            accounts: [
                NolonCodexAuthAccountView(
                    id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
                    name: "first",
                    createdAt: .distantPast,
                    relativeAuthPath: "a/auth.json",
                    isActive: true,
                    email: "first@example.com",
                    usageDisplay: "5h 90% / 7d 60%",
                    refreshedAt: Date(timeIntervalSince1970: 1_733_900_000)
                ),
                NolonCodexAuthAccountView(
                    id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
                    name: "second",
                    createdAt: .distantPast,
                    relativeAuthPath: "b/auth.json",
                    isActive: false,
                    email: "second@example.com",
                    usageDisplay: "5h 30% / 7d 20%",
                    refreshedAt: Date(timeIntervalSince1970: 1_733_900_000)
                ),
            ]
        )
    }

    func authUsage(providerID: String) async throws -> NolonCodexAuthUsagePayload {
        NolonCodexAuthUsagePayload(
            providerID: providerID,
            accounts: [
                NolonCodexAuthUsageAccountView(
                    id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
                    email: "first@example.com",
                    isActive: true,
                    fiveHourRemainingPercent: 90,
                    weeklyRemainingPercent: 60,
                    token1dCount: 100_000,
                    token30dCount: 200_000,
                    tokenAllCount: 300_000,
                    refreshedAt: Date(timeIntervalSince1970: 1_733_900_000)
                ),
                NolonCodexAuthUsageAccountView(
                    id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
                    email: "second@example.com",
                    isActive: false,
                    fiveHourRemainingPercent: 30,
                    weeklyRemainingPercent: 20,
                    token1dCount: 110_000,
                    token30dCount: 220_000,
                    tokenAllCount: 330_000,
                    refreshedAt: Date(timeIntervalSince1970: 1_733_900_000)
                ),
            ],
            summary: NolonCodexAuthUsageSummaryView(
                accountCount: 2,
                cachedCount: 2,
                avgFiveHourRemainingPercent: 60,
                avgWeeklyRemainingPercent: 40,
                totalToken1dCount: 210_000,
                totalToken30dCount: 420_000,
                totalTokenAllCount: 630_000,
                latestRefreshedAt: Date(timeIntervalSince1970: 1_733_900_000)
            )
        )
    }

    func authStatus(providerID: String) async throws -> NolonCodexAuthStatusPayload {
        NolonCodexAuthStatusPayload(
            providerID: providerID,
            activeAccountID: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB"),
            accountCount: 2,
            authHashHex: "consistency"
        )
    }

    func authActivate(providerID: String, accountID: UUID) async throws -> NolonCodexAuthActivatePayload { throw unsupported() }
    func authLogin(providerID: String, preferredAccountID: UUID?) async throws -> NolonCodexAuthLoginPayload { throw unsupported() }
    func authDelete(providerID: String, accountID: UUID) async throws -> NolonCodexAuthDeletePayload { throw unsupported() }
    func binaryList() async throws -> NolonCodexBinaryListPayload { throw unsupported() }
    func binaryAvailable() async throws -> NolonCodexBinaryAvailablePayload { throw unsupported() }
    func binaryCurrent() async throws -> NolonCodexBinaryCurrentPayload { throw unsupported() }
    func binaryInstall(version: String, setDefault: Bool) async throws -> NolonCodexBinaryInstallPayload { throw unsupported() }
    func binaryUse(version: String) async throws -> NolonCodexBinaryUsePayload { throw unsupported() }
    func binaryDoctor() async throws -> NolonCodexBinaryDoctorPayload { throw unsupported() }
    func statusProbe(providerID: String?) async throws -> NolonCodexStatusProbePayload { throw unsupported() }
    func runtimeList(providerID: String?) async throws -> NolonCodexRuntimeListPayload { throw unsupported() }
    func runtimeStop(pid: Int32, force: Bool, timeoutSeconds: Int) async throws -> NolonCodexRuntimeStopPayload { throw unsupported() }
    func providerList() async throws -> NolonProviderListPayload { throw unsupported() }
    func providerDiscover() async throws -> NolonCodexProviderDiscoverPayload { throw unsupported() }

    private func unsupported() -> NolonCoreCLIError {
        .invalidArguments("unsupported")
    }
}

private actor AuthListMissingFieldsCodexCLIService: NolonCodexCLIServing {
    func authStatus(providerID: String) async throws -> NolonCodexAuthStatusPayload {
        NolonCodexAuthStatusPayload(providerID: providerID, activeAccountID: nil, accountCount: 1, authHashHex: nil)
    }
    func authActivate(providerID: String, accountID: UUID) async throws -> NolonCodexAuthActivatePayload { throw unsupported() }
    func authLogin(providerID: String, preferredAccountID: UUID?) async throws -> NolonCodexAuthLoginPayload { throw unsupported() }
    func authDelete(providerID: String, accountID: UUID) async throws -> NolonCodexAuthDeletePayload { throw unsupported() }
    func binaryList() async throws -> NolonCodexBinaryListPayload { throw unsupported() }
    func binaryAvailable() async throws -> NolonCodexBinaryAvailablePayload { throw unsupported() }
    func binaryCurrent() async throws -> NolonCodexBinaryCurrentPayload { throw unsupported() }
    func binaryInstall(version: String, setDefault: Bool) async throws -> NolonCodexBinaryInstallPayload { throw unsupported() }
    func binaryUse(version: String) async throws -> NolonCodexBinaryUsePayload { throw unsupported() }
    func binaryDoctor() async throws -> NolonCodexBinaryDoctorPayload { throw unsupported() }
    func statusProbe(providerID: String?) async throws -> NolonCodexStatusProbePayload { throw unsupported() }
    func runtimeList(providerID: String?) async throws -> NolonCodexRuntimeListPayload { throw unsupported() }
    func runtimeStop(pid: Int32, force: Bool, timeoutSeconds: Int) async throws -> NolonCodexRuntimeStopPayload { throw unsupported() }
    func providerList() async throws -> NolonProviderListPayload { throw unsupported() }
    func providerDiscover() async throws -> NolonCodexProviderDiscoverPayload { throw unsupported() }

    func authUsage(providerID: String) async throws -> NolonCodexAuthUsagePayload {
        NolonCodexAuthUsagePayload(
            providerID: providerID,
            accounts: [],
            summary: NolonCodexAuthUsageSummaryView(
                accountCount: 0,
                cachedCount: 0,
                avgFiveHourRemainingPercent: nil,
                avgWeeklyRemainingPercent: nil,
                totalToken1dCount: nil,
                totalToken30dCount: nil,
                totalTokenAllCount: nil,
                earliestExpiresAt: nil,
                latestRefreshedAt: nil
            )
        )
    }

    func authList(providerID: String) async throws -> NolonCodexAuthListPayload {
        NolonCodexAuthListPayload(
            providerID: providerID,
            activeAccountID: nil,
            accounts: [
                NolonCodexAuthAccountView(
                    id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                    name: "unknown",
                    createdAt: .distantPast,
                    relativeAuthPath: "auth/missing.json",
                    isActive: false,
                    email: nil,
                    usageDisplay: nil,
                    refreshedAt: nil
                ),
            ]
        )
    }

    private func unsupported() -> NolonCoreCLIError {
        .invalidArguments("unsupported")
    }
}
