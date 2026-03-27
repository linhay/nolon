import SwiftUI

public struct RepositoryReadOnlyFieldView: View {
    let value: String

    public init(value: String) {
        self.value = value
    }

    public var body: some View {
        HStack {
            Text(value)
                .font(.system(size: 13))
                .dsSecondaryText(font: .system(size: 13))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .dsCard(
            background: DesignSystem.Colors.Component.controlFillSubtle,
            cornerRadius: DesignSystem.Metrics.cornerRadiusM,
            borderColor: DesignSystem.Colors.Component.border.opacity(0.20)
        )
    }
}

public struct RepositoryGitURLInputRowView: View {
    @Binding var gitURL: String
    let placeholder: String
    let providerDisplayName: String?
    let providerLogoName: String?
    let pasteTitle: String
    let onPaste: () -> Void

    public init(
        gitURL: Binding<String>,
        placeholder: String = "https://github.com/...",
        providerDisplayName: String?,
        providerLogoName: String?,
        pasteTitle: String = "Paste",
        onPaste: @escaping () -> Void
    ) {
        self._gitURL = gitURL
        self.placeholder = placeholder
        self.providerDisplayName = providerDisplayName
        self.providerLogoName = providerLogoName
        self.pasteTitle = pasteTitle
        self.onPaste = onPaste
    }

    public var body: some View {
        HStack(spacing: 12) {
            HStack {
                TextField(placeholder, text: $gitURL)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .textContentType(.URL)

                if !gitURL.isEmpty,
                   let providerDisplayName,
                   let providerLogoName {
                    ProviderLogoView(
                        name: providerDisplayName,
                        logoName: providerLogoName,
                        iconSize: 18
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .dsField(cornerRadius: DesignSystem.Metrics.cornerRadiusM)

            Button {
                onPaste()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard")
                    Text(pasteTitle)
                }
                .font(.system(size: 12, weight: .medium))
                .dsBadgeBorder(
                    foreground: DesignSystem.Colors.Text.primary,
                    background: DesignSystem.Colors.Component.controlFill,
                    borderColor: DesignSystem.Colors.Component.border.opacity(0.25),
                    borderWidth: 1,
                    horizontalPadding: 12,
                    verticalPadding: 8
                )
            }
            .dsLinkButton()
        }
    }
}
