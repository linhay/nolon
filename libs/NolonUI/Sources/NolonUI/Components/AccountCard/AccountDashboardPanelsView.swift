import SwiftUI
import NolonUIFoundation

public struct AccountTrendPanelView: View {
    let data: AccountTrendPanelData
    let onSelectWindow: (String) -> Void

    public init(data: AccountTrendPanelData, onSelectWindow: @escaping (String) -> Void) {
        self.data = data
        self.onSelectWindow = onSelectWindow
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(data.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(DesignSystem.Colors.Text.primary)

                Spacer()

                HStack(spacing: 8) {
                    ForEach(data.windowOptions) { option in
                        Button {
                            onSelectWindow(option.id)
                        } label: {
                            Text(option.title)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(option.isSelected ? DesignSystem.Colors.Text.primary : DesignSystem.Colors.Text.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(
                                            option.isSelected
                                                ? DesignSystem.Colors.Component.controlFillSubtle.opacity(0.35)
                                                : DesignSystem.Colors.Component.controlFillSubtle.opacity(0.18)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(data.samples) { item in
                    VStack(spacing: 8) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(DesignSystem.Colors.Component.controlFillSubtle.opacity(0.2))
                                .frame(width: 32, height: 124)
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(DesignSystem.Colors.primary.opacity(item.opacity))
                                .frame(width: 32, height: max(14, 100 * item.heightRatio))
                        }
                        Text(item.label)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(28)
        .frame(maxWidth: .infinity, minHeight: 250, alignment: .topLeading)
        .background(DesignSystem.Colors.Background.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(DesignSystem.Colors.Component.border.opacity(0.5), lineWidth: 1)
        )
    }
}

public struct AccountRankingPanelView: View {
    let data: AccountRankingPanelData

    public init(data: AccountRankingPanelData) {
        self.data = data
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(data.title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.Text.primary)

            ForEach(data.items) { item in
                HStack(spacing: 10) {
                    Text(item.name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                        .frame(width: 78, alignment: .leading)

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule(style: .continuous)
                                .fill(DesignSystem.Colors.Component.border.opacity(0.55))
                            Capsule(style: .continuous)
                                .fill(tintColor(for: item.tone))
                                .frame(width: max(8, proxy.size.width * CGFloat(item.ratio)))
                        }
                    }
                    .frame(height: 6)

                    Text(item.valueText)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.Text.primary)
                        .frame(width: 46, alignment: .trailing)
                }
                .frame(height: 16)
            }
        }
        .padding(28)
        .frame(width: 320, alignment: .topLeading)
        .frame(minHeight: 250, alignment: .topLeading)
        .background(DesignSystem.Colors.Background.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(DesignSystem.Colors.Component.border.opacity(0.5), lineWidth: 1)
        )
    }

    private func tintColor(for tone: AccountProviderRankingItemData.Tone) -> Color {
        switch tone {
        case .primary:
            return DesignSystem.Colors.primary
        case .secondary:
            return DesignSystem.Colors.secondary
        case .success:
            return DesignSystem.Colors.Status.success
        case .warning:
            return DesignSystem.Colors.Status.warning
        }
    }
}
