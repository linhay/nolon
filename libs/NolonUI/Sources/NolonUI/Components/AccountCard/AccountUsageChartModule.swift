import SwiftUI

struct AccountUsageChartPoint: Identifiable {
    let id = UUID()
    let day: String
    let input: CGFloat
    let output: CGFloat
}

struct AccountUsageMetric: Identifiable {
    let id = UUID()
    let title: String
    let value: String
}

struct AccountUsageChartModule: View {
    @State private var viewModel = AccountUsageChartModuleViewModel()
    let points: [AccountUsageChartPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: PreviewLayoutTokens.Spacing.row) {
            HStack(spacing: 12) {
                legendDot("Input", color: DesignSystem.Colors.primary.opacity(0.8))
                legendDot("Output", color: DesignSystem.Colors.Status.warning.opacity(0.85))
                Spacer(minLength: 0)
            }

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(points) { point in
                    VStack(spacing: 4) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(DesignSystem.Colors.Component.controlFillSubtle)
                                .frame(width: 12, height: 42)

                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(DesignSystem.Colors.primary.opacity(0.8))
                                .frame(width: 12, height: max(2, point.input * 42))

                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(DesignSystem.Colors.Status.warning.opacity(0.85))
                                .frame(width: 6, height: max(2, point.output * 42))
                        }

                        Text(point.day)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func legendDot(_ title: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(title)
                .font(.caption2)
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
        }
    }
}

struct AccountUsageMetricRow: View {
    @State private var viewModel = AccountUsageMetricRowViewModel()
    let metrics: [AccountUsageMetric]

    var body: some View {
        HStack(spacing: PreviewLayoutTokens.Spacing.group) {
            ForEach(metrics) { metric in
                metricChip(title: metric.title, value: metric.value)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metricChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(DesignSystem.Colors.Text.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(DesignSystem.Colors.Component.controlFillSubtle)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusM, style: .continuous))
    }
}
