import Foundation
import NolonResourceKit
import SKProcessRunner

enum XcodeMCPKitInstallError: LocalizedError, Equatable {
    case releaseNotFound
    case assetNotFound
    case binaryMissing(String)
    case extractionFailed(String)
    case httpFailed(Int)

    var errorDescription: String? {
        switch self {
        case .releaseNotFound:
            return "No available XcodeMCPKit release found."
        case .assetNotFound:
            return "No compatible macOS release asset found."
        case let .binaryMissing(name):
            return "Missing binary in package: \(name)"
        case let .extractionFailed(message):
            return "Failed to extract package: \(message)"
        case let .httpFailed(code):
            return "HTTP request failed with status code \(code)."
        }
    }
}

protocol XcodeMCPKitInstallServicing {
    func installLatest() async throws -> String
}

struct XcodeMCPKitInstallService: XcodeMCPKitInstallServicing {
    private struct GitHubRelease: Decodable {
        struct Asset: Decodable {
            let name: String
            let browser_download_url: String
        }

        let tag_name: String
        let prerelease: Bool
        let draft: Bool
        let assets: [Asset]
    }

    private let session: URLSession
    private let fileManager: FileManager
    private let dateProvider: @Sendable () -> Date
    private let nolonRootURL: URL

    init(
        session: URLSession = .shared,
        fileManager: FileManager = .default,
        dateProvider: @escaping @Sendable () -> Date = { Date() },
        nolonRootURL: URL = NolonManager.shared.rootURL
    ) {
        self.session = session
        self.fileManager = fileManager
        self.dateProvider = dateProvider
        self.nolonRootURL = nolonRootURL
    }

    func installLatest() async throws -> String {
        let release = try await fetchLatestRelease()
        let asset = try selectAsset(from: release.assets)

        let tmpDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tmpDir) }

        let archiveURL = tmpDir.appendingPathComponent(asset.name)
        let (archiveData, archiveResponse) = try await session.data(from: URL(string: asset.browser_download_url)!)
        try validateHTTP(archiveResponse)
        try archiveData.write(to: archiveURL, options: .atomic)

        try extract(archive: archiveURL, to: tmpDir)
        try installBinaries(from: tmpDir)
        try writeInstalledVersion(release.tag_name)
        try writeGlobalMcpConfig(installedAt: dateProvider())
        return release.tag_name
    }

    private func fetchLatestRelease() async throws -> GitHubRelease {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/linhay/XcodeMCPKit/releases?per_page=20")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("nolon-app", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        try validateHTTP(response)
        let releases = try JSONDecoder().decode([GitHubRelease].self, from: data)
        guard let release = releases.first(where: { !$0.draft && !$0.prerelease }) else {
            throw XcodeMCPKitInstallError.releaseNotFound
        }
        return release
    }

    private func selectAsset(from assets: [GitHubRelease.Asset]) throws -> GitHubRelease.Asset {
        #if arch(arm64)
        let arch = "arm64"
        #elseif arch(x86_64)
        let arch = "x86_64"
        #else
        let arch = ""
        #endif

        let candidates = assets.filter { $0.name.hasSuffix(".tar.gz") }
        let archMatch = candidates.first {
            $0.name.contains("darwin-\(arch)") &&
            ($0.name.contains("xcodemcpkit") || $0.name.contains("xcode-mcp-proxy"))
        }
        if let archMatch { return archMatch }

        if let fallback = candidates.first(where: { $0.name.contains("darwin") || $0.name.contains("proxy.tar.gz") }) {
            return fallback
        }
        throw XcodeMCPKitInstallError.assetNotFound
    }

    private func extract(archive: URL, to destination: URL) throws {
        var payload = SKProcessPayload.executableURL(URL(fileURLWithPath: "/usr/bin/tar"))
        payload = payload.arguments(["-xzf", archive.path, "-C", destination.path])
        let result: SKProcessResult
        do {
            result = try SKProcessRunner.runSync(payload)
        } catch let SKProcessRunError.nonZeroExit(exitCode, _, stderrData) {
            let stderrText = String(data: stderrData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let message = (stderrText?.isEmpty == false) ? stderrText! : "tar exited with code \(exitCode)"
            throw XcodeMCPKitInstallError.extractionFailed(message)
        } catch {
            throw XcodeMCPKitInstallError.extractionFailed(error.localizedDescription)
        }
        guard result.exitCode == 0 else {
            let stderrText = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            let message = stderrText.isEmpty ? "tar exited with code \(result.exitCode)" : stderrText
            throw XcodeMCPKitInstallError.extractionFailed(message)
        }
    }

    private func validateHTTP(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw XcodeMCPKitInstallError.httpFailed(http.statusCode)
        }
    }

    private func installBinaries(from extractedRoot: URL) throws {
        let installDir = nolonRootURL.appendingPathComponent("bin", isDirectory: true)
        try fileManager.createDirectory(at: installDir, withIntermediateDirectories: true)

        try installBinary(
            sourceCandidates: ["xcodemcpkit", "xcode-mcp-proxy-server"],
            targetName: "xcodemcpkit",
            from: extractedRoot,
            to: installDir
        )
        try installBinary(
            sourceCandidates: ["xcode-mcp-server", "xcode-mcp-proxy"],
            targetName: "xcode-mcp-server",
            from: extractedRoot,
            to: installDir
        )
    }

    private func installBinary(
        sourceCandidates: [String],
        targetName: String,
        from extractedRoot: URL,
        to installDir: URL
    ) throws {
        let sourceURL = try resolveBinaryURL(candidates: sourceCandidates, in: extractedRoot)
        let targetURL = installDir.appendingPathComponent(targetName, isDirectory: false)
        try? fileManager.removeItem(at: targetURL)
        try fileManager.copyItem(at: sourceURL, to: targetURL)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: targetURL.path)
    }

    private func resolveBinaryURL(candidates: [String], in root: URL) throws -> URL {
        let roots = [
            root.appendingPathComponent("bin", isDirectory: true),
            root
        ]
        for base in roots {
            for name in candidates {
                let candidate = base.appendingPathComponent(name, isDirectory: false)
                if fileManager.fileExists(atPath: candidate.path) {
                    return candidate
                }
            }
        }
        throw XcodeMCPKitInstallError.binaryMissing(candidates.joined(separator: " | "))
    }

    private func writeInstalledVersion(_ version: String) throws {
        let pluginDir = nolonRootURL
            .appendingPathComponent("plugins", isDirectory: true)
            .appendingPathComponent("xcodemcpkit", isDirectory: true)
        try fileManager.createDirectory(at: pluginDir, withIntermediateDirectories: true)
        let versionFile = pluginDir.appendingPathComponent("installed_version.txt", isDirectory: false)
        try version.write(to: versionFile, atomically: true, encoding: .utf8)
    }

    private func writeGlobalMcpConfig(installedAt: Date) throws {
        let mcpsDir = nolonRootURL.appendingPathComponent("mcps", isDirectory: true)
        try fileManager.createDirectory(at: mcpsDir, withIntermediateDirectories: true)
        let file = mcpsDir.appendingPathComponent("xcodemcpkit.json", isDirectory: false)

        let timestamp = ISO8601DateFormatter().string(from: installedAt)
        let payload: [String: Any] = [
            "mcpServers": [
                "xcodemcpkit": [
                    "command": "xcode-mcp-server",
                    "args": [],
                    "env": [String: String](),
                    "nolon_plugin": [
                        "managed": true,
                        "plugin_id": "xcodemcpkit",
                        "installed_by": "nolon-plugin-app",
                        "installed_at": timestamp
                    ]
                ]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: file, options: .atomic)
    }
}
