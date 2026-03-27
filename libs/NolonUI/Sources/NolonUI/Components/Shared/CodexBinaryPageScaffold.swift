import SwiftUI

public struct CodexBinaryPageScaffold<Content: View>: View {
    let isSupported: Bool
    let isLoading: Bool
    let unsupportedTitle: String
    let unsupportedSystemImage: String
    let unsupportedDescription: String
    let checkingUpdatesText: String?
    let content: () -> Content

    public init(
        isSupported: Bool,
        isLoading: Bool,
        unsupportedTitle: String,
        unsupportedSystemImage: String,
        unsupportedDescription: String,
        checkingUpdatesText: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isSupported = isSupported
        self.isLoading = isLoading
        self.unsupportedTitle = unsupportedTitle
        self.unsupportedSystemImage = unsupportedSystemImage
        self.unsupportedDescription = unsupportedDescription
        self.checkingUpdatesText = checkingUpdatesText
        self.content = content
    }

    public var body: some View {
        Group {
            if !isSupported {
                EmptyStateScaffold(
                    isEmpty: true,
                    emptyTitle: unsupportedTitle,
                    emptySystemImage: unsupportedSystemImage,
                    emptyDescription: unsupportedDescription
                ) {
                    EmptyView()
                }
            } else if isLoading {
                CenteredLoadingIndicatorView()
            } else {
                content()
            }
        }
        .overlay(alignment: .top) {
            if let checkingUpdatesText, !checkingUpdatesText.isEmpty {
                TopLoadingStatusBannerView(text: checkingUpdatesText)
                    .padding(.top, 12)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
    }
}

