import SwiftUI

public struct ProviderDetailGridScaffoldView<Content: View, FloatingButton: View>: View {
    let showSearch: Bool
    let searchPlaceholder: String
    @Binding var searchText: String
    let showFloatingButton: Bool
    let content: (ScrollViewProxy) -> Content
    let floatingButton: () -> FloatingButton

    public init(
        showSearch: Bool,
        searchPlaceholder: String = NSLocalizedString("search.placeholder", value: "Search", comment: "Search placeholder"),
        searchText: Binding<String>,
        showFloatingButton: Bool,
        @ViewBuilder content: @escaping (ScrollViewProxy) -> Content,
        @ViewBuilder floatingButton: @escaping () -> FloatingButton
    ) {
        self.showSearch = showSearch
        self.searchPlaceholder = searchPlaceholder
        self._searchText = searchText
        self.showFloatingButton = showFloatingButton
        self.content = content
        self.floatingButton = floatingButton
    }

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if showSearch {
                                HStack {
                                    SearchField(
                                        placeholder: searchPlaceholder,
                                        text: $searchText
                                    )
                                    Spacer()
                                }
                            }
                            content(scrollProxy)
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .padding()
                }

                if showFloatingButton {
                    floatingButton()
                }
            }
        }
    }
}
