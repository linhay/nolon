import XCTest
import NolonResourceKit

final class RemoteMCPInstallStatusResolverTests: XCTestCase {
    func testBDD_GivenGlobalCacheFiles_WhenResolvingInstalledMCPIDs_ThenReturnsJsonAndLegacyNames() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("remote-mcp-cache-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = NolonManager(rootURL: root)
        let statusService = InstalledResourceStatusService(nolonManager: manager)
        let mcpsRoot = root.appendingPathComponent("mcps", isDirectory: true)
        try FileManager.default.createDirectory(at: mcpsRoot, withIntermediateDirectories: true)

        try "{}".write(to: mcpsRoot.appendingPathComponent("stdio-server.json"), atomically: true, encoding: .utf8)
        try "{}".write(to: mcpsRoot.appendingPathComponent("legacy-server"), atomically: true, encoding: .utf8)
        try "".write(to: mcpsRoot.appendingPathComponent(".DS_Store"), atomically: true, encoding: .utf8)

        let ids = try statusService.installedMcpIDsStrict(provider: nil)
        XCTAssertEqual(ids, Set(["stdio-server", "legacy-server"]))
    }

    func testBDD_GivenEmptyGlobalCache_WhenResolvingInstalledMCPIDs_ThenReturnsEmptySet() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("remote-mcp-empty-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = NolonManager(rootURL: root)
        let statusService = InstalledResourceStatusService(nolonManager: manager)

        let ids = try statusService.installedMcpIDsStrict(provider: nil)
        XCTAssertTrue(ids.isEmpty)
    }
}
