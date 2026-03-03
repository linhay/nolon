import Foundation

public struct XcodeMCPKitRelease: Sendable, Equatable {
    public let tag: String
    public let htmlURL: URL?
    public let publishedAt: Date?

    public init(tag: String, htmlURL: URL?, publishedAt: Date?) {
        self.tag = tag
        self.htmlURL = htmlURL
        self.publishedAt = publishedAt
    }
}

public struct XcodeMCPKitUpgradeStatus: Sendable, Equatable {
    public let installedVersion: String?
    public let latestVersion: String?
    public let hasUpgrade: Bool
    public let releaseURL: URL?

    public init(
        installedVersion: String?,
        latestVersion: String?,
        hasUpgrade: Bool,
        releaseURL: URL?
    ) {
        self.installedVersion = installedVersion
        self.latestVersion = latestVersion
        self.hasUpgrade = hasUpgrade
        self.releaseURL = releaseURL
    }
}

public struct XcodeMCPKitReleaseChecker: Sendable {
    public typealias DataLoader = @Sendable (URL) async throws -> Data

    private let releasesAPIURL: URL
    private let dataLoader: DataLoader

    public init(
        owner: String = "linhay",
        repo: String = "XcodeMCPKit",
        dataLoader: DataLoader? = nil
    ) {
        self.releasesAPIURL = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases?per_page=20")!
        self.dataLoader = dataLoader ?? { url in
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            return data
        }
    }

    public func latestStableRelease() async throws -> XcodeMCPKitRelease? {
        let data = try await dataLoader(releasesAPIURL)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        let releases = try decoder.decode([GitHubRelease].self, from: data)
        return releases
            .filter { !$0.prerelease && !$0.draft }
            .compactMap { release in
                guard STVersion(string: release.tagName) != nil else { return nil }
                return XcodeMCPKitRelease(tag: release.tagName, htmlURL: release.htmlURL, publishedAt: release.publishedAt)
            }
            .max { lhs, rhs in
                guard let left = STVersion(string: lhs.tag), let right = STVersion(string: rhs.tag) else {
                    return false
                }
                return left < right
            }
    }

    public func checkUpgrade(installedVersion: String?) async -> XcodeMCPKitUpgradeStatus {
        do {
            let latest = try await latestStableRelease()
            let hasUpgrade: Bool
            if let installedVersion,
               let installed = STVersion(string: installedVersion),
               let latestTag = latest?.tag,
               let latestVersion = STVersion(string: latestTag) {
                hasUpgrade = installed < latestVersion
            } else {
                hasUpgrade = false
            }
            return XcodeMCPKitUpgradeStatus(
                installedVersion: installedVersion,
                latestVersion: latest?.tag,
                hasUpgrade: hasUpgrade,
                releaseURL: latest?.htmlURL
            )
        } catch {
            return XcodeMCPKitUpgradeStatus(
                installedVersion: installedVersion,
                latestVersion: nil,
                hasUpgrade: false,
                releaseURL: URL(string: "https://github.com/linhay/XcodeMCPKit/releases")
            )
        }
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: URL?
    let prerelease: Bool
    let draft: Bool
    let publishedAt: Date?
}
