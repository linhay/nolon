import NolonUIFoundation
import SwiftUI
import WebKit

// MARK: - ProviderSkillsTopControlsView

public struct ProviderSkillsTopControlsView: View {
    let providerPickerTitle: String
    let providers: [ProviderSkillsOption]
    @Binding var selectedProviderIndex: Int
    let migrationBannerTitle: String
    let migrationBannerDescription: String
    let migrationBannerActionTitle: String
    let showsMigrationBanner: Bool
    let onMigrateAll: () -> Void

    public struct Config {
        public var providerPickerTitle: String
        public var providers: [ProviderSkillsOption]
        public var migrationBannerTitle: String
        public var migrationBannerDescription: String
        public var migrationBannerActionTitle: String
        public var showsMigrationBanner: Bool
        public var onMigrateAll: () -> Void

        public init(
            providerPickerTitle: String = NSLocalizedString("provider_picker.label", value: "Provider", comment: "Provider picker label"),
            providers: [ProviderSkillsOption],
            migrationBannerTitle: String = NSLocalizedString("banner.orphaned_title", value: "Orphaned Skills Detected", comment: "Orphaned skills banner title"),
            migrationBannerDescription: String = NSLocalizedString("banner.orphaned_desc", value: "Some skills are not managed by this provider yet.", comment: "Orphaned skills banner description"),
            migrationBannerActionTitle: String = NSLocalizedString("action.import_all", value: "Import All", comment: "Import all action"),
            showsMigrationBanner: Bool,
            onMigrateAll: @escaping () -> Void
        ) {
            self.providerPickerTitle = providerPickerTitle
            self.providers = providers
            self.migrationBannerTitle = migrationBannerTitle
            self.migrationBannerDescription = migrationBannerDescription
            self.migrationBannerActionTitle = migrationBannerActionTitle
            self.showsMigrationBanner = showsMigrationBanner
            self.onMigrateAll = onMigrateAll
        }
    }

    public init(
        selectedProviderIndex: Binding<Int>,
        config: Config
    ) {
        self.providerPickerTitle = config.providerPickerTitle
        self.providers = config.providers
        self._selectedProviderIndex = selectedProviderIndex
        self.migrationBannerTitle = config.migrationBannerTitle
        self.migrationBannerDescription = config.migrationBannerDescription
        self.migrationBannerActionTitle = config.migrationBannerActionTitle
        self.showsMigrationBanner = config.showsMigrationBanner
        self.onMigrateAll = config.onMigrateAll
    }

    public init(
        providerPickerTitle: String = NSLocalizedString("provider_picker.label", value: "Provider", comment: "Provider picker label"),
        providers: [ProviderSkillsOption],
        selectedProviderIndex: Binding<Int>,
        migrationBannerTitle: String = NSLocalizedString("banner.orphaned_title", value: "Orphaned Skills Detected", comment: "Orphaned skills banner title"),
        migrationBannerDescription: String = NSLocalizedString("banner.orphaned_desc", value: "Some skills are not managed by this provider yet.", comment: "Orphaned skills banner description"),
        migrationBannerActionTitle: String = NSLocalizedString("action.import_all", value: "Import All", comment: "Import all action"),
        showsMigrationBanner: Bool,
        onMigrateAll: @escaping () -> Void
    ) {
        self.init(
            selectedProviderIndex: selectedProviderIndex,
            config: Config(
                providerPickerTitle: providerPickerTitle,
                providers: providers,
                migrationBannerTitle: migrationBannerTitle,
                migrationBannerDescription: migrationBannerDescription,
                migrationBannerActionTitle: migrationBannerActionTitle,
                showsMigrationBanner: showsMigrationBanner,
                onMigrateAll: onMigrateAll
            )
        )
    }

    public var body: some View {
        if !providers.isEmpty {
            Picker(providerPickerTitle, selection: $selectedProviderIndex) {
                ForEach(Array(providers.enumerated()), id: \.element.id) { index, provider in
                    Text(provider.title).tag(index)
                }
            }
            .pickerStyle(.segmented)
            .padding()
        }

        if showsMigrationBanner {
            OrphanedSkillsMigrationBannerView(
                title: migrationBannerTitle,
                description: migrationBannerDescription,
                actionTitle: migrationBannerActionTitle,
                onAction: onMigrateAll
            )
            .padding(.horizontal)
        }
    }
}

// MARK: - ProviderTokenTrendSectionView

public struct ProviderTokenTrendSectionView: View {
    private let data: ProviderTokenTrendSectionData
    private let layoutMode: ProviderTokenTrendSectionLayoutMode
    private let onRangeChange: (String) -> Void
    private let onSelectDay: (String?) -> Void
    private let onIntradayBucketChange: (String) -> Void
    private let onMetricModeChange: (ProviderTokenTrendMetricMode) -> Void
    private let onChartStyleChange: (ProviderTokenTrendChartStyle) -> Void
    private let onContentTabChange: (ProviderTokenTrendContentTab) -> Void
    private let onRefresh: () -> Void
    private let onRefreshIntraday: () -> Void

    @State private var sortKey: SortKey = .date
    @State private var sortAscending = false

    public struct Config {
        public var data: ProviderTokenTrendSectionData
        public var layoutMode: ProviderTokenTrendSectionLayoutMode
        public var onRangeChange: (String) -> Void
        public var onSelectDay: (String?) -> Void
        public var onIntradayBucketChange: (String) -> Void
        public var onMetricModeChange: (ProviderTokenTrendMetricMode) -> Void
        public var onChartStyleChange: (ProviderTokenTrendChartStyle) -> Void
        public var onContentTabChange: (ProviderTokenTrendContentTab) -> Void
        public var onRefresh: () -> Void
        public var onRefreshIntraday: () -> Void

        public init(
            data: ProviderTokenTrendSectionData,
            layoutMode: ProviderTokenTrendSectionLayoutMode = .flowing,
            onRangeChange: @escaping (String) -> Void,
            onSelectDay: @escaping (String?) -> Void,
            onIntradayBucketChange: @escaping (String) -> Void,
            onMetricModeChange: @escaping (ProviderTokenTrendMetricMode) -> Void,
            onChartStyleChange: @escaping (ProviderTokenTrendChartStyle) -> Void,
            onContentTabChange: @escaping (ProviderTokenTrendContentTab) -> Void,
            onRefresh: @escaping () -> Void,
            onRefreshIntraday: @escaping () -> Void
        ) {
            self.data = data
            self.layoutMode = layoutMode
            self.onRangeChange = onRangeChange
            self.onSelectDay = onSelectDay
            self.onIntradayBucketChange = onIntradayBucketChange
            self.onMetricModeChange = onMetricModeChange
            self.onChartStyleChange = onChartStyleChange
            self.onContentTabChange = onContentTabChange
            self.onRefresh = onRefresh
            self.onRefreshIntraday = onRefreshIntraday
        }
    }

    public init(config: Config) {
        self.data = config.data
        self.layoutMode = config.layoutMode
        self.onRangeChange = config.onRangeChange
        self.onSelectDay = config.onSelectDay
        self.onIntradayBucketChange = config.onIntradayBucketChange
        self.onMetricModeChange = config.onMetricModeChange
        self.onChartStyleChange = config.onChartStyleChange
        self.onContentTabChange = config.onContentTabChange
        self.onRefresh = config.onRefresh
        self.onRefreshIntraday = config.onRefreshIntraday
    }

    public init(
        data: ProviderTokenTrendSectionData,
        layoutMode: ProviderTokenTrendSectionLayoutMode = .flowing,
        onRangeChange: @escaping (String) -> Void,
        onSelectDay: @escaping (String?) -> Void,
        onIntradayBucketChange: @escaping (String) -> Void,
        onMetricModeChange: @escaping (ProviderTokenTrendMetricMode) -> Void,
        onChartStyleChange: @escaping (ProviderTokenTrendChartStyle) -> Void,
        onContentTabChange: @escaping (ProviderTokenTrendContentTab) -> Void,
        onRefresh: @escaping () -> Void,
        onRefreshIntraday: @escaping () -> Void
    ) {
        self.init(
            config: Config(
                data: data,
                layoutMode: layoutMode,
                onRangeChange: onRangeChange,
                onSelectDay: onSelectDay,
                onIntradayBucketChange: onIntradayBucketChange,
                onMetricModeChange: onMetricModeChange,
                onChartStyleChange: onChartStyleChange,
                onContentTabChange: onContentTabChange,
                onRefresh: onRefresh,
                onRefreshIntraday: onRefreshIntraday
            )
        )
    }

    @ViewBuilder
    public var body: some View {
        if let snapshot = data.snapshot {
            switch layoutMode {
            case .flowing:
                flowingSnapshotContent(snapshot: snapshot)
            case .standaloneUsageTab:
                standaloneUsageSnapshotContent(snapshot: snapshot)
            }
        } else {
            VStack(alignment: .leading, spacing: 16) {
                header

                if let errorMessage = data.errorMessage, !errorMessage.isEmpty {
                    errorState(message: errorMessage)
                } else if data.isLoading {
                    loadingState()
                } else {
                    emptyState
                }
            }
            .padding(16)
            .dsCard()
        }
    }

    private func flowingSnapshotContent(snapshot: ProviderTokenTrendSnapshotData) -> some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            header
            summary(snapshot: snapshot)
            trendWorkspaceSection(snapshot: snapshot)
        }
        .padding(16)
        .providerTokenTrendCardChrome()
    }

    private func standaloneUsageSnapshotContent(snapshot: ProviderTokenTrendSnapshotData) -> some View {
        LazyVStack(alignment: .leading, spacing: 16, pinnedViews: [.sectionHeaders]) {
            header
            summary(snapshot: snapshot)

            Section {
                workspaceBodyContent(snapshot: snapshot)
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                    .background(workspaceBodyBackground)
                    .overlay(workspaceBodyBorder)
            } header: {
                workspaceHeader(snapshot: snapshot)
                    .zIndex(1)
            }
        }
        .padding(16)
        .providerTokenTrendCardChrome()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text(sectionTitle)
                    .font(.headline)

                Spacer()

                Button {
                    onRefresh()
                } label: {
                    if data.isLoading {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .medium))
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .help(NSLocalizedString("generic.refresh", value: "Refresh", comment: "Refresh button"))
            }

            HStack(alignment: .firstTextBaseline) {
                Text(sectionSubtitle)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)

                Spacer()

                if let snapshot = data.snapshot {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                        Text("\(snapshot.updatedAt.formatted(date: .abbreviated, time: .shortened)) 更新")
                        if !snapshot.sourceLabel.isEmpty {
                            Text("(\(snapshot.sourceLabel))")
                        }
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                }
            }

            if let refreshStatus = data.refreshStatus {
                refreshStatusBanner(refreshStatus)
            }
        }
    }

    private var sectionTitle: String {
        switch data.metricMode {
        case .tokens:
            return NSLocalizedString(
                "usage.token_trend.title",
                value: "历史 Token 消耗",
                comment: "Token trend section title"
            )
        case .requests:
            return "历史请求趋势"
        }
    }

    private var sectionSubtitle: String {
        switch data.metricMode {
        case .tokens:
            return NSLocalizedString(
                "usage.token_trend.subtitle",
                value: "按日聚合输入、输出与缓存命中 token。",
                comment: "Token trend section subtitle"
            )
        case .requests:
            return "按日与分钟时间桶聚合请求数，统计口径与 token 趋势保持一致。"
        }
    }

    private func refreshStatusBanner(_ status: ProviderTokenTrendRefreshStatusData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.primary)
                    .padding(.top, 2)

                Text(status.headlineText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.Text.primary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .layoutPriority(1)

                Spacer()

                refreshStatusProgressLabel(status.progressLabel)
            }

            if let fractionCompleted = status.fractionCompleted {
                ProgressView(value: min(max(fractionCompleted, 0), 1), total: 1)
                    .controlSize(.small)
                    .tint(DesignSystem.Colors.primary)
            } else {
                ProgressView()
                    .controlSize(.small)
                    .tint(DesignSystem.Colors.primary)
            }
        }
        .padding(12)
        .frame(minHeight: ProviderTokenTrendLayoutMetrics.refreshStatusMinHeight, alignment: .topLeading)
        .background(DesignSystem.Colors.Background.elevated.opacity(0.24), in: RoundedRectangle(cornerRadius: 12))
    }

    private func summary(snapshot: ProviderTokenTrendSnapshotData) -> some View {
        let metrics = summaryMetrics(snapshot: snapshot)
        return LazyVGrid(
            columns: ProviderTokenTrendLayoutMetrics.summaryGridColumns(metricCount: metrics.count),
            spacing: ProviderTokenTrendLayoutMetrics.summaryCardSpacing
        ) {
            ForEach(metrics) { item in
                Button {
                    onRangeChange(item.targetRangeID)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(DesignSystem.Colors.Text.secondary)
                            .textCase(.uppercase)

                        Text(item.value)
                            .font(.title3.weight(.bold))
                            .monospacedDigit()
                            .minimumScaleFactor(0.72)
                            .foregroundStyle(DesignSystem.Colors.Text.primary)
                            .lineLimit(1)

                        Text(item.periodText)
                            .font(.system(size: 10, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }
                    .frame(maxWidth: .infinity, minHeight: ProviderTokenTrendLayoutMetrics.summaryCardMinHeight, alignment: .leading)
                    .padding(12)
                    .background(summaryCardBackground(for: item))
                    .overlay(summaryCardBorder(for: item))
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func trendWorkspaceSection(snapshot: ProviderTokenTrendSnapshotData) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            workspaceHeader(snapshot: snapshot)

            workspaceBodyContent(snapshot: snapshot)
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 12)
            .background(workspaceBodyBackground)
            .overlay(workspaceBodyBorder)
        }
    }

    @ViewBuilder
    private func workspaceBodyContent(snapshot: ProviderTokenTrendSnapshotData) -> some View {
        if resolvedContentTab == .daily {
            dailyTableSection(snapshot: snapshot)
        } else {
            ProviderTokenTrendIntradayContentSectionView(
                data: data,
                onRefreshIntraday: onRefreshIntraday
            )
        }
    }

    private func workspaceHeader(snapshot: ProviderTokenTrendSnapshotData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            workspaceControlDeck

            if resolvedContentTab == .daily {
                dailyWorkspaceHeader(snapshot: snapshot)
            } else {
                ProviderTokenTrendIntradayWorkspaceHeaderView(
                    data: data,
                    onIntradayBucketChange: onIntradayBucketChange,
                    onRefreshIntraday: onRefreshIntraday
                )
            }
        }
        .padding(10)
        .background(workspaceHeaderBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DesignSystem.Colors.Background.elevated.opacity(0.42))
                .frame(height: 1)
        }
    }

    private var workspaceHeaderBackground: some View {
        workspaceHeaderShape
            .fill(DesignSystem.Colors.Background.elevated.opacity(0.9))
    }

    private var workspaceBodyBackground: some View {
        workspaceBodyShape
            .fill(DesignSystem.Colors.Background.elevated.opacity(0.22))
    }

    private var workspaceBodyBorder: some View {
        workspaceBodyShape
            .strokeBorder(DesignSystem.Colors.Background.elevated.opacity(0.45), lineWidth: 1)
    }

    private var workspaceHeaderShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            cornerRadii: .init(topLeading: 12, topTrailing: 12),
            style: .continuous
        )
    }

    private var workspaceBodyShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            cornerRadii: .init(bottomLeading: 12, bottomTrailing: 12),
            style: .continuous
        )
    }

    private var resolvedContentTab: ProviderTokenTrendContentTab {
        guard data.supportsIntradayDrilldown else { return .daily }
        if data.activeTab == .intraday, data.selectedDayKey == nil {
            return .daily
        }
        return data.activeTab
    }

    private var workspaceControlDeck: some View {
        ProviderTokenTrendToolbarRail {
            ViewThatFits(in: .horizontal) {
                toolbarRailRow(compact: false)
                toolbarRailRow(compact: true)
            }
        }
    }

    private func toolbarRailRow(compact: Bool) -> some View {
        HStack(alignment: .center, spacing: 10) {
            leadingToolbarControls(compact: compact)

            Spacer(minLength: 8)

            if showsIntradayOptionsMenu {
                intradayOptionsMenu
            }
        }
        .frame(height: 28, alignment: .leading)
    }

    private func leadingToolbarControls(compact: Bool) -> some View {
        HStack(alignment: .center, spacing: 6) {
            if data.supportsIntradayDrilldown {
                contentTabControl(compact: compact)
            }

            metricModeControl(compact: compact)
            chartStyleControl(compact: compact)
        }
    }

    private func contentTabControl(compact: Bool) -> some View {
        ProviderTokenTrendToolbarField {
            ProviderTokenTrendToggleControl(
                options: [
                    .init(id: ProviderTokenTrendContentTab.daily, title: "Daily"),
                    .init(id: ProviderTokenTrendContentTab.intraday, title: compact ? "Intra" : "Intraday"),
                ],
                selection: resolvedContentTab,
                onSelectionChange: onContentTabChange
            )
        }
        .help("切换 Daily 与 Intraday 视图")
    }

    private func metricModeControl(compact: Bool) -> some View {
        ProviderTokenTrendToolbarField {
            ProviderTokenTrendToggleControl(
                options: [
                    .init(id: ProviderTokenTrendMetricMode.tokens, title: compact ? "Tok" : "Tokens"),
                    .init(id: ProviderTokenTrendMetricMode.requests, title: compact ? "Req" : "Requests"),
                ],
                selection: data.metricMode,
                onSelectionChange: onMetricModeChange
            )
        }
        .help("切换 Token 与请求数统计")
    }

    private func chartStyleControl(compact: Bool) -> some View {
        ProviderTokenTrendToolbarField {
            ProviderTokenTrendChartControlsView(
                compact: compact,
                chartStyle: data.chartStyle,
                onChartStyleChange: onChartStyleChange
            )
        }
        .help("切换柱状图与折线图")
    }

    private var showsIntradayBucketControl: Bool {
        resolvedContentTab == .intraday &&
            (data.drilldown?.availableBuckets.isEmpty == false)
    }

    private var intradayOptionsMenu: some View {
        ProviderTokenTrendToolbarField {
            Menu {
                if showsIntradayBucketControl {
                    Section("Bucket") {
                        ForEach(data.drilldown?.availableBuckets ?? []) { option in
                            Button {
                                onIntradayBucketChange(option.id)
                            } label: {
                                if option.id == data.drilldown?.bucketID {
                                    Label(compactBucketTitle(option.title), systemImage: "checkmark")
                                } else {
                                    Text(compactBucketTitle(option.title))
                                }
                            }
                        }
                    }
                }

                if showsIntradayRefreshControl {
                    Button {
                        onRefreshIntraday()
                    } label: {
                        Label(
                            data.drilldown?.isLoading == true ? "Refreshing..." : "Refresh",
                            systemImage: "arrow.clockwise"
                        )
                    }
                }
            } label: {
                ProviderTokenTrendMenuControl(
                    title: intradayMenuDisplayTitle,
                    systemImage: "slider.horizontal.3"
                )
            }
            .menuStyle(.borderlessButton)
        }
        .help("分钟级时间桶与刷新操作")
    }

    private var showsIntradayRefreshControl: Bool {
        resolvedContentTab == .intraday && data.selectedDayKey != nil
    }

    private var showsIntradayOptionsMenu: Bool {
        showsIntradayBucketControl || showsIntradayRefreshControl
    }

    private var intradayMenuDisplayTitle: String {
        if data.drilldown?.isLoading == true {
            return "Refreshing"
        }

        let currentTitle = data.drilldown?.availableBuckets.first(where: {
            $0.id == data.drilldown?.bucketID
        })?.title ?? data.drilldown?.bucketID ?? "Options"
        return compactBucketTitle(currentTitle)
    }

    private func compactBucketTitle(_ title: String) -> String {
        title
            .replacingOccurrences(of: "min", with: "m")
            .replacingOccurrences(of: "Min", with: "m")
            .replacingOccurrences(of: " ", with: "")
    }

    private func dailyWorkspaceHeader(snapshot: ProviderTokenTrendSnapshotData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if data.supportsIntradayDrilldown {
                ProviderTokenTrendContextTag(
                    icon: "cursorarrow.click.2",
                    text: "点选单日柱体或点位后，会自动切到 Intraday。",
                    accentColor: DesignSystem.Colors.primary
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            dailyChart(snapshot: snapshot)
            dailyChartFooter
        }
    }

    private var dailyChartFooter: some View {
        ProviderTokenTrendChartLegendView(
            chartStyle: data.chartStyle,
            metricMode: data.metricMode
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func dailyChart(snapshot: ProviderTokenTrendSnapshotData) -> some View {
        switch data.chartStyle {
        case .bar:
            dailyBarChart(snapshot: snapshot)
        case .line:
            dailyLineChart(snapshot: snapshot)
        }
    }

    private func dailyBarChart(snapshot: ProviderTokenTrendSnapshotData) -> some View {
        GeometryReader { proxy in
            let points = snapshot.points
            let maxValue = max(
                points.map {
                    ProviderTokenTrendChartSupport.resolvedValue(
                        for: $0,
                        metricMode: data.metricMode
                    )
                }.max() ?? 1,
                1
            )
            let layout = resolvedChartLayout(pointCount: points.count, containerWidth: proxy.size.width)
            let plotHeight = max(48, proxy.size.height - 22)

            ScrollViewReader { scrollProxy in
                ScrollView(.horizontal) {
                    HStack(alignment: .bottom, spacing: 0) {
                        ForEach(points, id: \.date) { point in
                            dailyBarSlot(
                                point: point,
                                maxValue: maxValue,
                                slotWidth: layout.slotWidth,
                                barWidth: layout.barWidth,
                                plotHeight: plotHeight
                            )
                            .id(point.date)
                        }
                    }
                    .padding(.horizontal, layout.edgePadding)
                    .padding(.bottom, 4)
                }
                .scrollIndicators(.hidden)
                .onAppear {
                    if let lastDate = points.last?.date {
                        scrollProxy.scrollTo(lastDate, anchor: .trailing)
                    }
                }
            }
        }
        .frame(height: ProviderTokenTrendLayoutMetrics.chartHeight)
    }

    private func dailyBarSlot(
        point: ProviderTokenTrendPointData,
        maxValue: Int,
        slotWidth: CGFloat,
        barWidth: CGFloat,
        plotHeight: CGFloat
    ) -> some View {
        let isSelected = point.date == data.selectedDayKey
        let metricValue = ProviderTokenTrendChartSupport.resolvedValue(
            for: point,
            metricMode: data.metricMode
        )
        let totalRatio = CGFloat(metricValue) / CGFloat(maxValue)
        let barHeight = max(6, totalRatio * plotHeight)

        return Button {
            onSelectDay(data.selectedDayKey == point.date ? nil : point.date)
        } label: {
            VStack(spacing: 6) {
                Spacer(minLength: 0)

                VStack(spacing: 0) {
                    if data.metricMode == .requests {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(DesignSystem.Colors.primary)
                            .frame(width: barWidth, height: barHeight)
                    } else {
                        barSegment(value: point.inputTokens, total: point.totalTokens, height: barHeight, color: DesignSystem.Colors.primary)
                        barSegment(value: point.outputTokens, total: point.totalTokens, height: barHeight, color: DesignSystem.Colors.Status.success)
                        barSegment(value: point.cacheReadTokens, total: point.totalTokens, height: barHeight, color: DesignSystem.Colors.Status.warning)
                    }
                }
                .frame(width: barWidth, height: barHeight)
                .background(DesignSystem.Colors.Background.elevated.opacity(0.28), in: RoundedRectangle(cornerRadius: 6))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(DesignSystem.Colors.primary, lineWidth: isSelected ? 2 : 0)
                )
                .opacity(data.selectedDayKey == nil || isSelected ? 1.0 : 0.48)

                Text(shortDate(point.date))
                    .font(.system(size: 9))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? DesignSystem.Colors.Text.primary : DesignSystem.Colors.Text.tertiary)
            }
            .frame(width: slotWidth, height: plotHeight + 20, alignment: .bottom)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func barSegment(value: Int, total: Int, height: CGFloat, color: Color) -> some View {
        let ratio = total > 0 ? CGFloat(value) / CGFloat(total) : 0
        return Rectangle()
            .fill(color)
            .frame(height: max(0, ratio * height))
    }

    private func dailyLineChart(snapshot: ProviderTokenTrendSnapshotData) -> some View {
        GeometryReader { proxy in
            let points = snapshot.points
            let maxValue = max(
                points.map {
                    ProviderTokenTrendChartSupport.resolvedValue(
                        for: $0,
                        metricMode: data.metricMode
                    )
                }.max() ?? 1,
                1
            )
            let layout = resolvedChartLayout(pointCount: points.count, containerWidth: proxy.size.width)
            let plotHeight = max(52, proxy.size.height - 22)
            let plotPoints = linePlotPoints(
                for: points,
                maxValue: maxValue,
                slotWidth: layout.slotWidth,
                plotHeight: plotHeight,
                metricMode: data.metricMode
            )
            let contentWidth = max(proxy.size.width - (layout.edgePadding * 2), CGFloat(max(points.count, 1)) * layout.slotWidth)

            ScrollViewReader { scrollProxy in
                ScrollView(.horizontal) {
                    ZStack(alignment: .topLeading) {
                        VStack(spacing: 0) {
                            ForEach([1.0, 0.5, 0.0], id: \.self) { ratio in
                                Rectangle()
                                    .fill(DesignSystem.Colors.Background.elevated.opacity(ratio == 0 ? 0.45 : 0.24))
                                    .frame(height: 1)
                                if ratio > 0 {
                                    Spacer()
                                }
                            }
                        }
                        .frame(width: contentWidth, height: plotHeight)

                        if let selectedPoint = plotPoints.first(where: { $0.point.date == data.selectedDayKey }) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(DesignSystem.Colors.primary.opacity(0.08))
                                .frame(width: max(18, layout.slotWidth - 6), height: plotHeight)
                                .position(x: selectedPoint.x, y: plotHeight / 2)
                        }

                        Path { path in
                            guard let firstPoint = plotPoints.first,
                                  let lastPoint = plotPoints.last else { return }
                            path.move(to: CGPoint(x: firstPoint.x, y: plotHeight))
                            path.addLine(to: CGPoint(x: firstPoint.x, y: firstPoint.y))
                            for point in plotPoints.dropFirst() {
                                path.addLine(to: CGPoint(x: point.x, y: point.y))
                            }
                            path.addLine(to: CGPoint(x: lastPoint.x, y: plotHeight))
                            path.closeSubpath()
                        }
                        .fill(
                            LinearGradient(
                                colors: [
                                    DesignSystem.Colors.primary.opacity(0.18),
                                    DesignSystem.Colors.primary.opacity(0.02),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        Path { path in
                            guard let firstPoint = plotPoints.first else { return }
                            path.move(to: CGPoint(x: firstPoint.x, y: firstPoint.y))
                            for point in plotPoints.dropFirst() {
                                path.addLine(to: CGPoint(x: point.x, y: point.y))
                            }
                        }
                        .stroke(DesignSystem.Colors.primary, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                        ForEach(plotPoints) { plotPoint in
                            lineValueLabel(
                                plotPoint,
                                isSelected: plotPoint.point.date == data.selectedDayKey
                            )
                            linePointMarker(
                                plotPoint,
                                isSelected: plotPoint.point.date == data.selectedDayKey
                            )
                        }

                        HStack(alignment: .bottom, spacing: 0) {
                            ForEach(points, id: \.date) { point in
                                Button {
                                    onSelectDay(data.selectedDayKey == point.date ? nil : point.date)
                                } label: {
                                    VStack(spacing: 6) {
                                        Spacer(minLength: 0)
                                        Text(shortDate(point.date))
                                            .font(.system(size: 9))
                                            .monospacedDigit()
                                            .foregroundStyle(point.date == data.selectedDayKey ? DesignSystem.Colors.Text.primary : DesignSystem.Colors.Text.tertiary)
                                    }
                                    .frame(width: layout.slotWidth, height: plotHeight + 20, alignment: .bottom)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .id(point.date)
                            }
                        }
                    }
                    .frame(width: contentWidth, height: plotHeight + 20)
                    .padding(.horizontal, layout.edgePadding)
                    .padding(.bottom, 4)
                }
                .scrollIndicators(.hidden)
                .onAppear {
                    if let lastDate = points.last?.date {
                        scrollProxy.scrollTo(lastDate, anchor: .trailing)
                    }
                }
            }
        }
        .frame(height: ProviderTokenTrendLayoutMetrics.chartHeight)
    }

    private func dailyTableSection(snapshot: ProviderTokenTrendSnapshotData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("usage.token_trend.table", value: "Daily Breakdown", comment: "Daily breakdown table"))
                .font(.subheadline.weight(.semibold))

            VStack(spacing: 0) {
                headerRow
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(DesignSystem.Colors.Background.elevated.opacity(0.3))

                VStack(spacing: 0) {
                    ForEach(sortedPoints(snapshot.points), id: \.date) { point in
                        dataRow(point: point)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(DesignSystem.Colors.Background.elevated.opacity(0.5), lineWidth: 1)
            )
        }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            sortableHeader(title: "Date", key: .date, width: 90, alignment: .leading)
            Spacer()
            sortableHeader(title: "Total", key: .total, width: ProviderTokenTrendLayoutMetrics.tableNumericColumnWidth)
            sortableHeader(title: "Requests", key: .requests, width: ProviderTokenTrendLayoutMetrics.tableNumericColumnWidth)
            sortableHeader(title: "Input", key: .input, width: ProviderTokenTrendLayoutMetrics.tableNumericColumnWidth)
            sortableHeader(title: "Output", key: .output, width: ProviderTokenTrendLayoutMetrics.tableNumericColumnWidth)
            sortableHeader(title: "Cache", key: .cache, width: ProviderTokenTrendLayoutMetrics.tableNumericColumnWidth)
        }
    }

    private func sortableHeader(title: String, key: SortKey, width: CGFloat, alignment: Alignment = .trailing) -> some View {
        Button {
            if sortKey == key {
                sortAscending.toggle()
            } else {
                sortKey = key
                sortAscending = key == .date
            }
        } label: {
            HStack(spacing: 4) {
                if alignment == .trailing && sortKey == key {
                    Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8))
                }
                Text(title)
                if alignment == .leading && sortKey == key {
                    Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8))
                }
            }
            .frame(width: width, alignment: alignment)
            .font(.caption2.weight(.bold))
            .foregroundStyle(sortKey == key ? DesignSystem.Colors.primary : DesignSystem.Colors.Text.secondary)
        }
        .buttonStyle(.plain)
    }

    private func dataRow(point: ProviderTokenTrendPointData) -> some View {
        let isSelected = point.date == data.selectedDayKey
        return HStack(spacing: 0) {
            Text(point.date)
                .frame(width: 90, alignment: .leading)
            Spacer()
            cell(formatTokenCount(point.totalTokens), width: ProviderTokenTrendLayoutMetrics.tableNumericColumnWidth)
            cell(
                formatTokenCount(point.requestCount),
                width: ProviderTokenTrendLayoutMetrics.tableNumericColumnWidth,
                color: data.metricMode == .requests ? DesignSystem.Colors.primary : .primary
            )
            cell(formatTokenCount(point.inputTokens), width: ProviderTokenTrendLayoutMetrics.tableNumericColumnWidth, color: DesignSystem.Colors.primary.opacity(0.8))
            cell(formatTokenCount(point.outputTokens), width: ProviderTokenTrendLayoutMetrics.tableNumericColumnWidth, color: DesignSystem.Colors.Status.success.opacity(0.8))
            cell(formatTokenCount(point.cacheReadTokens), width: ProviderTokenTrendLayoutMetrics.tableNumericColumnWidth, color: DesignSystem.Colors.Status.warning.opacity(0.8))
        }
        .font(.system(size: 11, design: .monospaced))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? DesignSystem.Colors.primary.opacity(0.08) : .clear)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelectDay(data.selectedDayKey == point.date ? nil : point.date)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DesignSystem.Colors.Background.elevated.opacity(0.3))
                .frame(height: 1)
        }
    }

    private func cell(_ text: String, width: CGFloat, alignment: Alignment = .trailing, color: Color = .primary) -> some View {
        Text(text)
            .foregroundStyle(color == .primary ? DesignSystem.Colors.Text.primary : color)
            .frame(width: width, alignment: alignment)
    }

    private func loadingState() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 4).fill(DesignSystem.Colors.Background.elevated.opacity(0.35)).frame(width: 52, height: 10)
                        RoundedRectangle(cornerRadius: 6).fill(DesignSystem.Colors.Background.elevated.opacity(0.42)).frame(width: 88, height: 20)
                        RoundedRectangle(cornerRadius: 4).fill(DesignSystem.Colors.Background.elevated.opacity(0.28)).frame(width: 72, height: 8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(DesignSystem.Colors.Background.elevated.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .redacted(reason: .placeholder)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(DesignSystem.Colors.Status.error)
            Text(message)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .frame(maxWidth: 240)
            Button(NSLocalizedString("generic.refresh", value: "Retry", comment: "Retry button")) { onRefresh() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 40)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.title2)
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
            Text(NSLocalizedString("usage.token_trend.empty", value: "No token history yet.", comment: "Empty token trend state"))
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 40)
    }

    private func sortedPoints(_ points: [ProviderTokenTrendPointData]) -> [ProviderTokenTrendPointData] {
        points.sorted { lhs, rhs in
            let ordered: Bool
            switch sortKey {
            case .date: ordered = lhs.date < rhs.date
            case .total: ordered = lhs.totalTokens < rhs.totalTokens
            case .requests: ordered = lhs.requestCount < rhs.requestCount
            case .input: ordered = lhs.inputTokens < rhs.inputTokens
            case .output: ordered = lhs.outputTokens < rhs.outputTokens
            case .cache: ordered = lhs.cacheReadTokens < rhs.cacheReadTokens
            }
            return sortAscending ? ordered : !ordered
        }
    }

    private func shortDate(_ value: String) -> String {
        guard value.count >= 10 else { return value }
        return String(value.suffix(5))
    }

    private func formatTokenCount(_ value: Int?) -> String {
        guard let value else { return "-" }
        let absValue = abs(value)
        switch absValue {
        case 1_000_000_000...:
            return String(format: "%.1fB", Double(value) / 1_000_000_000)
        case 1_000_000...:
            return String(format: "%.1fM", Double(value) / 1_000_000)
        case 1_000...:
            return String(format: "%.1fK", Double(value) / 1_000)
        default:
            return "\(value)"
        }
    }
}

private extension ProviderTokenTrendSectionView {
    func summaryMetrics(snapshot: ProviderTokenTrendSnapshotData) -> [SummaryMetric] {
        let todayValue = data.metricMode == .requests ? snapshot.todayRequests : snapshot.todayTokens
        let last7Value = data.metricMode == .requests ? snapshot.last7DaysRequests : snapshot.last7DaysTokens
        let last30Value = data.metricMode == .requests ? snapshot.last30DaysRequests : snapshot.last30DaysTokens
        let allValue = data.metricMode == .requests ? snapshot.allDaysRequests : snapshot.allDaysTokens

        return [
            SummaryMetric(
                title: NSLocalizedString("usage.token_trend.summary.today", value: "Today", comment: "Today tokens"),
                value: formatTokenCount(todayValue),
                periodText: snapshot.displayDateRange(for: "days1"),
                accentColor: DesignSystem.Colors.primary,
                secondaryAccentColor: DesignSystem.Colors.primary.opacity(0.5),
                targetRangeID: "days1"
            ),
            SummaryMetric(
                title: NSLocalizedString("usage.token_trend.summary.7d", value: "7 Days", comment: "7 day tokens"),
                value: formatTokenCount(last7Value),
                periodText: snapshot.displayDateRange(for: "days7"),
                accentColor: DesignSystem.Colors.Status.success,
                secondaryAccentColor: DesignSystem.Colors.Status.success.opacity(0.5),
                targetRangeID: "days7"
            ),
            SummaryMetric(
                title: NSLocalizedString("usage.token_trend.summary.30d", value: "30 Days", comment: "30 day tokens"),
                value: formatTokenCount(last30Value),
                periodText: snapshot.displayDateRange(for: "days30"),
                accentColor: DesignSystem.Colors.Status.warning,
                secondaryAccentColor: DesignSystem.Colors.Status.warning.opacity(0.5),
                targetRangeID: "days30"
            ),
            SummaryMetric(
                title: NSLocalizedString("codex.usage.range.all", value: "ALL", comment: "Codex usage trend range all"),
                value: formatTokenCount(allValue),
                periodText: snapshot.displayDateRange(for: "all"),
                accentColor: DesignSystem.Colors.Text.secondary,
                secondaryAccentColor: DesignSystem.Colors.Background.elevated,
                targetRangeID: "all"
            )
        ]
    }

    @ViewBuilder
    func summaryCardBackground(for item: SummaryMetric) -> some View {
        let isSelected = data.selectedRangeID == item.targetRangeID
        RoundedRectangle(cornerRadius: 12)
            .fill(
                LinearGradient(
                    colors: isSelected
                        ? [item.accentColor.opacity(0.26), item.secondaryAccentColor.opacity(0.16)]
                        : [item.accentColor.opacity(0.16), DesignSystem.Colors.Background.elevated.opacity(0.58)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    @ViewBuilder
    func summaryCardBorder(for item: SummaryMetric) -> some View {
        let isSelected = data.selectedRangeID == item.targetRangeID
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(
                isSelected ? item.accentColor.opacity(0.72) : item.accentColor.opacity(0.24),
                lineWidth: isSelected ? 1.5 : 1
            )
    }
}

private struct ProviderTokenTrendCardChromeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(
                    cornerRadius: DesignSystem.Metrics.cornerRadiusL,
                    style: .continuous
                )
                .fill(DesignSystem.Colors.Component.controlFillSubtle)
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: DesignSystem.Metrics.cornerRadiusL,
                    style: .continuous
                )
                .strokeBorder(
                    DesignSystem.Colors.Component.border.opacity(0.3),
                    lineWidth: 1
                )
            )
    }
}

private extension View {
    func providerTokenTrendCardChrome() -> some View {
        modifier(ProviderTokenTrendCardChromeModifier())
    }
}

// MARK: - ProviderUsageEmptyStateCard

public struct ProviderUsageEmptyStateCard: View {
    @State private var viewModel: ProviderUsageEmptyStateCardViewModel

    public struct Config {
        public var title: LocalizedStringKey
        public var systemImage: String
        public var descriptionText: Text

        public init(
            title: LocalizedStringKey,
            systemImage: String,
            descriptionText: Text
        ) {
            self.title = title
            self.systemImage = systemImage
            self.descriptionText = descriptionText
        }
    }

    public init(config: Config) {
        _viewModel = State(
            initialValue: ProviderUsageEmptyStateCardViewModel(
                title: config.title,
                systemImage: config.systemImage,
                descriptionText: config.descriptionText
            )
        )
    }

    public init(
        title: LocalizedStringKey,
        systemImage: String,
        descriptionText: Text
    ) {
        self.init(
            config: Config(
                title: title,
                systemImage: systemImage,
                descriptionText: descriptionText
            )
        )
    }

    public var body: some View {
        ContentUnavailableView(
            viewModel.title,
            systemImage: viewModel.systemImage,
            description: viewModel.descriptionText
                .dsSecondaryText(font: .body)
        )
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .center)
        .padding(24)
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity, alignment: .center)
        .dsCard(
            background: DesignSystem.Colors.Background.surface,
            borderColor: DesignSystem.Colors.Component.border.opacity(DesignSystem.Colors.Opacity.high)
        )
    }
}

// MARK: - ProviderUsageLoginSheets

public struct UsageLoginSheetView: View {
    let title: String
    let url: URL?

    @Environment(\.dismiss) private var dismiss

    public struct Config {
        public var title: String
        public var url: URL?

        public init(
            title: String,
            url: URL?
        ) {
            self.title = title
            self.url = url
        }
    }

    public init(config: Config) {
        self.title = config.title
        self.url = config.url
    }

    public init(title: String, url: URL?) {
        self.init(config: Config(title: title, url: url))
    }

    public var body: some View {
        VStack(spacing: 0) {
            SheetHeaderView(title: title) {
                dismiss()
            }

            SheetDivider()

            if let url {
                ProviderLoginWebView(url: url)
            } else {
                ContentUnavailableView(
                    NSLocalizedString("usage.monitor.login", value: "Sign in…", comment: "Sign in"),
                    systemImage: "globe",
                    description: Text(NSLocalizedString("usage.monitor.unsupported.desc", value: "Usage is not configured for this provider yet.", comment: "Unsupported"))
                        .dsSecondaryText(font: .body)
                )
            }
        }
        .frame(minWidth: 900, minHeight: 700)
    }
}

public struct ProviderLoginWebView: NSViewRepresentable {
    public struct Config {
        public var url: URL

        public init(url: URL) {
            self.url = url
        }
    }

    let url: URL

    public init(config: Config) {
        self.url = config.url
    }

    public init(url: URL) {
        self.init(config: Config(url: url))
    }

    public func makeNSView(context _: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let view = WKWebView(frame: .zero, configuration: config)
        view.load(URLRequest(url: url))
        return view
    }

    public func updateNSView(_ nsView: WKWebView, context _: Context) {
        if nsView.url != url {
            nsView.load(URLRequest(url: url))
        }
    }
}

public struct CodexLoginURLSheetView: View {
    public struct Config {
        public var mode: String
        public var url: URL?
        public var onCopy: () -> Void
        public var onOpen: () -> Void
        public var onCancel: () -> Void

        public init(
            mode: String,
            url: URL?,
            onCopy: @escaping () -> Void,
            onOpen: @escaping () -> Void,
            onCancel: @escaping () -> Void
        ) {
            self.mode = mode
            self.url = url
            self.onCopy = onCopy
            self.onOpen = onOpen
            self.onCancel = onCancel
        }
    }

    let mode: String
    let url: URL?
    let onCopy: () -> Void
    let onOpen: () -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    public static var dismissActionTitle: String {
        NSLocalizedString("codex.login.sheet.cancel", value: "取消登录", comment: "Cancel login")
    }

    public init(config: Config) {
        self.mode = config.mode
        self.url = config.url
        self.onCopy = config.onCopy
        self.onOpen = config.onOpen
        self.onCancel = config.onCancel
    }

    public init(
        mode: String,
        url: URL?,
        onCopy: @escaping () -> Void,
        onOpen: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.init(
            config: Config(
                mode: mode,
                url: url,
                onCopy: onCopy,
                onOpen: onOpen,
                onCancel: onCancel
            )
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(NSLocalizedString("codex.login.sheet.title", value: "登录中", comment: "Codex login sheet title"))
                    .font(.headline)
                Spacer()
                Button(Self.dismissActionTitle) {
                    onCancel()
                    dismiss()
                }
            }

            Text(mode)
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)

            GroupBox {
                Text(url?.absoluteString ?? "-")
                    .font(.caption)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Button(NSLocalizedString("codex.login.sheet.copy", value: "复制 URL", comment: "Copy login URL")) {
                    onCopy()
                }
                Button(NSLocalizedString("codex.login.sheet.open", value: "在浏览器中打开", comment: "Open in browser")) {
                    onOpen()
                }
                Spacer()
            }
        }
        .padding(16)
        .frame(minWidth: 620, minHeight: 220)
    }
}

// MARK: - McpConfigActionsToolbarView

public struct McpConfigActionsToolbarView: View {
    public struct Config {
        public var documentationURL: URL?
        public var documentationTitle: String
        public var editTitle: String
        public var onEdit: () -> Void

        public init(
            documentationURL: URL?,
            documentationTitle: String = NSLocalizedString(
                "mcp.action.documentation",
                value: "Documentation",
                comment: "MCP documentation action title"
            ),
            editTitle: String = NSLocalizedString(
                "mcp.action.edit_config",
                value: "Edit Config",
                comment: "MCP edit config action title"
            ),
            onEdit: @escaping () -> Void
        ) {
            self.documentationURL = documentationURL
            self.documentationTitle = documentationTitle
            self.editTitle = editTitle
            self.onEdit = onEdit
        }
    }

    let documentationURL: URL?
    let documentationTitle: String
    let editTitle: String
    let onEdit: () -> Void

    public init(config: Config) {
        self.documentationURL = config.documentationURL
        self.documentationTitle = config.documentationTitle
        self.editTitle = config.editTitle
        self.onEdit = config.onEdit
    }

    public init(
        documentationURL: URL?,
        documentationTitle: String = NSLocalizedString(
            "mcp.action.documentation",
            value: "Documentation",
            comment: "MCP documentation action title"
        ),
        editTitle: String = NSLocalizedString(
            "mcp.action.edit_config",
            value: "Edit Config",
            comment: "MCP edit config action title"
        ),
        onEdit: @escaping () -> Void
    ) {
        self.init(
            config: Config(
                documentationURL: documentationURL,
                documentationTitle: documentationTitle,
                editTitle: editTitle,
                onEdit: onEdit
            )
        )
    }

    public var body: some View {
        Menu {
            if let documentationURL {
                Link(destination: documentationURL) {
                    Label(documentationTitle, systemImage: "doc.text")
                }
            }
            Button {
                onEdit()
            } label: {
                Label(editTitle, systemImage: "pencil")
            }
        } label: {
            Label(editTitle, systemImage: "pencil")
        }
    }
}

// MARK: - McpConfigStateContainerView

public struct McpConfigStateContainerView<NoConfigView: View, NoServersView: View, NoResultsView: View, ContentView: View>: View {
    public struct Config {
        public var configExists: Bool
        public var isSearching: Bool
        public var hasFilteredServers: Bool
        public var noConfigView: () -> NoConfigView
        public var noServersView: () -> NoServersView
        public var noResultsView: () -> NoResultsView
        public var contentView: () -> ContentView

        public init(
            configExists: Bool,
            isSearching: Bool,
            hasFilteredServers: Bool,
            @ViewBuilder noConfigView: @escaping () -> NoConfigView,
            @ViewBuilder noServersView: @escaping () -> NoServersView,
            @ViewBuilder noResultsView: @escaping () -> NoResultsView,
            @ViewBuilder contentView: @escaping () -> ContentView
        ) {
            self.configExists = configExists
            self.isSearching = isSearching
            self.hasFilteredServers = hasFilteredServers
            self.noConfigView = noConfigView
            self.noServersView = noServersView
            self.noResultsView = noResultsView
            self.contentView = contentView
        }
    }

    let configExists: Bool
    let isSearching: Bool
    let hasFilteredServers: Bool
    let noConfigView: () -> NoConfigView
    let noServersView: () -> NoServersView
    let noResultsView: () -> NoResultsView
    let contentView: () -> ContentView

    public init(config: Config) {
        self.configExists = config.configExists
        self.isSearching = config.isSearching
        self.hasFilteredServers = config.hasFilteredServers
        self.noConfigView = config.noConfigView
        self.noServersView = config.noServersView
        self.noResultsView = config.noResultsView
        self.contentView = config.contentView
    }

    public init(
        configExists: Bool,
        isSearching: Bool,
        hasFilteredServers: Bool,
        @ViewBuilder noConfigView: @escaping () -> NoConfigView,
        @ViewBuilder noServersView: @escaping () -> NoServersView,
        @ViewBuilder noResultsView: @escaping () -> NoResultsView,
        @ViewBuilder contentView: @escaping () -> ContentView
    ) {
        self.init(
            config: Config(
                configExists: configExists,
                isSearching: isSearching,
                hasFilteredServers: hasFilteredServers,
                noConfigView: noConfigView,
                noServersView: noServersView,
                noResultsView: noResultsView,
                contentView: contentView
            )
        )
    }

    public var body: some View {
        if !configExists {
            noConfigView()
        } else if !hasFilteredServers && !isSearching {
            noServersView()
        } else if !hasFilteredServers {
            noResultsView()
        } else {
            contentView()
        }
    }
}

// MARK: - McpConfigStateViews

public struct McpConfigUnsupportedStateView: View {
    public struct Config {
        public var title: String
        public var systemImage: String
        public var description: String

        public init(
            title: String = NSLocalizedString(
                "mcp.not_supported",
                value: "MCP Not Supported",
                comment: "MCP unsupported title"
            ),
            systemImage: String = "exclamationmark.triangle",
            description: String = NSLocalizedString(
                "mcp.not_supported_desc",
                value: "This provider does not support MCP configuration",
                comment: "MCP unsupported description"
            )
        ) {
            self.title = title
            self.systemImage = systemImage
            self.description = description
        }
    }

    let title: String
    let systemImage: String
    let description: String

    public init(config: Config) {
        self.title = config.title
        self.systemImage = config.systemImage
        self.description = config.description
    }

    public init(
        title: String = NSLocalizedString(
            "mcp.not_supported",
            value: "MCP Not Supported",
            comment: "MCP unsupported title"
        ),
        systemImage: String = "exclamationmark.triangle",
        description: String = NSLocalizedString(
            "mcp.not_supported_desc",
            value: "This provider does not support MCP configuration",
            comment: "MCP unsupported description"
        )
    ) {
        self.init(
            config: Config(
                title: title,
                systemImage: systemImage,
                description: description
            )
        )
    }

    public var body: some View {
        UnavailableStateView(
            title: title,
            systemImage: systemImage,
            description: description
        )
    }
}

public struct McpConfigActionStateView: View {
    public enum Preset {
        case noConfiguration
        case noServers
    }

    public struct Config {
        public var title: String
        public var systemImage: String
        public var description: String
        public var actionTitle: String
        public var onAction: () -> Void

        public init(
            title: String,
            systemImage: String,
            description: String,
            actionTitle: String,
            onAction: @escaping () -> Void
        ) {
            self.title = title
            self.systemImage = systemImage
            self.description = description
            self.actionTitle = actionTitle
            self.onAction = onAction
        }
    }

    let title: String
    let systemImage: String
    let description: String
    let actionTitle: String
    let onAction: () -> Void

    public init(config: Config) {
        self.title = config.title
        self.systemImage = config.systemImage
        self.description = config.description
        self.actionTitle = config.actionTitle
        self.onAction = config.onAction
    }

    public init(
        title: String,
        systemImage: String,
        description: String,
        actionTitle: String,
        onAction: @escaping () -> Void
    ) {
        self.init(
            config: Config(
                title: title,
                systemImage: systemImage,
                description: description,
                actionTitle: actionTitle,
                onAction: onAction
            )
        )
    }

    public init(
        preset: Preset,
        onAction: @escaping () -> Void
    ) {
        let title: String
        let systemImage: String
        let description: String
        let actionTitle: String

        switch preset {
        case .noConfiguration:
            title = NSLocalizedString(
                "No Configuration",
                value: "No Configuration",
                comment: "MCP config missing title"
            )
            systemImage = "server.rack"
            description = NSLocalizedString(
                "MCP configuration file not found.",
                value: "MCP configuration file not found.",
                comment: "MCP config missing description"
            )
            actionTitle = NSLocalizedString(
                "Create Configuration",
                value: "Create Configuration",
                comment: "Create MCP config action"
            )
        case .noServers:
            title = NSLocalizedString(
                "No Servers",
                value: "No Servers",
                comment: "No MCP servers title"
            )
            systemImage = "server.rack"
            description = NSLocalizedString(
                "No MCP servers configured.",
                value: "No MCP servers configured.",
                comment: "No MCP servers description"
            )
            actionTitle = NSLocalizedString(
                "Edit Configuration",
                value: "Edit Configuration",
                comment: "Edit MCP config action"
            )
        }
        self.init(
            config: Config(
                title: title,
                systemImage: systemImage,
                description: description,
                actionTitle: actionTitle,
                onAction: onAction
            )
        )
    }

    public var body: some View {
        ActionUnavailableStateView(
            title: title,
            systemImage: systemImage,
            description: description,
            actionTitle: actionTitle
        ) {
            onAction()
        }
    }
}

public struct McpConfigNoResultsStateView: View {
    public struct Config {
        public var title: String
        public var systemImage: String
        public var description: String

        public init(
            title: String = NSLocalizedString(
                "mcp.empty.no_results.title",
                value: "No Results",
                comment: "MCP no results title"
            ),
            systemImage: String = "magnifyingglass",
            description: String = NSLocalizedString(
                "mcp.empty.no_results.desc",
                value: "No matching MCP servers found",
                comment: "MCP no results description"
            )
        ) {
            self.title = title
            self.systemImage = systemImage
            self.description = description
        }
    }

    let title: String
    let systemImage: String
    let description: String

    public init(config: Config) {
        self.title = config.title
        self.systemImage = config.systemImage
        self.description = config.description
    }

    public init(
        title: String = NSLocalizedString(
            "mcp.empty.no_results.title",
            value: "No Results",
            comment: "MCP no results title"
        ),
        systemImage: String = "magnifyingglass",
        description: String = NSLocalizedString(
            "mcp.empty.no_results.desc",
            value: "No matching MCP servers found",
            comment: "MCP no results description"
        )
    ) {
        self.init(
            config: Config(
                title: title,
                systemImage: systemImage,
                description: description
            )
        )
    }

    public var body: some View {
        UnavailableStateView(
            title: title,
            systemImage: systemImage,
            description: description
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - McpConfigToolbarScaffoldView

public struct McpConfigToolbarScaffoldView<Content: View>: View {
    public struct Config {
        public var documentationURL: URL?
        public var documentationTitle: String
        public var editTitle: String
        public var onEdit: () -> Void
        public var content: () -> Content

        public init(
            documentationURL: URL?,
            documentationTitle: String = NSLocalizedString(
                "mcp.action.documentation",
                value: "Documentation",
                comment: "MCP documentation action title"
            ),
            editTitle: String = NSLocalizedString(
                "mcp.action.edit_config",
                value: "Edit Config",
                comment: "MCP edit config action title"
            ),
            onEdit: @escaping () -> Void,
            @ViewBuilder content: @escaping () -> Content
        ) {
            self.documentationURL = documentationURL
            self.documentationTitle = documentationTitle
            self.editTitle = editTitle
            self.onEdit = onEdit
            self.content = content
        }
    }

    let documentationURL: URL?
    let documentationTitle: String
    let editTitle: String
    let onEdit: () -> Void
    let content: () -> Content

    public init(config: Config) {
        self.documentationURL = config.documentationURL
        self.documentationTitle = config.documentationTitle
        self.editTitle = config.editTitle
        self.onEdit = config.onEdit
        self.content = config.content
    }

    public init(
        documentationURL: URL?,
        documentationTitle: String = NSLocalizedString(
            "mcp.action.documentation",
            value: "Documentation",
            comment: "MCP documentation action title"
        ),
        editTitle: String = NSLocalizedString(
            "mcp.action.edit_config",
            value: "Edit Config",
            comment: "MCP edit config action title"
        ),
        onEdit: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            config: Config(
                documentationURL: documentationURL,
                documentationTitle: documentationTitle,
                editTitle: editTitle,
                onEdit: onEdit,
                content: content
            )
        )
    }

    public var body: some View {
        content()
            .toolbar {
                ToolbarItem {
                    McpConfigActionsToolbarView(
                        documentationURL: documentationURL,
                        documentationTitle: documentationTitle,
                        editTitle: editTitle,
                        onEdit: onEdit
                    )
                }
            }
    }
}
