import NolonUI

import SwiftUI

struct HighlightedText: View {
    let text: String
    let query: String
    var highlightColor: Color = DesignSystem.Colors.primary

    var body: some View {
        NolonUI.HighlightedText(
            text: text,
            query: query,
            highlightColor: highlightColor
        )
    }
}
