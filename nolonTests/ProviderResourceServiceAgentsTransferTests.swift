import XCTest
import STFilePath
import NolonResourceKit

final class ProviderResourceServiceAgentsTransferTests: XCTestCase {
    func testBDD_GivenProviderAgentsFile_WhenCopyToNolon_ThenSourceRemainsAndDestinationCreated() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("nolon-agent-copy-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = NolonManager(rootURL: root)
        let service = ProviderResourceService(nolonManager: manager)
        let providerFolder = root.appendingPathComponent("provider-codex", isDirectory: true)
        try FileManager.default.createDirectory(at: providerFolder, withIntermediateDirectories: true)
        let source = providerFolder.appendingPathComponent("AGENTS.md")
        try "# Provider Agents".write(to: source, atomically: true, encoding: .utf8)

        let copied = try service.copyAgentDocToNolon(atPath: source.path)

        XCTAssertTrue(STFile(source).isExists)
        XCTAssertTrue(STFile(copied).isExists)
        XCTAssertEqual(
            copied.deletingLastPathComponent().standardizedFileURL.path,
            manager.agentsURL.standardizedFileURL.path
        )
    }

    func testBDD_GivenNameConflict_WhenMoveToNolon_ThenUsesCopySuffixAndRemovesSource() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("nolon-agent-move-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = NolonManager(rootURL: root)
        let service = ProviderResourceService(nolonManager: manager)
        let providerFolder = root.appendingPathComponent("provider-codex", isDirectory: true)
        try FileManager.default.createDirectory(at: providerFolder, withIntermediateDirectories: true)

        let source = providerFolder.appendingPathComponent("AGENTS.md")
        try "# Provider Agents".write(to: source, atomically: true, encoding: .utf8)
        try "# Existing".write(
            to: manager.agentsURL.appendingPathComponent("AGENTS.md"),
            atomically: true,
            encoding: .utf8
        )

        let moved = try service.moveAgentDocToNolon(atPath: source.path)

        XCTAssertFalse(STFile(source).isExists)
        XCTAssertTrue(STFile(moved).isExists)
        XCTAssertEqual(moved.lastPathComponent, "AGENTS-copy-1.md")
    }
}
