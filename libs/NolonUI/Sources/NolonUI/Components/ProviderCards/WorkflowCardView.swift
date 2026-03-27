import SwiftUI
import NolonUIFoundation

public struct WorkflowCardView<ExtraContextMenu: View>: View {
    @State private var viewModel: WorkflowCardViewViewModel
    private let onReveal: () -> Void
    private let onDelete: () async -> Void
    private let onTap: () -> Void
    private let extraContextMenu: (WorkflowInfo) -> ExtraContextMenu

    private let descriptionHeight: CGFloat = 44

    public init(
        workflow: WorkflowInfo,
        searchText: String,
        onReveal: @escaping () -> Void,
        onDelete: @escaping () async -> Void,
        onTap: @escaping () -> Void,
        @ViewBuilder extraContextMenu: @escaping (WorkflowInfo) -> ExtraContextMenu
    ) {
        self._viewModel = State(
            initialValue: WorkflowCardViewViewModel(
                workflow: workflow,
                searchText: searchText
            )
        )
        self.onReveal = onReveal
        self.onDelete = onDelete
        self.onTap = onTap
        self.extraContextMenu = extraContextMenu
    }

    public init(
        workflow: WorkflowInfo,
        searchText: String,
        onReveal: @escaping () -> Void,
        onDelete: @escaping () async -> Void,
        onTap: @escaping () -> Void
    ) where ExtraContextMenu == EmptyView {
        self.init(
            workflow: workflow,
            searchText: searchText,
            onReveal: onReveal,
            onDelete: onDelete,
            onTap: onTap,
            extraContextMenu: { _ in EmptyView() }
        )
    }

    public var body: some View {
        ProviderCardTemplate(
            minHeight: 140,
            onTap: onTap
        ) {
            ProviderCardTitleMenuRow {
                HStack(spacing: DesignSystem.Metrics.spacingS) {
                    HighlightedText(text: viewModel.title, query: viewModel.searchText)
                        .font(.headline)
                        .lineLimit(1)

                    sourceBadge
                }
            } menuContent: {
                contextMenuItems
            }
        } bodyContent: {
            ProviderCardDescriptionBlock(
                text: viewModel.descriptionText,
                searchText: viewModel.searchText,
                minHeight: descriptionHeight,
                maxHeight: descriptionHeight
            )
        } footerContent: {
            HStack {
                Label("Workflow", systemImage: "arrow.triangle.branch")
                    .dsIconLabelText(foreground: DesignSystem.Colors.Text.secondary, font: .caption2)

                Spacer()
            }
        } actionContent: {
            EmptyView()
        } contextMenuContent: {
            contextMenuItems
        }
        .destructiveConfirmationDialog(
            data: DestructiveConfirmationDialogData(
                title: NSLocalizedString("action.delete_confirm_title", value: "Confirm Delete", comment: "Delete confirmation title"),
                message: NSLocalizedString(
                    "action.delete_confirm_message",
                    value: "Are you sure you want to delete this workflow? This action cannot be undone.",
                    comment: "Delete confirmation message"
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
    private var sourceBadge: some View {
        Text(viewModel.sourceTitle)
            .font(DesignSystem.Typography.caption2)
            .fontWeight(.bold)
            .dsBadge(
                foreground: viewModel.sourceColor,
                background: viewModel.sourceColor.opacity(0.15),
                horizontalPadding: 6,
                verticalPadding: 2
            )
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        ProviderCardRevealDeleteContextMenu(
            onReveal: onReveal,
            onDeleteRequest: { viewModel.showingDeleteConfirmation = true },
            extraContent: { extraContextMenu(viewModel.workflow) }
        )
    }
}

private struct WorkflowCardViewPreviewContainer: View {
    var body: some View {
        WorkflowCardView(
            workflow: WorkflowInfo(
                id: "workflow-1",
                name: "Publish Build",
                description: "Upload build, sync metadata, and notify the beta group automatically.",
                path: "/tmp/workflow.json",
                source: .skill
            ),
            searchText: "pb",
            onReveal: {},
            onDelete: {},
            onTap: {}
        )
        .frame(width: 320)
        .padding(16)
    }
}

#Preview("Workflow Card") {
    WorkflowCardViewPreviewContainer()
}
