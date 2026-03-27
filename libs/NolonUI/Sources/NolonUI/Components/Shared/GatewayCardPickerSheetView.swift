import SwiftUI
import NolonUIFoundation

public struct GatewayCardPickerSheetView: View {
    let data: GatewayCardPickerSheetData
    let onSelect: (UUID) -> Void
    let onCancel: () -> Void

    public init(
        data: GatewayCardPickerSheetData,
        onSelect: @escaping (UUID) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.data = data
        self.onSelect = onSelect
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(data.title)
                .font(.headline)

            if let subtitle = data.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
            }

            List(data.items) { item in
                Button {
                    onSelect(item.id)
                } label: {
                    HStack {
                        Text(item.title)
                        Spacer(minLength: 0)
                        Text(item.countText)
                            .font(.caption)
                            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
            .frame(minHeight: data.minListHeight)

            HStack {
                Spacer(minLength: 0)
                Button(data.cancelTitle) {
                    onCancel()
                }
            }
        }
        .padding(16)
        .frame(width: data.width, height: data.height)
    }
}
