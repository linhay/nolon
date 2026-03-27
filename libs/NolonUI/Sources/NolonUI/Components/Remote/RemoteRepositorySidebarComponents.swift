import SwiftUI
import NolonUIFoundation

public enum SyncHUDTone {
    case info
    case success
    case failure
}

public struct RepositoryFloatingAddButton: View {
    let title: String
    let action: () -> Void

    public init(
        title: String,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.Text.onAccent)
                .frame(width: 34, height: 34)
                .background(DesignSystem.Colors.primary, in: Circle())
                .shadow(color: DesignSystem.Colors.primary.opacity(0.35), radius: 6, x: 0, y: 3)
        }
        .dsLinkButton()
        .help(title)
        .accessibilityLabel(title)
    }
}

public struct SyncHUDCardView<Icon: View>: View {
    let title: String
    let subtitle: String?
    let tone: SyncHUDTone
    let icon: () -> Icon

    public init(
        title: String,
        subtitle: String?,
        tone: SyncHUDTone,
        @ViewBuilder icon: @escaping () -> Icon
    ) {
        self.title = title
        self.subtitle = subtitle
        self.tone = tone
        self.icon = icon
    }

    public var body: some View {
        HStack(spacing: 12) {
            icon()
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.Text.primary)
                    .lineLimit(2)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .dsSecondaryText(font: .system(size: 11))
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .dsCard(
            background: DesignSystem.Colors.Background.elevated.opacity(0.94),
            cornerRadius: DesignSystem.Metrics.cornerRadiusM,
            borderColor: DesignSystem.Colors.Component.border.opacity(tone == .failure ? 0.6 : 0.35),
            shadow: DesignSystem.CardShadow(
                color: DesignSystem.Colors.Text.primary.opacity(0.14),
                radius: 12,
                x: 0,
                y: 8
            )
        )
    }
}

public struct RepositorySyncHUDOverlay: View {
    let isSyncing: Bool
    let syncingRepositoryName: String?
    let completionMessage: String?
    let completionRepositoryName: String?
    let completionTone: SyncHUDTone

    public init(
        isSyncing: Bool,
        syncingRepositoryName: String?,
        completionMessage: String?,
        completionRepositoryName: String?,
        completionTone: SyncHUDTone
    ) {
        self.isSyncing = isSyncing
        self.syncingRepositoryName = syncingRepositoryName
        self.completionMessage = completionMessage
        self.completionRepositoryName = completionRepositoryName
        self.completionTone = completionTone
    }

    public var body: some View {
        if isSyncing || completionMessage != nil {
            ZStack {
                if isSyncing {
                    SyncHUDCardView(
                        title: NSLocalizedString("Syncing repository...", comment: "Sync in progress"),
                        subtitle: syncingRepositoryName,
                        tone: .info
                    ) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(DesignSystem.Colors.Status.info)
                    }
                } else if let completionMessage {
                    SyncHUDCardView(
                        title: completionMessage,
                        subtitle: completionRepositoryName,
                        tone: completionTone
                    ) {
                        Image(systemName: completionTone == .success ? "checkmark.circle.fill" : "xmark.octagon.fill")
                            .foregroundStyle(
                                completionTone == .success
                                ? DesignSystem.Colors.Status.success
                                : DesignSystem.Colors.Status.error
                            )
                    }
                }
            }
            .padding(.top, 12)
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
            .allowsHitTesting(false)
        }
    }
}

public struct RepositorySidebarSectionToggleRow: View {
    let title: String
    let isCollapsed: Bool
    let onToggle: () -> Void

    public init(
        title: String,
        isCollapsed: Bool,
        onToggle: @escaping () -> Void
    ) {
        self.title = title
        self.isCollapsed = isCollapsed
        self.onToggle = onToggle
    }

    public var body: some View {
        Button {
            onToggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.caption)
                    .dsSecondaryText(font: .caption)

                Text(title)
                    .font(.caption)
                    .dsSecondaryText(font: .caption)

                Spacer(minLength: 0)
            }
            .textCase(nil)
            .padding(.top, 6)
            .padding(.bottom, 2)
            .contentShape(Rectangle())
        }
        .dsLinkButton()
        .listRowSeparator(.hidden)
        .selectionDisabled(true)
    }
}

public struct RepositoryGitSyncStatusRow: View {
    let isSyncing: Bool
    let lastSyncDate: Date?
    let notSyncedText: String

    public init(
        isSyncing: Bool,
        lastSyncDate: Date?,
        notSyncedText: String
    ) {
        self.isSyncing = isSyncing
        self.lastSyncDate = lastSyncDate
        self.notSyncedText = notSyncedText
    }

    public var body: some View {
        Group {
            if isSyncing {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.Status.info)
            } else if let syncDate = lastSyncDate {
                Text(syncDate, style: .time)
                    .font(.caption2)
                    .dsSecondaryText(font: .caption2)
            } else {
                Text(notSyncedText)
                    .font(.caption2)
                    .foregroundStyle(DesignSystem.Colors.Status.warning)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

public struct RepositorySidebarRowView: View {
    let data: RepositorySidebarRowData

    public init(data: RepositorySidebarRowData) {
        self.data = data
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                if let logoName = data.logoName {
                    ProviderLogoView(name: data.title, logoName: logoName, iconSize: 16)
                } else {
                    Image(systemName: data.fallbackSystemIconName)
                        .dsSecondaryText(font: .caption)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(data.title)
                        .font(.body)
                        .foregroundStyle(DesignSystem.Colors.Text.primary)
                        .lineLimit(1)

                    if let secondaryText = data.secondaryText {
                        Text(secondaryText)
                            .font(.caption)
                            .dsSecondaryText(font: .caption)
                            .lineLimit(1)
                    }

                    if data.showGitStatus, let syncStatus = data.syncStatus {
                        gitStatusView(syncStatus)
                    }
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                if data.isBuiltIn {
                    Text(data.builtInText)
                        .dsBadge(
                            foreground: DesignSystem.Colors.Text.secondary,
                            background: DesignSystem.Colors.Component.controlFillSubtle,
                            horizontalPadding: 6,
                            verticalPadding: 2
                        )
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }

    @ViewBuilder
    private func gitStatusView(_ status: RepositorySyncStatusData) -> some View {
        switch status {
        case .syncing:
            RepositoryGitSyncStatusRow(
                isSyncing: true,
                lastSyncDate: nil,
                notSyncedText: ""
            )
        case .lastSynced(let date):
            RepositoryGitSyncStatusRow(
                isSyncing: false,
                lastSyncDate: date,
                notSyncedText: ""
            )
        case .notSynced(let text):
            RepositoryGitSyncStatusRow(
                isSyncing: false,
                lastSyncDate: nil,
                notSyncedText: text
            )
        }
    }
}
