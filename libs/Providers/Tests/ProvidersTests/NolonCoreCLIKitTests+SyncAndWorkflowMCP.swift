import Foundation
import ArgumentParser
import STFilePath
import Testing
@testable import NolonCoreCLIKit
@testable import ProviderUsage

extension NolonCoreCLIKitTests {
    @Test("runner skills add falls back to remote when local slug is absent")
    func runnerSkillsAddFallsBackToRemoteWhenLocalAbsent() async throws {
        let tempRoot = try STFolder(sanbox: .temporary).folder("nolon-cli-add-remote-\(UUID().uuidString)").create()
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
                "skills", "add", "xcode",
                "--provider", "codex",
                "--repositories-root", tempRoot.folder("repos").url.path,
                "--dry-run",
            ],
            outputMode: .json
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("\"source\":\"remote\""))
        #expect(result.stdout.contains("\"dry_run\":true"))
        #expect(result.stdout.contains("\"success_count\":1"))
        #expect(result.stdout.contains("\"slug\":\"xcode\""))
    }
    @Test("runner skills add returns skill_not_found when local and remote are absent")
    func runnerSkillsAddReturnsSkillNotFoundWhenLocalAndRemoteAbsent() async throws {
        let tempRoot = try STFolder(sanbox: .temporary).folder("nolon-cli-add-miss-\(UUID().uuidString)").create()
        defer { try? tempRoot.delete() }

        let nolonHome = tempRoot.folder("nolon-home")
        _ = nolonHome.createIfNotExists()
        setenv("NOLON_HOME", nolonHome.url.path, 1)
        defer { unsetenv("NOLON_HOME") }

        let runner = NolonCoreCLIRunner(
            service: EmptySkillLookupMockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "skills", "add", "does-not-exist",
                "--provider", "codex",
                "--repositories-root", tempRoot.folder("repos").url.path,
            ],
            outputMode: .json
        )

        #expect(result.exitCode == 2)
        #expect(result.stdout.isEmpty)
        #expect(result.stderr.contains("\"code\":\"skill_not_found\""))
        #expect(result.stderr.contains("Skill not found by slug: does-not-exist"))
    }
    @Test("runner skills add dry-run does not install")
    func runnerSkillsAddDryRunDoesNotInstall() async throws {
        let tempRoot = try STFolder(sanbox: .temporary).folder("nolon-cli-add-dry-run-\(UUID().uuidString)").create()
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

        let service = DryRunInstallGuardMockSkillsRepositoryService(
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
        #expect(result.stdout.contains("status: dry-run (no cache writes, no installation)"))
        #expect(result.stdout.contains("warnings:\n- Dry run enabled: no cache writes and no provider installation performed.") == false)
        #expect(result.stdout.contains("result: planned=1, invalid=0"))
        #expect(result.stdout.contains("[PLAN] codex ->"))
    }
    @Test("skills add safety warning for multi-provider targets")
    func skillsAddSafetyWarningForMultiProviderTargets() {
        let targets = [
            NolonSkillsAddTargetResult(
                providerID: "codex",
                providerPath: "/tmp/codex",
                sourcePath: "/tmp/skill",
                installedPath: "/tmp/codex/skill",
                status: .planned,
                errorCode: nil,
                errorMessage: nil
            ),
            NolonSkillsAddTargetResult(
                providerID: "claude",
                providerPath: "/tmp/claude",
                sourcePath: "/tmp/skill",
                installedPath: "/tmp/claude/skill",
                status: .planned,
                errorCode: nil,
                errorMessage: nil
            ),
        ]

        let dryRunWarning = NolonCoreCLIRunner.makeMultiProviderSafetyWarning(targets: targets, dryRun: true)
        #expect(dryRunWarning != nil)
        #expect(dryRunWarning?.contains("未指定 --provider") == true)
        #expect(dryRunWarning?.contains("2 个 providers") == true)

        let executeWarning = NolonCoreCLIRunner.makeMultiProviderSafetyWarning(targets: targets, dryRun: false)
        #expect(executeWarning?.contains("[WARN]") == true)
        #expect(executeWarning?.contains("--dry-run") == true)

        let singleProviderWarning = NolonCoreCLIRunner.makeMultiProviderSafetyWarning(
            targets: [targets[0]],
            dryRun: true
        )
        #expect(singleProviderWarning == nil)

        let scope = NolonCoreCLIRunner.makeInstallScopeLabel(targets: targets)
        #expect(scope == "multi-provider (2: claude,codex)")
        let singleScope = NolonCoreCLIRunner.makeInstallScopeLabel(targets: [targets[0]])
        #expect(singleScope == nil)
    }
    @Test("runner renders structured sync error code")
    func runnerRendersStructuredSyncErrorCode() async {
        let runner = NolonCoreCLIRunner(
            service: SyncErrorMockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )

        let result = await runner.execute(
            arguments: [
                "skills", "repo", "sync",
                "--source", "vercel/agent-skills",
                "--repositories-root", "/tmp/repos",
            ]
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("\"code\":\"access_token_required\""))
        #expect(result.stderr.contains("\"detail\""))
        #expect(result.stderr.contains("\"credential_strategy\":\"token-only\""))
    }
    @Test("runner renders git pull failed in text mode with actionable hints")
    func runnerRendersGitPullFailedInTextModeWithActionableHints() async {
        let runner = NolonCoreCLIRunner(
            service: GitPullFastForwardFailedMockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )

        let result = await runner.execute(
            arguments: [
                "workflow", "sync",
                "--source", "linhay/STFilePath",
            ],
            outputMode: .text
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("Error [git_pull_failed]"))
        #expect(result.stderr.contains("Cannot fast-forward to multiple branches"))
        #expect(result.stderr.contains("nolon workflow sync --source linhay/STFilePath --pull-strategy rebase"))
        #expect(result.stderr.contains("nolon skills/workflow/mcp sync") == false)
        #expect(result.stderr.contains("<owner/repo>") == false)
        #expect(result.stderr.contains("git -C "))
        #expect(result.stderr.contains("github.com/linhay@STFilePath"))
        #expect(result.stderr.contains("source_hint: linhay/STFilePath"))
        #expect(result.stderr.contains("repo_path_hint:"))
        #expect(result.stderr.contains("nolon skills repo list --verbose"))
    }
    @Test("runner maps git pull ref conflict to actionable guidance")
    func runnerMapsGitPullRefConflictToActionableGuidance() async {
        let runner = NolonCoreCLIRunner(
            service: GitRefConflictSyncMockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )

        let result = await runner.execute(
            arguments: [
                "workflow", "sync",
                "--source", "linhay/STFilePath",
            ],
            outputMode: .text
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("Error [git_ref_conflict]"))
        #expect(result.stderr.contains("nolon skills repo list --verbose"))
        #expect(result.stderr.contains("git -C "))
        #expect(result.stderr.contains("github.com/linhay@STFilePath"))
        #expect(result.stderr.contains("nolon workflow sync --source linhay/STFilePath"))
        #expect(result.stderr.contains("<owner/repo>") == false)
        #expect(result.stderr.contains("参考仓库: https://github.com/linhay/STFilePath.git"))
    }
    @Test("parse workflow list command")
    func parseWorkflowList() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            ["workflow", "list", "--provider", "codex", "--state", "broken", "--verbose"]
        )
        guard case let .workflowList(provider, includeEmpty, state, verbose, showFixes) = command else {
            Issue.record("Expected .workflowList")
            return
        }
        #expect(provider == "codex")
        #expect(includeEmpty == false)
        #expect(state == .broken)
        #expect(verbose == true)
        #expect(showFixes == false)
    }
    @Test("runner renders workflow sync text summary in text mode")
    func runnerRendersWorkflowSyncTextSummaryInTextMode() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "workflow", "sync",
                "--source", "vercel/agent-skills",
            ],
            outputMode: .text
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("workflow sync: cloned"))
        #expect(result.stdout.contains("workflows_discovered: 2"))
        #expect(result.stdout.contains("\"command\":\"workflow.sync\"") == false)
    }
    @Test("runner renders mcp sync text summary in text mode")
    func runnerRendersMcpSyncTextSummaryInTextMode() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "mcp", "sync",
                "--source", "vercel/agent-skills",
            ],
            outputMode: .text
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("mcp sync: cloned"))
        #expect(result.stdout.contains("mcps_discovered: 1"))
        #expect(result.stdout.contains("\"command\":\"mcp.sync\"") == false)
    }
    @Test("parse workflow add command")
    func parseWorkflowAdd() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "workflow", "add", "review",
                "--provider", "codex",
                "--install-method", "copy",
                "--dry-run",
            ]
        )
        guard case let .workflowAdd(slug, provider, version, _, installMethod, repositoriesRoot, dryRun) = command else {
            Issue.record("Expected .workflowAdd")
            return
        }
        #expect(slug == "review")
        #expect(provider == "codex")
        #expect(version == nil)
        #expect(installMethod == .copy)
        #expect(repositoriesRoot.hasSuffix("/repositories"))
        #expect(dryRun == true)
    }
    @Test("parse mcp remove command")
    func parseMcpRemove() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "mcp", "remove",
                "--resource-name", "cursor-mcp.json",
                "--provider", "codex",
            ]
        )
        guard case let .mcpRemove(resourceName, targetPath) = command else {
            Issue.record("Expected .mcpRemove")
            return
        }
        #expect(resourceName == "cursor-mcp.json")
        #expect(targetPath.contains(".codex"))
    }
    @Test("parse workflow remove rejects conflicting provider selectors")
    func parseWorkflowRemoveRejectsConflictingProviderSelectors() {
        do {
            _ = try NolonCoreCLIArgumentParser.parse(
                [
                    "workflow", "remove",
                    "--resource-name", "review.md",
                    "--provider", "codex",
                    "--provider-id", "opencode",
                ]
            )
            Issue.record("Expected invalid provider selector error")
        } catch let error as NolonCoreCLIError {
            #expect(error.code == "invalid_arguments")
            #expect((error.errorDescription ?? "").contains("Use either --provider or --provider-id"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
    @Test("parse mcp remove rejects conflicting provider selectors")
    func parseMcpRemoveRejectsConflictingProviderSelectors() {
        do {
            _ = try NolonCoreCLIArgumentParser.parse(
                [
                    "mcp", "remove",
                    "--resource-name", "cursor-mcp.json",
                    "--provider", "codex",
                    "--provider-id", "opencode",
                ]
            )
            Issue.record("Expected invalid provider selector error")
        } catch let error as NolonCoreCLIError {
            #expect(error.code == "invalid_arguments")
            #expect((error.errorDescription ?? "").contains("Use either --provider or --provider-id"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
    @Test("parse workflow remove rejects multiple target selectors")
    func parseWorkflowRemoveRejectsMultipleTargetSelectors() {
        do {
            _ = try NolonCoreCLIArgumentParser.parse(
                [
                    "workflow", "remove",
                    "--resource-name", "review.md",
                    "--target-path", "/tmp/workflows",
                    "--provider", "codex",
                ]
            )
            Issue.record("Expected invalid target selector error")
        } catch let error as NolonCoreCLIError {
            #expect(error.code == "invalid_arguments")
            #expect((error.errorDescription ?? "").contains("Use only one target selector: --target-path or --provider/--provider-id"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
    @Test("parse mcp remove rejects multiple target selectors")
    func parseMcpRemoveRejectsMultipleTargetSelectors() {
        do {
            _ = try NolonCoreCLIArgumentParser.parse(
                [
                    "mcp", "remove",
                    "--resource-name", "cursor-mcp.json",
                    "--target-path", "/tmp/mcp",
                    "--provider", "codex",
                ]
            )
            Issue.record("Expected invalid target selector error")
        } catch let error as NolonCoreCLIError {
            #expect(error.code == "invalid_arguments")
            #expect((error.errorDescription ?? "").contains("Use only one target selector: --target-path or --provider/--provider-id"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
    @Test("parse remote list command")
    func parseRemoteList() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "remote", "list",
                "--kind", "skill",
                "--query", "react",
                "--limit", "15",
                "--base-url", "https://clawhub.ai",
            ]
        )
        guard case let .remoteList(kind, query, limit, baseURL) = command else {
            Issue.record("Expected .remoteList")
            return
        }
        #expect(kind == .skill)
        #expect(query == "react")
        #expect(limit == 15)
        #expect(baseURL == "https://clawhub.ai")
    }
    @Test("parse remote download command")
    func parseRemoteDownload() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "remote", "download",
                "--kind", "workflow",
                "--slug", "daily-review",
                "--version", "1.2.0",
            ]
        )
        guard case let .remoteDownload(kind, slug, version, baseURL) = command else {
            Issue.record("Expected .remoteDownload")
            return
        }
        #expect(kind == .workflow)
        #expect(slug == "daily-review")
        #expect(version == "1.2.0")
        #expect(baseURL == "https://clawhub.ai")
    }
    @Test("parse remote sync command")
    func parseRemoteSync() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "remote", "sync",
                "--source", "vercel/agent-skills",
                "--repositories-root", "/tmp/repos",
                "--pull-strategy", "rebase",
                "--credential-strategy", "token-only",
                "--max-depth", "6",
            ]
        )
        guard case let .remoteSync(source, repositoriesRoot, accessToken, pullStrategy, credentialStrategy, maxDepth) = command else {
            Issue.record("Expected .remoteSync")
            return
        }
        #expect(source == "vercel/agent-skills")
        #expect(repositoriesRoot == "/tmp/repos")
        #expect(accessToken == nil)
        #expect(pullStrategy == .rebase)
        #expect(credentialStrategy == .tokenOnly)
        #expect(maxDepth == 6)
    }
    @Test("parse remote sync-install skill command")
    func parseRemoteSyncInstallSkill() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "remote", "sync-install",
                "--kind", "skill",
                "--source", "vercel/agent-skills",
                "--repositories-root", "/tmp/repos",
                "--path", "skills/react-best-practices",
                "--provider-id", "codex",
                "--install-method", "copy",
                "--skill-id", "react-best-practices",
            ]
        )
        guard case let .remoteSyncInstallSkill(source, repositoriesRoot, accessToken, pullStrategy, credentialStrategy, maxDepth, path, slug, strictSelector, providerPath, providerID, installMethod, skillID) = command else {
            Issue.record("Expected .remoteSyncInstallSkill")
            return
        }
        #expect(source == "vercel/agent-skills")
        #expect(repositoriesRoot == "/tmp/repos")
        #expect(accessToken == nil)
        #expect(pullStrategy == .ffOnly)
        #expect(credentialStrategy == .automatic)
        #expect(maxDepth == 5)
        #expect(path == "skills/react-best-practices")
        #expect(slug == nil)
        #expect(strictSelector == false)
        #expect(providerPath == nil)
        #expect(providerID == "codex")
        #expect(installMethod == .copy)
        #expect(skillID == "react-best-practices")
    }
    @Test("parse remote sync-install workflow command with slug selector")
    func parseRemoteSyncInstallWorkflowWithSlugSelector() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "remote", "sync-install",
                "--kind", "workflow",
                "--source", "vercel/agent-skills",
                "--repositories-root", "/tmp/repos",
                "--slug", "review",
                "--provider-id", "opencode",
            ]
        )
        guard case let .remoteSyncInstallResource(kind, source, repositoriesRoot, accessToken, pullStrategy, credentialStrategy, maxDepth, path, slug, strictSelector, targetPath, providerID, installMethod, resourceName) = command else {
            Issue.record("Expected .remoteSyncInstallResource")
            return
        }
        #expect(kind == .workflow)
        #expect(source == "vercel/agent-skills")
        #expect(repositoriesRoot == "/tmp/repos")
        #expect(accessToken == nil)
        #expect(pullStrategy == .ffOnly)
        #expect(credentialStrategy == .automatic)
        #expect(maxDepth == 5)
        #expect(path == nil)
        #expect(slug == "review")
        #expect(strictSelector == false)
        #expect(targetPath == nil)
        #expect(providerID == "opencode")
        #expect(installMethod == .symlink)
        #expect(resourceName == nil)
    }
    @Test("parse remote sync-install workflow command with strict selector")
    func parseRemoteSyncInstallWorkflowWithStrictSelector() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "remote", "sync-install",
                "--kind", "workflow",
                "--source", "vercel/agent-skills",
                "--repositories-root", "/tmp/repos",
                "--slug", "review",
                "--strict-selector", "true",
                "--provider-id", "opencode",
            ]
        )
        guard case let .remoteSyncInstallResource(kind, _, _, _, _, _, _, _, slug, strictSelector, _, _, _, _) = command else {
            Issue.record("Expected .remoteSyncInstallResource")
            return
        }
        #expect(kind == .workflow)
        #expect(slug == "review")
        #expect(strictSelector == true)
    }
    @Test("parse remote sync-install rejects missing selector")
    func parseRemoteSyncInstallRejectsMissingSelector() {
        #expect(throws: NolonCoreCLIError.invalidArguments("Missing required option: --path or --slug")) {
            _ = try NolonCoreCLIArgumentParser.parse(
                [
                    "remote", "sync-install",
                    "--kind", "skill",
                    "--source", "vercel/agent-skills",
                    "--repositories-root", "/tmp/repos",
                    "--provider-id", "codex",
                ]
            )
        }
    }
    @Test("parse remote sync-install rejects duplicate selector")
    func parseRemoteSyncInstallRejectsDuplicateSelector() {
        #expect(throws: NolonCoreCLIError.invalidArguments("Use only one selector: --path or --slug")) {
            _ = try NolonCoreCLIArgumentParser.parse(
                [
                    "remote", "sync-install",
                    "--kind", "skill",
                    "--source", "vercel/agent-skills",
                    "--repositories-root", "/tmp/repos",
                    "--path", "skills/agent-browser",
                    "--slug", "agent-browser",
                    "--provider-id", "codex",
                ]
            )
        }
    }
    @Test("parse remote sync-install skill rejects duplicate provider selector")
    func parseRemoteSyncInstallSkillRejectsDuplicateProviderSelector() {
        do {
            _ = try NolonCoreCLIArgumentParser.parse(
                [
                    "remote", "sync-install",
                    "--kind", "skill",
                    "--source", "vercel/agent-skills",
                    "--repositories-root", "/tmp/repos",
                    "--slug", "agent-browser",
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
    @Test("parse remote sync-install workflow rejects duplicate target selector")
    func parseRemoteSyncInstallWorkflowRejectsDuplicateTargetSelector() {
        do {
            _ = try NolonCoreCLIArgumentParser.parse(
                [
                    "remote", "sync-install",
                    "--kind", "workflow",
                    "--source", "vercel/agent-skills",
                    "--repositories-root", "/tmp/repos",
                    "--slug", "review",
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
    @Test("parse remote install skill command")
    func parseRemoteInstallSkill() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "remote", "install",
                "--kind", "skill",
                "--slug", "react-best-practices",
                "--provider-path", "/tmp/provider",
                "--install-method", "copy",
                "--skill-id", "react-skill",
            ]
        )
        guard case let .remoteInstallSkill(slug, version, baseURL, providerPath, providerID, installMethod, skillID) = command else {
            Issue.record("Expected .remoteInstallSkill")
            return
        }
        #expect(slug == "react-best-practices")
        #expect(version == nil)
        #expect(baseURL == "https://clawhub.ai")
        #expect(providerPath == "/tmp/provider")
        #expect(providerID == nil)
        #expect(installMethod == .copy)
        #expect(skillID == "react-skill")
    }
    @Test("parse remote install workflow command")
    func parseRemoteInstallWorkflow() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "remote", "install",
                "--kind", "workflow",
                "--slug", "daily-review",
                "--target-path", "/tmp/provider/workflows",
                "--resource-name", "daily.md",
            ]
        )
        guard case let .remoteInstallResource(kind, slug, version, baseURL, targetPath, providerID, installMethod, resourceName) = command else {
            Issue.record("Expected .remoteInstallResource")
            return
        }
        #expect(kind == .workflow)
        #expect(slug == "daily-review")
        #expect(version == nil)
        #expect(baseURL == "https://clawhub.ai")
        #expect(targetPath == "/tmp/provider/workflows")
        #expect(providerID == nil)
        #expect(installMethod == .symlink)
        #expect(resourceName == "daily.md")
    }
    @Test("parse remote install skill command with provider id")
    func parseRemoteInstallSkillWithProviderID() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "remote", "install",
                "--kind", "skill",
                "--slug", "react-best-practices",
                "--provider-id", "codex",
            ]
        )
        guard case let .remoteInstallSkill(slug, version, baseURL, providerPath, providerID, installMethod, skillID) = command else {
            Issue.record("Expected .remoteInstallSkill")
            return
        }
        #expect(slug == "react-best-practices")
        #expect(version == nil)
        #expect(baseURL == "https://clawhub.ai")
        #expect(providerPath == nil)
        #expect(providerID == "codex")
        #expect(installMethod == .symlink)
        #expect(skillID == nil)
    }
    @Test("parse remote install workflow command with provider id")
    func parseRemoteInstallWorkflowWithProviderID() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "remote", "install",
                "--kind", "workflow",
                "--slug", "daily-review",
                "--provider-id", "opencode",
            ]
        )
        guard case let .remoteInstallResource(kind, slug, version, baseURL, targetPath, providerID, installMethod, resourceName) = command else {
            Issue.record("Expected .remoteInstallResource")
            return
        }
        #expect(kind == .workflow)
        #expect(slug == "daily-review")
        #expect(version == nil)
        #expect(baseURL == "https://clawhub.ai")
        #expect(targetPath == nil)
        #expect(providerID == "opencode")
        #expect(installMethod == .symlink)
        #expect(resourceName == nil)
    }
    @Test("parse remote install skill rejects missing provider selector")
    func parseRemoteInstallSkillRejectsMissingProviderSelector() {
        #expect(throws: NolonCoreCLIError.invalidArguments("Missing required option: --provider-path or --provider-id")) {
            _ = try NolonCoreCLIArgumentParser.parse(
                [
                    "remote", "install",
                    "--kind", "skill",
                    "--slug", "react-best-practices",
                ]
            )
        }
    }
    @Test("parse remote install workflow rejects missing target selector")
    func parseRemoteInstallWorkflowRejectsMissingTargetSelector() {
        #expect(throws: NolonCoreCLIError.invalidArguments("Missing required option: --target-path or --provider-id")) {
            _ = try NolonCoreCLIArgumentParser.parse(
                [
                    "remote", "install",
                    "--kind", "workflow",
                    "--slug", "daily-review",
                ]
            )
        }
    }
}
