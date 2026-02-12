import Foundation
import STFilePath
import Testing
@testable import NolonCoreCLIKit

@Suite("NolonCoreCLIKit")
struct NolonCoreCLIKitTests {
    @Test("parse skills repo plan command")
    func parseSkillsRepoPlan() throws {
        let command = try NolonCoreCLICommandParser.parse(
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
        #expect(throws: NolonCoreCLIError.invalidArguments("Missing required option: --source")) {
            _ = try NolonCoreCLICommandParser.parse(
                ["skills", "repo", "plan", "--repositories-root", "/tmp/repos"]
            )
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
        let command = try NolonCoreCLICommandParser.parse(
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
        let command = try NolonCoreCLICommandParser.parse(
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
        #expect(throws: NolonCoreCLIError.invalidArguments("Unsupported --pull-strategy: no-fast-forward")) {
            _ = try NolonCoreCLICommandParser.parse(
                [
                    "skills", "repo", "preflight",
                    "--source", "vercel/agent-skills",
                    "--pull-strategy", "no-fast-forward",
                ]
            )
        }
    }

    @Test("invalid credential strategy is rejected by parser")
    func parseRejectsInvalidCredentialStrategy() {
        #expect(throws: NolonCoreCLIError.invalidArguments("Unsupported --credential-strategy: basic-auth")) {
            _ = try NolonCoreCLICommandParser.parse(
                [
                    "skills", "repo", "preflight",
                    "--source", "vercel/agent-skills",
                    "--credential-strategy", "basic-auth",
                ]
            )
        }
    }

    @Test("runner renders parse result from SKILL file")
    func runnerRendersParseResult() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("nolon-cli-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let skillFile = root.appendingPathComponent("SKILL.md")
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
        ).write(to: skillFile)

        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { path in
                try String(contentsOfFile: path, encoding: .utf8)
            }
        )

        let result = await runner.execute(
            arguments: [
                "skills", "parse",
                "--file", skillFile.path,
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

    @Test("parse resources discover command")
    func parseResourcesDiscover() throws {
        let command = try NolonCoreCLICommandParser.parse(
            ["resources", "discover", "--path", "/tmp/repo", "--max-depth", "3"]
        )
        guard case let .resourcesDiscover(path, maxDepth) = command else {
            Issue.record("Expected .resourcesDiscover")
            return
        }
        #expect(path == "/tmp/repo")
        #expect(maxDepth == 3)
    }

    @Test("parse resources install command")
    func parseResourcesInstall() throws {
        let command = try NolonCoreCLICommandParser.parse(
            [
                "resources", "install",
                "--kind", "workflow",
                "--file-path", "/tmp/source/review.md",
                "--target-path", "/tmp/provider/workflows",
                "--install-method", "copy",
            ]
        )
        guard case let .resourcesInstall(kind, filePath, resourceName, targetPath, installMethod) = command else {
            Issue.record("Expected .resourcesInstall")
            return
        }
        #expect(kind == .workflow)
        #expect(filePath == "/tmp/source/review.md")
        #expect(resourceName == nil)
        #expect(targetPath == "/tmp/provider/workflows")
        #expect(installMethod == .copy)
    }

    @Test("parse resources uninstall command")
    func parseResourcesUninstall() throws {
        let command = try NolonCoreCLICommandParser.parse(
            [
                "resources", "uninstall",
                "--kind", "mcp",
                "--resource-name", "cursor-mcp.json",
                "--target-path", "/tmp/provider/mcp",
            ]
        )
        guard case let .resourcesUninstall(kind, resourceName, targetPath) = command else {
            Issue.record("Expected .resourcesUninstall")
            return
        }
        #expect(kind == .mcp)
        #expect(resourceName == "cursor-mcp.json")
        #expect(targetPath == "/tmp/provider/mcp")
    }

    @Test("parse remote list command")
    func parseRemoteList() throws {
        let command = try NolonCoreCLICommandParser.parse(
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
        let command = try NolonCoreCLICommandParser.parse(
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

    @Test("parse skills install command")
    func parseSkillsInstall() throws {
        let command = try NolonCoreCLICommandParser.parse(
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
        let command = try NolonCoreCLICommandParser.parse(
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
        let command = try NolonCoreCLICommandParser.parse(
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
        let command = try NolonCoreCLICommandParser.parse(
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

    @Test("runner renders repository resources json")
    func runnerRendersRepositoryResources() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )

        let result = await runner.execute(
            arguments: ["resources", "discover", "--path", "/tmp/repo"]
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("\"command\":\"resources.discover\""))
        #expect(result.stdout.contains("\"workflows\""))
        #expect(result.stdout.contains("\"mcps\""))
    }

    @Test("runner renders resources install result")
    func runnerRendersResourcesInstallResult() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "resources", "install",
                "--kind", "workflow",
                "--file-path", "/tmp/source/review.md",
                "--target-path", "/tmp/provider/workflows",
                "--install-method", "copy",
            ]
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("\"command\":\"resources.install\""))
        #expect(result.stdout.contains("\"kind\":\"workflow\""))
        #expect(result.stdout.contains("\"install_method\":\"copy\""))
    }

    @Test("runner renders resources uninstall result")
    func runnerRendersResourcesUninstallResult() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: [
                "resources", "uninstall",
                "--kind", "mcp",
                "--resource-name", "cursor-mcp.json",
                "--target-path", "/tmp/provider/mcp",
            ]
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("\"command\":\"resources.uninstall\""))
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
        NolonRemoteDownloadResult(
            kind: kind,
            slug: slug,
            version: version,
            baseURL: baseURL,
            filePath: "/tmp/\(slug).bin"
        )
    }
}

private struct MockSkillsRepositoryService: NolonSkillsRepositoryServing {
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
        [NolonSkillsDirectoryCandidate(path: "skills", skillCount: 1, skillNames: ["agent-browser"])]
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
        NolonRepositoryResources(
            skillsDirectories: [NolonSkillsDirectoryCandidate(path: "skills", skillCount: 1, skillNames: ["agent-browser"])],
            workflows: [NolonResourceFile(path: "workflows/review.md", kind: "workflow")],
            mcps: [NolonResourceFile(path: "mcp_settings.json", kind: "mcp")]
        )
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
        NolonRemoteDownloadResult(kind: kind, slug: slug, version: version, baseURL: baseURL, filePath: "/tmp/\(slug).bin")
    }
}
