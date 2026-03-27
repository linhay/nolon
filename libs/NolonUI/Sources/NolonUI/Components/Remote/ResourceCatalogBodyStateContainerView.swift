import SwiftUI

public struct ResourceCatalogBodyStateContainerView<Content: View>: View {
    let isLoading: Bool
    let hasAnyContent: Bool
    let errorMessage: String?
    let loadErrorTitle: String
    let retryTitle: String
    let onCopyError: (String) -> Void
    let onRetry: () -> Void
    let content: () -> Content

    public init(
        isLoading: Bool,
        hasAnyContent: Bool,
        errorMessage: String?,
        loadErrorTitle: String = NSLocalizedString(
            "remote.error.title",
            value: "Error Loading Data",
            comment: "Remote load error title"
        ),
        retryTitle: String = NSLocalizedString(
            "remote.retry",
            value: "Retry",
            comment: "Retry"
        ),
        onCopyError: @escaping (String) -> Void,
        onRetry: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isLoading = isLoading
        self.hasAnyContent = hasAnyContent
        self.errorMessage = errorMessage
        self.loadErrorTitle = loadErrorTitle
        self.retryTitle = retryTitle
        self.onCopyError = onCopyError
        self.onRetry = onRetry
        self.content = content
    }

    public var body: some View {
        if isLoading && !hasAnyContent {
            CenteredLoadingIndicatorView()
        } else if let error = errorMessage, !hasAnyContent {
            ResourceCatalogErrorStateView(
                title: loadErrorTitle,
                message: error,
                retryTitle: retryTitle,
                onCopyMessage: {
                    onCopyError(error)
                },
                onRetry: onRetry
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 10) {
                if let error = errorMessage, !error.isEmpty {
                    InlineWarningBannerView(
                        message: error,
                        retryTitle: retryTitle,
                        onRetry: onRetry
                    )
                }
                content()
            }
        }
    }
}
