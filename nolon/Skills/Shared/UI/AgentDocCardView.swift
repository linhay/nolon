enum AgentDocKind: String, Sendable {
    case override
    case base
}

struct AgentDocInfo: Identifiable, Hashable, Sendable {
    let id: String
    let fileName: String
    let path: String
    let preview: String
    let kind: AgentDocKind
}
