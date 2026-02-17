import Foundation

public typealias UsageMonitorProviderSettings = ProviderUsageMonitorSettings

public extension ProviderAccountUsageOutcome {
    var displayName: String {
        switch self.account {
        case .default:
            return NSLocalizedString("usage.account.default", value: "Default session", comment: "Default account label")
        case let .tokenAccount(account):
            return account.displayName
        }
    }
}
