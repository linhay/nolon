import SwiftUI

public struct EmptyStateScaffold<Content: View>: View {
    let isEmpty: Bool
    let emptyTitle: String
    let emptySystemImage: String
    let emptyDescription: String
    let content: () -> Content

    public init(
        isEmpty: Bool,
        emptyTitle: String,
        emptySystemImage: String,
        emptyDescription: String,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isEmpty = isEmpty
        self.emptyTitle = emptyTitle
        self.emptySystemImage = emptySystemImage
        self.emptyDescription = emptyDescription
        self.content = content
    }

    public var body: some View {
        if isEmpty {
            UnavailableStateView(
                title: emptyTitle,
                systemImage: emptySystemImage,
                description: emptyDescription
            )
        } else {
            content()
        }
    }
}
