import Foundation

public struct PluginNavigationData: Sendable {
    public let itemTitle: String
    public let itemSystemImage: String
    public let groupTitle: String

    public init(itemTitle: String, itemSystemImage: String, groupTitle: String) {
        self.itemTitle = itemTitle
        self.itemSystemImage = itemSystemImage
        self.groupTitle = groupTitle
    }
}
