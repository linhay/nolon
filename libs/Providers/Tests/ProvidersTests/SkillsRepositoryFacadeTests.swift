import Foundation
import Testing
import STFilePath
import SKProcessRunner
@testable import ProviderCatalog

@Suite("SkillsRepositoryFacade")
struct SkillsRepositoryFacadeTests {
    private func makeTempRoot(_ prefix: String) throws -> STFolder {
        let root = STFolder("/tmp").folder("\(prefix)-\(UUID().uuidString)")
        _ = root.createIfNotExists()
        return root
    }

    @Test("build git import plan from shorthand with subpath")
    func buildPlanFromShorthand() throws {
        let root = STFolder("/tmp").folder("nolon-repositories")
        let plan = try SkillsRepositoryFacade.planGitImport(
            source: "vercel/agent-skills/skills/react-best-practices",
            repositoriesRoot: root.url
        )

        #expect(plan.normalizedGitURL == "https://github.com/vercel/agent-skills.git")
        #expect(plan.subpath == "skills/react-best-practices")
        #expect(plan.providerHost == "github.com")
        #expect(plan.owner == "vercel")
        #expect(plan.repo == "agent-skills")
        #expect(plan.localClonePath.path == "/tmp/nolon-repositories/github.com/vercel@agent-skills")
    }

    @Test("build git import plan from ssh url")
    func buildPlanFromSSH() throws {
        let root = STFolder("/tmp").folder("nolon-repositories")
        let plan = try SkillsRepositoryFacade.planGitImport(
            source: "git@gitlab.example.com:team/repo.git",
            repositoriesRoot: root.url
        )

        #expect(plan.normalizedGitURL == "git@gitlab.example.com:team/repo.git")
        #expect(plan.subpath == nil)
        #expect(plan.providerHost == "gitlab.example.com")
        #expect(plan.localClonePath.path == "/tmp/nolon-repositories/gitlab.example.com/team@repo")
    }

    @Test("discover skills via facade uses standard name parsing")
    func discoverSkillsViaFacade() throws {
        let root = try makeTempRoot("skills-facade")
        defer { try? root.delete() }

        let skillFolder = root.folder("skills").folder("my-folder-name")
        _ = skillFolder.createIfNotExists()
        let skill = skillFolder.file("SKILL.md")
        try Data(
            """
            ---
            name: from-frontmatter-name
            description: Example.
            ---
            """.utf8
        ).write(to: skill.url)

        let candidates = SkillsRepositoryFacade.discoverSkillsDirectories(at: root.url)
        #expect(candidates.contains { $0.path == "skills" && $0.skillNames == ["from-frontmatter-name"] })
    }

    @Test("normalize and extract URL components via facade")
    func normalizeAndExtractViaFacade() {
        let normalized = SkillsRepositoryFacade.normalizeGitURL("owner/repo/skills/web")
        #expect(normalized == "https://github.com/owner/repo.git")

        let subpath = SkillsRepositoryFacade.extractSubpath(from: "owner/repo/skills/web")
        #expect(subpath == "skills/web")

        let components = SkillsRepositoryFacade.extractURLComponents(from: "git@github.com:owner/repo.git")
        #expect(components?.host == "github.com")
        #expect(components?.owner == "owner")
        #expect(components?.repo == "repo")
    }

    @Test("suggest clone path via facade")
    func suggestedClonePathViaFacade() {
        let root = STFolder("/tmp").folder("nolon-repositories")
        let path = SkillsRepositoryFacade.suggestedClonePath(
            gitURL: "https://github.com/vercel/agent-skills.git",
            repositoriesRoot: root.url
        )
        #expect(path?.path == "/tmp/nolon-repositories/github.com/vercel@agent-skills")
    }

    @Test("sync maps invalid URL to facade sync error")
    func syncMapsInvalidURL() async {
        let localPath = STFolder("/tmp")
            .folder("facade-invalid-\(UUID().uuidString)")
            .url

        do {
            _ = try await SkillsRepositoryFacade.syncGitRepository(
                gitURL: "invalid",
                localClonePath: localPath,
                accessToken: nil
            )
            Issue.record("expected invalidURL error")
        } catch let error as SkillsRepositoryFacade.SyncError {
            #expect(error == .invalidURL)
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("git sync mode exposes facade semantic updated")
    func gitSyncModeUpdatedSemantic() {
        let mode = SkillsRepositoryFacade.GitSyncMode.updated
        #expect(mode == .updated)
    }

    @Test("sync maps token-only strategy without token to accessTokenRequired")
    func syncTokenOnlyRequiresToken() async {
        let localPath = STFolder("/tmp")
            .folder("facade-token-only-\(UUID().uuidString)")
            .url

        do {
            _ = try await SkillsRepositoryFacade.syncGitRepository(
                gitURL: "https://github.com/vercel/agent-skills.git",
                localClonePath: localPath,
                accessToken: nil,
                options: .init(
                    pullStrategy: .ffOnly,
                    credentialStrategy: .tokenOnly
                )
            )
            Issue.record("expected accessTokenRequired error")
        } catch let error as SkillsRepositoryFacade.SyncError {
            #expect(error == .accessTokenRequired)
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("preflight marks token-only without token as requiring access token")
    func preflightTokenOnlyWithoutToken() {
        let result = SkillsRepositoryFacade.preflightSync(
            source: "vercel/agent-skills",
            accessToken: nil,
            options: .init(
                pullStrategy: .ffOnly,
                credentialStrategy: .tokenOnly
            )
        )
        #expect(result.isValidURL == true)
        #expect(result.requiresAccessToken == true)
        #expect(result.credentialMode == .httpsAnonymous)
        #expect(result.issues.contains { $0.code == .accessTokenRequired })
        #expect(result.issues.contains { $0.code == .tokenStrategyRequiresHTTPS } == false)
    }

    @Test("preflight returns invalid url issue")
    func preflightInvalidURLIssue() {
        let result = SkillsRepositoryFacade.preflightSync(
            source: "not-a-valid-url",
            accessToken: nil,
            options: .init(
                pullStrategy: .ffOnly,
                credentialStrategy: .automatic
            )
        )
        #expect(result.isValidURL == false)
        #expect(result.issues.contains { $0.code == .invalidGitURL })
    }

    @Test("parse repository identity from shorthand")
    func parseRepositoryIdentityFromShorthand() {
        let identity = SkillsRepositoryFacade.parseRepositoryIdentity(from: "vercel/agent-skills/skills/react-best-practices")
        #expect(identity?.host == "github.com")
        #expect(identity?.owner == "vercel")
        #expect(identity?.repo == "agent-skills")
        #expect(identity?.repoFullName == "vercel@agent-skills")
        #expect(identity?.provider == .github)
    }

    @Test("parse repository identity from ssh url")
    func parseRepositoryIdentityFromSSH() {
        let identity = SkillsRepositoryFacade.parseRepositoryIdentity(from: "git@gitlab.example.com:team/repo.git")
        #expect(identity?.host == "gitlab.example.com")
        #expect(identity?.owner == "team")
        #expect(identity?.repo == "repo")
        #expect(identity?.repoFullName == "team@repo")
        #expect(identity?.provider == .gitlab)
    }

    @Test("list remote skills maps clawdhub list payload")
    func listRemoteSkills() async throws {
        let payload = """
        {
          "items": [
            {
              "slug": "agent-browser",
              "displayName": "Agent Browser",
              "summary": "Browser automation",
              "updatedAt": 1739366400000,
              "latestVersion": {"version": "1.2.0"},
              "stats": {"downloads": 120, "stars": 15}
            }
          ]
        }
        """
        let base = URL(string: "https://clawdhub.com")!

        let result = try await SkillsRepositoryFacade.listRemoteResources(
            kind: .skill,
            query: nil,
            limit: 20,
            baseURL: base.absoluteString,
            loader: { url in
                #expect(url.absoluteString.contains("/api/v1/skills"))
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (Data(payload.utf8), response)
            }
        )

        #expect(result.kind == .skill)
        #expect(result.items.count == 1)
        #expect(result.items.first?.slug == "agent-browser")
        #expect(result.items.first?.latestVersion == "1.2.0")
        #expect(result.items.first?.downloads == 120)
    }

    @Test("list remote search maps search payload")
    func listRemoteSearch() async throws {
        let payload = """
        {
          "results": [
            {
              "slug": "code-review",
              "displayName": "Code Review",
              "summary": "Review skill",
              "version": "0.9.0",
              "updatedAt": 1739366400000
            }
          ]
        }
        """
        let base = URL(string: "https://clawdhub.com")!

        let result = try await SkillsRepositoryFacade.listRemoteResources(
            kind: .workflow,
            query: "review",
            limit: 10,
            baseURL: base.absoluteString,
            loader: { url in
                #expect(url.absoluteString.contains("/api/v1/search/workflows"))
                #expect(url.absoluteString.contains("q=review"))
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (Data(payload.utf8), response)
            }
        )

        #expect(result.kind == .workflow)
        #expect(result.items.count == 1)
        #expect(result.items.first?.slug == "code-review")
        #expect(result.items.first?.latestVersion == "0.9.0")
    }

    @Test("list remote resources retries with clawhub.ai when clawdhub.com TLS fails")
    func listRemoteResourcesFallbackToClawhubAIOnTLSFailure() async throws {
        let payload = """
        {
          "results": [
            {
              "slug": "gemini",
              "displayName": "Gemini",
              "summary": "Gemini skill",
              "version": "1.0.0",
              "updatedAt": 1739366400000
            }
          ]
        }
        """
        let calledHosts = CalledHostsStore()

        let result = try await SkillsRepositoryFacade.listRemoteResources(
            kind: .skill,
            query: "gemini",
            limit: 20,
            baseURL: "https://clawdhub.com",
            loader: { url in
                let attempt = await calledHosts.append(url.host ?? "")
                if attempt == 1 {
                    throw URLError(.secureConnectionFailed)
                }
                #expect(url.host == "clawhub.ai")
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (Data(payload.utf8), response)
            }
        )

        #expect(await calledHosts.snapshot() == ["clawdhub.com", "clawhub.ai"])
        #expect(result.items.count == 1)
        #expect(result.items.first?.slug == "gemini")
    }

    @Test("download remote skill uses skill endpoint and preserves extension")
    func downloadRemoteSkill() async throws {
        let base = URL(string: "https://clawdhub.com")!
        let tempRoot = try makeTempRoot("facade-download-skill")
        defer { try? tempRoot.delete() }

        let result = try await SkillsRepositoryFacade.downloadRemoteResource(
            kind: .skill,
            slug: "agent-browser",
            version: "1.2.0",
            baseURL: base.absoluteString,
            downloader: { url in
                #expect(url.absoluteString.contains("/api/v1/download"))
                #expect(url.absoluteString.contains("slug=agent-browser"))
                #expect(url.absoluteString.contains("version=1.2.0"))
                let source = tempRoot.file("source.zip").url
                try Data("zip".utf8).write(to: source)
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (source, response)
            },
            temporaryDirectory: tempRoot.url
        )

        #expect(result.lastPathComponent.contains("agent-browser"))
        #expect(result.pathExtension == "zip")
        #expect(STPath(result).isExists)
    }

    @Test("download remote workflow uses workflow endpoint")
    func downloadRemoteWorkflow() async throws {
        let base = URL(string: "https://clawdhub.com")!
        let tempRoot = try makeTempRoot("facade-download-workflow")
        defer { try? tempRoot.delete() }

        let result = try await SkillsRepositoryFacade.downloadRemoteResource(
            kind: .workflow,
            slug: "daily-review",
            version: nil,
            baseURL: base.absoluteString,
            downloader: { url in
                #expect(url.absoluteString.contains("/api/v1/download/workflow"))
                #expect(url.absoluteString.contains("slug=daily-review"))
                #expect(url.absoluteString.contains("tag=latest"))
                let source = tempRoot.file("workflow.md").url
                try Data("# Workflow".utf8).write(to: source)
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (source, response)
            },
            temporaryDirectory: tempRoot.url
        )

        #expect(result.pathExtension == "md")
        #expect(STPath(result).isExists)
    }

    @Test("download remote resource retries with clawhub.ai when clawdhub.com TLS fails")
    func downloadRemoteResourceFallbackToClawhubAIOnTLSFailure() async throws {
        let tempRoot = try makeTempRoot("facade-download-fallback")
        defer { try? tempRoot.delete() }
        let calledHosts = CalledHostsStore()

        let result = try await SkillsRepositoryFacade.downloadRemoteResource(
            kind: .skill,
            slug: "gemini",
            version: "1.0.0",
            baseURL: "https://clawdhub.com",
            downloader: { url in
                let attempt = await calledHosts.append(url.host ?? "")
                if attempt == 1 {
                    throw URLError(.secureConnectionFailed)
                }
                #expect(url.host == "clawhub.ai")
                let source = tempRoot.file("source.zip").url
                try Data("zip".utf8).write(to: source)
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (source, response)
            },
            temporaryDirectory: tempRoot.url
        )

        #expect(await calledHosts.snapshot() == ["clawdhub.com", "clawhub.ai"])
        #expect(result.pathExtension == "zip")
        #expect(STPath(result).isExists)
    }

    @Test("download remote resource throws on non-2xx response")
    func downloadRemoteResourceHTTPError() async throws {
        do {
            _ = try await SkillsRepositoryFacade.downloadRemoteResource(
                kind: .mcp,
                slug: "filesystem",
                version: nil,
                baseURL: "https://clawdhub.com",
                downloader: { url in
                    let folder = STFolder("/tmp")
                        .folder("noop-\(UUID().uuidString)")
                    _ = folder.createIfNotExists()
                    let source = folder.file("noop.bin")
                        .url
                    try Data().write(to: source)
                    let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
                    return (source, response)
                }
            )
            Issue.record("expected commandFailed error")
        } catch let error as SkillsRepositoryFacade.SyncError {
            switch error {
            case let .commandFailed(message):
                #expect(message.contains("404"))
            default:
                Issue.record("unexpected sync error: \(error)")
            }
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("stage remote skill from zip into stable skills root")
    func stageRemoteSkillFromZip() throws {
        let tempRoot = try STFolder(sanbox: .temporary).folder("facade-stage-zip-\(UUID().uuidString)").create()
        defer { try? tempRoot.delete() }

        let skillFolder = try tempRoot.folder("source-skill").create()
        try skillFolder.file("SKILL.md").overlay(
            with: """
            ---
            name: staged-skill
            description: test
            ---
            """)

        let zipPath = tempRoot.file("source.zip")
        var payload = SKProcessPayload.executableURL(URL(fileURLWithPath: "/usr/bin/ditto"))
        payload.arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent", skillFolder.url.path, zipPath.url.path]
        payload.throwOnNonZeroExit = true
        _ = try SKProcessRunner.runSync(payload)

        let skillsRoot = try tempRoot.folder("skills-root").create()
        let staged = try SkillsRepositoryFacade.stageRemoteSkillForInstall(
            downloadedFileURL: zipPath.url,
            slug: "demo-skill",
            skillsRoot: skillsRoot.url
        )

        #expect(staged.lastPathComponent == "demo-skill")
        #expect(STFile(staged.appendingPathComponent("SKILL.md")).isExists)
    }

    @Test("stage remote skill from folder copies into stable skills root")
    func stageRemoteSkillFromFolder() throws {
        let tempRoot = try STFolder(sanbox: .temporary).folder("facade-stage-folder-\(UUID().uuidString)").create()
        defer { try? tempRoot.delete() }

        let sourceRoot = try tempRoot.folder("downloaded-folder").create()
        let nested = try sourceRoot.folder("nested").create()
        try nested.file("SKILL.md").overlay(
            with: """
            ---
            name: staged-folder
            description: test
            ---
            """)

        let skillsRoot = try tempRoot.folder("skills-root").create()
        let staged = try SkillsRepositoryFacade.stageRemoteSkillForInstall(
            downloadedFileURL: sourceRoot.url,
            slug: "folder-skill",
            skillsRoot: skillsRoot.url
        )

        #expect(staged.lastPathComponent == "folder-skill")
        #expect(STFile(staged.appendingPathComponent("SKILL.md")).isExists)
    }

    @Test("bind workflow from skill creates global workflow and provider symlink")
    func bindWorkflowFromSkillCreatesSymlink() throws {
        let root = try makeTempRoot("workflow-bind-skill")
        defer { try? root.delete() }

        let nolonHome = root.folder("nolon-home")
        _ = nolonHome.createIfNotExists()
        let skillRoot = nolonHome.folder("skills").folder("xcode")
        _ = skillRoot.createIfNotExists()
        try Data(
            """
            ---
            name: xcode
            description: Xcode helper skill.
            ---
            """.utf8
        ).write(to: skillRoot.file("SKILL.md").url)

        let providerWorkflow = root.folder("provider-workflows")
        _ = providerWorkflow.createIfNotExists()

        let result = try SkillsRepositoryFacade.bindWorkflowFromSkill(
            skillID: "xcode",
            providerWorkflowPath: providerWorkflow.url,
            nolonHome: nolonHome.url
        )

        #expect(result.source == .skill)
        #expect(result.workflowFileName == "xcode.md")
        #expect(STPath(result.globalWorkflowPath).isExists)
        #expect(STPath(result.providerWorkflowPath).isSymbolicLink)
        let linkedTo = try STPath(result.providerWorkflowPath).destinationOfSymbolicLink().url.path
        #expect(linkedTo == result.globalWorkflowPath)
    }

    @Test("bind workflow from mcp creates global workflow and provider symlink")
    func bindWorkflowFromMcpCreatesSymlink() throws {
        let root = try makeTempRoot("workflow-bind-mcp")
        defer { try? root.delete() }

        let nolonHome = root.folder("nolon-home")
        _ = nolonHome.createIfNotExists()
        let providerWorkflow = root.folder("provider-workflows")
        _ = providerWorkflow.createIfNotExists()

        let result = try SkillsRepositoryFacade.bindWorkflowFromMCP(
            mcpName: "playwright",
            providerWorkflowPath: providerWorkflow.url,
            nolonHome: nolonHome.url
        )

        #expect(result.source == .mcp)
        #expect(result.workflowFileName == "playwright.md")
        #expect(STPath(result.globalWorkflowPath).isExists)
        #expect(STPath(result.providerWorkflowPath).isSymbolicLink)
    }

    @Test("unbind workflow from skill removes provider link")
    func unbindWorkflowFromSkillRemovesProviderLink() throws {
        let root = try makeTempRoot("workflow-unbind-skill")
        defer { try? root.delete() }

        let nolonHome = root.folder("nolon-home")
        _ = nolonHome.createIfNotExists()
        let skillRoot = nolonHome.folder("skills").folder("find-skills")
        _ = skillRoot.createIfNotExists()
        try Data(
            """
            ---
            name: find-skills
            description: Find skills.
            ---
            """.utf8
        ).write(to: skillRoot.file("SKILL.md").url)

        let providerWorkflow = root.folder("provider-workflows")
        _ = providerWorkflow.createIfNotExists()
        _ = try SkillsRepositoryFacade.bindWorkflowFromSkill(
            skillID: "find-skills",
            providerWorkflowPath: providerWorkflow.url,
            nolonHome: nolonHome.url
        )

        let result = try SkillsRepositoryFacade.unbindWorkflowFromSkill(
            skillID: "find-skills",
            providerWorkflowPath: providerWorkflow.url
        )

        #expect(result.source == .skill)
        #expect(result.workflowFileName == "find-skills.md")
        #expect(result.removed == true)
        #expect(STPath(result.providerWorkflowPath).isExists == false)
    }
}

private actor CalledHostsStore {
    private var hosts: [String] = []

    func append(_ host: String) -> Int {
        hosts.append(host)
        return hosts.count
    }

    func snapshot() -> [String] {
        hosts
    }
}
