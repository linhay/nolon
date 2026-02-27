import Foundation
import ProviderCatalog

public struct RemoteRepositoryCounts: Sendable, Equatable {
    public let skills: Int
    public let workflows: Int
    public let mcps: Int

    public init(skills: Int, workflows: Int, mcps: Int) {
        self.skills = skills
        self.workflows = workflows
        self.mcps = mcps
    }
}

public struct RemoteRepositoryCountService: Sendable {
    private let queryService: RemoteCatalogQueryService

    public init(queryService: RemoteCatalogQueryService = .init()) {
        self.queryService = queryService
    }

    public func countAll(repository: RemoteRepository?, limit: Int = 100) async -> RemoteRepositoryCounts {
        guard let repository else {
            return .init(skills: 0, workflows: 0, mcps: 0)
        }
        do {
            async let skills = queryService.query(
                repository: repository,
                kind: .skill,
                query: nil,
                limit: limit
            )
            async let workflows = queryService.query(
                repository: repository,
                kind: .workflow,
                query: nil,
                limit: limit
            )
            async let mcps = queryService.query(
                repository: repository,
                kind: .mcp,
                query: nil,
                limit: limit
            )
            let (s, w, m) = try await (skills, workflows, mcps)
            return .init(skills: s.items.count, workflows: w.items.count, mcps: m.items.count)
        } catch {
            return .init(skills: 0, workflows: 0, mcps: 0)
        }
    }
}
