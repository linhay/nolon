import SwiftUI
import NolonUIFoundation

public struct AccountSectionHeaderView: View {
    let data: AccountSectionHeaderData

    public init(data: AccountSectionHeaderData) {
        self.data = data
    }

    public var body: some View {
        switch data.style {
        case .section(let section):
            sectionHeader(section)
        case .provider(let provider):
            providerHeader(provider)
        }
    }

    private func sectionHeader(_ section: AccountSectionHeaderData.Section) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(accent(for: section.tone))
                .frame(width: 28, height: 28)
                .overlay(
                    Text(section.shortLabel)
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(.white)
                )

            Text(section.title)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(DesignSystem.Colors.Text.primary)

            Spacer()

            Text(section.accountCountText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
        }
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DesignSystem.Colors.Component.border.opacity(0.35))
                .frame(height: 1)
        }
    }

    private func providerHeader(_ provider: AccountSectionHeaderData.Provider) -> some View {
        HStack(spacing: 10) {
            if let logoName = provider.logoName {
                ProviderLogoView(
                    name: provider.name,
                    logoName: logoName,
                    iconSize: 16
                )
            } else {
                Circle()
                    .fill(DesignSystem.Colors.primary.opacity(0.9))
                    .frame(width: 8, height: 8)
            }

            Text(provider.name)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.Text.primary)

            Spacer()
        }
    }

    private func accent(for tone: AccountSectionHeaderData.SectionTone) -> Color {
        switch tone {
        case .primary:
            return DesignSystem.Colors.primary
        case .secondary:
            return DesignSystem.Colors.secondary
        case .success:
            return DesignSystem.Colors.Status.success
        }
    }
}
