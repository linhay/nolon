import SwiftUI
import NolonUIFoundation

public struct AgentDocCardView<ExtraContextMenu: View>: View {
    @State private var viewModel = AgentDocCardViewViewModel()
    private let doc: AgentDocInfo
    private let searchText: String
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
        self.doc = doc
        self.searchText = searchText
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
        VStack(alignment: .leading, spacing: DesignSystem.Metrics.spacingM) {
            ProviderCardTitleMenuRow {
                HighlightedText(text: doc.fileName, query: searchText)
                    .font(.headline)
                    .lineLimit(1)
            } menuContent: {
                contextMenuItems
            }

            ProviderCardIconCaptionRow(
                iconName: doc.kind == .override ? "arrow.up.circle" : "doc.text",
                title: doc.kind == .override
                    ? NSLocalizedString("agents.priority.override", value: "Higher priority (override)", comment: "Override priority hint")
                    : NSLocalizedString("agents.priority.base", value: "Base priority", comment: "Base priority hint")
            )

            ProviderCardOptionalPreviewBlock(
                preview: doc.preview,
                searchText: searchText,
                minHeight: 16,
                maxHeight: .infinity,
                placeholderHeight: 16
            )
        }
        .padding(DesignSystem.Metrics.spacingL)
        .frame(minHeight: 140)
        .providerTabCardStyle()
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .contextMenu { contextMenuItems }
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
            extraContent: { extraContextMenu(doc) }
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
