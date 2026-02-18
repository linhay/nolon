import Foundation
import STFilePath
import Testing
@testable import NolonCoreCLIKit

@Suite("NolonCoreCLIKit")
struct NolonCoreCLIKitTests {
    @Test("parse skills repo plan command")
    func parseSkillsRepoPlan() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "skills", "repo", "plan",
                "--source", "vercel/agent-skills/skills/react-best-practices",
                "--repositories-root", "/tmp/repos"
            ]
        )

        guard case let .skillsRepoPlan(source, root, pull, credential, accessToken) = command else {
            Issue.record("Expected .skillsRepoPlan")
            return
        }

        #expect(source == "vercel/agent-skills/skills/react-best-practices")
        #expect(root == "/tmp/repos")
        #expect(pull == .ffOnly)
        #expect(credential == .automatic)
        #expect(accessToken == nil)
    }

    @Test("missing required option returns invalid arguments")
    func missingRequiredOption() {
        do {
            _ = try NolonCoreCLIArgumentParser.parse(
                ["skills", "repo", "plan", "--repositories-root", "/tmp/repos"]
            )
            Issue.record("Expected missing option error")
        } catch let error as NolonCoreCLIError {
            #expect(error.code == "invalid_arguments")
            #expect(error.localizedDescription.contains("--source"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("runner renders success json for plan command")
    func runnerRendersSuccessJSON() async throws {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )

        let result = await runner.execute(
            arguments: [
                "skills", "repo", "plan",
                "--source", "vercel/agent-skills",
                "--repositories-root", "/tmp/repos"
            ]
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("\"ok\":true"))
        #expect(result.stdout.contains("\"command\":\"skills.repo.plan\""))
        #expect(result.stdout.contains("\"preflight\""))
        #expect(result.stdout.contains("\"credentialMode\":\"https_anonymous\""))
        #expect(result.stdout.contains("\"issues\""))
        #expect(result.stderr.isEmpty)
    }

    @Test("json contract snapshot for remote list success")
    func jsonContractSnapshotRemoteListSuccess() async throws {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )

        let result = await runner.execute(
            arguments: [
                "remote", "list",
                "--kind", "skill",
            ]
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)

        let expected = #"{"command":"remote.list","data":{"result":{"base_url":"https:\/\/clawdhub.com","items":[],"kind":"skill","limit":20}},"ok":true}"#
        #expect(try canonicalJSON(result.stdout) == expected)
    }

    @Test("json contract snapshot for missing required option")
    func jsonContractSnapshotMissingRequiredOption() async throws {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )

        let result = await runner.execute(
            arguments: [
                "remote", "list",
            ]
        )

        #expect(result.exitCode == 2)
        #expect(result.stdout.isEmpty)

        #expect(result.stderr.contains("\"code\":\"invalid_arguments\""))
        #expect(result.stderr.contains("--kind"))
    }

    @Test("runner renders sync output with repository resources")
    func runnerRendersSyncWithResources() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )

        let result = await runner.execute(
            arguments: [
                "skills", "repo", "sync",
                "--source", "vercel/agent-skills",
                "--repositories-root", "/tmp/repos"
            ]
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("\"command\":\"skills.repo.sync\""))
        #expect(result.stdout.contains("\"resources\""))
        #expect(result.stdout.contains("\"workflows\""))
        #expect(result.stdout.contains("\"mcps\""))
        #expect(result.stdout.contains("\"defaultBranch\":\"main\""))
        #expect(result.stdout.contains("\"credentialMode\":\"https_token\""))
    }

    @Test("parse skills repo sync with lifecycle strategies")
    func parseSkillsRepoSyncWithStrategies() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "skills", "repo", "sync",
                "--source", "vercel/agent-skills",
                "--repositories-root", "/tmp/repos",
                "--pull-strategy", "rebase",
                "--credential-strategy", "token-only",
            ]
        )

        guard case let .skillsRepoSync(_, _, _, pullStrategy, credentialStrategy) = command else {
            Issue.record("Expected .skillsRepoSync with strategies")
            return
        }

        #expect(pullStrategy == .rebase)
        #expect(credentialStrategy == .tokenOnly)
    }

    @Test("parse skills repo preflight command")
    func parseSkillsRepoPreflight() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "skills", "repo", "preflight",
                "--source", "vercel/agent-skills",
                "--pull-strategy", "ff-only",
                "--credential-strategy", "token-only",
            ]
        )

        guard case let .skillsRepoPreflight(source, pull, credential, accessToken) = command else {
            Issue.record("Expected .skillsRepoPreflight")
            return
        }
        #expect(source == "vercel/agent-skills")
        #expect(pull == .ffOnly)
        #expect(credential == .tokenOnly)
        #expect(accessToken == nil)
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

    @Test("parse workflow discover command")
    func parseWorkflowDiscover() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            ["workflow", "discover", "--path", "/tmp/repo", "--max-depth", "3"]
        )
        guard case let .workflowDiscover(path, maxDepth) = command else {
            Issue.record("Expected .workflowDiscover")
            return
        }
        #expect(path == "/tmp/repo")
        #expect(maxDepth == 3)
    }

    @Test("parse workflow install command")
    func parseWorkflowInstall() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "workflow", "install",
                "--file-path", "/tmp/source/review.md",
                "--target-path", "/tmp/provider/workflows",
                "--install-method", "copy",
            ]
        )
        guard case let .workflowInstall(filePath, resourceName, targetPath, installMethod) = command else {
            Issue.record("Expected .workflowInstall")
            return
        }
        #expect(filePath == "/tmp/source/review.md")
        #expect(resourceName == nil)
        #expect(targetPath == "/tmp/provider/workflows")
        #expect(installMethod == .copy)
    }

    @Test("parse mcp uninstall command")
    func parseMcpUninstall() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "mcp", "uninstall",
                "--resource-name", "cursor-mcp.json",
                "--target-path", "/tmp/provider/mcp",
            ]
        )
        guard case let .mcpUninstall(resourceName, targetPath) = command else {
            Issue.record("Expected .mcpUninstall")
            return
        }
        #expect(resourceName == "cursor-mcp.json")
        #expect(targetPath == "/tmp/provider/mcp")
    }

    @Test("parse remote list command")
    func parseRemoteList() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "remote", "list",
                "--kind", "skill",
                "--query", "react",
                "--limit", "15",
                "--base-url", "https://clawdhub.com",
            ]
        )
        guard case let .remoteList(kind, query, limit, baseURL) = command else {
            Issue.record("Expected .remoteList")
            return
        }
        #expect(kind == .skill)
        #expect(query == "react")
        #expect(limit == 15)
        #expect(baseURL == "https://clawdhub.com")
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
        #expect(baseURL == "https://clawdhub.com")
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
        #expect(baseURL == "https://clawdhub.com")
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
        #expect(baseURL == "https://clawdhub.com")
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
        #expect(baseURL == "https://clawdhub.com")
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
        #expect(baseURL == "https://clawdhub.com")
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

    @Test("runner renders workflow discover json")
    func runnerRendersWorkflowDiscover() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )

        let result = await runner.execute(
            arguments: ["workflow", "discover", "--path", "/tmp/repo"]
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("\"command\":\"workflow.discover\""))
        #expect(result.stdout.contains("\"workflows\""))
        #expect(result.stdout.contains("\"mcps\":[]"))
    }

    @Test("runner renders mcp discover json")
    func runnerRendersMcpDiscover() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )

        let result = await runner.execute(
            arguments: ["mcp", "discover", "--path", "/tmp/repo"]
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("\"command\":\"mcp.discover\""))
        #expect(result.stdout.contains("\"workflows\":[]"))
        #expect(result.stdout.contains("\"mcps\""))
    }

    @Test("runner renders workflow install result")
    func runnerRendersWorkflowInstallResult() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "workflow", "install",
                "--file-path", "/tmp/source/review.md",
                "--target-path", "/tmp/provider/workflows",
                "--install-method", "copy",
            ]
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("\"command\":\"workflow.install\""))
        #expect(result.stdout.contains("\"kind\":\"workflow\""))
        #expect(result.stdout.contains("\"install_method\":\"copy\""))
    }

    @Test("runner renders mcp uninstall result")
    func runnerRendersMcpUninstallResult() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "mcp", "uninstall",
                "--resource-name", "cursor-mcp.json",
                "--target-path", "/tmp/provider/mcp",
            ]
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("\"command\":\"mcp.uninstall\""))
        #expect(result.stdout.contains("\"removed\":true"))
        #expect(result.stdout.contains("\"kind\":\"mcp\""))
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

private struct SyncErrorMockSkillsRepositoryService: NolonSkillsRepositoryServing {
    func planGitImport(source: String, repositoriesRoot: STFolder) throws -> NolonGitImportPlan {
        NolonGitImportPlan(
            source: source,
            normalizedGitURL: "https://github.com/vercel/agent-skills.git",
            subpath: nil,
            providerHost: "github.com",
            owner: "vercel",
            repo: "agent-skills",
            localClonePath: repositoriesRoot.folder("github.com/vercel@agent-skills").url
        )
    }

    func preflightGitSync(
        source: String,
        accessToken: String?,
        pullStrategy: NolonGitPullStrategy,
        credentialStrategy: NolonGitCredentialStrategy
    ) throws -> NolonGitSyncPreflight {
        NolonGitSyncPreflight(
            isValidURL: true,
            normalizedGitURL: "https://github.com/vercel/agent-skills.git",
            pullStrategy: pullStrategy,
            credentialStrategy: credentialStrategy,
            credentialMode: "https_anonymous",
            requiresAccessToken: false,
            warnings: [],
            issues: []
        )
    }

    func syncGitRepository(
        plan: NolonGitImportPlan,
        accessToken: String?,
        pullStrategy: NolonGitPullStrategy,
        credentialStrategy: NolonGitCredentialStrategy
    ) async throws -> NolonGitSyncResult {
        throw NolonCoreCLIError.syncFailed(
            code: "access_token_required",
            message: "access token is required for token-only strategy",
            detail: NolonGitSyncErrorDetail(
                gitURL: "https://github.com/vercel/agent-skills.git",
                pullStrategy: .ffOnly,
                credentialStrategy: .tokenOnly,
                hasAccessToken: false
            )
        )
    }

    func discoverSkillsDirectories(at repositoryPath: STFolder, maxDepth: Int) -> [NolonSkillsDirectoryCandidate] { [] }
    func discoverRepositoryResources(at repositoryPath: STFolder, maxDepth: Int) -> NolonRepositoryResources {
        NolonRepositoryResources(skillsDirectories: [], workflows: [], mcps: [])
    }
    func parseSkillMetadata(content: String, directoryName: String?) -> NolonSkillStandardMetadata? { nil }

    func installSkill(
        skillPath: STPath,
        skillID: String?,
        providerPath: STFolder,
        installMethod: NolonSkillInstallMethod
    ) throws -> NolonSkillInstallResult {
        NolonSkillInstallResult(
            skillID: skillID ?? "react-best-practices",
            sourcePath: skillPath.url.path,
            targetPath: providerPath.subpath(skillID ?? "react-best-practices").url.path,
            installMethod: installMethod
        )
    }

    func uninstallSkill(skillID: String, providerPath: STFolder) throws -> NolonSkillUninstallResult {
        NolonSkillUninstallResult(
            skillID: skillID,
            targetPath: providerPath.subpath(skillID).url.path,
            removed: true
        )
    }

    func scanProviderSkills(providerPath: STFolder, globalSkillsPath: STFolder) throws -> NolonSkillMigrateScanResult {
        NolonSkillMigrateScanResult(
            providerPath: providerPath.url.path,
            globalSkillsPath: globalSkillsPath.url.path,
            states: [NolonProviderSkillState(skillID: "react-best-practices", path: providerPath.subpath("react-best-practices").url.path, state: .orphaned)]
        )
    }

    func migrateSkill(
        skillID: String,
        providerPath: STFolder,
        globalSkillsPath: STFolder,
        installMethod: NolonSkillInstallMethod
    ) throws -> NolonSkillInstallResult {
        NolonSkillInstallResult(
            skillID: skillID,
            sourcePath: globalSkillsPath.subpath(skillID).url.path,
            targetPath: providerPath.subpath(skillID).url.path,
            installMethod: installMethod
        )
    }

    func installResource(
        kind: NolonResourceKind,
        filePath: STPath,
        resourceName: String?,
        targetPath: STFolder,
        installMethod: NolonSkillInstallMethod
    ) throws -> NolonResourceInstallResult {
        let resolved = resourceName ?? filePath.url.lastPathComponent
        return NolonResourceInstallResult(
            kind: kind,
            resourceName: resolved,
            sourcePath: filePath.url.path,
            targetPath: targetPath.subpath(resolved).url.path,
            installMethod: installMethod
        )
    }

    func uninstallResource(
        kind: NolonResourceKind,
        resourceName: String,
        targetPath: STFolder
    ) throws -> NolonResourceUninstallResult {
        NolonResourceUninstallResult(
            kind: kind,
            resourceName: resourceName,
            targetPath: targetPath.subpath(resourceName).url.path,
            removed: true
        )
    }

    func listRemoteResources(
        kind: NolonRemoteCatalogKind,
        query: String?,
        limit: Int,
        baseURL: String
    ) async throws -> NolonRemoteListResult {
        NolonRemoteListResult(
            kind: kind,
            baseURL: baseURL,
            query: query,
            limit: limit,
            items: [
                NolonRemoteCatalogItem(
                    kind: kind,
                    slug: "react-best-practices",
                    displayName: "React Best Practices",
                    summary: "desc",
                    latestVersion: "1.0.0",
                    updatedAt: nil,
                    downloads: nil,
                    stars: nil,
                    installs: nil
                )
            ]
        )
    }

    func downloadRemoteResource(
        kind: NolonRemoteCatalogKind,
        slug: String,
        version: String?,
        baseURL: String
    ) async throws -> NolonRemoteDownloadResult {
        if kind == .skill {
            let folder = try makeMockRemoteSkillFolder(slug: slug)
            return NolonRemoteDownloadResult(
                kind: kind,
                slug: slug,
                version: version,
                baseURL: baseURL,
                filePath: folder.path
            )
        }
        return NolonRemoteDownloadResult(
            kind: kind,
            slug: slug,
            version: version,
            baseURL: baseURL,
            filePath: "/tmp/\(slug).bin"
        )
    }
}

private struct MockSkillsRepositoryService: NolonSkillsRepositoryServing {
    let repositoryResources: NolonRepositoryResources

    init(repositoryResources: NolonRepositoryResources? = nil) {
        self.repositoryResources = repositoryResources ?? NolonRepositoryResources(
            skillsDirectories: [NolonSkillsDirectoryCandidate(path: "skills", skillCount: 1, skillNames: ["agent-browser"])],
            workflows: [
                NolonResourceFile(path: "workflows/review.md", kind: "workflow"),
                NolonResourceFile(path: "prompts/review.md", kind: "workflow"),
            ],
            mcps: [NolonResourceFile(path: "mcp_settings.json", kind: "mcp")]
        )
    }

    func planGitImport(source: String, repositoriesRoot: STFolder) throws -> NolonGitImportPlan {
        NolonGitImportPlan(
            source: source,
            normalizedGitURL: "https://github.com/vercel/agent-skills.git",
            subpath: nil,
            providerHost: "github.com",
            owner: "vercel",
            repo: "agent-skills",
            localClonePath: repositoriesRoot.folder("github.com/vercel@agent-skills").url
        )
    }

    func preflightGitSync(
        source: String,
        accessToken: String?,
        pullStrategy: NolonGitPullStrategy,
        credentialStrategy: NolonGitCredentialStrategy
    ) throws -> NolonGitSyncPreflight {
        NolonGitSyncPreflight(
            isValidURL: true,
            normalizedGitURL: "https://github.com/vercel/agent-skills.git",
            pullStrategy: pullStrategy,
            credentialStrategy: credentialStrategy,
            credentialMode: "https_anonymous",
            requiresAccessToken: credentialStrategy == .tokenOnly && (accessToken?.isEmpty != false),
            warnings: credentialStrategy == .tokenOnly ? ["access token is required for token-only strategy"] : [],
            issues: credentialStrategy == .tokenOnly
                ? [NolonGitSyncPreflightIssue(
                    code: .accessTokenRequired,
                    severity: .error,
                    message: "access token is required for token-only strategy"
                )]
                : []
        )
    }

    func syncGitRepository(
        plan: NolonGitImportPlan,
        accessToken: String?,
        pullStrategy: NolonGitPullStrategy,
        credentialStrategy: NolonGitCredentialStrategy
    ) async throws -> NolonGitSyncResult {
        #expect(pullStrategy == .ffOnly || pullStrategy == .rebase)
        #expect(credentialStrategy == .automatic || credentialStrategy == .tokenOnly)
        return NolonGitSyncResult(
            mode: "cloned",
            updatedAt: Date(timeIntervalSince1970: 1),
            directories: [],
            defaultBranch: "main",
            credentialMode: "https_token"
        )
    }

    func discoverSkillsDirectories(at repositoryPath: STFolder, maxDepth: Int) -> [NolonSkillsDirectoryCandidate] {
        repositoryResources.skillsDirectories
    }

    func parseSkillMetadata(content: String, directoryName: String?) -> NolonSkillStandardMetadata? {
        NolonSkillStandardMetadata(
            name: directoryName ?? "agent-browser",
            description: "Browser automation skill.",
            license: nil,
            compatibility: nil,
            metadata: ["author": "openai"],
            argumentHint: nil,
            allowedTools: [],
            isValid: true,
            warnings: [],
            issues: []
        )
    }

    func discoverRepositoryResources(at repositoryPath: STFolder, maxDepth: Int) -> NolonRepositoryResources {
        repositoryResources
    }

    func installSkill(
        skillPath: STPath,
        skillID: String?,
        providerPath: STFolder,
        installMethod: NolonSkillInstallMethod
    ) throws -> NolonSkillInstallResult {
        NolonSkillInstallResult(
            skillID: skillID ?? skillPath.url.lastPathComponent,
            sourcePath: skillPath.url.path,
            targetPath: providerPath.subpath(skillID ?? skillPath.url.lastPathComponent).url.path,
            installMethod: installMethod
        )
    }

    func uninstallSkill(skillID: String, providerPath: STFolder) throws -> NolonSkillUninstallResult {
        NolonSkillUninstallResult(
            skillID: skillID,
            targetPath: providerPath.subpath(skillID).url.path,
            removed: true
        )
    }

    func scanProviderSkills(providerPath: STFolder, globalSkillsPath: STFolder) throws -> NolonSkillMigrateScanResult {
        NolonSkillMigrateScanResult(
            providerPath: providerPath.url.path,
            globalSkillsPath: globalSkillsPath.url.path,
            states: [NolonProviderSkillState(skillID: "react-best-practices", path: providerPath.subpath("react-best-practices").url.path, state: .orphaned)]
        )
    }

    func migrateSkill(
        skillID: String,
        providerPath: STFolder,
        globalSkillsPath: STFolder,
        installMethod: NolonSkillInstallMethod
    ) throws -> NolonSkillInstallResult {
        NolonSkillInstallResult(
            skillID: skillID,
            sourcePath: globalSkillsPath.subpath(skillID).url.path,
            targetPath: providerPath.subpath(skillID).url.path,
            installMethod: installMethod
        )
    }

    func installResource(
        kind: NolonResourceKind,
        filePath: STPath,
        resourceName: String?,
        targetPath: STFolder,
        installMethod: NolonSkillInstallMethod
    ) throws -> NolonResourceInstallResult {
        let resolved = resourceName ?? filePath.url.lastPathComponent
        return NolonResourceInstallResult(
            kind: kind,
            resourceName: resolved,
            sourcePath: filePath.url.path,
            targetPath: targetPath.subpath(resolved).url.path,
            installMethod: installMethod
        )
    }

    func uninstallResource(
        kind: NolonResourceKind,
        resourceName: String,
        targetPath: STFolder
    ) throws -> NolonResourceUninstallResult {
        NolonResourceUninstallResult(
            kind: kind,
            resourceName: resourceName,
            targetPath: targetPath.subpath(resourceName).url.path,
            removed: true
        )
    }

    func listRemoteResources(
        kind: NolonRemoteCatalogKind,
        query: String?,
        limit: Int,
        baseURL: String
    ) async throws -> NolonRemoteListResult {
        NolonRemoteListResult(kind: kind, baseURL: baseURL, query: query, limit: limit, items: [])
    }

    func downloadRemoteResource(
        kind: NolonRemoteCatalogKind,
        slug: String,
        version: String?,
        baseURL: String
    ) async throws -> NolonRemoteDownloadResult {
        if kind == .skill {
            let folder = try makeMockRemoteSkillFolder(slug: slug)
            return NolonRemoteDownloadResult(
                kind: kind,
                slug: slug,
                version: version,
                baseURL: baseURL,
                filePath: folder.path
            )
        }
        return NolonRemoteDownloadResult(kind: kind, slug: slug, version: version, baseURL: baseURL, filePath: "/tmp/\(slug).bin")
    }
}

private func makeMockRemoteSkillFolder(slug: String) throws -> URL {
    let root = try STFolder(sanbox: .temporary).folder("nolon-core-cli-tests-\(UUID().uuidString)").create()
    let folder = try root.create(folder: slug)
    try """
    ---
    name: \(slug)
    description: test
    ---
    # \(slug)
    """.write(to: folder.file("SKILL.md").url, atomically: true, encoding: .utf8)
    return folder.url
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
