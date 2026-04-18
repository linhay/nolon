import Foundation
import ArgumentParser
import STFilePath
import Testing
@testable import NolonCoreCLIKit
@testable import ProviderUsage

extension NolonCoreCLIKitTests {
    @Test("runner search install out-of-range pick quotes spaced query in hint")
    func runnerSearchInstallOutOfRangePickQuotesSpacedQueryInHint() async {
        let runner = NolonCoreCLIRunner(
            service: ManyMatchRemoteSearchMockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "skills", "search", "ios app",
                "--install",
                "--pick", "99",
                "--provider", "codex",
                "--dry-run",
            ],
            outputMode: .text
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("Review candidates: nolon skills search 'ios app' --provider codex"))
        #expect(result.stderr.contains("Then retry: nolon skills search 'ios app' --install --pick <1-20> --provider codex --dry-run"))
    }
    @Test("runner search install prioritizes explicit pick over exact match")
    func runnerSearchInstallPrioritizesExplicitPickOverExactMatch() async throws {
        let tempRoot = try STFolder(sanbox: .temporary).folder("nolon-cli-search-install-pick-over-exact-\(UUID().uuidString)").create()
        defer { try? tempRoot.delete() }

        let nolonHome = tempRoot.folder("nolon-home")
        _ = nolonHome.createIfNotExists()
        setenv("NOLON_HOME", nolonHome.url.path, 1)
        defer { unsetenv("NOLON_HOME") }

        let runner = NolonCoreCLIRunner(
            service: MultiMatchRemoteSearchMockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "skills", "search", "xcode",
                "--install",
                "--pick", "2",
                "--provider", "codex",
                "--dry-run",
            ],
            outputMode: .text
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("skill: xcodebuildmcp (remote)"))
    }
    @Test("runner search install not-found returns actionable hint")
    func runnerSearchInstallNotFoundReturnsActionableHint() async {
        let runner = NolonCoreCLIRunner(
            service: EmptySkillLookupMockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "skills", "search", "nomatchkeyword123",
                "--install",
                "--dry-run",
            ],
            outputMode: .text
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("\"code\":\"skill_not_found\""))
        #expect(result.stderr.contains("Skill not found by query: nomatchkeyword123"))
        #expect(result.stderr.contains("nolon skills sync --source"))
        #expect(result.stderr.contains("nolon skills search nomatchkeyword123"))
    }
    @Test("runner workflow search install not-found returns workflow-specific hint")
    func runnerWorkflowSearchInstallNotFoundReturnsWorkflowSpecificHint() async {
        let runner = NolonCoreCLIRunner(
            service: EmptySkillLookupMockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "workflow", "search", "nomatchkeyword123",
                "--install",
                "--dry-run",
            ],
            outputMode: .text
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("\"code\":\"workflow_not_found\""))
        #expect(result.stderr.contains("Workflow not found by query: nomatchkeyword123"))
        #expect(result.stderr.contains("nolon workflow sync --source"))
        #expect(result.stderr.contains("nolon workflow search nomatchkeyword123"))
    }
    @Test("runner mcp search install not-found returns mcp-specific hint")
    func runnerMcpSearchInstallNotFoundReturnsMcpSpecificHint() async {
        let runner = NolonCoreCLIRunner(
            service: EmptySkillLookupMockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "mcp", "search", "nomatchkeyword123",
                "--install",
                "--dry-run",
            ],
            outputMode: .text
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("\"code\":\"mcp_not_found\""))
        #expect(result.stderr.contains("MCP not found by query: nomatchkeyword123"))
        #expect(result.stderr.contains("nolon mcp sync --source"))
        #expect(result.stderr.contains("nolon mcp search nomatchkeyword123"))
    }
    @Test("runner workflow search install keeps workflow-specific ambiguity hints")
    func runnerWorkflowSearchInstallKeepsWorkflowSpecificAmbiguityHints() async {
        let runner = NolonCoreCLIRunner(
            service: MultiMatchRemoteSearchMockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "workflow", "search", "xco",
                "--install",
                "--provider", "codex",
                "--dry-run",
            ],
            outputMode: .text
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("--install requires exactly one match"))
        #expect(result.stderr.contains("nolon workflow add <slug>"))
        #expect(result.stderr.contains("nolon workflow search xcode --install --provider codex --dry-run"))
        #expect(result.stderr.contains("nolon workflow search xco --install --pick 1 --provider codex --dry-run"))
    }
    @Test("runner search install ambiguity hint quotes spaced query")
    func runnerSearchInstallAmbiguityHintQuotesSpacedQuery() async {
        let runner = NolonCoreCLIRunner(
            service: ManyMatchRemoteSearchMockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "skills", "search", "ios app",
                "--install",
                "--provider", "codex",
                "--dry-run",
            ],
            outputMode: .text
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("Or disambiguate with --pick: nolon skills search 'ios app' --install --pick 1 --provider codex --dry-run"))
    }
    @Test("runner workflow search out-of-range pick keeps workflow namespace hint")
    func runnerWorkflowSearchOutOfRangePickKeepsWorkflowNamespaceHint() async {
        let runner = NolonCoreCLIRunner(
            service: MultiMatchRemoteSearchMockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "workflow", "search", "xco",
                "--install",
                "--pick", "99",
                "--provider", "codex",
                "--dry-run",
            ],
            outputMode: .text
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("--pick is out of range"))
        #expect(result.stderr.contains("Review candidates: nolon workflow search xco --provider codex"))
        #expect(result.stderr.contains("Then retry: nolon workflow search xco --install --pick <1-2> --provider codex --dry-run"))
    }
    @Test("runner maps remote 429 to actionable rate limit error")
    func runnerMapsRemote429ToActionableRateLimitError() async {
        let runner = NolonCoreCLIRunner(
            service: RateLimitedRemoteSearchMockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "skills", "search", "xcode",
            ],
            outputMode: .text
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("Error [rate_limited]"))
        #expect(result.stderr.contains("远端请求被限流（429）"))
        #expect(result.stderr.contains("请等待 30 秒后重试"))
        #expect(result.stderr.contains("nolon skills sync --source <owner/repo>"))
        #expect(result.stderr.contains("nolon skills add <slug> --dry-run"))
    }
    @Test("runner maps remote 404 to actionable catalog unavailable error")
    func runnerMapsRemote404ToActionableCatalogUnavailableError() async {
        let runner = NolonCoreCLIRunner(
            service: RemoteCatalogUnavailableMockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "workflow", "search", "xcode",
            ],
            outputMode: .text
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("Error [remote_catalog_unavailable]"))
        #expect(result.stderr.contains("远端目录当前不可用或不支持该资源类型（404）"))
        #expect(result.stderr.contains("nolon workflow sync --source <owner/repo>"))
        #expect(result.stderr.contains("nolon workflow add <slug> --provider codex --dry-run"))
        #expect(result.stderr.contains("nolon workflow list --verbose"))
        #expect(result.stderr.contains("nolon skills repo list --verbose"))
        #expect(result.stderr.contains("nolon skills sync --source") == false)
        #expect(result.stderr.contains("nolon mcp sync --source") == false)
    }
    @Test("runner maps remote 404 to mcp-specific catalog unavailable error")
    func runnerMapsRemote404ToMcpSpecificCatalogUnavailableError() async {
        let runner = NolonCoreCLIRunner(
            service: RemoteCatalogUnavailableMockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "mcp", "search", "xcode",
            ],
            outputMode: .text
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("Error [remote_catalog_unavailable]"))
        #expect(result.stderr.contains("nolon mcp sync --source <owner/repo>"))
        #expect(result.stderr.contains("nolon mcp add <slug> --provider codex --dry-run"))
        #expect(result.stderr.contains("nolon mcp list --verbose"))
        #expect(result.stderr.contains("nolon skills repo list --verbose"))
        #expect(result.stderr.contains("nolon skills sync --source") == false)
        #expect(result.stderr.contains("nolon workflow sync --source") == false)
    }
    @Test("runner maps permission denied to actionable error")
    func runnerMapsPermissionDeniedToActionableError() async {
        let runner = NolonCoreCLIRunner(
            service: PermissionDeniedRemoteSearchMockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "skills", "search", "xcode",
            ],
            outputMode: .text
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("Error [permission_denied]"))
        #expect(result.stderr.contains("权限不足（Operation not permitted）"))
        #expect(result.stderr.contains("建议: NOLON_HOME=/tmp/nolon-home"))
        #expect(result.stderr.contains("建议: 使用 `nolon skills list`"))
    }
    @Test("runner keeps json envelope for permission denied in json mode")
    func runnerKeepsJSONEnvelopeForPermissionDeniedInJSONMode() async {
        let runner = NolonCoreCLIRunner(
            service: PermissionDeniedRemoteSearchMockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "skills", "search", "xcode",
            ],
            outputMode: .json
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("\"code\":\"permission_denied\""))
        #expect(result.stderr.contains("\"ok\":false"))
    }
    @Test("runner search install requires non-empty query with actionable hint")
    func runnerSearchInstallRequiresNonEmptyQueryWithActionableHint() async {
        let runner = NolonCoreCLIRunner(
            service: EmptySkillLookupMockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "skills", "search",
                "--install",
                "--dry-run",
            ],
            outputMode: .text
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("\"code\":\"invalid_arguments\""))
        #expect(result.stderr.contains("--install requires a non-empty query"))
        #expect(result.stderr.contains("nolon skills search <keyword> --install --dry-run"))
        #expect(result.stderr.contains("nolon skills search <keyword> --install --yes --provider codex"))
        #expect(result.stderr.contains("nolon skills search --query <text> --install --dry-run"))
        #expect(result.stderr.contains("nolon skills search --query <text> --install --yes --provider codex"))
    }
    @Test("runner mcp search install requires non-empty query with mcp-specific hint")
    func runnerMcpSearchInstallRequiresNonEmptyQueryWithMcpSpecificHint() async {
        let runner = NolonCoreCLIRunner(
            service: EmptySkillLookupMockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "mcp", "search",
                "--install",
                "--dry-run",
            ],
            outputMode: .text
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("\"code\":\"invalid_arguments\""))
        #expect(result.stderr.contains("nolon mcp search <keyword> --install --dry-run"))
        #expect(result.stderr.contains("nolon mcp search <keyword> --install --yes --provider codex"))
        #expect(result.stderr.contains("nolon mcp search --query <text> --install --dry-run"))
        #expect(result.stderr.contains("nolon mcp search --query <text> --install --yes --provider codex"))
    }
    @Test("runner workflow search install validates empty query before remote call")
    func runnerWorkflowSearchInstallValidatesEmptyQueryBeforeRemoteCall() async {
        let runner = NolonCoreCLIRunner(
            service: RemoteCatalogUnavailableMockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "workflow", "search",
                "--install",
                "--dry-run",
            ],
            outputMode: .text
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("\"code\":\"invalid_arguments\""))
        #expect(result.stderr.contains("nolon workflow search <keyword> --install --dry-run"))
        #expect(result.stderr.contains("remote_catalog_unavailable") == false)
    }
    @Test("runner renders skills list text as compact list")
    func runnerRendersSkillsListTextAsCompactList() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "skills", "list",
                "--provider", "codex",
            ],
            outputMode: .text
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("[结论]"))
        #expect(result.stdout.contains("providers_scanned: 1"))
        #expect(result.stdout.contains("providers_matched: 1"))
        #expect(result.stdout.contains("健康度(已安装/总数):") == false)
        #expect(result.stdout.contains("状态(已安装/失效链接/损坏): 0/1/0 (0.0%/100.0%/0.0%)"))
        #expect(result.stdout.contains("行动建议: 需处理 1 项异常（高优先级）"))
        #expect(result.stdout.contains("摘要:") == false)
        #expect(result.stdout.contains("- codex/react-best-practices [失效链接]"))
        #expect(result.stdout.contains("异常提供方(1): codex"))
        #expect(result.stdout.contains("修复建议（可复制）:"))
        #expect(result.stdout.contains("[下一步（可复制执行）]"))
        #expect(result.stdout.contains("先设置前缀变量（与本次入口一致）") == false)
        #expect(result.stdout.contains("[下一步]") == false)
        #expect(result.stdout.contains("[立即执行（复制即用）]") == false)
        #expect(result.stdout.contains("查看失效链接详情"))
        #expect(result.stdout.contains("/Users/") == false)
        #expect(result.stdout.contains("nolon skills list --verbose"))
        #expect(result.stdout.contains("provider | skill | state | path") == false)
        #expect(result.stdout.contains("需处理异常: 1（失效链接 1，损坏 0）"))
        #expect(result.stdout.contains("nolon skills list --state orphaned"))
        #expect(result.stdout.contains("提示: 使用 `nolon skills list --verbose` 查看安装路径与来源。"))
        #expect(result.stdout.contains("快速筛坏链") == false)
        #expect(result.stdout.contains("快速筛失效链接") == false)
        #expect(result.stdout.contains("修复建议:") == false)
        #expect(result.stdout.contains("一键修复(all):") == false)
        #expect(result.stdout.contains("nolon skills list --show-fixes"))
    }
    @Test("runner hides installed items in default list mode")
    func runnerHidesInstalledItemsInDefaultListMode() async {
        let runner = NolonCoreCLIRunner(
            service: InstalledAndBrokenSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "skills", "list",
                "--provider", "codex",
            ],
            outputMode: .text
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("- codex/xcode [已安装]") == false)
        #expect(result.stdout.contains("- codex/find-skills [损坏]"))
        #expect(result.stdout.contains("修复建议（可复制）:"))
        #expect(result.stdout.contains("查看损坏详情"))
        #expect(result.stdout.contains("查看坏链详情") == false)
        #expect(result.stdout.contains("nolon skills list --state broken"))
        #expect(result.stdout.contains("nolon skills list --state orphaned") == false)
        #expect(result.stdout.contains("快速筛坏链") == false)
    }
    @Test("runner renders skills list verbose with path")
    func runnerRendersSkillsListVerboseWithPath() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "skills", "list",
                "--provider", "codex",
                "--verbose",
            ],
            outputMode: .text
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("- codex/react-best-practices [失效链接]\n  path:"))
        #expect(result.stdout.contains("/Users/linhey/.codex/skills/react-best-practices"))
    }
    @Test("runner skills list sees installed skill when provider root is symlink to global root")
    func runnerSkillsListSeesInstalledSkillUnderDirectLinkedProviderRoot() async throws {
        let root = try STFolder(sanbox: .temporary)
            .folder("nolon-cli-list-linked-root-\(UUID().uuidString)")
            .create()
        defer { try? root.delete() }

        let tempHome = root.folder("home")
        let nolonHome = root.folder("nolon-home")
        let globalSkills = nolonHome.folder("skills")
        _ = tempHome.createIfNotExists()
        _ = globalSkills.createIfNotExists()

        let globalSkill = globalSkills.folder("karpathy-guidelines")
        _ = globalSkill.createIfNotExists()
        try globalSkill.file("SKILL.md").overlay(
            with: """
            ---
            name: karpathy-guidelines
            description: test
            ---
            """
        )

        let codexHome = tempHome.folder(".codex")
        _ = codexHome.createIfNotExists()
        let providerLink = codexHome.subpath("skills")
        try providerLink.createSymbolicLink(to: STPath(globalSkills.url.path))

        let previousHome = getenv("HOME").map { String(cString: $0) }
        let previousNolonHome = getenv("NOLON_HOME").map { String(cString: $0) }
        setenv("HOME", tempHome.url.path, 1)
        setenv("NOLON_HOME", nolonHome.url.path, 1)
        defer {
            if let previousHome {
                setenv("HOME", previousHome, 1)
            } else {
                unsetenv("HOME")
            }
            if let previousNolonHome {
                setenv("NOLON_HOME", previousNolonHome, 1)
            } else {
                unsetenv("NOLON_HOME")
            }
        }

        let runner = NolonCoreCLIRunner(
            service: NolonLiveSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "skills", "list",
                "--provider", "codex",
                "--state", "installed",
                "--verbose",
            ],
            outputMode: .text
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("- codex/karpathy-guidelines"))
        #expect(result.stdout.contains(STFolder(providerLink.url).subpath("karpathy-guidelines").url.path))
        #expect(result.stdout.contains("skills_total: 1"))
    }
    @Test("runner skills verbose installed filter omits redundant installed tag and unknown origin")
    func runnerSkillsVerboseInstalledFilterOmitsRedundantInstalledTagAndUnknownOrigin() async {
        let runner = NolonCoreCLIRunner(
            service: InstalledAndBrokenSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "skills", "list",
                "--provider", "codex",
                "--state", "installed",
                "--verbose",
            ],
            outputMode: .text
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("- codex/xcode\n  path: /Users/linhey/.codex/skills/xcode"))
        #expect(result.stdout.contains("- codex/xcode [已安装]") == false)
        #expect(result.stdout.contains("origin=unknown") == false)
    }
    @Test("runner skills verbose mixed states are grouped into abnormal and installed sections")
    func runnerSkillsVerboseMixedStatesAreGroupedIntoSections() async {
        let runner = NolonCoreCLIRunner(
            service: InstalledAndBrokenSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "skills", "list",
                "--provider", "codex",
                "--verbose",
            ],
            outputMode: .text
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("[异常]"))
        #expect(result.stdout.contains("[已安装]"))
        #expect(result.stdout.contains("- codex/find-skills [损坏]\n  path: "))
        #expect(result.stdout.contains("- codex/xcode\n  path: "))
    }
    @Test("runner renders skills list with state filter")
    func runnerRendersSkillsListWithStateFilter() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "skills", "list",
                "--provider", "codex",
                "--state", "orphaned",
            ],
            outputMode: .text
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("筛选-状态: 失效链接"))
        #expect(result.stdout.contains("[异常]"))
        #expect(result.stdout.contains("- codex/react-best-practices [失效链接]"))
        #expect(result.stdout.contains("异常提供方(1): codex"))
        #expect(result.stdout.contains("修复建议（可复制）:"))
        #expect(result.stdout.contains("查看失效链接详情"))
        #expect(result.stdout.contains("修复建议:") == false)
        #expect(result.stdout.contains("nolon skills list --show-fixes"))
    }
    @Test("runner skills list unsupported provider includes recovery hint")
    func runnerSkillsListUnsupportedProviderIncludesRecoveryHint() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "skills", "list",
                "--provider", "not-exist",
            ],
            outputMode: .text
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("\"code\":\"invalid_arguments\""))
        #expect(result.stderr.contains("Unsupported --provider: not-exist"))
        #expect(result.stderr.contains("nolon provider list"))
    }
    @Test("runner skills show-fixes with installed filter prints explicit no-op hint")
    func runnerSkillsShowFixesWithInstalledFilterPrintsNoOpHint() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "skills", "list",
                "--provider", "codex",
                "--state", "installed",
                "--show-fixes",
            ],
            outputMode: .text
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("筛选-状态: 已安装"))
        #expect(result.stdout.contains("在 provider=codex 且 state=已安装 下，未发现匹配技能。"))
        #expect(result.stdout.contains("[下一步（可复制执行）]"))
        #expect(result.stdout.contains("当前筛选条件下无可修复项；请移除筛选后重试 --show-fixes。"))
        #expect(result.stdout.contains("复检命令: `nolon skills list --show-fixes`"))
        #expect(result.stdout.contains("可选复检:") == false)
        #expect(result.stdout.contains("健康度(已安装/总数):") == false)
        #expect(result.stdout.contains("立即执行（清理失效链接，") == false)
    }
    @Test("runner skills installed filter omits redundant installed tag in compact mode")
    func runnerSkillsInstalledFilterOmitsInstalledTagInCompactMode() async {
        let runner = NolonCoreCLIRunner(
            service: InstalledAndBrokenSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "skills", "list",
                "--provider", "codex",
                "--state", "installed",
                "--show-fixes",
            ],
            outputMode: .text
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("[已安装]"))
        #expect(result.stdout.contains("- codex/xcode"))
        #expect(result.stdout.contains("- codex/xcode [已安装]") == false)
        #expect(result.stdout.contains("修复动作：无。\n\n\n[已安装]") == false)
        #expect(result.stdout.contains("当前筛选条件下无可修复项；请移除筛选后重试 --show-fixes。"))
        #expect(result.stdout.contains("复检命令: `nolon skills list --show-fixes`"))
        #expect(result.stdout.contains("状态健康，无需修复；修复建议已启用但当前无可修复项。") == false)
    }
    @Test("runner renders skills list with show fixes")
    func runnerRendersSkillsListWithShowFixes() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "skills", "list",
                "--provider", "codex",
                "--show-fixes",
            ],
            outputMode: .text
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("[结论]"))
        #expect(result.stdout.contains("摘要: 异常=1 | 已安装=0/1 | 修复动作=需修复"))
        #expect(result.stdout.contains("summary: issues=") == false)
        #expect(result.stdout.contains("[详情]"))
        if let providerIdx = result.stdout.range(of: "筛选-提供方: codex")?.lowerBound,
           let scannedIdx = result.stdout.range(of: "providers_scanned: 1")?.lowerBound {
            #expect(providerIdx < scannedIdx)
        } else {
            #expect(Bool(false))
        }
        #expect(result.stdout.contains("健康度(已安装/总数):") == false)
        #expect(result.stdout.contains("[异常]"))
        #expect(result.stdout.contains("[下一步（按顺序执行）]"))
        #expect(result.stdout.contains("1. 清理失效链接（1项）"))
        #expect(result.stdout.contains("provider: codex (1)"))
        #expect(result.stdout.contains("3. 复检"))
        #expect(result.stdout.contains("[一键执行（可复制）]") == false)
        #expect(result.stdout.contains("```bash") == false)
        #expect(result.stdout.contains("nolon skills remove --skill-id react-best-practices --provider codex && nolon skills list --show-fixes") == false)
        #expect(result.stdout.contains("[下一步]") == false)
        #expect(result.stdout.contains("[立即执行（复制即用）]") == false)
        #expect(result.stdout.contains("`nolon skills list --show-fixes`"))
        #expect(result.stdout.contains("- 一键清理失效链接:") == false)
        #expect(result.stdout.contains("- `nolon skills remove --skill-id react-best-practices --provider codex`"))
        #expect(result.stdout.contains("明细查看:") == false)
        #expect(result.stdout.contains("提示: 使用 `nolon skills list --verbose` 查看安装路径。") == false)
        #expect(result.stdout.contains("修复建议（可复制）:") == false)
        #expect(result.stdout.contains("\norphaned(1):") == false)
        #expect(result.stdout.contains("一键清理(orphaned):") == false)
        #expect(result.stdout.contains("一键修复(all):") == false)
        #expect(result.stdout.contains("修复全部(all):") == false)
    }
    @Test("runner renders skills list with show fixes in two-step mode when orphaned and broken coexist")
    func runnerRendersSkillsListWithShowFixesInTwoStepMode() async {
        let runner = NolonCoreCLIRunner(
            service: OrphanedAndBrokenSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "skills", "list",
                "--provider", "codex",
                "--show-fixes",
            ],
            outputMode: .text
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("[下一步（按顺序执行）]"))
        #expect(result.stdout.contains("1. 清理失效链接（1项）"))
        #expect(result.stdout.contains("2. 修复损坏（1项：先 remove 再 add）"))
        #expect(result.stdout.contains("provider: codex (1)"))
        #expect(result.stdout.contains("3. 复检"))
        #expect(result.stdout.contains("[一键执行（可复制）]") == false)
        #expect(result.stdout.contains("```bash") == false)
        #expect(result.stdout.contains("nolon skills remove --skill-id agent-browser --provider codex &&") == false)
        #expect(result.stdout.contains("- 一键清理失效链接:") == false)
        #expect(result.stdout.contains("- 一键修复损坏:") == false)
        #expect(result.stdout.contains("执行顺序: 先执行「失效链接」，再执行「损坏」。") == false)
        #expect(result.stdout.contains("- 执行命令:") == false)
        #expect(result.stdout.contains("修复全部(all):") == false)
    }
    @Test("runner renders contextual empty message for filtered skills list")
    func runnerRendersContextualEmptyMessageForFilteredSkillsList() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "skills", "list",
                "--provider", "codex",
                "--state", "broken",
            ],
            outputMode: .text
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("筛选-提供方: codex"))
        #expect(result.stdout.contains("筛选-状态: 损坏"))
        #expect(result.stdout.contains("providers_matched: 1"))
        #expect(result.stdout.contains("在 provider=codex 且 state=损坏 下，未发现匹配技能。"))
    }
    @Test("runner renders skills add local-first success")
    func runnerRendersSkillsAddLocalFirstSuccess() async throws {
        let tempRoot = try STFolder(sanbox: .temporary).folder("nolon-cli-add-\(UUID().uuidString)").create()
        defer { try? tempRoot.delete() }

        let repoPath = tempRoot.folder("repos/repo-a")
        _ = repoPath.createIfNotExists()
        _ = repoPath.folder(".git").createIfNotExists()
        let localSkillPath = repoPath.folder("skills/xcode")
        _ = localSkillPath.createIfNotExists()
        try """
        ---
        name: xcode
        description: xcode
        ---
        """.write(to: localSkillPath.file("SKILL.md").url, atomically: true, encoding: .utf8)

        let nolonHome = tempRoot.folder("nolon-home")
        _ = nolonHome.createIfNotExists()
        setenv("NOLON_HOME", nolonHome.url.path, 1)
        defer { unsetenv("NOLON_HOME") }

        let service = MockSkillsRepositoryService(
            repositoryResources: NolonRepositoryResources(
                skillsDirectories: [NolonSkillsDirectoryCandidate(path: "skills", skillCount: 1, skillNames: ["xcode"])],
                workflows: [],
                mcps: []
            ),
            localRepositories: [
                NolonLocalRepositorySummary(
                    name: "repo-a",
                    path: repoPath.url.path,
                    skillsDirectoryCount: 1,
                    workflowCount: 0,
                    mcpCount: 0
                ),
            ]
        )
        let runner = NolonCoreCLIRunner(service: service, fileReader: { _ in "" })
        let result = await runner.execute(
            arguments: [
                "skills", "add", "xcode",
                "--provider", "codex",
                "--repositories-root", tempRoot.folder("repos").url.path,
                "--dry-run",
            ],
            outputMode: .json
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("\"command\":\"skills.add\""))
        #expect(result.stdout.contains("\"source\":\"local\""))
        #expect(result.stdout.contains("\"dry_run\":true"))
        #expect(result.stdout.contains("\"success_count\":1"))
    }
    @Test("runner skills add matches local skill by normalized display name")
    func runnerSkillsAddMatchesLocalSkillByNormalizedDisplayName() async throws {
        let tempRoot = try STFolder(sanbox: .temporary).folder("nolon-cli-add-display-name-\(UUID().uuidString)").create()
        defer { try? tempRoot.delete() }

        let repoPath = tempRoot.folder("repos/repo-a")
        _ = repoPath.createIfNotExists()
        _ = repoPath.folder(".git").createIfNotExists()
        let localSkillPath = repoPath.folder(".agent/skills/sectionui")
        _ = localSkillPath.createIfNotExists()
        try """
        ---
        name: SectionUI
        description: section ui
        ---
        """.write(to: localSkillPath.file("SKILL.md").url, atomically: true, encoding: .utf8)

        let nolonHome = tempRoot.folder("nolon-home")
        _ = nolonHome.createIfNotExists()
        setenv("NOLON_HOME", nolonHome.url.path, 1)
        defer { unsetenv("NOLON_HOME") }

        let service = MockSkillsRepositoryService(
            repositoryResources: NolonRepositoryResources(
                skillsDirectories: [
                    NolonSkillsDirectoryCandidate(
                        path: ".agent/skills",
                        skillCount: 1,
                        skillNames: ["SectionUI"]
                    ),
                ],
                workflows: [],
                mcps: []
            ),
            localRepositories: [
                NolonLocalRepositorySummary(
                    name: "repo-a",
                    path: repoPath.url.path,
                    skillsDirectoryCount: 1,
                    workflowCount: 0,
                    mcpCount: 0
                ),
            ]
        )
        let runner = NolonCoreCLIRunner(service: service, fileReader: { _ in "" })
        let result = await runner.execute(
            arguments: [
                "skills", "add", "sectionui",
                "--provider", "codex",
                "--repositories-root", tempRoot.folder("repos").url.path,
                "--dry-run",
            ],
            outputMode: .json
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("\"source\":\"local\""))
        #expect(result.stdout.contains("\"success_count\":1"))
        #expect(result.stdout.contains("\"slug\":\"sectionui\""))
    }
    @Test("runner skills add resolves single-skill repository alias")
    func runnerSkillsAddResolvesSingleSkillRepositoryAlias() async throws {
        let tempRoot = try STFolder(sanbox: .temporary).folder("nolon-cli-add-repo-alias-\(UUID().uuidString)").create()
        defer { try? tempRoot.delete() }

        let repoPath = tempRoot.folder("repos/repo-a")
        _ = repoPath.createIfNotExists()
        _ = repoPath.folder(".git").createIfNotExists()
        let localSkillPath = repoPath.folder(".agent/skills/sectionui")
        _ = localSkillPath.createIfNotExists()
        try """
        ---
        name: SectionUI
        description: section ui
        ---
        """.write(to: localSkillPath.file("SKILL.md").url, atomically: true, encoding: .utf8)

        let nolonHome = tempRoot.folder("nolon-home")
        _ = nolonHome.createIfNotExists()
        setenv("NOLON_HOME", nolonHome.url.path, 1)
        defer { unsetenv("NOLON_HOME") }

        let service = MockSkillsRepositoryService(
            repositoryResources: NolonRepositoryResources(
                skillsDirectories: [
                    NolonSkillsDirectoryCandidate(
                        path: ".agent/skills",
                        skillCount: 1,
                        skillNames: ["SectionUI"]
                    ),
                ],
                workflows: [],
                mcps: []
            ),
            localRepositories: [
                NolonLocalRepositorySummary(
                    name: "linhay@SectionKit",
                    path: repoPath.url.path,
                    skillsDirectoryCount: 1,
                    workflowCount: 0,
                    mcpCount: 0
                ),
            ]
        )
        let runner = NolonCoreCLIRunner(service: service, fileReader: { _ in "" })
        let result = await runner.execute(
            arguments: [
                "skills", "add", "sectionkit",
                "--provider", "codex",
                "--repositories-root", tempRoot.folder("repos").url.path,
                "--dry-run",
            ],
            outputMode: .json
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("\"source\":\"local\""))
        #expect(result.stdout.contains("\"success_count\":1"))
        #expect(result.stdout.contains("\"slug\":\"sectionkit\""))
    }
    @Test("runner renders skills add concise text output")
    func runnerRendersSkillsAddConciseTextOutput() async throws {
        let tempRoot = try STFolder(sanbox: .temporary).folder("nolon-cli-add-text-\(UUID().uuidString)").create()
        defer { try? tempRoot.delete() }

        let repoPath = tempRoot.folder("repos/repo-a")
        _ = repoPath.createIfNotExists()
        _ = repoPath.folder(".git").createIfNotExists()
        let localSkillPath = repoPath.folder("skills/xcode")
        _ = localSkillPath.createIfNotExists()
        try """
        ---
        name: xcode
        description: xcode
        ---
        """.write(to: localSkillPath.file("SKILL.md").url, atomically: true, encoding: .utf8)

        let nolonHome = tempRoot.folder("nolon-home")
        _ = nolonHome.createIfNotExists()
        setenv("NOLON_HOME", nolonHome.url.path, 1)
        defer { unsetenv("NOLON_HOME") }

        let service = MockSkillsRepositoryService(
            repositoryResources: NolonRepositoryResources(
                skillsDirectories: [NolonSkillsDirectoryCandidate(path: "skills", skillCount: 1, skillNames: ["xcode"])],
                workflows: [],
                mcps: []
            ),
            localRepositories: [
                NolonLocalRepositorySummary(
                    name: "repo-a",
                    path: repoPath.url.path,
                    skillsDirectoryCount: 1,
                    workflowCount: 0,
                    mcpCount: 0
                ),
            ]
        )
        let runner = NolonCoreCLIRunner(service: service, fileReader: { _ in "" })
        let result = await runner.execute(
            arguments: [
                "skills", "add", "xcode",
                "--provider", "codex",
                "--repositories-root", tempRoot.folder("repos").url.path,
                "--dry-run",
            ],
            outputMode: .text
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("[DRY-RUN] No changes applied"))
        #expect(result.stdout.contains("skill: xcode (local)"))
        #expect(result.stdout.contains("status: dry-run (no cache writes, no installation)"))
        #expect(result.stdout.contains("result: planned=1, invalid=0"))
        #expect(result.stdout.contains("targets:"))
        #expect(result.stdout.contains("[PLAN] codex ->"))
    }
}
