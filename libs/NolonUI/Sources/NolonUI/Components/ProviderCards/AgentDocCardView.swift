import SwiftUI
import NolonUIFoundation

public struct AgentDocCardView<ExtraContextMenu: View>: View {
    @State private var viewModel: AgentDocCardViewViewModel
    private let onReveal: () -> Void
    private let onDelete: () async -> Void
    private let onTap: () -> Void
    private let extraContextMenu: (AgentDocInfo) -> ExtraContextMenu

    public init(
        doc: AgentDocInfo,
        searchText: String,
        onReveal: @escaping () -> Void,
        onDelete: @escaping () async -> Void,
        onTap: @escaping () -> Void,
        @ViewBuilder extraContextMenu: @escaping (AgentDocInfo) -> ExtraContextMenu
    ) {
        self._viewModel = State(
            initialValue: AgentDocCardViewViewModel(
                doc: doc,
                searchText: searchText
            )
        )
        self.onReveal = onReveal
        self.onDelete = onDelete
        self.onTap = onTap
        self.extraContextMenu = extraContextMenu
    }

    public init(
        doc: AgentDocInfo,
        searchText: String,
        onReveal: @escaping () -> Void,
        onDelete: @escaping () async -> Void,
        onTap: @escaping () -> Void
    ) where ExtraContextMenu == EmptyView {
        self.init(
            doc: doc,
            searchText: searchText,
            onReveal: onReveal,
            onDelete: onDelete,
            onTap: onTap,
            extraContextMenu: { _ in EmptyView() }
        )
    }

    public var body: some View {
        UnifiedCardContainerView(
            minHeight: 140,
            contentPadding: DesignSystem.Metrics.spacingL,
            style: .provider(isSelected: false),
            onTap: onTap
        ) {
            VStack(alignment: .leading, spacing: DesignSystem.Metrics.spacingM) {
                ProviderCardTitleMenuRow {
                    HighlightedText(text: viewModel.title, query: viewModel.searchText)
                        .font(.headline)
                        .lineLimit(1)
                } menuContent: {
                    contextMenuItems
                }

                ProviderCardIconCaptionRow(
                    iconName: viewModel.priorityIconName,
                    title: viewModel.priorityText
                )

                ProviderCardOptionalPreviewBlock(
                    preview: viewModel.preview,
                    searchText: viewModel.searchText,
                    minHeight: 16,
                    maxHeight: .infinity,
                    placeholderHeight: 16
                )

                EmptyView()
            }
        } menuContent: {
            contextMenuItems
        }
        .destructiveConfirmationDialog(
            data: DestructiveConfirmationDialogData(
                title: NSLocalizedString("action.delete_confirm_title", value: "Confirm Delete", comment: "Delete confirmation title"),
                message: NSLocalizedString(
                    "agents.delete_confirm_message",
                    value: "Are you sure you want to delete this AGENTS document? This action cannot be undone.",
                    comment: "AGENTS document delete confirmation message"
                ),
                confirmTitle: NSLocalizedString("action.delete", comment: "Delete"),
                cancelTitle: NSLocalizedString("action.cancel", value: "Cancel", comment: "Cancel action")
            ),
            isPresented: $viewModel.showingDeleteConfirmation,
            onConfirm: {
                Task { await onDelete() }
            },
            onCancel: {}
        )
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        ProviderCardRevealDeleteContextMenu(
            onReveal: onReveal,
            onDeleteRequest: { viewModel.showingDeleteConfirmation = true },
            extraContent: { extraContextMenu(viewModel.doc) }
        )
    }
}

private struct AgentDocCardViewPreviewContainer: View {
    var body: some View {
        AgentDocCardView(
            doc: AgentDocInfo(
                id: "AGENTS.md",
                fileName: "AGENTS.md",
                path: "/tmp/AGENTS.md",
                preview: "Global execution rules for coding agents.",
                kind: .override
            ),
            searchText: "ag",
            onReveal: {},
            onDelete: {},
            onTap: {}
        )
        .frame(width: 320)
        .padding(16)
    }
}

#Preview("Agent Doc Card") {
    AgentDocCardViewPreviewContainer()
}
