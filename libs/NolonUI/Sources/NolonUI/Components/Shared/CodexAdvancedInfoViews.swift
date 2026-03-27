import SwiftUI

public enum CodexAdvancedHintTone {
    case secondary
    case warning
}

public struct CodexAdvancedSectionHeaderRowView: View {
    let title: String
    let isLoading: Bool

    public init(title: String, isLoading: Bool) {
        self.title = title
        self.isLoading = isLoading
    }

    public var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(DesignSystem.Colors.Text.primary)

            Spacer(minLength: 0)

            if isLoading {
                ProgressView().controlSize(.small)
            }
        }
    }
}

public struct CodexAdvancedHintTextView: View {
    let text: String
    let tone: CodexAdvancedHintTone

    public init(text: String, tone: CodexAdvancedHintTone = .secondary) {
        self.text = text
        self.tone = tone
    }

    public var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(foregroundStyle)
    }

    private var foregroundStyle: Color {
        switch tone {
        case .secondary:
            return DesignSystem.Colors.Text.secondary
        case .warning:
            return DesignSystem.Colors.Status.warning
        }
    }
}
