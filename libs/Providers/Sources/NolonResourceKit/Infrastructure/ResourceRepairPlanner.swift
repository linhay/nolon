import Foundation

public enum RepairResourceKind: String, Sendable {
    case skill
    case workflow
    case mcp
}

public enum RepairStateKind: String, Sendable {
    case orphaned
    case broken
}

public struct RepairItem: Sendable, Equatable {
    public let providerID: String
    public let resourceID: String
    public let state: RepairStateKind

    public init(providerID: String, resourceID: String, state: RepairStateKind) {
        self.providerID = providerID
        self.resourceID = resourceID
        self.state = state
    }
}

public struct RepairStep: Sendable, Equatable {
    public let title: String
    public let commands: [String]

    public init(title: String, commands: [String]) {
        self.title = title
        self.commands = commands
    }
}

public struct RepairPlan: Sendable, Equatable {
    public let kind: RepairResourceKind
    public let steps: [RepairStep]
    public let recheckCommand: String

    public init(kind: RepairResourceKind, steps: [RepairStep], recheckCommand: String) {
        self.kind = kind
        self.steps = steps
        self.recheckCommand = recheckCommand
    }
}

public enum ResourceRepairPlanner {
    public static func command(
        kind: RepairResourceKind,
        item: RepairItem
    ) -> String {
        switch kind {
        case .skill:
            let remove = "nolon skills remove --skill-id \(item.resourceID) --provider \(item.providerID)"
            if item.state == .broken {
                return "\(remove) && nolon skills add \(item.resourceID) --provider \(item.providerID)"
            }
            return remove
        case .workflow, .mcp:
            return "nolon \(kind.rawValue) remove --resource-name \(item.resourceID) --provider \(item.providerID)"
        }
    }

    public static func plan(
        kind: RepairResourceKind,
        items: [RepairItem]
    ) -> RepairPlan {
        let groupedOrphaned = items.filter { $0.state == .orphaned }
        let groupedBroken = items.filter { $0.state == .broken }
        var steps: [RepairStep] = []

        if !groupedOrphaned.isEmpty {
            let commands = groupedOrphaned.map { command(kind: kind, item: $0) }
            steps.append(.init(title: "清理失效链接", commands: commands))
        }

        if !groupedBroken.isEmpty {
            let commands = groupedBroken.map { command(kind: kind, item: $0) }
            steps.append(.init(title: kind == .skill ? "修复损坏（先 remove 再 add）" : "清理损坏项", commands: commands))
        }

        return RepairPlan(
            kind: kind,
            steps: steps,
            recheckCommand: "nolon \(kind.rawValue) list --show-fixes"
        )
    }
}
