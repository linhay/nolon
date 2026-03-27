import Foundation
import Observation
import NolonResourceKit
import NolonUIFoundation

enum SettingsCategory: String, CaseIterable, Identifiable {
    case general = "General"
    case display = "Display"
    case advanced = "Advanced"
    case about = "About"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .general: NSLocalizedString("settings.category.general", value: "General", comment: "Category")
        case .display: NSLocalizedString("settings.category.display", value: "Display", comment: "Category")
        case .advanced: NSLocalizedString("settings.category.advanced", value: "Advanced", comment: "Category")
        case .about: NSLocalizedString("settings.category.about", value: "About", comment: "Category")
        }
    }
}

@MainActor
@Observable
final class AppSettingsViewModel {
    var settingsStore = AppSettingsStore.shared
    var selectedCategory: SettingsCategory = .general
    var showingOnboardingResetConfirm = false

    var overwriteExisting = false
    var isRebuildingSkillLock = false
    var rebuildResultMessage: String?
    var rebuildErrorMessage: String?
    var showingRebuildConfirmation = false
    var showingUpdatesSheet = false
    var updateCount = 0

    private let defaults: UserDefaults
    private let onboardingCompletedKey = "hasCompletedOnboarding"

    private let supportedLanguages: [AppLanguage] = [
        .simplifiedChinese,
        .english,
    ]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var sidebarItems: [SettingsSidebarItemData] {
        SettingsCategory.allCases.map { category in
            SettingsSidebarItemData(id: category.rawValue, title: category.displayName)
        }
    }

    var selectedCategoryID: String {
        get { selectedCategory.rawValue }
        set { selectedCategory = SettingsCategory(rawValue: newValue) ?? .general }
    }

    var aboutSettingsData: AboutSettingsData {
        AboutSettingsData(
            appName: "nolon",
            version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            description: NSLocalizedString(
                "settings.about.description",
                value: "Desktop workspace for managing agent assets and distributing skills, memory docs, and sync rules.",
                comment: "About text"
            ),
            checkUpdatesTitle: NSLocalizedString(
                "settings.about.check_updates",
                value: "Check for updates",
                comment: "Button"
            )
        )
    }

    var onboardingResetConfirmationData: ConfirmationAlertData {
        ConfirmationAlertData(
            title: NSLocalizedString(
                "settings.onboarding.reset.confirm_title",
                value: "Run onboarding again?",
                comment: "Onboarding reset confirmation title"
            ),
            message: NSLocalizedString(
                "settings.onboarding.reset.confirm_message",
                value: "This will show onboarding again the next time the main window appears.",
                comment: "Onboarding reset confirmation message"
            ),
            confirmTitle: NSLocalizedString(
                "settings.onboarding.reset.confirm_action",
                value: "Run",
                comment: "Onboarding reset confirmation action"
            ),
            cancelTitle: NSLocalizedString("action.cancel", value: "Cancel", comment: "Cancel")
        )
    }

    var displayData: DisplaySettingsContentData {
        DisplaySettingsContentData(
            appearanceTitle: NSLocalizedString("settings.appearance", value: "Appearance", comment: "Section title"),
            appearanceOptions: AppAppearance.allCases.map { appearance in
                DisplaySettingsOptionRowData(
                    id: appearance.rawValue,
                    row: .init(
                        title: appearance.displayName,
                        leadingSystemImage: appearanceIcon(for: appearance),
                        isSelected: settingsStore.appearance == appearance,
                        contentPadding: 20,
                        showsSelectionShadow: true
                    )
                )
            },
            languageTitle: NSLocalizedString("settings.language", value: "Language", comment: "Section title"),
            languageOptions: supportedLanguages.map { language in
                DisplaySettingsOptionRowData(
                    id: language.rawValue,
                    row: .init(
                        title: language.displayName,
                        leadingSystemImage: nil,
                        isSelected: settingsStore.language == language,
                        contentPadding: 16,
                        showsSelectionShadow: false
                    )
                )
            }
        )
    }

    var rebuildSkillLockConfirmationData: ConfirmationAlertData {
        ConfirmationAlertData(
            title: NSLocalizedString(
                "settings.advanced.skill_lock.confirm_title",
                value: "Rebuild Skill Lock?",
                comment: "Confirm title"
            ),
            message: NSLocalizedString(
                "settings.advanced.skill_lock.confirm_message",
                value: "This will scan your global skills folder and write .skill-lock.json. You can keep existing entries or overwrite them.",
                comment: "Confirm message"
            ),
            confirmTitle: NSLocalizedString(
                "settings.advanced.skill_lock.confirm_action",
                value: "Rebuild",
                comment: "Confirm action"
            ),
            cancelTitle: NSLocalizedString("action.cancel", comment: "Cancel")
        )
    }

    var skillLockSectionData: SettingsDescriptionToggleActionData {
        SettingsDescriptionToggleActionData(
            description: NSLocalizedString(
                "settings.advanced.skill_lock.description",
                value: "Rebuild the .skill-lock.json file by scanning ~/.nolon/skills. This helps update checking work for existing installations.",
                comment: "Description"
            ),
            toggleTitle: NSLocalizedString(
                "settings.advanced.skill_lock.overwrite",
                value: "Overwrite existing entries",
                comment: "Overwrite toggle"
            ),
            actionCard: .init(
                leadingSystemImage: "arrow.triangle.2.circlepath",
                isLeadingLoading: isRebuildingSkillLock,
                title: NSLocalizedString(
                    "settings.advanced.skill_lock.rebuild",
                    value: "Rebuild .skill-lock.json",
                    comment: "Rebuild action"
                )
            ),
            resultMessage: rebuildResultMessage,
            errorMessage: rebuildErrorMessage
        )
    }

    var updatesActionData: SettingsActionCardData {
        .init(
            leadingSystemImage: updateCount > 0 ? "arrow.down.circle.fill" : "arrow.down.circle",
            title: NSLocalizedString(
                "settings.advanced.updates.open",
                value: "Manage skill updates",
                comment: "Open updates"
            ),
            trailingText: updateCount > 0 ? "\(updateCount)" : nil,
            trailingTone: .warning
        )
    }

    func confirmOnboardingReset() {
        defaults.set(false, forKey: onboardingCompletedKey)
    }

    func selectAppearance(id: String) {
        guard let appearance = AppAppearance(rawValue: id) else { return }
        settingsStore.appearance = appearance
    }

    func selectLanguage(id: String) {
        guard let language = AppLanguage(rawValue: id) else { return }
        settingsStore.language = language
    }

    func normalizeLanguageIfNeeded() {
        guard !supportedLanguages.contains(settingsStore.language) else { return }
        let preferred = Locale.preferredLanguages.first ?? ""
        settingsStore.language = preferred.hasPrefix("zh") ? .simplifiedChinese : .english
    }

    func refreshUpdateCount() async {
        let checker = SkillUpdateChecker()
        updateCount = await checker.getUpdatableSkillsCount()
    }

    func rebuildSkillLock() async {
        isRebuildingSkillLock = true
        rebuildResultMessage = NSLocalizedString(
            "settings.advanced.skill_lock.running",
            value: "Rebuilding .skill-lock.json...",
            comment: "Running"
        )
        rebuildErrorMessage = nil
        defer { isRebuildingSkillLock = false }

        do {
            let manager = SkillLockFileManager()
            let result = try await manager.rebuildFromGlobalSkills(overwriteExisting: overwriteExisting)
            rebuildResultMessage = String(
                format: NSLocalizedString(
                    "settings.advanced.skill_lock.success",
                    value: "Done. Processed %d, added %d, updated %d, skipped %d.",
                    comment: "Success"
                ),
                result.processedCount,
                result.addedCount,
                result.updatedCount,
                result.skippedCount
            )
        } catch {
            rebuildResultMessage = nil
            rebuildErrorMessage = String(
                format: NSLocalizedString(
                    "settings.advanced.skill_lock.failed",
                    value: "Failed to rebuild: %@",
                    comment: "Failure"
                ),
                error.localizedDescription
            )
        }
    }

    private func appearanceIcon(for appearance: AppAppearance) -> String {
        switch appearance {
        case .light: return "sun.max"
        case .dark: return "moon"
        case .system: return "desktopcomputer"
        }
    }
}
