import SwiftUI
import NolonUIFoundation

struct AccountUsageContentCard: View {
    let presentation: AccountCardPresentation
    let header: AccountSummaryCardHeaderModel
    let points: [AccountUsageChartPoint]
    let metrics: [AccountUsageMetric]

    init(
        presentation: AccountCardPresentation = .neutral,
        header: AccountSummaryCardHeaderModel = .init(
            eyebrow: "Analytics",
            title: "Token Trend (7d)",
            subtitle: "Daily usage overview",
            meta: "Updated 3m ago",
            badge: .init(text: "LIVE", tone: .active)
        ),
        points: [AccountUsageChartPoint] = [
            .init(day: "Mon", input: 0.48, output: 0.26),
            .init(day: "Tue", input: 0.62, output: 0.35),
            .init(day: "Wed", input: 0.55, output: 0.32),
            .init(day: "Thu", input: 0.82, output: 0.41),
            .init(day: "Fri", input: 0.74, output: 0.38),
            .init(day: "Sat", input: 0.44, output: 0.21),
            .init(day: "Sun", input: 0.69, output: 0.33),
        ],
        metrics: [AccountUsageMetric] = [
            .init(title: "Input", value: "1.42M"),
            .init(title: "Output", value: "0.68M"),
            .init(title: "Total", value: "2.10M"),
        ]
    ) {
        self.presentation = presentation
        self.header = header
        self.points = points
        self.metrics = metrics
    }

    var body: some View {
        AccountSummaryContentCard(
            presentation: presentation,
            header: header,
            showsDetailsSection: true,
            showsActionsSection: true
        ) {
            AccountUsageChartModule(points: points)
        } details: {
            AccountUsageMetricRow(metrics: metrics)
        } actions: {
            HStack(spacing: 8) {
                Button("7D") {}
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                Button("30D") {}
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("Refresh") {}
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }
}

struct AccountUsageContentCardScene: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Usage Chart Module")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)

            AccountUsageContentCard()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@MainActor
private struct AccountUsageContentCardPreview: View {
    var body: some View {
        ScrollView(.vertical) {
            AccountUsageContentCardScene()
                .frame(width: 740, height: 2940, alignment: .topLeading)
                .padding(PreviewLayoutTokens.Spacing.page)
                .background(DesignSystem.Colors.Background.canvas)
        }
        .frame(width: 740, height: 2940, alignment: .topLeading)
    }
}

#Preview("Account Card / Chart") {
    AccountUsageContentCardPreview()
}
