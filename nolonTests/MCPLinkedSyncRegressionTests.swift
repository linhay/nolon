import XCTest
import ProviderCatalog
import NolonResourceKit
import STFilePath

final class MCPLinkedSyncRegressionTests: XCTestCase {
    func testDeletingAllCacheFragmentsClearsCodexProjection() throws {
        try withIsolatedNolonHome { root in
            let manager = NolonManager.shared
            _ = manager.mcpsFolder.createIfNotExists()
            let beforeNames = Set(try MCPConfigManager.listServers(for: .codex).map(\.name))

            let alphaName = "reg-alpha-\(UUID().uuidString.prefix(8))"
            let betaName = "reg-beta-\(UUID().uuidString.prefix(8))"
            let alpha = manager.mcpsURL.appendingPathComponent("\(alphaName).json")
            let beta = manager.mcpsURL.appendingPathComponent("\(betaName).json")
            try writeCacheFragment(
                to: alpha,
                name: alphaName,
                server: [
                    "command": "npx",
                    "args": ["-y", "@acme/alpha-mcp"],
                    "enabled": true
                ]
            )
            try writeCacheFragment(
                to: beta,
                name: betaName,
                server: [
                    "url": "http://localhost:8081/mcp",
                    "enabled": true
                ]
            )

            let configPath = ProviderTemplate.codex.defaultMcpConfigPath
            _ = STFolder(configPath.deletingLastPathComponent()).createIfNotExists()
            try """
            [mcp_servers.legacy]
            command = "legacy"
            """.write(to: configPath, atomically: true, encoding: .utf8)

            _ = try MCPConfigManager.syncAllCacheServersToProvider(for: .codex)
            let withNewNames = Set(try MCPConfigManager.listServers(for: .codex).map(\.name))
            XCTAssertTrue(withNewNames.contains(alphaName))
            XCTAssertTrue(withNewNames.contains(betaName))

            try STFile(alpha).deleteIncludingBrokenSymlink()
            try STFile(beta).deleteIncludingBrokenSymlink()

            _ = try MCPConfigManager.syncAllCacheServersToProvider(for: .codex)
            let afterDeleteNames = Set(try MCPConfigManager.listServers(for: .codex).map(\.name))
            XCTAssertFalse(afterDeleteNames.contains(alphaName))
            XCTAssertFalse(afterDeleteNames.contains(betaName))
            XCTAssertTrue(beforeNames.isSubset(of: afterDeleteNames))
        }
    }

    func testLinkedSyncIsIdempotentForCodexConfig() throws {
        try withIsolatedNolonHome { _ in
            let manager = NolonManager.shared
            _ = manager.mcpsFolder.createIfNotExists()

            let zetaName = "reg-zeta-\(UUID().uuidString.prefix(8))"
            let alphaName = "reg-alpha-\(UUID().uuidString.prefix(8))"
            let zeta = manager.mcpsURL.appendingPathComponent("\(zetaName).json")
            let alpha = manager.mcpsURL.appendingPathComponent("\(alphaName).json")
            try writeCacheFragment(
                to: zeta,
                name: zetaName,
                server: [
                    "command": "npx",
                    "args": ["-y", "@acme/zeta-mcp"],
                    "enabled": true
                ]
            )
            try writeCacheFragment(
                to: alpha,
                name: alphaName,
                server: [
                    "url": "http://localhost:8088/mcp",
                    "enabled": true
                ]
            )

            let configPath = ProviderTemplate.codex.defaultMcpConfigPath
            _ = STFolder(configPath.deletingLastPathComponent()).createIfNotExists()
            try "".write(to: configPath, atomically: true, encoding: .utf8)

            _ = try MCPConfigManager.syncAllCacheServersToProvider(for: .codex)
            let first = try Data(contentsOf: configPath)

            _ = try MCPConfigManager.syncAllCacheServersToProvider(for: .codex)
            let second = try Data(contentsOf: configPath)
            _ = try MCPConfigManager.syncAllCacheServersToProvider(for: .codex)
            let third = try Data(contentsOf: configPath)

            // First run may normalize existing provider entries; subsequent syncs must be stable.
            XCTAssertEqual(second, third)
            XCTAssertFalse(second.isEmpty)
            XCTAssertFalse(first.isEmpty)
        }
    }
}

private extension MCPLinkedSyncRegressionTests {
    func withIsolatedNolonHome(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "nolon-mcp-linked-sync-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let previousHome = getenv("HOME").map { String(cString: $0) }
        let previousNolonHome = getenv("NOLON_HOME").map { String(cString: $0) }
        setenv("HOME", root.path, 1)
        setenv("NOLON_HOME", root.appendingPathComponent(".nolon", isDirectory: true).path, 1)
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

        try body(root)
    }

    func writeCacheFragment(to path: URL, name: String, server: [String: Any]) throws {
        let payload: [String: Any] = [
            "mcpServers": [
                name: server
            ]
        ]
        let data = try JSONSerialization.data(
            withJSONObject: payload,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        try data.write(to: path, options: .atomic)
    }
}
