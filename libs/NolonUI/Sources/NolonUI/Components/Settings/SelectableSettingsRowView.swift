import SwiftUI
import NolonUIFoundation

public struct SelectableSettingsRowView: View {
    let data: SelectableSettingsRowData
    let onTap: () -> Void

    public init(data: SelectableSettingsRowData, onTap: @escaping () -> Void) {
        self.data = data
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                if let icon = data.leadingSystemImage {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .frame(width: 24)
                }

                Text(data.title)
                    .font(.system(size: 13, weight: .medium))

                Spacer()

                if data.isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.primary)
                }
            }
            .padding(CGFloat(data.contentPadding))
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    if data.isSelected {
                        RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusM)
                            .stroke(DesignSystem.Colors.primary.opacity(0.5), lineWidth: 2)
                            .background(DesignSystem.Colors.primary.opacity(0.05))
                            .shadow(
                                color: data.showsSelectionShadow ? DesignSystem.Colors.primary.opacity(0.2) : .clear,
                                radius: data.showsSelectionShadow ? 8 : 0
                            )
                    }
                }
            )
        }
        .dsLinkButton()
    }
}
