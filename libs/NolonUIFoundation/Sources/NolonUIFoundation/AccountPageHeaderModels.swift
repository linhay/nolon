import Foundation

public struct AccountPageHeaderData: Sendable {
    public let title: String
    public let subtitle: String
    public let refreshTitle: String
    public let addAccountTitle: String
    public let isRefreshing: Bool

    public init(
        title: String = NSLocalizedString(
            "accounts.title",
            value: "Account Panorama",
            comment: "Accounts title"
        ),
        subtitle: String = NSLocalizedString(
            "accounts.empty.description",
            value: "Unified management for all account-enabled providers.",
            comment: "Accounts subtitle"
        ),
        refreshTitle: String = NSLocalizedString(
            "accounts.action.refresh",
            value: "Refresh All",
            comment: "Refresh accounts"
        ),
        addAccountTitle: String = NSLocalizedString(
            "accounts.action.add_account",
            value: "+ Add Account",
            comment: "Add account action"
        ),
        isRefreshing: Bool
    ) {
        self.title = title
        self.subtitle = subtitle
        self.refreshTitle = refreshTitle
        self.addAccountTitle = addAccountTitle
        self.isRefreshing = isRefreshing
    }
}
