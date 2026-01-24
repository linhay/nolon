import SwiftUI

/// A view that displays text with highlights for matches of a search query.
struct HighlightedText: View {
    let text: String
    let query: String
    var highlightColor: Color = .blue
    
    var body: some View {
        if query.isEmpty {
            Text(text)
        } else {
            let attributedString = computeAttributedString()
            Text(attributedString)
        }
    }
    
    private func computeAttributedString() -> AttributedString {
        var str = AttributedString(text)
        
        guard !query.isEmpty else { return str }
        
        let lowerText = text.lowercased()
        let lowerQuery = query.lowercased()
        
        var currentIndex = lowerText.startIndex
        
        for char in lowerQuery {
            // Find next occurrence of char in lowerText
            if let range = lowerText.range(of: String(char), options: .caseInsensitive, range: currentIndex..<lowerText.endIndex) {
                // Convert String.Index to AttributedString.Index
                if let attrStart = AttributedString.Index(range.lowerBound, within: str),
                   let attrEnd = AttributedString.Index(range.upperBound, within: str) {
                    let attrRange = attrStart..<attrEnd
                    str[attrRange].foregroundColor = highlightColor
                    str[attrRange].inlinePresentationIntent = .stronglyEmphasized
                }
                currentIndex = range.upperBound
            } else {
                // Not a strict fuzzy match (subsequence)
                // We'll just stop highlighting if the subsequence breaks
                break
            }
        }
        
        return str
    }
}

// MARK: - Fuzzy Logic (Future Enhancement)
/*
func fuzzyMatch(text: String, query: String) -> [Range<String.Index>] {
    // VSCode style fuzzy matching implementation
    return []
}
*/
