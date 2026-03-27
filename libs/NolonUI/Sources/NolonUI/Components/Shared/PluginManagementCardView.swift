import SwiftUI
import NolonUIFoundation

public struct PluginManagementCardView: View {
    let data: PluginManagementCardData
    let onRuntimeAction: () -> Void
    let onLogs: () -> Void
    let onUpgrade: () -> Void
    let onOpenRelease: () -> Void
    let onUninstall: () -> Void

    public init(
        data: PluginManagementCardData,
        onRuntimeAction: @escaping () -> Void,
        onLogs: @escaping () -> Void,
        onUpgrade: @escaping () -> Void,
        onOpenRelease: @escaping () -> Void,
        onUninstall: @escaping () -> Void
    ) {
        self.data = data
        self.onRuntimeAction = onRuntimeAction
        self.onLogs = onLogs
        self.onUpgrade = onUpgrade
        self.onOpenRelease = onOpenRelease
        self.onUninstall = onUninstall
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(data.name, systemImage: "puzzlepiece.extension")
                    .font(.headline)
                Spacer(minLength: 0)
                Button(data.runtimeActionTitle, action: onRuntimeAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!data.runtimeActionEnabled)

                Button(data.logsTitle, action: onLogs)
                    .buttonStyle(.bordered)

                if data.showsUpgradeButton {
                    Button(data.upgradeActionTitle, action: onUpgrade)
                        .dsPrimaryButton()
                        .disabled(!data.upgradeActionEnabled)
                } else {
                    Button(data.openReleaseTitle, action: onOpenRelease)
                        .dsLinkButton()
                }

                if data.showsUninstallButton {
                    Button(data.uninstallActionTitle, action: onUninstall)
                        .buttonStyle(.bordered)
                        .disabled(!data.uninstallActionEnabled)
                }
            }

            HStack(spacing: 14) {
                Text(data.statusText)
                    .font(.caption)
                    .dsSecondaryText(font: .caption)
                Text(data.installedText)
                    .font(.caption)
                    .dsSecondaryText(font: .caption)
                Text(data.latestText)
                    .font(.caption)
                    .dsSecondaryText(font: .caption)
            }

            Text(data.runtimeStatusText)
                .font(.caption)
                .dsSecondaryText(font: .caption)
                .textSelection(.enabled)
        }
        .padding(12)
        .dsCard(
            background: DesignSystem.Colors.Background.elevated,
            cornerRadius: DesignSystem.Metrics.cornerRadiusM,
            borderColor: DesignSystem.Colors.Component.border.opacity(0.4)
        )
    }
}
