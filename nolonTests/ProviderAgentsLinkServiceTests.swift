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
}
