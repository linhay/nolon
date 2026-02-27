import AppKit
import Foundation
import OSLog
import ServiceManagement
import SwiftUI
import NolonResourceKit

@MainActor
@Observable
final class AppSettingsStore {
    static let shared = AppSettingsStore(userDefaults: .standard)

    private static let logger = Logger(subsystem: "com.nolon.app", category: "settings")

    private enum Keys {
        static let appearance = "app.appearance"
        static let language = "app.language"
        static let unlinkingPolicy = "app.unlinking_policy"
        static let appleLanguages = "AppleLanguages"
    }

    private let userDefaults: UserDefaults

    var appearance: AppAppearance {
        didSet {
            userDefaults.set(appearance.rawValue, forKey: Keys.appearance)
            applyAppearance()
        }
    }

    var language: AppLanguage {
        didSet {
            userDefaults.set(language.rawValue, forKey: Keys.language)
            applyLanguage()
        }
    }

    var unlinkingPolicy: AppUnlinkingPolicy {
        didSet {
            userDefaults.set(unlinkingPolicy.rawValue, forKey: Keys.unlinkingPolicy)
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
                Self.logger.error("Failed to update launch at login: \(String(describing: error))")
            }
        }
    }

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults

        let appearanceRaw = userDefaults.string(forKey: Keys.appearance) ?? AppAppearance.system.rawValue
        self.appearance = AppAppearance(rawValue: appearanceRaw) ?? .system

        let languageRaw = userDefaults.string(forKey: Keys.language) ?? AppLanguage.system.rawValue
        self.language = AppLanguage(rawValue: languageRaw) ?? .system

        let unlinkRaw = userDefaults.string(forKey: Keys.unlinkingPolicy) ?? AppUnlinkingPolicy.askEveryTime.rawValue
        self.unlinkingPolicy = AppUnlinkingPolicy(rawValue: unlinkRaw) ?? .askEveryTime
    }

    func applyAllSettings() {
        applyAppearance()
        applyLanguage()
    }

    func applyAppearance() {
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }

        switch appearance {
        case .system:
            NSApplication.shared.appearance = nil
        case .light:
            NSApplication.shared.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
        }
    }

    func applyLanguage() {
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }

        AppLocalizationService.setLanguageOverride(language == .system ? nil : language.rawValue)

        if language == .system {
            userDefaults.removeObject(forKey: Keys.appleLanguages)
        } else {
            userDefaults.set([language.rawValue], forKey: Keys.appleLanguages)
        }
    }
}
