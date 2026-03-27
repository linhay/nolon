import Foundation

public enum GatewayCandidateSectionTone: Sendable {
    case relay
    case openAI
    case premium
    case generic
}

public struct GatewayAccountCandidateItemData: Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let subtitle: String?

    public init(
        id: UUID,
        title: String,
        subtitle: String?
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
    }
}

public struct GatewayAccountCandidateSectionData: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let iconName: String
    public let tone: GatewayCandidateSectionTone
    public let items: [GatewayAccountCandidateItemData]

    public init(
        id: String,
        title: String,
        iconName: String,
        tone: GatewayCandidateSectionTone,
        items: [GatewayAccountCandidateItemData]
    ) {
        self.id = id
        self.title = title
        self.iconName = iconName
        self.tone = tone
        self.items = items
    }
}
