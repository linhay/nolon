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

    @Test("loader bootstraps template config into NOLON_HOME cli directory")
    func loaderBootstrapsConfigFileToCLIHome() {
        let isolatedRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("provider-template-loader-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: isolatedRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: isolatedRoot) }

        let loader = ProviderTemplateLoader(
            environment: ["NOLON_HOME": isolatedRoot.path],
            userHomeURL: isolatedRoot
        )
        loader.load()

        let configFile = STFile(isolatedRoot.appendingPathComponent("cli/ProviderTemplate.json", isDirectory: false))
        #expect(configFile.isExists)
        let data = try? configFile.data()
        #expect(data?.isEmpty == false)
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
