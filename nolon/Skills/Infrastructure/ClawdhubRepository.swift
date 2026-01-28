import Foundation

/// Clawdhub remote repository implementation
/// Replaces ClawdhubService.swift
public actor ClawdhubRepository: RemoteResourceRepository {
    public static let shared = ClawdhubRepository()
    
    // MARK: - RemoteResourceRepository Protocol
    
    public let id: String
    public let name: String
    public let supportedTypes: Set<RemoteContentType> = [.skill, .workflow, .mcp]
    public var lastSyncDate: Date? { nil }
    
    // MARK: - Private Properties
    
    private let baseURL: URL
    private let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
    
    // MARK: - Initialization
    
    /// Default initializer using Clawdhub as the base URL
    public init() {
        self.id = "clawdhub"
        self.name = "Clawdhub"
        self.baseURL = URL(string: "https://clawdhub.com")!
    }
    
    /// Initializer with custom base URL for supporting other repositories
    public init(id: String = "clawdhub", name: String = "Clawdhub", baseURL: String) {
        self.id = id
        self.name = name
        self.baseURL = URL(string: baseURL) ?? URL(string: "https://clawdhub.com")!
    }
    
    /// Initializer with RemoteRepository
    public init(repository: RemoteRepository) {
        self.id = repository.id
        self.name = repository.name
        self.baseURL = URL(string: repository.baseURL) ?? URL(string: "https://clawdhub.com")!
    }
    
    // MARK: - Skills API
    
    public func fetchSkills(query: String? = nil, limit: Int = 20) async throws -> [RemoteSkill] {
        if let query = query, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return try await search(query: query, limit: limit)
        } else {
            return try await fetchLatest(limit: limit)
        }
    }
    
    /// Fetches the latest skills list
    /// Endpoint: GET /api/v1/skills?limit=N
    private func fetchLatest(limit: Int = 12) async throws -> [RemoteSkill] {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("/api/v1/skills"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "limit", value: String(limit))
        ]
        
        guard let url = components?.url else {
            throw RepositoryError.invalidURL
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
    private func search(query: String, limit: Int = 20) async throws -> [RemoteSkill] {
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
            throw RepositoryError.invalidURL
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
            throw RepositoryError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return try jsonDecoder.decode(RemoteSkillDetail.self, from: data)
    }
    
    public func downloadSkill(slug: String) async throws -> URL {
        return try await downloadSkill(slug: slug, version: nil)
    }
    
    /// Downloads a skill zip file
    /// Endpoint: GET /api/v1/download?slug=SLUG&version=VERSION (or tag=latest)
    private func downloadSkill(slug: String, version: String?) async throws -> URL {
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
            throw RepositoryError.invalidURL
        }
        
        let (tempURL, response) = try await URLSession.shared.download(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode)
        else {
            throw RepositoryError.downloadFailed("HTTP error")
        }
        
        // Move to a temporary location with correct name
        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(slug)-\(version ?? "latest")-\(UUID().uuidString).zip")
        
        try FileManager.default.moveItem(at: tempURL, to: destinationURL)
        return destinationURL
    }
    
    // MARK: - Workflows API
    
    public func fetchWorkflows(query: String? = nil, limit: Int = 20) async throws -> [RemoteWorkflow] {
        if let query = query, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return try await searchWorkflows(query: query, limit: limit)
        } else {
            return try await fetchLatestWorkflows(limit: limit)
        }
    }
    
    /// Fetches the latest workflows list
    /// Endpoint: GET /api/v1/workflows?limit=N
    private func fetchLatestWorkflows(limit: Int = 12) async throws -> [RemoteWorkflow] {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("/api/v1/workflows"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "limit", value: String(limit))
        ]
        
        guard let url = components?.url else {
            throw RepositoryError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try jsonDecoder.decode(WorkflowListResponse.self, from: data)
        
        return response.items.map { item in
            RemoteWorkflow(
                slug: item.slug,
                displayName: item.displayName,
                summary: item.summary,
                latestVersion: item.latestVersion?.version,
                updatedAt: Date(timeIntervalSince1970: item.updatedAt / 1000),
                downloads: item.stats?.downloads,
                stars: item.stats?.stars,
                usages: item.stats?.usages
            )
        }
    }
    
    /// Searches for workflows matching the query
    /// Endpoint: GET /api/v1/search/workflows?q=QUERY&limit=N
    private func searchWorkflows(query: String, limit: Int = 20) async throws -> [RemoteWorkflow] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        
        var components = URLComponents(
            url: baseURL.appendingPathComponent("/api/v1/search/workflows"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "q", value: trimmed),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        
        guard let url = components?.url else {
            throw RepositoryError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try jsonDecoder.decode(WorkflowSearchResponse.self, from: data)
        
        return response.results.compactMap { result in
            guard let slug = result.slug, let displayName = result.displayName else { return nil }
            return RemoteWorkflow(
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
    
    public func downloadWorkflow(slug: String) async throws -> URL {
        return try await downloadWorkflow(slug: slug, version: nil)
    }
    
    /// Downloads a workflow markdown file
    /// Endpoint: GET /api/v1/download/workflow?slug=SLUG&version=VERSION (or tag=latest)
    private func downloadWorkflow(slug: String, version: String?) async throws -> URL {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("/api/v1/download/workflow"),
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
            throw RepositoryError.invalidURL
        }
        
        let (tempURL, response) = try await URLSession.shared.download(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode)
        else {
            throw RepositoryError.downloadFailed("HTTP error")
        }
        
        // Move to a temporary location with correct name
        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(slug)-\(version ?? "latest")-\(UUID().uuidString).md")
        
        try FileManager.default.moveItem(at: tempURL, to: destinationURL)
        return destinationURL
    }
    
    // MARK: - MCPs API
    
    public func fetchMCPs(query: String? = nil, limit: Int = 20) async throws -> [RemoteMCP] {
        if let query = query, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return try await searchMCPs(query: query, limit: limit)
        } else {
            return try await fetchLatestMCPs(limit: limit)
        }
    }
    
    /// Fetches the latest MCPs list
    /// Endpoint: GET /api/v1/mcps?limit=N
    private func fetchLatestMCPs(limit: Int = 12) async throws -> [RemoteMCP] {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("/api/v1/mcps"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "limit", value: String(limit))
        ]
        
        guard let url = components?.url else {
            throw RepositoryError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try jsonDecoder.decode(MCPListResponse.self, from: data)
        
        return response.items.map { item in
            RemoteMCP(
                slug: item.slug,
                displayName: item.displayName,
                summary: item.summary,
                latestVersion: item.latestVersion?.version,
                updatedAt: Date(timeIntervalSince1970: item.updatedAt / 1000),
                downloads: item.stats?.downloads,
                stars: item.stats?.stars,
                installs: item.stats?.installs,
                configuration: item.configuration
            )
        }
    }
    
    /// Searches for MCPs matching the query
    /// Endpoint: GET /api/v1/search/mcps?q=QUERY&limit=N
    private func searchMCPs(query: String, limit: Int = 20) async throws -> [RemoteMCP] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        
        var components = URLComponents(
            url: baseURL.appendingPathComponent("/api/v1/search/mcps"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "q", value: trimmed),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        
        guard let url = components?.url else {
            throw RepositoryError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try jsonDecoder.decode(MCPSearchResponse.self, from: data)
        
        return response.results.compactMap { result in
            guard let slug = result.slug, let displayName = result.displayName else { return nil }
            return RemoteMCP(
                slug: slug,
                displayName: displayName,
                summary: result.summary,
                latestVersion: result.version,
                updatedAt: result.updatedAt.map { Date(timeIntervalSince1970: $0 / 1000) },
                downloads: nil,
                stars: nil,
                configuration: result.configuration
            )
        }
    }
    
    public func downloadMCP(slug: String) async throws -> URL {
        let config = try await downloadMCPConfig(slug: slug, version: nil)
        
        // Save configuration to temporary file
        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(slug)-\(UUID().uuidString).json")
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: destinationURL)
        
        return destinationURL
    }
    
    /// Downloads an MCP configuration JSON
    /// Endpoint: GET /api/v1/download/mcp?slug=SLUG&version=VERSION (or tag=latest)
    private func downloadMCPConfig(slug: String, version: String?) async throws -> RemoteMCP.MCPConfiguration {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("/api/v1/download/mcp"),
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
            throw RepositoryError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode)
        else {
            throw RepositoryError.downloadFailed("HTTP error")
        }
        
        return try jsonDecoder.decode(RemoteMCP.MCPConfiguration.self, from: data)
    }
    
    // MARK: - Sync (Not needed for API-based repository)
    
    public func sync() async throws -> Bool {
        return true
    }
}

// MARK: - Response Structures

extension ClawdhubRepository {
    struct SearchResponse: Decodable {
        let results: [SearchResult]
    }
    
    struct SearchResult: Decodable {
        let slug: String?
        let displayName: String?
        let summary: String?
        let version: String?
        let updatedAt: TimeInterval?
    }
    
    struct SkillListResponse: Decodable {
        let items: [SkillListItem]
    }
    
    struct SkillListItem: Decodable {
        let slug: String
        let displayName: String
        let summary: String?
        let updatedAt: TimeInterval
        let latestVersion: LatestVersion?
        let stats: Stats?
    }
    
    struct LatestVersion: Decodable {
        let version: String
        let createdAt: TimeInterval
        let changelog: String?
    }
    
    struct Stats: Decodable {
        let downloads: Int?
        let stars: Int?
    }
    
    struct WorkflowListResponse: Decodable {
        let items: [WorkflowListItem]
    }
    
    struct WorkflowListItem: Decodable {
        let slug: String
        let displayName: String
        let summary: String?
        let updatedAt: TimeInterval
        let latestVersion: LatestVersion?
        let stats: WorkflowStats?
    }
    
    struct WorkflowStats: Decodable {
        let downloads: Int?
        let stars: Int?
        let usages: Int?
    }
    
    struct WorkflowSearchResponse: Decodable {
        let results: [WorkflowSearchResult]
    }
    
    struct WorkflowSearchResult: Decodable {
        let slug: String?
        let displayName: String?
        let summary: String?
        let version: String?
        let updatedAt: TimeInterval?
    }
    
    struct MCPListResponse: Decodable {
        let items: [MCPListItem]
    }
    
    struct MCPListItem: Decodable {
        let slug: String
        let displayName: String
        let summary: String?
        let updatedAt: TimeInterval
        let latestVersion: LatestVersion?
        let stats: MCPStats?
        let configuration: RemoteMCP.MCPConfiguration?
    }
    
    struct MCPStats: Decodable {
        let downloads: Int?
        let stars: Int?
        let installs: Int?
    }
    
    struct MCPSearchResponse: Decodable {
        let results: [MCPSearchResult]
    }
    
    struct MCPSearchResult: Decodable {
        let slug: String?
        let displayName: String?
        let summary: String?
        let version: String?
        let updatedAt: TimeInterval?
        let configuration: RemoteMCP.MCPConfiguration?
    }
}
