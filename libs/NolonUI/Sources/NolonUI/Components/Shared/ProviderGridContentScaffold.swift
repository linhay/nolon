import SwiftUI

public struct ProviderGridContentScaffold<Content: View>: View {
    let isEmpty: Bool
    let emptyTitle: String
    let emptySystemImage: String
    let emptyDescription: String
    let columns: [GridItem]
    let spacing: CGFloat
    let content: () -> Content

    public init(
        isEmpty: Bool,
        emptyTitle: String = NSLocalizedString("provider.empty", value: "No Skills", comment: "No skills"),
        emptySystemImage: String = "folder.badge.questionmark",
        emptyDescription: String = NSLocalizedString("provider.empty_desc", value: "No skills found in this provider", comment: "No skills in provider"),
        columns: [GridItem],
        spacing: CGFloat = 16,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isEmpty = isEmpty
        self.emptyTitle = emptyTitle
        self.emptySystemImage = emptySystemImage
        self.emptyDescription = emptyDescription
        self.columns = columns
        self.spacing = spacing
        self.content = content
    }

    public var body: some View {
        if isEmpty {
            ProviderGridEmptyStateView(
                title: emptyTitle,
                systemImage: emptySystemImage,
                description: emptyDescription
            )
        } else {
            LazyVGrid(columns: columns, spacing: spacing) {
                content()
            }
        }
    }
}
