import Foundation
import ArgumentParser
import STFilePath
import Testing
@testable import NolonCoreCLIKit
@testable import ProviderUsage

extension NolonCoreCLIKitTests {
    @Test("parse remote install skill rejects duplicate provider selector")
    func parseRemoteInstallSkillRejectsDuplicateProviderSelector() {
        do {
            _ = try NolonCoreCLIArgumentParser.parse(
                [
                    "remote", "install",
                    "--kind", "skill",
                    "--slug", "react-best-practices",
                    "--provider-path", "/tmp/provider",
                    "--provider-id", "codex",
                ]
            )
            Issue.record("Expected invalid_arguments")
        } catch let error as NolonCoreCLIError {
            #expect(error.code == "invalid_arguments")
            #expect((error.errorDescription ?? "").contains("Use only one target selector: --provider-path or --provider-id"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
    @Test("parse remote install workflow rejects duplicate target selector")
    func parseRemoteInstallWorkflowRejectsDuplicateTargetSelector() {
        do {
            _ = try NolonCoreCLIArgumentParser.parse(
                [
                    "remote", "install",
                    "--kind", "workflow",
                    "--slug", "daily-review",
                    "--target-path", "/tmp/workflows",
                    "--provider-id", "opencode",
                ]
            )
            Issue.record("Expected invalid_arguments")
        } catch let error as NolonCoreCLIError {
            #expect(error.code == "invalid_arguments")
            #expect((error.errorDescription ?? "").contains("Use only one target selector: --target-path or --provider-id"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
    @Test("parse skills install command")
    func parseSkillsInstall() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "skills", "install",
                "--skill-path", "/tmp/skills/react-best-practices",
                "--provider-path", "/tmp/provider",
                "--install-method", "copy",
                "--skill-id", "react-best-practices",
            ]
        )

        guard case let .skillsInstall(skillPath, skillID, providerPath, installMethod) = command else {
            Issue.record("Expected .skillsInstall")
            return
        }
        #expect(skillPath == "/tmp/skills/react-best-practices")
        #expect(skillID == "react-best-practices")
        #expect(providerPath == "/tmp/provider")
        #expect(installMethod == .copy)
    }
    @Test("parse skills uninstall command")
    func parseSkillsUninstall() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "skills", "uninstall",
                "--skill-id", "react-best-practices",
                "--provider-path", "/tmp/provider",
            ]
        )

        guard case let .skillsUninstall(skillID, providerPath) = command else {
            Issue.record("Expected .skillsUninstall")
            return
        }
        #expect(skillID == "react-best-practices")
        #expect(providerPath == "/tmp/provider")
    }
    @Test("parse skills remove command with provider id")
    func parseSkillsRemoveWithProviderID() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "skills", "remove",
                "--skill-id", "react-best-practices",
                "--provider", "codex",
            ]
        )

        guard case let .skillsUninstall(skillID, providerPath) = command else {
            Issue.record("Expected .skillsUninstall")
            return
        }
        #expect(skillID == "react-best-practices")
        #expect(providerPath.hasSuffix("/.codex/skills"))
    }
    @Test("parse skills remove command rejects missing target selector")
    func parseSkillsRemoveRejectsMissingTargetSelector() {
        do {
            _ = try NolonCoreCLIArgumentParser.parse(
                [
                    "skills", "remove",
                    "--skill-id", "react-best-practices",
                ]
            )
            Issue.record("Expected invalid target selector")
        } catch let error as NolonCoreCLIError {
            #expect(error.code == "invalid_arguments")
            #expect(error.localizedDescription.contains("--provider-path"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
    @Test("parse skills migrate scan command")
    func parseSkillsMigrateScan() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "skills", "migrate", "scan",
                "--provider-path", "/tmp/provider",
                "--global-skills-path", "/tmp/global-skills",
            ]
        )
        guard case let .skillsMigrateScan(providerPath, globalSkillsPath) = command else {
            Issue.record("Expected .skillsMigrateScan")
            return
        }
        #expect(providerPath == "/tmp/provider")
        #expect(globalSkillsPath == "/tmp/global-skills")
    }
    @Test("parse skills migrate apply command")
    func parseSkillsMigrateApply() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "skills", "migrate", "apply",
                "--skill-id", "react-best-practices",
                "--provider-path", "/tmp/provider",
                "--global-skills-path", "/tmp/global-skills",
                "--install-method", "copy",
            ]
        )
        guard case let .skillsMigrateApply(skillID, providerPath, globalSkillsPath, installMethod) = command else {
            Issue.record("Expected .skillsMigrateApply")
            return
        }
        #expect(skillID == "react-best-practices")
        #expect(providerPath == "/tmp/provider")
        #expect(globalSkillsPath == "/tmp/global-skills")
        #expect(installMethod == .copy)
    }
    @Test("runner renders install result")
    func runnerRendersInstallResult() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )

        let result = await runner.execute(
            arguments: [
                "skills", "install",
                "--skill-path", "/tmp/skills/react-best-practices",
                "--provider-path", "/tmp/provider",
                "--install-method", "symlink",
            ]
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("\"command\":\"skills.install\""))
        #expect(result.stdout.contains("\"install_method\":\"symlink\""))
        #expect(result.stdout.contains("\"skill_id\":\"react-best-practices\""))
    }
    @Test("runner renders uninstall result")
    func runnerRendersUninstallResult() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )

        let result = await runner.execute(
            arguments: [
                "skills", "uninstall",
                "--skill-id", "react-best-practices",
                "--provider-path", "/tmp/provider",
            ]
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("\"command\":\"skills.uninstall\""))
        #expect(result.stdout.contains("\"removed\":true"))
        #expect(result.stdout.contains("\"skill_id\":\"react-best-practices\""))
    }
    @Test("runner renders migrate scan result")
    func runnerRendersMigrateScanResult() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "skills", "migrate", "scan",
                "--provider-path", "/tmp/provider",
                "--global-skills-path", "/tmp/global-skills",
            ]
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("\"command\":\"skills.migrate.scan\""))
        #expect(result.stdout.contains("\"states\""))
        #expect(result.stdout.contains("\"state\":\"orphaned\""))
    }
    @Test("runner renders migrate apply result")
    func runnerRendersMigrateApplyResult() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "skills", "migrate", "apply",
                "--skill-id", "react-best-practices",
                "--provider-path", "/tmp/provider",
                "--global-skills-path", "/tmp/global-skills",
            ]
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("\"command\":\"skills.migrate.apply\""))
        #expect(result.stdout.contains("\"skill_id\":\"react-best-practices\""))
    }
    @Test("runner renders workflow list json")
    func runnerRendersWorkflowList() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )

        let result = await runner.execute(
            arguments: ["workflow", "list", "--provider", "codex"]
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("\"command\":\"workflow.list\""))
        #expect(result.stdout.contains("\"result\""))
    }
    @Test("runner renders mcp list json")
    func runnerRendersMcpList() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )

        let result = await runner.execute(
            arguments: ["mcp", "list", "--provider", "codex"]
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("\"command\":\"mcp.list\""))
        #expect(result.stdout.contains("\"result\""))
    }
    @Test("runner renders mcp server list text")
    func runnerRendersMcpServerListText() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )

        let result = await runner.execute(
            arguments: ["mcp", "server", "list", "--provider", "codex"],
            outputMode: .text
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("mcp server list"))
        #expect(result.stdout.contains("provider: codex"))
        #expect(result.stdout.contains("[servers]"))
        #expect(result.stdout.contains("- name: playwright"))
    }
    @Test("runner renders mcp cache status json")
    func runnerRendersMcpCacheStatusJSON() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )

        let result = await runner.execute(
            arguments: ["mcp", "cache", "status", "--provider", "codex"]
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("\"command\":\"mcp.cache.status\""))
        #expect(result.stdout.contains("\"state\":\"migrated_up_to_date\""))
    }
    @Test("mcp list sources server names from service layer")
    func mcpListSourcesServerNamesFromServiceLayer() throws {
        let service = MockSkillsRepositoryService()
        let result = try service.listMcpServers(provider: "codex")
        #expect(result.providerID == "codex")
        #expect(result.items.map(\.name) == ["playwright"])
    }
    @Test("mcp list output reflects service-provided server names")
    func mcpListOutputReflectsServiceProvidedServerNames() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(arguments: ["mcp", "list", "--provider", "codex"])
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("\"skill_id\":\"playwright\""))
        #expect(result.stdout.contains("\"skill_id\":\"AGENTS.md\"") == false)
    }
    @Test("resource fix command builder renders compact and detailed commands")
    func resourceFixCommandBuilderRendersCompactAndDetailedCommands() {
        let items: [NolonSkillsListItem] = [
            .init(providerID: "codex", providerPath: "/tmp/a", skillID: "a.md", state: .orphaned, path: "/tmp/a/a.md", origin: nil),
            .init(providerID: "opencode", providerPath: "/tmp/b", skillID: "b.md", state: .broken, path: "/tmp/b/b.md", origin: nil),
            .init(providerID: "codex", providerPath: "/tmp/c", skillID: "ok.md", state: .installed, path: "/tmp/c/ok.md", origin: nil),
        ]

        let commands = NolonCoreCLIRunner.buildResourceFixCommands(kind: .workflow, items: items)
        #expect(commands.simple == "nolon workflow remove --resource-name a.md --provider codex")
        #expect(commands.detailed.count == 2)
        #expect(commands.detailed[0] == "nolon workflow remove --resource-name a.md --provider codex")
        #expect(commands.detailed[1] == "nolon workflow remove --resource-name b.md --provider opencode")
    }
    @Test("resource fix command builder returns empty for installed-only items")
    func resourceFixCommandBuilderReturnsEmptyForInstalledOnlyItems() {
        let items: [NolonSkillsListItem] = [
            .init(providerID: "codex", providerPath: "/tmp", skillID: "ok.md", state: .installed, path: "/tmp/ok.md", origin: nil),
        ]

        let commands = NolonCoreCLIRunner.buildResourceFixCommands(kind: .mcp, items: items)
        #expect(commands.simple.isEmpty)
        #expect(commands.detailed.isEmpty)
    }
    @Test("skill fix command builder renders skills commands")
    func skillFixCommandBuilderRendersSkillsCommands() {
        let items: [NolonSkillsListItem] = [
            .init(providerID: "codex", providerPath: "/tmp/a", skillID: "find-skills", state: .orphaned, path: "/tmp/a/find-skills", origin: nil),
            .init(providerID: "opencode", providerPath: "/tmp/b", skillID: "agent-browser", state: .broken, path: "/tmp/b/agent-browser", origin: nil),
        ]

        let commands = NolonCoreCLIRunner.buildSkillFixCommands(items: items)
        #expect(commands.simple == "nolon skills remove --skill-id find-skills --provider codex")
        #expect(commands.detailed.count == 2)
        #expect(commands.detailed[0] == "nolon skills remove --skill-id find-skills --provider codex")
        #expect(
            commands.detailed[1] ==
            "nolon skills remove --skill-id agent-browser --provider opencode && nolon skills add agent-browser --provider opencode"
        )
    }
    @Test("runner renders mcp remove result")
    func runnerRendersMcpRemoveResult() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "mcp", "remove",
                "--resource-name", "cursor-mcp.json",
                "--target-path", "/tmp/provider/mcp",
            ]
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("\"command\":\"mcp.remove\""))
        #expect(result.stdout.contains("\"removed\":true"))
        #expect(result.stdout.contains("\"kind\":\"mcp\""))
    }
    @Test("runner renders workflow list text with state filter label")
    func runnerRendersWorkflowListTextWithStateFilterLabel() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "workflow", "list",
                "--provider", "codex",
                "--state", "orphaned",
            ],
            outputMode: .text
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("筛选-提供方: codex"))
        #expect(result.stdout.contains("筛选-状态: 失效链接"))
        #expect(result.stdout.contains("workflow_total: "))
    }
    @Test("runner workflow installed filter does not add extra blank lines before installed section")
    func runnerWorkflowInstalledFilterAvoidsExtraBlankLinesBeforeInstalledSection() async {
        let runner = NolonCoreCLIRunner(
            service: InstalledAndBrokenSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "workflow", "list",
                "--provider", "codex",
                "--state", "installed",
                "--show-fixes",
            ],
            outputMode: .text
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("筛选-状态: 已安装"))
        if result.stdout.contains("[已安装]") {
            #expect(result.stdout.contains("筛选-状态: 已安装\n\n\n[已安装]") == false)
            #expect(result.stdout.contains("当前筛选条件下无可修复项；请移除筛选后重试 --show-fixes。"))
            #expect(result.stdout.contains("复检命令: `nolon workflow list --show-fixes`"))
            #expect(result.stdout.contains("状态健康，无需修复；修复建议已启用但当前无可修复项。") == false)
        } else {
            #expect(result.stdout.contains("在 provider=codex 且 state=已安装 下，未发现匹配工作流资源。"))
        }
    }
    @Test("runner workflow installed verbose show-fixes does not add extra blank lines before installed section")
    func runnerWorkflowInstalledVerboseShowFixesAvoidsExtraBlankLinesBeforeInstalledSection() async {
        let runner = NolonCoreCLIRunner(
            service: InstalledAndBrokenSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "workflow", "list",
                "--provider", "codex",
                "--state", "installed",
                "--verbose",
                "--show-fixes",
            ],
            outputMode: .text
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("筛选-状态: 已安装"))
        if result.stdout.contains("[已安装]") {
            #expect(result.stdout.contains("筛选-状态: 已安装\n\n\n[已安装]") == false)
            #expect(result.stdout.contains("[已安装]\n- codex/update-agent-skills-workflows.md"))
            #expect(result.stdout.contains("复检命令: `nolon workflow list --show-fixes`"))
        } else {
            #expect(result.stdout.contains("在 provider=codex 且 state=已安装 下，未发现匹配工作流资源。"))
        }
    }
    @Test("runner workflow fix hints keep provider filter in commands")
    func runnerWorkflowFixHintsKeepProviderFilterInCommands() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "workflow", "list",
                "--provider", "codex",
            ],
            outputMode: .text
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("[结论]"))
        if result.stdout.contains("需处理异常: 0") {
            #expect(result.stdout.contains("在 provider=codex 下，未发现异常工作流资源（失效链接/损坏）。"))
            #expect(result.stdout.contains("如需查看已安装工作流资源，请执行: `nolon workflow list --provider codex --state installed`"))
            #expect(result.stdout.contains("[下一步（可复制执行）]") == false)
            #expect(result.stdout.contains("摘要:") == false)
        } else {
            #expect(result.stdout.contains("行动建议: 需处理"))
            #expect(result.stdout.contains("摘要:") == false)
            #expect(result.stdout.contains("修复建议（可复制）:"))
            #expect(result.stdout.contains("[下一步（可复制执行）]"))
            #expect(result.stdout.contains("先设置前缀变量（与本次入口一致）") == false)
            #expect(
                result.stdout.contains("1) 生成分条修复命令: `nolon workflow list --provider codex --show-fixes`")
                || result.stdout.contains("1) `nolon workflow remove --resource-name")
            )
            #expect(result.stdout.contains("2) 查看路径与来源: `nolon workflow list --provider codex --verbose --show-fixes`"))
        }
        #expect(result.stdout.contains("[下一步]") == false)
        #expect(result.stdout.contains("[立即执行（复制即用）]") == false)
    }
    @Test("runner renders mcp list text with provider filter label")
    func runnerRendersMcpListTextWithProviderFilterLabel() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "mcp", "list",
                "--provider", "codex",
            ],
            outputMode: .text
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("筛选-提供方: codex"))
        #expect(result.stdout.contains("mcp_total: "))
        if result.stdout.contains("需处理异常: 0") {
            #expect(result.stdout.contains("如需查看已安装 MCP 资源，请执行: `nolon mcp list --provider codex --state installed`"))
        }
    }
    @Test("runner mcp show-fixes prints explicit no-op hint when no issues")
    func runnerMcpShowFixesPrintsNoOpHintWhenNoIssues() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "mcp", "list",
                "--show-fixes",
            ],
            outputMode: .text
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("健康："))
        #expect(result.stdout.contains("（100.0%），异常 0，修复动作：无。"))
        #expect(result.stdout.contains("如需查看已安装 MCP 资源，请执行: `nolon mcp list --state installed`"))
        #expect(result.stdout.contains("未发现异常 MCP 资源（失效链接/损坏）。") == false)
        #expect(result.stdout.contains("[下一步（可复制执行）]") == false)
        #expect(result.stdout.contains("可选复检:") == false)
        #expect(result.stdout.contains("立即执行（清理失效链接，") == false)
    }
    @Test("runner mcp verbose show-fixes uses unified healthy summary line")
    func runnerMcpVerboseShowFixesUsesUnifiedHealthySummaryLine() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "mcp", "list",
                "--verbose",
                "--show-fixes",
            ],
            outputMode: .text
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("[详情]"))
        #expect(result.stdout.contains("摘要: 异常=0 | 已安装="))
        #expect(result.stdout.contains(" | 修复动作=无"))
        #expect(result.stdout.contains("summary: issues=") == false)
        #expect(result.stdout.contains("健康："))
        #expect(result.stdout.contains("（100.0%），异常 0，修复动作：无。"))
        #expect(result.stdout.contains("结论：全部健康") == false)
    }
    @Test("workflow help text contains scenarios")
    func workflowHelpTextContainsScenarios() {
        let help = NolonCoreCLIHelpResolver.resolvedHelpText(arguments: ["workflow"]) ?? ""
        #expect(help.contains("场景: 搜索工作流"))
        #expect(help.contains("nolon workflow search xcode"))
        #expect(help.contains("场景: 安装工作流"))
        #expect(help.contains("场景: 从 skill 绑定 workflow"))
        #expect(help.contains("nolon workflow bind-skill --skill-id find-skills --provider codex"))
        #expect(help.contains("场景: 从 mcp 解绑 workflow"))
        #expect(help.contains("nolon workflow unbind-mcp --mcp-name playwright --provider codex"))
    }
    @Test("mcp help text contains scenarios")
    func mcpHelpTextContainsScenarios() {
        let help = NolonCoreCLIHelpResolver.resolvedHelpText(arguments: ["mcp"]) ?? ""
        #expect(help.contains("场景: 搜索 MCP"))
        #expect(help.contains("nolon mcp search xcode"))
        #expect(help.contains("场景: 管理 MCP servers"))
        #expect(help.contains("nolon mcp server list --provider codex"))
        #expect(help.contains("nolon mcp server set-enabled --provider codex --name playwright --disabled"))
        #expect(help.contains("场景: 迁移 MCP cache"))
        #expect(help.contains("nolon mcp cache migrate --provider codex --overwrite"))
        #expect(help.contains("nolon mcp cache status --provider codex --name playwright"))
        #expect(help.contains("场景: 修复异常"))
    }
    @Test("mcp help text includes server and cache subcommands")
    func mcpHelpTextIncludesServerAndCacheSubcommands() {
        let help = NolonCoreCLIHelpResolver.resolvedHelpText(arguments: ["mcp"]) ?? ""
        #expect(help.contains("server list"))
        #expect(help.contains("--name <name>                                # 服务器名称（必填）"))
        #expect(help.contains("cache status"))
        #expect(help.contains("--overwrite                                  # 覆盖已存在缓存（可选）"))
        #expect(help.contains("  list      [--provider <id>|--provider-id <id>]") == false)
    }
}
