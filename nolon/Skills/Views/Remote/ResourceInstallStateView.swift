import SwiftUI

struct ResourceInstallStateView: View {
    let isInstalled: Bool
    let isInstalling: Bool
    let errorMessage: String?
    let onInstall: () -> Void
    let onRetry: () -> Void

    var body: some View {
        if isInstalled {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                Text(NSLocalizedString("remote.status.installed", value: "Installed", comment: "Remote installed status"))
            }
            .fontWeight(.medium)
            .dsBadge(
                foreground: DesignSystem.Colors.Status.success,
                background: DesignSystem.Colors.Status.success.opacity(0.10)
            )
        } else if isInstalling {
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.small)
                Text(NSLocalizedString("remote.status.installing", value: "Installing", comment: "Remote installing status"))
            }
            .fontWeight(.medium)
            .dsBadge(
                foreground: DesignSystem.Colors.secondary,
                background: DesignSystem.Colors.secondary.opacity(0.10)
            )
        } else if let errorMessage, !errorMessage.isEmpty {
            Button {
                onRetry()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise.circle")
                    Text(NSLocalizedString("remote.retry", value: "Retry", comment: "Retry"))
                }
                .fontWeight(.semibold)
                .dsBadge(
                    foreground: DesignSystem.Colors.Status.error,
                    background: DesignSystem.Colors.Status.error.opacity(0.10),
                    horizontalPadding: 10,
                    verticalPadding: 6
                )
            }
            .dsLinkButton()
            .help(errorMessage)
        } else {
            Button {
                onInstall()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle")
                    Text(NSLocalizedString("action.install", value: "Install", comment: "Install action"))
                }
                .fontWeight(.semibold)
                .dsBadge(
                    foreground: DesignSystem.Colors.primary,
                    background: DesignSystem.Colors.primary.opacity(0.10),
                    horizontalPadding: 10,
                    verticalPadding: 6
                )
            }
            .dsLinkButton()
        }
    }
}
