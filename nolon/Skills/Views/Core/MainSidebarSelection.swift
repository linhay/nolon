import Foundation
import ProviderCatalog

public enum MainSidebarSelection: Hashable {
    case provider(Provider.ID)
    case accounts
    case pluginManagement
}
