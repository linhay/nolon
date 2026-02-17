import Foundation

nonisolated public struct RemoteMCP: Decodable, Identifiable, Hashable, Sendable, RemoteItem {
    nonisolated public var id: String { slug }
    public let slug: String
    public let displayName: String
    public let summary: String?
    public let updatedAt: TimeInterval
    public let latestVersion: LatestVersion?
    public let stats: Stats?
    public let localPath: String?
    public let configuration: MCPConfiguration?
    
    public struct Stats: Decodable, Hashable, Sendable {
        public let downloads: Int?
        public let stars: Int?
        public let installs: Int?

        nonisolated public init(
            downloads: Int? = nil,
            stars: Int? = nil,
            installs: Int? = nil
        ) {
            self.downloads = downloads
            self.stars = stars
            self.installs = installs
        }
    }
    
    public struct LatestVersion: Decodable, Hashable, Sendable {
        public let version: String
        public let createdAt: TimeInterval
        public let changelog: String?

        nonisolated public init(version: String, createdAt: TimeInterval = 0, changelog: String? = nil) {
            self.version = version
            self.createdAt = createdAt
            self.changelog = changelog
        }
    }
    
    public struct MCPConfiguration: Codable, Hashable, Sendable {
        public let command: String?
        public let args: [String]?
        public let env: [String: String]?

        nonisolated public init(
            command: String? = nil,
            args: [String]? = nil,
            env: [String: String]? = nil
        ) {
            self.command = command
            self.args = args
            self.env = env
        }
    }
    
    nonisolated public init(
        slug: String,
        displayName: String,
        summary: String?,
        latestVersion: String?,
        updatedAt: Date?,
        downloads: Int?,
        stars: Int?,
        installs: Int? = nil,
        configuration: MCPConfiguration? = nil,
        localPath: String? = nil
    ) {
        self.slug = slug
        self.displayName = displayName
        self.summary = summary
        self.updatedAt = updatedAt?.timeIntervalSince1970 ?? Date().timeIntervalSince1970
        self.latestVersion = latestVersion.map { LatestVersion(version: $0) }
        self.stats = (downloads != nil || stars != nil || installs != nil)
            ? Stats(downloads: downloads, stars: stars, installs: installs)
            : nil
        self.configuration = configuration
        self.localPath = localPath
    }
}
