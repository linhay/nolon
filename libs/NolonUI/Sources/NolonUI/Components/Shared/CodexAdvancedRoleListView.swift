import SwiftUI
import NolonUIFoundation

public struct CodexAdvancedRoleListView: View {
    let emptyText: String
    let roles: [CodexAdvancedRoleRowData]
    let onEdit: (String) -> Void
    let onDelete: (String) -> Void

    public init(
        emptyText: String,
        roles: [CodexAdvancedRoleRowData],
        onEdit: @escaping (String) -> Void,
        onDelete: @escaping (String) -> Void
    ) {
        self.emptyText = emptyText
        self.roles = roles
        self.onEdit = onEdit
        self.onDelete = onDelete
    }

    public var body: some View {
        if roles.isEmpty {
            CodexAdvancedRoleEmptyStateCardView(text: emptyText)
        } else {
            ForEach(roles) { role in
                CodexAdvancedRoleRowView(
                    data: role,
                    onEdit: { onEdit(role.id) },
                    onDelete: { onDelete(role.id) }
                )
            }
        }
    }
}
