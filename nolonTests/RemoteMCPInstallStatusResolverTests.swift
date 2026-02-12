import XCTest
@testable import nolon

final class RemoteMCPInstallStatusResolverTests: XCTestCase {
    func testBDD_GivenGlobalCacheFiles_WhenResolvingSlugs_ThenReturnsJsonAndLegacyNames() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("remote-mcp-cache-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try "{}".write(to: root.appendingPathComponent("stdio-server.json"), atomically: true, encoding: .utf8)
        try "{}".write(to: root.appendingPathComponent("legacy-server"), atomically: true, encoding: .utf8)
        try "".write(to: root.appendingPathComponent(".DS_Store"), atomically: true, encoding: .utf8)

        let slugs = RemoteMCPInstallStatusResolver.slugsFromGlobalCache(at: root)

        XCTAssertEqual(slugs, Set(["stdio-server", "legacy-server"]))
    }

    func testBDD_GivenTomlConfig_WhenResolvingSlugs_ThenReturnsMcpServerKeys() throws {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("remote-mcp-toml-\(UUID().uuidString).toml")
        defer { try? FileManager.default.removeItem(at: file) }

        let content = """
        [mcp_servers.alpha]
        command = "node"

        [mcp_servers.beta]
        command = "python"
        """
        try content.write(to: file, atomically: true, encoding: .utf8)

        let slugs = RemoteMCPInstallStatusResolver.slugsFromProviderConfig(at: file, templateId: "codex")

        XCTAssertEqual(slugs, Set(["alpha", "beta"]))
    }

    func testBDD_GivenJsonMcpServers_WhenResolvingSlugs_ThenReturnsServerKeys() throws {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("remote-mcp-json-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: file) }

        let content = """
        {
          "mcpServers": {
            "s1": {"command": "node"},
            "s2": {"url": "https://example.com/mcp"}
          }
        }
        """
        try content.write(to: file, atomically: true, encoding: .utf8)

        let slugs = RemoteMCPInstallStatusResolver.slugsFromProviderConfig(at: file, templateId: "cursor")

        XCTAssertEqual(slugs, Set(["s1", "s2"]))
    }

    func testBDD_GivenOpenCodeJson_WhenResolvingSlugs_ThenUsesMcpField() throws {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("remote-mcp-opencode-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: file) }

        let content = """
        {
          "mcp": {
            "a": {"type": "local", "command": ["node", "server.js"]},
            "b": {"type": "remote", "url": "https://example.com/mcp"}
          }
        }
        """
        try content.write(to: file, atomically: true, encoding: .utf8)

        let slugs = RemoteMCPInstallStatusResolver.slugsFromProviderConfig(at: file, templateId: "opencode")

        XCTAssertEqual(slugs, Set(["a", "b"]))
    }
}
