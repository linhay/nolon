import SwiftUI
import NolonUIFoundation

public struct CodexAdvancedSectionHeaderView: View {
    let title: String

    public init(title: String) {
        self.title = title
    }

    public var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(DesignSystem.Colors.Text.primary)
    }
}

public struct CodexAdvancedStatTileView: View {
    let data: CodexAdvancedStatTileData

    public init(data: CodexAdvancedStatTileData) {
        self.data = data
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(data.title)
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
            Text(data.value)
                .font(.callout.weight(.semibold))
                .foregroundStyle(DesignSystem.Colors.Text.primary)
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusS, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusS, style: .continuous)
                .stroke(DesignSystem.Colors.Component.border.opacity(0.22), lineWidth: 1)
        )
    }
}

public struct CodexAdvancedPathInfoRowView: View {
    let data: CodexAdvancedPathInfoRowData

    public init(data: CodexAdvancedPathInfoRowData) {
        self.data = data
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: data.iconName)
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
            Text(data.text)
                .font(.caption.monospaced())
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .dsCard(
            background: DesignSystem.Colors.Background.surface.opacity(0.22),
            cornerRadius: DesignSystem.Metrics.cornerRadiusS,
            borderColor: DesignSystem.Colors.Component.border.opacity(0.14)
        )
    }
}

public struct CodexAdvancedTrailingActionRowView: View {
    let title: String
    let onTap: () -> Void

    public init(title: String, onTap: @escaping () -> Void) {
        self.title = title
        self.onTap = onTap
    }

    public var body: some View {
        HStack {
            Spacer(minLength: 0)
            Button(title) {
                onTap()
            }
            .dsSecondaryButton()
        }
    }
}
