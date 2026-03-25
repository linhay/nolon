import SwiftUI

public enum HighlightedTextMatcher {
    public static func matchRanges(text: String, query: String) -> [Range<String.Index>] {
        guard !query.isEmpty else { return [] }

        let lowerText = text.lowercased()
        let lowerQuery = query.lowercased()
        var currentIndex = lowerText.startIndex
        var ranges: [Range<String.Index>] = []

        for char in lowerQuery {
            guard let range = lowerText.range(
                of: String(char),
                options: .caseInsensitive,
                range: currentIndex..<lowerText.endIndex
            ) else {
                break
            }

            ranges.append(range)
            currentIndex = range.upperBound
        }

        return ranges
    }
}

public struct HighlightedText: View {
    @State private var viewModel = HighlightedTextViewModel()
    private let text: String
    private let query: String
    private let highlightColor: Color

    public init(text: String, query: String, highlightColor: Color = DesignSystem.Colors.primary) {
        self.text = text
        self.query = query
        self.highlightColor = highlightColor
    }

    public var body: some View {
        if query.isEmpty {
            Text(text)
        } else {
            Text(computeAttributedString())
        }
    }

    private func computeAttributedString() -> AttributedString {
        var attributed = AttributedString(text)

        for range in HighlightedTextMatcher.matchRanges(text: text, query: query) {
            guard
                let start = AttributedString.Index(range.lowerBound, within: attributed),
                let end = AttributedString.Index(range.upperBound, within: attributed)
            else {
                continue
            }

            let attributedRange = start..<end
            attributed[attributedRange].foregroundColor = highlightColor
            attributed[attributedRange].inlinePresentationIntent = .stronglyEmphasized
        }

        return attributed
    }
}

#Preview("Highlighted Text") {
    VStack(alignment: .leading, spacing: 8) {
        HighlightedText(text: "Provider Sidebar", query: "ps")
        HighlightedText(text: "Workflow Automation", query: "wa")
        HighlightedText(text: "No Query", query: "")
    }
    .padding(16)
    .frame(width: 320)
}
