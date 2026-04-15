import Foundation
import STFilePath
import Testing
import TOML
@testable import NolonResourceKit
import ProviderCatalog
import CodexProvider

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

        #expect(provider.codexRulesURL.standardizedFileURL.path == provider.codexRulesFolder.url.standardizedFileURL.path)
        #expect(provider.codexAgentsFileURL.standardizedFileURL.path == provider.codexAgentsFile.url.standardizedFileURL.path)
    }

    @Test("Provider claude paths expose instruction doc path while keeping URL compatibility")
    func providerClaudePathViews() {
        let provider = Provider(
            kind: .vendor,
            name: "Claude Code",
            defaultSkillsPath: "/tmp/.claude/skills",
            workflowPath: "/tmp/.claude/workflows",
            templateId: ProviderTemplate.claudeCode.rawValue
        )

        #expect(provider.claudeHomeFolder.url.standardizedFileURL.path == "/tmp/.claude")
        #expect(provider.claudeInstructionsFile.url.standardizedFileURL.path == "/tmp/.claude/CLAUDE.md")
        #expect(provider.claudeInstructionsFileURL.standardizedFileURL.path == provider.claudeInstructionsFile.url.standardizedFileURL.path)
    }

    @Test("ProviderTemplate default paths respect current HOME environment")
    func providerTemplateDefaultPathsRespectCurrentHomeEnvironment() throws {
        let root = try STFolder(sanbox: .temporary)
            .folder("provider-template-home-\(UUID().uuidString)")
            .create()
        defer { try? root.deleteIncludingBrokenSymlink() }

        let previousHome = getenv("HOME").map { String(cString: $0) }
        setenv("HOME", root.url.path, 1)
        defer {
            if let previousHome {
                setenv("HOME", previousHome, 1)
            }
        }

        #expect(ProviderTemplate.codex.defaultSkillsPath.standardizedFileURL.path == root.folder(".codex").folder("skills").url.standardizedFileURL.path)
        #expect(ProviderTemplate.codex.defaultMcpConfigPath.standardizedFileURL.path == root.folder(".codex").file("config.toml").url.standardizedFileURL.path)
        #expect(ProviderTemplate.copilot.defaultMcpConfigPath.standardizedFileURL.path == root.folder(".copilot").file("mcp_settings.json").url.standardizedFileURL.path)
    }

    @Test("CodexModelPreferenceService merges visible model slugs and reads config")
    func codexModelPreferenceServiceLoadsModelsAndConfig() throws {
        let root = try STFolder(sanbox: .temporary)
            .folder("nolon-codex-pref-load-\(UUID().uuidString)")
            .create()
        defer { try? root.deleteIncludingBrokenSymlink() }

        let providerHome = root.folder("provider-codex")
        let providerSkills = providerHome.folder("skills")
        _ = providerSkills.createIfNotExists()
        let userCodex = root.folder(".codex")
        _ = userCodex.createIfNotExists()

        let provider = Provider(
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: providerSkills.url.path,
            workflowPath: providerHome.folder("prompts").url.path,
            templateId: "codex"
        )

        let providerCache = providerHome.file("models_cache.json")
        try """
        {
          "fetched_at": "2026-02-25T12:00:00Z",
          "models": [
            { "slug": "gpt-5-codex", "display_name": "GPT-5 Codex", "visibility": "list" },
            { "slug": "hidden-model", "display_name": "Hidden", "visibility": "hide" }
          ]
        }
        """.write(to: providerCache.url, atomically: true, encoding: .utf8)

        let userCache = userCodex.file("models_cache.json")
        try """
        {
          "fetched_at": "2026-02-25T12:01:00Z",
          "models": [
            { "slug": "gpt-5-codex", "display_name": "GPT-5 Codex", "visibility": "list" },
            { "slug": "gpt-5-mini", "display_name": "GPT-5 Mini", "visibility": "list" }
          ]
        }
        """.write(to: userCache.url, atomically: true, encoding: .utf8)

        try """
        model = "gpt-5-codex"
        model_reasoning_effort = "high"
        """.write(to: providerHome.file("config.toml").url, atomically: true, encoding: .utf8)

        let previousHome = getenv("HOME").map { String(cString: $0) }
        setenv("HOME", root.url.path, 1)
        defer {
            if let previousHome {
                setenv("HOME", previousHome, 1)
            }
        }

        let service = CodexModelPreferenceService(homeDirectoryPath: { root.url.path })
        let snapshot = service.loadModelsCache(for: provider)
        #expect(snapshot.sourcePath == providerCache.url.path)
        #expect(snapshot.models.count == 2)
        #expect(service.loadVisibleModelSlugs(for: provider) == ["gpt-5-codex", "gpt-5-mini"])
        #expect(service.loadConfiguredModel(for: provider) == "gpt-5-codex")
        #expect(service.loadConfiguredReasoningEffort(for: provider) == "high")
    }

    @Test("CodexModelPreferenceService saves and clears configured model")
    func codexModelPreferenceServiceSavesConfiguredModel() async throws {
        let root = try STFolder(sanbox: .temporary)
            .folder("nolon-codex-pref-save-\(UUID().uuidString)")
            .create()
        defer { try? root.deleteIncludingBrokenSymlink() }

        let providerHome = root.folder("provider-codex")
        let providerSkills = providerHome.folder("skills")
        _ = providerSkills.createIfNotExists()
        let provider = Provider(
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: providerSkills.url.path,
            workflowPath: providerHome.folder("prompts").url.path,
            templateId: "codex"
        )

        let manager = CodexBinaryManager(
            homeURL: root.url,
            nolonHomeURL: root.folder(".nolon").url
        )
        let service = CodexModelPreferenceService(homeDirectoryPath: { root.url.path })

        let saved = try await service.saveSelectedModel("  gpt-5.3-codex  ", for: provider, manager: manager)
        #expect(saved == "gpt-5.3-codex")
        #expect(service.loadConfiguredModel(for: provider) == "gpt-5.3-codex")

        let cleared = try await service.saveSelectedModel(nil, for: provider, manager: manager)
        #expect(cleared == nil)
        #expect(service.loadConfiguredModel(for: provider) == nil)
    }

    @Test("RemoteRepository local clone exposes STFolder view while keeping URL compatibility")
    func remoteRepositoryLocalClonePathViews() {
        let repo = RemoteRepository(
            name: "local",
            templateType: .localFolder,
            localPath: "/tmp/nolon-local-repo"
        )

        #expect(repo.localClonePath.standardizedFileURL.path == "/tmp/nolon-local-repo")
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

    @Test("MCPConfigManager honors current NOLON_HOME even after shared manager was initialized")
    func mcpConfigManagerUsesCurrentEnvironmentAfterSharedWarmup() throws {
        _ = NolonManager.shared

        let root = try STFolder(sanbox: .temporary)
            .folder("nolon-mcp-env-\(UUID().uuidString)")
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

        let serverName = "env-\(UUID().uuidString.prefix(8))"
        defer { try? MCPConfigManager.removeServer(for: .codex, name: serverName) }

        try MCPConfigManager.upsertServer(
            for: .codex,
            name: serverName,
            serverConfig: [
                "command": "npx",
                "args": ["@acme/env-mcp"],
                "enabled": true,
            ]
        )

        let manager = NolonManager()
        let cachePath = manager.mcpsURL.appendingPathComponent("\(serverName).json")
        #expect(STFile(cachePath).isExists)
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
        #expect(migrate.migrated + migrate.updated >= 0)

        let status = try MCPConfigManager.cacheStatus(for: .codex, name: serverName)
        #expect(status.count == 1)
        #expect(status.first?.name == serverName)
        #expect(status.first?.state == .migratedUpToDate)
        let cachePath = status.first?.cachePath ?? ""
        #expect(STFile(cachePath).isExists == true)
    }

    @Test("ProviderMCPMaintenanceService provides snapshot and single-cache update")
    func providerMcpMaintenanceServiceSnapshotAndSingleCacheUpdate() throws {
        let root = try STFolder(sanbox: .temporary)
            .folder("nolon-provider-mcp-maint-\(UUID().uuidString)")
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

        let service = ProviderMCPMaintenanceService()
        let serverName = "uiagent-\(UUID().uuidString.prefix(8))"
        defer { try? service.removeServer(template: .codex, name: serverName) }

        try service.upsertServer(
            template: .codex,
            name: serverName,
            serverConfig: [
                "command": "npx",
                "args": ["@uiagent/mcp@latest"],
                "enabled": true,
            ]
        )

        var snapshot = try service.listSnapshot(template: .codex)
        let mcp = try #require(snapshot.mcps.first(where: { $0.name == serverName }))
        #expect(snapshot.cacheStates[serverName] == .migratedUpToDate)

        try service.migrateMcpToGlobalCache(mcp)
        snapshot = try service.listSnapshot(template: .codex)
        #expect(snapshot.cacheStates[serverName] == .migratedUpToDate)

        try service.setEnabled(template: .codex, name: serverName, enabled: false)
        snapshot = try service.listSnapshot(template: .codex)
        #expect(snapshot.cacheStates[serverName] == .migratedUpToDate)
        let toggled = try #require(snapshot.mcps.first(where: { $0.name == serverName }))

        try service.updateCachedMcpIfNeeded(toggled)
        snapshot = try service.listSnapshot(template: .codex)
        #expect(snapshot.cacheStates[serverName] == .migratedUpToDate)
    }

    @Test("MCP fragments are source of truth and projected back to provider native config")
    func mcpFragmentsAuthoritativeAndProjectedToProviderConfig() throws {
        let root = try STFolder(sanbox: .temporary)
            .folder("nolon-mcp-fragment-source-\(UUID().uuidString)")
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

        let providerConfigPath = ProviderTemplate.codex.defaultMcpConfigPath
        _ = STFolder(providerConfigPath.deletingLastPathComponent()).createIfNotExists()
        try """
        [mcp_servers.playwright]
        command = "provider-cmd"
        args = ["from-provider"]
        enabled = true
        """.write(to: providerConfigPath, atomically: true, encoding: .utf8)

        let manager = NolonManager()
        _ = manager.mcpsFolder.createIfNotExists()
        let fragmentPath = manager.mcpsURL.appendingPathComponent("playwright.json")
        let fragment: [String: Any] = [
            "mcpServers": [
                "playwright": [
                    "command": "cache-cmd",
                    "args": ["from-cache"],
                    "enabled": true,
                    "http_headers": ["x-token": "abc"]
                ]
            ],
            "x-nolon": ["providers": ["codex"]]
        ]
        let fragmentData = try JSONSerialization.data(withJSONObject: fragment, options: [.prettyPrinted, .sortedKeys])
        try fragmentData.write(to: fragmentPath, options: .atomic)

        let servers = try MCPConfigManager.listServers(for: .codex)
        let playwright = try #require(servers.first(where: { $0.name == "playwright" }))
        #expect(playwright.command == "cache-cmd")
        #expect(playwright.args == ["from-cache"])

        _ = try MCPConfigManager.syncAllCacheServersToProvider(for: .codex)
        let projected = try Data(contentsOf: providerConfigPath)
        let projectedConfig = try TOMLDecoder().decode(CodexMCPConfig.self, from: projected)
        let projectedServer = try #require(projectedConfig.mcpServers?["playwright"])
        #expect(projectedServer.command == "cache-cmd")
        #expect(projectedServer.args == ["from-cache"])
        #expect(projectedServer.httpHeaders?["x-token"] == nil)
    }

    @Test("Provider resource snapshot does not rewrite native MCP config when provider MCP link is disabled")
    func providerResourceSnapshotDoesNotProjectUnlinkedMcpCache() throws {
        let root = try STFolder(sanbox: .temporary)
            .folder("nolon-mcp-unlinked-snapshot-\(UUID().uuidString)")
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

        let manager = NolonManager()
        _ = manager.mcpsFolder.createIfNotExists()
        let fragmentPath = manager.mcpsURL.appendingPathComponent("playwright.json")
        let fragment: [String: Any] = [
            "mcpServers": [
                "playwright": [
                    "command": "npx",
                    "args": ["@playwright/mcp@latest"],
                    "enabled": true
                ]
            ]
        ]
        let fragmentData = try JSONSerialization.data(withJSONObject: fragment, options: [.prettyPrinted, .sortedKeys])
        try fragmentData.write(to: fragmentPath, options: .atomic)

        let providerRoot = root.folder("provider")
        let provider = Provider(
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: providerRoot.folder("skills").url.path,
            workflowPath: providerRoot.folder("prompts").url.path,
            mcpLinkEnabled: false,
            templateId: ProviderTemplate.codex.rawValue
        )

        let configPath = ProviderTemplate.codex.defaultMcpConfigPath
        #expect(STFile(configPath).isExists == false)

        let snapshot = ProviderResourceSnapshotService().load(provider: provider)

        #expect(snapshot.mcps.contains(where: { $0.name == "playwright" }))
        #expect(STFile(configPath).isExists == false)
    }

    @Test("Copilot provider keeps native servers key while syncing with fragments")
    func copilotKeepsNativeServersKeyWhileSyncing() throws {
        let root = try STFolder(sanbox: .temporary)
            .folder("nolon-mcp-copilot-servers-\(UUID().uuidString)")
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

        let configPath = ProviderTemplate.copilot.defaultMcpConfigPath
        _ = STFolder(configPath.deletingLastPathComponent()).createIfNotExists()
        try """
        {
          "servers": {
            "serverA": {
              "command": "node",
              "args": ["a.js"],
              "enabled": true
            }
          },
          "workspace": "test"
        }
        """.write(to: configPath, atomically: true, encoding: .utf8)

        _ = try MCPConfigManager.listServers(for: .copilot)
        try MCPConfigManager.upsertServer(
            for: .copilot,
            name: "serverB",
            serverConfig: [
                "command": "node",
                "args": ["b.js"],
                "enabled": true
            ]
        )

        let rootJSON = try JSONSerialization.jsonObject(with: Data(contentsOf: configPath)) as? [String: Any]
        let servers = rootJSON?["servers"] as? [String: Any]
        #expect(servers?["serverA"] != nil)
        #expect(servers?["serverB"] != nil)
        #expect(rootJSON?["mcpServers"] == nil)
        #expect(rootJSON?["workspace"] as? String == "test")
    }

    @Test("Codex private MCP fields persist through fragment sync")
    func codexPrivateMcpFieldsPersistThroughFragmentSync() throws {
        let root = try STFolder(sanbox: .temporary)
            .folder("nolon-mcp-private-fields-\(UUID().uuidString)")
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

        let name = "private-\(UUID().uuidString.prefix(8))"
        defer { try? MCPConfigManager.removeServer(for: .codex, name: name) }

        try MCPConfigManager.upsertServer(
            for: .codex,
            name: name,
            serverConfig: [
                "url": "https://example.com/mcp",
                "type": "http",
                "enabled": true,
                "enabled_tools": ["search", "open"],
                "http_headers": ["authorization": "Bearer token"],
                "oauth_resource": "https://example.com/mcp",
                "startup_timeout_sec": 25
            ]
        )

        let configPath = ProviderTemplate.codex.defaultMcpConfigPath
        let configData = try Data(contentsOf: configPath)
        let config = try TOMLDecoder().decode(CodexMCPConfig.self, from: configData)
        let server = try #require(config.mcpServers?[name])
        #expect(server.enabledTools == ["search", "open"])
        #expect(server.httpHeaders?["authorization"] == "Bearer token")
        #expect(server.url == "https://example.com/mcp")
        #expect(server.type == nil)
        #expect(server.oauthResource == "https://example.com/mcp")
        #expect(server.startupTimeoutSec == 25)

        let cachePath = NolonManager().mcpsURL.appendingPathComponent("\(name).json")
        #expect(STFile(cachePath).isExists)
        let cacheData = try Data(contentsOf: cachePath)
        let cachedServer = try MCPJsonFile.serverConfig(from: cacheData, slug: name)
        #expect(cachedServer["enabled_tools"] as? [String] == ["search", "open"])
        #expect((cachedServer["http_headers"] as? [String: Any])?["authorization"] as? String == "Bearer token")
        #expect(cachedServer["oauth_resource"] as? String == "https://example.com/mcp")
    }

    @Test("Linked MCP sync projects all cache fragments to provider native config")
    func linkedMcpSyncProjectsAllFragments() throws {
        let root = try STFolder(sanbox: .temporary)
            .folder("nolon-mcp-linked-sync-\(UUID().uuidString)")
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

        let manager = NolonManager()
        _ = manager.mcpsFolder.createIfNotExists()

        let alphaName = "reg-linked-alpha"
        let betaName = "reg-linked-beta"
        let aPath = manager.mcpsURL.appendingPathComponent("\(alphaName).json")
        let bPath = manager.mcpsURL.appendingPathComponent("\(betaName).json")
        let aRoot: [String: Any] = [
            "mcpServers": [
                alphaName: [
                    "command": "npx",
                    "args": ["-y", "@acme/alpha-mcp"],
                    "enabled": true
                ]
            ],
            "x-nolon": ["providers": ["codex"]]
        ]
        let bRoot: [String: Any] = [
            "mcpServers": [
                betaName: [
                    "url": "http://localhost:8081/mcp",
                    "enabled": true
                ]
            ],
            "x-nolon": ["providers": ["codex"]]
        ]
        try JSONSerialization.data(withJSONObject: aRoot, options: [.prettyPrinted, .sortedKeys]).write(to: aPath)
        try JSONSerialization.data(withJSONObject: bRoot, options: [.prettyPrinted, .sortedKeys]).write(to: bPath)

        let configPath = ProviderTemplate.codex.defaultMcpConfigPath
        _ = STFolder(configPath.deletingLastPathComponent()).createIfNotExists()
        try """
        [mcp_servers.legacy]
        command = "legacy"
        """.write(to: configPath, atomically: true, encoding: .utf8)

        let synced = try MCPConfigManager.syncAllCacheServersToProvider(for: .codex)
        #expect(synced == 2)

        let providerServers = try MCPConfigManager.listServers(for: .codex).map(\.name).sorted()
        #expect(providerServers == [alphaName, betaName, "legacy"])

        let alphaData = try Data(contentsOf: aPath)
        let alphaJSON = try #require(JSONSerialization.jsonObject(with: alphaData) as? [String: Any])
        let alphaNolon = try #require(alphaJSON["x-nolon"] as? [String: Any])
        let alphaProviders = try #require(alphaNolon["providers"] as? [String])
        #expect(alphaProviders.contains("codex"))

        // Deleting a fragment should prune provider projection on next linked sync.
        try STFile(aPath).deleteIncludingBrokenSymlink()
        let resynced = try MCPConfigManager.syncAllCacheServersToProvider(for: .codex)
        #expect(resynced == 1)
        let providerServersAfterDelete = try MCPConfigManager.listServers(for: .codex).map(\.name).sorted()
        #expect(providerServersAfterDelete == [betaName, "legacy"])
    }

    @Test("Linked MCP sync respects fragment provider ownership")
    func linkedMcpSyncRespectsFragmentProviderOwnership() throws {
        let root = try STFolder(sanbox: .temporary)
            .folder("nolon-mcp-linked-provider-scope-\(UUID().uuidString)")
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

        let manager = NolonManager()
        _ = manager.mcpsFolder.createIfNotExists()

        let codexPath = manager.mcpsURL.appendingPathComponent("codex-only.json")
        let opencodePath = manager.mcpsURL.appendingPathComponent("opencode-only.json")

        let codexRoot: [String: Any] = [
            "mcpServers": [
                "codex-only": [
                    "command": "npx",
                    "args": ["-y", "@acme/codex-only"],
                    "enabled": true
                ]
            ],
            "x-nolon": ["providers": ["codex"]]
        ]
        let opencodeRoot: [String: Any] = [
            "mcpServers": [
                "opencode-only": [
                    "command": "npx",
                    "args": ["-y", "@acme/opencode-only"],
                    "enabled": true
                ]
            ],
            "x-nolon": ["providers": ["opencode"]]
        ]

        try JSONSerialization.data(withJSONObject: codexRoot, options: [.prettyPrinted, .sortedKeys]).write(to: codexPath)
        try JSONSerialization.data(withJSONObject: opencodeRoot, options: [.prettyPrinted, .sortedKeys]).write(to: opencodePath)

        _ = STFolder(ProviderTemplate.codex.defaultMcpConfigPath.deletingLastPathComponent()).createIfNotExists()
        _ = STFolder(ProviderTemplate.opencode.defaultMcpConfigPath.deletingLastPathComponent()).createIfNotExists()

        let codexCount = try MCPConfigManager.syncAllCacheServersToProvider(for: .codex)
        #expect(codexCount == 1)

        let codexServers = try MCPConfigManager.listServers(for: .codex).map(\.name).sorted()
        #expect(codexServers == ["codex-only"])

        let opencodeFragmentAfterCodexSync = try Data(contentsOf: opencodePath)
        let opencodeFragmentJSON = try #require(JSONSerialization.jsonObject(with: opencodeFragmentAfterCodexSync) as? [String: Any])
        let opencodeNolon = try #require(opencodeFragmentJSON["x-nolon"] as? [String: Any])
        let opencodeProviders = Set((opencodeNolon["providers"] as? [String]) ?? [])
        #expect(opencodeProviders == ["opencode"])
    }

    @Test("Linked MCP sync strips unsupported Codex stdio HTTP header fields")
    func linkedMcpSyncStripsUnsupportedCodexStdioHTTPHeaderFields() throws {
        let root = try STFolder(sanbox: .temporary)
            .folder("nolon-mcp-codex-sanitize-\(UUID().uuidString)")
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

        let manager = NolonManager()
        _ = manager.mcpsFolder.createIfNotExists()

        let fragmentPath = manager.mcpsURL.appendingPathComponent("playwright.json")
        let fragment: [String: Any] = [
            "mcpServers": [
                "playwright": [
                    "command": "npx",
                    "args": ["@playwright/mcp@latest"],
                    "type": "stdio",
                    "http_headers": ["x-token": "abc"]
                ]
            ],
            "x-nolon": ["providers": ["codex"]]
        ]
        try JSONSerialization.data(withJSONObject: fragment, options: [.prettyPrinted, .sortedKeys]).write(to: fragmentPath)

        _ = try MCPConfigManager.syncAllCacheServersToProvider(for: .codex)

        let configPath = ProviderTemplate.codex.defaultMcpConfigPath
        let configData = try Data(contentsOf: configPath)
        let config = try TOMLDecoder().decode(CodexMCPConfig.self, from: configData)
        let playwright = try #require(config.mcpServers?["playwright"])
        #expect(playwright.command == "npx")
        #expect(playwright.type == nil)
        #expect(playwright.httpHeaders == nil)

        let rawConfig = try String(contentsOf: configPath, encoding: .utf8)
        #expect(rawConfig.contains("[mcp_servers.playwright.http_headers]") == false)
    }

    @Test("Linked MCP sync round-trips Codex cwd and bearer token env settings")
    func linkedMcpSyncRoundTripsCodexCwdAndBearerTokenEnvSettings() throws {
        let root = try STFolder(sanbox: .temporary)
            .folder("nolon-mcp-codex-roundtrip-\(UUID().uuidString)")
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

        let manager = NolonManager()
        _ = manager.mcpsFolder.createIfNotExists()

        let fragmentPath = manager.mcpsURL.appendingPathComponent("context7.json")
        let fragment: [String: Any] = [
            "mcpServers": [
                "context7": [
                    "command": "npx",
                    "args": ["-y", "@upstash/context7-mcp"],
                    "cwd": "/tmp/context7",
                    "bearer_token_env_var": "CONTEXT7_TOKEN",
                    "enabled": true
                ]
            ],
            "x-nolon": ["providers": ["codex"]]
        ]
        try JSONSerialization.data(withJSONObject: fragment, options: [.prettyPrinted, .sortedKeys]).write(to: fragmentPath)

        _ = try MCPConfigManager.syncAllCacheServersToProvider(for: .codex)

        let configPath = ProviderTemplate.codex.defaultMcpConfigPath
        let configData = try Data(contentsOf: configPath)
        let config = try TOMLDecoder().decode(CodexMCPConfig.self, from: configData)
        let context7 = try #require(config.mcpServers?["context7"])
        #expect(context7.cwd == "/tmp/context7")
        #expect(context7.bearerTokenEnvVar == "CONTEXT7_TOKEN")

        let providerServers = try MCPConfigManager.listServers(for: .codex).map(\.name).sorted()
        #expect(providerServers == ["context7"])
    }

    @Test("Provider MCP repair strips unsupported stdio HTTP header fields from cache and config")
    func providerMcpRepairStripsUnsupportedStdioHTTPHeaderFieldsFromCacheAndConfig() throws {
        let root = try STFolder(sanbox: .temporary)
            .folder("nolon-mcp-codex-repair-\(UUID().uuidString)")
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

        let manager = NolonManager()
        _ = manager.mcpsFolder.createIfNotExists()

        let fragmentPath = manager.mcpsURL.appendingPathComponent("playwright.json")
        let fragment: [String: Any] = [
            "mcpServers": [
                "playwright": [
                    "command": "npx",
                    "args": ["@playwright/mcp@latest"],
                    "type": "stdio",
                    "http_headers": ["x-token": "abc"]
                ]
            ],
            "x-nolon": ["providers": ["codex"]]
        ]
        try JSONSerialization.data(withJSONObject: fragment, options: [.prettyPrinted, .sortedKeys]).write(to: fragmentPath)

        let configPath = ProviderTemplate.codex.defaultMcpConfigPath
        _ = STFolder(configPath.deletingLastPathComponent()).createIfNotExists()
        try """
        [mcp_servers.playwright]
        command = "npx"
        args = ["@playwright/mcp@latest"]
        type = "stdio"

        [mcp_servers.playwright.http_headers]
        x-token = "abc"
        """.write(to: configPath, atomically: true, encoding: .utf8)

        let repaired = try MCPConfigManager.repairProviderMCPStateIfNeeded(for: .codex)
        #expect(repaired)

        let fragmentData = try Data(contentsOf: fragmentPath)
        let fragmentRoot = try #require(JSONSerialization.jsonObject(with: fragmentData) as? [String: Any])
        let fragmentServers = try #require(fragmentRoot["mcpServers"] as? [String: Any])
        let playwrightFragment = try #require(fragmentServers["playwright"] as? [String: Any])
        #expect(playwrightFragment["http_headers"] == nil)

        let configData = try Data(contentsOf: configPath)
        let config = try TOMLDecoder().decode(CodexMCPConfig.self, from: configData)
        let playwright = try #require(config.mcpServers?["playwright"])
        #expect(playwright.httpHeaders == nil)

        let rawConfig = try String(contentsOf: configPath, encoding: .utf8)
        #expect(rawConfig.contains("[mcp_servers.playwright.http_headers]") == false)
    }

    @Test("Provider MCP repair canonicalizes legacy headers alias into http_headers")
    func providerMcpRepairCanonicalizesLegacyHeadersAlias() throws {
        let root = try STFolder(sanbox: .temporary)
            .folder("nolon-mcp-http-headers-canonical-\(UUID().uuidString)")
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

        let manager = NolonManager()
        _ = manager.mcpsFolder.createIfNotExists()

        let fragmentPath = manager.mcpsURL.appendingPathComponent("context7.json")
        let fragment: [String: Any] = [
            "mcpServers": [
                "context7": [
                    "url": "https://mcp.context7.com/mcp",
                    "type": "http",
                    "headers": ["CONTEXT7_API_KEY": "abc"]
                ]
            ],
            "x-nolon": ["providers": ["copilot"]]
        ]
        try JSONSerialization.data(withJSONObject: fragment, options: [.prettyPrinted, .sortedKeys]).write(to: fragmentPath)

        let configPath = ProviderTemplate.copilot.defaultMcpConfigPath
        _ = STFolder(configPath.deletingLastPathComponent()).createIfNotExists()
        try """
        {
          "servers": {
            "context7": {
              "url": "https://mcp.context7.com/mcp",
              "type": "http",
              "headers": {
                "CONTEXT7_API_KEY": "abc"
              }
            }
          }
        }
        """.write(to: configPath, atomically: true, encoding: .utf8)

        let repaired = try MCPConfigManager.repairProviderMCPStateIfNeeded(for: .copilot)
        #expect(repaired)

        let fragmentData = try Data(contentsOf: fragmentPath)
        let fragmentRoot = try #require(JSONSerialization.jsonObject(with: fragmentData) as? [String: Any])
        let fragmentServers = try #require(fragmentRoot["mcpServers"] as? [String: Any])
        let context7Fragment = try #require(fragmentServers["context7"] as? [String: Any])
        #expect(context7Fragment["headers"] == nil)
        let fragmentHTTPHeaders = try #require(context7Fragment["http_headers"] as? [String: Any])
        #expect(fragmentHTTPHeaders["CONTEXT7_API_KEY"] as? String == "abc")

        let providerRoot = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: configPath)) as? [String: Any])
        let providerServers = try #require(providerRoot["servers"] as? [String: Any])
        let providerContext7 = try #require(providerServers["context7"] as? [String: Any])
        #expect(providerContext7["headers"] == nil)
        let providerHTTPHeaders = try #require(providerContext7["http_headers"] as? [String: Any])
        #expect(providerHTTPHeaders["CONTEXT7_API_KEY"] as? String == "abc")
    }

    @Test("MCP setEnabled canonicalizes legacy headers alias in cache and provider config")
    func mcpSetEnabledCanonicalizesLegacyHeadersAlias() throws {
        let root = try STFolder(sanbox: .temporary)
            .folder("nolon-mcp-set-enabled-http-headers-\(UUID().uuidString)")
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

        let manager = NolonManager()
        _ = manager.mcpsFolder.createIfNotExists()
        let fragmentPath = manager.mcpsURL.appendingPathComponent("context7.json")
        let fragment: [String: Any] = [
            "mcpServers": [
                "context7": [
                    "url": "https://mcp.context7.com/mcp",
                    "type": "http",
                    "headers": ["CONTEXT7_API_KEY": "abc"]
                ]
            ],
            "x-nolon": ["providers": ["copilot"]]
        ]
        try JSONSerialization.data(withJSONObject: fragment, options: [.prettyPrinted, .sortedKeys]).write(to: fragmentPath)

        let configPath = ProviderTemplate.copilot.defaultMcpConfigPath
        _ = STFolder(configPath.deletingLastPathComponent()).createIfNotExists()
        try """
        {
          "servers": {
            "context7": {
              "url": "https://mcp.context7.com/mcp",
              "type": "http",
              "headers": {
                "CONTEXT7_API_KEY": "abc"
              }
            }
          }
        }
        """.write(to: configPath, atomically: true, encoding: .utf8)

        try MCPConfigManager.setEnabled(for: .copilot, name: "context7", enabled: true)

        let fragmentRoot = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: fragmentPath)) as? [String: Any])
        let fragmentServers = try #require(fragmentRoot["mcpServers"] as? [String: Any])
        let context7Fragment = try #require(fragmentServers["context7"] as? [String: Any])
        #expect(context7Fragment["headers"] == nil)
        #expect((context7Fragment["http_headers"] as? [String: Any])?["CONTEXT7_API_KEY"] as? String == "abc")

        let providerRoot = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: configPath)) as? [String: Any])
        let providerServers = try #require(providerRoot["servers"] as? [String: Any])
        let providerContext7 = try #require(providerServers["context7"] as? [String: Any])
        #expect(providerContext7["headers"] == nil)
        #expect((providerContext7["http_headers"] as? [String: Any])?["CONTEXT7_API_KEY"] as? String == "abc")
    }

    @Test("Codex config.toml MCP patch keeps minimal native formatting")
    func codexConfigTomlMcpPatchKeepsMinimalNativeFormatting() throws {
        let root = try STFolder(sanbox: .temporary)
            .folder("nolon-codex-config-format-\(UUID().uuidString)")
            .create()
        defer { try? root.deleteIncludingBrokenSymlink() }

        let previousHome = getenv("HOME").map { String(cString: $0) }
        setenv("HOME", root.url.path, 1)
        defer {
            if let previousHome {
                setenv("HOME", previousHome, 1)
            }
        }

        let configPath = ProviderTemplate.codex.defaultMcpConfigPath
        _ = STFolder(configPath.deletingLastPathComponent()).createIfNotExists()
        try """
        [projects]

        [projects."/tmp/demo"]
        trust_level = "trusted"
        """.write(to: configPath, atomically: true, encoding: .utf8)

        try MCPConfigManager.upsertServer(
            for: .codex,
            name: "context7",
            serverConfig: [
                "url": "https://mcp.context7.com/mcp",
                "type": "http",
                "enabled": true,
                "http_headers": ["CONTEXT7_API_KEY": "YOUR_API_KEY"]
            ]
        )

        let raw = try String(contentsOf: configPath, encoding: .utf8)
        #expect(raw.contains(#"[projects."/tmp/demo"]"#))
        #expect(raw.contains(#"[mcp_servers.context7]"#))
        #expect(raw.contains(#"url = "https://mcp.context7.com/mcp""#))
        #expect(raw.contains(#"http_headers = { "CONTEXT7_API_KEY" = "YOUR_API_KEY" }"#))
        #expect(raw.contains(#"type = "http""#) == false)
        #expect(raw.contains(#"enabled = true"#) == false)
        #expect(raw.contains(#"[mcp_servers.context7.http_headers]"#) == false)
    }

    @Test("ResourceInstaller installs Codex MCP through shared patch writer")
    func resourceInstallerInstallsCodexMcpThroughSharedPatchWriter() async throws {
        let root = try STFolder(sanbox: .temporary)
            .folder("nolon-resource-installer-codex-install-\(UUID().uuidString)")
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

        let provider = Provider(
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: root.folder(".codex").folder("skills").url.path,
            workflowPath: root.folder(".codex").folder("prompts").url.path,
            templateId: ProviderTemplate.codex.rawValue
        )

        let configPath = ProviderTemplate.codex.defaultMcpConfigPath
        _ = STFolder(configPath.deletingLastPathComponent()).createIfNotExists()
        try """
        [projects]

        [projects."/tmp/demo"]
        trust_level = "trusted"
        """.write(to: configPath, atomically: true, encoding: .utf8)

        let mcpFile = root.file("context7.json")
        try """
        {
          "mcpServers": {
            "context7": {
              "type": "http",
              "url": "https://mcp.context7.com/mcp",
              "http_headers": {
                "CONTEXT7_API_KEY": "ctx7sk-test"
              }
            }
          }
        }
        """.write(to: mcpFile.url, atomically: true, encoding: .utf8)

        let installer = ResourceInstaller(
            globalCache: GlobalCacheRepository(
                nolonManager: NolonManager(
                    rootURL: nil,
                    environment: ["NOLON_HOME": root.folder(".nolon").url.path],
                    userHomeURL: root.url
                )
            ),
            nolonManager: NolonManager(
                rootURL: nil,
                environment: ["NOLON_HOME": root.folder(".nolon").url.path],
                userHomeURL: root.url
            )
        )

        try await installer.installFromLocal(
            resourceURL: mcpFile.url,
            resourceSlug: "context7",
            resourceType: .mcp,
            to: provider
        )

        let raw = try String(contentsOf: configPath, encoding: .utf8)
        #expect(raw.contains(#"[projects."/tmp/demo"]"#))
        #expect(raw.contains(#"[mcp_servers.context7]"#))
        #expect(raw.contains(#"url = "https://mcp.context7.com/mcp""#))
        #expect(raw.contains(#"http_headers = { "CONTEXT7_API_KEY" = "ctx7sk-test" }"#))
        #expect(raw.contains(#"type = "http""#) == false)
        #expect(raw.contains(#"enabled = true"#) == false)
        #expect(raw.contains(#"[mcp_servers.context7.http_headers]"#) == false)
    }

    @Test("ResourceInstaller uninstall keeps Codex MCP patch formatting")
    func resourceInstallerUninstallKeepsCodexMcpPatchFormatting() async throws {
        let root = try STFolder(sanbox: .temporary)
            .folder("nolon-resource-installer-codex-uninstall-\(UUID().uuidString)")
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

        let provider = Provider(
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: root.folder(".codex").folder("skills").url.path,
            workflowPath: root.folder(".codex").folder("prompts").url.path,
            templateId: ProviderTemplate.codex.rawValue
        )

        let configPath = ProviderTemplate.codex.defaultMcpConfigPath
        _ = STFolder(configPath.deletingLastPathComponent()).createIfNotExists()
        try """
        [projects]

        [projects."/tmp/demo"]
        trust_level = "trusted"
        """.write(to: configPath, atomically: true, encoding: .utf8)

        try MCPConfigManager.upsertServer(
            for: .codex,
            name: "context7",
            serverConfig: [
                "url": "https://mcp.context7.com/mcp",
                "http_headers": ["CONTEXT7_API_KEY": "ctx7sk-test"]
            ]
        )

        let installer = ResourceInstaller(
            globalCache: GlobalCacheRepository(
                nolonManager: NolonManager(
                    rootURL: nil,
                    environment: ["NOLON_HOME": root.folder(".nolon").url.path],
                    userHomeURL: root.url
                )
            ),
            nolonManager: NolonManager(
                rootURL: nil,
                environment: ["NOLON_HOME": root.folder(".nolon").url.path],
                userHomeURL: root.url
            )
        )

        try await installer.uninstall(
            resourceSlug: "context7",
            resourceType: .mcp,
            from: provider
        )

        let raw = try String(contentsOf: configPath, encoding: .utf8)
        #expect(raw.contains(#"[projects."/tmp/demo"]"#))
        #expect(raw.contains(#"[mcp_servers.context7]"#) == false)
        #expect(raw.contains(#"[mcp_servers.context7.http_headers]"#) == false)
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

    @Test("ProviderResourceService parses workflow with source/state from symlink target")
    func providerResourceServiceParsesWorkflowSourceAndState() throws {
        let root = try STFolder(sanbox: .temporary)
            .folder("nolon-resource-service-\(UUID().uuidString)")
            .create()
        defer { try? root.deleteIncludingBrokenSymlink() }

        let manager = NolonManager(rootURL: root.url)
        let service = ProviderResourceService(nolonManager: manager)
        let providerRoot = root.folder("provider-codex")
        _ = providerRoot.createIfNotExists()
        let workflowDir = providerRoot.folder("prompts")
        _ = workflowDir.createIfNotExists()
        let cacheWorkflow = manager.generatedWorkflowsFolder.file("find-skills.md")
        try """
        ---
        name: Find Skills
        description: lookup skill by keyword
        ---
        """.write(to: cacheWorkflow.url, atomically: true, encoding: .utf8)

        let linked = workflowDir.file("find-skills.md")
        try linked.createSymbolicLink(to: STPath(cacheWorkflow.url))

        let provider = Provider(
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: providerRoot.folder("skills").url.path,
            workflowPath: workflowDir.url.path
        )

        let items = service.scanWorkflows(provider: provider)
        #expect(items.count == 1)
        #expect(items[0].id == "find-skills")
        #expect(items[0].source == .skill)
        #expect(items[0].state == .installed)
    }

    @Test("ProviderResourceService creates and deletes provider drafts")
    func providerResourceServiceCreatesAndDeletesDrafts() throws {
        let root = try STFolder(sanbox: .temporary)
            .folder("nolon-resource-draft-\(UUID().uuidString)")
            .create()
        defer { try? root.deleteIncludingBrokenSymlink() }

        let service = ProviderResourceService(nolonManager: NolonManager(rootURL: root.url))
        let providerRoot = root.folder("provider-codex")
        _ = providerRoot.createIfNotExists()
        let provider = Provider(
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: providerRoot.folder("skills").url.path,
            workflowPath: providerRoot.folder("prompts").url.path
        )

        let ruleURL = try service.createDraft(provider: provider, kind: .rule)
        #expect(STFile(ruleURL).isExists)

        try service.deleteResource(atPath: ruleURL.path)
        #expect(STFile(ruleURL).isExists == false)
    }

    @Test("ProviderResourceService copies provider AGENTS doc into nolon agents folder")
    func providerResourceServiceCopiesAgentDocToNolon() throws {
        let root = try STFolder(sanbox: .temporary)
            .folder("nolon-resource-agent-copy-\(UUID().uuidString)")
            .create()
        defer { try? root.deleteIncludingBrokenSymlink() }

        let manager = NolonManager(rootURL: root.url)
        let service = ProviderResourceService(nolonManager: manager)
        let providerRoot = root.folder("provider-codex")
        _ = providerRoot.createIfNotExists()
        let source = providerRoot.file("AGENTS.md")
        try "# Provider Agents".write(to: source.url, atomically: true, encoding: .utf8)

        let copied = try service.copyAgentDocToNolon(atPath: source.url.path)

        #expect(STFile(source.url).isExists)
        #expect(STFile(copied).isExists)
        #expect(copied.deletingLastPathComponent().standardizedFileURL.path == manager.agentsURL.standardizedFileURL.path)
    }

    @Test("ProviderResourceService moves provider AGENTS doc into nolon agents folder with conflict suffix")
    func providerResourceServiceMovesAgentDocToNolonWithConflictSuffix() throws {
        let root = try STFolder(sanbox: .temporary)
            .folder("nolon-resource-agent-move-\(UUID().uuidString)")
            .create()
        defer { try? root.deleteIncludingBrokenSymlink() }

        let manager = NolonManager(rootURL: root.url)
        let service = ProviderResourceService(nolonManager: manager)
        let providerRoot = root.folder("provider-codex")
        _ = providerRoot.createIfNotExists()
        let source = providerRoot.file("AGENTS.md")
        try "# Provider Agents".write(to: source.url, atomically: true, encoding: .utf8)

        let existing = manager.agentsFolder.file("AGENTS.md")
        _ = manager.agentsFolder.createIfNotExists()
        try "# Existing".write(to: existing.url, atomically: true, encoding: .utf8)

        let moved = try service.moveAgentDocToNolon(atPath: source.url.path)

        #expect(STFile(source.url).isExists == false)
        #expect(STFile(moved).isExists)
        #expect(moved.lastPathComponent == "AGENTS-copy-1.md")
    }

    @MainActor
    @Test("InstalledResourceStatusService resolves global MCP slugs from cache")
    func installedResourceStatusServiceResolvesGlobalMcpSlugs() throws {
        let root = try STFolder(sanbox: .temporary)
            .folder("nolon-installed-status-\(UUID().uuidString)")
            .create()
        defer { try? root.deleteIncludingBrokenSymlink() }

        let manager = NolonManager(rootURL: root.url)
        let cacheFolder = manager.mcpsFolder
        _ = cacheFolder.createIfNotExists()
        try "{}".write(to: cacheFolder.file("playwright.json").url, atomically: true, encoding: .utf8)
        try "{}".write(to: cacheFolder.file("xcode.json").url, atomically: true, encoding: .utf8)

        let service = InstalledResourceStatusService(nolonManager: manager)
        let slugs = service.installedMcpIDs(provider: nil)
        #expect(slugs.contains("playwright"))
        #expect(slugs.contains("xcode"))
    }

    @MainActor
    @Test("ProviderResourceSummaryService aggregates provider counts")
    func providerResourceSummaryServiceAggregatesProviderCounts() throws {
        let root = try STFolder(sanbox: .temporary)
            .folder("nolon-provider-summary-\(UUID().uuidString)")
            .create()
        defer { try? root.deleteIncludingBrokenSymlink() }

        let manager = NolonManager(rootURL: root.url)
        let repository = SkillRepository(nolonManager: manager)
        let settings = ProviderSettings(userDefaults: .standard, nolonManager: manager)
        settings.providers = []

        let providerRoot = root.folder("provider-codex")
        let skillsFolder = providerRoot.folder("skills")
        let workflowsFolder = providerRoot.folder("prompts")
        let rulesFolder = providerRoot.folder("rules")
        _ = skillsFolder.createIfNotExists()
        _ = workflowsFolder.createIfNotExists()
        _ = rulesFolder.createIfNotExists()

        let provider = Provider(
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: skillsFolder.url.path,
            workflowPath: workflowsFolder.url.path,
            installMethod: .copy,
            templateId: "codex"
        )
        settings.providers = [provider]

        let globalSkill = manager.skillsFolder.folder("find-skills")
        _ = globalSkill.createIfNotExists()
        try """
        ---
        name: find-skills
        description: find skills by query
        ---
        """.write(to: globalSkill.file("SKILL.md").url, atomically: true, encoding: .utf8)
        let skill = try #require(repository.listSkills().first { $0.id == "find-skills" })
        let installer = SkillInstaller(repository: repository, settings: settings, nolonManager: manager)
        try installer.install(skill: skill, to: provider)

        try """
        ---
        name: Find Skills Workflow
        description: generated by skill
        ---
        """.write(to: workflowsFolder.file("find-skills.md").url, atomically: true, encoding: .utf8)
        try "// rules".write(to: rulesFolder.file("default.rules").url, atomically: true, encoding: .utf8)
        try "# AGENTS".write(to: provider.codexAgentsFileURL, atomically: true, encoding: .utf8)

        let summaryService = ProviderResourceSummaryService(
            resourceService: ProviderResourceService(nolonManager: manager),
            statusService: InstalledResourceStatusService(nolonManager: manager),
            repository: repository,
            settings: settings
        )
        let summary = summaryService.summarize(provider: provider)
        #expect(summary.skillsCount == 1)
        #expect(summary.workflowsCount == 1)
        #expect(summary.rulesCount == 1)
        #expect(summary.agentsCount == 1)
    }

    @MainActor
    @Test("SkillInstaller installLocal materializes relative symlinked skill assets")
    func skillInstallerInstallLocalMaterializesRelativeSymlinkedAssets() throws {
        let root = try STFolder(sanbox: .temporary)
            .folder("nolon-local-symlink-skill-\(UUID().uuidString)")
            .create()
        defer { try? root.deleteIncludingBrokenSymlink() }

        let repoRoot = root.folder("repo")
        let skillFolder = repoRoot.folder(".claude").folder("skills").folder("ui-ux-pro-max")
        let sourceScripts = repoRoot.folder("src").folder("ui-ux-pro-max").folder("scripts")
        _ = skillFolder.createIfNotExists()
        _ = sourceScripts.createIfNotExists()

        try """
        ---
        name: ui-ux-pro-max
        description: ui ux helper
        ---
        """.write(to: skillFolder.file("SKILL.md").url, atomically: true, encoding: .utf8)
        try "print('ok')".write(to: sourceScripts.file("search.py").url, atomically: true, encoding: .utf8)

        let fileManager = FileManager.default
        try fileManager.createSymbolicLink(
            atPath: skillFolder.subpath("scripts").url.path,
            withDestinationPath: "../../../src/ui-ux-pro-max/scripts"
        )

        let manager = NolonManager(rootURL: root.folder(".nolon").url)
        let repository = SkillRepository(nolonManager: manager)
        let settings = ProviderSettings(userDefaults: .standard, nolonManager: manager)
        let providerSkills = root.folder("provider").folder("skills")
        _ = providerSkills.createIfNotExists()
        let provider = Provider(
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: providerSkills.url.path,
            workflowPath: root.folder("provider").folder("prompts").url.path,
            installMethod: .symlink,
            templateId: "codex"
        )
        settings.providers = [provider]

        let installer = SkillInstaller(repository: repository, settings: settings, nolonManager: manager)
        try installer.installLocal(from: skillFolder.url.path, slug: "ui-ux-pro-max", to: provider)

        let globalSkill = manager.skillsFolder.folder("ui-ux-pro-max")
        let globalScripts = STPath(globalSkill.subpath("scripts").url.path)
        #expect(globalScripts.isSymbolicLink == false)
        #expect(STFile("\(globalSkill.url.path)/scripts/search.py").isExists)
    }

    @Test("ProviderDiscoveryService detects installed providers from paths")
    func providerDiscoveryServiceDetectsInstalledProvidersFromPaths() {
        let knownPaths = Set([
            ProviderTemplate.codex.defaultSkillsPath.path,
            ProviderTemplate.opencode.defaultWorkflowPath.path,
        ])
        let service = ProviderDiscoveryService(
            pathExists: { knownPaths.contains($0) },
            cliResolver: { _ in nil }
        )
        let detected = service.detectInstalledProviders(templates: [.codex, .opencode, .claudeCode])
        #expect(detected.contains(.codex))
        #expect(detected.contains(.opencode))
        #expect(detected.contains(.claudeCode) == false)
    }

    @Test("ProviderDiscoveryService resolves templates with installed CLI")
    func providerDiscoveryServiceResolvesTemplatesWithInstalledCLI() {
        let service = ProviderDiscoveryService(
            pathExists: { _ in false },
            cliResolver: { executable in
                executable == ProviderTemplate.codex.cliName ? "/opt/homebrew/bin/\(executable)" : nil
            }
        )
        let detected = service.templatesWithInstalledCLI(templates: [.codex, .opencode, .claudeCode])
        #expect(detected == [.codex])
    }

    @Test("ProviderSkillMaintenanceService scans and migrates skills")
    func providerSkillMaintenanceServiceScansAndMigratesSkills() throws {
        let root = try STFolder(sanbox: .temporary)
            .folder("nolon-skill-maintenance-\(UUID().uuidString)")
            .create()
        defer { try? root.deleteIncludingBrokenSymlink() }

        let providerFolder = root.folder("provider-skills")
        let globalFolder = root.folder("global-skills")
        _ = providerFolder.createIfNotExists()
        _ = globalFolder.createIfNotExists()

        let globalSkill = globalFolder.folder("find-skills")
        _ = globalSkill.createIfNotExists()
        try "x".write(to: globalSkill.file("SKILL.md").url, atomically: true, encoding: .utf8)

        let localSkill = providerFolder.folder("find-skills")
        _ = localSkill.createIfNotExists()
        try "y".write(to: localSkill.file("SKILL.md").url, atomically: true, encoding: .utf8)

        let service = ProviderSkillMaintenanceService()
        let scan = try service.scanProviderSkills(providerPath: providerFolder, globalSkillsPath: globalFolder)
        #expect(scan.states.count == 1)
        #expect(scan.states.first?.state == .orphaned)

        let migrated = try service.migrateSkill(
            skillID: "find-skills",
            providerPath: providerFolder,
            globalSkillsPath: globalFolder,
            installMethod: .copy
        )
        #expect(migrated.skillID == "find-skills")
        #expect(STPath(migrated.targetPath).isExists)
    }

    @Test("ProviderSkillsLinkService enables link directly for empty provider skills folder")
    func providerSkillsLinkServiceEnableForEmptyFolder() throws {
        let root = try STFolder(sanbox: .temporary)
            .folder("nolon-provider-skills-link-empty-\(UUID().uuidString)")
            .create()
        defer { try? root.deleteIncludingBrokenSymlink() }

        let manager = NolonManager(rootURL: root.folder("nolon-home").url)
        let providerSkills = root.folder("provider-home").folder("skills")
        _ = providerSkills.createIfNotExists()

        let provider = Provider(
            kind: .project,
            name: "Project Provider",
            defaultSkillsPath: providerSkills.url.path,
            workflowPath: root.folder("provider-home").folder("workflows").url.path
        )

        let service = ProviderSkillsLinkService(nolonManager: manager)
        let preflight = try service.preflightEnable(provider: provider)
        #expect(preflight.requiresConfirmation == false)
        #expect(preflight.isProviderSkillsEmpty == true)

        try service.applyEnable(provider: provider, backupExisting: false)
        #expect(STPath(provider.defaultSkillsPath).isSymbolicLink)
    }

    @Test("ProviderSkillsLinkService backs up non-empty provider skills folder before linking")
    func providerSkillsLinkServiceBackupsAndLinks() throws {
        let root = try STFolder(sanbox: .temporary)
            .folder("nolon-provider-skills-link-backup-\(UUID().uuidString)")
            .create()
        defer { try? root.deleteIncludingBrokenSymlink() }

        let manager = NolonManager(rootURL: root.folder("nolon-home").url)
        let providerHome = root.folder("provider-home")
        let providerSkills = providerHome.folder("skills")
        _ = providerSkills.createIfNotExists()
        try "legacy".write(to: providerSkills.file("legacy.txt").url, atomically: true, encoding: .utf8)

        let staleBackup = providerHome.folder("skills.bak")
        _ = staleBackup.createIfNotExists()
        try "stale".write(to: staleBackup.file("stale.txt").url, atomically: true, encoding: .utf8)

        let provider = Provider(
            kind: .vendor,
            name: "Vendor Provider",
            defaultSkillsPath: providerSkills.url.path,
            workflowPath: providerHome.folder("workflows").url.path
        )

        let service = ProviderSkillsLinkService(nolonManager: manager)
        let preflight = try service.preflightEnable(provider: provider)
        #expect(preflight.requiresConfirmation == true)
        #expect(preflight.isProviderSkillsEmpty == false)

        try service.applyEnable(provider: provider, backupExisting: true)

        let backupFolder = providerHome.folder("skills.bak")
        #expect(backupFolder.isExists)
        #expect(backupFolder.file("legacy.txt").isExists)
        #expect(backupFolder.file("stale.txt").isExists == false)
        #expect(STPath(providerSkills.url.path).isSymbolicLink)
    }

    @Test("ProviderSkillMaintenanceService marks skills as installed when provider skills root links to global")
    func providerSkillMaintenanceServiceTreatsGlobalRootLinkAsInstalled() throws {
        let root = try STFolder(sanbox: .temporary)
            .folder("nolon-skill-maintenance-global-link-\(UUID().uuidString)")
            .create()
        defer { try? root.deleteIncludingBrokenSymlink() }

        let globalFolder = root.folder("global-skills")
        _ = globalFolder.createIfNotExists()
        let globalSkill = globalFolder.folder("find-skills")
        _ = globalSkill.createIfNotExists()
        try "x".write(to: globalSkill.file("SKILL.md").url, atomically: true, encoding: .utf8)

        let providerHome = root.folder("provider-home")
        _ = providerHome.createIfNotExists()
        let providerSkillsPath = providerHome.subpath("skills")
        try providerSkillsPath.createSymbolicLink(to: STPath(globalFolder.url.path))

        let providerScannableFolder = STFolder((try providerSkillsPath.destinationOfSymbolicLink()).url.path)
        let service = ProviderSkillMaintenanceService()
        let scan = try service.scanProviderSkills(
            providerPath: providerScannableFolder,
            globalSkillsPath: globalFolder
        )
        #expect(scan.states.count == 1)
        #expect(scan.states.first?.state == .installed)
    }

    @Test("ProviderSkillMaintenanceService marks skills as installed when provider skills root resolves to global through ancestor symlink")
    func providerSkillMaintenanceServiceTreatsAncestorLinkedGlobalRootAsInstalled() throws {
        let root = try STFolder(sanbox: .temporary)
            .folder("nolon-skill-maintenance-ancestor-link-\(UUID().uuidString)")
            .create()
        defer { try? root.deleteIncludingBrokenSymlink() }

        let globalHome = root.folder("nolon-home")
        let globalFolder = globalHome.folder("skills")
        _ = globalFolder.createIfNotExists()
        let globalSkill = globalFolder.folder("scale")
        _ = globalSkill.createIfNotExists()
        try "x".write(to: globalSkill.file("SKILL.md").url, atomically: true, encoding: .utf8)

        let providerHome = root.folder("provider-home")
        _ = providerHome.createIfNotExists()
        let linkedHome = providerHome.subpath("linked-home")
        try linkedHome.createSymbolicLink(to: STPath(globalHome.url.path))
        let providerSkillsFolder = STFolder(linkedHome.url.appendingPathComponent("skills", isDirectory: true))

        let service = ProviderSkillMaintenanceService()
        let scan = try service.scanProviderSkills(
            providerPath: providerSkillsFolder,
            globalSkillsPath: globalFolder
        )
        #expect(scan.states.count == 1)
        #expect(scan.states.first?.state == .installed)
    }

    @Test("ProviderSkillMaintenanceService installs copies into linked global skills root")
    func providerSkillMaintenanceServiceInstallsCopiesIntoLinkedGlobalRoot() throws {
        let root = try STFolder(sanbox: .temporary)
            .folder("nolon-skill-maintenance-linked-install-\(UUID().uuidString)")
            .create()
        defer { try? root.deleteIncludingBrokenSymlink() }

        let repositoryRoot = root.folder("repositories").folder("gate").folder("skills")
        let sourceSkill = repositoryRoot.folder("scale")
        _ = sourceSkill.createIfNotExists()
        try """
        ---
        name: scale
        description: scale helper
        ---
        """.write(to: sourceSkill.file("SKILL.md").url, atomically: true, encoding: .utf8)

        let globalFolder = root.folder("global-skills")
        _ = globalFolder.createIfNotExists()

        let providerHome = root.folder("provider-home")
        _ = providerHome.createIfNotExists()
        let providerSkillsPath = providerHome.subpath("skills")
        try providerSkillsPath.createSymbolicLink(to: STPath(globalFolder.url.path))

        let service = ProviderSkillMaintenanceService()
        let result = try service.installSkill(
            skillPath: STPath(sourceSkill.url),
            skillID: nil,
            providerPath: STFolder(providerSkillsPath.url),
            installMethod: .symlink
        )

        let installedSkill = globalFolder.folder("scale")
        #expect(result.installMethod == .copy)
        #expect(installedSkill.isExists)
        #expect(STPath(installedSkill.url).isSymbolicLink == false)
        #expect(installedSkill.file("SKILL.md").isExists)
    }

    @Test("ProviderSkillMaintenanceService heals stale managed provider root before install")
    func providerSkillMaintenanceServiceHealsStaleManagedRootBeforeInstall() throws {
        let root = try STFolder(sanbox: .temporary)
            .folder("nolon-skill-maintenance-stale-link-\(UUID().uuidString)")
            .create()
        defer { try? root.deleteIncludingBrokenSymlink() }

        let currentNolonHome = root.folder("active-nolon-home")
        _ = currentNolonHome.createIfNotExists()
        let manager = NolonManager(rootURL: currentNolonHome.url)

        let repositoryRoot = root.folder("repositories").folder("gate").folder("skills")
        let sourceSkill = repositoryRoot.folder("scale")
        _ = sourceSkill.createIfNotExists()
        try """
        ---
        name: scale
        description: scale helper
        ---
        """.write(to: sourceSkill.file("SKILL.md").url, atomically: true, encoding: .utf8)

        let staleNolonHome = root.folder("stale-nolon-home")
        let staleSkillsRoot = staleNolonHome.folder("skills")
        _ = staleSkillsRoot.createIfNotExists()
        _ = staleNolonHome.folder("repositories").createIfNotExists()
        _ = staleNolonHome.folder("mcps").createIfNotExists()
        _ = staleNolonHome.folder("agents").createIfNotExists()

        let providerHome = root.folder("provider-home")
        _ = providerHome.createIfNotExists()
        let providerSkillsPath = providerHome.subpath("skills")
        try providerSkillsPath.createSymbolicLink(to: STPath(staleSkillsRoot.url.path))

        let service = ProviderSkillMaintenanceService(nolonManager: manager)
        let result = try service.installSkill(
            skillPath: STPath(sourceSkill.url),
            skillID: nil,
            providerPath: STFolder(providerSkillsPath.url),
            installMethod: .symlink
        )

        let relinkedTarget = try #require(try? providerSkillsPath.destinationOfSymbolicLink().url.standardizedFileURL.path)
        #expect(relinkedTarget == manager.skillsFolder.url.standardizedFileURL.path)
        #expect(result.installMethod == .copy)
        #expect(manager.skillsFolder.folder("scale").isExists)
        #expect(staleSkillsRoot.folder("scale").isExists == false)
    }

    @Test("WorkflowBindingService binds and unbinds workflows for skill and MCP")
    func workflowBindingServiceBindsAndUnbindsWorkflows() throws {
        let root = try STFolder(sanbox: .temporary)
            .folder("nolon-workflow-binding-\(UUID().uuidString)")
            .create()
        defer { try? root.deleteIncludingBrokenSymlink() }

        let nolonHome = root.folder("nolon-home")
        _ = nolonHome.createIfNotExists()
        let providerWorkflow = root.folder("provider-workflows")
        _ = providerWorkflow.createIfNotExists()

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

        let manager = NolonManager(rootURL: nolonHome.url)
        let service = WorkflowBindingService(manager: manager)

        let skillInstall = try service.bindWorkflowFromSkill(
            skillID: "find-skills",
            providerWorkflowPath: providerWorkflow
        )
        #expect(skillInstall.workflowFileName == "find-skills.md")
        #expect(STPath(skillInstall.globalWorkflowPath).isExists)
        #expect(STPath(skillInstall.providerWorkflowPath).isSymbolicLink)

        let mcpInstall = try service.bindWorkflowFromMCP(
            mcpName: "playwright",
            providerWorkflowPath: providerWorkflow
        )
        #expect(mcpInstall.workflowFileName == "playwright.md")
        #expect(STPath(mcpInstall.globalWorkflowPath).isExists)
        #expect(STPath(mcpInstall.providerWorkflowPath).isSymbolicLink)

        let skillUninstall = try service.unbindWorkflowFromSkill(
            skillID: "find-skills",
            providerWorkflowPath: providerWorkflow
        )
        #expect(skillUninstall.workflowFileName == "find-skills.md")
        #expect(skillUninstall.removed)
        #expect(STPath(skillUninstall.providerWorkflowPath).isExists == false)

        let mcpUninstall = try service.unbindWorkflowFromMCP(
            mcpName: "playwright",
            providerWorkflowPath: providerWorkflow
        )
        #expect(mcpUninstall.workflowFileName == "playwright.md")
        #expect(mcpUninstall.removed)
        #expect(STPath(mcpUninstall.providerWorkflowPath).isExists == false)
    }

    @Test("ResourceRepairPlanner builds deterministic steps")
    func resourceRepairPlannerBuildsSteps() {
        let plan = ResourceRepairPlanner.plan(
            kind: .workflow,
            items: [
                .init(providerID: "codex", resourceID: "a.md", state: .orphaned),
                .init(providerID: "opencode", resourceID: "b.md", state: .broken),
            ]
        )
        #expect(plan.steps.count == 2)
        #expect(plan.steps[0].title == "清理失效链接")
        #expect(plan.steps[0].commands[0] == "nolon workflow remove --resource-name a.md --provider codex")
        #expect(plan.steps[1].title == "清理损坏项")
        #expect(plan.recheckCommand == "nolon workflow list --show-fixes")
    }

    @Test("ResourceRepairPlanner builds skill repair command by state")
    func resourceRepairPlannerBuildsSkillRepairCommandByState() {
        let orphaned = ResourceRepairPlanner.command(
            kind: .skill,
            item: .init(providerID: "codex", resourceID: "find-skills", state: .orphaned)
        )
        #expect(orphaned == "nolon skills remove --skill-id find-skills --provider codex")

        let broken = ResourceRepairPlanner.command(
            kind: .skill,
            item: .init(providerID: "codex", resourceID: "find-skills", state: .broken)
        )
        #expect(
            broken ==
            "nolon skills remove --skill-id find-skills --provider codex && nolon skills add find-skills --provider codex"
        )
    }

    @Test("ResourceListOverviewFormatter renders status and summary deterministically")
    func resourceListOverviewFormatterRendersStatusAndSummary() {
        let metrics = ResourceListOverviewMetrics(
            installedCount: 2,
            orphanedCount: 1,
            brokenCount: 1,
            itemCount: 4
        )

        #expect(ResourceListOverviewFormatter.issueCount(metrics) == 2)
        #expect(
            ResourceListOverviewFormatter.summaryLine(showFixes: true, metrics: metrics)
                == "摘要: 异常=2 | 已安装=2/4 | 修复动作=需修复"
        )
        #expect(
            ResourceListOverviewFormatter.statusLine(metrics: metrics)
                == "状态(已安装/失效链接/损坏): 2/1/1 (50.0%/25.0%/25.0%)"
        )
        #expect(
            ResourceListOverviewFormatter.conclusionLines(showFixes: false, metrics: metrics)
                == ["需处理异常: 2（失效链接 1，损坏 1）", "行动建议: 需处理 2 项异常（高优先级）"]
        )
    }

    @Test("ResourceListOverviewFormatter compact healthy summary rule")
    func resourceListOverviewFormatterCompactHealthySummaryRule() {
        let healthy = ResourceListOverviewMetrics(
            installedCount: 4,
            orphanedCount: 0,
            brokenCount: 0,
            itemCount: 4
        )

        #expect(
            ResourceListOverviewFormatter.compactHealthySummary(
                showFixes: true,
                verbose: false,
                hasProviderFilter: false,
                hasStateFilter: false,
                metrics: healthy
            )
        )
        #expect(
            ResourceListOverviewFormatter.compactHealthySummary(
                showFixes: true,
                verbose: false,
                hasProviderFilter: true,
                hasStateFilter: false,
                metrics: healthy
            ) == false
        )
    }

    @Test("ResourceListGuidancePolicy renders empty-state variants")
    func resourceListGuidancePolicyRendersEmptyStateVariants() {
        #expect(
            ResourceListGuidancePolicy.emptyResultLine(
                resourceDisplayLabel: "技能",
                providerFilter: "codex",
                stateFilterLabel: "损坏"
            ) == "在 provider=codex 且 state=损坏 下，未发现匹配技能。"
        )
        #expect(
            ResourceListGuidancePolicy.emptyResultLine(
                resourceDisplayLabel: "工作流资源",
                providerFilter: "codex",
                stateFilterLabel: nil
            ) == "在 provider=codex 下，未发现异常工作流资源（失效链接/损坏）。"
        )
    }

    @Test("ResourceListGuidancePolicy renders guidance lines")
    func resourceListGuidancePolicyRendersGuidanceLines() {
        #expect(
            ResourceListGuidancePolicy.installedHintLine(
                resourceDisplayLabel: "技能",
                command: "nolon skills list --state installed"
            ) == "如需查看已安装技能，请执行: `nolon skills list --state installed`"
        )
        #expect(
            ResourceListGuidancePolicy.noFixesRetryLines(command: "nolon skills list --show-fixes")
                == [
                    "当前筛选条件下无可修复项；请移除筛选后重试 --show-fixes。",
                    "复检命令: `nolon skills list --show-fixes`",
                ]
        )
        #expect(
            ResourceListGuidancePolicy.verboseHintLine(command: "nolon skills list --verbose")
                == "提示: 使用 `nolon skills list --verbose` 查看安装路径与来源。"
        )
    }

    @Test("ResourceListGuidancePolicy renders skills quick action items")
    func resourceListGuidancePolicyRendersSkillsQuickActionItems() {
        #expect(
            ResourceListGuidancePolicy.skillsQuickActionItems(hasBroken: true, hasOrphaned: true)
                == [
                    "查看损坏详情: `nolon skills list --state broken --verbose`",
                    "查看失效链接详情: `nolon skills list --state orphaned --verbose`",
                    "生成修复命令: `nolon skills list --show-fixes`",
                ]
        )
        #expect(
            ResourceListGuidancePolicy.skillsQuickActionItems(hasBroken: false, hasOrphaned: true)
                == [
                    "查看失效链接详情: `nolon skills list --state orphaned --verbose`",
                    "生成修复命令: `nolon skills list --show-fixes`",
                ]
        )
    }

    @Test("ResourceListGuidancePolicy renders resource quick action items")
    func resourceListGuidancePolicyRendersResourceQuickActionItems() {
        #expect(
            ResourceListGuidancePolicy.resourceQuickActionItems(
                singleFixCommand: "nolon workflow remove --resource-name a.md --provider codex",
                showFixesCommand: "nolon workflow list --show-fixes",
                verboseShowFixesCommand: "nolon workflow list --verbose --show-fixes"
            ) == [
                "`nolon workflow remove --resource-name a.md --provider codex`",
                "查看路径与来源: `nolon workflow list --verbose --show-fixes`",
            ]
        )
        #expect(
            ResourceListGuidancePolicy.resourceQuickActionItems(
                singleFixCommand: nil,
                showFixesCommand: "nolon mcp list --show-fixes",
                verboseShowFixesCommand: "nolon mcp list --verbose --show-fixes"
            ) == [
                "生成分条修复命令: `nolon mcp list --show-fixes`",
                "查看路径与来源: `nolon mcp list --verbose --show-fixes`",
            ]
        )
    }

    @Test("SearchPresentationPolicy prioritizes exact slug")
    func searchPresentationPolicyPrioritizesExactSlug() {
        struct Item { let slug: String }
        let selection = SearchPresentationPolicy.select(
            query: "find-skills",
            items: [Item(slug: "find"), Item(slug: "find-skills"), Item(slug: "find-skills-2")],
            maxDisplayCount: 10,
            slug: \.slug
        )
        #expect(selection.exactMatch?.slug == "find-skills")
        #expect(selection.displayed.count == 1)
        #expect(selection.alternatives.count == 2)
    }

    @Test("SearchPresentationPolicy keeps large result sets uncollapsed")
    func searchPresentationPolicyKeepsLargeResultSetsUncollapsed() {
        struct Item { let slug: String }
        let selection = SearchPresentationPolicy.select(
            query: "find-skills",
            items: (1...20).map { idx in
                idx == 1 ? Item(slug: "find-skills") : Item(slug: "find-skills-\(idx)")
            },
            maxDisplayCount: 10,
            slug: \.slug
        )
        #expect(selection.exactMatch == nil)
        #expect(selection.displayed.count == 10)
        #expect(selection.alternatives.isEmpty)
    }

    @Test("UsageRefreshPolicy keeps first-load and interval semantics")
    func usageRefreshPolicyKeepsSemantics() {
        let now = Date(timeIntervalSince1970: 100)
        #expect(
            UsageRefreshPolicy.shouldRefresh(
                hasTriggeredAppearRefresh: false,
                intervalMinutes: 10,
                lastRefreshAt: now,
                now: now
            )
        )
        #expect(
            UsageRefreshPolicy.shouldRefresh(
                hasTriggeredAppearRefresh: true,
                intervalMinutes: 0,
                lastRefreshAt: now,
                now: now
            ) == false
        )
        #expect(
            UsageRefreshPolicy.shouldRefresh(
                hasTriggeredAppearRefresh: true,
                intervalMinutes: 10,
                lastRefreshAt: Date(timeIntervalSince1970: 0),
                now: now
            ) == false
        )
    }

    @Test("RemoteRefreshPolicy centralizes app-facing refresh delays")
    func remoteRefreshPolicyDelays() {
        #expect(RemoteRefreshPolicy.installPropagationDelay == 0.35)
        #expect(RemoteRefreshPolicy.repositorySelectionDelay == 0.35)
    }

    @Test("RemoteCatalogQueryService queries local folder repositories for all kinds")
    func remoteCatalogQueryServiceQueriesLocalFolder() async throws {
        let root = try STFolder(sanbox: .temporary)
            .folder("nolon-remote-query-\(UUID().uuidString)")
            .create()
        defer { try? root.deleteIncludingBrokenSymlink() }

        let skillsDir = root.folder("skills")
        _ = skillsDir.createIfNotExists()
        let findSkillsDir = skillsDir.folder("find-skills")
        _ = findSkillsDir.createIfNotExists()
        try """
        ---
        name: Find Skills
        description: Find installable skills quickly
        ---
        """.write(to: findSkillsDir.file("SKILL.md").url, atomically: true, encoding: .utf8)
        try """
        ---
        name: Update Workflow
        description: Update docs and tests
        ---
        """.write(to: skillsDir.file("update-agent-skills-workflows.md").url, atomically: true, encoding: .utf8)
        try """
        {
          "name": "playwright",
          "description": "browser automation",
          "mcpServers": {
            "playwright": { "command": "npx", "args": ["@playwright/mcp@latest"] }
          }
        }
        """.write(to: skillsDir.file("playwright.json").url, atomically: true, encoding: .utf8)

        let repository = RemoteRepository(
            name: "local",
            templateType: .localFolder,
            localPath: skillsDir.url.path
        )
        let service = RemoteCatalogQueryService()

        let skills = try await service.query(repository: repository, kind: .skill, query: nil, limit: 20)
        let workflows = try await service.query(repository: repository, kind: .workflow, query: nil, limit: 20)
        let mcps = try await service.query(repository: repository, kind: .mcp, query: nil, limit: 20)

        #expect(skills.items.count == 1)
        #expect(skills.items.first?.slug == "find-skills")
        #expect(skills.items.first?.localPath?.hasSuffix("/find-skills") == true)
        #expect(workflows.items.count == 1)
        #expect(workflows.items.first?.slug == "update-agent-skills-workflows")
        #expect(workflows.items.first?.localPath?.hasSuffix("/update-agent-skills-workflows.md") == true)
        #expect(mcps.items.count == 1)
        #expect(mcps.items.first?.slug == "playwright")
        #expect(mcps.items.first?.localPath?.hasSuffix("/playwright.json") == true)
    }

    @Test("RemoteCatalogQueryService workflow query skips SKILL.md")
    func remoteCatalogQueryServiceWorkflowQuerySkipsSkillSpec() async throws {
        let root = try STFolder(sanbox: .temporary)
            .folder("nolon-remote-query-skip-skill-md-\(UUID().uuidString)")
            .create()
        defer { try? root.deleteIncludingBrokenSymlink() }

        let base = root.folder("skills")
        _ = base.createIfNotExists()

        try """
        ---
        name: Axure Skill
        description: Skill specification
        ---
        """.write(to: base.file("SKILL.md").url, atomically: true, encoding: .utf8)

        let repository = RemoteRepository(
            name: "local",
            templateType: .localFolder,
            localPath: base.url.path
        )
        let service = RemoteCatalogQueryService()

        let workflows = try await service.query(repository: repository, kind: .workflow, query: nil, limit: 20)

        #expect(workflows.items.isEmpty)
    }

    @Test("RemoteRepositoryCountService aggregates counts from shared query service")
    func remoteRepositoryCountServiceAggregates() async throws {
        let root = try STFolder(sanbox: .temporary)
            .folder("nolon-remote-count-\(UUID().uuidString)")
            .create()
        defer { try? root.deleteIncludingBrokenSymlink() }

        let base = root.folder("repo")
        _ = base.createIfNotExists()
        let skillDir = base.folder("sample")
        _ = skillDir.createIfNotExists()
        try """
        ---
        name: Sample
        description: sample skill
        ---
        """.write(to: skillDir.file("SKILL.md").url, atomically: true, encoding: .utf8)
        try """
        ---
        name: wf
        description: wf
        ---
        """.write(to: base.file("wf.md").url, atomically: true, encoding: .utf8)
        try """
        {
          "name": "xcode",
          "description": "xcode mcp",
          "mcpServers": { "xcode": { "command": "xcode-mcp-proxy" } }
        }
        """.write(to: base.file("xcode.json").url, atomically: true, encoding: .utf8)

        let repository = RemoteRepository(name: "local", templateType: .localFolder, localPath: base.url.path)
        let counts = await RemoteRepositoryCountService().countAll(repository: repository, limit: 100)

        #expect(counts.skills == 1)
        #expect(counts.workflows == 1)
        #expect(counts.mcps == 1)
    }

    @Test("RepositorySyncOrchestrator marks directory prompt when repo has no configured paths")
    func repositorySyncOrchestratorBuildsPromptPlan() async throws {
        let repository = RemoteRepository(
            name: "git",
            templateType: .git,
            gitURL: "https://github.com/acme/repo",
            skillsPaths: []
        )

        let orchestrator = RepositorySyncOrchestrator(
            sync: { _ in
                .success(
                    isNewClone: false,
                    detectedDirectories: [
                        .init(path: "/tmp/repo/skills", skillCount: 2, skillNames: ["a", "b"])
                    ],
                    workflowPaths: [],
                    mcpPaths: []
                )
            },
            detectRepositoryResources: { _ in
                .init(
                    skillsDirectories: [],
                    workflowPaths: [],
                    mcpPaths: []
                )
            }
        )

        let (_, plan) = try await orchestrator.sync(repository: repository)
        #expect(plan.shouldPromptDirectorySelection)
        #expect(plan.detectedDirectories.count == 1)
        #expect(plan.repository.detectedDirectories?.count == 1)
    }

    @Test("ProviderResourceSnapshotService returns workflows/rules/agents and mcps")
    func providerResourceSnapshotServiceLoadsAll() throws {
        let root = try STFolder(sanbox: .temporary)
            .folder("nolon-provider-snapshot-\(UUID().uuidString)")
            .create()
        defer { try? root.deleteIncludingBrokenSymlink() }

        let previousHome = getenv("HOME").map { String(cString: $0) }
        setenv("HOME", root.url.path, 1)
        defer {
            if let previousHome { setenv("HOME", previousHome, 1) }
        }

        let providerRoot = root.folder("codex-home")
        let provider = Provider(
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: providerRoot.folder("skills").url.path,
            workflowPath: providerRoot.folder("prompts").url.path,
            templateId: "codex"
        )
        _ = providerRoot.folder("prompts").createIfNotExists()
        _ = providerRoot.folder("rules").createIfNotExists()
        try """
        ---
        name: WF
        description: workflow desc
        ---
        """.write(to: providerRoot.folder("prompts").file("wf.md").url, atomically: true, encoding: .utf8)
        try "rule".write(to: providerRoot.folder("rules").file("default.rules").url, atomically: true, encoding: .utf8)
        try "# AGENTS".write(to: provider.codexAgentsFileURL, atomically: true, encoding: .utf8)

        let mcpService = ProviderMCPMaintenanceService()
        let mcpName = "playwright-\(UUID().uuidString.prefix(6))"
        defer { try? mcpService.removeServer(template: .codex, name: mcpName) }
        try mcpService.upsertServer(
            template: .codex,
            name: mcpName,
            serverConfig: ["command": "npx", "enabled": true]
        )

        let snapshot = ProviderResourceSnapshotService().load(provider: provider)
        #expect(snapshot.workflows.count == 1)
        #expect(snapshot.rules.count == 1)
        #expect(snapshot.agents.count == 1)
        #expect(snapshot.mcps.contains(where: { $0.name == mcpName }))
    }

    @Test("ProviderResourceViewMapper maps workflow/rule/agent view models")
    func providerResourceViewMapperMapsItems() {
        let mapper = ProviderResourceViewMapper()
        let snapshot = ProviderResourceSnapshot(
            workflows: [
                .init(kind: .workflow, id: "b", name: "B", path: "/tmp/b.md", preview: "desc b", source: .mcp),
                .init(kind: .workflow, id: "a", name: "A", path: "/tmp/a.md", preview: "desc a", source: .skill),
            ],
            rules: [
                .init(kind: .rule, id: "default", name: "default", path: "/tmp/default.rules", preview: "rule", relativePath: "default.rules"),
            ],
            agents: [
                .init(kind: .agent, id: "/tmp/AGENTS.override.md", name: "AGENTS.override.md", path: "/tmp/AGENTS.override.md", preview: "override", agentKind: .override),
            ],
            mcps: [],
            mcpCacheStates: [:]
        )

        let mapped = mapper.map(snapshot: snapshot)
        #expect(mapped.workflows.map(\.id) == ["a", "b"])
        #expect(mapped.workflows.first?.source == .skill)
        #expect(mapped.rules.first?.relativePath == "default.rules")
        #expect(mapped.agents.first?.kind == .override)
    }

    @Test("RepositoryDraftService validates duplicates and parses imported URL")
    func repositoryDraftServiceValidationAndImport() {
        let service = RepositoryDraftService()
        let existing: [RemoteRepository] = [
            .init(name: "Repo1", templateType: .git, gitURL: "https://github.com/acme/repo1"),
            .init(name: "Local1", templateType: .localFolder, localPath: "/tmp/skills"),
        ]

        let duplicateName = service.validate(
            .init(
                selectedTemplate: .git,
                repositoryName: "Repo1",
                gitURL: "https://github.com/acme/new",
                localPath: "",
                repositories: existing,
                editingRepositoryID: nil
            )
        )
        #expect(duplicateName == "A repository with this name already exists.")

        let duplicateGit = service.validate(
            .init(
                selectedTemplate: .git,
                repositoryName: "Repo2",
                gitURL: "git@github.com:acme/repo1.git",
                localPath: "",
                repositories: existing,
                editingRepositoryID: nil
            )
        )
        #expect(duplicateGit == "This Git repository has already been added.")

        let imported = service.importedDraft(from: "https://github.com/acme/repo2/tree/main/skills")
        #expect(imported.template == .git)
        #expect(imported.name == "repo2")
        #expect(imported.normalizedGitURL == "https://github.com/acme/repo2.git")
        #expect(imported.skillsPaths == ["skills"])

        let importedSkillFile = service.importedDraft(
            from: "https://gitlab.dxy.net/f2e/axure-helper/axure-skill-group/-/blob/main/axure-skill/SKILL.md"
        )
        #expect(importedSkillFile.skillsPaths == ["axure-skill"])
    }

    @Test("RepositoryDraftService extracts Clawhub skill query from marketplace URL")
    func repositoryDraftServiceExtractsClawhubSkillQuery() {
        let service = RepositoryDraftService()

        #expect(service.clawhubSkillQuery(from: "https://clawhub.ai/steipete/gemini") == "gemini")
        #expect(service.clawhubSkillQuery(from: "https://clawhub.ai/steipete/gemini.git") == "gemini")
        #expect(service.clawhubSkillQuery(from: "https://clawhub.ai/steipete/gemini") == "gemini")
        #expect(service.clawhubSkillQuery(from: "https://github.com/steipete/gemini") == nil)
        #expect(service.clawhubSkillQuery(from: "https://clawhub.ai") == nil)
    }

    @Test("RepositoryDraftService parses import intent for Clawhub and Git URLs")
    func repositoryDraftServiceParsesImportIntent() {
        let service = RepositoryDraftService()

        let clawhubIntent = service.parseImportIntent(from: "https://clawhub.ai/steipete/gemini")
        #expect(clawhubIntent.kind == .clawhubSkill)
        #expect(clawhubIntent.host == "clawhub.ai")
        #expect(clawhubIntent.owner == "steipete")
        #expect(clawhubIntent.slug == "gemini")
        #expect(clawhubIntent.normalizedGitURL == nil)

        let clawhubIntentWithoutScheme = service.parseImportIntent(from: "clawhub.ai/steipete/gemini.git")
        #expect(clawhubIntentWithoutScheme.kind == .clawhubSkill)
        #expect(clawhubIntentWithoutScheme.slug == "gemini")

        let gitIntent = service.parseImportIntent(from: "https://github.com/acme/repo")
        #expect(gitIntent.kind == .gitRepository)
        #expect(gitIntent.host == "github.com")
        #expect(gitIntent.normalizedGitURL == "https://github.com/acme/repo.git")

        let sshGitIntent = service.parseImportIntent(from: "git@github.com:acme/repo.git")
        #expect(sshGitIntent.kind == .gitRepository)
        #expect(sshGitIntent.normalizedGitURL == "git@github.com:acme/repo.git")

        let gitlabNestedSSHIntent = service.parseImportIntent(
            from: "git@gitlab.dxy.net:f2e/axure-helper/axure-skill-group.git"
        )
        #expect(gitlabNestedSSHIntent.kind == .gitRepository)
        #expect(
            gitlabNestedSSHIntent.normalizedGitURL
                == "git@gitlab.dxy.net:f2e/axure-helper/axure-skill-group.git"
        )

        let gitlabNestedIntent = service.parseImportIntent(
            from: "https://gitlab.dxy.net/f2e/axure-helper/axure-skill-group"
        )
        #expect(gitlabNestedIntent.kind == .gitRepository)
        #expect(
            gitlabNestedIntent.normalizedGitURL
                == "https://gitlab.dxy.net/f2e/axure-helper/axure-skill-group.git"
        )

        let unknownIntent = service.parseImportIntent(from: "https://clawhub.ai")
        #expect(unknownIntent.kind == .unknown)
    }

    @Test("RemoteCatalogPagingStore keeps page limits and cache-buster behavior")
    func remoteCatalogPagingStoreTracksPagingState() {
        let store = RemoteCatalogPagingStore(pageSize: 20, maxLimit: 60)
        let key = store.key(repositoryID: "repo", kind: .skill, query: "git")
        #expect(store.currentLimit(for: key) == 20)
        #expect(store.nextLimit(for: key) == 40)

        store.saveSuccess(
            for: key,
            items: [
                .init(kind: .skill, slug: "gitlab-cli-skills", displayName: "GitLab CLI Skills", summary: nil, latestVersion: "1.0.0", updatedAt: nil, downloads: nil, stars: nil, installs: nil),
            ],
            cacheBuster: "v1",
            limit: 40,
            canLoadMore: true
        )

        #expect(store.currentLimit(for: key) == 40)
        #expect(store.nextLimit(for: key) == 60)
        #expect(store.shouldUseCachedResult(for: key, cacheBuster: "v1"))
        #expect(!store.shouldUseCachedResult(for: key, cacheBuster: "v2"))
    }

    @Test("ProviderUsageSnapshotService aggregates status and latest update")
    func providerUsageSnapshotServiceAggregates() {
        let service = ProviderUsageSnapshotService()
        let old = Date(timeIntervalSince1970: 1_700_000_000)
        let new = Date(timeIntervalSince1970: 1_700_100_000)
        let aggregate = service.aggregate(
            items: [
                .init(id: "a", status: .success, updatedAt: old, hasCredits: true),
                .init(id: "b", status: .failure, updatedAt: nil, hasCredits: false),
                .init(id: "c", status: .success, updatedAt: new, hasCredits: false),
            ]
        )
        #expect(aggregate.totalCount == 3)
        #expect(aggregate.successCount == 2)
        #expect(aggregate.failureCount == 1)
        #expect(aggregate.creditsReadyCount == 1)
        #expect(aggregate.latestUpdatedAt == new)
    }

    @Test("RemoteSearchTextPresenter renders empty and non-empty search results")
    func remoteSearchTextPresenterRenders() {
        let presenter = RemoteSearchTextPresenter()
        let empty = presenter.render(
            .init(kind: .workflow, baseURL: "https://clawhub.ai", query: "abc", items: [])
        )
        #expect(empty.contains("未找到匹配 workflow"))

        let nonEmpty = presenter.render(
            .init(
                kind: .mcp,
                baseURL: "https://clawhub.ai",
                query: "playwright",
                items: [
                    .init(slug: "playwright-mcp", summary: "browser automation", latestVersion: "1.0.0", updatedAt: Date(timeIntervalSince1970: 1_700_000_000)),
                ]
            )
        )
        #expect(nonEmpty.contains("匹配结果: 1 (query: playwright)"))
        #expect(nonEmpty.contains("nolon mcp add <slug> --provider codex --dry-run"))
    }

    @Test("RemoteCatalogItemMapper converts between catalog items and remote models")
    func remoteCatalogItemMapperConvertsItems() {
        let mapper = RemoteCatalogItemMapper()
        let catalog = SkillsRepositoryFacade.RemoteCatalogItem(
            kind: .mcp,
            slug: "playwright-mcp",
            displayName: "Playwright MCP",
            summary: "browser automation",
            latestVersion: "1.0.0",
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            downloads: 10,
            stars: 5,
            installs: 3,
            localPath: "/tmp/playwright.json"
        )

        let mcp = mapper.toRemoteMCP(catalog)
        #expect(mcp.slug == "playwright-mcp")
        #expect(mcp.stats?.installs == 3)
        #expect(mcp.localPath == "/tmp/playwright.json")

        let roundTrip = mapper.toCatalogItem(mcp)
        #expect(roundTrip.slug == "playwright-mcp")
        #expect(roundTrip.latestVersion == "1.0.0")
        #expect(roundTrip.localPath == "/tmp/playwright.json")
    }

    @Test("ResourceListTextPresenter renders skills show-fixes skeleton")
    func resourceListTextPresenterRendersSkillsFixes() {
        let presenter = ResourceListTextPresenter()
        let text = presenter.render(
            .init(
                kind: .skill,
                providerFilter: nil,
                stateFilter: nil,
                items: [
                    .init(providerID: "codex", resourceID: "find-skills", state: .broken, path: "/tmp/find-skills", originDescription: "远端(repo)"),
                ],
                summary: .init(
                    providersScanned: 5,
                    providersMatched: 1,
                    totalCount: 1,
                    installedCount: 0,
                    orphanedCount: 0,
                    brokenCount: 1
                ),
                verbose: true,
                showFixes: true
            )
        )

        #expect(text.contains("[下一步（按顺序执行）]"))
        #expect(text.contains("修复损坏"))
        #expect(text.contains("nolon skills remove --skill-id find-skills --provider codex"))
    }

    @Test("ProviderSkillSnapshotService loads installed and orphaned skills across provider paths")
    func providerSkillSnapshotServiceLoadsSkills() throws {
        let root = try STFolder(sanbox: .temporary)
            .folder("nolon-skill-snapshot-\(UUID().uuidString)")
            .create()
        defer { try? root.deleteIncludingBrokenSymlink() }

        let nolonHome = root.folder(".nolon")
        _ = nolonHome.createIfNotExists()
        let manager = NolonManager(rootURL: nolonHome.url)

        let providerRoot = root.folder("provider")
        let defaultSkills = providerRoot.folder("skills")
        let additionalSkills = providerRoot.folder("extra-skills")
        _ = defaultSkills.createIfNotExists()
        _ = additionalSkills.createIfNotExists()

        let globalLinkedSkill = manager.skillsFolder.folder("linked-skill")
        _ = globalLinkedSkill.createIfNotExists()
        try """
        ---
        name: Linked Skill
        description: linked
        version: 1.0.0
        ---
        """.write(to: globalLinkedSkill.file("SKILL.md").url, atomically: true, encoding: .utf8)

        try defaultSkills.subpath("linked-skill").createSymbolicLink(to: globalLinkedSkill)
        try defaultSkills.subpath("broken-skill").createSymbolicLink(to: STPath("/tmp/does-not-exist-\(UUID().uuidString)"))

        let orphanedSkill = additionalSkills.folder("orphaned-skill")
        _ = orphanedSkill.createIfNotExists()
        try """
        ---
        name: Orphaned Skill
        description: orphaned
        version: 1.0.0
        ---
        """.write(to: orphanedSkill.file("SKILL.md").url, atomically: true, encoding: .utf8)

        let provider = Provider(
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: defaultSkills.url.path,
            workflowPath: providerRoot.folder("prompts").url.path,
            additionalSkillsPaths: [additionalSkills.url.path]
        )

        let service = ProviderSkillSnapshotService(nolonManager: manager)
        let skills = try service.load(provider: provider)

        #expect(skills.count == 2)
        #expect(Set(skills.map(\.id)) == Set(["linked-skill", "orphaned-skill"]))

        let linked = skills.first(where: { $0.id == "linked-skill" })
        #expect(linked?.installationState == .installed)
        #expect(linked?.sourcePath == defaultSkills.url.path)

        let orphaned = skills.first(where: { $0.id == "orphaned-skill" })
        #expect(orphaned?.installationState == .orphaned)
        #expect(orphaned?.sourcePath == additionalSkills.url.path)
    }

    @Test("ProviderSkillSnapshotService resolves symlinked default skills root before scanning")
    func providerSkillSnapshotServiceResolvesSymlinkedDefaultRoot() throws {
        let root = try STFolder(sanbox: .temporary)
            .folder("nolon-skill-snapshot-symlink-\(UUID().uuidString)")
            .create()
        defer { try? root.deleteIncludingBrokenSymlink() }

        let nolonHome = root.folder(".nolon")
        _ = nolonHome.createIfNotExists()
        let manager = NolonManager(rootURL: nolonHome.url)

        let globalSkill = manager.skillsFolder.folder("find-skills")
        _ = globalSkill.createIfNotExists()
        try """
        ---
        name: Find Skills
        description: test
        version: 1.0.0
        ---
        """.write(to: globalSkill.file("SKILL.md").url, atomically: true, encoding: .utf8)

        let providerRoot = root.folder("provider")
        _ = providerRoot.createIfNotExists()
        let providerSkillsPath = providerRoot.subpath("skills")
        try providerSkillsPath.createSymbolicLink(to: STPath(manager.skillsFolder.url.path))

        let provider = Provider(
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: providerSkillsPath.url.path,
            workflowPath: providerRoot.folder("prompts").url.path
        )

        let service = ProviderSkillSnapshotService(nolonManager: manager)
        let skills = try service.load(provider: provider)

        #expect(skills.count == 1)
        #expect(skills.first?.id == "find-skills")
        #expect(skills.first?.installationState == .installed)
    }
}
