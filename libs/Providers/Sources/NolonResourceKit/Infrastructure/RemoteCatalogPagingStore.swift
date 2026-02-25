import Foundation
import ProviderCatalog

public struct RemoteCatalogPageKey: Sendable, Equatable, Hashable {
    public let repositoryID: String
    public let kind: SkillsRepositoryFacade.RemoteCatalogKind
    public let query: String

    public init(repositoryID: String, kind: SkillsRepositoryFacade.RemoteCatalogKind, query: String) {
        self.repositoryID = repositoryID
        self.kind = kind
        self.query = query
    }
}

public struct RemoteCatalogPageEntry: Sendable, Equatable {
    public let items: [SkillsRepositoryFacade.RemoteCatalogItem]
    public let errorMessage: String?
    public let cacheBuster: String
    public let limit: Int
    public let canLoadMore: Bool

    public init(
        items: [SkillsRepositoryFacade.RemoteCatalogItem],
        errorMessage: String?,
        cacheBuster: String,
        limit: Int,
        canLoadMore: Bool
    ) {
        self.items = items
        self.errorMessage = errorMessage
        self.cacheBuster = cacheBuster
        self.limit = limit
        self.canLoadMore = canLoadMore
    }
}

public final class RemoteCatalogPagingStore: @unchecked Sendable {
    private var cache: [RemoteCatalogPageKey: RemoteCatalogPageEntry] = [:]
    public let pageSize: Int
    public let maxLimit: Int

    public init(pageSize: Int = 20, maxLimit: Int = 200) {
        self.pageSize = max(1, pageSize)
        self.maxLimit = max(self.pageSize, maxLimit)
    }

    public func key(repositoryID: String, kind: SkillsRepositoryFacade.RemoteCatalogKind, query: String) -> RemoteCatalogPageKey {
        RemoteCatalogPageKey(repositoryID: repositoryID, kind: kind, query: query)
    }

    public func entry(for key: RemoteCatalogPageKey) -> RemoteCatalogPageEntry? {
        cache[key]
    }

    public func shouldUseCachedResult(for key: RemoteCatalogPageKey, cacheBuster: String) -> Bool {
        guard let cached = cache[key] else { return false }
        return cached.cacheBuster == cacheBuster
    }

    public func currentLimit(for key: RemoteCatalogPageKey) -> Int {
        cache[key]?.limit ?? pageSize
    }

    public func nextLimit(for key: RemoteCatalogPageKey) -> Int? {
        let current = currentLimit(for: key)
        let next = min(maxLimit, current + pageSize)
        return next > current ? next : nil
    }

    public func saveSuccess(
        for key: RemoteCatalogPageKey,
        items: [SkillsRepositoryFacade.RemoteCatalogItem],
        cacheBuster: String,
        limit: Int,
        canLoadMore: Bool
    ) {
        cache[key] = RemoteCatalogPageEntry(
            items: items,
            errorMessage: nil,
            cacheBuster: cacheBuster,
            limit: max(1, limit),
            canLoadMore: canLoadMore
        )
    }

    public func saveError(
        for key: RemoteCatalogPageKey,
        items: [SkillsRepositoryFacade.RemoteCatalogItem],
        cacheBuster: String,
        limit: Int,
        errorMessage: String
    ) {
        cache[key] = RemoteCatalogPageEntry(
            items: items,
            errorMessage: errorMessage,
            cacheBuster: cacheBuster,
            limit: max(1, limit),
            canLoadMore: false
        )
    }
}
