import SwiftUI
import NolonUIFoundation

public struct AccountPageHeaderView: View {
    let data: AccountPageHeaderData
    let onRefresh: () -> Void
    let onAddAccount: () -> Void

    public init(
        data: AccountPageHeaderData,
        onRefresh: @escaping () -> Void,
        onAddAccount: @escaping () -> Void
    ) {
        self.data = data
        self.onRefresh = onRefresh
        self.onAddAccount = onAddAccount
    }

    public var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(data.title)
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(DesignSystem.Colors.Text.primary)

                Text(data.subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
            }

            Spacer()

            HStack(spacing: 12) {
                Button(action: onRefresh) {
                    HStack(spacing: 6) {
                        if data.isRefreshing {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(data.refreshTitle)
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(DesignSystem.Colors.Component.controlFillSubtle.opacity(0.2))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(DesignSystem.Colors.Component.border.opacity(0.5), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(data.isRefreshing)

                Button(action: onAddAccount) {
                    Text(data.addAccountTitle)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.Text.onAccent)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(DesignSystem.Colors.primary)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
