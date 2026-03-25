import SwiftUI
import NolonUIFoundation

public struct WorkflowCardView<ExtraContextMenu: View>: View {
    @State private var viewModel = WorkflowCardViewViewModel()
    private let workflow: WorkflowInfo
    private let searchText: String
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
        self.workflow = workflow
        self.searchText = searchText
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
            HStack(alignment: .center) {
                HStack(spacing: DesignSystem.Metrics.spacingS) {
                    HighlightedText(text: workflow.name, query: searchText)
                        .font(.headline)
                        .lineLimit(1)

                    sourceBadge
                }

                Spacer()

                moreMenu
            }
        } bodyContent: {
            HighlightedText(text: workflow.description, query: searchText)
                .font(.caption)
                .dsSecondaryText(font: .caption)
                .lineLimit(3)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, minHeight: descriptionHeight, maxHeight: descriptionHeight, alignment: .topLeading)
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
        .confirmationDialog(
            NSLocalizedString("action.delete_confirm_title", value: "Confirm Delete", comment: "Delete confirmation title"),
            isPresented: $viewModel.showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("action.delete", comment: "Delete"), role: .destructive) {
                Task { await onDelete() }
            }
            Button(NSLocalizedString("action.cancel", value: "Cancel", comment: "Cancel action"), role: .cancel) {}
        } message: {
            Text(
                NSLocalizedString(
                    "action.delete_confirm_message",
                    value: "Are you sure you want to delete this workflow? This action cannot be undone.",
                    comment: "Delete confirmation message"
                )
            )
        }
    }

    @ViewBuilder
    private var sourceBadge: some View {
        Text(NSLocalizedString(workflow.source.localizedKey, value: workflow.source.fallbackTitle, comment: "Workflow source"))
            .font(DesignSystem.Typography.caption2)
            .fontWeight(.bold)
            .dsBadge(
                foreground: sourceColor,
                background: sourceColor.opacity(0.15),
                horizontalPadding: 6,
                verticalPadding: 2
            )
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        Button {
            onReveal()
        } label: {
            Label(
                NSLocalizedString("action.show_in_finder", comment: "Show in Finder"),
                systemImage: "folder"
            )
            .dsIconLabelButton()
        }

        Divider()

        Button(role: .destructive) {
            viewModel.showingDeleteConfirmation = true
        } label: {
            Label(
                NSLocalizedString("action.delete", comment: "Delete"),
                systemImage: "trash"
            )
            .dsIconLabelButton()
        }

        extraContextMenu(workflow)
    }

    private var moreMenu: some View {
        Menu {
            contextMenuItems
        } label: {
            Image(systemName: "ellipsis")
                .dsIconButton()
        }
        .dsBorderlessMenu()
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private var sourceColor: Color {
        switch workflow.source {
        case .skill:
            return DesignSystem.Colors.primary
        case .user:
            return DesignSystem.Colors.Status.warning
        case .mcp:
            return DesignSystem.Colors.secondary
        case .unknown:
            return DesignSystem.Colors.Text.secondary
        }
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
