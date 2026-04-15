import XCTest
import ProviderCatalog
import NolonResourceKit
import STFilePath
import TOML
@testable import nolon

final class MCPLinkedSyncRegressionTests: XCTestCase {
    func testDeletingAllCacheFragmentsOnlyPrunesManagedCodexProjection() throws {
        try withIsolatedNolonHome { root in
            let manager = NolonManager()
            _ = manager.mcpsFolder.createIfNotExists()
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
                ],
                providers: ["codex"]
            )
            try writeCacheFragment(
                to: beta,
                name: betaName,
                server: [
                    "url": "http://localhost:8081/mcp",
                    "enabled": true
                ],
                providers: ["codex"]
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
            XCTAssertTrue(withNewNames.contains("legacy"))

            try STFile(alpha).deleteIncludingBrokenSymlink()
            try STFile(beta).deleteIncludingBrokenSymlink()

            _ = try MCPConfigManager.syncAllCacheServersToProvider(for: .codex)
            let afterDeleteNames = Set(try MCPConfigManager.listServers(for: .codex).map(\.name))
            XCTAssertFalse(afterDeleteNames.contains(alphaName))
            XCTAssertFalse(afterDeleteNames.contains(betaName))
            XCTAssertEqual(afterDeleteNames, ["legacy"])
        }
    }

    func testLinkedSyncIsIdempotentForCodexConfig() throws {
        try withIsolatedNolonHome { _ in
            let manager = NolonManager()
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
                ],
                providers: ["codex"]
            )
            try writeCacheFragment(
                to: alpha,
                name: alphaName,
                server: [
                    "url": "http://localhost:8088/mcp",
                    "enabled": true
                ],
                providers: ["codex"]
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

    @MainActor
    func testAppSetupRepairsStaleCodexMCPConfigBeforeWatcherSync() throws {
        try withIsolatedNolonHome { _ in
            let manager = NolonManager()
            _ = manager.mcpsFolder.createIfNotExists()

            let fragmentPath = manager.mcpsURL.appendingPathComponent("playwright.json")
            try writeCacheFragment(
                to: fragmentPath,
                name: "playwright",
                server: [
                    "command": "npx",
                    "args": ["@playwright/mcp@latest"],
                    "type": "stdio",
                    "http_headers": ["x-token": "abc"]
                ],
                providers: ["codex"]
            )

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

            let suiteName = "nolon-mcp-linked-sync-\(UUID().uuidString)"
            let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
            defer { userDefaults.removePersistentDomain(forName: suiteName) }

            let settings = ProviderSettings(userDefaults: userDefaults, nolonManager: manager)
            let viewModel = MainSplitViewModel(
                settings: settings,
                repository: SkillRepository(nolonManager: manager),
                nolonManager: manager,
                userDefaults: userDefaults
            )

            viewModel.setup()

            let fragmentRoot = try XCTUnwrap(
                JSONSerialization.jsonObject(with: Data(contentsOf: fragmentPath)) as? [String: Any]
            )
            let fragmentServers = try XCTUnwrap(fragmentRoot["mcpServers"] as? [String: Any])
            let playwrightFragment = try XCTUnwrap(fragmentServers["playwright"] as? [String: Any])
            XCTAssertNil(playwrightFragment["http_headers"])

            let rawConfig = try String(contentsOf: configPath, encoding: .utf8)
            XCTAssertFalse(rawConfig.contains("[mcp_servers.playwright.http_headers]"))
        }
    }

    func testLoopbackHTTPServerIsProjectedAsDisabledWhenUnavailable() throws {
        try withIsolatedNolonHome { _ in
            let manager = NolonManager()
            _ = manager.mcpsFolder.createIfNotExists()

            let name = "figma-desktop"
            let fragmentPath = manager.mcpsURL.appendingPathComponent("\(name).json")
            try writeCacheFragment(
                to: fragmentPath,
                name: name,
                server: [
                    "url": "http://127.0.0.1:1/mcp",
                    "enabled": true
                ],
                providers: ["codex"]
            )

            _ = try MCPConfigManager.syncAllCacheServersToProvider(for: .codex)

            let configPath = ProviderTemplate.codex.defaultMcpConfigPath
            let configData = try Data(contentsOf: configPath)
            let config = try TOMLDecoder().decode(CodexMCPConfig.self, from: configData)
            let server = try XCTUnwrap(config.mcpServers?[name])
            XCTAssertEqual(server.url, "http://127.0.0.1:1/mcp")
            XCTAssertEqual(server.enabled, false)
        }
    }

    func testSessionBoundXcodeServerIsProjectedAsDisabledWhenSessionEnvIsInvalid() throws {
        try withIsolatedNolonHome { _ in
            let manager = NolonManager()
            _ = manager.mcpsFolder.createIfNotExists()

            let name = "xcode-tools"
            let fragmentPath = manager.mcpsURL.appendingPathComponent("\(name).json")
            try writeCacheFragment(
                to: fragmentPath,
                name: name,
                server: [
                    "command": "xcode-build-mcp",
                    "args": ["serve"],
                    "env": [
                        "MCP_XCODE_PID": "999999",
                        "MCP_XCODE_SESSION_ID": "session-123"
                    ],
                    "enabled": true
                ],
                providers: ["codex"]
            )

            _ = try MCPConfigManager.syncAllCacheServersToProvider(for: .codex)

            let configPath = ProviderTemplate.codex.defaultMcpConfigPath
            let configData = try Data(contentsOf: configPath)
            let config = try TOMLDecoder().decode(CodexMCPConfig.self, from: configData)
            let server = try XCTUnwrap(config.mcpServers?[name])
            XCTAssertEqual(server.command, "xcode-build-mcp")
            XCTAssertEqual(server.enabled, false)
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

    func writeCacheFragment(
        to path: URL,
        name: String,
        server: [String: Any],
        providers: [String] = []
    ) throws {
        var payload: [String: Any] = [
            "mcpServers": [
                name: server
            ]
        ]
        if !providers.isEmpty {
            payload["x-nolon"] = ["providers": providers]
        }
        let data = try JSONSerialization.data(
            withJSONObject: payload,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        try data.write(to: path, options: .atomic)
    }
}
