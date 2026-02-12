import Foundation
import Testing
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
            RemoteGitRepositorySupport.normalizeGitURL("https://gitlab.com/owner/repo/sub/path")
                == "https://gitlab.com/owner/repo.git"
        )
    }

    @Test("extract subpath from shorthand and URL")
    func extractSubpath() {
        #expect(RemoteGitRepositorySupport.extractSubpath(from: "owner/repo") == nil)
        #expect(RemoteGitRepositorySupport.extractSubpath(from: "owner/repo/skills/foo") == "skills/foo")
        #expect(
            RemoteGitRepositorySupport.extractSubpath(from: "https://github.com/owner/repo/skills/foo")
                == "skills/foo"
        )
    }

    @Test("extract URL components supports ssh and https")
    func extractURLComponents() {
        let https = RemoteGitRepositorySupport.extractURLComponents(from: "https://gitlab.example.com/team/repo.git")
        #expect(https?.host == "gitlab.example.com")
        #expect(https?.owner == "team")
        #expect(https?.repo == "repo")

        let ssh = RemoteGitRepositorySupport.extractURLComponents(from: "git@github.com:vercel/agent-skills.git")
        #expect(ssh?.host == "github.com")
        #expect(ssh?.owner == "vercel")
        #expect(ssh?.repo == "agent-skills")
    }

    @Test("discover skill directories supports agent-skills style layout")
    func discoverSkillDirectories() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("remote-git-discovery-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let skillA = root.appendingPathComponent("skills/react-best-practices/SKILL.md")
        let skillB = root.appendingPathComponent("skills/composition-patterns/SKILL.md")
        let nestedSkill = root.appendingPathComponent("skills/claude.ai/vercel-deploy-claimable/SKILL.md")

        try FileManager.default.createDirectory(at: skillA.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: skillB.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: nestedSkill.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(
            """
            ---
            name: react-best-practices
            description: React best practices.
            ---
            """.utf8
        ).write(to: skillA)
        try Data(
            """
            ---
            name: composition-patterns
            description: Composition patterns.
            ---
            """.utf8
        ).write(to: skillB)
        try Data(
            """
            ---
            name: vercel-deploy-claimable
            description: Claimable deployments.
            ---
            """.utf8
        ).write(to: nestedSkill)

        let candidates = RemoteGitRepositorySupport.detectSkillsDirectories(at: root)

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
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("remote-git-resources-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let skill = root.appendingPathComponent("skills/agent-browser/SKILL.md")
        let workflow = root.appendingPathComponent("workflows/review.md")
        let mcp = root.appendingPathComponent("configs/mcp_settings.json")

        try FileManager.default.createDirectory(at: skill.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: workflow.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: mcp.deletingLastPathComponent(), withIntermediateDirectories: true)

        try Data("---\nname: agent-browser\ndescription: Browser\n---\n".utf8).write(to: skill)
        try Data("# Workflow\n".utf8).write(to: workflow)
        try Data("{\"mcpServers\":{}}".utf8).write(to: mcp)

        let resources = RemoteGitRepositorySupport.detectRepositoryResources(at: root)

        #expect(resources.skillsDirectories.contains { $0.path == "skills" && $0.skillCount == 1 })
        #expect(resources.workflows.contains { $0.path == "workflows/review.md" })
        #expect(resources.mcps.contains { $0.path == "configs/mcp_settings.json" })
    }

    @Test("discover skill directories includes hidden .agents layout")
    func discoverSkillsDirectoriesInHiddenAgentsFolder() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("remote-git-hidden-agents-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let hiddenSkill = root.appendingPathComponent(".agents/skills/find-skills/SKILL.md")
        try FileManager.default.createDirectory(
            at: hiddenSkill.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(
            """
            ---
            name: find-skills
            description: Find installable skills.
            ---
            """.utf8
        ).write(to: hiddenSkill)

        let candidates = RemoteGitRepositorySupport.detectSkillsDirectories(at: root)
        #expect(candidates.contains { $0.path == ".agents/skills" && $0.skillCount == 1 })
    }

    @Test("discover repository resources includes github workflow yaml")
    func discoverRepositoryResourcesInGitHubWorkflowFolder() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("remote-git-github-workflow-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let workflowYAML = root.appendingPathComponent(".github/workflows/ci.yml")
        try FileManager.default.createDirectory(
            at: workflowYAML.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("name: CI\non: [push]\n".utf8).write(to: workflowYAML)

        let resources = RemoteGitRepositorySupport.detectRepositoryResources(at: root)
        #expect(resources.workflows.contains { $0.path == ".github/workflows/ci.yml" })
    }

    @Test("sync token-only strategy requires access token")
    func syncTokenOnlyRequiresAccessToken() async {
        let localPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("remote-git-token-only-\(UUID().uuidString)", isDirectory: true)

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
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("remote-git-default-branch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let run: ([String]) throws -> Void = { args in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = args
            let stderr = Pipe()
            process.standardError = stderr
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus != 0 {
                let data = stderr.fileHandleForReading.readDataToEndOfFile()
                let message = String(data: data, encoding: .utf8) ?? "unknown"
                throw NSError(domain: "git", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: message])
            }
        }

        try run(["-C", root.path, "init", "--initial-branch", "main"])
        try run(["-C", root.path, "config", "user.name", "test"])
        try run(["-C", root.path, "config", "user.email", "test@example.com"])
        try "hello".write(to: root.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        try run(["-C", root.path, "add", "."])
        try run(["-C", root.path, "commit", "-m", "init"])

        let branch = RemoteGitRepositorySupport.detectDefaultBranch(at: root)
        #expect(branch == "main")
    }
}
