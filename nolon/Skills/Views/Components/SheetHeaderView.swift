import SwiftUI

struct SheetHeaderView: View {
    private let title: String
    private var subtitle: String?
    private var isCloseDisabled: Bool
    private let trailing: AnyView

    init(
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

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> some View
    ) {
        self.title = title
        self.subtitle = subtitle
        self.isCloseDisabled = false
        self.trailing = AnyView(trailing())
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
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
        .padding(.horizontal, SheetLayout.horizontalPadding)
        .padding(.top, SheetLayout.horizontalPadding)
        .padding(.bottom, SheetLayout.contentVerticalPadding)
    }
}
