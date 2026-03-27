import SwiftUI
import NolonUIFoundation

public struct CodexAdvancedRuntimeOverviewView: View {
    let stats: [CodexAdvancedStatTileData]
    let metaRows: [CodexAdvancedMetaRowData]

    public init(
        stats: [CodexAdvancedStatTileData],
        metaRows: [CodexAdvancedMetaRowData]
    ) {
        self.stats = stats
        self.metaRows = metaRows
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AdaptiveCardGrid(
                columns: [
                    GridItem(.flexible(minimum: 160), spacing: 10),
                    GridItem(.flexible(minimum: 160), spacing: 10)
                ],
                alignment: .leading,
                spacing: 10
            ) {
                ForEach(Array(stats.enumerated()), id: \.offset) { _, stat in
                    CodexAdvancedStatTileView(data: stat)
                }
            }

            if !metaRows.isEmpty {
                CodexAdvancedMetaRowsView(rows: metaRows)
            }
        }
    }
}
