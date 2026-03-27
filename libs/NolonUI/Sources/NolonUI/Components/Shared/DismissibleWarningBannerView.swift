import SwiftUI

public struct DismissibleWarningBannerView: View {
    let message: String
    let onDismiss: () -> Void

    public init(
        message: String,
        onDismiss: @escaping () -> Void
    ) {
        self.message = message
        self.onDismiss = onDismiss
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DesignSystem.Colors.Status.warning)
            Text(message)
                .font(.callout)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .textSelection(.enabled)
            Spacer(minLength: 0)
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(DesignSystem.Colors.Status.warning.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(DesignSystem.Colors.Status.warning.opacity(0.28), lineWidth: 1)
        )
    }
}
