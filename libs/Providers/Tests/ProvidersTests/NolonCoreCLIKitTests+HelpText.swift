import Foundation
import ArgumentParser
import STFilePath
import Testing
@testable import NolonCoreCLIKit
@testable import ProviderUsage

extension NolonCoreCLIKitTests {
    @Test("plugin help text clarifies global resource center behavior")
    func pluginHelpTextClarifiesGlobalResourceCenterBehavior() {
        let help = NolonCoreCLIHelpResolver.resolvedHelpText(arguments: ["plugin"]) ?? ""
        #expect(help.contains("固定写入资源中心-全局"))
        #expect(help.contains("固定从资源中心-全局移除"))
        #expect(help.contains("nolon plugin install --name xcodemcpkit"))
        #expect(help.contains("nolon plugin install --name xcodemcpkit --provider codex") == false)
    }
    @Test("remote help text renders one-parameter-per-line with comments")
    func remoteHelpTextRendersOneParameterPerLineWithComments() {
        let help = NolonCoreCLIHelpResolver.resolvedHelpText(arguments: ["remote"]) ?? ""
        #expect(help.contains("  list\n"))
        #expect(help.contains("--kind skill|workflow|mcp                    # 资源类型（必填）"))
        #expect(help.contains("--slug <slug>                                # 资源标识（必填）"))
        #expect(help.contains("skill 目标:"))
        #expect(help.contains("workflow/mcp 目标:"))
        #expect(help.contains("  list      --kind skill|workflow|mcp") == false)
    }
    @Test("codex auth help text renders one-parameter-per-line with comments")
    func codexAuthHelpTextRendersOneParameterPerLineWithComments() {
        let help = NolonCodexCLIHelpResolver.resolvedHelpText(arguments: ["codex", "auth"]) ?? ""
        #expect(help.contains("Actions:"))
        #expect(help.contains("  list\n"))
        #expect(help.contains("--provider codex|codex-xcode                # 指定 provider（可选）"))
        #expect(help.contains("  list      [--provider codex|codex-xcode]") == false)
    }
    @Test("codex auth usage action help renders one-parameter-per-line with comments")
    func codexAuthUsageActionHelpRendersOneParameterPerLineWithComments() {
        let help = NolonCodexCLIHelpResolver.resolvedHelpText(arguments: ["codex", "auth", "usage", "--help"]) ?? ""
        #expect(help.contains("Usage: nolon codex auth usage [options]"))
        #expect(help.contains("--provider <id>                             # 指定 provider（可选"))
        #expect(help.contains("--summary                                   # 仅输出汇总（可选）"))
        #expect(help.contains("--refresh                                   # 输出前刷新用量缓存（可选）"))
        #expect(help.contains("Options:") == false)
    }
    @Test("codex runtime stop action help renders one-parameter-per-line with comments")
    func codexRuntimeStopActionHelpRendersOneParameterPerLineWithComments() {
        let help = NolonCodexCLIHelpResolver.resolvedHelpText(arguments: ["codex", "runtime", "stop", "--help"]) ?? ""
        #expect(help.contains("Usage: nolon codex runtime stop --pid <pid> [--force] [--timeout-seconds <n>]"))
        #expect(help.contains("--pid <pid>                                 # 进程 PID（必填）"))
        #expect(help.contains("--force                                     # 立即强制结束（可选）"))
        #expect(help.contains("--timeout-seconds <n>                       # 温和结束超时阈值（可选）"))
        #expect(help.contains("Options:") == false)
    }
    @Test("skills help text contains safe install scenario")
    func skillsHelpTextContainsSafeInstallScenario() {
        let help = NolonCoreCLIHelpResolver.resolvedHelpText(arguments: ["skills"]) ?? ""
        #expect(help.contains("场景: 搜索技能"))
        #expect(help.contains("nolon skills search xcode"))
        #expect(help.contains("场景: 安装技能"))
        #expect(help.contains("nolon skills add xcode --provider codex --dry-run"))
        #expect(help.contains("nolon skills add xcode --provider codex\n") == false)
    }
    @Test("skills help text renders one-parameter-per-line with comments")
    func skillsHelpTextRendersOneParameterPerLineWithComments() {
        let help = NolonCoreCLIHelpResolver.resolvedHelpText(arguments: ["skills"]) ?? ""
        #expect(help.contains("  list\n"))
        #expect(help.contains("--provider <id>                              # 按 provider 过滤"))
        #expect(help.contains("--provider-id <id>                           # provider 别名参数"))
        #expect(help.contains("--state installed|orphaned|broken            # 按状态过滤"))
        #expect(help.contains("--dry-run                                    # 仅预览，不落盘"))
        #expect(help.contains("  list      [--provider <id>|--provider-id <id>]") == false)
    }
    @Test("skills repo help text renders one-parameter-per-line with comments")
    func skillsRepoHelpTextRendersOneParameterPerLineWithComments() {
        let help = NolonCoreCLIHelpResolver.resolvedHelpText(arguments: ["skills", "repo"]) ?? ""
        #expect(help.contains("  list\n"))
        #expect(help.contains("--repositories-root <path>                   # 本地仓库根目录（可选）"))
        #expect(help.contains("--credential-strategy automatic|prefer-ssh|token-only|ssh-only  # 凭据策略（可选）"))
        #expect(help.contains("  list       [--repositories-root <path>] [--max-depth <n>] [--verbose]") == false)
    }
    @Test("skills list help summary reflects default abnormal-focus behavior")
    func skillsListHelpSummaryReflectsDefaultAbnormalFocus() {
        let help = NolonRootCommand.message(for: CleanExit.helpRequest(NolonSkillsListCommand.self))
        #expect(help.contains("Inspect skill install states by provider (defaults to orphaned/broken"))
        #expect(help.contains("view)."))
        #expect(help.contains("List installed skills by provider.") == false)
    }
    @Test("workflow list help includes option descriptions")
    func workflowListHelpIncludesOptionDescriptions() {
        let help = NolonRootCommand.message(for: CleanExit.helpRequest(NolonWorkflowListCommand.self))
        #expect(help.contains("Target provider ID. Omit only if you intend"))
        #expect(help.contains("multi-provider distribution to all detected CLI"))
        #expect(help.contains("Alias of --provider. Omit only if you intend"))
        #expect(help.contains("Show full install path for each workflow item."))
        #expect(help.contains("Show repair commands for orphaned/broken items."))
    }
    @Test("workflow help text renders expanded one-parameter-per-line add/search notes")
    func workflowHelpTextRendersExpandedOneParameterPerLineAddSearchNotes() {
        let help = NolonCoreCLIHelpResolver.resolvedHelpText(arguments: ["workflow"]) ?? ""
        #expect(help.contains("--provider <id>                              # 按 provider 过滤"))
        #expect(help.contains("--provider-id <id>                           # provider 别名参数"))
        #expect(help.contains("--dry-run                                    # 与 --install 一起使用，预览执行"))
        #expect(help.contains("--yes                                        # 与 --install 一起使用，确认执行"))
        #expect(help.contains("默认先从本地 repositories-root 查找；未命中则回退远程 base-url。"))
        #expect(help.contains("所有来源统一先缓存到 NOLON_HOME/workflows/<slug>，再分发到目标 provider。"))
        #expect(help.contains("  list      [--provider <id>|--provider-id <id>]") == false)
    }
    @Test("mcp list help includes option descriptions")
    func mcpListHelpIncludesOptionDescriptions() {
        let help = NolonRootCommand.message(for: CleanExit.helpRequest(NolonMcpListCommand.self))
        #expect(help.contains("Target provider ID. Omit only if you intend"))
        #expect(help.contains("multi-provider distribution to all detected CLI"))
        #expect(help.contains("Alias of --provider. Omit only if you intend"))
        #expect(help.contains("Show full install path for each MCP item."))
        #expect(help.contains("Show repair commands for orphaned/broken items."))
    }
    @Test("mcp help text renders expanded one-parameter-per-line add/search notes")
    func mcpHelpTextRendersExpandedOneParameterPerLineAddSearchNotes() {
        let help = NolonCoreCLIHelpResolver.resolvedHelpText(arguments: ["mcp"]) ?? ""
        #expect(help.contains("--provider <id>                              # 按 provider 过滤"))
        #expect(help.contains("--provider-id <id>                           # provider 别名参数"))
        #expect(help.contains("--dry-run                                    # 与 --install 一起使用，预览执行"))
        #expect(help.contains("--yes                                        # 与 --install 一起使用，确认执行"))
        #expect(help.contains("默认先从本地 repositories-root 查找；未命中则回退远程 base-url。"))
        #expect(help.contains("所有来源统一先缓存到 NOLON_HOME/mcps/<slug>，再分发到目标 provider。"))
        #expect(help.contains("  list      [--provider <id>|--provider-id <id>]") == false)
    }
    @Test("runner renders mcp list with state filter keeps matched provider count")
    func runnerRendersMcpListWithStateFilterKeepsMatchedProviderCount() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "mcp", "list",
                "--provider", "codex",
                "--state", "orphaned",
            ],
            outputMode: .text
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("筛选-提供方: codex"))
        #expect(result.stdout.contains("筛选-状态: 失效链接"))
        #expect(result.stdout.contains("providers_matched: 1"))
        #expect(result.stdout.contains("在 provider=codex 且 state=失效链接 下，未发现匹配 MCP 资源。"))
    }
    @Test("runner mcp verbose list renders inline paths without duplicated config section")
    func runnerMcpVerboseListRendersInlinePathsWithoutDuplicatedConfigSection() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "mcp", "list",
                "--verbose",
            ],
            outputMode: .text
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("- codex/playwright\n  path:"))
        #expect(result.stdout.contains("来源: MCP("))
        #expect(result.stdout.contains("[推断]"))
        #expect(result.stdout.contains("origin: ") == false)
        #expect(result.stdout.contains("[配置路径]") == false)
        #expect(result.stdout.contains("config_path:") == false)
    }
    @Test("origin description compacts long source ref and keeps anchor")
    func originDescriptionCompactsLongSourceRefAndKeepsAnchor() {
        let origin = NolonResourceOrigin(
            resourceKind: .mcp,
            sourceType: .fromMcp,
            sourceKind: .mcp,
            sourceRef: "/Users/linhey/Library/Developer/Xcode/CodingAssistant/codex/sessions/2026/02/very/long/path/for/mcp/config.toml#playwright",
            sourceDisplay: "unused",
            createdAt: Date(),
            updatedAt: Date(),
            metadata: ["inferred": "true"]
        )
        let rendered = NolonCoreCLIRunner.originDescriptionForDisplay(origin)
        #expect(rendered.contains("MCP("))
        #expect(rendered.contains("..."))
        #expect(rendered.contains("#playwright"))
        #expect(rendered.contains("[推断]"))
    }
    @Test("origin description localizes source type labels")
    func originDescriptionLocalizesSourceTypeLabels() {
        let now = Date()
        let fromSkill = NolonResourceOrigin(
            resourceKind: .workflow,
            sourceType: .fromSkill,
            sourceKind: .skill,
            sourceRef: "find-skills",
            sourceDisplay: "find-skills",
            createdAt: now,
            updatedAt: now
        )
        let fromWorkflow = NolonResourceOrigin(
            resourceKind: .workflow,
            sourceType: .fromWorkflow,
            sourceKind: .workflow,
            sourceRef: "my-workflow",
            sourceDisplay: "my-workflow",
            createdAt: now,
            updatedAt: now
        )

        #expect(NolonCoreCLIRunner.originDescriptionForDisplay(fromSkill).contains("技能("))
        #expect(NolonCoreCLIRunner.originDescriptionForDisplay(fromWorkflow).contains("工作流("))
    }
    @Test("runner renders workflow list contextual empty message with state filter")
    func runnerRendersWorkflowListContextualEmptyMessageWithStateFilter() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "workflow", "list",
                "--provider", "codex",
                "--state", "broken",
            ],
            outputMode: .text
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("筛选-提供方: codex"))
        #expect(result.stdout.contains("筛选-状态: 损坏"))
        #expect(result.stdout.contains("在 provider=codex 且 state=损坏 下，未发现匹配工作流资源。"))
    }
    @Test("runner workflow show-fixes hides compact summary and keeps detailed commands")
    func runnerWorkflowShowFixesHidesCompactSummaryAndKeepsDetailedCommands() async throws {
        let tempRoot = try STFolder(sanbox: .temporary).folder("nolon-cli-workflow-fixture-\(UUID().uuidString)").create()
        defer { try? tempRoot.delete() }
        let tempHome = tempRoot.folder("home")
        _ = tempHome.createIfNotExists()
        let nolonHome = tempRoot.folder("nolon-home")
        _ = nolonHome.createIfNotExists()
        let workflowCache = nolonHome.folder("workflows")
        _ = workflowCache.createIfNotExists()
        let cacheFile = workflowCache.file("update-agent-skills-workflows.md")
        try "fixture".write(to: cacheFile.url, atomically: true, encoding: .utf8)

        let codexPrompts = tempHome.folder(".codex/prompts")
        _ = codexPrompts.createIfNotExists()
        let opencodeCommands = tempHome.folder(".config/opencode/commands")
        _ = opencodeCommands.createIfNotExists()

        // Two broken links for codex.
        try? FileManager.default.createSymbolicLink(
            atPath: codexPrompts.subpath("find-skills.md").url.path,
            withDestinationPath: "/tmp/non-existent-find-skills.md"
        )
        try? FileManager.default.createSymbolicLink(
            atPath: codexPrompts.subpath("uiagent.md").url.path,
            withDestinationPath: "/tmp/non-existent-uiagent.md"
        )

        // Two installed links (codex + opencode) pointing to cache.
        try? FileManager.default.createSymbolicLink(
            atPath: codexPrompts.subpath("update-agent-skills-workflows.md").url.path,
            withDestinationPath: cacheFile.url.path
        )
        try? FileManager.default.createSymbolicLink(
            atPath: opencodeCommands.subpath("update-agent-skills-workflows.md").url.path,
            withDestinationPath: cacheFile.url.path
        )

        let backupHome = getenv("HOME").map { String(cString: $0) }
        let backupNolon = getenv("NOLON_HOME").map { String(cString: $0) }
        setenv("HOME", tempHome.url.path, 1)
        setenv("NOLON_HOME", nolonHome.url.path, 1)
        defer {
            if let backupHome { setenv("HOME", backupHome, 1) } else { unsetenv("HOME") }
            if let backupNolon { setenv("NOLON_HOME", backupNolon, 1) } else { unsetenv("NOLON_HOME") }
        }

        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "workflow", "list",
                "--show-fixes",
            ],
            outputMode: .text
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("[结论]"))
        #expect(result.stdout.contains("[详情]"))
        #expect(result.stdout.contains("需处理异常:") == false)
        #expect(result.stdout.contains("行动建议:") == false)
        #expect(result.stdout.contains("摘要: 异常="))
        #expect(result.stdout.contains("summary: issues=") == false)
        #expect(result.stdout.contains("先设置前缀变量（与本次入口一致）") == false)
        #expect(result.stdout.contains("[执行约束]") == false)
        #expect(result.stdout.contains("立即执行（清理失效链接，2 项，仅支持 --resource-name <xxx.md>）:") == false)
        #expect(result.stdout.contains("[下一步]") == false)
        #expect(result.stdout.contains("[立即执行（复制即用）]") == false)
        #expect(result.stdout.contains("首条:") == false)
        #expect(result.stdout.contains("其余") == false)

        if result.stdout.contains("异常 0") {
            #expect(result.stdout.contains("健康："))
            #expect(result.stdout.contains("如需查看已安装工作流资源，请执行: `nolon workflow list --state installed`"))
            #expect(result.stdout.contains("修复计划:") == false)
            #expect(result.stdout.contains("[下一步（按顺序执行）]") == false)
            #expect(result.stdout.contains("[一键执行（可复制）]") == false)
        } else {
            #expect(result.stdout.contains("状态(已安装/失效链接/损坏): "))
            #expect(result.stdout.contains("状态：已安装 ") == false)
            #expect(result.stdout.contains("修复计划:"))
            #expect(result.stdout.contains("1. 清理异常项（"))
            #expect(result.stdout.contains("provider: codex"))
            #expect(result.stdout.contains("2. 复检"))
            #expect(result.stdout.contains("1. `nolon workflow remove --resource-name") == false)
            #expect(result.stdout.contains("- `nolon workflow remove --resource-name"))
            #expect(result.stdout.contains("[一键执行（可复制）]") == false)
            #expect(result.stdout.contains("```bash") == false)
            #expect(result.stdout.contains("`nolon workflow list --show-fixes`"))
            #expect(result.stdout.contains("[下一步（按顺序执行）]"))
        }
    }
    @Test("runner workflow default list shows compact fix summary")
    func runnerWorkflowDefaultListShowsCompactFixSummary() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "workflow", "list",
            ],
            outputMode: .text
        )
        #expect(result.exitCode == 0)
        if result.stdout.contains("需处理异常: 0") {
            #expect(result.stdout.contains("修复建议（可复制）:") == false)
            #expect(result.stdout.contains("未发现异常工作流资源（失效链接/损坏）。"))
            #expect(result.stdout.contains("如需查看已安装工作流资源，请执行: `nolon workflow list --state installed`"))
        } else {
            #expect(result.stdout.contains("修复建议（可复制）:"))
            #expect(result.stdout.contains("1) 生成分条修复命令: `nolon workflow list --show-fixes`"))
            #expect(result.stdout.contains("2) 查看路径与来源: `nolon workflow list --verbose --show-fixes`"))
        }
        #expect(result.stdout.contains("立即执行（清理失效链接，") == false)
    }
    @Test("runner workflow verbose abnormal items keep trailing state label format")
    func runnerWorkflowVerboseAbnormalItemsKeepTrailingStateLabelFormat() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "workflow", "list",
                "--verbose",
            ],
            outputMode: .text
        )

        #expect(result.exitCode == 0)
        if result.stdout.contains("[异常]") {
            #expect(result.stdout.contains("- [失效链接] ") == false)
            #expect(result.stdout.contains(" [失效链接]\n  path: "))
        }
    }
    @Test("runner renders remote list result")
    func runnerRendersRemoteListResult() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "remote", "list",
                "--kind", "skill",
                "--query", "react",
            ]
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("\"command\":\"remote.list\""))
        #expect(result.stdout.contains("\"items\""))
        #expect(result.stdout.contains("\"kind\":\"skill\""))
    }
    @Test("runner renders remote download result")
    func runnerRendersRemoteDownloadResult() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "remote", "download",
                "--kind", "mcp",
                "--slug", "cursor-mcp",
            ]
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("\"command\":\"remote.download\""))
        #expect(result.stdout.contains("\"file_path\""))
        #expect(result.stdout.contains("\"kind\":\"mcp\""))
    }
    @Test("runner renders remote sync result")
    func runnerRendersRemoteSyncResult() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "remote", "sync",
                "--source", "vercel/agent-skills",
                "--repositories-root", "/tmp/repos",
                "--max-depth", "7",
            ]
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("\"command\":\"remote.sync\""))
        #expect(result.stdout.contains("\"plan\""))
        #expect(result.stdout.contains("\"resources\""))
        #expect(result.stdout.contains("\"workflows\""))
        #expect(result.stdout.contains("\"mcps\""))
    }
    @Test("runner renders remote sync-install skill result")
    func runnerRendersRemoteSyncInstallSkillResult() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "remote", "sync-install",
                "--kind", "skill",
                "--source", "vercel/agent-skills",
                "--repositories-root", "/tmp/repos",
                "--path", "skills/react-best-practices",
                "--provider-id", "codex",
                "--install-method", "copy",
            ]
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("\"command\":\"remote.sync-install\""))
        #expect(result.stdout.contains("\"install\""))
        #expect(result.stdout.contains("\"kind\":\"skill\""))
        #expect(result.stdout.contains("\"repository_file_path\""))
        #expect(result.stdout.contains("skills\\/react-best-practices"))
        #expect(result.stdout.contains("\"install_method\":\"copy\""))
    }
    @Test("runner rejects remote sync-install path outside repository root")
    func runnerRejectsRemoteSyncInstallPathOutsideRepositoryRoot() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "remote", "sync-install",
                "--kind", "skill",
                "--source", "vercel/agent-skills",
                "--repositories-root", "/tmp/repos",
                "--path", "../outside-skill",
                "--provider-id", "codex",
            ]
        )
        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("\"code\":\"invalid_arguments\""))
        #expect(result.stderr.contains("outside synced repository root"))
    }
    @Test("runner renders remote sync-install workflow result")
    func runnerRendersRemoteSyncInstallWorkflowResult() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "remote", "sync-install",
                "--kind", "workflow",
                "--source", "vercel/agent-skills",
                "--repositories-root", "/tmp/repos",
                "--path", "workflows/review.md",
                "--provider-id", "opencode",
            ]
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("\"command\":\"remote.sync-install\""))
        #expect(result.stdout.contains("\"kind\":\"workflow\""))
        #expect(result.stdout.contains("workflows\\/review.md"))
        #expect(result.stdout.contains("\"resource_name\":\"review.md\""))
    }
    @Test("runner renders remote sync-install workflow result with slug selector")
    func runnerRendersRemoteSyncInstallWorkflowResultWithSlugSelector() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "remote", "sync-install",
                "--kind", "workflow",
                "--source", "vercel/agent-skills",
                "--repositories-root", "/tmp/repos",
                "--slug", "review",
                "--provider-id", "opencode",
            ]
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("\"command\":\"remote.sync-install\""))
        #expect(result.stdout.contains("\"kind\":\"workflow\""))
        #expect(result.stdout.contains("workflows\\/review.md"))
        #expect(result.stdout.contains("\"resource_name\":\"review.md\""))
        #expect(result.stdout.contains("\"warnings\""))
        #expect(result.stdout.contains("Ambiguous --slug 'review'"))
    }
    @Test("runner rejects ambiguous slug when strict selector enabled")
    func runnerRejectsAmbiguousSlugWhenStrictSelectorEnabled() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "remote", "sync-install",
                "--kind", "workflow",
                "--source", "vercel/agent-skills",
                "--repositories-root", "/tmp/repos",
                "--slug", "review",
                "--strict-selector", "true",
                "--provider-id", "opencode",
            ]
        )
        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("\"code\":\"invalid_arguments\""))
        #expect(result.stderr.contains("Ambiguous --slug"))
    }
    @Test("runner renders remote sync-install skill result with slug selector warning")
    func runnerRendersRemoteSyncInstallSkillResultWithSlugSelectorWarning() async {
        let resources = NolonRepositoryResources(
            skillsDirectories: [
                NolonSkillsDirectoryCandidate(path: "skills", skillCount: 1, skillNames: ["agent-browser"]),
                NolonSkillsDirectoryCandidate(path: "community/skills", skillCount: 1, skillNames: ["agent-browser"]),
            ],
            workflows: [],
            mcps: []
        )
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(repositoryResources: resources),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "remote", "sync-install",
                "--kind", "skill",
                "--source", "vercel/agent-skills",
                "--repositories-root", "/tmp/repos",
                "--slug", "agent-browser",
                "--provider-id", "codex",
            ]
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("\"command\":\"remote.sync-install\""))
        #expect(result.stdout.contains("\"kind\":\"skill\""))
        #expect(result.stdout.contains("skills\\/agent-browser"))
        #expect(result.stdout.contains("\"warnings\""))
        #expect(result.stdout.contains("Ambiguous --slug 'agent-browser'"))
    }
    @Test("runner rejects ambiguous skill slug when strict selector enabled")
    func runnerRejectsAmbiguousSkillSlugWhenStrictSelectorEnabled() async {
        let resources = NolonRepositoryResources(
            skillsDirectories: [
                NolonSkillsDirectoryCandidate(path: "skills", skillCount: 1, skillNames: ["agent-browser"]),
                NolonSkillsDirectoryCandidate(path: "community/skills", skillCount: 1, skillNames: ["agent-browser"]),
            ],
            workflows: [],
            mcps: []
        )
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(repositoryResources: resources),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "remote", "sync-install",
                "--kind", "skill",
                "--source", "vercel/agent-skills",
                "--repositories-root", "/tmp/repos",
                "--slug", "agent-browser",
                "--strict-selector", "true",
                "--provider-id", "codex",
            ]
        )
        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("\"code\":\"invalid_arguments\""))
        #expect(result.stderr.contains("Ambiguous --slug"))
    }
    @Test("runner renders remote install skill result")
    func runnerRendersRemoteInstallSkillResult() async {
        let tempNolonHome = STFolder("/tmp").folder("nolon-core-cli-home-\(UUID().uuidString)")
        _ = tempNolonHome.createIfNotExists()
        defer { try? tempNolonHome.delete() }
        let backup = getenv("NOLON_HOME").map { String(cString: $0) }
        setenv("NOLON_HOME", tempNolonHome.url.path, 1)
        defer {
            if let backup {
                setenv("NOLON_HOME", backup, 1)
            } else {
                unsetenv("NOLON_HOME")
            }
        }

        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "remote", "install",
                "--kind", "skill",
                "--slug", "react-best-practices",
                "--provider-path", "/tmp/provider",
                "--install-method", "copy",
            ]
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("\"command\":\"remote.install\""))
        #expect(result.stdout.contains("\"kind\":\"skill\""))
        #expect(result.stdout.contains("\"downloaded_file_path\""))
        #expect(result.stdout.contains("\"installed_path\""))
        #expect(result.stdout.contains("\"install_method\":\"copy\""))
        #expect(result.stdout.contains("\"skill_id\":\"react-best-practices\""))
    }
}
