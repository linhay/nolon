import Foundation

public struct RemoteResourceDetailData: Sendable {
    public struct StatItem: Identifiable, Sendable {
        public let id: String
        public let title: String
        public let systemImage: String

        public init(id: String, title: String, systemImage: String) {
            self.id = id
            self.title = title
            self.systemImage = systemImage
        }
    }

    public enum Section: Identifiable, Sendable {
        case markdown(id: String, title: String, content: String)
        case codeBlock(id: String, title: String, content: String)
        case list(id: String, title: String, items: [String], monospaced: Bool)
        case kvList(id: String, title: String, items: [String], monospaced: Bool)

        public var id: String {
            switch self {
            case .markdown(let id, _, _):
                return id
            case .codeBlock(let id, _, _):
                return id
            case .list(let id, _, _, _):
                return id
            case .kvList(let id, _, _, _):
                return id
            }
        }
    }

    public let title: String
    public let subtitle: String?
    public let stats: [StatItem]
    public let sections: [Section]
    public let providers: [SkillInstallProviderOption]
    public let preferredProviderID: String?

    public init(
        title: String,
        subtitle: String?,
        stats: [StatItem],
        sections: [Section],
        providers: [SkillInstallProviderOption],
        preferredProviderID: String?
    ) {
        self.title = title
        self.subtitle = subtitle
        self.stats = stats
        self.sections = sections
        self.providers = providers
        self.preferredProviderID = preferredProviderID
    }
}
