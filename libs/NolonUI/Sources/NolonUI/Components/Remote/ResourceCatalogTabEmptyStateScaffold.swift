import SwiftUI

public struct ResourceCatalogTabEmptyStateScaffold<Content: View>: View {
    let isEmpty: Bool
    let searchText: String
    let emptyTitle: String
    let emptySystemImage: String
    let emptyDescription: String
    let noResultsTitle: String
    let noResultsSystemImage: String
    let noResultsDescription: String
    let content: () -> Content

    public init(
        isEmpty: Bool,
        searchText: String,
        emptyTitle: String,
        emptySystemImage: String,
        emptyDescription: String,
        noResultsTitle: String,
        noResultsSystemImage: String = "magnifyingglass",
        noResultsDescription: String,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isEmpty = isEmpty
        self.searchText = searchText
        self.emptyTitle = emptyTitle
        self.emptySystemImage = emptySystemImage
        self.emptyDescription = emptyDescription
        self.noResultsTitle = noResultsTitle
        self.noResultsSystemImage = noResultsSystemImage
        self.noResultsDescription = noResultsDescription
        self.content = content
    }

    public var body: some View {
        ProviderEmptyStateScaffold(
            isEmpty: isEmpty,
            emptyTitle: searchText.isEmpty ? emptyTitle : noResultsTitle,
            emptySystemImage: searchText.isEmpty ? emptySystemImage : noResultsSystemImage,
            emptyDescription: searchText.isEmpty ? emptyDescription : noResultsDescription
        ) {
            content()
        }
    }
}
