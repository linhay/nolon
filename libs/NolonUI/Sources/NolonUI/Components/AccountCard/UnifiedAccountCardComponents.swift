import NolonUIFoundation
import SwiftUI

// MARK: - AccountPageHeaderView

public struct AccountPageHeaderView: View {
    public struct Config {
        public var data: AccountPageHeaderData
        public var onRefresh: () -> Void
        public var onAddAccount: () -> Void

        public init(
            data: AccountPageHeaderData,
            onRefresh: @escaping () -> Void,
            onAddAccount: @escaping () -> Void
        ) {
            self.data = data
            self.onRefresh = onRefresh
            self.onAddAccount = onAddAccount
        }
    }

    let data: AccountPageHeaderData
    let onRefresh: () -> Void
    let onAddAccount: () -> Void

    public init(config: Config) {
        self.data = config.data
        self.onRefresh = config.onRefresh
        self.onAddAccount = config.onAddAccount
    }

    public init(
        data: AccountPageHeaderData,
        onRefresh: @escaping () -> Void,
        onAddAccount: @escaping () -> Void
    ) {
        self.init(config: Config(data: data, onRefresh: onRefresh, onAddAccount: onAddAccount))
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

// MARK: - AccountSummaryCard

public struct AccountSummaryCard<Content: View>: View {
    public struct Config {
        public var presentation: AccountCardPresentation
        public var contentInsets: EdgeInsets
        public var content: () -> Content

        public init(
            presentation: AccountCardPresentation = .neutral,
            contentInsets: EdgeInsets = EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12),
            @ViewBuilder content: @escaping () -> Content
        ) {
            self.presentation = presentation
            self.contentInsets = contentInsets
            self.content = content
        }
    }

    @State private var viewModel = AccountSummaryCardViewModel()
    private let presentation: AccountCardPresentation
    private let contentInsets: EdgeInsets
    @ViewBuilder private var content: Content

    public init(config: Config) {
        self.presentation = config.presentation
        self.contentInsets = config.contentInsets
        self.content = config.content()
    }

    public init(
        presentation: AccountCardPresentation = .neutral,
        contentInsets: EdgeInsets = EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12),
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            config: Config(
                presentation: presentation,
                contentInsets: contentInsets,
                content: content
            )
        )
    }

    public var body: some View {
        content
            .padding(contentInsets)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(backgroundShape)
            .overlay(borderShape)
            .overlay(alignment: .topTrailing) {
                if presentation.showsSelectionBadge {
                    selectionBadge
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusL, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusL, style: .continuous))
            .animation(DesignSystem.Animations.standard, value: presentation.selectionStyle)
    }

    private var backgroundShape: some View {
        RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusL, style: .continuous)
            .fill(backgroundColor)
            .shadow(
                color: presentation.selectionStyle == .active ? DesignSystem.Colors.primary.opacity(0.12) : Color.clear,
                radius: 8,
                x: 0,
                y: 4
            )
    }

    private var borderShape: some View {
        RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusL, style: .continuous)
            .strokeBorder(borderColor, style: borderStyle)
    }

    private var selectionBadge: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(DesignSystem.Colors.primary)
            .background(Circle().fill(Color.white))
            .padding(10)
            .transition(.scale.combined(with: .opacity))
    }

    private var backgroundColor: Color {
        switch presentation.selectionStyle {
        case .neutral:
            return DesignSystem.Colors.Background.elevated
        case .active, .pending, .transitioning, .selected:
            return DesignSystem.Colors.primary.opacity(Self.backgroundOpacity(for: presentation.selectionStyle))
        }
    }

    private var borderColor: Color {
        switch presentation.selectionStyle {
        case .neutral:
            return DesignSystem.Colors.Component.border.opacity(0.5)
        case .active:
            return DesignSystem.Colors.primary
        case .pending:
            return DesignSystem.Colors.primary.opacity(0.6)
        case .transitioning:
            return DesignSystem.Colors.primary.opacity(0.7)
        case .selected:
            return DesignSystem.Colors.primary.opacity(0.8)
        }
    }

    private var borderStyle: StrokeStyle {
        StrokeStyle(
            lineWidth: Self.borderLineWidth(for: presentation.selectionStyle),
            dash: Self.borderDash(for: presentation.selectionStyle)
        )
    }

    public static func backgroundOpacity(for selectionStyle: AccountCardSelectionStyle) -> Double {
        switch selectionStyle {
        case .neutral: return 0
        case .active: return 0.08
        case .pending: return 0.04
        case .transitioning: return 0.09
        case .selected: return 0.06
        }
    }

    public static func borderLineWidth(for selectionStyle: AccountCardSelectionStyle) -> CGFloat {
        switch selectionStyle {
        case .active: return 2.0
        case .transitioning: return 2.0
        case .selected: return 1.5
        case .neutral, .pending: return 1.0
        }
    }

    public static func borderDash(for selectionStyle: AccountCardSelectionStyle) -> [CGFloat] {
        switch selectionStyle {
        case .pending: return [5, 4]
        case .neutral, .active, .transitioning, .selected: return []
        }
    }
}

@MainActor


// MARK: - AccountSummaryContentCard

private enum AccountSummaryContentCardLayout {
    static let cardSpacing: CGFloat = 14
    static let sectionSpacing: CGFloat = 10
}

public struct AccountSummaryContentCard<Body: View, Details: View, Actions: View>: View {
    public struct Config {
        public var presentation: AccountCardPresentation
        public var header: AccountSummaryCardHeaderModel
        public var showsDetailsSection: Bool
        public var showsActionsSection: Bool
        public var body: () -> Body
        public var details: () -> Details
        public var actions: () -> Actions

        public init(
            presentation: AccountCardPresentation = .neutral,
            header: AccountSummaryCardHeaderModel,
            showsDetailsSection: Bool = false,
            showsActionsSection: Bool = false,
            @ViewBuilder body: @escaping () -> Body,
            @ViewBuilder details: @escaping () -> Details = { EmptyView() },
            @ViewBuilder actions: @escaping () -> Actions = { EmptyView() }
        ) {
            self.presentation = presentation
            self.header = header
            self.showsDetailsSection = showsDetailsSection
            self.showsActionsSection = showsActionsSection
            self.body = body
            self.details = details
            self.actions = actions
        }
    }

    @State private var viewModel = AccountSummaryContentCardViewModel()
    private let presentation: AccountCardPresentation
    private let header: AccountSummaryCardHeaderModel
    private let showsDetailsSection: Bool
    private let showsActionsSection: Bool
    @ViewBuilder private var bodyContent: Body
    @ViewBuilder private var detailsContent: Details
    @ViewBuilder private var actionsContent: Actions

    public init(config: Config) {
        self.presentation = config.presentation
        self.header = config.header
        self.showsDetailsSection = config.showsDetailsSection
        self.showsActionsSection = config.showsActionsSection
        self.bodyContent = config.body()
        self.detailsContent = config.details()
        self.actionsContent = config.actions()
    }

    public init(
        presentation: AccountCardPresentation = .neutral,
        header: AccountSummaryCardHeaderModel,
        showsDetailsSection: Bool = false,
        showsActionsSection: Bool = false,
        @ViewBuilder body: @escaping () -> Body,
        @ViewBuilder details: @escaping () -> Details = { EmptyView() },
        @ViewBuilder actions: @escaping () -> Actions = { EmptyView() }
    ) {
        self.init(
            config: Config(
                presentation: presentation,
                header: header,
                showsDetailsSection: showsDetailsSection,
                showsActionsSection: showsActionsSection,
                body: body,
                details: details,
                actions: actions
            )
        )
    }

    public var body: some View {
        AccountSummaryCard(presentation: presentation) {
            VStack(alignment: .leading, spacing: AccountSummaryContentCardLayout.cardSpacing) {
                headerSection
                bodySection

                if showsDetailsSection {
                    supplementarySection(detailsContent)
                }

                if showsActionsSection {
                    supplementarySection(actionsContent)
                }
            }
        }
    }

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                if let eyebrow = header.eyebrow, !eyebrow.isEmpty {
                    Text(eyebrow)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                        .textCase(.uppercase)
                }

                Text(header.title)
                    .font(.headline)
                    .foregroundStyle(DesignSystem.Colors.Text.primary)
                    .lineLimit(1)
                    .layoutPriority(2)

                if let subtitle = header.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            if header.badge != nil || (header.meta?.isEmpty == false) {
                VStack(alignment: .trailing, spacing: 6) {
                    if let badge = header.badge {
                        AccountSummaryCardBadge(badge: badge)
                    }

                    if let meta = header.meta, !meta.isEmpty {
                        Text(meta)
                            .font(.caption2)
                            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    private var bodySection: some View {
        bodyContent
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func supplementarySection<Content: View>(_ content: Content) -> some View {
        VStack(alignment: .leading, spacing: AccountSummaryContentCardLayout.sectionSpacing) {
            sectionDivider
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(DesignSystem.Colors.Component.border.opacity(0.35))
            .frame(height: 1)
    }
}

private struct AccountSummaryCardBadge: View {
    let badge: AccountSummaryCardBadgeModel

    var body: some View {
        Text(badge.text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(backgroundColor)
            )
            .foregroundStyle(foregroundColor)
    }

    private var backgroundColor: Color {
        switch badge.tone {
        case .neutral:
            return DesignSystem.Colors.Component.controlFillSubtle
        case .active:
            return DesignSystem.Colors.primary.opacity(0.2)
        case .warning:
            return DesignSystem.Colors.Status.warning.opacity(0.18)
        }
    }

    private var foregroundColor: Color {
        switch badge.tone {
        case .neutral:
            return DesignSystem.Colors.Text.secondary
        case .active:
            return DesignSystem.Colors.primary
        case .warning:
            return DesignSystem.Colors.Status.warning
        }
    }
}

// MARK: - AccountDashboardSectionView

public struct AccountDashboardSectionView<TrendContent: View, RankingContent: View>: View {
    public struct Config {
        public var dividerColor: Color
        public var trendContent: () -> TrendContent
        public var rankingContent: () -> RankingContent

        public init(
            dividerColor: Color = DesignSystem.Colors.Component.border.opacity(0.35),
            @ViewBuilder trendContent: @escaping () -> TrendContent,
            @ViewBuilder rankingContent: @escaping () -> RankingContent
        ) {
            self.dividerColor = dividerColor
            self.trendContent = trendContent
            self.rankingContent = rankingContent
        }
    }

    private let dividerColor: Color
    private let trendContent: () -> TrendContent
    private let rankingContent: () -> RankingContent

    public init(config: Config) {
        self.dividerColor = config.dividerColor
        self.trendContent = config.trendContent
        self.rankingContent = config.rankingContent
    }

    public init(
        dividerColor: Color = DesignSystem.Colors.Component.border.opacity(0.35),
        @ViewBuilder trendContent: @escaping () -> TrendContent,
        @ViewBuilder rankingContent: @escaping () -> RankingContent
    ) {
        self.init(
            config: Config(
                dividerColor: dividerColor,
                trendContent: trendContent,
                rankingContent: rankingContent
            )
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            Rectangle()
                .fill(dividerColor)
                .frame(height: 1)

            HStack(alignment: .top, spacing: 30) {
                trendContent()
                    .frame(maxWidth: .infinity)
                rankingContent()
                    .frame(width: 320)
            }
        }
        .padding(.top, 4)
    }
}

// MARK: - AccountDashboardPanelsView

public struct AccountTrendPanelView: View {
    public struct Config {
        public var data: AccountTrendPanelData
        public var onSelectWindow: (String) -> Void

        public init(
            data: AccountTrendPanelData,
            onSelectWindow: @escaping (String) -> Void
        ) {
            self.data = data
            self.onSelectWindow = onSelectWindow
        }
    }

    let data: AccountTrendPanelData
    let onSelectWindow: (String) -> Void

    public init(config: Config) {
        self.data = config.data
        self.onSelectWindow = config.onSelectWindow
    }

    public init(data: AccountTrendPanelData, onSelectWindow: @escaping (String) -> Void) {
        self.init(config: Config(data: data, onSelectWindow: onSelectWindow))
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
    public struct Config {
        public var data: AccountRankingPanelData

        public init(data: AccountRankingPanelData) {
            self.data = data
        }
    }

    let data: AccountRankingPanelData

    public init(config: Config) {
        self.data = config.data
    }

    public init(data: AccountRankingPanelData) {
        self.init(config: Config(data: data))
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

// MARK: - AccountUsageContentCardScene

struct AccountUsageContentCard: View {
    @State private var viewModel = AccountUsageContentCardViewModel()
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
    @State private var viewModel = AccountUsageContentCardSceneViewModel()
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


// MARK: - AccountUsageChartModule

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

// MARK: - AccountQuotaModule

public struct AccountQuotaRow: Identifiable {
    public let id = UUID()
    public let title: String
    public let remainingText: String
    public let progress: CGFloat
    public let meta: String

    public init(title: String, remainingText: String, progress: CGFloat, meta: String) {
        self.title = title
        self.remainingText = remainingText
        self.progress = progress
        self.meta = meta
    }
}

public enum AccountQuotaStyle {
    public static func color(for progress: CGFloat) -> Color {
        if progress <= 0.1 {
            return DesignSystem.Colors.Status.error
        }
        if progress <= 0.25 {
            return DesignSystem.Colors.Status.warning
        }
        return DesignSystem.Colors.primary
    }
}

public struct AccountQuotaModule: View {
    public struct Config {
        public var rows: [AccountQuotaRow]
        public var creditsText: String

        public init(rows: [AccountQuotaRow], creditsText: String) {
            self.rows = rows
            self.creditsText = creditsText
        }
    }

    @State private var viewModel = AccountQuotaModuleViewModel()
    public let rows: [AccountQuotaRow]
    public let creditsText: String

    public init(config: Config) {
        self.rows = config.rows
        self.creditsText = config.creditsText
    }

    public init(rows: [AccountQuotaRow], creditsText: String) {
        self.init(config: Config(rows: rows, creditsText: creditsText))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PreviewLayoutTokens.Spacing.row) {
            ForEach(rows) { row in
                quotaRow(row)
            }
            HStack {
                Text("Credits")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                Spacer(minLength: 0)
                Text(creditsText)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DesignSystem.Colors.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func quotaRow(_ row: AccountQuotaRow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(row.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                Text(row.meta)
                    .font(.caption2)
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                Spacer(minLength: 0)
                Text(row.remainingText)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AccountQuotaStyle.color(for: row.progress))
            }
            GeometryReader { proxy in
                let totalWidth = proxy.size.width
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(DesignSystem.Colors.Component.controlFill)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(AccountQuotaStyle.color(for: row.progress).opacity(0.22))
                            .frame(width: max(0, min(1, row.progress)) * totalWidth)
                    }
            }
            .frame(height: 8)
        }
    }
}

public struct AccountInlineQuotaProgress: View {
    public struct Config {
        public var progress: CGFloat
        public var percentText: String

        public init(progress: CGFloat, percentText: String) {
            self.progress = progress
            self.percentText = percentText
        }
    }

    @State private var viewModel = AccountInlineQuotaProgressViewModel()
    public let progress: CGFloat
    public let percentText: String

    public init(config: Config) {
        self.progress = config.progress
        self.percentText = config.percentText
    }

    public init(progress: CGFloat, percentText: String) {
        self.init(config: Config(progress: progress, percentText: percentText))
    }

    public var body: some View {
        HStack(spacing: 8) {
            GeometryReader { proxy in
                let totalWidth = proxy.size.width
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(DesignSystem.Colors.Component.controlFill)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(AccountQuotaStyle.color(for: progress).opacity(0.22))
                            .frame(width: max(0, min(1, progress)) * totalWidth)
                    }
            }
            .frame(height: 8)

            Text(percentText)
                .font(.caption2.weight(.bold))
                .foregroundStyle(AccountQuotaStyle.color(for: progress))
        }
    }
}

// MARK: - AccountStateModule

public struct AccountErrorStateModule: View {
    public struct Config {
        public var title: String
        public var message: String

        public init(
            title: String = NSLocalizedString("usage.error.title", value: "Sync Failed", comment: "Error title"),
            message: String
        ) {
            self.title = title
            self.message = message
        }
    }

    @State private var viewModel = AccountErrorStateModuleViewModel()
    public let title: String
    public let message: String

    public init(config: Config) {
        self.title = config.title
        self.message = config.message
    }

    public init(
        title: String = NSLocalizedString("usage.error.title", value: "Sync Failed", comment: "Error title"),
        message: String
    ) {
        self.init(config: Config(title: title, message: message))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DesignSystem.Colors.Status.error)
            Text(message)
                .font(.caption2)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Colors.Status.error.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusM, style: .continuous))
    }
}

public struct AccountLoadingStateModule: View {
    @State private var viewModel = AccountLoadingStateModuleViewModel()

    public struct Config {
        public init() {}
    }

    public init(config: Config) {}

    public init() {
        self.init(config: Config())
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PreviewLayoutTokens.Spacing.row) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(DesignSystem.Colors.Component.controlFill)
                .frame(height: 12)
                .frame(maxWidth: 210)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(DesignSystem.Colors.Component.controlFill)
                .frame(height: 12)
                .frame(maxWidth: 160)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(DesignSystem.Colors.Component.controlFill)
                .frame(height: 12)
                .frame(maxWidth: 240)
        }
        .redacted(reason: .placeholder)
    }
}

public struct AccountEmptyStateModule: View {
    public struct Config {
        public var text: String

        public init(
            text: String = NSLocalizedString("usage.monitor.empty.desc", value: "No data available.", comment: "Empty data")
        ) {
            self.text = text
        }
    }

    @State private var viewModel = AccountEmptyStateModuleViewModel()
    public let text: String

    public init(config: Config) {
        self.text = config.text
    }

    public init(
        text: String = NSLocalizedString("usage.monitor.empty.desc", value: "No data available.", comment: "Empty data")
    ) {
        self.init(config: Config(text: text))
    }

    public var body: some View {
        HStack(spacing: PreviewLayoutTokens.Spacing.row) {
            Image(systemName: "tray")
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
            Text(text)
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
            Spacer(minLength: 0)
        }
        .padding(PreviewLayoutTokens.Spacing.row)
        .background(DesignSystem.Colors.Component.controlFillSubtle)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusM, style: .continuous))
    }
}

// MARK: - AccountListModeModule

public struct AccountListModeUsageWindow: Identifiable {
    public let id: String
    public let title: String
    public let progress: CGFloat
    public let percentText: String

    public init(id: String, title: String, progress: CGFloat, percentText: String) {
        self.id = id
        self.title = title
        self.progress = progress
        self.percentText = percentText
    }

    public init(title: String, progress: CGFloat, percentText: String) {
        self.id = UUID().uuidString
        self.title = title
        self.progress = progress
        self.percentText = percentText
    }
}

public struct AccountListModeRowAction: Identifiable {
    public let id: String
    public let title: String
    public let systemImage: String?
    public let role: ButtonRole?
    public let isEnabled: Bool

    public init(
        id: String,
        title: String,
        systemImage: String? = nil,
        role: ButtonRole? = nil,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.isEnabled = isEnabled
    }
}

public struct AccountListModeItem: Identifiable {
    public let id: String
    public let presentation: AccountCardPresentation
    public let header: AccountSummaryCardHeaderModel
    public let usageWindows: [AccountListModeUsageWindow]
    public let menuActions: [AccountListModeRowAction]
    public let isLoadingPlaceholder: Bool

    public init(
        id: String,
        presentation: AccountCardPresentation,
        header: AccountSummaryCardHeaderModel,
        usageWindows: [AccountListModeUsageWindow],
        menuActions: [AccountListModeRowAction] = [],
        isLoadingPlaceholder: Bool = false
    ) {
        self.id = id
        self.presentation = presentation
        self.header = header
        self.usageWindows = usageWindows
        self.menuActions = menuActions
        self.isLoadingPlaceholder = isLoadingPlaceholder
    }

    public init(
        presentation: AccountCardPresentation,
        header: AccountSummaryCardHeaderModel,
        usageWindows: [AccountListModeUsageWindow],
        menuActions: [AccountListModeRowAction] = [],
        isLoadingPlaceholder: Bool = false
    ) {
        self.init(
            id: UUID().uuidString,
            presentation: presentation,
            header: header,
            usageWindows: usageWindows,
            menuActions: menuActions,
            isLoadingPlaceholder: isLoadingPlaceholder
        )
    }

    public init(
        id: String,
        presentation: AccountCardPresentation,
        header: AccountSummaryCardHeaderModel,
        progress: CGFloat,
        percentText: String,
        menuActions: [AccountListModeRowAction] = [],
        isLoadingPlaceholder: Bool = false
    ) {
        self.init(
            id: id,
            presentation: presentation,
            header: header,
            usageWindows: [.init(title: "Session", progress: progress, percentText: percentText)],
            menuActions: menuActions,
            isLoadingPlaceholder: isLoadingPlaceholder
        )
    }

    public init(
        presentation: AccountCardPresentation,
        header: AccountSummaryCardHeaderModel,
        progress: CGFloat,
        percentText: String,
        menuActions: [AccountListModeRowAction] = [],
        isLoadingPlaceholder: Bool = false
    ) {
        self.init(
            id: UUID().uuidString,
            presentation: presentation,
            header: header,
            progress: progress,
            percentText: percentText,
            menuActions: menuActions,
            isLoadingPlaceholder: isLoadingPlaceholder
        )
    }
}

public struct AccountListModeSection: Identifiable {
    public let id: String
    public let title: String?
    public let items: [AccountListModeItem]

    public init(id: String = UUID().uuidString, title: String? = nil, items: [AccountListModeItem]) {
        self.id = id
        self.title = title
        self.items = items
    }
}

public struct AccountListModeModule: View {
    public struct Config {
        public var title: String?
        public var sections: [AccountListModeSection]
        public var accountColumnTitle: String
        public var planColumnTitle: String
        public var usageColumnTitle: String
        public var planColumnWidth: CGFloat
        public var usageColumnWidth: CGFloat
        public var onTap: ((String) -> Void)?
        public var onMenuAction: ((String, String) -> Void)?

        public init(
            title: String? = nil,
            sections: [AccountListModeSection],
            accountColumnTitle: String = NSLocalizedString("codex.accounts.list.header.account", value: "Account", comment: "Account list table account column"),
            planColumnTitle: String = NSLocalizedString("codex.accounts.list.header.plan", value: "Plan", comment: "Account list table plan column"),
            usageColumnTitle: String = NSLocalizedString("codex.accounts.list.header.usage", value: "Usage", comment: "Account list table usage column"),
            planColumnWidth: CGFloat = 90,
            usageColumnWidth: CGFloat = 220,
            onTap: ((String) -> Void)? = nil,
            onMenuAction: ((String, String) -> Void)? = nil
        ) {
            self.title = title
            self.sections = sections
            self.accountColumnTitle = accountColumnTitle
            self.planColumnTitle = planColumnTitle
            self.usageColumnTitle = usageColumnTitle
            self.planColumnWidth = planColumnWidth
            self.usageColumnWidth = usageColumnWidth
            self.onTap = onTap
            self.onMenuAction = onMenuAction
        }
    }

    @State private var viewModel = AccountListModeModuleViewModel()
    let title: String?
    let sections: [AccountListModeSection]
    let accountColumnTitle: String
    let planColumnTitle: String
    let usageColumnTitle: String
    let planColumnWidth: CGFloat
    let usageColumnWidth: CGFloat
    let onTap: ((String) -> Void)?
    let onMenuAction: ((String, String) -> Void)?

    public init(config: Config) {
        self.title = config.title
        self.sections = config.sections
        self.accountColumnTitle = config.accountColumnTitle
        self.planColumnTitle = config.planColumnTitle
        self.usageColumnTitle = config.usageColumnTitle
        self.planColumnWidth = config.planColumnWidth
        self.usageColumnWidth = config.usageColumnWidth
        self.onTap = config.onTap
        self.onMenuAction = config.onMenuAction
    }

    public init(
        title: String? = nil,
        items: [AccountListModeItem]
    ) {
        self.init(
            config: Config(
                title: title,
                sections: [.init(items: items)]
            )
        )
    }

    public init(
        title: String? = nil,
        sections: [AccountListModeSection],
        accountColumnTitle: String = NSLocalizedString("codex.accounts.list.header.account", value: "Account", comment: "Account list table account column"),
        planColumnTitle: String = NSLocalizedString("codex.accounts.list.header.plan", value: "Plan", comment: "Account list table plan column"),
        usageColumnTitle: String = NSLocalizedString("codex.accounts.list.header.usage", value: "Usage", comment: "Account list table usage column"),
        planColumnWidth: CGFloat = 90,
        usageColumnWidth: CGFloat = 220,
        onTap: ((String) -> Void)? = nil,
        onMenuAction: ((String, String) -> Void)? = nil
    ) {
        self.init(
            config: Config(
                title: title,
                sections: sections,
                accountColumnTitle: accountColumnTitle,
                planColumnTitle: planColumnTitle,
                usageColumnTitle: usageColumnTitle,
                planColumnWidth: planColumnWidth,
                usageColumnWidth: usageColumnWidth,
                onTap: onTap,
                onMenuAction: onMenuAction
            )
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PreviewLayoutTokens.Spacing.group) {
            if let title, !title.isEmpty {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
            }

            VStack(alignment: .leading, spacing: 0) {
                tableHeader

                ForEach(Array(sections.enumerated()), id: \.element.id) { sectionIndex, section in
                    if let title = section.title, !title.isEmpty {
                        Text(title)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                            .padding(.top, sectionIndex == 0 ? 0 : PreviewLayoutTokens.Spacing.row)
                            .padding(.bottom, 4)
                    }

                    ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                        tableRow(item)
                            .redacted(reason: item.isLoadingPlaceholder ? .placeholder : [])

                        if index < section.items.count - 1 {
                            Divider()
                                .overlay(DesignSystem.Colors.Component.border.opacity(0.25))
                        }
                    }
                }
            }
            .padding(.horizontal, PreviewLayoutTokens.Spacing.group)
            .padding(.vertical, PreviewLayoutTokens.Spacing.row)
            .background(DesignSystem.Colors.Background.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusL, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusL, style: .continuous)
                    .stroke(DesignSystem.Colors.Component.border.opacity(0.3), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var showsPlanColumn: Bool {
        let normalizedTitle = planColumnTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return planColumnWidth > 0 && !normalizedTitle.isEmpty
    }

    private var tableHeader: some View {
        HStack(spacing: PreviewLayoutTokens.Spacing.group) {
            Text(accountColumnTitle)
                .frame(maxWidth: .infinity, alignment: .leading)
            if showsPlanColumn {
                Text(planColumnTitle)
                    .frame(width: planColumnWidth, alignment: .leading)
            }
            Text(usageColumnTitle)
                .frame(width: usageColumnWidth, alignment: .leading)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
        .padding(.vertical, PreviewLayoutTokens.Spacing.row)
    }

    @ViewBuilder
    private func tableRow(_ item: AccountListModeItem) -> some View {
        let row = HStack(spacing: PreviewLayoutTokens.Spacing.group) {
            HStack(alignment: .top, spacing: 8) {
                Circle()
                    .fill(statusColor(for: item))
                    .frame(width: 6, height: 6)
                    .padding(.top, 3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.header.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DesignSystem.Colors.Text.primary)
                        .lineLimit(1)
                    if let secondary = accountSecondaryText(for: item) {
                        Text(secondary)
                            .font(.caption2)
                            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if showsPlanColumn {
                Text(planText(for: item))
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    .lineLimit(1)
                    .frame(width: planColumnWidth, alignment: .leading)
            }

            usageWindowsColumn(item.usageWindows)
                .frame(width: usageColumnWidth, alignment: .leading)
        }
        .padding(.vertical, 10)

        let decoratedRow = row
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(rowBackgroundColor(for: item))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(rowBorderColor(for: item), lineWidth: rowBorderLineWidth(for: item))
            )

        if let onTap {
            if item.menuActions.isEmpty {
                decoratedRow
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onTap(item.id)
                    }
            } else {
                decoratedRow
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onTap(item.id)
                    }
                    .contextMenu {
                        ForEach(item.menuActions) { action in
                            Button(role: action.role) {
                                onMenuAction?(item.id, action.id)
                            } label: {
                                if let symbol = action.systemImage, !symbol.isEmpty {
                                    Label(action.title, systemImage: symbol)
                                } else {
                                    Text(action.title)
                                }
                            }
                            .disabled(!action.isEnabled)
                        }
                    }
            }
        } else if item.menuActions.isEmpty {
            decoratedRow
        } else {
            decoratedRow.contextMenu {
                ForEach(item.menuActions) { action in
                    Button(role: action.role) {
                        onMenuAction?(item.id, action.id)
                    } label: {
                        if let symbol = action.systemImage, !symbol.isEmpty {
                            Label(action.title, systemImage: symbol)
                        } else {
                            Text(action.title)
                        }
                    }
                    .disabled(!action.isEnabled)
                }
            }
        }
    }

    private func rowBackgroundColor(for item: AccountListModeItem) -> Color {
        switch item.presentation.selectionStyle {
        case .active:
            return DesignSystem.Colors.primary.opacity(0.12)
        case .pending:
            return DesignSystem.Colors.Status.warning.opacity(0.14)
        case .transitioning:
            return DesignSystem.Colors.primary.opacity(0.16)
        case .selected:
            return DesignSystem.Colors.primary.opacity(0.10)
        case .neutral:
            return Color.clear
        }
    }

    private func rowBorderColor(for item: AccountListModeItem) -> Color {
        switch item.presentation.selectionStyle {
        case .active:
            return DesignSystem.Colors.primary.opacity(0.45)
        case .pending:
            return DesignSystem.Colors.Status.warning.opacity(0.45)
        case .transitioning:
            return DesignSystem.Colors.primary.opacity(0.55)
        case .selected:
            return DesignSystem.Colors.primary.opacity(0.35)
        case .neutral:
            return Color.clear
        }
    }

    private func rowBorderLineWidth(for item: AccountListModeItem) -> CGFloat {
        switch item.presentation.selectionStyle {
        case .neutral:
            return 0
        case .active, .pending, .transitioning, .selected:
            return 1
        }
    }

    private func usageWindowsColumn(_ windows: [AccountListModeUsageWindow]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(windows) { window in
                HStack(spacing: 6) {
                    Text(window.title)
                        .font(.caption2)
                        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                        .frame(width: 46, alignment: .leading)
                    AccountInlineQuotaProgress(progress: window.progress, percentText: window.percentText)
                }
            }
        }
    }

    private func accountSecondaryText(for item: AccountListModeItem) -> String? {
        let eyebrow = item.header.eyebrow?.trimmingCharacters(in: .whitespacesAndNewlines)
        let meta = item.header.meta?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let eyebrow, !eyebrow.isEmpty, let meta, !meta.isEmpty {
            return "\(eyebrow) • \(meta)"
        }
        if let eyebrow, !eyebrow.isEmpty {
            return eyebrow
        }
        if let meta, !meta.isEmpty {
            return meta
        }
        return nil
    }

    private func planText(for item: AccountListModeItem) -> String {
        let raw = item.header.subtitle ?? "-"
        let normalized = raw.split(separator: "•").first?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (normalized?.isEmpty == false) ? normalized! : "-"
    }

    private func statusColor(for item: AccountListModeItem) -> Color {
        if let badge = item.header.badge {
            switch badge.tone {
            case .active:
                return DesignSystem.Colors.primary
            case .warning:
                return DesignSystem.Colors.Status.warning
            case .neutral:
                return DesignSystem.Colors.Text.secondary
            }
        }
        switch item.presentation.selectionStyle {
        case .active:
            return DesignSystem.Colors.primary
        case .pending:
            return DesignSystem.Colors.Status.warning
        case .transitioning:
            return DesignSystem.Colors.primary
        case .selected:
            return DesignSystem.Colors.primary
        case .neutral:
            return DesignSystem.Colors.Text.secondary
        }
    }
}
