import SwiftUI
import ServiceManagement

/// App-level settings using @AppStorage for persistence
@Observable
final class AppSettings {
    
    static let shared = AppSettings()
    
    // MARK: - Unlinking Policy
    enum UnlinkingPolicy: String, CaseIterable, Identifiable {
        case askEveryTime = "askEveryTime"
        case keepSyncedFiles = "keepSyncedFiles"
        case deleteSyncedFiles = "deleteSyncedFiles"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .askEveryTime: NSLocalizedString("settings.unlinking.ask", comment: "Ask every time")
            case .keepSyncedFiles: NSLocalizedString("settings.unlinking.keep", comment: "Keep synced files")
            case .deleteSyncedFiles: NSLocalizedString("settings.unlinking.delete", comment: "Delete synced files")
            }
        }
        
        var description: String {
            switch self {
            case .askEveryTime: NSLocalizedString("settings.unlinking.ask_desc", comment: "Show a confirmation dialog")
            case .keepSyncedFiles: NSLocalizedString("settings.unlinking.keep_desc", comment: "Skip confirmation, only remove the link")
            case .deleteSyncedFiles: NSLocalizedString("settings.unlinking.delete_desc", comment: "Skip confirmation, delete both link and files")
            }
        }
    }
    
    // MARK: - Appearance
    enum Appearance: String, CaseIterable, Identifiable {
        case system = "system"
        case light = "light"
        case dark = "dark"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .system: NSLocalizedString("appearance.system", comment: "System")
            case .light: NSLocalizedString("appearance.light", comment: "Light")
            case .dark: NSLocalizedString("appearance.dark", comment: "Dark")
            }
        }
        
        var colorScheme: ColorScheme? {
            switch self {
            case .system: nil
            case .light: .light
            case .dark: .dark
            }
        }
    }
    
    // MARK: - Language
    enum Language: String, CaseIterable, Identifiable {
        case system = ""
        case english = "en"
        case simplifiedChinese = "zh-Hans"
        case traditionalChinese = "zh-Hant"
        case japanese = "ja"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .system: NSLocalizedString("language.system", comment: "System")
            case .english: NSLocalizedString("language.en", comment: "English")
            case .simplifiedChinese: NSLocalizedString("language.zh-Hans", comment: "Simplified Chinese")
            case .traditionalChinese: NSLocalizedString("language.zh-Hant", comment: "Traditional Chinese")
            case .japanese: NSLocalizedString("language.ja", comment: "Japanese")
            }
        }
    }
    
    // MARK: - Properties
    private enum Keys {
        static let appearance = "app.appearance"
        static let language = "app.language"
        static let unlinkingPolicy = "app.unlinking_policy"
    }
    
    var appearance: Appearance {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: Keys.appearance)
            applyAppearance()
        }
    }
    
    var language: Language {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Keys.language)
            applyLanguage()
        }
    }
    
    var unlinkingPolicy: UnlinkingPolicy {
        didSet {
            UserDefaults.standard.set(unlinkingPolicy.rawValue, forKey: Keys.unlinkingPolicy)
        }
    }
    
    var workspacePath: String {
        NolonManager.shared.rootPath
    }
    
    var launchAtLogin: Bool {
        get {
            SMAppService.mainApp.status == .enabled
        }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to update launch at login: \(error)")
            }
        }
    }
    
    // MARK: - Init
    private init() {
        let appearanceValue = UserDefaults.standard.string(forKey: Keys.appearance) ?? Appearance.system.rawValue
        self.appearance = Appearance(rawValue: appearanceValue) ?? .system
        
        let languageValue = UserDefaults.standard.string(forKey: Keys.language) ?? ""
        self.language = Language(rawValue: languageValue) ?? .system
        
        let unlinkingValue = UserDefaults.standard.string(forKey: Keys.unlinkingPolicy) ?? UnlinkingPolicy.askEveryTime.rawValue
        self.unlinkingPolicy = UnlinkingPolicy(rawValue: unlinkingValue) ?? .askEveryTime
    }
    
    // MARK: - Apply Settings
    func applyAppearance() {
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }
        
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first {
                switch self.appearance {
                case .system:
                    window.appearance = nil
                case .light:
                    window.appearance = NSAppearance(named: .aqua)
                case .dark:
                    window.appearance = NSAppearance(named: .darkAqua)
                }
            }
        }
    }
    
    func applyLanguage() {
        if language == .system {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")
        }
        // Note: Language change requires app restart to take effect
    }
    
    func applyAllSettings() {
        applyAppearance()
    }
}
