import SwiftUI
import NolonUIFoundation

public struct CodexAdvancedFeatureRowView: View {
    private struct ChipStyle {
        let foreground: Color
        let background: Color
        let border: Color
    }

    let data: CodexAdvancedFeatureRowData
    let onToggle: (Bool) -> Void

    public init(
        data: CodexAdvancedFeatureRowData,
        onToggle: @escaping (Bool) -> Void
    ) {
        self.data = data
        self.onToggle = onToggle
    }

    public var body: some View {
        let maturityStyle = chipStyle(for: data.maturityTone)
        let sourceStyle = chipStyle(for: data.sourceTone)

        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                highlightedText(data.keyText, query: data.queryText)
                    .font(.callout.monospaced())
                    .foregroundStyle(DesignSystem.Colors.Text.primary)

                highlightedText(data.descriptionText, query: data.queryText)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)

                HStack(spacing: 6) {
                    highlightedText(data.maturityText, query: data.queryText)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(maturityStyle.foreground)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(maturityStyle.background, in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(maturityStyle.border, lineWidth: 1)
                        )

                    highlightedText(data.sourceText, query: data.queryText)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(sourceStyle.foreground)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(sourceStyle.background, in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(sourceStyle.border, lineWidth: 1)
                        )
                }
            }

            Spacer(minLength: 0)

            Toggle(
                "",
                isOn: Binding(
                    get: { data.isEnabled },
                    set: { onToggle($0) }
                )
            )
            .labelsHidden()
            .toggleStyle(.switch)
            .padding(.top, 2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCard(
            background: DesignSystem.Colors.Background.surface.opacity(0.25),
            cornerRadius: DesignSystem.Metrics.cornerRadiusS,
            borderColor: DesignSystem.Colors.Component.border.opacity(0.18)
        )
    }

    private func highlightedText(_ raw: String, query: String) -> Text {
        var text = AttributedString(raw)
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return Text(text) }

        let lowerRaw = raw.lowercased()
        let lowerKeyword = keyword.lowercased()
        var searchStart = lowerRaw.startIndex
        while let range = lowerRaw.range(of: lowerKeyword, range: searchStart..<lowerRaw.endIndex) {
            let lowerBound = lowerRaw.distance(from: lowerRaw.startIndex, to: range.lowerBound)
            let upperBound = lowerRaw.distance(from: lowerRaw.startIndex, to: range.upperBound)
            let start = text.index(text.startIndex, offsetByCharacters: lowerBound)
            let end = text.index(text.startIndex, offsetByCharacters: upperBound)
            text[start..<end].backgroundColor = .yellow.opacity(0.35)
            searchStart = range.upperBound
        }
        return Text(text)
    }

    private func chipStyle(for tone: CodexFeatureChipTone) -> ChipStyle {
        switch tone {
        case .success:
            return .init(
                foreground: DesignSystem.Colors.Status.success,
                background: DesignSystem.Colors.Status.success.opacity(0.14),
                border: DesignSystem.Colors.Status.success.opacity(0.45)
            )
        case .info:
            return .init(
                foreground: DesignSystem.Colors.Status.info,
                background: DesignSystem.Colors.Status.info.opacity(0.14),
                border: DesignSystem.Colors.Status.info.opacity(0.45)
            )
        case .warning:
            return .init(
                foreground: DesignSystem.Colors.Status.warning,
                background: DesignSystem.Colors.Status.warning.opacity(0.14),
                border: DesignSystem.Colors.Status.warning.opacity(0.45)
            )
        case .error:
            return .init(
                foreground: DesignSystem.Colors.Status.error,
                background: DesignSystem.Colors.Status.error.opacity(0.14),
                border: DesignSystem.Colors.Status.error.opacity(0.45)
            )
        case .secondary:
            return .init(
                foreground: DesignSystem.Colors.Text.secondary,
                background: DesignSystem.Colors.Component.controlFillSubtle.opacity(0.25),
                border: DesignSystem.Colors.Component.border.opacity(0.35)
            )
        }
    }
}
