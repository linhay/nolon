import Foundation

public enum ResourceCenterUITestActionKind: Sendable {
    case deleteGlobalSkill
    case deleteGlobalWorkflow
    case deleteGlobalMCP
    case deleteProviderSkill
}

public struct ResourceCenterUITestActionData: Sendable, Identifiable {
    public let id: String
    public let kind: ResourceCenterUITestActionKind
    public let slug: String
    public let providerIndex: Int?
    public let title: String
    public let accessibilityIdentifier: String

    public init(
        id: String,
        kind: ResourceCenterUITestActionKind,
        slug: String,
        providerIndex: Int? = nil,
        title: String,
        accessibilityIdentifier: String
    ) {
        self.id = id
        self.kind = kind
        self.slug = slug
        self.providerIndex = providerIndex
        self.title = title
        self.accessibilityIdentifier = accessibilityIdentifier
    }
}
