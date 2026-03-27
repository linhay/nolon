import SwiftUI
import NolonUIFoundation

public struct CodexBinaryVersionTableView: View {
    public let data: CodexBinaryVersionTableData
    public let onTapRow: (String) -> Void
    public let onTapAction: (String) -> Void

    public init(
        data: CodexBinaryVersionTableData,
        onTapRow: @escaping (String) -> Void,
        onTapAction: @escaping (String) -> Void
    ) {
        self.data = data
        self.onTapRow = onTapRow
        self.onTapAction = onTapAction
    }

    public var body: some View {
        VStack(spacing: 0) {
            header

            Divider()
                .overlay(DesignSystem.Colors.Component.border.opacity(0.35))

            ForEach(Array(data.rows.enumerated()), id: \.element.id) { index, row in
                rowView(row)
                if index != data.rows.count - 1 {
                    Divider()
                        .overlay(DesignSystem.Colors.Component.border.opacity(0.28))
                }
            }
        }
        .dsCard(
            background: DesignSystem.Colors.Background.surface.opacity(0.38),
            cornerRadius: DesignSystem.Metrics.cornerRadiusS,
            borderColor: DesignSystem.Colors.Component.border.opacity(0.22)
        )
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text(data.nameTitle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(data.versionTitle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(data.sourceTitle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(data.stateTitle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(data.actionsTitle)
                .frame(width: 120, alignment: .trailing)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(DesignSystem.Colors.Text.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func rowView(_ row: CodexBinaryVersionRowData) -> some View {
        HStack(spacing: 10) {
            Text(row.nameText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(DesignSystem.Colors.Text.primary)
            Text(row.versionText)
                .font(.callout.monospaced())
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(DesignSystem.Colors.Text.primary)
            Text(row.sourceText)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
            Text(row.stateText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(toneColor(row.stateTone))

            actionView(for: row)
                .frame(width: 120, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            guard row.isSelectable else { return }
            onTapRow(row.id)
        }
    }

    @ViewBuilder
    private func actionView(for row: CodexBinaryVersionRowData) -> some View {
        if row.isActionInProgress {
            VStack(alignment: .trailing, spacing: 4) {
                if let fraction = row.progressFraction, let progressText = row.progressText {
                    ProgressView(value: fraction)
                        .frame(width: 70, alignment: .trailing)
                    Text(progressText)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                } else {
                    ProgressView()
                        .frame(width: 70, alignment: .trailing)
                    Text(row.inProgressFallbackText ?? "")
                        .font(.caption2)
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                }
            }
        } else if let actionTitle = row.actionTitle {
            Button(actionTitle) {
                onTapAction(row.id)
            }
            .buttonStyle(.plain)
            .foregroundStyle(row.kind == .local ? DesignSystem.Colors.Status.error : DesignSystem.Colors.primary)
            .disabled(!row.actionEnabled)
        } else {
            EmptyView()
        }
    }

    private func toneColor(_ tone: CodexBinaryRowTone) -> Color {
        switch tone {
        case .primary:
            return DesignSystem.Colors.Text.primary
        case .secondary:
            return DesignSystem.Colors.Text.secondary
        case .success:
            return DesignSystem.Colors.Status.success
        case .warning:
            return DesignSystem.Colors.Status.warning
        case .error:
            return DesignSystem.Colors.Status.error
        }
    }
}
