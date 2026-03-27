import SwiftUI

public struct McpConfigActionsToolbarView: View {
    let documentationURL: URL?
    let documentationTitle: String
    let editTitle: String
    let onEdit: () -> Void

    public init(
        documentationURL: URL?,
        documentationTitle: String = NSLocalizedString(
            "mcp.action.documentation",
            value: "Documentation",
            comment: "MCP documentation action title"
        ),
        editTitle: String = NSLocalizedString(
            "mcp.action.edit_config",
            value: "Edit Config",
            comment: "MCP edit config action title"
        ),
        onEdit: @escaping () -> Void
    ) {
        self.documentationURL = documentationURL
        self.documentationTitle = documentationTitle
        self.editTitle = editTitle
        self.onEdit = onEdit
    }

    public var body: some View {
        Menu {
            if let documentationURL {
                Link(destination: documentationURL) {
                    Label(documentationTitle, systemImage: "doc.text")
                }
            }
            Button {
                onEdit()
            } label: {
                Label(editTitle, systemImage: "pencil")
            }
        } label: {
            Label(editTitle, systemImage: "pencil")
        }
    }
}
