import SwiftUI

public struct ResourceCatalogLoadMoreStateView: View {
    let isEnabled: Bool
    let loadMoreErrorMessage: String?
    let canLoadMore: Bool
    let isLoadingMore: Bool
    let isLoading: Bool
    let hasAnyContent: Bool
    let retryTitle: String
    let loadMoreTitle: String
    let loadingTitle: String
    let endTitle: String
    let onLoadMore: () -> Void

    public init(
        isEnabled: Bool,
        loadMoreErrorMessage: String?,
        canLoadMore: Bool,
        isLoadingMore: Bool,
        isLoading: Bool,
        hasAnyContent: Bool,
        retryTitle: String = NSLocalizedString("remote.retry", value: "Retry", comment: "Retry"),
        loadMoreTitle: String = NSLocalizedString("remote.load_more", value: "Load More", comment: "Load more"),
        loadingTitle: String = NSLocalizedString("remote.load_more.loading", value: "Loading...", comment: "Loading more indicator"),
        endTitle: String = NSLocalizedString("remote.load_more.end", value: "You have reached the end.", comment: "End of list"),
        onLoadMore: @escaping () -> Void
    ) {
        self.isEnabled = isEnabled
        self.loadMoreErrorMessage = loadMoreErrorMessage
        self.canLoadMore = canLoadMore
        self.isLoadingMore = isLoadingMore
        self.isLoading = isLoading
        self.hasAnyContent = hasAnyContent
        self.retryTitle = retryTitle
        self.loadMoreTitle = loadMoreTitle
        self.loadingTitle = loadingTitle
        self.endTitle = endTitle
        self.onLoadMore = onLoadMore
    }

    public var body: some View {
        if !isEnabled {
            EmptyView()
        } else if let message = loadMoreErrorMessage, !message.isEmpty {
            ResourceCatalogLoadMoreFooterView {
                VStack(spacing: 8) {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.Status.error)
                        .multilineTextAlignment(.center)
                    Button(action: onLoadMore) {
                        Text(retryTitle)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .frame(maxWidth: 220)
                }
            }
        } else if canLoadMore {
            ResourceCatalogLoadMoreFooterView {
                Button(action: onLoadMore) {
                    HStack(spacing: 8) {
                        if isLoadingMore {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(DesignSystem.Colors.Status.info)
                        }
                        Text(isLoadingMore ? loadingTitle : loadMoreTitle)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .disabled(isLoadingMore)
                .frame(maxWidth: 240)
                .onAppear {
                    guard !isLoadingMore else { return }
                    onLoadMore()
                }
            }
        } else if !isLoading && hasAnyContent {
            ResourceCatalogLoadMoreFooterView {
                Text(endTitle)
                    .dsSecondaryText(font: .callout)
            }
        }
    }
}
