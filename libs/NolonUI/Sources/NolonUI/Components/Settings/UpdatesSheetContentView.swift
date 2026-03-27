import SwiftUI
import NolonUIFoundation

public struct UpdatesSheetContentView: View {
    let data: UpdatesSheetContentData
    let onRefresh: () -> Void
    let onClose: () -> Void
    let onTapUpdate: (String) -> Void

    public init(
        data: UpdatesSheetContentData,
        onRefresh: @escaping () -> Void,
        onClose: @escaping () -> Void,
        onTapUpdate: @escaping (String) -> Void
    ) {
        self.data = data
        self.onRefresh = onRefresh
        self.onClose = onClose
        self.onTapUpdate = onTapUpdate
    }

    public var body: some View {
        SheetHeaderSection(
            title: data.title,
            subtitle: data.subtitle
        ) {
            headerTrailingActions
        } content: {
            contentView
        }
    }

    private var headerTrailingActions: some View {
        HStack(spacing: 12) {
            if let availableCountText = data.availableCountText {
                Label(availableCountText, systemImage: "arrow.down.circle")
                    .dsIconLabelText(
                        foreground: DesignSystem.Colors.Status.info,
                        font: .subheadline
                    )
            }

            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .dsIconButton()
            }
            .disabled(data.isChecking)
            .help(data.refreshHelpText)

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .dsIconButton(size: 22, foreground: DesignSystem.Colors.Text.tertiary)
            }
            .dsLinkButton()
            .accessibilityLabel(data.closeAccessibilityLabel)
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if data.isChecking {
            CenteredLoadingIndicatorView()
                .padding()
        } else if data.rows.isEmpty {
            EmptyStateScaffold(
                isEmpty: true,
                emptyTitle: data.emptyTitle,
                emptySystemImage: data.emptySystemImage,
                emptyDescription: data.emptyDescription
            ) {
                EmptyView()
            }
            .padding()
            .frame(maxHeight: .infinity)
        } else {
            SheetPaddedList(data.rows) { row in
                SkillUpdateRowView(data: row) {
                    onTapUpdate(row.id)
                }
            }
        }
    }
}
