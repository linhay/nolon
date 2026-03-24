import Foundation
import STFilePath
import Testing
import SKProcessRunner
@testable import ProviderCatalog

@Suite("RemoteGitRepositorySupport")
struct RemoteGitRepositorySupportTests {
    @Test("normalize git URL supports shorthand and strips subpath")
    func normalizeGitURL() {
        #expect(
            RemoteGitRepositorySupport.normalizeGitURL("vercel/agent-skills")
                == "https://github.com/vercel/agent-skills.git"
        )
        #expect(
            RemoteGitRepositorySupport.normalizeGitURL("owner/repo/skills/my-skill")
                == "https://github.com/owner/repo.git"
        )
        #expect(
            RemoteGitRepositorySupport.normalizeGitURL("https://gitlab.com/group/subgroup/project")
                == "https://gitlab.com/group/subgroup/project.git"
        )
    }

    @Test("extract subpath from shorthand and URL")
    func extractSubpath() {
        #expect(RemoteGitRepositorySupport.extractSubpath(from: "owner/repo") == nil)
        #expect(RemoteGitRepositorySupport.extractSubpath(from: "owner/repo/skills/foo") == "skills/foo")
        #expect(
            RemoteGitRepositorySupport.extractSubpath(
                from: "https://github.com/owner/repo/tree/main/skills/foo"
            ) == "skills/foo"
        )
        #expect(
            RemoteGitRepositorySupport.extractSubpath(from: "https://github.com/owner/repo/skills/foo")
                == "skills/foo"
        )
        #expect(
            RemoteGitRepositorySupport.extractSubpath(from: "https://gitlab.com/group/subgroup/project")
                == nil
        )
        #expect(
            RemoteGitRepositorySupport.extractSubpath(from: "https://gitlab.com/group/subgroup/project/-/tree/main/skills/foo")
                == "skills/foo"
        )
        #expect(
            RemoteGitRepositorySupport.extractSubpath(
                from: "https://gitlab.com/group/subgroup/project/-/blob/main/skills/foo/SKILL.md"
            ) == "skills/foo"
        )
    }

    @Test("extract URL components supports ssh and https")
    func extractURLComponents() {
        let https = RemoteGitRepositorySupport.extractURLComponents(from: "https://gitlab.example.com/team/repo.git")
        #expect(https?.host == "gitlab.example.com")
        #expect(https?.owner == "team")
        #expect(https?.repo == "repo")

        let gitlabNested = RemoteGitRepositorySupport.extractURLComponents(
            from: "https://gitlab.example.com/group/subgroup/project.git"
        )
        #expect(gitlabNested?.host == "gitlab.example.com")
        #expect(gitlabNested?.owner == "group/subgroup")
        #expect(gitlabNested?.repo == "project")

        let ssh = RemoteGitRepositorySupport.extractURLComponents(from: "git@github.com:vercel/agent-skills.git")
        #expect(ssh?.host == "github.com")
        #expect(ssh?.owner == "vercel")
        #expect(ssh?.repo == "agent-skills")

        let gitlabNestedSSH = RemoteGitRepositorySupport.extractURLComponents(
            from: "git@gitlab.dxy.net:f2e/axure-helper/axure-skill-group.git"
        )
        #expect(gitlabNestedSSH?.host == "gitlab.dxy.net")
        #expect(gitlabNestedSSH?.owner == "f2e/axure-helper")
        #expect(gitlabNestedSSH?.repo == "axure-skill-group")
    }

    @Test("discover skill directories supports agent-skills style layout")
    func discoverSkillDirectories() throws {
        let root = STFolder("/tmp").folder("remote-git-discovery-\(UUID().uuidString)")
        _ = root.createIfNotExists()
        defer { try? root.delete() }

        let skillAFolder = root.folder("skills/react-best-practices")
        let skillBFolder = root.folder("skills/composition-patterns")
        let nestedSkillFolder = root.folder("skills/claude.ai/vercel-deploy-claimable")
        _ = skillAFolder.createIfNotExists()
        _ = skillBFolder.createIfNotExists()
        _ = nestedSkillFolder.createIfNotExists()

        let skillA = skillAFolder.file("SKILL.md")
        let skillB = skillBFolder.file("SKILL.md")
        let nestedSkill = nestedSkillFolder.file("SKILL.md")
        try Data(
            """
            ---
            name: react-best-practices
            description: React best practices.
            ---
            """.utf8
        ).write(to: skillA.url)
        try Data(
            """
            ---
            name: composition-patterns
            description: Composition patterns.
            ---
            """.utf8
        ).write(to: skillB.url)
        try Data(
            """
            ---
            name: vercel-deploy-claimable
            description: Claimable deployments.
            ---
            """.utf8
        ).write(to: nestedSkill.url)

        let candidates = RemoteGitRepositorySupport.detectSkillsDirectories(at: root.url)

        #expect(candidates.contains { $0.path == "skills" && $0.skillCount == 2 })
        #expect(candidates.contains { $0.path == "skills/claude.ai" && $0.skillCount == 1 })
        #expect(
            candidates.contains {
                $0.path == "skills" && $0.skillNames == ["composition-patterns", "react-best-practices"]
            }
        )
    }

    @Test("discover repository resources includes workflows and mcp files")
    func discoverRepositoryResources() throws {
        let root = STFolder("/tmp").folder("remote-git-resources-\(UUID().uuidString)")
        _ = root.createIfNotExists()
        defer { try? root.delete() }

        let skillFolder = root.folder("skills/agent-browser")
        let workflowFolder = root.folder("workflows")
        let mcpFolder = root.folder("configs")
        _ = skillFolder.createIfNotExists()
        _ = workflowFolder.createIfNotExists()
        _ = mcpFolder.createIfNotExists()

        let skill = skillFolder.file("SKILL.md")
        let workflow = workflowFolder.file("review.md")
        let mcp = mcpFolder.file("mcp_settings.json")

        try Data("---\nname: agent-browser\ndescription: Browser\n---\n".utf8).write(to: skill.url)
        try Data("# Workflow\n".utf8).write(to: workflow.url)
        try Data("{\"mcpServers\":{}}".utf8).write(to: mcp.url)

        let resources = RemoteGitRepositorySupport.detectRepositoryResources(at: root.url)

        #expect(resources.skillsDirectories.contains { $0.path == "skills" && $0.skillCount == 1 })
        #expect(resources.workflows.contains { $0.path == "workflows/review.md" })
        #expect(resources.mcps.contains { $0.path == "configs/mcp_settings.json" })
    }

    @Test("discover skill directories includes hidden .agents layout")
    func discoverSkillsDirectoriesInHiddenAgentsFolder() throws {
        let root = STFolder("/tmp").folder("remote-git-hidden-agents-\(UUID().uuidString)")
        _ = root.createIfNotExists()
        defer { try? root.delete() }

        let hiddenSkillFolder = root.folder(".agents/skills/find-skills")
        _ = hiddenSkillFolder.createIfNotExists()
        let hiddenSkill = hiddenSkillFolder.file("SKILL.md")
        try Data(
            """
            ---
            name: find-skills
            description: Find installable skills.
            ---
            """.utf8
        ).write(to: hiddenSkill.url)

        let candidates = RemoteGitRepositorySupport.detectSkillsDirectories(at: root.url)
        #expect(candidates.contains { $0.path == ".agents/skills" && $0.skillCount == 1 })
    }

    @Test("discover repository resources includes github workflow yaml")
    func discoverRepositoryResourcesInGitHubWorkflowFolder() throws {
        let root = STFolder("/tmp").folder("remote-git-github-workflow-\(UUID().uuidString)")
        _ = root.createIfNotExists()
        defer { try? root.delete() }

        let workflowFolder = root.folder(".github/workflows")
        _ = workflowFolder.createIfNotExists()
        let workflowYAML = workflowFolder.file("ci.yml")
        try Data("name: CI\non: [push]\n".utf8).write(to: workflowYAML.url)

        let resources = RemoteGitRepositorySupport.detectRepositoryResources(at: root.url)
        #expect(resources.workflows.contains { $0.path == ".github/workflows/ci.yml" })
    }

    @Test("sync token-only strategy requires access token")
    func syncTokenOnlyRequiresAccessToken() async {
        let localPath = STFolder("/tmp")
            .folder("remote-git-token-only-\(UUID().uuidString)")
            .url

        do {
            _ = try await RemoteGitRepositorySupport.syncRepository(
                gitURL: "https://github.com/vercel/agent-skills.git",
                localClonePath: localPath,
                accessToken: nil,
                options: .init(
                    pullStrategy: .ffOnly,
                    credentialStrategy: .tokenOnly
                )
            )
            Issue.record("expected accessTokenRequired error")
        } catch let error as RemoteGitRepositorySupport.SyncError {
            #expect(error == .accessTokenRequired)
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("detect default branch from local repository")
    func detectDefaultBranch() throws {
        let root = STFolder("/tmp").folder("remote-git-default-branch-\(UUID().uuidString)")
        _ = root.createIfNotExists()
        defer { try? root.delete() }

        let run: ([String]) throws -> Void = { args in
            var payload = SKProcessPayload.executableURL(URL(fileURLWithPath: "/usr/bin/git"))
            payload.arguments = args
            payload.throwOnNonZeroExit = true
            _ = try SKProcessRunner.runSync(payload)
        }

        try run(["-C", root.url.path, "init", "--initial-branch", "main"])
        try run(["-C", root.url.path, "config", "user.name", "test"])
        try run(["-C", root.url.path, "config", "user.email", "test@example.com"])
        try "hello".write(to: root.file("README.md").url, atomically: true, encoding: .utf8)
        try run(["-C", root.url.path, "add", "."])
        try run(["-C", root.url.path, "commit", "-m", "init"])

        let branch = RemoteGitRepositorySupport.detectDefaultBranch(at: root.url)
        #expect(branch == "main")
    }
}
