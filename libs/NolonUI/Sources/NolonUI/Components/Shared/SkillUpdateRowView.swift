import SwiftUI
import NolonUIFoundation

public struct SkillUpdateRowView: View {
    public let data: SkillUpdateRowData
    public let onUpdate: () -> Void

    public init(data: SkillUpdateRowData, onUpdate: @escaping () -> Void) {
        self.data = data
        self.onUpdate = onUpdate
    }

    public var body: some View {
        HStack(spacing: 16) {
            statusIndicator

            VStack(alignment: .leading, spacing: 4) {
                Text(data.skillName)
                    .font(.headline)

                HStack(spacing: 8) {
                    Label(data.sourceLabel, systemImage: data.sourceSystemImage)
                        .dsIconLabelText(foreground: DesignSystem.Colors.Text.secondary, font: .caption)

                    if let currentVersionText = data.currentVersionText {
                        Text(currentVersionText)
                            .font(.caption)
                            .dsSecondaryText(font: .caption)
                    }

                    if let latestVersionText = data.latestVersionText {
                        Text(latestVersionText)
                            .font(.caption)
                            .foregroundStyle(DesignSystem.Colors.Status.success)
                    }
                }
            }

            Spacer()

            if data.hasUpdate {
                Button(data.updateButtonTitle) {
                    onUpdate()
                }
                .dsPrimaryButton()
                .controlSize(.small)
            } else {
                Label(data.upToDateText, systemImage: "checkmark")
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Status.success)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusIndicator: some View {
        Circle()
            .fill(data.hasUpdate ? DesignSystem.Colors.Status.warning : DesignSystem.Colors.Status.success)
            .frame(width: 8, height: 8)
    }
}
