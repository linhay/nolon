import Foundation
import ProviderCatalog

public struct RemoteCatalogQueryResult: Sendable, Equatable {
    public let items: [SkillsRepositoryFacade.RemoteCatalogItem]
    public let canLoadMore: Bool

    public init(items: [SkillsRepositoryFacade.RemoteCatalogItem], canLoadMore: Bool) {
        self.items = items
        self.canLoadMore = canLoadMore
    }
}

public struct RemoteCatalogQueryService: Sendable {
    public init() {}

    public func query(
        repository: RemoteRepository,
        kind: SkillsRepositoryFacade.RemoteCatalogKind,
        query: String?,
        limit: Int
    ) async throws -> RemoteCatalogQueryResult {
        let safeLimit = max(1, limit)
        let normalizedQuery = query?.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveQuery = (normalizedQuery?.isEmpty == false) ? normalizedQuery : nil

        let items: [SkillsRepositoryFacade.RemoteCatalogItem]
        switch repository.templateType {
        case .clawdhub:
            let result = try await SkillsRepositoryFacade.listRemoteResources(
                kind: kind,
                query: effectiveQuery,
                limit: safeLimit,
                baseURL: repository.baseURL
            )
            items = result.items
        case .globalSkills:
            let cache = GlobalCacheRepository()
            items = try await queryFromGlobalCache(cache: cache, kind: kind, query: effectiveQuery, limit: safeLimit)
        case .localFolder:
            let paths = repository.effectiveSkillsPaths
            guard !paths.isEmpty else {
                throw RepositoryError.invalidConfiguration
            }
            let local = LocalFolderRepository(id: repository.id, name: repository.name, basePaths: paths)
            items = try await queryFromLocal(local: local, kind: kind, query: effectiveQuery, limit: safeLimit)
        case .git:
            let paths = repository.effectiveSkillsPaths
            guard !paths.isEmpty else {
                throw RepositoryError.invalidConfiguration
            }
            let git = try GitRepository(repository: repository)
            items = try await queryFromGit(git: git, kind: kind, query: effectiveQuery, limit: safeLimit)
        }

        return RemoteCatalogQueryResult(
            items: items,
            canLoadMore: items.count >= safeLimit
        )
    }
}

private extension RemoteCatalogQueryService {
    func queryFromGlobalCache(
        cache: GlobalCacheRepository,
        kind: SkillsRepositoryFacade.RemoteCatalogKind,
        query: String?,
        limit: Int
    ) async throws -> [SkillsRepositoryFacade.RemoteCatalogItem] {
        switch kind {
        case .skill:
            return try await cache.fetchSkills(query: query, limit: limit).map(toCatalogItem)
        case .workflow:
            return try await cache.fetchWorkflows(query: query, limit: limit).map(toCatalogItem)
        case .mcp:
            return try await cache.fetchMCPs(query: query, limit: limit).map(toCatalogItem)
        }
    }

    func queryFromLocal(
        local: LocalFolderRepository,
        kind: SkillsRepositoryFacade.RemoteCatalogKind,
        query: String?,
        limit: Int
    ) async throws -> [SkillsRepositoryFacade.RemoteCatalogItem] {
        switch kind {
        case .skill:
            return try await local.fetchSkills(query: query, limit: limit).map(toCatalogItem)
        case .workflow:
            return try await local.fetchWorkflows(query: query, limit: limit).map(toCatalogItem)
        case .mcp:
            return try await local.fetchMCPs(query: query, limit: limit).map(toCatalogItem)
        }
    }

    func queryFromGit(
        git: GitRepository,
        kind: SkillsRepositoryFacade.RemoteCatalogKind,
        query: String?,
        limit: Int
    ) async throws -> [SkillsRepositoryFacade.RemoteCatalogItem] {
        switch kind {
        case .skill:
            return try await git.fetchSkills(query: query, limit: limit).map(toCatalogItem)
        case .workflow:
            return try await git.fetchWorkflows(query: query, limit: limit).map(toCatalogItem)
        case .mcp:
            return try await git.fetchMCPs(query: query, limit: limit).map(toCatalogItem)
        }
    }

    func toCatalogItem(_ skill: RemoteSkill) -> SkillsRepositoryFacade.RemoteCatalogItem {
        SkillsRepositoryFacade.RemoteCatalogItem(
            kind: .skill,
            slug: skill.slug,
            displayName: skill.displayName,
            summary: skill.summary,
            latestVersion: skill.latestVersion?.version,
            updatedAt: Date(timeIntervalSince1970: skill.updatedAt),
            downloads: skill.stats?.downloads,
            stars: skill.stats?.stars,
            installs: skill.stats?.installsAllTime
        )
    }

    func toCatalogItem(_ workflow: RemoteWorkflow) -> SkillsRepositoryFacade.RemoteCatalogItem {
        SkillsRepositoryFacade.RemoteCatalogItem(
            kind: .workflow,
            slug: workflow.slug,
            displayName: workflow.displayName,
            summary: workflow.summary,
            latestVersion: workflow.latestVersion?.version,
            updatedAt: Date(timeIntervalSince1970: workflow.updatedAt),
            downloads: workflow.stats?.downloads,
            stars: workflow.stats?.stars,
            installs: workflow.stats?.usages
        )
    }

    func toCatalogItem(_ mcp: RemoteMCP) -> SkillsRepositoryFacade.RemoteCatalogItem {
        SkillsRepositoryFacade.RemoteCatalogItem(
            kind: .mcp,
            slug: mcp.slug,
            displayName: mcp.displayName,
            summary: mcp.summary,
            latestVersion: mcp.latestVersion?.version,
            updatedAt: Date(timeIntervalSince1970: mcp.updatedAt),
            downloads: mcp.stats?.downloads,
            stars: mcp.stats?.stars,
            installs: mcp.stats?.installs
        )
    }
}
