import SwiftUI
import NolonUIFoundation

public struct CodexRuntimeProcessRowView<ExpandedContent: View>: View {
    public let data: CodexRuntimeProcessRowData
    public let onStop: () -> Void
    public let onForce: () -> Void
    public let onToggleSelection: () -> Void
    public let expandedContent: () -> ExpandedContent

    public init(
        data: CodexRuntimeProcessRowData,
        onStop: @escaping () -> Void,
        onForce: @escaping () -> Void,
        onToggleSelection: @escaping () -> Void,
        @ViewBuilder expandedContent: @escaping () -> ExpandedContent
    ) {
        self.data = data
        self.onStop = onStop
        self.onForce = onForce
        self.onToggleSelection = onToggleSelection
        self.expandedContent = expandedContent
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Text(data.pidText)
                    .font(.subheadline.monospacedDigit())

                Text(data.elapsedText)
                    .font(.caption.monospacedDigit())
                    .dsSecondaryText(font: .caption)

                if let hint = data.providerHint, !hint.isEmpty {
                    Text(hint)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .dsBadge(
                            foreground: DesignSystem.Colors.Text.secondary,
                            background: DesignSystem.Colors.Background.elevated
                        )
                }

                Spacer()

                Button(data.stopTitle, action: onStop)
                    .disabled(data.isStopping)

                Button(data.forceTitle, action: onForce)
                    .disabled(data.isStopping)
            }

            Text(data.commandText)
                .font(.caption.monospaced())
                .lineLimit(2)
                .textSelection(.enabled)
                .dsSecondaryText(font: .caption)

            if let workingDirectory = data.workingDirectory, !workingDirectory.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                        .font(.caption)
                        .dsSecondaryText(font: .caption)
                    Text(workingDirectory)
                        .font(.caption.monospaced())
                        .lineLimit(1)
                        .textSelection(.enabled)
                        .dsSecondaryText(font: .caption)
                }
            }

            if data.isSelected {
                expandedContent()
            }
        }
        .padding(10)
        .dsCard(
            background: data.isSelected ? DesignSystem.Colors.primary.opacity(0.08) : DesignSystem.Colors.Background.elevated,
            cornerRadius: DesignSystem.Metrics.cornerRadiusS,
            borderColor: data.isSelected ? DesignSystem.Colors.primary.opacity(0.45) : DesignSystem.Colors.Component.border,
            borderWidth: 1
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggleSelection)
    }
}
