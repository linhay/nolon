import SwiftUI
import NolonUIFoundation

public struct AdvancedSettingsContentView: View {
    let skillLockTitle: String
    let skillLockData: SettingsDescriptionToggleActionData
    @Binding var overwriteExisting: Bool
    let isRebuildingSkillLock: Bool
    let onTapRebuildSkillLock: () -> Void

    let updatesTitle: String
    let updatesActionData: SettingsActionCardData
    let onTapUpdates: () -> Void

    public init(
        skillLockTitle: String = NSLocalizedString(
            "settings.advanced.skill_lock.title",
            value: "Skill Lock",
            comment: "Skill lock section title"
        ),
        skillLockData: SettingsDescriptionToggleActionData,
        overwriteExisting: Binding<Bool>,
        isRebuildingSkillLock: Bool,
        onTapRebuildSkillLock: @escaping () -> Void,
        updatesTitle: String = NSLocalizedString(
            "settings.advanced.updates.title",
            value: "Updates",
            comment: "Updates section title"
        ),
        updatesActionData: SettingsActionCardData,
        onTapUpdates: @escaping () -> Void
    ) {
        self.skillLockTitle = skillLockTitle
        self.skillLockData = skillLockData
        self._overwriteExisting = overwriteExisting
        self.isRebuildingSkillLock = isRebuildingSkillLock
        self.onTapRebuildSkillLock = onTapRebuildSkillLock
        self.updatesTitle = updatesTitle
        self.updatesActionData = updatesActionData
        self.onTapUpdates = onTapUpdates
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsSectionView(title: skillLockTitle) {
                SettingsDescriptionToggleActionView(
                    data: skillLockData,
                    toggleValue: $overwriteExisting,
                    isActionDisabled: isRebuildingSkillLock,
                    onActionTap: onTapRebuildSkillLock
                )
            }

            SettingsSectionView(title: updatesTitle) {
                SettingsActionCardView(
                    data: updatesActionData,
                    onTap: onTapUpdates
                )
            }
        }
    }
}
