import Foundation

nonisolated public struct RemoteWorkflow: Decodable, Identifiable, Hashable, Sendable, RemoteItem {
    nonisolated public var id: String { slug }
    public let slug: String
    public let displayName: String
    public let summary: String?
    public let updatedAt: TimeInterval
    public let latestVersion: LatestVersion?
    public let stats: Stats?
    public let localPath: String?
    
    public struct Stats: Decodable, Hashable, Sendable {
        public let downloads: Int?
        public let stars: Int?
        public let usages: Int?

        nonisolated public init(
            downloads: Int? = nil,
            stars: Int? = nil,
            usages: Int? = nil
        ) {
            self.downloads = downloads
            self.stars = stars
            self.usages = usages
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
    
    nonisolated public init(
        slug: String,
        displayName: String,
        summary: String?,
        latestVersion: String?,
        updatedAt: Date?,
        downloads: Int?,
        stars: Int?,
        usages: Int? = nil,
        localPath: String? = nil
    ) {
        self.slug = slug
        self.displayName = displayName
        self.summary = summary
        self.updatedAt = updatedAt?.timeIntervalSince1970 ?? Date().timeIntervalSince1970
        self.latestVersion = latestVersion.map { LatestVersion(version: $0) }
        self.stats = (downloads != nil || stars != nil || usages != nil)
            ? Stats(downloads: downloads, stars: stars, usages: usages)
            : nil
        self.localPath = localPath
    }
}
