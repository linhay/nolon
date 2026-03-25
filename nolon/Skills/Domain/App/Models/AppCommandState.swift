import SwiftUI
import ProviderCatalog

@Observable
final class AppCommandState {
    static let shared = AppCommandState()

    enum PendingNavigation: Equatable {
        case providerTab(providerID: Provider.ID, tab: ProviderContentTabType)
    }

    private enum StorageKey {
        static let debugPageMarkersEnabled = "debug.page_markers.enabled"
    }

    private let userDefaults: UserDefaults

    var showingSettings = false
    var pendingNavigation: PendingNavigation?
    var isDebugPageMarkersEnabled: Bool {
        didSet {
            userDefaults.set(isDebugPageMarkersEnabled, forKey: StorageKey.debugPageMarkersEnabled)
        }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.isDebugPageMarkersEnabled = userDefaults.bool(forKey: StorageKey.debugPageMarkersEnabled)
    }

    nonisolated deinit {}
}
