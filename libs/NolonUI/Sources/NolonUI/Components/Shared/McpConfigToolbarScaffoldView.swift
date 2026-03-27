import SwiftUI

public struct McpConfigToolbarScaffoldView<Content: View>: View {
    let documentationURL: URL?
    let documentationTitle: String
    let editTitle: String
    let onEdit: () -> Void
    let content: () -> Content

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
        onEdit: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.documentationURL = documentationURL
        self.documentationTitle = documentationTitle
        self.editTitle = editTitle
        self.onEdit = onEdit
        self.content = content
    }

    public var body: some View {
        content()
            .toolbar {
                ToolbarItem {
                    McpConfigActionsToolbarView(
                        documentationURL: documentationURL,
                        documentationTitle: documentationTitle,
                        editTitle: editTitle,
                        onEdit: onEdit
                    )
                }
            }
    }
}
