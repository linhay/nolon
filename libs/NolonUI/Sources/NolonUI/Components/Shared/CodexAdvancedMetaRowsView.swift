import SwiftUI
import NolonUIFoundation

public struct CodexAdvancedMetaRowsView: View {
    let rows: [CodexAdvancedMetaRowData]

    public init(rows: [CodexAdvancedMetaRowData]) {
        self.rows = rows
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(rows) { row in
                Text(row.text)
                    .font(row.isMonospaced ? .caption.monospaced() : .caption)
                    .dsSecondaryText(font: .caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }
}
