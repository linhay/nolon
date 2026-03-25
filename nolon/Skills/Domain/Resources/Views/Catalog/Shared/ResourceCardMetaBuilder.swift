import Foundation
import NolonResourceKit

enum ResourceCardMetaItem: Equatable {
    case stars(Int)
    case downloads(Int)
    case usages(Int)
    case installs(Int)
    case command(String)
}

enum ResourceCardMetaBuilder {
    static func skillItems(_ skill: RemoteSkill) -> [ResourceCardMetaItem] {
        var items: [ResourceCardMetaItem] = []
        if let stars = skill.stats?.stars { items.append(.stars(stars)) }
        if let downloads = skill.stats?.downloads { items.append(.downloads(downloads)) }
        return items
    }

    static func workflowItems(_ workflow: RemoteWorkflow) -> [ResourceCardMetaItem] {
        var items: [ResourceCardMetaItem] = []
        if let stars = workflow.stats?.stars { items.append(.stars(stars)) }
        if let usages = workflow.stats?.usages { items.append(.usages(usages)) }
        if let downloads = workflow.stats?.downloads { items.append(.downloads(downloads)) }
        return items
    }

    static func mcpItems(_ mcp: RemoteMCP) -> [ResourceCardMetaItem] {
        var items: [ResourceCardMetaItem] = []
        if let stars = mcp.stats?.stars { items.append(.stars(stars)) }
        if let installs = mcp.stats?.installs { items.append(.installs(installs)) }
        if let downloads = mcp.stats?.downloads { items.append(.downloads(downloads)) }
        if let command = mcp.configuration?.command?.trimmingCharacters(in: .whitespacesAndNewlines),
           !command.isEmpty {
            items.append(.command(command))
        }
        return items
    }
}

