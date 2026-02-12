import Foundation
import Testing
@testable import ProviderCatalog

@Suite("SkillsRepositoryFacade")
struct SkillsRepositoryFacadeTests {
    @Test("build git import plan from shorthand with subpath")
    func buildPlanFromShorthand() throws {
        let root = URL(fileURLWithPath: "/tmp/nolon-repositories", isDirectory: true)
        let plan = try SkillsRepositoryFacade.planGitImport(
            source: "vercel/agent-skills/skills/react-best-practices",
            repositoriesRoot: root
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
        let root = URL(fileURLWithPath: "/tmp/nolon-repositories", isDirectory: true)
        let plan = try SkillsRepositoryFacade.planGitImport(
            source: "git@gitlab.example.com:team/repo.git",
            repositoriesRoot: root
        )

        #expect(plan.normalizedGitURL == "git@gitlab.example.com:team/repo.git")
        #expect(plan.subpath == nil)
        #expect(plan.providerHost == "gitlab.example.com")
        #expect(plan.localClonePath.path == "/tmp/nolon-repositories/gitlab.example.com/team@repo")
    }

    @Test("discover skills via facade uses standard name parsing")
    func discoverSkillsViaFacade() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("skills-facade-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let skill = root.appendingPathComponent("skills/my-folder-name/SKILL.md")
        try FileManager.default.createDirectory(at: skill.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(
            """
            ---
            name: from-frontmatter-name
            description: Example.
            ---
            """.utf8
        ).write(to: skill)

        let candidates = SkillsRepositoryFacade.discoverSkillsDirectories(at: root)
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
        let root = URL(fileURLWithPath: "/tmp/nolon-repositories", isDirectory: true)
        let path = SkillsRepositoryFacade.suggestedClonePath(
            gitURL: "https://github.com/vercel/agent-skills.git",
            repositoriesRoot: root
        )
        #expect(path?.path == "/tmp/nolon-repositories/github.com/vercel@agent-skills")
    }

    @Test("sync maps invalid URL to facade sync error")
    func syncMapsInvalidURL() async {
        let localPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("facade-invalid-\(UUID().uuidString)", isDirectory: true)

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
        let localPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("facade-token-only-\(UUID().uuidString)", isDirectory: true)

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

    @Test("download remote skill uses skill endpoint and preserves extension")
    func downloadRemoteSkill() async throws {
        let base = URL(string: "https://clawdhub.com")!
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("facade-download-skill-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let result = try await SkillsRepositoryFacade.downloadRemoteResource(
            kind: .skill,
            slug: "agent-browser",
            version: "1.2.0",
            baseURL: base.absoluteString,
            downloader: { url in
                #expect(url.absoluteString.contains("/api/v1/download"))
                #expect(url.absoluteString.contains("slug=agent-browser"))
                #expect(url.absoluteString.contains("version=1.2.0"))
                let source = tempRoot.appendingPathComponent("source.zip")
                try Data("zip".utf8).write(to: source)
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (source, response)
            },
            temporaryDirectory: tempRoot
        )

        #expect(result.lastPathComponent.contains("agent-browser"))
        #expect(result.pathExtension == "zip")
        #expect(FileManager.default.fileExists(atPath: result.path))
    }

    @Test("download remote workflow uses workflow endpoint")
    func downloadRemoteWorkflow() async throws {
        let base = URL(string: "https://clawdhub.com")!
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("facade-download-workflow-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let result = try await SkillsRepositoryFacade.downloadRemoteResource(
            kind: .workflow,
            slug: "daily-review",
            version: nil,
            baseURL: base.absoluteString,
            downloader: { url in
                #expect(url.absoluteString.contains("/api/v1/download/workflow"))
                #expect(url.absoluteString.contains("slug=daily-review"))
                #expect(url.absoluteString.contains("tag=latest"))
                let source = tempRoot.appendingPathComponent("workflow.md")
                try Data("# Workflow".utf8).write(to: source)
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (source, response)
            },
            temporaryDirectory: tempRoot
        )

        #expect(result.pathExtension == "md")
        #expect(FileManager.default.fileExists(atPath: result.path))
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
                    let source = FileManager.default.temporaryDirectory
                        .appendingPathComponent("noop-\(UUID().uuidString)")
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
}
