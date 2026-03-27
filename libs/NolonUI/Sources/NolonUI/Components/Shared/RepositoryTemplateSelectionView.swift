import SwiftUI

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

    public init(
        title: String = "Repository Type",
        options: [RepositoryTemplateOptionItem],
        selectedID: Binding<String>,
        disabled: Bool = false
    ) {
        self.title = title
        self.options = options
        self._selectedID = selectedID
        self.disabled = disabled
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
