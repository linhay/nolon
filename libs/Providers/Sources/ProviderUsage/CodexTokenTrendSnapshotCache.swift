import Foundation
import ProvidersShared

final class CodexTokenTrendSnapshotCache: @unchecked Sendable {
    private struct Envelope: Codable, Sendable {
        let schemaVersion: Int
        let snapshot: ProviderTokenTrendSnapshot
    }

    private static let schemaVersion = 2

    private let fileManager: FileManager
    private let rootDirectory: URL

    init(
        rootDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        if let rootDirectory {
            self.rootDirectory = rootDirectory
        } else {
            let appSupport = NolonHomeEnvironment.resolveApplicationSupportFolder(
                environment: ProcessInfo.processInfo.environment,
                fileManager: fileManager
            )
            self.rootDirectory = appSupport
                .appendingPathComponent("Nolon", isDirectory: true)
                .appendingPathComponent("provider-usage", isDirectory: true)
                .appendingPathComponent("codex-token-trend-cache", isDirectory: true)
        }
    }

    func load(codexHome: URL) throws -> ProviderTokenTrendSnapshot? {
        let fileURL = cacheFileURL(for: codexHome)
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }

        let data = try Data(contentsOf: fileURL)
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        guard envelope.schemaVersion == Self.schemaVersion else {
            return nil
        }
        return envelope.snapshot
    }

    func save(
        _ snapshot: ProviderTokenTrendSnapshot,
        codexHome: URL
    ) throws {
        try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        let envelope = Envelope(schemaVersion: Self.schemaVersion, snapshot: snapshot)
        let data = try JSONEncoder().encode(envelope)
        try data.write(to: cacheFileURL(for: codexHome), options: .atomic)
    }

    private func cacheFileURL(for codexHome: URL) -> URL {
        let homePath = codexHome.standardizedFileURL.path
        let encodedPath = Data(homePath.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return rootDirectory.appendingPathComponent("\(encodedPath).json", isDirectory: false)
    }
}
