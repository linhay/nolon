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
    private let mapper = RemoteCatalogItemMapper()
    private let environment: [String: String]

    public init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.environment = environment
    }

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
            let cachedItems = try await queryFromGlobalCache(cache: cache, kind: kind, query: effectiveQuery, limit: safeLimit)
            items = appendUITestFixtureIfNeeded(
                to: cachedItems,
                repository: repository,
                kind: kind,
                query: effectiveQuery,
                limit: safeLimit
            )
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
        mapper.toCatalogItem(skill, installs: skill.stats?.installsAllTime)
    }

    func toCatalogItem(_ workflow: RemoteWorkflow) -> SkillsRepositoryFacade.RemoteCatalogItem {
        mapper.toCatalogItem(workflow, installs: workflow.stats?.usages)
    }

    func toCatalogItem(_ mcp: RemoteMCP) -> SkillsRepositoryFacade.RemoteCatalogItem {
        mapper.toCatalogItem(mcp)
    }

    func appendUITestFixtureIfNeeded(
        to items: [SkillsRepositoryFacade.RemoteCatalogItem],
        repository: RemoteRepository,
        kind: SkillsRepositoryFacade.RemoteCatalogKind,
        query: String?,
        limit: Int
    ) -> [SkillsRepositoryFacade.RemoteCatalogItem] {
        guard repository.templateType == .globalSkills,
              kind == .skill,
              let slug = environment["NOLON_UI_TEST_FIXTURE_GLOBAL_SKILL_SLUG"]?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !slug.isEmpty
        else {
            return items
        }

        let lowercaseQuery = query?.lowercased()
        if let lowercaseQuery,
           !slug.lowercased().contains(lowercaseQuery),
           !"Gemini".lowercased().contains(lowercaseQuery) {
            return items
        }

        if items.contains(where: { $0.slug == slug }) {
            return items
        }

        let localPath = environment["NOLON_HOME"]
            .map { URL(fileURLWithPath: $0).appendingPathComponent("skills/\(slug)").path }

        let fixture = mapper.toCatalogItem(
            RemoteSkill(
                slug: slug,
                displayName: "Gemini",
                summary: "UI test fixture",
                latestVersion: "1.0.0",
                updatedAt: nil,
                downloads: nil,
                stars: nil,
                localPath: localPath
            ),
            installs: nil
        )

        return Array(([fixture] + items).prefix(limit))
    }
}
