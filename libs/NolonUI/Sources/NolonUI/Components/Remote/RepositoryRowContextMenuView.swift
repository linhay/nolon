import SwiftUI

public struct RepositoryRowContextMenuView<TrailingContent: View>: View {
    let syncTitle: String
    let revealTitle: String
    let editTitle: String
    let removeTitle: String
    let onSync: (() -> Void)?
    let onRevealInFinder: (() -> Void)?
    let onEdit: (() -> Void)?
    let onRemove: (() -> Void)?
    let trailingContent: () -> TrailingContent

    public init(
        syncTitle: String = "Sync",
        revealTitle: String = "Reveal in Finder",
        editTitle: String = "Edit",
        removeTitle: String = "Remove",
        onSync: (() -> Void)? = nil,
        onRevealInFinder: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        onRemove: (() -> Void)? = nil,
        @ViewBuilder trailingContent: @escaping () -> TrailingContent
    ) {
        self.syncTitle = syncTitle
        self.revealTitle = revealTitle
        self.editTitle = editTitle
        self.removeTitle = removeTitle
        self.onSync = onSync
        self.onRevealInFinder = onRevealInFinder
        self.onEdit = onEdit
        self.onRemove = onRemove
        self.trailingContent = trailingContent
    }

    public var body: some View {
        if let onSync {
            Button {
                onSync()
            } label: {
                Label(syncTitle, systemImage: "arrow.triangle.2.circlepath")
                    .dsIconLabelButton()
            }
        }

        if let onRevealInFinder {
            Button {
                onRevealInFinder()
            } label: {
                Label(revealTitle, systemImage: "folder")
                    .dsIconLabelButton()
            }
        }

        if let onEdit {
            Button {
                onEdit()
            } label: {
                Label(editTitle, systemImage: "pencil")
                    .dsIconLabelButton()
            }
        }

        if let onRemove {
            Divider()
            ContextMenuDestructiveButton(
                title: removeTitle,
                systemImage: "trash"
            ) {
                onRemove()
            }
        }

        trailingContent()
    }
}
