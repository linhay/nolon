import SwiftUI

struct SheetHeaderView: View {
    let title: String
    var subtitle: String? = nil
    var isCloseDisabled: Bool = false
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(DesignSystem.Colors.Text.primary)

                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
            }
            .accessibilityLabel(NSLocalizedString("Close", comment: "Close"))
            .buttonStyle(.plain)
            .disabled(isCloseDisabled)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }
}
