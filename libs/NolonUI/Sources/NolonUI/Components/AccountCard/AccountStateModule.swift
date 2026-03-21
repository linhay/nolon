import SwiftUI

public struct AccountErrorStateModule: View {
    public let title: String
    public let message: String

    public init(
        title: String = "Sync Failed",
        message: String
    ) {
        self.title = title
        self.message = message
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DesignSystem.Colors.Status.error)
            Text(message)
                .font(.caption2)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Colors.Status.error.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusM, style: .continuous))
    }
}

public struct AccountLoadingStateModule: View {
    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: PreviewLayoutTokens.Spacing.row) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(DesignSystem.Colors.Component.controlFill)
                .frame(height: 12)
                .frame(maxWidth: 210)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(DesignSystem.Colors.Component.controlFill)
                .frame(height: 12)
                .frame(maxWidth: 160)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(DesignSystem.Colors.Component.controlFill)
                .frame(height: 12)
                .frame(maxWidth: 240)
        }
        .redacted(reason: .placeholder)
    }
}

public struct AccountEmptyStateModule: View {
    public let text: String

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        HStack(spacing: PreviewLayoutTokens.Spacing.row) {
            Image(systemName: "tray")
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
            Text(text)
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
            Spacer(minLength: 0)
        }
        .padding(PreviewLayoutTokens.Spacing.row)
        .background(DesignSystem.Colors.Component.controlFillSubtle)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusM, style: .continuous))
    }
}
