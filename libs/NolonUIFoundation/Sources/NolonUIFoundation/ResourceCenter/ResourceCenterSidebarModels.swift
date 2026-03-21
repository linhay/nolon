import Foundation

public enum ResourceCenterTabID: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case skills
    case workflows
    case mcps

    public var id: Self { self }
}

public struct ResourceCenterTabItem: Codable, Hashable, Sendable, Identifiable {
    public let id: ResourceCenterTabID
    public let titleKey: String
    public let fallbackTitle: String
    public let iconName: String
    public let count: Int

    public init(
        id: ResourceCenterTabID,
        titleKey: String,
        fallbackTitle: String,
        iconName: String,
        count: Int
    ) {
        self.id = id
        self.titleKey = titleKey
        self.fallbackTitle = fallbackTitle
        self.iconName = iconName
        self.count = count
    }
}

public extension ResourceCenterTabItem {
    static func defaults(counts: [ResourceCenterTabID: Int] = [:]) -> [ResourceCenterTabItem] {
        [
            .init(
                id: .skills,
                titleKey: "tab.skills",
                fallbackTitle: "Skills",
                iconName: "square.grid.2x2",
                count: counts[.skills] ?? 0
            ),
            .init(
                id: .workflows,
                titleKey: "tab.workflows",
                fallbackTitle: "Workflows",
                iconName: "arrow.triangle.branch",
                count: counts[.workflows] ?? 0
            ),
            .init(
                id: .mcps,
                titleKey: "tab.mcps",
                fallbackTitle: "MCPs",
                iconName: "server.rack",
                count: counts[.mcps] ?? 0
            )
        ]
    }
}
