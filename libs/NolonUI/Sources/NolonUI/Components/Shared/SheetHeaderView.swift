import SwiftUI

public enum SheetHeaderMetrics {
    public static let horizontalPadding: CGFloat = DesignSystem.Metrics.paddingXL
    public static let topPadding: CGFloat = DesignSystem.Metrics.paddingXL
    public static let bottomPadding: CGFloat = DesignSystem.Metrics.paddingL
}

public struct SheetHeaderView: View {
    @State private var viewModel = SheetHeaderViewViewModel()
    private let title: String
    private var subtitle: String?
    private var isCloseDisabled: Bool
    private let trailing: AnyView

    public init(
        title: String,
        subtitle: String? = nil,
        isCloseDisabled: Bool = false,
        onClose: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.isCloseDisabled = isCloseDisabled
        self.trailing = AnyView(
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .dsIconButton(size: 24, foreground: DesignSystem.Colors.Text.tertiary)
            }
                .accessibilityLabel(NSLocalizedString("Close", comment: "Close"))
                .dsLinkButton()
                .disabled(isCloseDisabled)
        )
    }

    public init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> some View
    ) {
        self.title = title
        self.subtitle = subtitle
        self.isCloseDisabled = false
        self.trailing = AnyView(trailing())
    }

    public var body: some View {
        HStack(alignment: .center, spacing: DesignSystem.Metrics.spacingL) {
            VStack(alignment: .leading, spacing: DesignSystem.Metrics.spacingXS) {
                Text(title)
                    .font(DesignSystem.Typography.h3)
                    .foregroundStyle(DesignSystem.Colors.Text.primary)

                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .dsSecondaryText(font: .subheadline)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
            trailing
        }
        .padding(.horizontal, SheetHeaderMetrics.horizontalPadding)
        .padding(.top, SheetHeaderMetrics.topPadding)
        .padding(.bottom, SheetHeaderMetrics.bottomPadding)
    }
}

#Preview("Sheet Header / Close") {
    SheetHeaderView(title: "Settings", subtitle: "Configure provider and runtime") {}
        .frame(width: 480)
}

#Preview("Sheet Header / Trailing") {
    SheetHeaderView(title: "Import", subtitle: "Choose import source") {
        Button("Done") {}
            .buttonStyle(.borderedProminent)
    }
    .frame(width: 480)
}
