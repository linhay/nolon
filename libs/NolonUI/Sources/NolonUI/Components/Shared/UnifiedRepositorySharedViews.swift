import Foundation
import NolonUIFoundation
import SwiftUI
import UniformTypeIdentifiers
import WebKit

// MARK: - RepositoryFormCommonViews.swift"

public struct RepositoryReadOnlyFieldView: View {
    public struct Config {
        public var value: String

        public init(value: String) {
            self.value = value
        }
    }

    let value: String

    public init(config: Config) {
        self.value = config.value
    }

    public init(value: String) {
        self.init(config: Config(value: value))
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

    public struct Config {
        public var placeholder: String
        public var providerDisplayName: String?
        public var providerLogoName: String?
        public var pasteTitle: String
        public var onPaste: () -> Void

        public init(
            placeholder: String = "https://github.com/...",
            providerDisplayName: String?,
            providerLogoName: String?,
            pasteTitle: String = "Paste",
            onPaste: @escaping () -> Void
        ) {
            self.placeholder = placeholder
            self.providerDisplayName = providerDisplayName
            self.providerLogoName = providerLogoName
            self.pasteTitle = pasteTitle
            self.onPaste = onPaste
        }
    }

    public init(
        gitURL: Binding<String>,
        config: Config
    ) {
        self._gitURL = gitURL
        self.placeholder = config.placeholder
        self.providerDisplayName = config.providerDisplayName
        self.providerLogoName = config.providerLogoName
        self.pasteTitle = config.pasteTitle
        self.onPaste = config.onPaste
    }

    public init(
        gitURL: Binding<String>,
        placeholder: String = "https://github.com/...",
        providerDisplayName: String?,
        providerLogoName: String?,
        pasteTitle: String = "Paste",
        onPaste: @escaping () -> Void
    ) {
        self.init(
            gitURL: gitURL,
            config: Config(
                placeholder: placeholder,
                providerDisplayName: providerDisplayName,
                providerLogoName: providerLogoName,
                pasteTitle: pasteTitle,
                onPaste: onPaste
            )
        )
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

// MARK: - RepositoryTemplateSelectionView.swift"

public struct RepositoryTemplateOptionItem: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let logoName: String?
    public let iconName: String

    public init(
        id: String,
        title: String,
        logoName: String?,
        iconName: String
    ) {
        self.id = id
        self.title = title
        self.logoName = logoName
        self.iconName = iconName
    }
}

public struct RepositoryTemplateSelectionView: View {
    let title: String
    let options: [RepositoryTemplateOptionItem]
    @Binding var selectedID: String
    let disabled: Bool

    public struct Config {
        public var title: String
        public var options: [RepositoryTemplateOptionItem]
        public var disabled: Bool

        public init(
            title: String = "Repository Type",
            options: [RepositoryTemplateOptionItem],
            disabled: Bool = false
        ) {
            self.title = title
            self.options = options
            self.disabled = disabled
        }
    }

    public init(
        selectedID: Binding<String>,
        config: Config
    ) {
        self.title = config.title
        self.options = config.options
        self._selectedID = selectedID
        self.disabled = config.disabled
    }

    public init(
        title: String = "Repository Type",
        options: [RepositoryTemplateOptionItem],
        selectedID: Binding<String>,
        disabled: Bool = false
    ) {
        self.init(
            selectedID: selectedID,
            config: Config(
                title: title,
                options: options,
                disabled: disabled
            )
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))

            HStack(spacing: 10) {
                ForEach(options) { option in
                    optionButton(option)
                }
            }
        }
    }

    private func optionButton(_ option: RepositoryTemplateOptionItem) -> some View {
        GenericSelectionControl(
            value: option.id,
            selection: $selectedID,
            disabled: disabled
        ) { isSelected in
            HStack(spacing: 8) {
                if let logoName = option.logoName {
                    ProviderLogoView(name: option.title, logoName: logoName, iconSize: 16)
                } else {
                    Image(systemName: option.iconName)
                        .font(.system(size: 14))
                        .foregroundStyle(
                            isSelected
                            ? DesignSystem.Colors.Text.onAccent
                            : DesignSystem.Colors.Text.secondary
                        )
                }

                Text(option.title)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 14)
            .dsBadgeBorder(
                foreground: isSelected ? DesignSystem.Colors.Text.onAccent : DesignSystem.Colors.Text.primary,
                background: isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.Component.controlFill,
                borderColor: isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.Component.border.opacity(0.25),
                borderWidth: 1,
                horizontalPadding: 12,
                verticalPadding: 5
            )
        }
        .dsLinkButton()
    }
}
