import Foundation
import ProviderCatalog

enum ProviderUsageLoginPolicy {
    static func shouldUseCLILogin(for provider: Provider) -> Bool {
        guard let templateID = provider.templateId else { return false }
        switch templateID {
        case "gemini", "antigravity":
            return true
        default:
            return false
        }
    }

    static func shouldShowDashboardSignIn(for provider: Provider, dashboardURL: URL?) -> Bool {
        guard dashboardURL != nil else { return false }
        guard let templateID = provider.templateId else { return true }
        switch templateID {
        case "gemini", "antigravity":
            return false
        default:
            return true
        }
    }
}
