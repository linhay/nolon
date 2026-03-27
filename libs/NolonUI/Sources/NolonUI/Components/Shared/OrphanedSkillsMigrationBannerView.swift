import SwiftUI

public struct OrphanedSkillsMigrationBannerView: View {
    let title: String
    let description: String
    let actionTitle: String
    let onAction: () -> Void

    public init(
        title: String,
        description: String,
        actionTitle: String,
        onAction: @escaping () -> Void
    ) {
        self.title = title
        self.description = description
        self.actionTitle = actionTitle
        self.onAction = onAction
    }

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(DesignSystem.Colors.Status.warning)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.caption)
                    .dsSecondaryText(font: .caption)
            }

            Spacer()

            Button(actionTitle, action: onAction)
                .dsPrimaryButton()
                .controlSize(.small)
        }
        .padding()
        .dsCard(
            background: DesignSystem.Colors.Status.warning.opacity(0.12),
            cornerRadius: DesignSystem.Metrics.cornerRadiusM,
            borderColor: DesignSystem.Colors.Status.warning.opacity(0.35)
        )
    }
}
