import Foundation
import ProviderCatalog

public struct ProviderResourceSnapshot: Sendable {
    public let workflows: [ProviderResourceItem]
    public let rules: [ProviderResourceItem]
    public let agents: [ProviderResourceItem]
    public let mcps: [MCP]
    public let mcpCacheStates: [String: MCPCacheState]

    public init(
        workflows: [ProviderResourceItem],
        rules: [ProviderResourceItem],
        agents: [ProviderResourceItem],
        mcps: [MCP],
        mcpCacheStates: [String: MCPCacheState]
    ) {
        self.workflows = workflows
        self.rules = rules
        self.agents = agents
        self.mcps = mcps
        self.mcpCacheStates = mcpCacheStates
    }
}

public final class ProviderResourceSnapshotService: @unchecked Sendable {
    private let resourceService: ProviderResourceService
    private let mcpService: ProviderMCPMaintenanceService

    public init(
        resourceService: ProviderResourceService = .init(),
        mcpService: ProviderMCPMaintenanceService = .init()
    ) {
        self.resourceService = resourceService
        self.mcpService = mcpService
    }

    public func load(provider: Provider) -> ProviderResourceSnapshot {
        let workflows = resourceService.scanWorkflows(provider: provider)
        let rules = resourceService.scanRules(provider: provider)
        let agents = resourceService.scanAgentDocs(provider: provider)

        guard let templateID = provider.templateId,
              let template = ProviderTemplate(rawValue: templateID)
        else {
            return .init(
                workflows: workflows,
                rules: rules,
                agents: agents,
                mcps: [],
                mcpCacheStates: [:]
            )
        }

        do {
            let mcpSnapshot = try mcpService.listSnapshot(template: template)
            return .init(
                workflows: workflows,
                rules: rules,
                agents: agents,
                mcps: mcpSnapshot.mcps,
                mcpCacheStates: mcpSnapshot.cacheStates
            )
        } catch {
            return .init(
                workflows: workflows,
                rules: rules,
                agents: agents,
                mcps: [],
                mcpCacheStates: [:]
            )
        }
    }
}
