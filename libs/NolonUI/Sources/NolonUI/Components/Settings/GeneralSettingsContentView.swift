import SwiftUI
import NolonUIFoundation

public struct GeneralSettingsContentView: View {
    let projectConfigurationTitle: String
    let workspaceData: SettingsWorkspaceCardData
    let importingTitle: String
    let onboardingActionData: SettingsActionCardData
    let onTapOnboardingAction: () -> Void

    public init(
        projectConfigurationTitle: String = NSLocalizedString(
            "settings.project_configuration.title",
            value: "Project Configuration",
            comment: "Project configuration section title"
        ),
        workspaceData: SettingsWorkspaceCardData,
        importingTitle: String = NSLocalizedString(
            "settings.importing.title",
            value: "Importing",
            comment: "Importing section title"
        ),
        onboardingActionData: SettingsActionCardData,
        onTapOnboardingAction: @escaping () -> Void
    ) {
        self.projectConfigurationTitle = projectConfigurationTitle
        self.workspaceData = workspaceData
        self.importingTitle = importingTitle
        self.onboardingActionData = onboardingActionData
        self.onTapOnboardingAction = onTapOnboardingAction
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsSectionView(title: projectConfigurationTitle) {
                SettingsWorkspaceCardView(data: workspaceData)
            }

            SettingsSectionView(title: importingTitle) {
                SettingsActionCardView(
                    data: onboardingActionData,
                    onTap: onTapOnboardingAction
                )
            }
        }
    }
}
