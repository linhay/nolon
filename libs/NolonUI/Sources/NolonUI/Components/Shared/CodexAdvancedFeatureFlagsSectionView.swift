import SwiftUI
import NolonUIFoundation

public struct CodexAdvancedFeatureFlagsSectionView: View {
    let searchPlaceholder: String
    @Binding var searchText: String
    let rows: [CodexAdvancedFeatureRowData]
    let onToggle: (String, Bool) -> Void

    public init(
        searchPlaceholder: String = NSLocalizedString(
            "codex.features.search.placeholder",
            value: "Search features...",
            comment: "Feature search placeholder"
        ),
        searchText: Binding<String>,
        rows: [CodexAdvancedFeatureRowData],
        onToggle: @escaping (String, Bool) -> Void
    ) {
        self.searchPlaceholder = searchPlaceholder
        self._searchText = searchText
        self.rows = rows
        self.onToggle = onToggle
    }

    public var body: some View {
        CodexAdvancedSectionCardView {
            TextField(searchPlaceholder, text: $searchText)
                .textFieldStyle(.roundedBorder)

            ForEach(rows) { row in
                CodexAdvancedFeatureRowView(
                    data: row,
                    onToggle: { newValue in
                        onToggle(row.id, newValue)
                    }
                )
            }
        }
    }
}
