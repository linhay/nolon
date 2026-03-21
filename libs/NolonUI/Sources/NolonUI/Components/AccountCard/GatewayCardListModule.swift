import SwiftUI
import NolonUIFoundation

public struct GatewayCardListModule<Item: Identifiable, Content: View>: View {
    public enum LayoutMode: Sendable {
        case list
        case cards
    }

    public let items: [Item]
    public let layoutMode: LayoutMode
    public let columns: [GridItem]
    public let spacing: CGFloat
    @ViewBuilder public let content: (Item) -> Content

    public init(
        items: [Item],
        layoutMode: LayoutMode,
        columns: [GridItem] = [GridItem(.adaptive(minimum: 240, maximum: 340), spacing: 12, alignment: .topLeading)],
        spacing: CGFloat = 12,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.layoutMode = layoutMode
        self.columns = columns
        self.spacing = spacing
        self.content = content
    }

    public var body: some View {
        Group {
            switch layoutMode {
            case .list:
                LazyVStack(alignment: .leading, spacing: spacing) {
                    ForEach(items) { item in
                        content(item)
                    }
                }
            case .cards:
                LazyVGrid(columns: columns, alignment: .leading, spacing: spacing) {
                    ForEach(items) { item in
                        content(item)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@MainActor
private struct GatewayCardListModulePreviewContainer: View {
    private struct SampleCard: Identifiable {
        let id = UUID()
        let title: String
        let members: [GatewayCardMemberItem]
        let presentation: AccountCardPresentation
    }

    private let cards: [SampleCard] = [
        .init(
            title: "Prod Gateway",
            members: [
                .init(id: UUID(), title: "codex-alpha", plan: "Pro"),
                .init(id: UUID(), title: "relay-us"),
                .init(id: UUID(), title: "relay-eu", plan: "Relay"),
            ],
            presentation: .selected
        ),
        .init(
            title: "Staging Gateway",
            members: [
                .init(id: UUID(), title: "codex-beta"),
                .init(id: UUID(), title: "backup-1"),
            ],
            presentation: .neutral
        ),
        .init(
            title: "Gateway with Very Long Name for Cards/List Preview",
            members: [
                .init(id: UUID(), title: "node-a", plan: "Team"),
                .init(id: UUID(), title: "node-b"),
                .init(id: UUID(), title: "node-c", plan: "Relay"),
                .init(id: UUID(), title: "node-d"),
                .init(id: UUID(), title: "node-e", plan: "Pro"),
            ],
            presentation: .pending
        ),
        .init(
            title: "Empty Gateway",
            members: [],
            presentation: .neutral
        ),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PreviewLayoutTokens.Spacing.section) {
                Text("List Mode")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)

                GatewayCardListModule(items: cards, layoutMode: .list) { card in
                    GatewayCardModule(
                        presentation: card.presentation,
                        title: card.title,
                        memberCountText: "\(card.members.count) 个成员",
                        members: card.members,
                        isCompact: true,
                        memberDisplayLimit: 8,
                        memberRowMaxHeight: 48
                    )
                }

                Text("Cards Mode")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)

                GatewayCardListModule(items: cards, layoutMode: .cards) { card in
                    GatewayCardModule(
                        presentation: card.presentation,
                        title: card.title,
                        memberCountText: "\(card.members.count) 个成员",
                        members: card.members,
                        isCompact: false,
                        memberDisplayLimit: 12,
                        memberRowMaxHeight: 70
                    )
                }
            }
            .padding(PreviewLayoutTokens.Spacing.page)
        }
        .background(DesignSystem.Colors.Background.canvas)
    }
}

#Preview("Gateway Card List Module") {
    GatewayCardListModulePreviewContainer()
        .frame(width: 900, height: 860)
}
