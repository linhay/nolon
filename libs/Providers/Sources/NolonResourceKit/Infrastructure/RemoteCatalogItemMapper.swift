import Foundation
import ProviderCatalog

public struct RemoteCatalogItemMapper: Sendable {
    public init() {}

    public func toRemoteSkill(_ item: SkillsRepositoryFacade.RemoteCatalogItem) -> RemoteSkill {
        RemoteSkill(
            slug: item.slug,
            displayName: item.displayName,
            summary: item.summary,
            latestVersion: item.latestVersion,
            updatedAt: item.updatedAt,
            downloads: item.downloads,
            stars: item.stars
        )
    }

    public func toRemoteWorkflow(_ item: SkillsRepositoryFacade.RemoteCatalogItem) -> RemoteWorkflow {
        RemoteWorkflow(
            slug: item.slug,
            displayName: item.displayName,
            summary: item.summary,
            latestVersion: item.latestVersion,
            updatedAt: item.updatedAt,
            downloads: item.downloads,
            stars: item.stars
        )
    }

    public func toRemoteMCP(_ item: SkillsRepositoryFacade.RemoteCatalogItem) -> RemoteMCP {
        RemoteMCP(
            slug: item.slug,
            displayName: item.displayName,
            summary: item.summary,
            latestVersion: item.latestVersion,
            updatedAt: item.updatedAt,
            downloads: item.downloads,
            stars: item.stars,
            installs: item.installs
        )
    }

    public func toCatalogItem(_ skill: RemoteSkill, installs: Int? = nil) -> SkillsRepositoryFacade.RemoteCatalogItem {
        SkillsRepositoryFacade.RemoteCatalogItem(
            kind: .skill,
            slug: skill.slug,
            displayName: skill.displayName,
            summary: skill.summary,
            latestVersion: skill.latestVersion?.version,
            updatedAt: Date(timeIntervalSince1970: skill.updatedAt),
            downloads: skill.stats?.downloads,
            stars: skill.stats?.stars,
            installs: installs ?? skill.stats?.installsAllTime
        )
    }

    public func toCatalogItem(_ workflow: RemoteWorkflow, installs: Int? = nil) -> SkillsRepositoryFacade.RemoteCatalogItem {
        SkillsRepositoryFacade.RemoteCatalogItem(
            kind: .workflow,
            slug: workflow.slug,
            displayName: workflow.displayName,
            summary: workflow.summary,
            latestVersion: workflow.latestVersion?.version,
            updatedAt: Date(timeIntervalSince1970: workflow.updatedAt),
            downloads: workflow.stats?.downloads,
            stars: workflow.stats?.stars,
            installs: installs ?? workflow.stats?.usages
        )
    }

    public func toCatalogItem(_ mcp: RemoteMCP) -> SkillsRepositoryFacade.RemoteCatalogItem {
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
