import SwiftUI
import NolonUIFoundation

public struct CodexRuntimeDiagnosticsCardView: View {
    public let title: String
    public let rows: [CodexRuntimeDiagnosticRowData]

    public init(
        title: String = NSLocalizedString(
            "codex.runtime.diagnostics.title",
            value: "Diagnostics",
            comment: "Runtime diagnostics title"
        ),
        rows: [CodexRuntimeDiagnosticRowData]
    ) {
        self.title = title
        self.rows = rows
    }

    public var body: some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption)
                    .dsSecondaryText(font: .caption)

                ForEach(rows) { row in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(row.label)
                            .font(.caption)
                            .dsSecondaryText(font: .caption)
                            .frame(width: 90, alignment: .leading)
                        Text(row.value)
                            .font(.callout.monospaced())
                            .textSelection(.enabled)
                            .lineLimit(1)
                    }
                }
            }
            .padding(8)
            .dsCard(
                background: DesignSystem.Colors.Background.elevated,
                cornerRadius: DesignSystem.Metrics.cornerRadiusS,
                borderColor: DesignSystem.Colors.Component.border,
                borderWidth: 1
            )
        }
    }
}

public struct CodexRuntimeLogsCardView: View {
    public let data: CodexRuntimeLogsSectionData
    public let onRefresh: () -> Void
    public let onCopy: () -> Void
    public let onClear: () -> Void

    public init(
        data: CodexRuntimeLogsSectionData,
        onRefresh: @escaping () -> Void,
        onCopy: @escaping () -> Void,
        onClear: @escaping () -> Void
    ) {
        self.data = data
        self.onRefresh = onRefresh
        self.onCopy = onCopy
        self.onClear = onClear
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(data.title)
                    .font(.headline)
                Spacer()
                if let pidText = data.pidText {
                    Text(pidText)
                        .font(.caption.monospacedDigit())
                        .dsSecondaryText(font: .caption)
                }
            }

            HStack(spacing: 10) {
                Button(data.refreshTitle, action: onRefresh)
                    .disabled(data.isLoading)

                Button(data.copyTitle, action: onCopy)
                    .disabled(data.logsText.isEmpty)

                Button(data.clearTitle, action: onClear)
                    .disabled(data.logsText.isEmpty && data.errorMessage == nil)

                Spacer()

                if data.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if let error = data.errorMessage, !error.isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Status.error)
            }

            ScrollView {
                Text(data.logsText.isEmpty ? data.emptyText : data.logsText)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(minHeight: 140)
            .dsCard(
                background: DesignSystem.Colors.Background.elevated,
                cornerRadius: DesignSystem.Metrics.cornerRadiusS,
                borderColor: DesignSystem.Colors.Component.border,
                borderWidth: 1
            )
        }
        .padding(.top, 2)
        .dsCard(
            background: DesignSystem.Colors.Background.elevated,
            cornerRadius: DesignSystem.Metrics.cornerRadiusS,
            borderColor: DesignSystem.Colors.Component.border,
            borderWidth: 1
        )
    }
}
