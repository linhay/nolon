import SwiftUI
import NolonUIFoundation

public struct ProviderQuotaSectionView: View {
    let data: ProviderQuotaSectionData
    let onRefresh: (() -> Void)?

    public init(data: ProviderQuotaSectionData, onRefresh: (() -> Void)? = nil) {
        self.data = data
        self.onRefresh = onRefresh
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if data.showsHeader {
                header
            }

            if data.isLoading {
                loadingSkeleton
            } else if let errorMessage = data.errorMessage {
                errorState(message: errorMessage)
            } else if !data.rows.isEmpty || data.creditsText != nil {
                quotaList
            } else if data.showsEmptyState {
                emptyState
            }

            footer
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            if data.usesCardChrome {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(DesignSystem.Colors.Background.surface)
            }
        }
        .overlay {
            if data.usesCardChrome {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(DesignSystem.Colors.Background.elevated.opacity(0.3), lineWidth: 1)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Circle()
                .fill(statusColor(for: data.statusPercent))
                .frame(width: 6, height: 6)
                .shadow(color: statusColor(for: data.statusPercent).opacity(0.5), radius: 3)

            Text(data.accountTitle)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.Text.primary)
                .lineLimit(1)

            Spacer()

            if let onRefresh {
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                }
                .buttonStyle(.plain)
                .opacity(data.isLoading ? 0.3 : 0.6)
                .disabled(data.isLoading)
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 8)
    }

    private var quotaList: some View {
        VStack(spacing: 2) {
            ForEach(data.rows) { row in
                ghostRow(row: row)
            }

            if let creditsText = data.creditsText {
                creditsRow(creditsText)
            }
        }
    }

    private func ghostRow(row: ProviderQuotaSectionData.WindowRow) -> some View {
        let color = statusColor(for: row.remainingPercent)

        return ZStack(alignment: .leading) {
            GeometryReader { proxy in
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.opacity(0.15))
                    .frame(
                        width: row.remainingPercent.isInfinite
                            ? proxy.size.width
                            : max(0, proxy.size.width * min(1, max(0, row.remainingPercent / 100.0)))
                    )
            }
            .frame(height: 28)

            HStack(alignment: .center) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(row.title)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.Text.primary)

                    if let resetText = row.resetText, !resetText.isEmpty {
                        Text("· \(resetText)")
                            .font(.system(size: 9))
                            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                    }
                }

                Spacer()

                Text(row.percentText)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
            }
            .padding(.horizontal, 10)
        }
        .frame(height: 28)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func creditsRow(_ creditsText: String) -> some View {
        HStack {
            Text(NSLocalizedString("usage.metric.credits", value: "Credits", comment: "Credits label"))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.Text.primary)

            Spacer()

            Text(creditsText)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(DesignSystem.Colors.primary)
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
    }

    private var footer: some View {
        HStack(alignment: .center) {
            if let planText = data.planText, !planText.isEmpty {
                Text(planText)
                    .font(.system(size: 8, weight: .black))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 4).fill(planColor(planText).opacity(0.15)))
                    .foregroundStyle(planColor(planText))
                    .textCase(.uppercase)
            }

            Spacer()

            if let syncText = data.syncText, !syncText.isEmpty {
                Text(syncText)
                    .font(.system(size: 10))
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
            }
        }
        .padding(.top, 10)
        .padding(.horizontal, 4)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(DesignSystem.Colors.Background.elevated.opacity(0.3))
                .frame(height: 1)
        }
        .padding(.top, 4)
    }

    private func errorState(message: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(NSLocalizedString("usage.error.title", value: "Sync Failed", comment: "Error title"))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.Status.error)
            Text(message)
                .font(.system(size: 9))
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .lineLimit(2)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Colors.Status.error.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var loadingSkeleton: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(0..<2, id: \.self) { index in
                RoundedRectangle(cornerRadius: 6)
                    .fill(DesignSystem.Colors.Background.elevated.opacity(0.28))
                    .frame(height: 28)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(statusColor(for: 100).opacity(index == 0 ? 0.12 : 0.08))
                            .frame(width: index == 0 ? 148 : 116)
                    }
            }
        }
        .redacted(reason: .placeholder)
    }

    private var emptyState: some View {
        Text(NSLocalizedString("usage.monitor.empty.desc", value: "No data available.", comment: "Empty data"))
            .font(.system(size: 10))
            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
            .frame(maxWidth: .infinity, minHeight: 40)
    }

    private func statusColor(for percent: Double) -> Color {
        if percent.isInfinite { return DesignSystem.Colors.Status.success }
        if percent < 10 { return DesignSystem.Colors.Status.error }
        if percent < 25 { return DesignSystem.Colors.Status.warning }
        return DesignSystem.Colors.primary
    }

    private func planColor(_ plan: String) -> Color {
        let value = plan.lowercased()
        if value.contains("pro") || value.contains("enterprise") || value.contains("team") {
            return DesignSystem.Colors.primary
        }
        if value.contains("free") || value.contains("limited") {
            return DesignSystem.Colors.Status.error
        }
        return DesignSystem.Colors.Text.secondary
    }
}
