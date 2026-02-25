import Foundation
import STFilePath
import Testing
@testable import NolonResourceKit
import ProviderCatalog

@Suite("NolonResourceKit", .serialized)
struct NolonResourceKitTests {
    @Test("NolonManager respects NOLON_HOME environment")
    func nolonManagerUsesEnvironment() throws {
        let tempRoot = try STFolder(sanbox: .temporary)
            .folder("nolon-home-test-\(UUID().uuidString)")
            .create()
        defer { try? tempRoot.deleteIncludingBrokenSymlink() }

        let manager = NolonManager(
            rootURL: nil,
            environment: ["NOLON_HOME": tempRoot.url.path],
            userHomeURL: tempRoot.url.deletingLastPathComponent()
        )

        #expect(manager.rootURL.standardizedFileURL.path == tempRoot.url.standardizedFileURL.path)
        #expect(STFolder(manager.skillsURL).isExists)
        #expect(STFolder(manager.mcpsURL).isExists)
        #expect(STFolder(manager.repositoriesURL).isExists)
    }

    @Test("NolonManager exposes STPath views while keeping URL compatibility")
    func nolonManagerExposesPathViews() throws {
        let root = STFolder("/tmp").folder("nolon-manager-view-\(UUID().uuidString)")
        _ = root.createIfNotExists()
        defer { try? root.deleteIncludingBrokenSymlink() }

        let manager = NolonManager(rootURL: root.url)

        #expect(manager.rootFolder.url.standardizedFileURL.path == manager.rootURL.standardizedFileURL.path)
        #expect(manager.skillsFolder.url.standardizedFileURL.path == manager.skillsURL.standardizedFileURL.path)
        #expect(manager.repositoriesFolder.url.standardizedFileURL.path == manager.repositoriesURL.standardizedFileURL.path)
        #expect(manager.providersConfigFile.url.standardizedFileURL.path == manager.providersConfigURL.standardizedFileURL.path)
    }

    @Test("Provider codex paths expose STPath views while keeping URL compatibility")
    func providerCodexPathViews() {
        let provider = Provider(
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-home/skills",
            workflowPath: "/tmp/codex-home/prompts"
        )

        #expect(provider.codexHomeFolder.url.standardizedFileURL.path == "/tmp/codex-home")
        #expect(provider.codexRulesFolder.url.standardizedFileURL.path == "/tmp/codex-home/rules")
        #expect(provider.codexDefaultRulesFile.url.standardizedFileURL.path == "/tmp/codex-home/rules/default.rules")
        #expect(provider.codexAgentsFile.url.standardizedFileURL.path == "/tmp/codex-home/AGENTS.md")
        #expect(provider.codexAgentsOverrideFile.url.standardizedFileURL.path == "/tmp/codex-home/AGENTS.override.md")

        #expect(provider.codexHomeURL.standardizedFileURL.path == provider.codexHomeFolder.url.standardizedFileURL.path)
        #expect(provider.codexRulesURL.standardizedFileURL.path == provider.codexRulesFolder.url.standardizedFileURL.path)
        #expect(provider.codexDefaultRulesFileURL.standardizedFileURL.path == provider.codexDefaultRulesFile.url.standardizedFileURL.path)
        #expect(provider.codexAgentsFileURL.standardizedFileURL.path == provider.codexAgentsFile.url.standardizedFileURL.path)
        #expect(provider.codexAgentsOverrideFileURL.standardizedFileURL.path == provider.codexAgentsOverrideFile.url.standardizedFileURL.path)
    }

    @Test("RemoteRepository local clone exposes STFolder view while keeping URL compatibility")
    func remoteRepositoryLocalClonePathViews() {
        let repo = RemoteRepository(
            name: "local",
            templateType: .localFolder,
            localPath: "/tmp/nolon-local-repo"
        )

        #expect(repo.localClonePath.standardizedFileURL.path == "/tmp/nolon-local-repo")
        #expect(repo.localCloneFolder.url.standardizedFileURL.path == repo.localClonePath.standardizedFileURL.path)
    }

    @Test("MCPConfigManager codex upsert/list/set-enabled/remove")
    func mcpConfigManagerCodexCRUD() throws {
        let root = try STFolder(sanbox: .temporary)
            .folder("nolon-mcp-codex-\(UUID().uuidString)")
            .create()
        defer { try? root.deleteIncludingBrokenSymlink() }

        let previousHome = getenv("HOME").map { String(cString: $0) }
        setenv("HOME", root.url.path, 1)
        defer {
            if let previousHome {
                setenv("HOME", previousHome, 1)
            }
        }

        let serverName = "playwright-\(UUID().uuidString.prefix(8))"
        defer { try? MCPConfigManager.removeServer(for: .codex, name: serverName) }

        try MCPConfigManager.upsertServer(
            for: .codex,
            name: serverName,
            serverConfig: [
                "command": "npx",
                "args": ["@playwright/mcp@latest"],
                "enabled": true,
            ]
        )

        var servers = try MCPConfigManager.listServers(for: .codex).filter { $0.name == serverName }
        #expect(servers.count == 1)
        #expect(servers.first?.name == serverName)
        #expect(servers.first?.isEnabled == true)

        try MCPConfigManager.setEnabled(for: .codex, name: serverName, enabled: false)
        servers = try MCPConfigManager.listServers(for: .codex).filter { $0.name == serverName }
        #expect(servers.first?.isEnabled == false)

        try MCPConfigManager.removeServer(for: .codex, name: serverName)
        servers = try MCPConfigManager.listServers(for: .codex).filter { $0.name == serverName }
        #expect(servers.isEmpty)
    }

    @Test("MCPConfigManager cache migrate and status")
    func mcpConfigManagerCacheMigrateAndStatus() throws {
        let root = try STFolder(sanbox: .temporary)
            .folder("nolon-mcp-cache-\(UUID().uuidString)")
            .create()
        defer { try? root.deleteIncludingBrokenSymlink() }

        let previousHome = getenv("HOME").map { String(cString: $0) }
        let previousNolonHome = getenv("NOLON_HOME").map { String(cString: $0) }
        setenv("HOME", root.url.path, 1)
        setenv("NOLON_HOME", root.folder(".nolon").url.path, 1)
        defer {
            if let previousHome {
                setenv("HOME", previousHome, 1)
            }
            if let previousNolonHome {
                setenv("NOLON_HOME", previousNolonHome, 1)
            } else {
                unsetenv("NOLON_HOME")
            }
        }

        let serverName = "xcode-\(UUID().uuidString.prefix(8))"
        defer { try? MCPConfigManager.removeServer(for: .codex, name: serverName) }

        try MCPConfigManager.upsertServer(
            for: .codex,
            name: serverName,
            serverConfig: [
                "command": "xcode-mcp-proxy",
                "enabled": true,
            ]
        )

        let migrate = try MCPConfigManager.migrateServersToGlobalCache(for: .codex, overwrite: true)
        #expect(migrate.migrated + migrate.updated >= 1)

        let status = try MCPConfigManager.cacheStatus(for: .codex, name: serverName)
        #expect(status.count == 1)
        #expect(status.first?.name == serverName)
        #expect(status.first?.state == .migratedUpToDate)
        let cachePath = status.first?.cachePath ?? ""
        #expect(STFile(cachePath).isExists == true)
    }

    @Test("WorkflowSourceResolver resolves relative symlink destination against link directory")
    func workflowSourceResolverResolvesRelativeSymlinkDestination() {
        let linkPath = "/tmp/providers/codex/prompts/find-skills.md"
        let destination = "../../.nolon/workflows/find-skills.md"
        let resolved = WorkflowSourceResolver.resolveSymlinkDestination(
            linkPath: linkPath,
            destination: destination
        )
        #expect(resolved == "/tmp/providers/.nolon/workflows/find-skills.md")
    }

    @Test("WorkflowSourceResolver classifies workflow source by resolved path")
    func workflowSourceResolverClassifiesByResolvedPath() throws {
        let root = try STFolder(sanbox: .temporary)
            .folder("nolon-workflow-source-\(UUID().uuidString)")
            .create()
        defer { try? root.deleteIncludingBrokenSymlink() }

        let manager = NolonManager(rootURL: root.url)
        let providerWorkflow = root.folder("providers").folder("codex").folder("prompts").subpath("a.md").url.path

        let skillResolved = root.folder("skills-workflows").subpath("a.md").url.path
        let mcpResolved = root.folder("mcps-workflows").subpath("a.md").url.path
        let userResolved = root.folder("workflows").subpath("a.md").url.path

        #expect(
            WorkflowSourceResolver.resolve(
                workflowPath: providerWorkflow,
                resolvedPath: skillResolved,
                nolonManager: manager
            ) == .skill
        )
        #expect(
            WorkflowSourceResolver.resolve(
                workflowPath: providerWorkflow,
                resolvedPath: mcpResolved,
                nolonManager: manager
            ) == .mcp
        )
        #expect(
            WorkflowSourceResolver.resolve(
                workflowPath: providerWorkflow,
                resolvedPath: userResolved,
                nolonManager: manager
            ) == .user
        )
        #expect(
            WorkflowSourceResolver.resolve(
                workflowPath: providerWorkflow,
                resolvedPath: "/opt/other/a.md",
                nolonManager: manager
            ) == .unknown
        )
    }
}
