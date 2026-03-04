import XCTest
@testable import nolon

final class XcodeMCPKitInstallServiceTests: XCTestCase {
    override func tearDown() {
        URLProtocol.unregisterClass(MockURLProtocol.self)
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testInstallLatest_WhenReleaseContainsLegacyBinaryNames_InstallsAndWritesMetadata() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("nolon-install-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let archiveData = try makeLegacyArchiveData()
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else {
                throw URLError(.badURL)
            }
            if url.absoluteString.contains("/releases?per_page=20") {
                let body = """
                [
                  {
                    "tag_name": "v1.2.3",
                    "prerelease": false,
                    "draft": false,
                    "assets": [
                      {
                        "name": "xcode-mcp-proxy-darwin-arm64.tar.gz",
                        "browser_download_url": "https://example.com/xcode-mcp-proxy-darwin-arm64.tar.gz"
                      }
                    ]
                  }
                ]
                """
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data(body.utf8))
            }
            if url.absoluteString == "https://example.com/xcode-mcp-proxy-darwin-arm64.tar.gz" {
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, archiveData)
            }
            throw URLError(.unsupportedURL)
        }

        URLProtocol.registerClass(MockURLProtocol.self)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let service = XcodeMCPKitInstallService(
            session: session,
            fileManager: .default,
            dateProvider: { Date(timeIntervalSince1970: 1_700_000_000) },
            nolonRootURL: root
        )

        let version = try await service.installLatest()
        XCTAssertEqual(version, "v1.2.3")

        let binDir = root.appendingPathComponent("bin", isDirectory: true)
        let runtime = binDir.appendingPathComponent("xcodemcpkit", isDirectory: false).path
        let server = binDir.appendingPathComponent("xcode-mcp-server", isDirectory: false).path
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: runtime))
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: server))

        let versionFile = root
            .appendingPathComponent("plugins", isDirectory: true)
            .appendingPathComponent("xcodemcpkit", isDirectory: true)
            .appendingPathComponent("installed_version.txt", isDirectory: false)
        let writtenVersion = try String(contentsOf: versionFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(writtenVersion, "v1.2.3")

        let globalMcp = root
            .appendingPathComponent("mcps", isDirectory: true)
            .appendingPathComponent("xcodemcpkit.json", isDirectory: false)
        let payload = try Data(contentsOf: globalMcp)
        let json = try JSONSerialization.jsonObject(with: payload) as? [String: Any]
        let mcpServers = json?["mcpServers"] as? [String: Any]
        let entry = mcpServers?["xcodemcpkit"] as? [String: Any]
        XCTAssertEqual(entry?["command"] as? String, "xcode-mcp-server")
    }

    func testInstallLatest_WhenNoStableRelease_ThrowsReleaseNotFound() async {
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            let body = """
            [
              {
                "tag_name": "v1.2.3-beta.1",
                "prerelease": true,
                "draft": false,
                "assets": []
              }
            ]
            """
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(body.utf8))
        }

        URLProtocol.registerClass(MockURLProtocol.self)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let service = XcodeMCPKitInstallService(session: session)

        do {
            _ = try await service.installLatest()
            XCTFail("Expected releaseNotFound")
        } catch let error as XcodeMCPKitInstallError {
            XCTAssertEqual(error, .releaseNotFound)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testInstallLatest_WhenNoCompatibleAsset_ThrowsAssetNotFound() async {
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            let body = """
            [
              {
                "tag_name": "v1.2.3",
                "prerelease": false,
                "draft": false,
                "assets": [
                  {
                    "name": "linux-x64.tar.gz",
                    "browser_download_url": "https://example.com/linux-x64.tar.gz"
                  }
                ]
              }
            ]
            """
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(body.utf8))
        }

        URLProtocol.registerClass(MockURLProtocol.self)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let service = XcodeMCPKitInstallService(session: session)

        do {
            _ = try await service.installLatest()
            XCTFail("Expected assetNotFound")
        } catch let error as XcodeMCPKitInstallError {
            XCTAssertEqual(error, .assetNotFound)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testInstallLatest_WhenReleaseRequestHTTPError_ThrowsHTTPFailed() async {
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            let response = HTTPURLResponse(url: url, statusCode: 429, httpVersion: nil, headerFields: nil)!
            return (response, Data("{}".utf8))
        }

        URLProtocol.registerClass(MockURLProtocol.self)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let service = XcodeMCPKitInstallService(session: session)

        do {
            _ = try await service.installLatest()
            XCTFail("Expected httpFailed")
        } catch let error as XcodeMCPKitInstallError {
            XCTAssertEqual(error, .httpFailed(429))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testInstallLatest_WhenArchiveCorrupted_ThrowsExtractionFailed() async {
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            if url.absoluteString.contains("/releases?per_page=20") {
                let body = """
                [
                  {
                    "tag_name": "v1.2.3",
                    "prerelease": false,
                    "draft": false,
                    "assets": [
                      {
                        "name": "xcode-mcp-proxy-darwin-arm64.tar.gz",
                        "browser_download_url": "https://example.com/corrupted.tar.gz"
                      }
                    ]
                  }
                ]
                """
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data(body.utf8))
            }
            if url.absoluteString == "https://example.com/corrupted.tar.gz" {
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data("not-a-tar-gz".utf8))
            }
            throw URLError(.unsupportedURL)
        }

        URLProtocol.registerClass(MockURLProtocol.self)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let service = XcodeMCPKitInstallService(session: session)

        do {
            _ = try await service.installLatest()
            XCTFail("Expected extractionFailed")
        } catch let error as XcodeMCPKitInstallError {
            if case .extractionFailed = error {
                XCTAssertTrue(true)
            } else {
                XCTFail("Unexpected install error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testUninstall_WhenManagedMcpAndArtifactsExist_RemovesAllPluginArtifacts() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("nolon-uninstall-test-\(UUID().uuidString)", isDirectory: true)
        let fm = FileManager.default
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let binDir = root.appendingPathComponent("bin", isDirectory: true)
        try fm.createDirectory(at: binDir, withIntermediateDirectories: true)
        let runtime = binDir.appendingPathComponent("xcodemcpkit", isDirectory: false)
        let server = binDir.appendingPathComponent("xcode-mcp-server", isDirectory: false)
        try "runtime".write(to: runtime, atomically: true, encoding: .utf8)
        try "server".write(to: server, atomically: true, encoding: .utf8)

        let pluginDir = root
            .appendingPathComponent("plugins", isDirectory: true)
            .appendingPathComponent("xcodemcpkit", isDirectory: true)
        try fm.createDirectory(at: pluginDir, withIntermediateDirectories: true)
        try "v1.2.3".write(
            to: pluginDir.appendingPathComponent("installed_version.txt", isDirectory: false),
            atomically: true,
            encoding: .utf8
        )

        let mcpsDir = root.appendingPathComponent("mcps", isDirectory: true)
        try fm.createDirectory(at: mcpsDir, withIntermediateDirectories: true)
        let managedMcp = mcpsDir.appendingPathComponent("xcodemcpkit.json", isDirectory: false)
        let managedPayload = """
        {
          "mcpServers": {
            "xcodemcpkit": {
              "command": "xcode-mcp-server",
              "nolon_plugin": {
                "managed": true,
                "plugin_id": "xcodemcpkit"
              }
            }
          }
        }
        """
        try managedPayload.write(to: managedMcp, atomically: true, encoding: .utf8)

        let service = XcodeMCPKitInstallService(
            fileManager: fm,
            nolonRootURL: root
        )
        try await service.uninstall()

        XCTAssertFalse(fm.fileExists(atPath: runtime.path))
        XCTAssertFalse(fm.fileExists(atPath: server.path))
        XCTAssertFalse(fm.fileExists(atPath: pluginDir.path))
        XCTAssertFalse(fm.fileExists(atPath: managedMcp.path))
    }

    func testUninstall_WhenMcpIsNotPluginManaged_KeepsGlobalMcpFile() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("nolon-uninstall-keep-mcp-\(UUID().uuidString)", isDirectory: true)
        let fm = FileManager.default
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let mcpsDir = root.appendingPathComponent("mcps", isDirectory: true)
        try fm.createDirectory(at: mcpsDir, withIntermediateDirectories: true)
        let mcp = mcpsDir.appendingPathComponent("xcodemcpkit.json", isDirectory: false)
        let unmanagedPayload = """
        {
          "mcpServers": {
            "xcodemcpkit": {
              "command": "xcode-mcp-server"
            }
          }
        }
        """
        try unmanagedPayload.write(to: mcp, atomically: true, encoding: .utf8)

        let service = XcodeMCPKitInstallService(
            fileManager: fm,
            nolonRootURL: root
        )
        try await service.uninstall()

        XCTAssertTrue(fm.fileExists(atPath: mcp.path))
    }

    func testInstallLatest_WhenInstallSucceeded_CallsBinarySignerForInstalledExecutables() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("nolon-install-sign-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let archiveData = try makeLegacyArchiveData()
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            if url.absoluteString.contains("/releases?per_page=20") {
                let body = """
                [
                  {
                    "tag_name": "v1.2.4",
                    "prerelease": false,
                    "draft": false,
                    "assets": [
                      {
                        "name": "xcode-mcp-proxy-darwin-arm64.tar.gz",
                        "browser_download_url": "https://example.com/xcode-mcp-proxy-darwin-arm64.tar.gz"
                      }
                    ]
                  }
                ]
                """
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data(body.utf8))
            }
            if url.absoluteString == "https://example.com/xcode-mcp-proxy-darwin-arm64.tar.gz" {
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, archiveData)
            }
            throw URLError(.unsupportedURL)
        }

        URLProtocol.registerClass(MockURLProtocol.self)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        var signedPaths: [String] = []
        let service = XcodeMCPKitInstallService(
            session: session,
            fileManager: .default,
            dateProvider: { Date(timeIntervalSince1970: 1_700_000_000) },
            nolonRootURL: root,
            binarySigner: { signedPaths.append($0.path) }
        )

        _ = try await service.installLatest()

        let runtime = root.appendingPathComponent("bin/xcodemcpkit", isDirectory: false).path
        let server = root.appendingPathComponent("bin/xcode-mcp-server", isDirectory: false).path
        XCTAssertEqual(Set(signedPaths), Set([runtime, server]))
    }

    private func makeLegacyArchiveData() throws -> Data {
        let fm = FileManager.default
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("nolon-install-archive-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmp) }

        let bin = tmp.appendingPathComponent("bin", isDirectory: true)
        try fm.createDirectory(at: bin, withIntermediateDirectories: true)

        let runtime = bin.appendingPathComponent("xcode-mcp-proxy-server", isDirectory: false)
        let server = bin.appendingPathComponent("xcode-mcp-proxy", isDirectory: false)
        try "#!/bin/sh\necho runtime\n".write(to: runtime, atomically: true, encoding: .utf8)
        try "#!/bin/sh\necho server\n".write(to: server, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: runtime.path)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: server.path)

        let archive = tmp.appendingPathComponent("pkg.tar.gz", isDirectory: false)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["-czf", archive.path, "-C", tmp.path, "bin"]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
        return try Data(contentsOf: archive)
    }
}

private final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
