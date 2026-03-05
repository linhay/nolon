import Foundation
import Testing
import STFilePath
@testable import ProviderCatalog

@Suite("ProviderCatalog Template")
struct ProviderCatalogTemplateTests {
    @Test("claudeCode alias resolves config loaded from claude key")
    func claudeCodeAlias() {
        let template = ProviderTemplate.claudeCode
        #expect(template.displayName == "Claude Code")
        #expect(template.defaultSkillsPath.path.hasSuffix(".claude/skills"))
    }

    @Test("codex template defaults to ~/.codex paths")
    func codexDefaultPaths() {
        let home = NSHomeDirectory()
        let template = ProviderTemplate.codex
        #expect(template.defaultSkillsPath.path.hasPrefix(home))
        #expect(template.defaultSkillsPath.path.hasSuffix(".codex/skills"))
        #expect(template.defaultWorkflowPath.path.hasSuffix(".codex/prompts"))
        #expect(template.defaultMcpConfigPath.path.hasSuffix(".codex/config.toml"))
    }

    @Test("provider template exposes cliName from built-in config")
    func providerTemplateCLIName() {
        #expect(ProviderTemplate.codex.cliName == "codex")
        #expect(ProviderTemplate.gemini.cliName == "gemini")
        #expect(ProviderTemplate.opencode.cliName == "opencode")
        #expect(ProviderTemplate.claudeCode.providerID == "claude")
    }

    @Test("gemini family templates expose usage vendor tab")
    func geminiFamilyUsageVendorTab() throws {
        let geminiTabs = try #require(ProviderTemplate.gemini.config?.vendorTabs)
        #expect(geminiTabs.contains("usage"))

        let antigravityTabs = try #require(ProviderTemplate.antigravity.config?.vendorTabs)
        #expect(antigravityTabs.contains("usage"))
    }

    @Test("resolve providerID supports stable ids and codex-xcode aliases")
    func resolveProviderID() {
        #expect(ProviderTemplate.resolve(providerID: "codex") == .codex)
        #expect(ProviderTemplate.resolve(providerID: "claude") == .claudeCode)
        #expect(ProviderTemplate.resolve(providerID: "codex-xcode") == .codexXcode)
        #expect(ProviderTemplate.resolve(providerID: "codexxcode") == .codexXcode)
        #expect(ProviderTemplate.resolve(providerID: "unknown-provider") == nil)
    }

    @Test("loader bootstraps template config into NOLON_HOME cli directory")
    func loaderBootstrapsConfigFileToCLIHome() {
        let isolatedRoot = STFolder("/tmp")
            .folder("provider-template-loader-\(UUID().uuidString)")
        _ = isolatedRoot.createIfNotExists()
        defer { try? isolatedRoot.delete() }

        let loader = ProviderTemplateLoader(
            environment: ["NOLON_HOME": isolatedRoot.url.path],
            userHomeURL: isolatedRoot.url
        )
        loader.load()

        let configFile = isolatedRoot.folder("cli").file("ProviderTemplate.json")
        #expect(configFile.isExists)
        let data = try? configFile.data()
        #expect(data?.isEmpty == false)
    }

    @Test("loader resolves relative NOLON_HOME against current directory")
    func loaderResolvesRelativeNolonHome() {
        let relative = "tmp/provider-template-loader-rel-\(UUID().uuidString)"
        let current = STFolder(FileManager.default.currentDirectoryPath)
        let expectedRoot = current.folder(relative)
        _ = expectedRoot.createIfNotExists()
        defer { try? expectedRoot.delete() }

        let loader = ProviderTemplateLoader(
            environment: ["NOLON_HOME": relative],
            userHomeURL: current.url
        )
        loader.load()

        let configFile = expectedRoot.folder("cli").file("ProviderTemplate.json")
        #expect(configFile.isExists)
    }

    @Test("provider exposes STPath views while keeping URL compatibility")
    func providerPathViews() {
        let provider = Provider(
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: "/tmp/a/skills",
            workflowPath: "/tmp/a/prompts",
            additionalSkillsPaths: ["/tmp/a/skills2", "/tmp/a/skills3"]
        )

        #expect(provider.path == STPath("/tmp/a/skills"))
        #expect(provider.additionalPaths == [STPath("/tmp/a/skills2"), STPath("/tmp/a/skills3")])
        #expect(provider.pathURL.path == provider.path.url.path)
        #expect(provider.additionalPathURLs.map(\.path) == provider.additionalPaths.map(\.url.path))
    }
}
