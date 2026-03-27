import SwiftUI
import NolonUIFoundation

public struct SettingsActionCardView: View {
    let data: SettingsActionCardData
    let onTap: () -> Void

    public init(data: SettingsActionCardData, onTap: @escaping () -> Void) {
        self.data = data
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            HStack {
                leadingView
                Text(data.title)
                Spacer()
                if let trailingText = data.trailingText, !trailingText.isEmpty {
                    Text(trailingText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(trailingColor)
                }
            }
            .padding(16)
            .dsCard()
        }
        .dsLinkButton()
    }

    @ViewBuilder
    private var leadingView: some View {
        if data.isLeadingLoading {
            ProgressView()
                .controlSize(.small)
        } else if let image = data.leadingSystemImage {
            Image(systemName: image)
        }
    }

    private var trailingColor: Color {
        switch data.trailingTone {
        case .secondary:
            return DesignSystem.Colors.Text.secondary
        case .warning:
            return DesignSystem.Colors.Status.warning
        }
    }
}
