import XCTest
import ProviderCatalog
import NolonResourceKit
import STFilePath

final class ProviderAgentsLinkServiceTests: XCTestCase {
    func testEnableAndDisableAgentsLinkPreservesLocalFiles() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "nolon-agents-link-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = NolonManager(rootURL: root.appendingPathComponent(".nolon", isDirectory: true))
        let service = ProviderAgentsLinkService(nolonManager: manager)

        let codexHome = root.appendingPathComponent(".codex", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: codexHome.appendingPathComponent("skills", isDirectory: true).path,
            workflowPath: codexHome.appendingPathComponent("prompts", isDirectory: true).path,
            templateId: "codex"
        )

        let base = provider.codexAgentsFile
        let override = provider.codexAgentsOverrideFile
        try "local-base".write(to: base.url, atomically: true, encoding: .utf8)
        try "local-override".write(to: override.url, atomically: true, encoding: .utf8)

        try service.applyEnable(provider: provider)

        XCTAssertTrue(STPath(base.url).isSymbolicLink)
        XCTAssertTrue(STPath(override.url).isSymbolicLink)
        XCTAssertTrue(manager.agentsFolder.file("AGENTS.md").isExists)
        XCTAssertTrue(manager.agentsFolder.file("AGENTS.override.md").isExists)

        try "global-base".write(
            to: manager.agentsFolder.file("AGENTS.md").url,
            atomically: true,
            encoding: .utf8
        )

        try service.applyDisable(provider: provider)

        XCTAssertFalse(STPath(base.url).isSymbolicLink)
        XCTAssertFalse(STPath(override.url).isSymbolicLink)
        XCTAssertEqual(try base.read(), "local-base")
        XCTAssertEqual(try override.read(), "local-override")
    }

    func testEnableAgentsLinkForOpenCodeWithoutExistingFileCreatesSymlink() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "nolon-agents-link-opencode-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = NolonManager(rootURL: root.appendingPathComponent(".nolon", isDirectory: true))
        let service = ProviderAgentsLinkService(nolonManager: manager)

        let opencodeHome = root.appendingPathComponent(".config/opencode", isDirectory: true)
        let skills = opencodeHome.appendingPathComponent("skills", isDirectory: true)
        try FileManager.default.createDirectory(at: skills, withIntermediateDirectories: true)
        let provider = Provider(
            name: "OpenCode",
            defaultSkillsPath: skills.path,
            workflowPath: opencodeHome.appendingPathComponent("commands", isDirectory: true).path,
            templateId: "opencode"
        )

        let providerAgents = STFile(opencodeHome.appendingPathComponent("AGENTS.md", isDirectory: false))
        XCTAssertFalse(providerAgents.isExists)

        try service.applyEnable(provider: provider)

        XCTAssertTrue(STPath(providerAgents.url).isSymbolicLink)
        XCTAssertTrue(manager.agentsFolder.file("AGENTS.md").isExists)
    }

    func testDisableAgentsLinkForOpenCodeWithoutBackupRemovesSymlink() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "nolon-agents-link-opencode-disable-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = NolonManager(rootURL: root.appendingPathComponent(".nolon", isDirectory: true))
        let service = ProviderAgentsLinkService(nolonManager: manager)

        let opencodeHome = root.appendingPathComponent(".config/opencode", isDirectory: true)
        let skills = opencodeHome.appendingPathComponent("skills", isDirectory: true)
        try FileManager.default.createDirectory(at: skills, withIntermediateDirectories: true)
        let provider = Provider(
            name: "OpenCode",
            defaultSkillsPath: skills.path,
            workflowPath: opencodeHome.appendingPathComponent("commands", isDirectory: true).path,
            templateId: "opencode"
        )

        let providerAgents = STFile(opencodeHome.appendingPathComponent("AGENTS.md", isDirectory: false))

        try service.applyEnable(provider: provider)
        XCTAssertTrue(STPath(providerAgents.url).isSymbolicLink)

        try service.applyDisable(provider: provider)

        XCTAssertFalse(providerAgents.isExists)
        XCTAssertFalse(STPath(providerAgents.url).isSymbolicLink)
    }

    func testEnableAgentsLinkForCopilotWithoutExistingFileCreatesSymlink() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "nolon-agents-link-copilot-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = NolonManager(rootURL: root.appendingPathComponent(".nolon", isDirectory: true))
        let service = ProviderAgentsLinkService(nolonManager: manager)

        let copilotHome = root.appendingPathComponent(".copilot", isDirectory: true)
        let skills = copilotHome.appendingPathComponent("skills", isDirectory: true)
        try FileManager.default.createDirectory(at: skills, withIntermediateDirectories: true)
        let provider = Provider(
            name: "GitHub Copilot",
            defaultSkillsPath: skills.path,
            workflowPath: copilotHome.appendingPathComponent("workflows", isDirectory: true).path,
            templateId: "copilot"
        )

        let providerAgents = STFile(copilotHome.appendingPathComponent("AGENTS.md", isDirectory: false))
        XCTAssertFalse(providerAgents.isExists)

        try service.applyEnable(provider: provider)

        XCTAssertTrue(STPath(providerAgents.url).isSymbolicLink)
        XCTAssertTrue(manager.agentsFolder.file("AGENTS.md").isExists)
    }

    func testDisableAgentsLinkForCopilotWithoutBackupRemovesSymlink() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "nolon-agents-link-copilot-disable-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = NolonManager(rootURL: root.appendingPathComponent(".nolon", isDirectory: true))
        let service = ProviderAgentsLinkService(nolonManager: manager)

        let copilotHome = root.appendingPathComponent(".copilot", isDirectory: true)
        let skills = copilotHome.appendingPathComponent("skills", isDirectory: true)
        try FileManager.default.createDirectory(at: skills, withIntermediateDirectories: true)
        let provider = Provider(
            name: "GitHub Copilot",
            defaultSkillsPath: skills.path,
            workflowPath: copilotHome.appendingPathComponent("workflows", isDirectory: true).path,
            templateId: "copilot"
        )

        let providerAgents = STFile(copilotHome.appendingPathComponent("AGENTS.md", isDirectory: false))

        try service.applyEnable(provider: provider)
        XCTAssertTrue(STPath(providerAgents.url).isSymbolicLink)

        try service.applyDisable(provider: provider)

        XCTAssertFalse(providerAgents.isExists)
        XCTAssertFalse(STPath(providerAgents.url).isSymbolicLink)
    }

    func testEnableAndDisableAgentsLinkForClaudePreservesLocalClaudeFileAndLinksToGlobalAgents() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "nolon-agents-link-claude-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = NolonManager(rootURL: root.appendingPathComponent(".nolon", isDirectory: true))
        let service = ProviderAgentsLinkService(nolonManager: manager)

        let claudeHome = root.appendingPathComponent(".claude", isDirectory: true)
        let skills = claudeHome.appendingPathComponent("skills", isDirectory: true)
        try FileManager.default.createDirectory(at: skills, withIntermediateDirectories: true)
        let provider = Provider(
            name: "Claude Code",
            defaultSkillsPath: skills.path,
            workflowPath: claudeHome.appendingPathComponent("workflows", isDirectory: true).path,
            templateId: ProviderTemplate.claudeCode.rawValue
        )

        let providerInstructions = STFile(claudeHome.appendingPathComponent("CLAUDE.md", isDirectory: false))
        try "local-claude".write(to: providerInstructions.url, atomically: true, encoding: .utf8)

        try service.applyEnable(provider: provider)

        XCTAssertTrue(STPath(providerInstructions.url).isSymbolicLink)
        XCTAssertTrue(manager.agentsFolder.file("AGENTS.md").isExists)
        let destination = try STPath(providerInstructions.url).destinationOfSymbolicLink().url.standardizedFileURL.path
        XCTAssertEqual(destination, manager.agentsFolder.file("AGENTS.md").url.standardizedFileURL.path)

        try service.applyDisable(provider: provider)

        XCTAssertFalse(STPath(providerInstructions.url).isSymbolicLink)
        XCTAssertEqual(try providerInstructions.read(), "local-claude")
    }
}
