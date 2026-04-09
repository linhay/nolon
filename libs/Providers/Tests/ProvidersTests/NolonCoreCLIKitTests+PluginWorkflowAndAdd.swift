import Foundation
import ArgumentParser
import STFilePath
import Testing
@testable import NolonCoreCLIKit
@testable import ProviderUsage

extension NolonCoreCLIKitTests {
    @Test("runner plugin start/stop is idempotent when runtime command is shell script")
    func runnerPluginStartStopIdempotentForShellScriptRuntime() async throws {
        let tempRoot = try STFolder(sanbox: .temporary).folder("nolon-cli-plugin-runtime-\(UUID().uuidString)").create()
        defer { try? tempRoot.delete() }

        let nolonHome = tempRoot.folder("nolon-home")
        _ = nolonHome.createIfNotExists()
        let binDir = tempRoot.folder("bin")
        _ = binDir.createIfNotExists()
        try """
        #!/bin/sh
        trap 'exit 0' TERM INT
        sleep 120 &
        wait $!
        """.write(to: binDir.file("xcodemcpkit").url, atomically: true, encoding: .utf8)
        try makeExecutableScript(at: binDir.file("xcode-mcp-server").url.path)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: binDir.file("xcodemcpkit").url.path)

        let backupHome = getenv("NOLON_HOME").map { String(cString: $0) }
        let backupPath = getenv("PATH").map { String(cString: $0) } ?? ""
        setenv("NOLON_HOME", nolonHome.url.path, 1)
        setenv("PATH", "\(binDir.url.path):\(backupPath)", 1)
        defer {
            if let backupHome {
                setenv("NOLON_HOME", backupHome, 1)
            } else {
                unsetenv("NOLON_HOME")
            }
            setenv("PATH", backupPath, 1)
        }

        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )

        _ = await runner.execute(arguments: ["plugin", "install", "--name", "xcodemcpkit"], outputMode: .text)
        let start1 = await runner.execute(arguments: ["plugin", "start", "--name", "xcodemcpkit"], outputMode: .text)
        let start2 = await runner.execute(arguments: ["plugin", "start", "--name", "xcodemcpkit"], outputMode: .text)
        let stop1 = await runner.execute(arguments: ["plugin", "stop", "--name", "xcodemcpkit"], outputMode: .text)
        usleep(200_000)
        let stop2 = await runner.execute(arguments: ["plugin", "stop", "--name", "xcodemcpkit"], outputMode: .text)

        #expect(start1.exitCode == 0)
        #expect(start2.exitCode == 0)
        #expect(start2.stdout.contains("already running"))
        #expect(stop1.exitCode == 0)
        #expect(stop2.exitCode == 0)
        #expect(stop2.stdout.contains("not running") || stop2.stdout.contains("sent SIGTERM"))
    }
    @Test("runner plugin start returns error when runtime exits immediately")
    func runnerPluginStartFailsWhenRuntimeExitsImmediately() async throws {
        let tempRoot = try STFolder(sanbox: .temporary).folder("nolon-cli-plugin-runtime-exit-\(UUID().uuidString)").create()
        defer { try? tempRoot.delete() }

        let nolonHome = tempRoot.folder("nolon-home")
        _ = nolonHome.createIfNotExists()
        let binDir = tempRoot.folder("bin")
        _ = binDir.createIfNotExists()
        try """
        #!/bin/sh
        exit 0
        """.write(to: binDir.file("xcodemcpkit").url, atomically: true, encoding: .utf8)
        try makeExecutableScript(at: binDir.file("xcode-mcp-server").url.path)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: binDir.file("xcodemcpkit").url.path)

        let backupHome = getenv("NOLON_HOME").map { String(cString: $0) }
        let backupPath = getenv("PATH").map { String(cString: $0) } ?? ""
        setenv("NOLON_HOME", nolonHome.url.path, 1)
        setenv("PATH", "\(binDir.url.path):\(backupPath)", 1)
        defer {
            if let backupHome {
                setenv("NOLON_HOME", backupHome, 1)
            } else {
                unsetenv("NOLON_HOME")
            }
            setenv("PATH", backupPath, 1)
        }

        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )

        let start = await runner.execute(arguments: ["plugin", "start", "--name", "xcodemcpkit"], outputMode: .json)

        #expect(start.exitCode == 2)
        #expect(start.stderr.contains("\"code\":\"plugin_runtime_start_failed\""))
    }
    @Test("parse workflow bind-skill command")
    func parseWorkflowBindSkill() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "workflow", "bind-skill",
                "--skill-id", "find-skills",
                "--target-path", "/tmp/workflows",
            ]
        )

        guard case let .workflowBindSkill(skillID, targetPath) = command else {
            Issue.record("Expected .workflowBindSkill")
            return
        }
        #expect(skillID == "find-skills")
        #expect(targetPath == "/tmp/workflows")
    }
    @Test("parse workflow bind-mcp command")
    func parseWorkflowBindMcp() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "workflow", "bind-mcp",
                "--mcp-name", "playwright",
                "--target-path", "/tmp/workflows",
            ]
        )

        guard case let .workflowBindMcp(mcpName, targetPath) = command else {
            Issue.record("Expected .workflowBindMcp")
            return
        }
        #expect(mcpName == "playwright")
        #expect(targetPath == "/tmp/workflows")
    }
    @Test("parse workflow unbind-skill command")
    func parseWorkflowUnbindSkill() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "workflow", "unbind-skill",
                "--skill-id", "find-skills",
                "--target-path", "/tmp/workflows",
            ]
        )

        guard case let .workflowUnbindSkill(skillID, targetPath) = command else {
            Issue.record("Expected .workflowUnbindSkill")
            return
        }
        #expect(skillID == "find-skills")
        #expect(targetPath == "/tmp/workflows")
    }
    @Test("parse skills add command")
    func parseSkillsAdd() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "skills", "add", "xcode",
                "--provider", "codex",
                "--version", "1.0.0",
                "--install-method", "copy",
            ]
        )
        guard case let .skillsAdd(slug, provider, version, baseURL, installMethod, repositoriesRoot, dryRun) = command else {
            Issue.record("Expected .skillsAdd")
            return
        }
        #expect(slug == "xcode")
        #expect(provider == "codex")
        #expect(version == "1.0.0")
        #expect(baseURL == "https://clawhub.ai")
        #expect(installMethod == .copy)
        #expect(!repositoriesRoot.isEmpty)
        #expect(dryRun == false)
    }
    @Test("parse skills add accepts provider-id alias")
    func parseSkillsAddProviderIDAlias() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            ["skills", "add", "xcode", "--provider-id", "codex"]
        )
        guard case let .skillsAdd(_, provider, _, _, _, _, _) = command else {
            Issue.record("Expected .skillsAdd")
            return
        }
        #expect(provider == "codex")
    }
    @Test("parse skills add supports dry-run")
    func parseSkillsAddDryRun() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            ["skills", "add", "xcode", "--dry-run"]
        )
        guard case let .skillsAdd(_, _, _, _, _, _, dryRun) = command else {
            Issue.record("Expected .skillsAdd")
            return
        }
        #expect(dryRun == true)
    }
    @Test("parse skills add rejects conflicting provider options")
    func parseSkillsAddRejectsConflictingProviderOptions() {
        do {
            _ = try NolonCoreCLIArgumentParser.parse(
                ["skills", "add", "xcode", "--provider", "codex", "--provider-id", "opencode"]
            )
            Issue.record("Expected invalid provider conflict")
        } catch let error as NolonCoreCLIError {
            #expect(error.code == "invalid_arguments")
            #expect((error.errorDescription ?? "").contains("--provider"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
    @Test("parse skills search rejects non-positive limit")
    func parseSkillsSearchRejectsNonPositiveLimit() {
        do {
            _ = try NolonCoreCLIArgumentParser.parse(
                ["skills", "search", "--limit", "0"]
            )
            Issue.record("Expected invalid limit error")
        } catch let error as NolonCoreCLIError {
            #expect(error.code == "invalid_arguments")
            let message = error.errorDescription ?? ""
            #expect(message.contains("greater than 0"))
            #expect(message.contains("received 0"))
            #expect(message.contains("Try --limit 10"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
    @Test("parse skills search rejects too-large limit")
    func parseSkillsSearchRejectsTooLargeLimit() {
        do {
            _ = try NolonCoreCLIArgumentParser.parse(
                ["skills", "search", "--limit", "201"]
            )
            Issue.record("Expected invalid limit error")
        } catch let error as NolonCoreCLIError {
            #expect(error.code == "invalid_arguments")
            #expect((error.errorDescription ?? "").contains("--limit"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
    @Test("parse skills repo list rejects non-positive max depth")
    func parseSkillsRepoListRejectsNonPositiveMaxDepth() {
        do {
            _ = try NolonCoreCLIArgumentParser.parse(
                [
                    "skills", "repo", "list",
                    "--repositories-root", "/tmp/repos",
                    "--max-depth", "0",
                ]
            )
            Issue.record("Expected invalid max-depth error")
        } catch let error as NolonCoreCLIError {
            #expect(error.code == "invalid_arguments")
            #expect((error.errorDescription ?? "").contains("--max-depth"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
    @Test("invalid pull strategy is rejected by parser")
    func parseRejectsInvalidPullStrategy() {
        do {
            _ = try NolonCoreCLIArgumentParser.parse(
                [
                    "skills", "repo", "preflight",
                    "--source", "vercel/agent-skills",
                    "--pull-strategy", "no-fast-forward",
                ]
            )
            Issue.record("Expected invalid pull strategy error")
        } catch let error as NolonCoreCLIError {
            #expect(error.code == "invalid_arguments")
            #expect(error.localizedDescription.contains("pull-strategy"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
    @Test("invalid credential strategy is rejected by parser")
    func parseRejectsInvalidCredentialStrategy() {
        do {
            _ = try NolonCoreCLIArgumentParser.parse(
                [
                    "skills", "repo", "preflight",
                    "--source", "vercel/agent-skills",
                    "--credential-strategy", "basic-auth",
                ]
            )
            Issue.record("Expected invalid credential strategy error")
        } catch let error as NolonCoreCLIError {
            #expect(error.code == "invalid_arguments")
            #expect(error.localizedDescription.contains("credential-strategy"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
    @Test("runner renders parse result from SKILL file")
    func runnerRendersParseResult() async throws {
        let root = STFolder("/tmp").folder("nolon-cli-\(UUID().uuidString)")
        _ = root.createIfNotExists()
        defer { try? root.delete() }

        let skillFile = root.file("SKILL.md")
        try Data(
            """
            ---
            name: agent-browser
            description: Browser automation skill.
            metadata:
              author: openai
            ---

            # Agent Browser
            """.utf8
        ).write(to: skillFile.url)

        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { path in
                try String(contentsOfFile: path, encoding: .utf8)
            }
        )

        let result = await runner.execute(
            arguments: [
                "skills", "parse",
                "--file", skillFile.url.path,
                "--directory-name", "agent-browser"
            ]
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("\"command\":\"skills.parse\""))
        #expect(result.stdout.contains("\"name\":\"agent-browser\""))
        #expect(result.stdout.contains("\"description\":\"Browser automation skill.\""))
        #expect(result.stdout.contains("\"is_valid\":true"))
        #expect(result.stdout.contains("\"issues\":[]"))
    }
    @Test("runner renders preflight result")
    func runnerRendersPreflight() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )

        let result = await runner.execute(
            arguments: [
                "skills", "repo", "preflight",
                "--source", "vercel/agent-skills",
                "--credential-strategy", "token-only",
            ]
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("\"command\":\"skills.repo.preflight\""))
        #expect(result.stdout.contains("\"requiresAccessToken\":true"))
        #expect(result.stdout.contains("\"code\":\"access_token_required\""))
    }
    @Test("runner renders skills repo list result")
    func runnerRendersSkillsRepoListResult() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "skills", "repo", "list",
                "--repositories-root", "/tmp/repos",
                "--max-depth", "6",
            ]
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("\"command\":\"skills.repo.list\""))
        #expect(result.stdout.contains("\"repositories_root\""))
        #expect(result.stdout.contains("\"skills_directory_count\":1"))
    }
    @Test("runner renders skills repo list text table")
    func runnerRendersSkillsRepoListTextTable() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "skills", "repo", "list",
                "--repositories-root", "/tmp/repos",
                "--verbose",
            ],
            outputMode: .text
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("repositories_root: /tmp/repos"))
        #expect(result.stdout.contains("repo"))
        #expect(result.stdout.contains("path"))
        #expect(result.stdout.contains("vercel@agent-skills"))
    }
    @Test("runner renders skills search result")
    func runnerRendersSkillsSearchResult() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "skills", "search",
                "--query", "react",
                "--limit", "10",
            ]
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("\"command\":\"skills.search\""))
        #expect(result.stdout.contains("\"kind\":\"skill\""))
        #expect(result.stdout.contains("\"query\":\"react\""))
    }
    @Test("runner renders skills search text empty result")
    func runnerRendersSkillsSearchTextEmptyResult() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "skills", "search",
                "--query", "react",
                "--limit", "10",
            ],
            outputMode: .text
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("base_url:") == false)
        #expect(result.stdout.contains("query:") == false)
        #expect(result.stdout.contains("未找到匹配 skill"))
        #expect(result.stdout.contains("提示:"))
        #expect(result.stdout.contains("nolon skills sync --source <owner/repo>"))
    }
    @Test("runner renders skills search text list")
    func runnerRendersSkillsSearchTextList() async {
        let runner = NolonCoreCLIRunner(
            service: RemoteFallbackMockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "skills", "search",
                "--query", "xcode",
                "--limit", "10",
            ],
            outputMode: .text
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("精确命中: xcode (query: xcode), candidates: 1"))
        #expect(result.stdout.contains("source: remote-api") == false)
        #expect(result.stdout.contains("安装:"))
        #expect(result.stdout.contains("- nolon skills add xcode --provider codex --dry-run"))
        #expect(result.stdout.contains("--install --pick") == false)
        #expect(result.stdout.contains("全部 providers:") == false)
        #expect(result.stdout.contains("[1] xcode"))
        #expect(result.stdout.contains("version: 1.0.0"))
        #expect(result.stdout.contains("updated: 1970-01-01"))
        #expect(result.stdout.contains("summary: Xcode skill"))
        #expect(result.stdout.contains("updated: 1970-01-01\n\n  summary:") == false)
        #expect(result.stdout.contains("install: nolon skills add xcode --provider codex --dry-run") == false)
        #expect(result.stdout.contains("install_all_providers: nolon skills add xcode --dry-run [可能批量写入]") == false)
        #expect(result.stdout.contains("name:") == false)
        #expect(result.stdout.contains("slug | name | version | updated") == false)
        #expect(result.stdout.contains("---") == false)
        #expect(result.stdout.contains("下一步:") == false)
        #expect(result.stdout.contains("提示: 用 `--install --pick <序号>` 或直接 slug 安装。") == false)
    }
    @Test("runner compacts and truncates long summary in skills search text list")
    func runnerCompactsAndTruncatesLongSummaryInSkillsSearchTextList() async {
        let runner = NolonCoreCLIRunner(
            service: LongSummaryRemoteSearchMockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "skills", "search",
                "--query", "xcode",
                "--limit", "10",
            ],
            outputMode: .text
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("summary: Xcode long summary line one line two"))
        #expect(result.stdout.contains("...\n\n[") == false)
        #expect(result.stdout.contains("安装:"))
        #expect(result.stdout.contains("\n\n  summary:") == false)
    }
    @Test("runner prefers exact slug display in skills search text list")
    func runnerPrefersExactSlugDisplayInSkillsSearchTextList() async {
        let runner = NolonCoreCLIRunner(
            service: MultiMatchRemoteSearchMockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "skills", "search",
                "--query", "xcode",
                "--limit", "20",
            ],
            outputMode: .text
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("精确命中: xcode (query: xcode), candidates: 2"))
        #expect(result.stdout.contains("检测到精确 slug 命中") == false)
        #expect(result.stdout.contains("--install --pick") == false)
        #expect(result.stdout.contains("- nolon skills add xcode --provider codex --dry-run"))
        #expect(result.stdout.contains("[1] xcode"))
        #expect(result.stdout.contains("[2] xcodebuildmcp") == false)
        #expect(result.stdout.contains("其他候选(1): xcodebuildmcp"))
    }
    @Test("runner omits summary in skills search text list when result is large")
    func runnerOmitsSummaryInSkillsSearchTextListWhenResultIsLarge() async {
        let runner = NolonCoreCLIRunner(
            service: ManyMatchRemoteSearchMockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "skills", "search",
                "--query", "gitlab-cli-skills",
                "--limit", "20",
            ],
            outputMode: .text
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("匹配结果: 20 (query: gitlab-cli-skills)"))
        #expect(result.stdout.contains("提示: 已省略 summary（将 `--limit` 设为 8 或更小可查看摘要）；仅展示前 10 条"))
        #expect(result.stdout.contains("- nolon skills search gitlab-cli-skills --install --pick <序号> --provider codex --dry-run"))
        #expect(result.stdout.contains("summary:") == false)
        #expect(result.stdout.contains("[1] skill-1"))
        #expect(result.stdout.contains("[2] skill-2"))
        #expect(result.stdout.contains("[1] skill-1\n  version: 1.0.0\n  updated: 1970-01-01\n\n[2] skill-2"))
    }
    @Test("runner truncates large skills search text list to top 10")
    func runnerTruncatesLargeSkillsSearchTextListToTopTen() async {
        let runner = NolonCoreCLIRunner(
            service: ManyMatchRemoteSearchMockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "skills", "search",
                "--query", "gitlab-cli-skills",
                "--limit", "20",
            ],
            outputMode: .text
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("[10] skill-10"))
        #expect(result.stdout.contains("[11] skill-11") == false)
        #expect(result.stdout.contains("仅展示前 10 条"))
    }
    @Test("runner large skills search hint does not suggest same limit value")
    func runnerLargeSkillsSearchHintDoesNotSuggestSameLimitValue() async {
        let runner = NolonCoreCLIRunner(
            service: ManyMatchRemoteSearchMockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "skills", "search",
                "--query", "gitlab-cli-skills",
                "--limit", "20",
            ],
            outputMode: .text
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("`--limit 20` 查看更多") == false)
        #expect(result.stdout.contains("可增大 `--limit` 查看更多"))
    }
    @Test("runner annotates future updated date in skills search text list")
    func runnerAnnotatesFutureUpdatedDateInSkillsSearchTextList() async {
        let runner = NolonCoreCLIRunner(
            service: FutureDateRemoteSearchMockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "skills", "search",
                "--query", "xcode",
                "--limit", "10",
            ],
            outputMode: .text
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("updated: 2100-01-"))
        #expect(result.stdout.contains("(future +"))
    }
    @Test("runner executes skills search install dry-run for unique match")
    func runnerExecutesSkillsSearchInstallDryRunForUniqueMatch() async throws {
        let tempRoot = try STFolder(sanbox: .temporary).folder("nolon-cli-search-install-\(UUID().uuidString)").create()
        defer { try? tempRoot.delete() }

        let nolonHome = tempRoot.folder("nolon-home")
        _ = nolonHome.createIfNotExists()
        setenv("NOLON_HOME", nolonHome.url.path, 1)
        defer { unsetenv("NOLON_HOME") }

        let runner = NolonCoreCLIRunner(
            service: RemoteFallbackMockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "skills", "search", "xcode",
                "--install",
                "--provider", "codex",
                "--dry-run",
            ],
            outputMode: .text
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("skill: xcode (remote)"))
        #expect(result.stdout.contains("status: dry-run (no cache writes, no installation)"))
        #expect(result.stdout.contains("[PLAN] codex"))
    }
    @Test("runner search install prefers exact slug when multiple matches")
    func runnerSearchInstallPrefersExactSlugWhenMultipleMatches() async throws {
        let tempRoot = try STFolder(sanbox: .temporary).folder("nolon-cli-search-install-exact-\(UUID().uuidString)").create()
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
                "--provider", "codex",
                "--dry-run",
            ],
            outputMode: .text
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("skill: xcode (remote)"))
        #expect(result.stdout.contains("[PLAN] codex"))
    }
    @Test("runner search install keeps ambiguity error when no exact slug")
    func runnerSearchInstallKeepsAmbiguityErrorWhenNoExactSlug() async {
        let runner = NolonCoreCLIRunner(
            service: MultiMatchRemoteSearchMockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "skills", "search", "xco",
                "--install",
                "--provider", "codex",
                "--dry-run",
            ],
            outputMode: .text
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("\"code\":\"invalid_arguments\""))
        #expect(result.stderr.contains("--install requires exactly one match"))
        #expect(result.stderr.contains("matches(2): [1] xcode; [2] xcodebuildmcp"))
        #expect(result.stderr.contains("Next: nolon skills search xcode --install --provider codex --dry-run"))
    }
    @Test("runner search install supports pick disambiguation")
    func runnerSearchInstallSupportsPickDisambiguation() async throws {
        let tempRoot = try STFolder(sanbox: .temporary).folder("nolon-cli-search-install-pick-\(UUID().uuidString)").create()
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
                "skills", "search", "xco",
                "--install",
                "--pick", "2",
                "--provider", "codex",
                "--dry-run",
            ],
            outputMode: .text
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("skill: xcodebuildmcp (remote)"))
        #expect(result.stdout.contains("[PLAN] codex"))
    }
    @Test("runner search install out-of-range pick returns actionable hint")
    func runnerSearchInstallOutOfRangePickReturnsActionableHint() async {
        let runner = NolonCoreCLIRunner(
            service: MultiMatchRemoteSearchMockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "skills", "search", "xco",
                "--install",
                "--pick", "99",
                "--provider", "codex",
                "--dry-run",
            ],
            outputMode: .text
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("--pick is out of range"))
        #expect(result.stderr.contains("available range: 1...2"))
        #expect(result.stderr.contains("Review candidates: nolon skills search xco --provider codex"))
        #expect(result.stderr.contains("Then retry: nolon skills search xco --install --pick <1-2> --provider codex --dry-run"))
    }
}
