import Foundation

@MainActor
final class CodexSessionsPreferencesStore {
    private enum Keys {
        static func groupingMode(providerID: String) -> String {
            "codex.sessions.\(providerID).grouping_mode"
        }

        static func sortMode(providerID: String) -> String {
            "codex.sessions.\(providerID).sort_mode"
        }
    }

    private let providerID: String
    private let userDefaults: UserDefaults

    init(providerID: String, userDefaults: UserDefaults = .standard) {
        self.providerID = providerID
        self.userDefaults = userDefaults
    }

    var groupingMode: CodexSessionsTabViewModel.SessionGroupingMode {
        get {
            guard
                let rawValue = userDefaults.string(forKey: Keys.groupingMode(providerID: providerID)),
                let groupingMode = CodexSessionsTabViewModel.SessionGroupingMode(rawValue: rawValue)
            else {
                return .project
            }
            return groupingMode
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: Keys.groupingMode(providerID: providerID))
        }
    }

    var sortMode: CodexSessionsTabViewModel.SessionSortMode {
        get {
            guard
                let rawValue = userDefaults.string(forKey: Keys.sortMode(providerID: providerID)),
                let sortMode = CodexSessionsTabViewModel.SessionSortMode(rawValue: rawValue)
            else {
                return .recent
            }
            return sortMode
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: Keys.sortMode(providerID: providerID))
        }
    }
}
