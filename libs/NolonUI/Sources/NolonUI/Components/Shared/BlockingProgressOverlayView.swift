import SwiftUI

public struct BlockingProgressOverlayView: View {
    let message: String

    public init(message: String) {
        self.message = message
    }

    public var body: some View {
        ZStack {
            DesignSystem.Colors.Overlay.scrim
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusXL, style: .continuous))

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)

                Text(message)
                    .font(.system(size: 14, weight: .medium))
                    .dsSecondaryText(font: .system(size: 14, weight: .medium))
            }
            .padding(32)
            .dsGlassPanel(cornerRadius: DesignSystem.Metrics.cornerRadiusL)
        }
    }
}
