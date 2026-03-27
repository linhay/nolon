import Foundation

public enum AgentDocKind: String, Sendable, Codable, Hashable {
    case override
    case base
}

public struct AgentDocInfo: Identifiable, Hashable, Sendable, Codable {
    public let id: String
    public let fileName: String
    public let path: String
    public let preview: String
    public let kind: AgentDocKind

    public init(id: String, fileName: String, path: String, preview: String, kind: AgentDocKind) {
        self.id = id
        self.fileName = fileName
        self.path = path
        self.preview = preview
        self.kind = kind
    }
}

public struct RuleInfo: Identifiable, Hashable, Sendable, Codable {
    public let id: String
    public let name: String
    public let preview: String
    public let relativePath: String
    public let path: String

    public init(id: String, name: String, preview: String, relativePath: String, path: String) {
        self.id = id
        self.name = name
        self.preview = preview
        self.relativePath = relativePath
        self.path = path
    }
}

public enum WorkflowSource: String, CaseIterable, Sendable, Codable, Hashable {
    case skill
    case user
    case mcp
    case unknown

    public var localizedKey: String {
        switch self {
        case .skill:
            return "workflow.source.skill"
        case .user:
            return "workflow.source.user"
        case .mcp:
            return "workflow.source.mcp"
        case .unknown:
            return "workflow.source.unknown"
        }
    }

    public var fallbackTitle: String {
        switch self {
        case .skill:
            return "Skill"
        case .user:
            return "User"
        case .mcp:
            return "MCP"
        case .unknown:
            return "Unknown"
        }
    }
}

public struct WorkflowInfo: Identifiable, Hashable, Sendable, Codable {
    public let id: String
    public let name: String
    public let description: String
    public let path: String
    public let source: WorkflowSource

    public init(id: String, name: String, description: String, path: String, source: WorkflowSource) {
        self.id = id
        self.name = name
        self.description = description
        self.path = path
        self.source = source
    }
}

public enum ProviderSkillCardState: String, CaseIterable, Sendable, Codable, Hashable {
    case installed
    case orphaned
    case broken
}

public struct ProviderSkillCardInfo: Identifiable, Hashable, Sendable, Codable {
    public var id: String { path }
    public let skillName: String
    public let state: ProviderSkillCardState
    public let path: String

    public init(skillName: String, state: ProviderSkillCardState, path: String) {
        self.skillName = skillName
        self.state = state
        self.path = path
    }
}

public struct SkillRowInfo: Identifiable, Hashable, Sendable, Codable {
    public var id: String { globalPath }
    public let name: String
    public let description: String
    public let isInstalled: Bool
    public let version: String
    public let globalPath: String
    public let referenceCount: Int
    public let scriptCount: Int

    public init(
        name: String,
        description: String,
        isInstalled: Bool,
        version: String,
        globalPath: String,
        referenceCount: Int,
        scriptCount: Int
    ) {
        self.name = name
        self.description = description
        self.isInstalled = isInstalled
        self.version = version
        self.globalPath = globalPath
        self.referenceCount = referenceCount
        self.scriptCount = scriptCount
    }
}
