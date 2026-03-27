import SwiftUI

public struct ResourceCatalogPlaceholderView: View {
    let title: String
    let systemImage: String

    public init(title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
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

public struct CenteredLoadingIndicatorView: View {
    public init() {}

    public var body: some View {
        Image(systemName: "arrow.triangle.2.circlepath")
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(DesignSystem.Colors.Status.info)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

public struct ResourceCatalogErrorStateView: View {
    let title: String
    let message: String
    let retryTitle: String
    let onCopyMessage: () -> Void
    let onRetry: () -> Void

    public init(
        title: String,
        message: String,
        retryTitle: String,
        onCopyMessage: @escaping () -> Void,
        onRetry: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.retryTitle = retryTitle
        self.onCopyMessage = onCopyMessage
        self.onRetry = onRetry
    }

    public var body: some View {
        ContentUnavailableView {
            Label {
                Text(title)
                    .dsEmptyStateErrorTitle()
            } icon: {
                Image(systemName: "exclamationmark.triangle")
                    .dsEmptyStateIcon(color: DesignSystem.Colors.Status.error)
            }
        } description: {
            Button {
                onCopyMessage()
            } label: {
                Text(message)
                    .dsSecondaryText(font: .body)
            }
            .buttonStyle(.plain)
        } actions: {
            Button {
                onRetry()
            } label: {
                Text(retryTitle)
            }
            .buttonStyle(.bordered)
        }
    }
}
