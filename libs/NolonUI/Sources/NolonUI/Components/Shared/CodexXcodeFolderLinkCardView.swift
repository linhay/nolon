import SwiftUI
import NolonUIFoundation

public struct CodexXcodeFolderLinkCardView: View {
    let data: CodexXcodeFolderLinkCardData
    let onToggleLink: (Bool) -> Void
    let onShowInFinder: () -> Void

    public init(
        data: CodexXcodeFolderLinkCardData,
        onToggleLink: @escaping (Bool) -> Void,
        onShowInFinder: @escaping () -> Void
    ) {
        self.data = data
        self.onToggleLink = onToggleLink
        self.onShowInFinder = onShowInFinder
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(data.folderTitle)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(DesignSystem.Colors.Text.primary)

                        Text(data.statusText)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(
                                data.isLinked
                                ? DesignSystem.Colors.Status.success
                                : DesignSystem.Colors.Text.secondary
                            )
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                (data.isLinked
                                    ? DesignSystem.Colors.Status.success
                                    : DesignSystem.Colors.Component.controlFillSubtle).opacity(0.12),
                                in: Capsule()
                            )
                    }
                }

                Spacer(minLength: 0)

                Toggle(
                    "",
                    isOn: Binding(
                        get: { data.isLinked },
                        set: { onToggleLink($0) }
                    )
                )
                .labelsHidden()
                .toggleStyle(.switch)
                .disabled(data.isApplying)
            }

            VStack(alignment: .leading, spacing: 6) {
                CodexAdvancedPathInfoRowView(
                    data: CodexAdvancedPathInfoRowData(
                        iconName: "link",
                        text: data.sourcePathText
                    )
                )

                CodexAdvancedPathInfoRowView(
                    data: CodexAdvancedPathInfoRowData(
                        iconName: "folder",
                        text: data.targetPathText
                    )
                )
            }

            if data.hasVisibleEntries {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text(data.conflictHintText)
                        .font(.caption)
                }
                .foregroundStyle(DesignSystem.Colors.Status.warning)
            }

            HStack {
                Spacer(minLength: 0)
                Menu {
                    Button(data.showInFinderTitle) {
                        onShowInFinder()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                        .frame(width: 28, height: 24)
                        .background(
                            DesignSystem.Colors.Component.controlFillSubtle.opacity(0.3),
                            in: RoundedRectangle(cornerRadius: 7)
                        )
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCard(
            background: DesignSystem.Colors.Background.elevated.opacity(0.55),
            cornerRadius: DesignSystem.Metrics.cornerRadiusS,
            borderColor: DesignSystem.Colors.Component.border.opacity(0.18)
        )
    }
}
