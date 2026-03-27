import SwiftUI

public struct SheetPaddedList<Data: RandomAccessCollection, RowContent: View>: View where Data.Element: Identifiable {
    let data: Data
    let rowContent: (Data.Element) -> RowContent

    public init(
        _ data: Data,
        @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent
    ) {
        self.data = data
        self.rowContent = rowContent
    }

    public var body: some View {
        List(data) { item in
            rowContent(item)
        }
        .sheetScrollContentPadding()
    }
}
