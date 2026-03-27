import SwiftUI

public struct ProviderGroupedPathHeaderView: View {
    let title: String
    let columnCount: Int

    public init(title: String, columnCount: Int) {
        self.title = title
        self.columnCount = columnCount
    }

    public var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .dsSecondaryText(font: .headline)
            Spacer()
        }
        .padding(.top, 8)
        .gridCellColumns(columnCount)
    }
}
