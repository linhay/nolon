import SwiftUI
import NolonUIFoundation

public struct CodexXcodeFolderLinksSectionView: View {
    let descriptionText: String
    let cards: [CodexXcodeFolderLinkCardData]
    let onToggleLink: (String, Bool) -> Void
    let onShowInFinder: (String) -> Void

    public init(
        descriptionText: String,
        cards: [CodexXcodeFolderLinkCardData],
        onToggleLink: @escaping (String, Bool) -> Void,
        onShowInFinder: @escaping (String) -> Void
    ) {
        self.descriptionText = descriptionText
        self.cards = cards
        self.onToggleLink = onToggleLink
        self.onShowInFinder = onShowInFinder
    }

    public var body: some View {
        CodexAdvancedSectionCardView {
            Text(descriptionText)
                .font(.callout)
                .dsSecondaryText(font: .callout)
                .padding(.horizontal, 2)

            ForEach(cards) { card in
                CodexXcodeFolderLinkCardView(
                    data: card,
                    onToggleLink: { enabled in
                        onToggleLink(card.id, enabled)
                    },
                    onShowInFinder: {
                        onShowInFinder(card.id)
                    }
                )
            }
        }
    }
}
