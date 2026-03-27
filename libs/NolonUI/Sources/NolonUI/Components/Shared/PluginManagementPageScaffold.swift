import SwiftUI

public struct PluginManagementPageScaffold<Content: View>: View {
    let isChecking: Bool
    let hasPlugin: Bool
    let emptyTitle: String
    let emptySystemImage: String
    let emptyDescription: String
    let errorMessage: String?
    let content: () -> Content

    public init(
        isChecking: Bool,
        hasPlugin: Bool,
        emptyTitle: String = NSLocalizedString("plugin.empty.title", value: "No Plugin", comment: "No plugin title"),
        emptySystemImage: String = "puzzlepiece",
        emptyDescription: String = NSLocalizedString("plugin.empty.desc", value: "No available plugins.", comment: "No plugin description"),
        errorMessage: String?,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isChecking = isChecking
        self.hasPlugin = hasPlugin
        self.emptyTitle = emptyTitle
        self.emptySystemImage = emptySystemImage
        self.emptyDescription = emptyDescription
        self.errorMessage = errorMessage
        self.content = content
    }

    public var body: some View {
        PaddedScrollContainer {
            VStack(alignment: .leading, spacing: 12) {
                if isChecking {
                    CenteredLoadingIndicatorView()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                EmptyStateScaffold(
                    isEmpty: !hasPlugin && !isChecking,
                    emptyTitle: emptyTitle,
                    emptySystemImage: emptySystemImage,
                    emptyDescription: emptyDescription
                ) {
                    if hasPlugin {
                        content()
                    } else {
                        EmptyView()
                    }
                }

                if let errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.callout)
                        .dsSecondaryText(font: .callout)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}
