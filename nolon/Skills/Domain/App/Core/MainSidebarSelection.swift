import Foundation
import ProviderCatalog

public enum MainSidebarSelection: Hashable {
    case provider(Provider.ID)
    case nolon
    case accounts
    case pluginManagement

    var storageKey: String {
        switch self {
        case .provider(let providerID):
            return "provider:\(providerID)"
        case .nolon:
            return "nolon"
        case .accounts:
            return "accounts"
        case .pluginManagement:
            return "pluginManagement"
        }
    }

    init?(storageKey: String) {
        if storageKey == "nolon" {
            self = .nolon
        } else if storageKey == "accounts" {
            self = .accounts
        } else if storageKey == "pluginManagement" {
            self = .pluginManagement
        } else if storageKey.hasPrefix("provider:") {
            self = .provider(String(storageKey.dropFirst("provider:".count)))
        } else {
            return nil
        }
    }
}
