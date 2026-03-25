import SwiftUI

public enum FloatingCloseButtonMetrics {
    public static let iconSystemName = "xmark"
    public static let iconFontSize: CGFloat = 13
    public static let buttonFrameSize: CGFloat = 32
}

public struct FloatingCloseButton: View {
    @State private var viewModel = FloatingCloseButtonViewModel()
    private let help: String
    private let enableCancelShortcut: Bool
    private let action: () -> Void

    public init(
        help: String = "Close",
        enableCancelShortcut: Bool = true,
        action: @escaping () -> Void
    ) {
        self.help = help
        self.enableCancelShortcut = enableCancelShortcut
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: FloatingCloseButtonMetrics.iconSystemName)
                .font(.system(size: FloatingCloseButtonMetrics.iconFontSize, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .frame(
                    width: FloatingCloseButtonMetrics.buttonFrameSize,
                    height: FloatingCloseButtonMetrics.buttonFrameSize
                )
                .background(
                    Circle()
                        .fill(.white.opacity(0.1))
                        .background(
                            Circle()
                                .stroke(.white.opacity(0.1), lineWidth: 1)
                        )
                )
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
        .modifier(FloatingCloseButtonCancelShortcutModifier(isEnabled: enableCancelShortcut))
    }
}

private struct FloatingCloseButtonCancelShortcutModifier: ViewModifier {
    let isEnabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content.keyboardShortcut(.cancelAction)
        } else {
            content
        }
    }
}

#Preview("Floating Close Button") {
    FloatingCloseButton(help: "Close") {}
}
