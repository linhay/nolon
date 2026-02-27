import Foundation

public struct ProviderWorkflowViewData: Sendable, Equatable, Hashable {
    public let id: String
    public let name: String
    public let description: String
    public let path: String
    public let source: WorkflowSourceKind

    public init(id: String, name: String, description: String, path: String, source: WorkflowSourceKind) {
        self.id = id
        self.name = name
        self.description = description
        self.path = path
        self.source = source
    }
}

public struct ProviderRuleViewData: Sendable, Equatable, Hashable {
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

public struct ProviderAgentDocViewData: Sendable, Equatable, Hashable {
    public let id: String
    public let fileName: String
    public let path: String
    public let preview: String
    public let kind: ProviderAgentKind

    public init(id: String, fileName: String, path: String, preview: String, kind: ProviderAgentKind) {
        self.id = id
        self.fileName = fileName
        self.path = path
        self.preview = preview
        self.kind = kind
    }
}

public struct ProviderResourceViewMapper: Sendable {
    public init() {}

    public func mapWorkflows(_ items: [ProviderResourceItem]) -> [ProviderWorkflowViewData] {
        items
            .filter { $0.kind == .workflow }
            .map {
                ProviderWorkflowViewData(
                    id: $0.id,
                    name: $0.name,
                    description: $0.preview,
                    path: $0.path,
                    source: $0.source ?? .unknown
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public func mapRules(_ items: [ProviderResourceItem]) -> [ProviderRuleViewData] {
        items
            .filter { $0.kind == .rule }
            .map {
                ProviderRuleViewData(
                    id: $0.id,
                    name: $0.name,
                    preview: $0.preview,
                    relativePath: $0.relativePath ?? "\($0.name).rules",
                    path: $0.path
                )
            }
            .sorted { $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending }
    }

    public func mapAgentDocs(_ items: [ProviderResourceItem]) -> [ProviderAgentDocViewData] {
        items
            .filter { $0.kind == .agent }
            .compactMap {
                guard let kind = $0.agentKind else { return nil }
                return ProviderAgentDocViewData(
                    id: $0.path,
                    fileName: $0.name,
                    path: $0.path,
                    preview: $0.preview,
                    kind: kind
                )
            }
            .sorted {
                if $0.kind == $1.kind {
                    return $0.fileName.localizedCaseInsensitiveCompare($1.fileName) == .orderedAscending
                }
                return $0.kind == .override
            }
    }

    public func map(snapshot: ProviderResourceSnapshot) -> (
        workflows: [ProviderWorkflowViewData],
        rules: [ProviderRuleViewData],
        agents: [ProviderAgentDocViewData]
    ) {
        (
            workflows: mapWorkflows(snapshot.workflows),
            rules: mapRules(snapshot.rules),
            agents: mapAgentDocs(snapshot.agents)
        )
    }
}
