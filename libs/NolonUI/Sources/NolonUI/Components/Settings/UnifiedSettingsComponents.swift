import NolonUIFoundation
import SwiftUI

// MARK: - UnifiedSettingsCardViews

public struct SettingsActionCardView: View {
    public struct Config {
        public var data: SettingsActionCardData
        public var onTap: () -> Void

        public init(
            data: SettingsActionCardData,
            onTap: @escaping () -> Void
        ) {
            self.data = data
            self.onTap = onTap
        }
    }

    let data: SettingsActionCardData
    let onTap: () -> Void

    public init(config: Config) {
        self.data = config.data
        self.onTap = config.onTap
    }

    public init(data: SettingsActionCardData, onTap: @escaping () -> Void) {
        self.init(config: Config(data: data, onTap: onTap))
    }

    public var body: some View {
        Button(action: onTap) {
            SettingsCardContainer {
                HStack {
                    leadingView
                    Text(data.title)
                    Spacer()
                    if let trailingText = data.trailingText, !trailingText.isEmpty {
                        Text(trailingText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(trailingColor)
                    }
                }
            }
        }
        .dsLinkButton()
    }

    @ViewBuilder
    private var leadingView: some View {
        if data.isLeadingLoading {
            ProgressView()
                .controlSize(.small)
        } else if let image = data.leadingSystemImage {
            Image(systemName: image)
        }
    }

    private var trailingColor: Color {
        switch data.trailingTone {
        case .secondary:
            return DesignSystem.Colors.Text.secondary
        case .warning:
            return DesignSystem.Colors.Status.warning
        }
    }
}

public struct SettingsWorkspaceCardView: View {
    public struct Config {
        public var data: SettingsWorkspaceCardData

        public init(data: SettingsWorkspaceCardData) {
            self.data = data
        }
    }

    let data: SettingsWorkspaceCardData

    public init(config: Config) {
        self.data = config.data
    }

    public init(data: SettingsWorkspaceCardData) {
        self.init(config: Config(data: data))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(data.label)
                .font(.caption)
                .dsSecondaryText(font: .caption)

            SettingsCardContainer(alignment: .leading) {
                HStack(spacing: 12) {
                    Image(systemName: "folder")
                        .dsSecondaryText(font: .body)
                    Text(data.path)
                        .font(.system(size: 13, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
    }
}

private struct SettingsCardContainer<Content: View>: View {
    let alignment: Alignment
    @ViewBuilder let content: Content

    init(
        alignment: Alignment = .center,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: alignment)
            .dsCard()
    }
}

// MARK: - UnifiedSettingsContentViews

public struct AboutSettingsSectionView: View {
    public struct Config {
        public var data: AboutSettingsData
        public var onCheckUpdates: () -> Void

        public init(
            data: AboutSettingsData,
            onCheckUpdates: @escaping () -> Void
        ) {
            self.data = data
            self.onCheckUpdates = onCheckUpdates
        }
    }

    let data: AboutSettingsData
    let onCheckUpdates: () -> Void

    public init(config: Config) {
        self.data = config.data
        self.onCheckUpdates = config.onCheckUpdates
    }

    public init(data: AboutSettingsData, onCheckUpdates: @escaping () -> Void) {
        self.init(config: Config(data: data, onCheckUpdates: onCheckUpdates))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(data.appName)
                        .font(.system(size: 15, weight: .bold))

                    if let version = data.version, !version.isEmpty {
                        Text(version)
                            .font(.caption)
                            .dsSecondaryText(font: .caption)
                    }
                }

                Text(data.description)
                    .font(.subheadline)
                    .dsSecondaryText(font: .subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dsCard()

            Button(action: onCheckUpdates) {
                HStack {
                    Text(data.checkUpdatesTitle)
                    Spacer()
                    Image(systemName: "arrow.up.circle")
                        .dsSecondaryText(font: .body)
                }
                .padding(16)
                .dsCard()
            }
            .dsLinkButton()
        }
    }
}

public struct AdvancedSettingsContentView: View {
    public struct Config {
        public var skillLockTitle: String
        public var skillLockData: SettingsDescriptionToggleActionData
        public var overwriteExisting: Binding<Bool>
        public var isRebuildingSkillLock: Bool
        public var onTapRebuildSkillLock: () -> Void
        public var updatesTitle: String
        public var updatesActionData: SettingsActionCardData
        public var onTapUpdates: () -> Void

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
            self.overwriteExisting = overwriteExisting
            self.isRebuildingSkillLock = isRebuildingSkillLock
            self.onTapRebuildSkillLock = onTapRebuildSkillLock
            self.updatesTitle = updatesTitle
            self.updatesActionData = updatesActionData
            self.onTapUpdates = onTapUpdates
        }
    }

    let skillLockTitle: String
    let skillLockData: SettingsDescriptionToggleActionData
    @Binding var overwriteExisting: Bool
    let isRebuildingSkillLock: Bool
    let onTapRebuildSkillLock: () -> Void

    let updatesTitle: String
    let updatesActionData: SettingsActionCardData
    let onTapUpdates: () -> Void

    public init(config: Config) {
        self.skillLockTitle = config.skillLockTitle
        self.skillLockData = config.skillLockData
        self._overwriteExisting = config.overwriteExisting
        self.isRebuildingSkillLock = config.isRebuildingSkillLock
        self.onTapRebuildSkillLock = config.onTapRebuildSkillLock
        self.updatesTitle = config.updatesTitle
        self.updatesActionData = config.updatesActionData
        self.onTapUpdates = config.onTapUpdates
    }

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
        self.init(
            config: Config(
                skillLockTitle: skillLockTitle,
                skillLockData: skillLockData,
                overwriteExisting: overwriteExisting,
                isRebuildingSkillLock: isRebuildingSkillLock,
                onTapRebuildSkillLock: onTapRebuildSkillLock,
                updatesTitle: updatesTitle,
                updatesActionData: updatesActionData,
                onTapUpdates: onTapUpdates
            )
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsSectionView(config: .init(title: skillLockTitle)) {
                SettingsDescriptionToggleActionView(
                    data: skillLockData,
                    toggleValue: $overwriteExisting,
                    isActionDisabled: isRebuildingSkillLock,
                    onActionTap: onTapRebuildSkillLock
                )
            }

            SettingsSectionView(config: .init(title: updatesTitle)) {
                SettingsActionCardView(
                    data: updatesActionData,
                    onTap: onTapUpdates
                )
            }
        }
    }
}

public struct DisplaySettingsContentView: View {
    public struct Config {
        public var data: DisplaySettingsContentData
        public var onSelectAppearance: (String) -> Void
        public var onSelectLanguage: (String) -> Void

        public init(
            data: DisplaySettingsContentData,
            onSelectAppearance: @escaping (String) -> Void,
            onSelectLanguage: @escaping (String) -> Void
        ) {
            self.data = data
            self.onSelectAppearance = onSelectAppearance
            self.onSelectLanguage = onSelectLanguage
        }
    }

    let data: DisplaySettingsContentData
    let onSelectAppearance: (String) -> Void
    let onSelectLanguage: (String) -> Void

    public init(config: Config) {
        self.data = config.data
        self.onSelectAppearance = config.onSelectAppearance
        self.onSelectLanguage = config.onSelectLanguage
    }

    public init(
        data: DisplaySettingsContentData,
        onSelectAppearance: @escaping (String) -> Void,
        onSelectLanguage: @escaping (String) -> Void
    ) {
        self.init(config: Config(data: data, onSelectAppearance: onSelectAppearance, onSelectLanguage: onSelectLanguage))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsSectionView(config: .init(title: data.appearanceTitle)) {
                SettingsCardRows(config: .init()) {
                    ForEach(data.appearanceOptions) { option in
                        SelectableSettingsRowView(data: option.row) {
                            onSelectAppearance(option.id)
                        }
                    }
                }
            }

            SettingsSectionView(config: .init(title: data.languageTitle)) {
                SettingsCardRows(config: .init()) {
                    ForEach(data.languageOptions) { option in
                        SelectableSettingsRowView(data: option.row) {
                            onSelectLanguage(option.id)
                        }
                    }
                }
            }
        }
    }
}

public struct GeneralSettingsContentView: View {
    public struct Config {
        public var projectConfigurationTitle: String
        public var workspaceData: SettingsWorkspaceCardData
        public var importingTitle: String
        public var onboardingActionData: SettingsActionCardData
        public var onTapOnboardingAction: () -> Void

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
    }

    let projectConfigurationTitle: String
    let workspaceData: SettingsWorkspaceCardData
    let importingTitle: String
    let onboardingActionData: SettingsActionCardData
    let onTapOnboardingAction: () -> Void

    public init(config: Config) {
        self.projectConfigurationTitle = config.projectConfigurationTitle
        self.workspaceData = config.workspaceData
        self.importingTitle = config.importingTitle
        self.onboardingActionData = config.onboardingActionData
        self.onTapOnboardingAction = config.onTapOnboardingAction
    }

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
        self.init(
            config: Config(
                projectConfigurationTitle: projectConfigurationTitle,
                workspaceData: workspaceData,
                importingTitle: importingTitle,
                onboardingActionData: onboardingActionData,
                onTapOnboardingAction: onTapOnboardingAction
            )
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsSectionView(config: .init(title: projectConfigurationTitle)) {
                SettingsWorkspaceCardView(data: workspaceData)
            }

            SettingsSectionView(config: .init(title: importingTitle)) {
                SettingsActionCardView(
                    data: onboardingActionData,
                    onTap: onTapOnboardingAction
                )
            }
        }
    }
}

public struct UpdatesSheetContentView: View {
    public struct Config {
        public var data: UpdatesSheetContentData
        public var onRefresh: () -> Void
        public var onClose: () -> Void
        public var onTapUpdate: (String) -> Void

        public init(
            data: UpdatesSheetContentData,
            onRefresh: @escaping () -> Void,
            onClose: @escaping () -> Void,
            onTapUpdate: @escaping (String) -> Void
        ) {
            self.data = data
            self.onRefresh = onRefresh
            self.onClose = onClose
            self.onTapUpdate = onTapUpdate
        }
    }

    let data: UpdatesSheetContentData
    let onRefresh: () -> Void
    let onClose: () -> Void
    let onTapUpdate: (String) -> Void

    public init(config: Config) {
        self.data = config.data
        self.onRefresh = config.onRefresh
        self.onClose = config.onClose
        self.onTapUpdate = config.onTapUpdate
    }

    public init(
        data: UpdatesSheetContentData,
        onRefresh: @escaping () -> Void,
        onClose: @escaping () -> Void,
        onTapUpdate: @escaping (String) -> Void
    ) {
        self.init(
            config: Config(
                data: data,
                onRefresh: onRefresh,
                onClose: onClose,
                onTapUpdate: onTapUpdate
            )
        )
    }

    public var body: some View {
        SheetHeaderSection(
            title: data.title,
            subtitle: data.subtitle
        ) {
            headerTrailingActions
        } content: {
            contentView
        }
    }

    private var headerTrailingActions: some View {
        HStack(spacing: 12) {
            if let availableCountText = data.availableCountText {
                Label(availableCountText, systemImage: "arrow.down.circle")
                    .dsIconLabelText(
                        foreground: DesignSystem.Colors.Status.info,
                        font: .subheadline
                    )
            }

            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .dsIconButton()
            }
            .disabled(data.isChecking)
            .help(data.refreshHelpText)

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .dsIconButton(size: 22, foreground: DesignSystem.Colors.Text.tertiary)
            }
            .dsLinkButton()
            .accessibilityLabel(data.closeAccessibilityLabel)
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if data.isChecking {
            CenteredLoadingIndicatorView()
                .padding()
        } else if data.rows.isEmpty {
            EmptyStateScaffold(
                isEmpty: true,
                emptyTitle: data.emptyTitle,
                emptySystemImage: data.emptySystemImage,
                emptyDescription: data.emptyDescription
            ) {
                EmptyView()
            }
            .padding()
            .frame(maxHeight: .infinity)
        } else {
            SheetPaddedList(data.rows) { row in
                SkillUpdateRowView(data: row) {
                    onTapUpdate(row.id)
                }
            }
        }
    }
}

// MARK: - UnifiedSettingsRowViews

public struct SettingsCardRows<Content: View>: View {
    let content: () -> Content

    public struct Config {
        public init() {}
    }

    public init(
        config: Config,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.content = content
    }

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.init(
            config: Config(),
            content: content
        )
    }

    public var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .dsCard()
    }
}

public struct SelectableSettingsRowView: View {
    public struct Config {
        public var data: SelectableSettingsRowData
        public var onTap: () -> Void

        public init(
            data: SelectableSettingsRowData,
            onTap: @escaping () -> Void
        ) {
            self.data = data
            self.onTap = onTap
        }
    }

    let data: SelectableSettingsRowData
    let onTap: () -> Void

    public init(config: Config) {
        self.data = config.data
        self.onTap = config.onTap
    }

    public init(data: SelectableSettingsRowData, onTap: @escaping () -> Void) {
        self.init(config: Config(data: data, onTap: onTap))
    }

    public var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                if let icon = data.leadingSystemImage {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .frame(width: 24)
                }

                Text(data.title)
                    .font(.system(size: 13, weight: .medium))

                Spacer()

                if data.isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.primary)
                }
            }
            .padding(CGFloat(data.contentPadding))
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    if data.isSelected {
                        RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusM)
                            .stroke(DesignSystem.Colors.primary.opacity(0.5), lineWidth: 2)
                            .background(DesignSystem.Colors.primary.opacity(0.05))
                            .shadow(
                                color: data.showsSelectionShadow ? DesignSystem.Colors.primary.opacity(0.2) : .clear,
                                radius: data.showsSelectionShadow ? 8 : 0
                            )
                    }
                }
            )
        }
        .dsLinkButton()
    }
}

public struct SettingsDescriptionToggleActionView: View {
    public struct Config {
        public var data: SettingsDescriptionToggleActionData
        public var toggleValue: Binding<Bool>
        public var isActionDisabled: Bool
        public var onActionTap: () -> Void

        public init(
            data: SettingsDescriptionToggleActionData,
            toggleValue: Binding<Bool>,
            isActionDisabled: Bool,
            onActionTap: @escaping () -> Void
        ) {
            self.data = data
            self.toggleValue = toggleValue
            self.isActionDisabled = isActionDisabled
            self.onActionTap = onActionTap
        }
    }

    let data: SettingsDescriptionToggleActionData
    @Binding var toggleValue: Bool
    let isActionDisabled: Bool
    let onActionTap: () -> Void

    public init(config: Config) {
        self.data = config.data
        self._toggleValue = config.toggleValue
        self.isActionDisabled = config.isActionDisabled
        self.onActionTap = config.onActionTap
    }

    public init(
        data: SettingsDescriptionToggleActionData,
        toggleValue: Binding<Bool>,
        isActionDisabled: Bool,
        onActionTap: @escaping () -> Void
    ) {
        self.init(
            config: Config(
                data: data,
                toggleValue: toggleValue,
                isActionDisabled: isActionDisabled,
                onActionTap: onActionTap
            )
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(data.description)
                .font(.caption)
                .dsSecondaryText(font: .caption)

            Toggle(data.toggleTitle, isOn: $toggleValue)

            SettingsActionCardView(data: data.actionCard, onTap: onActionTap)
                .disabled(isActionDisabled)

            if let resultMessage = data.resultMessage, !resultMessage.isEmpty {
                Text(resultMessage)
                    .font(.caption)
                    .dsSecondaryText(font: .caption)
            }

            if let errorMessage = data.errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .dsErrorText(font: .caption)
            }
        }
    }
}
