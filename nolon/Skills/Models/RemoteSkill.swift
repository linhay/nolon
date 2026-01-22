import Foundation

public struct RemoteSkill: Decodable, Identifiable, Hashable, Sendable {
    public var id: String { slug }
    public let slug: String
    public let displayName: String
    public let summary: String?
    public let updatedAt: TimeInterval
    public let latestVersion: LatestVersion?
    public let stats: Stats?
    
    /// Local path for skills from local folder or GitHub repositories
    public let localPath: String?

    public struct Stats: Decodable, Hashable, Sendable {
        public let comments: Int?
        public let downloads: Int?
        public let installsAllTime: Int?
        public let installsCurrent: Int?
        public let stars: Int?
        public let versions: Int?

        public init(
            comments: Int? = nil,
            downloads: Int? = nil,
            installsAllTime: Int? = nil,
            installsCurrent: Int? = nil,
            stars: Int? = nil,
            versions: Int? = nil
        ) {
            self.comments = comments
            self.downloads = downloads
            self.installsAllTime = installsAllTime
            self.installsCurrent = installsCurrent
            self.stars = stars
            self.versions = versions
        }
    }

    public struct LatestVersion: Decodable, Hashable, Sendable {
        public let version: String
        public let createdAt: TimeInterval
        public let changelog: String?

        public init(version: String, createdAt: TimeInterval = 0, changelog: String? = nil) {
            self.version = version
            self.createdAt = createdAt
            self.changelog = changelog
        }
    }

    /// Memberwise initializer for creating RemoteSkill from API response or local scan
    public init(
        slug: String,
        displayName: String,
        summary: String?,
        latestVersion: String?,
        updatedAt: Date?,
        downloads: Int?,
        stars: Int?,
        localPath: String? = nil
    ) {
        self.slug = slug
        self.displayName = displayName
        self.summary = summary
        self.updatedAt = updatedAt?.timeIntervalSince1970 ?? Date().timeIntervalSince1970
        self.latestVersion = latestVersion.map { LatestVersion(version: $0) }
        self.stats =
            (downloads != nil || stars != nil)
            ? Stats(downloads: downloads, stars: stars)
            : nil
        self.localPath = localPath
    }
}

public struct RemoteSkillDetail: Decodable, Sendable {
    public let skill: RemoteSkill
    public let latestVersion: RemoteSkill.LatestVersion?
    public let owner: Owner?

    public struct Owner: Decodable, Sendable {
        public let handle: String?
        public let displayName: String?
        public let image: String?
    }
}
