import Foundation
import ProviderUsage
import CodexBarProviderCatalog

typealias UsageMonitorProviderSettings = ProviderUsageMonitorSettings

typealias ProviderAccountUsageOutcome = ProviderUsage.ProviderAccountUsageOutcome

extension ProviderAccountUsageOutcome {
    var displayName: String {
        switch self.account {
        case .default:
            return NSLocalizedString("usage.account.default", value: "Default session", comment: "Default account label")
        case let .tokenAccount(account):
            return account.displayName
        }
    }
}
