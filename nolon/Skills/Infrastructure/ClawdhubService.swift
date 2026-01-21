import Foundation

public actor ClawdhubService {
    public static let shared = ClawdhubService()

    /// Base URL for the API
    private let baseURL: URL
    private let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    /// Default initializer using Clawdhub as the base URL
    public init() {
        self.baseURL = URL(string: "https://clawdhub.com")!
    }

    /// Initializer with custom base URL for supporting other repositories
    public init(baseURL: String) {
        self.baseURL = URL(string: baseURL) ?? URL(string: "https://clawdhub.com")!
    }

    /// Initializer with RemoteRepository
    public init(repository: RemoteRepository) {
        self.baseURL = URL(string: repository.baseURL) ?? URL(string: "https://clawdhub.com")!
    }

    // MARK: - API Response Structures

    public struct SearchResponse: Decodable {
        public let results: [SearchResult]
    }

    public struct SearchResult: Decodable {
        public let slug: String?
        public let displayName: String?
        public let summary: String?
        public let version: String?
        public let updatedAt: TimeInterval?
    }

    public struct SkillListResponse: Decodable {
        public let items: [SkillListItem]
    }

    public struct SkillListItem: Decodable {
        public let slug: String
        public let displayName: String
        public let summary: String?
        public let updatedAt: TimeInterval
        public let latestVersion: LatestVersion?
        public let stats: Stats?
    }

    public struct LatestVersion: Decodable {
        public let version: String
        public let createdAt: TimeInterval
        public let changelog: String?
    }

    public struct Stats: Decodable {
        public let downloads: Int?
        public let stars: Int?
    }

    // MARK: - Public API

    /// Fetches skills from Clawdhub. If query is provided, performs search; otherwise fetches latest skills.
    public func fetchSkills(query: String? = nil, limit: Int = 20) async throws -> [RemoteSkill] {
        if let query = query, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return try await search(query: query, limit: limit)
        } else {
            return try await fetchLatest(limit: limit)
        }
    }

    /// Fetches the latest skills list
    /// Endpoint: GET /api/v1/skills?limit=N
    public func fetchLatest(limit: Int = 12) async throws -> [RemoteSkill] {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("/api/v1/skills"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "limit", value: String(limit))
        ]

        guard let url = components?.url else {
            throw customError("Invalid URL")
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try jsonDecoder.decode(SkillListResponse.self, from: data)

        return response.items.map { item in
            RemoteSkill(
                slug: item.slug,
                displayName: item.displayName,
                summary: item.summary,
                latestVersion: item.latestVersion?.version,
                updatedAt: Date(timeIntervalSince1970: item.updatedAt / 1000),
                downloads: item.stats?.downloads,
                stars: item.stats?.stars
            )
        }
    }

    /// Searches for skills matching the query
    /// Endpoint: GET /api/v1/search?q=QUERY&limit=N
    public func search(query: String, limit: Int = 20) async throws -> [RemoteSkill] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var components = URLComponents(
            url: baseURL.appendingPathComponent("/api/v1/search"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "q", value: trimmed),
            URLQueryItem(name: "limit", value: String(limit)),
        ]

        guard let url = components?.url else {
            throw customError("Invalid URL")
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try jsonDecoder.decode(SearchResponse.self, from: data)

        return response.results.compactMap { result in
            guard let slug = result.slug, let displayName = result.displayName else { return nil }
            return RemoteSkill(
                slug: slug,
                displayName: displayName,
                summary: result.summary,
                latestVersion: result.version,
                updatedAt: result.updatedAt.map { Date(timeIntervalSince1970: $0 / 1000) },
                downloads: nil,
                stars: nil
            )
        }
    }

    /// Fetches skill detail including owner information
    /// Endpoint: GET /api/skill?slug=SLUG
    public func fetchSkillDetail(slug: String) async throws -> RemoteSkillDetail {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("/api/skill"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "slug", value: slug)
        ]

        guard let url = components?.url else {
            throw customError("Invalid URL")
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        return try jsonDecoder.decode(RemoteSkillDetail.self, from: data)
    }

    /// Downloads a skill zip file
    /// Endpoint: GET /api/v1/download?slug=SLUG&version=VERSION (or tag=latest)
    public func downloadSkill(slug: String, version: String?) async throws -> URL {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("/api/v1/download"),
            resolvingAgainstBaseURL: false
        )

        var queryItems = [URLQueryItem(name: "slug", value: slug)]
        if let version = version, !version.isEmpty {
            queryItems.append(URLQueryItem(name: "version", value: version))
        } else {
            queryItems.append(URLQueryItem(name: "tag", value: "latest"))
        }
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw customError("Invalid URL")
        }

        let (tempURL, response) = try await URLSession.shared.download(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
            (200..<300).contains(httpResponse.statusCode)
        else {
            throw customError("Download failed")
        }

        // Move to a temporary location with correct name
        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(slug)-\(version ?? "latest")-\(UUID().uuidString).zip")

        try FileManager.default.moveItem(at: tempURL, to: destinationURL)
        return destinationURL
    }

    private func customError(_ message: String) -> Error {
        NSError(domain: "ClawdhubService", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
