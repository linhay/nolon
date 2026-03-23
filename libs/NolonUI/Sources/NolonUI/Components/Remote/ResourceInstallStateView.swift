import SwiftUI

enum ResourceInstallState: Equatable {
    case installed
    case installing
    case failed(message: String)
    case installable

    static func resolve(isInstalled: Bool, isInstalling: Bool, errorMessage: String?) -> ResourceInstallState {
        if isInstalled {
            return .installed
        }

        if isInstalling {
            return .installing
        }

        if let errorMessage, !errorMessage.isEmpty {
            return .failed(message: errorMessage)
        }

        return .installable
    }
}

public struct ResourceInstallStateView: View {
    private let state: ResourceInstallState
    private let onInstall: () -> Void
    private let onRetry: () -> Void

    public init(
        isInstalled: Bool,
        isInstalling: Bool,
        errorMessage: String?,
        onInstall: @escaping () -> Void,
        onRetry: @escaping () -> Void
    ) {
        self.state = ResourceInstallState.resolve(
            isInstalled: isInstalled,
            isInstalling: isInstalling,
            errorMessage: errorMessage
        )
        self.onInstall = onInstall
        self.onRetry = onRetry
    }

    public var body: some View {
        switch state {
        case .installed:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                Text(NSLocalizedString("remote.status.installed", value: "Installed", comment: "Remote installed status"))
            }
            .fontWeight(.medium)
            .dsBadge(
                foreground: DesignSystem.Colors.Status.success,
                background: DesignSystem.Colors.Status.success.opacity(0.10)
            )

        case .installing:
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

        case let .failed(message):
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
            .help(message)

        case .installable:
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

private struct ResourceInstallStateViewPreviewContainer: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ResourceInstallStateView(isInstalled: true, isInstalling: false, errorMessage: nil, onInstall: {}, onRetry: {})
            ResourceInstallStateView(isInstalled: false, isInstalling: true, errorMessage: nil, onInstall: {}, onRetry: {})
            ResourceInstallStateView(isInstalled: false, isInstalling: false, errorMessage: "Network unavailable", onInstall: {}, onRetry: {})
            ResourceInstallStateView(isInstalled: false, isInstalling: false, errorMessage: nil, onInstall: {}, onRetry: {})
        }
        .padding(16)
        .frame(width: 320)
    }
}

#Preview("Resource Install State") {
    ResourceInstallStateViewPreviewContainer()
}
