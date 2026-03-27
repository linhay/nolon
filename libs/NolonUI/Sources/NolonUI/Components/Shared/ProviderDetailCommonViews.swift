import SwiftUI
import NolonUIFoundation

public struct ProviderDetailPlaceholderView: View {
    public enum Preset {
        case noProvider
        case noTab
    }

    let title: String
    let systemImage: String

    public init(title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }

    public init(preset: Preset) {
        switch preset {
        case .noProvider:
            self.title = NSLocalizedString("detail.no_provider", comment: "Select a Provider")
            self.systemImage = "sidebar.left"
        case .noTab:
            self.title = NSLocalizedString("detail.select_tab", comment: "Select a Tab")
            self.systemImage = "list.bullet"
        }
    }

    public var body: some View {
        ContentUnavailableView {
            Label {
                Text(title)
                    .dsEmptyStateTitle()
            } icon: {
                Image(systemName: systemImage)
                    .dsEmptyStateIcon()
            }
        }
    }
}

public struct ProviderWarningCardView: View {
    let message: String

    public init(message: String) {
        self.message = message
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DesignSystem.Colors.Status.warning)
            Text(message)
                .font(.callout)
                .dsSecondaryText(font: .callout)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .dsCard(
            background: DesignSystem.Colors.Status.warning.opacity(0.08),
            cornerRadius: DesignSystem.Metrics.cornerRadiusM,
            borderColor: DesignSystem.Colors.Status.warning.opacity(0.25),
            borderWidth: 1
        )
    }
}

public struct ProviderCodexXcodeNoticeCardView: View {
    let title: String
    let description: String
    let closeAction: () -> Void

    public init(
        title: String,
        description: String,
        closeAction: @escaping () -> Void
    ) {
        self.title = title
        self.description = description
        self.closeAction = closeAction
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "hammer.fill")
                .font(.title3)
                .foregroundStyle(DesignSystem.Colors.Status.info)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(DesignSystem.Colors.Text.primary)

                Text(description)
                    .font(.callout)
                    .dsSecondaryText(font: .callout)
            }

            Spacer(minLength: 0)
            Button {
                closeAction()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    .padding(6)
                    .background(DesignSystem.Colors.Component.controlFillSubtle, in: .circle)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .dsCard(
            background: DesignSystem.Colors.Background.elevated,
            cornerRadius: DesignSystem.Metrics.cornerRadiusM,
            borderColor: DesignSystem.Colors.Component.border.opacity(0.4)
        )
    }
}

public struct FloatingAccentActionButton: View {
    let systemImage: String
    let iconSize: CGFloat
    let action: () -> Void

    public init(
        systemImage: String = "plus",
        iconSize: CGFloat = 24,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.iconSize = iconSize
        self.action = action
    }

    public var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.primary)
                    .frame(width: 56, height: 56)
                    .shadow(color: DesignSystem.Colors.primary.opacity(0.4), radius: 10, x: 0, y: 5)

                Image(systemName: systemImage)
                    .font(.system(size: iconSize, weight: .bold))
                    .foregroundStyle(DesignSystem.Colors.Text.onAccent)
            }
        }
        .dsLinkButton()
    }
}

public struct ProviderResourceHealthSummaryCardView: View {
    let data: ProviderResourceHealthSummaryData
    let onTapOrphanedSkills: () -> Void

    public init(
        data: ProviderResourceHealthSummaryData,
        onTapOrphanedSkills: @escaping () -> Void
    ) {
        self.data = data
        self.onTapOrphanedSkills = onTapOrphanedSkills
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(DesignSystem.Colors.Status.warning)
                Text(data.warningTitle)
                    .font(.callout.weight(.semibold))
            }

            HStack(spacing: 12) {
                if let orphanedText = data.orphanedSkillsText {
                    Button {
                        onTapOrphanedSkills()
                    } label: {
                        Text(orphanedText)
                            .font(.caption)
                            .dsBadge(
                                foreground: DesignSystem.Colors.Status.warning,
                                background: DesignSystem.Colors.Status.warning.opacity(0.14)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(data.orphanedSkillsHelp ?? "")
                }

                if let brokenText = data.brokenSkillsText {
                    Text(brokenText)
                        .font(.caption)
                        .dsBadge(
                            foreground: DesignSystem.Colors.Status.error,
                            background: DesignSystem.Colors.Status.error.opacity(0.14)
                        )
                }

                if let unknownText = data.unknownWorkflowsText {
                    Text(unknownText)
                        .font(.caption)
                        .dsBadge(
                            foreground: DesignSystem.Colors.Text.secondary,
                            background: DesignSystem.Colors.Component.controlFillSubtle
                        )
                }

                if let mcpUpdateText = data.mcpUpdateText {
                    Text(mcpUpdateText)
                        .font(.caption)
                        .dsBadge(
                            foreground: DesignSystem.Colors.secondary,
                            background: DesignSystem.Colors.secondary.opacity(0.14)
                        )
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .dsCard(
            background: DesignSystem.Colors.Status.warning.opacity(0.08),
            cornerRadius: DesignSystem.Metrics.cornerRadiusM,
            borderColor: DesignSystem.Colors.Status.warning.opacity(0.25),
            borderWidth: 1
        )
    }
}

public struct ProviderCodexLinkedHintCardView: View {
    let data: ProviderCodexLinkedHintData
    let onAction: () -> Void

    public init(
        data: ProviderCodexLinkedHintData,
        onAction: @escaping () -> Void
    ) {
        self.data = data
        self.onAction = onAction
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(data.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.Text.primary)

                Text(data.pathText)
                    .font(.caption.monospaced())
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
            }

            Spacer(minLength: 0)
            Button(data.actionTitle) {
                onAction()
            }
            .dsPrimaryButton()
        }
        .padding(12)
        .dsCard(
            background: DesignSystem.Colors.Background.elevated,
            cornerRadius: DesignSystem.Metrics.cornerRadiusM,
            borderColor: DesignSystem.Colors.Component.border.opacity(0.35)
        )
    }
}

public struct ProviderCodexTopHintsView: View {
    let noticeData: ProviderCodexXcodeNoticeData?
    let linkedHintData: ProviderCodexLinkedHintData?
    let onDismissNotice: (() -> Void)?
    let onTapLinkedHint: (() -> Void)?

    public init(
        noticeData: ProviderCodexXcodeNoticeData?,
        linkedHintData: ProviderCodexLinkedHintData?,
        onDismissNotice: (() -> Void)? = nil,
        onTapLinkedHint: (() -> Void)? = nil
    ) {
        self.noticeData = noticeData
        self.linkedHintData = linkedHintData
        self.onDismissNotice = onDismissNotice
        self.onTapLinkedHint = onTapLinkedHint
    }

    public var body: some View {
        if let noticeData, let onDismissNotice {
            ProviderCodexXcodeNoticeCardView(
                title: noticeData.title,
                description: noticeData.description,
                closeAction: onDismissNotice
            )
        }

        if let linkedHintData, let onTapLinkedHint {
            ProviderCodexLinkedHintCardView(
                data: linkedHintData,
                onAction: onTapLinkedHint
            )
        }
    }
}

public struct ProviderTabSectionView<Content: View>: View {
    let warningMessage: String?
    let content: () -> Content

    public init(
        warningMessage: String?,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.warningMessage = warningMessage
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let warningMessage, !warningMessage.isEmpty {
                ProviderWarningCardView(message: warningMessage)
            }
            content()
        }
    }
}
