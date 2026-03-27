import Foundation

public struct AccountPageHeaderData: Sendable {
    public let title: String
    public let subtitle: String
    public let refreshTitle: String
    public let addAccountTitle: String
    public let isRefreshing: Bool

    public init(
        title: String,
        subtitle: String,
        refreshTitle: String,
        addAccountTitle: String,
        isRefreshing: Bool
    ) {
        self.title = title
        self.subtitle = subtitle
        self.refreshTitle = refreshTitle
        self.addAccountTitle = addAccountTitle
        self.isRefreshing = isRefreshing
    }
}
