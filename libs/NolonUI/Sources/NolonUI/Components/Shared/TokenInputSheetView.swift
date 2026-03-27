import SwiftUI

public struct TokenInputSheetView: View {
    @Binding var isPresented: Bool
    let host: String
    @Binding var token: String
    let onConfirm: () -> Void

    public init(
        isPresented: Binding<Bool>,
        host: String,
        token: Binding<String>,
        onConfirm: @escaping () -> Void
    ) {
        self._isPresented = isPresented
        self.host = host
        self._token = token
        self.onConfirm = onConfirm
    }

    public var body: some View {
        VStack(spacing: 0) {
            SheetHeaderView(title: NSLocalizedString("SSH Authentication Unavailable", comment: "SSH unavailable")) {
                isPresented = false
            }

            SheetDivider()

            VStack(spacing: 20) {
                Image(systemName: "key.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(DesignSystem.Colors.Status.warning)

                Text(
                    String(
                        format: NSLocalizedString(
                            "SSH key is not configured for %@. Please provide a Personal Access Token to authenticate.",
                            comment: "SSH token prompt"
                        ),
                        host
                    )
                )
                .font(.subheadline)
                .dsSecondaryText(font: .subheadline)
                .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("Personal Access Token", comment: "Personal access token"))
                        .font(.caption)
                        .dsSecondaryText(font: .caption)

                    SecureField(NSLocalizedString("Enter your token", comment: "Enter token"), text: $token)
                        .textFieldStyle(.roundedBorder)
                }

                Text(NSLocalizedString("Generate a token from your Git provider's settings with 'read_repository' scope.", comment: "Token help"))
                    .font(.caption)
                    .dsTertiaryText(font: .caption)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, SheetLayout.horizontalPadding)
            .padding(.vertical, SheetLayout.contentVerticalPadding)

            SheetDivider()

            HStack(spacing: 12) {
                Button(NSLocalizedString("Cancel", comment: "Cancel")) {
                    isPresented = false
                }
                .dsLinkButton()

                Spacer(minLength: 0)

                Button(NSLocalizedString("Save & Retry", comment: "Save and retry")) {
                    isPresented = false
                    onConfirm()
                }
                .dsPrimaryButton()
                .disabled(token.isEmpty)
            }
            .padding(.horizontal, SheetLayout.footerHorizontalPadding)
            .padding(.vertical, SheetLayout.footerVerticalPadding)
        }
        .frame(width: 420)
    }
}
