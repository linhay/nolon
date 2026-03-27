import SwiftUI
import NolonUIFoundation

public struct CodexAdvancedMultiAgentToggleRowView: View {
    let data: CodexAdvancedMultiAgentToggleRowData
    let onToggle: (Bool) -> Void

    public init(
        data: CodexAdvancedMultiAgentToggleRowData,
        onToggle: @escaping (Bool) -> Void
    ) {
        self.data = data
        self.onToggle = onToggle
    }

    public var body: some View {
        HStack(spacing: 10) {
            Text(data.labelText)
                .font(.caption.monospaced())
                .foregroundStyle(DesignSystem.Colors.Text.secondary)

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
        }
    }
}

public struct CodexAdvancedMultiAgentStatusRowView: View {
    let data: CodexAdvancedMultiAgentStatusRowData

    public init(data: CodexAdvancedMultiAgentStatusRowData) {
        self.data = data
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: data.isEnabled ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(data.isEnabled ? DesignSystem.Colors.Status.success : DesignSystem.Colors.Text.secondary)

            Text(data.messageText)
                .font(.callout)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
        }
    }
}
