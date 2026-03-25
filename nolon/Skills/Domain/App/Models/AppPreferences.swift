import Foundation
import SwiftUI

// MARK: - App Preferences (Pure Model)

struct AppPreferences: Codable, Equatable, Sendable {
    var appearance: AppAppearance
    var language: AppLanguage
    var unlinkingPolicy: AppUnlinkingPolicy

    static let `default` = AppPreferences(
        appearance: .system,
        language: .system,
        unlinkingPolicy: .askEveryTime
    )
}

enum AppUnlinkingPolicy: String, CaseIterable, Identifiable, Codable, Sendable {
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

enum AppAppearance: String, CaseIterable, Identifiable, Codable, Sendable {
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

enum AppLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
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

