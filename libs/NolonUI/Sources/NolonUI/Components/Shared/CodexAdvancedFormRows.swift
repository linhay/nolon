import SwiftUI

public struct CodexAdvancedAlignedConfigRow<Control: View>: View {
    let label: String
    let description: String?
    let control: () -> Control

    public init(
        label: String,
        description: String? = nil,
        @ViewBuilder control: @escaping () -> Control
    ) {
        self.label = label
        self.description = description
        self.control = control
    }

    public var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption.monospaced())
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)

                if let description, !description.isEmpty {
                    Text(description)
                        .font(.caption2)
                        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 12)

            control()
                .frame(minWidth: 200, maxWidth: 420, alignment: .trailing)
        }
    }
}
