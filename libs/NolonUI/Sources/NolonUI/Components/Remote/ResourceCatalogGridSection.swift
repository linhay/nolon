import SwiftUI

public struct ResourceCatalogGridSection<Data: RandomAccessCollection, CardContent: View>: View where Data.Element: Identifiable {
    let title: String
    let items: Data
    let columns: [GridItem]
    let spacing: CGFloat
    let cardContent: (Data.Element) -> CardContent

    public init(
        title: String,
        items: Data,
        columns: [GridItem],
        spacing: CGFloat = 16,
        @ViewBuilder cardContent: @escaping (Data.Element) -> CardContent
    ) {
        self.title = title
        self.items = items
        self.columns = columns
        self.spacing = spacing
        self.cardContent = cardContent
    }

    public var body: some View {
        if !items.isEmpty {
            ResourceCatalogSectionBlock(title: title, count: items.count) {
                LazyVGrid(columns: columns, spacing: spacing) {
                    ForEach(items) { item in
                        cardContent(item)
                    }
                }
            }
        }
    }
}
