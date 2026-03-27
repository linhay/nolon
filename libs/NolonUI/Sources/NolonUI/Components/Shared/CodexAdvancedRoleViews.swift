import SwiftUI
import NolonUIFoundation

public struct CodexAdvancedRoleEmptyStateCardView: View {
    let text: String

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(DesignSystem.Colors.Text.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dsCard(
                background: DesignSystem.Colors.Background.surface.opacity(0.26),
                cornerRadius: DesignSystem.Metrics.cornerRadiusS,
                borderColor: DesignSystem.Colors.Component.border.opacity(0.18)
            )
    }
}

public struct CodexAdvancedRoleRowView: View {
    let data: CodexAdvancedRoleRowData
    let onEdit: () -> Void
    let onDelete: () -> Void

    public init(
        data: CodexAdvancedRoleRowData,
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.data = data
        self.onEdit = onEdit
        self.onDelete = onDelete
    }

    public var body: some View {
        HStack(spacing: 8) {
            Text(data.title)
                .font(.headline)
                .foregroundStyle(DesignSystem.Colors.Text.primary)

            Text(data.modelText)
                .font(.caption.monospaced())
                .foregroundStyle(DesignSystem.Colors.Text.secondary)

            Spacer(minLength: 0)

            Button(data.editTitle) {
                onEdit()
            }
            .buttonStyle(.borderless)

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCard(
            background: DesignSystem.Colors.Background.surface.opacity(0.26),
            cornerRadius: DesignSystem.Metrics.cornerRadiusS,
            borderColor: DesignSystem.Colors.Component.border.opacity(0.18)
        )
    }
}
