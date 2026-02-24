import Foundation
import ArgumentParser
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

    @Test("parse skills sync command defaults repositories root")
    func parseSkillsSyncDefaultsRepositoriesRoot() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "skills", "sync",
                "--source", "vercel/agent-skills",
            ]
        )

        guard case let .skillsRepoSync(source, repositoriesRoot, accessToken, pullStrategy, credentialStrategy) = command else {
            Issue.record("Expected .skillsRepoSync")
            return
        }
        #expect(source == "vercel/agent-skills")
        #expect(repositoriesRoot.hasSuffix("/repositories"))
        #expect(accessToken == nil)
        #expect(pullStrategy == .ffOnly)
        #expect(credentialStrategy == .automatic)
    }

    @Test("parse skills repo without action returns missing subcommand error")
    func parseSkillsRepoWithoutActionReturnsMissingSubcommandError() {
        do {
            _ = try NolonCoreCLIArgumentParser.parse(["skills", "repo"])
            Issue.record("Expected invalid_arguments")
        } catch let error as NolonCoreCLIError {
            #expect(error.code == "invalid_arguments")
            #expect((error.errorDescription ?? "").contains("Missing command. Expected: skills repo <action> ..."))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
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

    @Test("parse skills repo list command")
    func parseSkillsRepoList() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "skills", "repo", "list",
                "--repositories-root", "/tmp/repos",
                "--max-depth", "7",
                "--verbose",
            ]
        )

        guard case let .skillsRepoList(repositoriesRoot, maxDepth, verbose) = command else {
            Issue.record("Expected .skillsRepoList")
            return
        }
        #expect(repositoriesRoot == "/tmp/repos")
        #expect(maxDepth == 7)
        #expect(verbose == true)
    }

    @Test("parse skills list command")
    func parseSkillsList() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "skills", "list",
                "--provider", "codex",
                "--include-empty",
            ]
        )

        guard case let .skillsList(provider, includeEmpty, state, verbose, showFixes) = command else {
            Issue.record("Expected .skillsList")
            return
        }
        #expect(provider == "codex")
        #expect(includeEmpty == true)
        #expect(state == nil)
        #expect(verbose == false)
        #expect(showFixes == false)
    }

    @Test("parse skills list command without options")
    func parseSkillsListWithoutOptions() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "skills", "list",
            ]
        )

        guard case let .skillsList(provider, includeEmpty, state, verbose, showFixes) = command else {
            Issue.record("Expected .skillsList")
            return
        }
        #expect(provider == nil)
        #expect(includeEmpty == false)
        #expect(state == nil)
        #expect(verbose == false)
        #expect(showFixes == false)
    }

    @Test("parse skills list command with state filter")
    func parseSkillsListWithStateFilter() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "skills", "list",
                "--provider", "codex",
                "--state", "broken",
            ]
        )

        guard case let .skillsList(provider, includeEmpty, state, verbose, showFixes) = command else {
            Issue.record("Expected .skillsList")
            return
        }
        #expect(provider == "codex")
        #expect(includeEmpty == false)
        #expect(state == .broken)
        #expect(verbose == false)
        #expect(showFixes == false)
    }

    @Test("parse skills list command with verbose")
    func parseSkillsListWithVerbose() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "skills", "list",
                "--provider", "codex",
                "--verbose",
            ]
        )

        guard case let .skillsList(provider, includeEmpty, state, verbose, showFixes) = command else {
            Issue.record("Expected .skillsList")
            return
        }
        #expect(provider == "codex")
        #expect(includeEmpty == false)
        #expect(state == nil)
        #expect(verbose == true)
        #expect(showFixes == false)
    }

    @Test("parse skills list command with show fixes")
    func parseSkillsListWithShowFixes() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "skills", "list",
                "--provider", "codex",
                "--show-fixes",
            ]
        )

        guard case let .skillsList(provider, includeEmpty, state, verbose, showFixes) = command else {
            Issue.record("Expected .skillsList")
            return
        }
        #expect(provider == "codex")
        #expect(includeEmpty == false)
        #expect(state == nil)
        #expect(verbose == false)
        #expect(showFixes == true)
    }

    @Test("parse skills search command")
    func parseSkillsSearch() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "skills", "search",
                "--query", "agent",
                "--limit", "9",
                "--base-url", "https://clawdhub.com",
            ]
        )

        guard case let .skillsSearch(query, limit, baseURL, install, provider, installMethod, pick, dryRun, assumeYes) = command else {
            Issue.record("Expected .skillsSearch")
            return
        }
        #expect(query == "agent")
        #expect(limit == 9)
        #expect(baseURL == "https://clawdhub.com")
        #expect(install == false)
        #expect(provider == nil)
        #expect(installMethod == .symlink)
        #expect(pick == nil)
        #expect(dryRun == false)
        #expect(assumeYes == false)
    }

    @Test("parse skills search positional query command")
    func parseSkillsSearchPositionalQuery() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "skills", "search", "xcode",
                "--limit", "9",
            ]
        )

        guard case let .skillsSearch(query, limit, baseURL, install, provider, installMethod, pick, dryRun, assumeYes) = command else {
            Issue.record("Expected .skillsSearch")
            return
        }
        #expect(query == "xcode")
        #expect(limit == 9)
        #expect(baseURL == "https://clawdhub.com")
        #expect(install == false)
        #expect(provider == nil)
        #expect(installMethod == .symlink)
        #expect(pick == nil)
        #expect(dryRun == false)
        #expect(assumeYes == false)
    }

    @Test("parse skills search install command")
    func parseSkillsSearchInstall() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "skills", "search", "xcode",
                "--install",
                "--provider", "codex",
                "--install-method", "copy",
                "--dry-run",
            ]
        )

        guard case let .skillsSearch(query, limit, baseURL, install, provider, installMethod, pick, dryRun, assumeYes) = command else {
            Issue.record("Expected .skillsSearch")
            return
        }
        #expect(query == "xcode")
        #expect(limit == 20)
        #expect(baseURL == "https://clawdhub.com")
        #expect(install == true)
        #expect(provider == "codex")
        #expect(installMethod == .copy)
        #expect(pick == nil)
        #expect(dryRun == true)
        #expect(assumeYes == false)
    }

    @Test("parse skills search install command with yes")
    func parseSkillsSearchInstallWithYes() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            ["skills", "search", "xcodebuildmcp", "--install", "--yes", "--provider", "codex"]
        )

        guard case let .skillsSearch(query, _, _, install, _, _, pick, dryRun, assumeYes) = command else {
            Issue.record("Expected .skillsSearch")
            return
        }
        #expect(query == "xcodebuildmcp")
        #expect(install == true)
        #expect(pick == nil)
        #expect(dryRun == false)
        #expect(assumeYes == true)
    }

    @Test("parse skills search install command with pick")
    func parseSkillsSearchInstallWithPick() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            ["skills", "search", "xco", "--install", "--pick", "2", "--dry-run"]
        )

        guard case let .skillsSearch(query, _, _, install, _, _, pick, dryRun, assumeYes) = command else {
            Issue.record("Expected .skillsSearch")
            return
        }
        #expect(query == "xco")
        #expect(install == true)
        #expect(pick == 2)
        #expect(dryRun == true)
        #expect(assumeYes == false)
    }

    @Test("parse skills search rejects install options without install")
    func parseSkillsSearchRejectsInstallOptionsWithoutInstall() {
        do {
            _ = try NolonCoreCLIArgumentParser.parse(
                ["skills", "search", "xcode", "--provider", "codex"]
            )
            Issue.record("Expected invalid install options error")
        } catch let error as NolonCoreCLIError {
            #expect(error.code == "invalid_arguments")
            #expect((error.errorDescription ?? "").contains("--provider requires --install"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("parse skills search install requires yes or dry-run")
    func parseSkillsSearchInstallRequiresYesOrDryRun() {
        do {
            _ = try NolonCoreCLIArgumentParser.parse(
                ["skills", "search", "xcodebuildmcp", "--install", "--provider", "codex"]
            )
            Issue.record("Expected missing confirmation error")
        } catch let error as NolonCoreCLIError {
            #expect(error.code == "invalid_arguments")
            #expect((error.errorDescription ?? "").contains("--yes"))
            #expect((error.errorDescription ?? "").contains("--dry-run"))
            #expect((error.errorDescription ?? "").contains("nolon skills search <keyword> --install --dry-run"))
            #expect((error.errorDescription ?? "").contains("nolon skills search <keyword> --install --yes --provider codex"))
            #expect((error.errorDescription ?? "").contains("nolon skills search --query <text> --install --dry-run"))
            #expect((error.errorDescription ?? "").contains("nolon skills search --query <text> --install --yes --provider codex"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("parse skills search rejects duplicate positional and option query")
    func parseSkillsSearchRejectsDuplicateQueryInputs() {
        do {
            _ = try NolonCoreCLIArgumentParser.parse(
                ["skills", "search", "xcode", "--query", "swift"]
            )
            Issue.record("Expected invalid query input error")
        } catch let error as NolonCoreCLIError {
            #expect(error.code == "invalid_arguments")
            let message = error.errorDescription ?? ""
            #expect(message.contains("xcode"))
            #expect(message.contains("swift"))
            #expect(message.contains("nolon skills search xcode"))
            #expect(message.contains("nolon skills search --query swift"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("parse workflow search install requires yes or dry-run")
    func parseWorkflowSearchInstallRequiresYesOrDryRun() {
        do {
            _ = try NolonCoreCLIArgumentParser.parse(
                ["workflow", "search", "xcode", "--install", "--provider", "codex"]
            )
            Issue.record("Expected missing confirmation error")
        } catch let error as NolonCoreCLIError {
            #expect(error.code == "invalid_arguments")
            let message = error.errorDescription ?? ""
            #expect(message.contains("--yes"))
            #expect(message.contains("--dry-run"))
            #expect(message.contains("nolon workflow search <keyword> --install --dry-run"))
            #expect(message.contains("nolon workflow search <keyword> --install --yes --provider codex"))
            #expect(message.contains("nolon workflow search --query <text> --install --dry-run"))
            #expect(message.contains("nolon workflow search --query <text> --install --yes --provider codex"))
            #expect(message.contains("nolon skills search") == false)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("parse mcp search install requires yes or dry-run")
    func parseMcpSearchInstallRequiresYesOrDryRun() {
        do {
            _ = try NolonCoreCLIArgumentParser.parse(
                ["mcp", "search", "xcode", "--install", "--provider", "codex"]
            )
            Issue.record("Expected missing confirmation error")
        } catch let error as NolonCoreCLIError {
            #expect(error.code == "invalid_arguments")
            let message = error.errorDescription ?? ""
            #expect(message.contains("--yes"))
            #expect(message.contains("--dry-run"))
            #expect(message.contains("nolon mcp search <keyword> --install --dry-run"))
            #expect(message.contains("nolon mcp search <keyword> --install --yes --provider codex"))
            #expect(message.contains("nolon mcp search --query <text> --install --dry-run"))
            #expect(message.contains("nolon mcp search --query <text> --install --yes --provider codex"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("parse workflow search rejects duplicate positional and option query")
    func parseWorkflowSearchRejectsDuplicateQueryInputs() {
        do {
            _ = try NolonCoreCLIArgumentParser.parse(
                ["workflow", "search", "xcode", "--query", "swift"]
            )
            Issue.record("Expected invalid query input error")
        } catch let error as NolonCoreCLIError {
            #expect(error.code == "invalid_arguments")
            let message = error.errorDescription ?? ""
            #expect(message.contains("xcode"))
            #expect(message.contains("swift"))
            #expect(message.contains("nolon workflow search xcode"))
            #expect(message.contains("nolon workflow search --query swift"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("parse mcp search rejects duplicate positional and option query")
    func parseMcpSearchRejectsDuplicateQueryInputs() {
        do {
            _ = try NolonCoreCLIArgumentParser.parse(
                ["mcp", "search", "xcode", "--query", "swift"]
            )
            Issue.record("Expected invalid query input error")
        } catch let error as NolonCoreCLIError {
            #expect(error.code == "invalid_arguments")
            let message = error.errorDescription ?? ""
            #expect(message.contains("xcode"))
            #expect(message.contains("swift"))
            #expect(message.contains("nolon mcp search xcode"))
            #expect(message.contains("nolon mcp search --query swift"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
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
        #expect(baseURL == "https://clawdhub.com")
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
        #expect(result.stdout.contains("在 provider=codex 且 state=installed 下，未发现匹配技能。"))
        #expect(result.stdout.contains("可选复检:"))
        #expect(result.stdout.contains("- 直接运行: `nolon skills list --show-fixes`"))
        #expect(result.stdout.contains("- 源码模式: `swift run --package-path libs/Providers nolon skills list --show-fixes`"))
        #expect(result.stdout.contains("健康度(已安装/总数):") == false)
        #expect(result.stdout.contains("[下一步（可复制执行）]") == false)
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
        #expect(result.stdout.contains("summary: issues=1 | installed=0/1 | action=fix"))
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
        #expect(result.stdout.contains("在 provider=codex 且 state=broken 下，未发现匹配技能。"))
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

    @Test("mcp parser reads server names from toml sections")
    func parseMcpServerNamesFromToml() throws {
        let names = try NolonCoreCLIRunner.parseMCPServerNames(
            content: """
            [mcp_servers.filesystem]
            command = "npx"

            [mcp.servers.git]
            command = "uvx"
            """,
            fileExtension: "toml"
        )

        #expect(names == ["filesystem", "git"])
    }

    @Test("mcp parser ignores nested env subsection in toml")
    func parseMcpServerNamesIgnoresNestedEnvSubsectionInToml() throws {
        let names = try NolonCoreCLIRunner.parseMCPServerNames(
            content: """
            [mcp_servers.xcode-tools]
            command = "npx"

            [mcp_servers.xcode-tools.env]
            FOO = "bar"
            """,
            fileExtension: "toml"
        )

        #expect(names == ["xcode-tools"])
    }

    @Test("mcp list uses config file entries instead of scanning sibling files")
    func mcpListUsesConfigEntriesInsteadOfDirectoryScan() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("nolon-mcp-config-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let config = root.appendingPathComponent("config.toml")
        try """
        [mcp_servers.filesystem]
        command = "npx"
        """.write(to: config, atomically: true, encoding: .utf8)

        let sibling = root.appendingPathComponent("AGENTS.md")
        try "noise".write(to: sibling, atomically: true, encoding: .utf8)

        let items = NolonCoreCLIRunner.buildMCPListItemsForConfig(
            providerID: "codex",
            configPath: config.path
        )

        #expect(items.count == 1)
        #expect(items.first?.skillID == "filesystem")
        #expect(items.first?.state == .installed)
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
            #expect(result.stdout.contains("在 provider=codex 且 state=installed 下，未发现匹配工作流资源。"))
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
            #expect(result.stdout.contains("在 provider=codex 且 state=installed 下，未发现匹配工作流资源。"))
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
        #expect(result.stdout.contains("健康：11/11（100.0%），异常 0，修复动作：无。"))
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
        #expect(result.stdout.contains("健康：11/11（100.0%），异常 0，修复动作：无。"))
        #expect(result.stdout.contains("结论：全部健康") == false)
    }

    @Test("workflow help text contains scenarios")
    func workflowHelpTextContainsScenarios() {
        let help = NolonCoreCLIHelpResolver.resolvedHelpText(arguments: ["workflow"]) ?? ""
        #expect(help.contains("场景: 搜索工作流"))
        #expect(help.contains("nolon workflow search xcode"))
        #expect(help.contains("场景: 安装工作流"))
    }

    @Test("mcp help text contains scenarios")
    func mcpHelpTextContainsScenarios() {
        let help = NolonCoreCLIHelpResolver.resolvedHelpText(arguments: ["mcp"]) ?? ""
        #expect(help.contains("场景: 搜索 MCP"))
        #expect(help.contains("nolon mcp search xcode"))
        #expect(help.contains("场景: 修复异常"))
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

    @Test("mcp list help includes option descriptions")
    func mcpListHelpIncludesOptionDescriptions() {
        let help = NolonRootCommand.message(for: CleanExit.helpRequest(NolonMcpListCommand.self))
        #expect(help.contains("Target provider ID. Omit only if you intend"))
        #expect(help.contains("multi-provider distribution to all detected CLI"))
        #expect(help.contains("Alias of --provider. Omit only if you intend"))
        #expect(help.contains("Show full install path for each MCP item."))
        #expect(help.contains("Show repair commands for orphaned/broken items."))
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
        #expect(result.stdout.contains("在 provider=codex 且 state=orphaned 下，未发现匹配 MCP 资源。"))
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
        #expect(result.stdout.contains("- codex/xcode\n  path:"))
        #expect(result.stdout.contains("[配置路径]") == false)
        #expect(result.stdout.contains("config_path:") == false)
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
        #expect(result.stdout.contains("在 provider=codex 且 state=broken 下，未发现匹配工作流资源。"))
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
        #expect(result.stdout.contains("摘要:") == false)
        #expect(result.stdout.contains("先设置前缀变量（与本次入口一致）") == false)
        #expect(result.stdout.contains("[执行约束]") == false)
        #expect(result.stdout.contains("立即执行（清理失效链接，2 项，仅支持 --resource-name <xxx.md>）:") == false)
        #expect(result.stdout.contains("[下一步]") == false)
        #expect(result.stdout.contains("[立即执行（复制即用）]") == false)
        #expect(result.stdout.contains("首条:") == false)
        #expect(result.stdout.contains("其余") == false)

        if result.stdout.contains("异常 0") {
            #expect(result.stdout.contains("健康："))
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

private struct GitRefConflictSyncMockSkillsRepositoryService: NolonSkillsRepositoryServing {
    func planGitImport(source: String, repositoriesRoot: STFolder) throws -> NolonGitImportPlan {
        NolonGitImportPlan(
            source: source,
            normalizedGitURL: "https://github.com/linhay/STFilePath.git",
            subpath: nil,
            providerHost: "github.com",
            owner: "linhay",
            repo: "STFilePath",
            localClonePath: repositoriesRoot.folder("github.com/linhay@STFilePath").url
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
            normalizedGitURL: "https://github.com/linhay/STFilePath.git",
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
            code: "git_pull_failed",
            message: "Failed to update repository: error: cannot lock ref 'refs/remotes/origin/main': is at aaa but expected bbb\nFrom github.com:linhay/STFilePath\n ! bbb..aaa  main -> origin/main  (unable to update local ref)",
            detail: NolonGitSyncErrorDetail(
                gitURL: "https://github.com/linhay/STFilePath.git",
                pullStrategy: .ffOnly,
                credentialStrategy: .automatic,
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
        NolonSkillMigrateScanResult(providerPath: providerPath.url.path, globalSkillsPath: globalSkillsPath.url.path, states: [])
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
        let resolvedName = resourceName ?? filePath.url.lastPathComponent
        return NolonResourceInstallResult(
            kind: kind,
            resourceName: resolvedName,
            sourcePath: filePath.url.path,
            targetPath: targetPath.subpath(resolvedName).url.path,
            installMethod: installMethod
        )
    }

    func uninstallResource(
        kind: NolonResourceKind,
        resourceName: String,
        targetPath: STFolder
    ) throws -> NolonResourceUninstallResult {
        NolonResourceUninstallResult(kind: kind, resourceName: resourceName, targetPath: targetPath.subpath(resourceName).url.path, removed: true)
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
        NolonRemoteDownloadResult(
            kind: kind,
            slug: slug,
            version: version ?? "latest",
            baseURL: baseURL,
            filePath: "/tmp/\(slug).zip"
        )
    }

    func listLocalRepositories(repositoriesRoot: STFolder, maxDepth: Int) -> [NolonLocalRepositorySummary] { [] }
}

private struct GitPullFastForwardFailedMockSkillsRepositoryService: NolonSkillsRepositoryServing {
    private let base = MockSkillsRepositoryService(
        repositoryResources: NolonRepositoryResources(skillsDirectories: [], workflows: [], mcps: []),
        localRepositories: []
    )

    func planGitImport(source: String, repositoriesRoot: STFolder) throws -> NolonGitImportPlan {
        try base.planGitImport(source: source, repositoriesRoot: repositoriesRoot)
    }

    func preflightGitSync(
        source: String,
        accessToken: String?,
        pullStrategy: NolonGitPullStrategy,
        credentialStrategy: NolonGitCredentialStrategy
    ) throws -> NolonGitSyncPreflight {
        try base.preflightGitSync(
            source: source,
            accessToken: accessToken,
            pullStrategy: pullStrategy,
            credentialStrategy: credentialStrategy
        )
    }

    func syncGitRepository(
        plan: NolonGitImportPlan,
        accessToken: String?,
        pullStrategy: NolonGitPullStrategy,
        credentialStrategy: NolonGitCredentialStrategy
    ) async throws -> NolonGitSyncResult {
        throw NolonCoreCLIError.syncFailed(
            code: "git_pull_failed",
            message: "Failed to update repository: fatal: Cannot fast-forward to multiple branches.",
            detail: NolonGitSyncErrorDetail(
                gitURL: "https://github.com/linhay/STFilePath.git",
                pullStrategy: .ffOnly,
                credentialStrategy: .automatic,
                hasAccessToken: false
            )
        )
    }

    func discoverSkillsDirectories(at repositoryPath: STFolder, maxDepth: Int) -> [NolonSkillsDirectoryCandidate] {
        base.discoverSkillsDirectories(at: repositoryPath, maxDepth: maxDepth)
    }

    func listLocalRepositories(repositoriesRoot: STFolder, maxDepth: Int) -> [NolonLocalRepositorySummary] {
        base.listLocalRepositories(repositoriesRoot: repositoriesRoot, maxDepth: maxDepth)
    }

    func parseSkillMetadata(content: String, directoryName: String?) -> NolonSkillStandardMetadata? {
        base.parseSkillMetadata(content: content, directoryName: directoryName)
    }

    func discoverRepositoryResources(at repositoryPath: STFolder, maxDepth: Int) -> NolonRepositoryResources {
        base.discoverRepositoryResources(at: repositoryPath, maxDepth: maxDepth)
    }

    func installSkill(
        skillPath: STPath,
        skillID: String?,
        providerPath: STFolder,
        installMethod: NolonSkillInstallMethod
    ) throws -> NolonSkillInstallResult {
        try base.installSkill(skillPath: skillPath, skillID: skillID, providerPath: providerPath, installMethod: installMethod)
    }

    func uninstallSkill(skillID: String, providerPath: STFolder) throws -> NolonSkillUninstallResult {
        try base.uninstallSkill(skillID: skillID, providerPath: providerPath)
    }

    func scanProviderSkills(providerPath: STFolder, globalSkillsPath: STFolder) throws -> NolonSkillMigrateScanResult {
        try base.scanProviderSkills(providerPath: providerPath, globalSkillsPath: globalSkillsPath)
    }

    func migrateSkill(
        skillID: String,
        providerPath: STFolder,
        globalSkillsPath: STFolder,
        installMethod: NolonSkillInstallMethod
    ) throws -> NolonSkillInstallResult {
        try base.migrateSkill(
            skillID: skillID,
            providerPath: providerPath,
            globalSkillsPath: globalSkillsPath,
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
        try base.installResource(
            kind: kind,
            filePath: filePath,
            resourceName: resourceName,
            targetPath: targetPath,
            installMethod: installMethod
        )
    }

    func uninstallResource(
        kind: NolonResourceKind,
        resourceName: String,
        targetPath: STFolder
    ) throws -> NolonResourceUninstallResult {
        try base.uninstallResource(kind: kind, resourceName: resourceName, targetPath: targetPath)
    }

    func listRemoteResources(
        kind: NolonRemoteCatalogKind,
        query: String?,
        limit: Int,
        baseURL: String
    ) async throws -> NolonRemoteListResult {
        try await base.listRemoteResources(kind: kind, query: query, limit: limit, baseURL: baseURL)
    }

    func downloadRemoteResource(
        kind: NolonRemoteCatalogKind,
        slug: String,
        version: String?,
        baseURL: String
    ) async throws -> NolonRemoteDownloadResult {
        try await base.downloadRemoteResource(kind: kind, slug: slug, version: version, baseURL: baseURL)
    }
}

private struct MockSkillsRepositoryService: NolonSkillsRepositoryServing {
    let repositoryResources: NolonRepositoryResources
    let localRepositories: [NolonLocalRepositorySummary]

    init(
        repositoryResources: NolonRepositoryResources? = nil,
        localRepositories: [NolonLocalRepositorySummary]? = nil
    ) {
        self.repositoryResources = repositoryResources ?? NolonRepositoryResources(
            skillsDirectories: [NolonSkillsDirectoryCandidate(path: "skills", skillCount: 1, skillNames: ["agent-browser"])],
            workflows: [
                NolonResourceFile(path: "workflows/review.md", kind: "workflow"),
                NolonResourceFile(path: "prompts/review.md", kind: "workflow"),
            ],
            mcps: [NolonResourceFile(path: "mcp_settings.json", kind: "mcp")]
        )
        self.localRepositories = localRepositories ?? [
            NolonLocalRepositorySummary(
                name: "vercel@agent-skills",
                path: "/tmp/repos/github.com/vercel@agent-skills",
                skillsDirectoryCount: 1,
                workflowCount: 2,
                mcpCount: 1
            ),
        ]
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

    func listLocalRepositories(repositoriesRoot: STFolder, maxDepth: Int) -> [NolonLocalRepositorySummary] {
        localRepositories
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

private struct RemoteFallbackMockSkillsRepositoryService: NolonSkillsRepositoryServing {
    private let base = MockSkillsRepositoryService(
        repositoryResources: NolonRepositoryResources(skillsDirectories: [], workflows: [], mcps: []),
        localRepositories: []
    )

    func planGitImport(source: String, repositoriesRoot: STFolder) throws -> NolonGitImportPlan {
        try base.planGitImport(source: source, repositoriesRoot: repositoriesRoot)
    }
    func preflightGitSync(
        source: String,
        accessToken: String?,
        pullStrategy: NolonGitPullStrategy,
        credentialStrategy: NolonGitCredentialStrategy
    ) throws -> NolonGitSyncPreflight {
        try base.preflightGitSync(
            source: source,
            accessToken: accessToken,
            pullStrategy: pullStrategy,
            credentialStrategy: credentialStrategy
        )
    }
    func syncGitRepository(
        plan: NolonGitImportPlan,
        accessToken: String?,
        pullStrategy: NolonGitPullStrategy,
        credentialStrategy: NolonGitCredentialStrategy
    ) async throws -> NolonGitSyncResult {
        try await base.syncGitRepository(
            plan: plan,
            accessToken: accessToken,
            pullStrategy: pullStrategy,
            credentialStrategy: credentialStrategy
        )
    }
    func discoverSkillsDirectories(at repositoryPath: STFolder, maxDepth: Int) -> [NolonSkillsDirectoryCandidate] {
        base.discoverSkillsDirectories(at: repositoryPath, maxDepth: maxDepth)
    }
    func listLocalRepositories(repositoriesRoot: STFolder, maxDepth: Int) -> [NolonLocalRepositorySummary] {
        []
    }
    func parseSkillMetadata(content: String, directoryName: String?) -> NolonSkillStandardMetadata? {
        base.parseSkillMetadata(content: content, directoryName: directoryName)
    }
    func discoverRepositoryResources(at repositoryPath: STFolder, maxDepth: Int) -> NolonRepositoryResources {
        NolonRepositoryResources(skillsDirectories: [], workflows: [], mcps: [])
    }
    func installSkill(
        skillPath: STPath,
        skillID: String?,
        providerPath: STFolder,
        installMethod: NolonSkillInstallMethod
    ) throws -> NolonSkillInstallResult {
        try base.installSkill(
            skillPath: skillPath,
            skillID: skillID,
            providerPath: providerPath,
            installMethod: installMethod
        )
    }
    func uninstallSkill(skillID: String, providerPath: STFolder) throws -> NolonSkillUninstallResult {
        try base.uninstallSkill(skillID: skillID, providerPath: providerPath)
    }
    func scanProviderSkills(providerPath: STFolder, globalSkillsPath: STFolder) throws -> NolonSkillMigrateScanResult {
        try base.scanProviderSkills(providerPath: providerPath, globalSkillsPath: globalSkillsPath)
    }
    func migrateSkill(
        skillID: String,
        providerPath: STFolder,
        globalSkillsPath: STFolder,
        installMethod: NolonSkillInstallMethod
    ) throws -> NolonSkillInstallResult {
        try base.migrateSkill(
            skillID: skillID,
            providerPath: providerPath,
            globalSkillsPath: globalSkillsPath,
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
        try base.installResource(
            kind: kind,
            filePath: filePath,
            resourceName: resourceName,
            targetPath: targetPath,
            installMethod: installMethod
        )
    }
    func uninstallResource(
        kind: NolonResourceKind,
        resourceName: String,
        targetPath: STFolder
    ) throws -> NolonResourceUninstallResult {
        try base.uninstallResource(kind: kind, resourceName: resourceName, targetPath: targetPath)
    }
    func listRemoteResources(
        kind: NolonRemoteCatalogKind,
        query: String?,
        limit: Int,
        baseURL: String
    ) async throws -> NolonRemoteListResult {
        let item = NolonRemoteCatalogItem(
            kind: .skill,
            slug: "xcode",
            displayName: "Xcode",
            summary: "Xcode skill",
            latestVersion: "1.0.0",
            updatedAt: Date(timeIntervalSince1970: 0),
            downloads: nil,
            stars: nil,
            installs: nil
        )
        return NolonRemoteListResult(kind: kind, baseURL: baseURL, query: query, limit: limit, items: [item])
    }
    func downloadRemoteResource(
        kind: NolonRemoteCatalogKind,
        slug: String,
        version: String?,
        baseURL: String
    ) async throws -> NolonRemoteDownloadResult {
        try await base.downloadRemoteResource(kind: kind, slug: slug, version: version, baseURL: baseURL)
    }
}

private struct EmptySkillLookupMockSkillsRepositoryService: NolonSkillsRepositoryServing {
    private let base = MockSkillsRepositoryService(
        repositoryResources: NolonRepositoryResources(skillsDirectories: [], workflows: [], mcps: []),
        localRepositories: []
    )

    func planGitImport(source: String, repositoriesRoot: STFolder) throws -> NolonGitImportPlan {
        try base.planGitImport(source: source, repositoriesRoot: repositoriesRoot)
    }
    func preflightGitSync(
        source: String,
        accessToken: String?,
        pullStrategy: NolonGitPullStrategy,
        credentialStrategy: NolonGitCredentialStrategy
    ) throws -> NolonGitSyncPreflight {
        try base.preflightGitSync(
            source: source,
            accessToken: accessToken,
            pullStrategy: pullStrategy,
            credentialStrategy: credentialStrategy
        )
    }
    func syncGitRepository(
        plan: NolonGitImportPlan,
        accessToken: String?,
        pullStrategy: NolonGitPullStrategy,
        credentialStrategy: NolonGitCredentialStrategy
    ) async throws -> NolonGitSyncResult {
        try await base.syncGitRepository(
            plan: plan,
            accessToken: accessToken,
            pullStrategy: pullStrategy,
            credentialStrategy: credentialStrategy
        )
    }
    func discoverSkillsDirectories(at repositoryPath: STFolder, maxDepth: Int) -> [NolonSkillsDirectoryCandidate] {
        []
    }
    func listLocalRepositories(repositoriesRoot: STFolder, maxDepth: Int) -> [NolonLocalRepositorySummary] {
        []
    }
    func parseSkillMetadata(content: String, directoryName: String?) -> NolonSkillStandardMetadata? {
        base.parseSkillMetadata(content: content, directoryName: directoryName)
    }
    func discoverRepositoryResources(at repositoryPath: STFolder, maxDepth: Int) -> NolonRepositoryResources {
        NolonRepositoryResources(skillsDirectories: [], workflows: [], mcps: [])
    }
    func installSkill(
        skillPath: STPath,
        skillID: String?,
        providerPath: STFolder,
        installMethod: NolonSkillInstallMethod
    ) throws -> NolonSkillInstallResult {
        try base.installSkill(
            skillPath: skillPath,
            skillID: skillID,
            providerPath: providerPath,
            installMethod: installMethod
        )
    }
    func uninstallSkill(skillID: String, providerPath: STFolder) throws -> NolonSkillUninstallResult {
        try base.uninstallSkill(skillID: skillID, providerPath: providerPath)
    }
    func scanProviderSkills(providerPath: STFolder, globalSkillsPath: STFolder) throws -> NolonSkillMigrateScanResult {
        try base.scanProviderSkills(providerPath: providerPath, globalSkillsPath: globalSkillsPath)
    }
    func migrateSkill(
        skillID: String,
        providerPath: STFolder,
        globalSkillsPath: STFolder,
        installMethod: NolonSkillInstallMethod
    ) throws -> NolonSkillInstallResult {
        try base.migrateSkill(
            skillID: skillID,
            providerPath: providerPath,
            globalSkillsPath: globalSkillsPath,
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
        try base.installResource(
            kind: kind,
            filePath: filePath,
            resourceName: resourceName,
            targetPath: targetPath,
            installMethod: installMethod
        )
    }
    func uninstallResource(
        kind: NolonResourceKind,
        resourceName: String,
        targetPath: STFolder
    ) throws -> NolonResourceUninstallResult {
        try base.uninstallResource(kind: kind, resourceName: resourceName, targetPath: targetPath)
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
        try await base.downloadRemoteResource(kind: kind, slug: slug, version: version, baseURL: baseURL)
    }
}

private struct MultiMatchRemoteSearchMockSkillsRepositoryService: NolonSkillsRepositoryServing {
    private let base = MockSkillsRepositoryService(
        repositoryResources: NolonRepositoryResources(skillsDirectories: [], workflows: [], mcps: []),
        localRepositories: []
    )

    func planGitImport(source: String, repositoriesRoot: STFolder) throws -> NolonGitImportPlan {
        try base.planGitImport(source: source, repositoriesRoot: repositoriesRoot)
    }
    func preflightGitSync(
        source: String,
        accessToken: String?,
        pullStrategy: NolonGitPullStrategy,
        credentialStrategy: NolonGitCredentialStrategy
    ) throws -> NolonGitSyncPreflight {
        try base.preflightGitSync(
            source: source,
            accessToken: accessToken,
            pullStrategy: pullStrategy,
            credentialStrategy: credentialStrategy
        )
    }
    func syncGitRepository(
        plan: NolonGitImportPlan,
        accessToken: String?,
        pullStrategy: NolonGitPullStrategy,
        credentialStrategy: NolonGitCredentialStrategy
    ) async throws -> NolonGitSyncResult {
        try await base.syncGitRepository(
            plan: plan,
            accessToken: accessToken,
            pullStrategy: pullStrategy,
            credentialStrategy: credentialStrategy
        )
    }
    func discoverSkillsDirectories(at repositoryPath: STFolder, maxDepth: Int) -> [NolonSkillsDirectoryCandidate] {
        []
    }
    func listLocalRepositories(repositoriesRoot: STFolder, maxDepth: Int) -> [NolonLocalRepositorySummary] {
        []
    }
    func parseSkillMetadata(content: String, directoryName: String?) -> NolonSkillStandardMetadata? {
        base.parseSkillMetadata(content: content, directoryName: directoryName)
    }
    func discoverRepositoryResources(at repositoryPath: STFolder, maxDepth: Int) -> NolonRepositoryResources {
        NolonRepositoryResources(skillsDirectories: [], workflows: [], mcps: [])
    }
    func installSkill(
        skillPath: STPath,
        skillID: String?,
        providerPath: STFolder,
        installMethod: NolonSkillInstallMethod
    ) throws -> NolonSkillInstallResult {
        try base.installSkill(
            skillPath: skillPath,
            skillID: skillID,
            providerPath: providerPath,
            installMethod: installMethod
        )
    }
    func uninstallSkill(skillID: String, providerPath: STFolder) throws -> NolonSkillUninstallResult {
        try base.uninstallSkill(skillID: skillID, providerPath: providerPath)
    }
    func scanProviderSkills(providerPath: STFolder, globalSkillsPath: STFolder) throws -> NolonSkillMigrateScanResult {
        try base.scanProviderSkills(providerPath: providerPath, globalSkillsPath: globalSkillsPath)
    }
    func migrateSkill(
        skillID: String,
        providerPath: STFolder,
        globalSkillsPath: STFolder,
        installMethod: NolonSkillInstallMethod
    ) throws -> NolonSkillInstallResult {
        try base.migrateSkill(
            skillID: skillID,
            providerPath: providerPath,
            globalSkillsPath: globalSkillsPath,
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
        try base.installResource(
            kind: kind,
            filePath: filePath,
            resourceName: resourceName,
            targetPath: targetPath,
            installMethod: installMethod
        )
    }
    func uninstallResource(
        kind: NolonResourceKind,
        resourceName: String,
        targetPath: STFolder
    ) throws -> NolonResourceUninstallResult {
        try base.uninstallResource(kind: kind, resourceName: resourceName, targetPath: targetPath)
    }
    func listRemoteResources(
        kind: NolonRemoteCatalogKind,
        query: String?,
        limit: Int,
        baseURL: String
    ) async throws -> NolonRemoteListResult {
        let items = [
            NolonRemoteCatalogItem(
                kind: .skill,
                slug: "xcode",
                displayName: "Xcode",
                summary: "Xcode skill",
                latestVersion: "1.0.0",
                updatedAt: Date(timeIntervalSince1970: 0),
                downloads: nil,
                stars: nil,
                installs: nil
            ),
            NolonRemoteCatalogItem(
                kind: .skill,
                slug: "xcodebuildmcp",
                displayName: "xcodebuildmcp",
                summary: "xcodebuildmcp skill",
                latestVersion: "1.0.0",
                updatedAt: Date(timeIntervalSince1970: 0),
                downloads: nil,
                stars: nil,
                installs: nil
            ),
        ]
        return NolonRemoteListResult(kind: kind, baseURL: baseURL, query: query, limit: limit, items: items)
    }
    func downloadRemoteResource(
        kind: NolonRemoteCatalogKind,
        slug: String,
        version: String?,
        baseURL: String
    ) async throws -> NolonRemoteDownloadResult {
        try await base.downloadRemoteResource(kind: kind, slug: slug, version: version, baseURL: baseURL)
    }
}

private struct ManyMatchRemoteSearchMockSkillsRepositoryService: NolonSkillsRepositoryServing {
    private let base = MockSkillsRepositoryService(
        repositoryResources: NolonRepositoryResources(skillsDirectories: [], workflows: [], mcps: []),
        localRepositories: []
    )

    func planGitImport(source: String, repositoriesRoot: STFolder) throws -> NolonGitImportPlan {
        try base.planGitImport(source: source, repositoriesRoot: repositoriesRoot)
    }
    func preflightGitSync(
        source: String,
        accessToken: String?,
        pullStrategy: NolonGitPullStrategy,
        credentialStrategy: NolonGitCredentialStrategy
    ) throws -> NolonGitSyncPreflight {
        try base.preflightGitSync(
            source: source,
            accessToken: accessToken,
            pullStrategy: pullStrategy,
            credentialStrategy: credentialStrategy
        )
    }
    func syncGitRepository(
        plan: NolonGitImportPlan,
        accessToken: String?,
        pullStrategy: NolonGitPullStrategy,
        credentialStrategy: NolonGitCredentialStrategy
    ) async throws -> NolonGitSyncResult {
        try await base.syncGitRepository(
            plan: plan,
            accessToken: accessToken,
            pullStrategy: pullStrategy,
            credentialStrategy: credentialStrategy
        )
    }
    func discoverSkillsDirectories(at repositoryPath: STFolder, maxDepth: Int) -> [NolonSkillsDirectoryCandidate] {
        []
    }
    func listLocalRepositories(repositoriesRoot: STFolder, maxDepth: Int) -> [NolonLocalRepositorySummary] {
        []
    }
    func parseSkillMetadata(content: String, directoryName: String?) -> NolonSkillStandardMetadata? {
        base.parseSkillMetadata(content: content, directoryName: directoryName)
    }
    func discoverRepositoryResources(at repositoryPath: STFolder, maxDepth: Int) -> NolonRepositoryResources {
        NolonRepositoryResources(skillsDirectories: [], workflows: [], mcps: [])
    }
    func installSkill(
        skillPath: STPath,
        skillID: String?,
        providerPath: STFolder,
        installMethod: NolonSkillInstallMethod
    ) throws -> NolonSkillInstallResult {
        try base.installSkill(skillPath: skillPath, skillID: skillID, providerPath: providerPath, installMethod: installMethod)
    }
    func uninstallSkill(skillID: String, providerPath: STFolder) throws -> NolonSkillUninstallResult {
        try base.uninstallSkill(skillID: skillID, providerPath: providerPath)
    }
    func scanProviderSkills(providerPath: STFolder, globalSkillsPath: STFolder) throws -> NolonSkillMigrateScanResult {
        try base.scanProviderSkills(providerPath: providerPath, globalSkillsPath: globalSkillsPath)
    }
    func migrateSkill(
        skillID: String,
        providerPath: STFolder,
        globalSkillsPath: STFolder,
        installMethod: NolonSkillInstallMethod
    ) throws -> NolonSkillInstallResult {
        try base.migrateSkill(
            skillID: skillID,
            providerPath: providerPath,
            globalSkillsPath: globalSkillsPath,
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
        try base.installResource(kind: kind, filePath: filePath, resourceName: resourceName, targetPath: targetPath, installMethod: installMethod)
    }
    func uninstallResource(
        kind: NolonResourceKind,
        resourceName: String,
        targetPath: STFolder
    ) throws -> NolonResourceUninstallResult {
        try base.uninstallResource(kind: kind, resourceName: resourceName, targetPath: targetPath)
    }
    func listRemoteResources(
        kind: NolonRemoteCatalogKind,
        query: String?,
        limit: Int,
        baseURL: String
    ) async throws -> NolonRemoteListResult {
        let items = (1...20).map { index in
            NolonRemoteCatalogItem(
                kind: .skill,
                slug: "skill-\(index)",
                displayName: "Skill \(index)",
                summary: "summary \(index)",
                latestVersion: "1.0.0",
                updatedAt: Date(timeIntervalSince1970: 0),
                downloads: nil,
                stars: nil,
                installs: nil
            )
        }
        return NolonRemoteListResult(kind: kind, baseURL: baseURL, query: query, limit: limit, items: items)
    }
    func downloadRemoteResource(
        kind: NolonRemoteCatalogKind,
        slug: String,
        version: String?,
        baseURL: String
    ) async throws -> NolonRemoteDownloadResult {
        try await base.downloadRemoteResource(kind: kind, slug: slug, version: version, baseURL: baseURL)
    }
}

private struct RateLimitedRemoteSearchMockSkillsRepositoryService: NolonSkillsRepositoryServing {
    private let base = MockSkillsRepositoryService(
        repositoryResources: NolonRepositoryResources(skillsDirectories: [], workflows: [], mcps: []),
        localRepositories: []
    )

    func planGitImport(source: String, repositoriesRoot: STFolder) throws -> NolonGitImportPlan {
        try base.planGitImport(source: source, repositoriesRoot: repositoriesRoot)
    }
    func preflightGitSync(
        source: String,
        accessToken: String?,
        pullStrategy: NolonGitPullStrategy,
        credentialStrategy: NolonGitCredentialStrategy
    ) throws -> NolonGitSyncPreflight {
        try base.preflightGitSync(
            source: source,
            accessToken: accessToken,
            pullStrategy: pullStrategy,
            credentialStrategy: credentialStrategy
        )
    }
    func syncGitRepository(
        plan: NolonGitImportPlan,
        accessToken: String?,
        pullStrategy: NolonGitPullStrategy,
        credentialStrategy: NolonGitCredentialStrategy
    ) async throws -> NolonGitSyncResult {
        try await base.syncGitRepository(
            plan: plan,
            accessToken: accessToken,
            pullStrategy: pullStrategy,
            credentialStrategy: credentialStrategy
        )
    }
    func discoverSkillsDirectories(at repositoryPath: STFolder, maxDepth: Int) -> [NolonSkillsDirectoryCandidate] {
        []
    }
    func listLocalRepositories(repositoriesRoot: STFolder, maxDepth: Int) -> [NolonLocalRepositorySummary] {
        []
    }
    func parseSkillMetadata(content: String, directoryName: String?) -> NolonSkillStandardMetadata? {
        base.parseSkillMetadata(content: content, directoryName: directoryName)
    }
    func discoverRepositoryResources(at repositoryPath: STFolder, maxDepth: Int) -> NolonRepositoryResources {
        NolonRepositoryResources(skillsDirectories: [], workflows: [], mcps: [])
    }
    func installSkill(
        skillPath: STPath,
        skillID: String?,
        providerPath: STFolder,
        installMethod: NolonSkillInstallMethod
    ) throws -> NolonSkillInstallResult {
        try base.installSkill(
            skillPath: skillPath,
            skillID: skillID,
            providerPath: providerPath,
            installMethod: installMethod
        )
    }
    func uninstallSkill(skillID: String, providerPath: STFolder) throws -> NolonSkillUninstallResult {
        try base.uninstallSkill(skillID: skillID, providerPath: providerPath)
    }
    func scanProviderSkills(providerPath: STFolder, globalSkillsPath: STFolder) throws -> NolonSkillMigrateScanResult {
        try base.scanProviderSkills(providerPath: providerPath, globalSkillsPath: globalSkillsPath)
    }
    func migrateSkill(
        skillID: String,
        providerPath: STFolder,
        globalSkillsPath: STFolder,
        installMethod: NolonSkillInstallMethod
    ) throws -> NolonSkillInstallResult {
        try base.migrateSkill(
            skillID: skillID,
            providerPath: providerPath,
            globalSkillsPath: globalSkillsPath,
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
        try base.installResource(
            kind: kind,
            filePath: filePath,
            resourceName: resourceName,
            targetPath: targetPath,
            installMethod: installMethod
        )
    }
    func uninstallResource(
        kind: NolonResourceKind,
        resourceName: String,
        targetPath: STFolder
    ) throws -> NolonResourceUninstallResult {
        try base.uninstallResource(kind: kind, resourceName: resourceName, targetPath: targetPath)
    }
    func listRemoteResources(
        kind: NolonRemoteCatalogKind,
        query: String?,
        limit: Int,
        baseURL: String
    ) async throws -> NolonRemoteListResult {
        throw NolonCoreCLIError.executionFailed("Failed to run command: Remote list failed with status 429")
    }
    func downloadRemoteResource(
        kind: NolonRemoteCatalogKind,
        slug: String,
        version: String?,
        baseURL: String
    ) async throws -> NolonRemoteDownloadResult {
        try await base.downloadRemoteResource(kind: kind, slug: slug, version: version, baseURL: baseURL)
    }
}

private struct PermissionDeniedRemoteSearchMockSkillsRepositoryService: NolonSkillsRepositoryServing {
    private let base = MockSkillsRepositoryService(
        repositoryResources: NolonRepositoryResources(skillsDirectories: [], workflows: [], mcps: []),
        localRepositories: []
    )

    func planGitImport(source: String, repositoriesRoot: STFolder) throws -> NolonGitImportPlan {
        try base.planGitImport(source: source, repositoriesRoot: repositoriesRoot)
    }
    func preflightGitSync(
        source: String,
        accessToken: String?,
        pullStrategy: NolonGitPullStrategy,
        credentialStrategy: NolonGitCredentialStrategy
    ) throws -> NolonGitSyncPreflight {
        try base.preflightGitSync(
            source: source,
            accessToken: accessToken,
            pullStrategy: pullStrategy,
            credentialStrategy: credentialStrategy
        )
    }
    func syncGitRepository(
        plan: NolonGitImportPlan,
        accessToken: String?,
        pullStrategy: NolonGitPullStrategy,
        credentialStrategy: NolonGitCredentialStrategy
    ) async throws -> NolonGitSyncResult {
        try await base.syncGitRepository(
            plan: plan,
            accessToken: accessToken,
            pullStrategy: pullStrategy,
            credentialStrategy: credentialStrategy
        )
    }
    func discoverSkillsDirectories(at repositoryPath: STFolder, maxDepth: Int) -> [NolonSkillsDirectoryCandidate] { [] }
    func listLocalRepositories(repositoriesRoot: STFolder, maxDepth: Int) -> [NolonLocalRepositorySummary] { [] }
    func parseSkillMetadata(content: String, directoryName: String?) -> NolonSkillStandardMetadata? {
        base.parseSkillMetadata(content: content, directoryName: directoryName)
    }
    func discoverRepositoryResources(at repositoryPath: STFolder, maxDepth: Int) -> NolonRepositoryResources {
        NolonRepositoryResources(skillsDirectories: [], workflows: [], mcps: [])
    }
    func installSkill(
        skillPath: STPath,
        skillID: String?,
        providerPath: STFolder,
        installMethod: NolonSkillInstallMethod
    ) throws -> NolonSkillInstallResult {
        try base.installSkill(skillPath: skillPath, skillID: skillID, providerPath: providerPath, installMethod: installMethod)
    }
    func uninstallSkill(skillID: String, providerPath: STFolder) throws -> NolonSkillUninstallResult {
        try base.uninstallSkill(skillID: skillID, providerPath: providerPath)
    }
    func scanProviderSkills(providerPath: STFolder, globalSkillsPath: STFolder) throws -> NolonSkillMigrateScanResult {
        try base.scanProviderSkills(providerPath: providerPath, globalSkillsPath: globalSkillsPath)
    }
    func migrateSkill(
        skillID: String,
        providerPath: STFolder,
        globalSkillsPath: STFolder,
        installMethod: NolonSkillInstallMethod
    ) throws -> NolonSkillInstallResult {
        try base.migrateSkill(
            skillID: skillID,
            providerPath: providerPath,
            globalSkillsPath: globalSkillsPath,
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
        try base.installResource(kind: kind, filePath: filePath, resourceName: resourceName, targetPath: targetPath, installMethod: installMethod)
    }
    func uninstallResource(
        kind: NolonResourceKind,
        resourceName: String,
        targetPath: STFolder
    ) throws -> NolonResourceUninstallResult {
        try base.uninstallResource(kind: kind, resourceName: resourceName, targetPath: targetPath)
    }
    func listRemoteResources(
        kind: NolonRemoteCatalogKind,
        query: String?,
        limit: Int,
        baseURL: String
    ) async throws -> NolonRemoteListResult {
        throw NolonCoreCLIError.executionFailed("Operation not permitted")
    }
    func downloadRemoteResource(
        kind: NolonRemoteCatalogKind,
        slug: String,
        version: String?,
        baseURL: String
    ) async throws -> NolonRemoteDownloadResult {
        try await base.downloadRemoteResource(kind: kind, slug: slug, version: version, baseURL: baseURL)
    }
}

private struct RemoteCatalogUnavailableMockSkillsRepositoryService: NolonSkillsRepositoryServing {
    private let base = MockSkillsRepositoryService(
        repositoryResources: NolonRepositoryResources(skillsDirectories: [], workflows: [], mcps: []),
        localRepositories: []
    )

    func planGitImport(source: String, repositoriesRoot: STFolder) throws -> NolonGitImportPlan {
        try base.planGitImport(source: source, repositoriesRoot: repositoriesRoot)
    }
    func preflightGitSync(
        source: String,
        accessToken: String?,
        pullStrategy: NolonGitPullStrategy,
        credentialStrategy: NolonGitCredentialStrategy
    ) throws -> NolonGitSyncPreflight {
        try base.preflightGitSync(
            source: source,
            accessToken: accessToken,
            pullStrategy: pullStrategy,
            credentialStrategy: credentialStrategy
        )
    }
    func syncGitRepository(
        plan: NolonGitImportPlan,
        accessToken: String?,
        pullStrategy: NolonGitPullStrategy,
        credentialStrategy: NolonGitCredentialStrategy
    ) async throws -> NolonGitSyncResult {
        try await base.syncGitRepository(
            plan: plan,
            accessToken: accessToken,
            pullStrategy: pullStrategy,
            credentialStrategy: credentialStrategy
        )
    }
    func discoverSkillsDirectories(at repositoryPath: STFolder, maxDepth: Int) -> [NolonSkillsDirectoryCandidate] { [] }
    func listLocalRepositories(repositoriesRoot: STFolder, maxDepth: Int) -> [NolonLocalRepositorySummary] { [] }
    func parseSkillMetadata(content: String, directoryName: String?) -> NolonSkillStandardMetadata? {
        base.parseSkillMetadata(content: content, directoryName: directoryName)
    }
    func discoverRepositoryResources(at repositoryPath: STFolder, maxDepth: Int) -> NolonRepositoryResources {
        NolonRepositoryResources(skillsDirectories: [], workflows: [], mcps: [])
    }
    func installSkill(
        skillPath: STPath,
        skillID: String?,
        providerPath: STFolder,
        installMethod: NolonSkillInstallMethod
    ) throws -> NolonSkillInstallResult {
        try base.installSkill(skillPath: skillPath, skillID: skillID, providerPath: providerPath, installMethod: installMethod)
    }
    func uninstallSkill(skillID: String, providerPath: STFolder) throws -> NolonSkillUninstallResult {
        try base.uninstallSkill(skillID: skillID, providerPath: providerPath)
    }
    func scanProviderSkills(providerPath: STFolder, globalSkillsPath: STFolder) throws -> NolonSkillMigrateScanResult {
        try base.scanProviderSkills(providerPath: providerPath, globalSkillsPath: globalSkillsPath)
    }
    func migrateSkill(
        skillID: String,
        providerPath: STFolder,
        globalSkillsPath: STFolder,
        installMethod: NolonSkillInstallMethod
    ) throws -> NolonSkillInstallResult {
        try base.migrateSkill(
            skillID: skillID,
            providerPath: providerPath,
            globalSkillsPath: globalSkillsPath,
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
        try base.installResource(kind: kind, filePath: filePath, resourceName: resourceName, targetPath: targetPath, installMethod: installMethod)
    }
    func uninstallResource(
        kind: NolonResourceKind,
        resourceName: String,
        targetPath: STFolder
    ) throws -> NolonResourceUninstallResult {
        try base.uninstallResource(kind: kind, resourceName: resourceName, targetPath: targetPath)
    }
    func listRemoteResources(
        kind: NolonRemoteCatalogKind,
        query: String?,
        limit: Int,
        baseURL: String
    ) async throws -> NolonRemoteListResult {
        throw NolonCoreCLIError.executionFailed("Failed to run command: Remote list failed with status 404")
    }
    func downloadRemoteResource(
        kind: NolonRemoteCatalogKind,
        slug: String,
        version: String?,
        baseURL: String
    ) async throws -> NolonRemoteDownloadResult {
        try await base.downloadRemoteResource(kind: kind, slug: slug, version: version, baseURL: baseURL)
    }
}

private struct LongSummaryRemoteSearchMockSkillsRepositoryService: NolonSkillsRepositoryServing {
    private let base = MockSkillsRepositoryService(
        repositoryResources: NolonRepositoryResources(skillsDirectories: [], workflows: [], mcps: []),
        localRepositories: []
    )

    func planGitImport(source: String, repositoriesRoot: STFolder) throws -> NolonGitImportPlan {
        try base.planGitImport(source: source, repositoriesRoot: repositoriesRoot)
    }
    func preflightGitSync(
        source: String,
        accessToken: String?,
        pullStrategy: NolonGitPullStrategy,
        credentialStrategy: NolonGitCredentialStrategy
    ) throws -> NolonGitSyncPreflight {
        try base.preflightGitSync(
            source: source,
            accessToken: accessToken,
            pullStrategy: pullStrategy,
            credentialStrategy: credentialStrategy
        )
    }
    func syncGitRepository(
        plan: NolonGitImportPlan,
        accessToken: String?,
        pullStrategy: NolonGitPullStrategy,
        credentialStrategy: NolonGitCredentialStrategy
    ) async throws -> NolonGitSyncResult {
        try await base.syncGitRepository(
            plan: plan,
            accessToken: accessToken,
            pullStrategy: pullStrategy,
            credentialStrategy: credentialStrategy
        )
    }
    func discoverSkillsDirectories(at repositoryPath: STFolder, maxDepth: Int) -> [NolonSkillsDirectoryCandidate] { [] }
    func listLocalRepositories(repositoriesRoot: STFolder, maxDepth: Int) -> [NolonLocalRepositorySummary] { [] }
    func parseSkillMetadata(content: String, directoryName: String?) -> NolonSkillStandardMetadata? {
        base.parseSkillMetadata(content: content, directoryName: directoryName)
    }
    func discoverRepositoryResources(at repositoryPath: STFolder, maxDepth: Int) -> NolonRepositoryResources {
        NolonRepositoryResources(skillsDirectories: [], workflows: [], mcps: [])
    }
    func installSkill(
        skillPath: STPath,
        skillID: String?,
        providerPath: STFolder,
        installMethod: NolonSkillInstallMethod
    ) throws -> NolonSkillInstallResult {
        try base.installSkill(skillPath: skillPath, skillID: skillID, providerPath: providerPath, installMethod: installMethod)
    }
    func uninstallSkill(skillID: String, providerPath: STFolder) throws -> NolonSkillUninstallResult {
        try base.uninstallSkill(skillID: skillID, providerPath: providerPath)
    }
    func scanProviderSkills(providerPath: STFolder, globalSkillsPath: STFolder) throws -> NolonSkillMigrateScanResult {
        try base.scanProviderSkills(providerPath: providerPath, globalSkillsPath: globalSkillsPath)
    }
    func migrateSkill(
        skillID: String,
        providerPath: STFolder,
        globalSkillsPath: STFolder,
        installMethod: NolonSkillInstallMethod
    ) throws -> NolonSkillInstallResult {
        try base.migrateSkill(skillID: skillID, providerPath: providerPath, globalSkillsPath: globalSkillsPath, installMethod: installMethod)
    }
    func installResource(
        kind: NolonResourceKind,
        filePath: STPath,
        resourceName: String?,
        targetPath: STFolder,
        installMethod: NolonSkillInstallMethod
    ) throws -> NolonResourceInstallResult {
        try base.installResource(kind: kind, filePath: filePath, resourceName: resourceName, targetPath: targetPath, installMethod: installMethod)
    }
    func uninstallResource(
        kind: NolonResourceKind,
        resourceName: String,
        targetPath: STFolder
    ) throws -> NolonResourceUninstallResult {
        try base.uninstallResource(kind: kind, resourceName: resourceName, targetPath: targetPath)
    }
    func listRemoteResources(
        kind: NolonRemoteCatalogKind,
        query: String?,
        limit: Int,
        baseURL: String
    ) async throws -> NolonRemoteListResult {
        let summary = """
        Xcode long summary line one
        line two and line three with additional details that should be compacted into one single line for CLI readability and then truncated because it is too long for concise output.
        """
        let item = NolonRemoteCatalogItem(
            kind: .skill,
            slug: "xcode",
            displayName: "Xcode",
            summary: summary,
            latestVersion: "1.0.0",
            updatedAt: Date(timeIntervalSince1970: 0),
            downloads: nil,
            stars: nil,
            installs: nil
        )
        return NolonRemoteListResult(kind: kind, baseURL: baseURL, query: query, limit: limit, items: [item])
    }
    func downloadRemoteResource(
        kind: NolonRemoteCatalogKind,
        slug: String,
        version: String?,
        baseURL: String
    ) async throws -> NolonRemoteDownloadResult {
        try await base.downloadRemoteResource(kind: kind, slug: slug, version: version, baseURL: baseURL)
    }
}

private struct FutureDateRemoteSearchMockSkillsRepositoryService: NolonSkillsRepositoryServing {
    private let base = MockSkillsRepositoryService(
        repositoryResources: NolonRepositoryResources(skillsDirectories: [], workflows: [], mcps: []),
        localRepositories: []
    )

    func planGitImport(source: String, repositoriesRoot: STFolder) throws -> NolonGitImportPlan {
        try base.planGitImport(source: source, repositoriesRoot: repositoriesRoot)
    }
    func preflightGitSync(
        source: String,
        accessToken: String?,
        pullStrategy: NolonGitPullStrategy,
        credentialStrategy: NolonGitCredentialStrategy
    ) throws -> NolonGitSyncPreflight {
        try base.preflightGitSync(
            source: source,
            accessToken: accessToken,
            pullStrategy: pullStrategy,
            credentialStrategy: credentialStrategy
        )
    }
    func syncGitRepository(
        plan: NolonGitImportPlan,
        accessToken: String?,
        pullStrategy: NolonGitPullStrategy,
        credentialStrategy: NolonGitCredentialStrategy
    ) async throws -> NolonGitSyncResult {
        try await base.syncGitRepository(
            plan: plan,
            accessToken: accessToken,
            pullStrategy: pullStrategy,
            credentialStrategy: credentialStrategy
        )
    }
    func discoverSkillsDirectories(at repositoryPath: STFolder, maxDepth: Int) -> [NolonSkillsDirectoryCandidate] { [] }
    func listLocalRepositories(repositoriesRoot: STFolder, maxDepth: Int) -> [NolonLocalRepositorySummary] { [] }
    func parseSkillMetadata(content: String, directoryName: String?) -> NolonSkillStandardMetadata? {
        base.parseSkillMetadata(content: content, directoryName: directoryName)
    }
    func discoverRepositoryResources(at repositoryPath: STFolder, maxDepth: Int) -> NolonRepositoryResources {
        NolonRepositoryResources(skillsDirectories: [], workflows: [], mcps: [])
    }
    func installSkill(
        skillPath: STPath,
        skillID: String?,
        providerPath: STFolder,
        installMethod: NolonSkillInstallMethod
    ) throws -> NolonSkillInstallResult {
        try base.installSkill(skillPath: skillPath, skillID: skillID, providerPath: providerPath, installMethod: installMethod)
    }
    func uninstallSkill(skillID: String, providerPath: STFolder) throws -> NolonSkillUninstallResult {
        try base.uninstallSkill(skillID: skillID, providerPath: providerPath)
    }
    func scanProviderSkills(providerPath: STFolder, globalSkillsPath: STFolder) throws -> NolonSkillMigrateScanResult {
        try base.scanProviderSkills(providerPath: providerPath, globalSkillsPath: globalSkillsPath)
    }
    func migrateSkill(
        skillID: String,
        providerPath: STFolder,
        globalSkillsPath: STFolder,
        installMethod: NolonSkillInstallMethod
    ) throws -> NolonSkillInstallResult {
        try base.migrateSkill(skillID: skillID, providerPath: providerPath, globalSkillsPath: globalSkillsPath, installMethod: installMethod)
    }
    func installResource(
        kind: NolonResourceKind,
        filePath: STPath,
        resourceName: String?,
        targetPath: STFolder,
        installMethod: NolonSkillInstallMethod
    ) throws -> NolonResourceInstallResult {
        try base.installResource(kind: kind, filePath: filePath, resourceName: resourceName, targetPath: targetPath, installMethod: installMethod)
    }
    func uninstallResource(
        kind: NolonResourceKind,
        resourceName: String,
        targetPath: STFolder
    ) throws -> NolonResourceUninstallResult {
        try base.uninstallResource(kind: kind, resourceName: resourceName, targetPath: targetPath)
    }
    func listRemoteResources(
        kind: NolonRemoteCatalogKind,
        query: String?,
        limit: Int,
        baseURL: String
    ) async throws -> NolonRemoteListResult {
        let item = NolonRemoteCatalogItem(
            kind: .skill,
            slug: "xcode",
            displayName: "Xcode",
            summary: "Xcode skill",
            latestVersion: "1.0.0",
            updatedAt: Date(timeIntervalSince1970: 4_102_444_800), // 2100-01-02
            downloads: nil,
            stars: nil,
            installs: nil
        )
        return NolonRemoteListResult(kind: kind, baseURL: baseURL, query: query, limit: limit, items: [item])
    }
    func downloadRemoteResource(
        kind: NolonRemoteCatalogKind,
        slug: String,
        version: String?,
        baseURL: String
    ) async throws -> NolonRemoteDownloadResult {
        try await base.downloadRemoteResource(kind: kind, slug: slug, version: version, baseURL: baseURL)
    }
}

private struct DryRunInstallGuardMockSkillsRepositoryService: NolonSkillsRepositoryServing {
    private let base: MockSkillsRepositoryService

    init(
        repositoryResources: NolonRepositoryResources,
        localRepositories: [NolonLocalRepositorySummary]
    ) {
        self.base = MockSkillsRepositoryService(
            repositoryResources: repositoryResources,
            localRepositories: localRepositories
        )
    }

    func planGitImport(source: String, repositoriesRoot: STFolder) throws -> NolonGitImportPlan {
        try base.planGitImport(source: source, repositoriesRoot: repositoriesRoot)
    }
    func preflightGitSync(
        source: String,
        accessToken: String?,
        pullStrategy: NolonGitPullStrategy,
        credentialStrategy: NolonGitCredentialStrategy
    ) throws -> NolonGitSyncPreflight {
        try base.preflightGitSync(
            source: source,
            accessToken: accessToken,
            pullStrategy: pullStrategy,
            credentialStrategy: credentialStrategy
        )
    }
    func syncGitRepository(
        plan: NolonGitImportPlan,
        accessToken: String?,
        pullStrategy: NolonGitPullStrategy,
        credentialStrategy: NolonGitCredentialStrategy
    ) async throws -> NolonGitSyncResult {
        try await base.syncGitRepository(
            plan: plan,
            accessToken: accessToken,
            pullStrategy: pullStrategy,
            credentialStrategy: credentialStrategy
        )
    }
    func discoverSkillsDirectories(at repositoryPath: STFolder, maxDepth: Int) -> [NolonSkillsDirectoryCandidate] {
        base.discoverSkillsDirectories(at: repositoryPath, maxDepth: maxDepth)
    }
    func listLocalRepositories(repositoriesRoot: STFolder, maxDepth: Int) -> [NolonLocalRepositorySummary] {
        base.listLocalRepositories(repositoriesRoot: repositoriesRoot, maxDepth: maxDepth)
    }
    func parseSkillMetadata(content: String, directoryName: String?) -> NolonSkillStandardMetadata? {
        base.parseSkillMetadata(content: content, directoryName: directoryName)
    }
    func discoverRepositoryResources(at repositoryPath: STFolder, maxDepth: Int) -> NolonRepositoryResources {
        base.discoverRepositoryResources(at: repositoryPath, maxDepth: maxDepth)
    }
    func installSkill(
        skillPath: STPath,
        skillID: String?,
        providerPath: STFolder,
        installMethod: NolonSkillInstallMethod
    ) throws -> NolonSkillInstallResult {
        throw NolonCoreCLIError.executionFailed("install should not be called during dry-run")
    }
    func uninstallSkill(skillID: String, providerPath: STFolder) throws -> NolonSkillUninstallResult {
        try base.uninstallSkill(skillID: skillID, providerPath: providerPath)
    }
    func scanProviderSkills(providerPath: STFolder, globalSkillsPath: STFolder) throws -> NolonSkillMigrateScanResult {
        try base.scanProviderSkills(providerPath: providerPath, globalSkillsPath: globalSkillsPath)
    }
    func migrateSkill(
        skillID: String,
        providerPath: STFolder,
        globalSkillsPath: STFolder,
        installMethod: NolonSkillInstallMethod
    ) throws -> NolonSkillInstallResult {
        try base.migrateSkill(
            skillID: skillID,
            providerPath: providerPath,
            globalSkillsPath: globalSkillsPath,
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
        try base.installResource(
            kind: kind,
            filePath: filePath,
            resourceName: resourceName,
            targetPath: targetPath,
            installMethod: installMethod
        )
    }
    func uninstallResource(
        kind: NolonResourceKind,
        resourceName: String,
        targetPath: STFolder
    ) throws -> NolonResourceUninstallResult {
        try base.uninstallResource(kind: kind, resourceName: resourceName, targetPath: targetPath)
    }
    func listRemoteResources(
        kind: NolonRemoteCatalogKind,
        query: String?,
        limit: Int,
        baseURL: String
    ) async throws -> NolonRemoteListResult {
        try await base.listRemoteResources(kind: kind, query: query, limit: limit, baseURL: baseURL)
    }
    func downloadRemoteResource(
        kind: NolonRemoteCatalogKind,
        slug: String,
        version: String?,
        baseURL: String
    ) async throws -> NolonRemoteDownloadResult {
        try await base.downloadRemoteResource(kind: kind, slug: slug, version: version, baseURL: baseURL)
    }
}

private struct InstalledAndBrokenSkillsRepositoryService: NolonSkillsRepositoryServing {
    private let base = MockSkillsRepositoryService()

    func planGitImport(source: String, repositoriesRoot: STFolder) throws -> NolonGitImportPlan {
        try base.planGitImport(source: source, repositoriesRoot: repositoriesRoot)
    }
    func preflightGitSync(
        source: String,
        accessToken: String?,
        pullStrategy: NolonGitPullStrategy,
        credentialStrategy: NolonGitCredentialStrategy
    ) throws -> NolonGitSyncPreflight {
        try base.preflightGitSync(
            source: source,
            accessToken: accessToken,
            pullStrategy: pullStrategy,
            credentialStrategy: credentialStrategy
        )
    }
    func syncGitRepository(
        plan: NolonGitImportPlan,
        accessToken: String?,
        pullStrategy: NolonGitPullStrategy,
        credentialStrategy: NolonGitCredentialStrategy
    ) async throws -> NolonGitSyncResult {
        try await base.syncGitRepository(
            plan: plan,
            accessToken: accessToken,
            pullStrategy: pullStrategy,
            credentialStrategy: credentialStrategy
        )
    }
    func discoverSkillsDirectories(at repositoryPath: STFolder, maxDepth: Int) -> [NolonSkillsDirectoryCandidate] {
        base.discoverSkillsDirectories(at: repositoryPath, maxDepth: maxDepth)
    }
    func listLocalRepositories(repositoriesRoot: STFolder, maxDepth: Int) -> [NolonLocalRepositorySummary] {
        base.listLocalRepositories(repositoriesRoot: repositoriesRoot, maxDepth: maxDepth)
    }
    func parseSkillMetadata(content: String, directoryName: String?) -> NolonSkillStandardMetadata? {
        base.parseSkillMetadata(content: content, directoryName: directoryName)
    }
    func discoverRepositoryResources(at repositoryPath: STFolder, maxDepth: Int) -> NolonRepositoryResources {
        base.discoverRepositoryResources(at: repositoryPath, maxDepth: maxDepth)
    }
    func installSkill(
        skillPath: STPath,
        skillID: String?,
        providerPath: STFolder,
        installMethod: NolonSkillInstallMethod
    ) throws -> NolonSkillInstallResult {
        try base.installSkill(skillPath: skillPath, skillID: skillID, providerPath: providerPath, installMethod: installMethod)
    }
    func uninstallSkill(skillID: String, providerPath: STFolder) throws -> NolonSkillUninstallResult {
        try base.uninstallSkill(skillID: skillID, providerPath: providerPath)
    }
    func scanProviderSkills(providerPath: STFolder, globalSkillsPath: STFolder) throws -> NolonSkillMigrateScanResult {
        NolonSkillMigrateScanResult(
            providerPath: providerPath.url.path,
            globalSkillsPath: globalSkillsPath.url.path,
            states: [
                NolonProviderSkillState(skillID: "xcode", path: providerPath.subpath("xcode").url.path, state: .installed),
                NolonProviderSkillState(skillID: "find-skills", path: providerPath.subpath("find-skills").url.path, state: .broken),
            ]
        )
    }
    func migrateSkill(
        skillID: String,
        providerPath: STFolder,
        globalSkillsPath: STFolder,
        installMethod: NolonSkillInstallMethod
    ) throws -> NolonSkillInstallResult {
        try base.migrateSkill(
            skillID: skillID,
            providerPath: providerPath,
            globalSkillsPath: globalSkillsPath,
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
        try base.installResource(
            kind: kind,
            filePath: filePath,
            resourceName: resourceName,
            targetPath: targetPath,
            installMethod: installMethod
        )
    }
    func uninstallResource(
        kind: NolonResourceKind,
        resourceName: String,
        targetPath: STFolder
    ) throws -> NolonResourceUninstallResult {
        try base.uninstallResource(kind: kind, resourceName: resourceName, targetPath: targetPath)
    }
    func listRemoteResources(
        kind: NolonRemoteCatalogKind,
        query: String?,
        limit: Int,
        baseURL: String
    ) async throws -> NolonRemoteListResult {
        try await base.listRemoteResources(kind: kind, query: query, limit: limit, baseURL: baseURL)
    }
    func downloadRemoteResource(
        kind: NolonRemoteCatalogKind,
        slug: String,
        version: String?,
        baseURL: String
    ) async throws -> NolonRemoteDownloadResult {
        try await base.downloadRemoteResource(kind: kind, slug: slug, version: version, baseURL: baseURL)
    }
}

private struct OrphanedAndBrokenSkillsRepositoryService: NolonSkillsRepositoryServing {
    private let base = MockSkillsRepositoryService(
        repositoryResources: NolonRepositoryResources(skillsDirectories: [], workflows: [], mcps: []),
        localRepositories: []
    )

    func planGitImport(source: String, repositoriesRoot: STFolder) throws -> NolonGitImportPlan {
        try base.planGitImport(source: source, repositoriesRoot: repositoriesRoot)
    }
    func preflightGitSync(
        source: String,
        accessToken: String?,
        pullStrategy: NolonGitPullStrategy,
        credentialStrategy: NolonGitCredentialStrategy
    ) throws -> NolonGitSyncPreflight {
        try base.preflightGitSync(
            source: source,
            accessToken: accessToken,
            pullStrategy: pullStrategy,
            credentialStrategy: credentialStrategy
        )
    }
    func syncGitRepository(
        plan: NolonGitImportPlan,
        accessToken: String?,
        pullStrategy: NolonGitPullStrategy,
        credentialStrategy: NolonGitCredentialStrategy
    ) async throws -> NolonGitSyncResult {
        try await base.syncGitRepository(
            plan: plan,
            accessToken: accessToken,
            pullStrategy: pullStrategy,
            credentialStrategy: credentialStrategy
        )
    }
    func discoverSkillsDirectories(at repositoryPath: STFolder, maxDepth: Int) -> [NolonSkillsDirectoryCandidate] {
        []
    }
    func listLocalRepositories(repositoriesRoot: STFolder, maxDepth: Int) -> [NolonLocalRepositorySummary] {
        []
    }
    func parseSkillMetadata(content: String, directoryName: String?) -> NolonSkillStandardMetadata? {
        base.parseSkillMetadata(content: content, directoryName: directoryName)
    }
    func discoverRepositoryResources(at repositoryPath: STFolder, maxDepth: Int) -> NolonRepositoryResources {
        NolonRepositoryResources(skillsDirectories: [], workflows: [], mcps: [])
    }
    func installSkill(
        skillPath: STPath,
        skillID: String?,
        providerPath: STFolder,
        installMethod: NolonSkillInstallMethod
    ) throws -> NolonSkillInstallResult {
        try base.installSkill(skillPath: skillPath, skillID: skillID, providerPath: providerPath, installMethod: installMethod)
    }
    func uninstallSkill(skillID: String, providerPath: STFolder) throws -> NolonSkillUninstallResult {
        try base.uninstallSkill(skillID: skillID, providerPath: providerPath)
    }
    func scanProviderSkills(providerPath: STFolder, globalSkillsPath: STFolder) throws -> NolonSkillMigrateScanResult {
        return NolonSkillMigrateScanResult(
            providerPath: providerPath.url.path,
            globalSkillsPath: globalSkillsPath.url.path,
            states: [
                NolonProviderSkillState(skillID: "agent-browser", path: providerPath.subpath("agent-browser").url.path, state: .orphaned),
                NolonProviderSkillState(skillID: "find-skills", path: providerPath.subpath("find-skills").url.path, state: .broken),
            ]
        )
    }
    func migrateSkill(
        skillID: String,
        providerPath: STFolder,
        globalSkillsPath: STFolder,
        installMethod: NolonSkillInstallMethod
    ) throws -> NolonSkillInstallResult {
        try base.migrateSkill(skillID: skillID, providerPath: providerPath, globalSkillsPath: globalSkillsPath, installMethod: installMethod)
    }
    func installResource(
        kind: NolonResourceKind,
        filePath: STPath,
        resourceName: String?,
        targetPath: STFolder,
        installMethod: NolonSkillInstallMethod
    ) throws -> NolonResourceInstallResult {
        try base.installResource(kind: kind, filePath: filePath, resourceName: resourceName, targetPath: targetPath, installMethod: installMethod)
    }
    func uninstallResource(
        kind: NolonResourceKind,
        resourceName: String,
        targetPath: STFolder
    ) throws -> NolonResourceUninstallResult {
        try base.uninstallResource(kind: kind, resourceName: resourceName, targetPath: targetPath)
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
        try await base.downloadRemoteResource(kind: kind, slug: slug, version: version, baseURL: baseURL)
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
