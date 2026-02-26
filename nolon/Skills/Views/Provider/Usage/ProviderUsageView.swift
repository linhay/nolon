import SwiftUI
import AppKit
import ProviderCatalog
import WebKit
import ProviderUsage
import CodexBarProviderCatalog
import CodexProvider
import UniformTypeIdentifiers

struct ProviderUsageView: View {
    let provider: Provider
    let isEmbedded: Bool
    @State private var viewModel: ProviderUsageViewModel
    @State private var codexTrendSortKey: CodexTrendSortKey = .date
    @State private var codexTrendSortAscending = false

    private let codexAccountColumns: [GridItem] = [
        GridItem(.adaptive(minimum: 240, maximum: 340), spacing: 12, alignment: .topLeading)
    ]

    private enum CodexTrendSortKey: String, CaseIterable, Identifiable {
        case date
        case total
        case input
        case output
        case cache

        var id: String { rawValue }
    }

    init(provider: Provider, isEmbedded: Bool = false) {
        self.provider = provider
        self.isEmbedded = isEmbedded
        self._viewModel = State(initialValue: ProviderUsageViewModel(provider: provider))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            content

        }
        .if(!isEmbedded) { view in
            view.navigationTitle(NSLocalizedString("tab.usage", value: "Usage", comment: "Usage"))
        }
        .task(id: provider.id) {
            await viewModel.loadIfNeeded()
        }
        .onAppear {
            Task { await viewModel.handleUsageViewAppear() }
        }
        .onChange(of: viewModel.settings) { _, _ in
            Task { await viewModel.load() }
        }
        .sheet(isPresented: Bindable(viewModel).isShowingLogin) {
            UsageLoginSheet(title: provider.name, url: viewModel.dashboardURL)
        }
        .fileImporter(
            isPresented: $viewModel.isShowingAuthFileImporter,
            allowedContentTypes: [.json, .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                viewModel.importedAuthFileURL = urls.first
                if urls.first != nil {
                    viewModel.addAccountSource = .file
                    Task { await viewModel.confirmAddAccount() }
                }
            case .failure:
                viewModel.importedAuthFileURL = nil
            }
        }
        .alert(viewModel.alertTitle ?? "", isPresented: Binding(get: {
            viewModel.alertTitle != nil || viewModel.alertMessage != nil
        }, set: { newValue in
            if !newValue {
                viewModel.alertTitle = nil
                viewModel.alertMessage = nil
            }
        })) {
            Button(NSLocalizedString("generic.ok", value: "OK", comment: "OK")) {
                viewModel.alertTitle = nil
                viewModel.alertMessage = nil
            }
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
        .alert(
            NSLocalizedString("codex.accounts.activate.title", value: "Activate Account", comment: "Activate account title"),
            isPresented: $viewModel.isShowingActivateConfirm
        ) {
            Button(NSLocalizedString("generic.cancel", value: "Cancel", comment: "Cancel"), role: .cancel) {
                viewModel.pendingActivateCodexAccount = nil
            }
            Button(NSLocalizedString("codex.accounts.action.activate", value: "Activate", comment: "Activate account")) {
                Task { await viewModel.confirmActivate() }
            }
        } message: {
            let name = viewModel.pendingActivateCodexAccount?.name ?? ""
            let path = viewModel.codexAuthFilePath ?? "~/.codex/auth.json"
            let format = NSLocalizedString(
                "codex.accounts.activate.message",
                value: "Switch to \"%@\"? This will overwrite:\n%@",
                comment: "Activate account message"
            )
            Text(String(format: format, name, path))
        }
        .task(id: viewModel.settings.autoRefreshIntervalMinutes) {
            let minutes = viewModel.settings.autoRefreshIntervalMinutes
            guard minutes > 0 else { return }
            let interval = UInt64(minutes) * 60 * 1_000_000_000
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: interval)
                if Task.isCancelled { break }
                await viewModel.performAutoRefresh()
            }
        }
    }

    private var autoRefreshIntervalBinding: Binding<Int> {
        Binding(
            get: { viewModel.settings.autoRefreshIntervalMinutes },
            set: { newValue in
                var updated = viewModel.settings
                updated.autoRefreshIntervalMinutes = newValue
                viewModel.settings = updated
            }
        )
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.usageProvider == nil {
            ContentUnavailableView(
                NSLocalizedString("usage.monitor.unsupported.title", value: "Usage not supported", comment: "Unsupported title"),
                systemImage: "chart.bar.xaxis",
                description: Text(NSLocalizedString(
                    "usage.monitor.unsupported.desc",
                    value: "Usage is not configured for this provider yet.",
                    comment: "Unsupported description"
                ))
                .dsSecondaryText(font: .body)
            )
        } else if viewModel.usageProvider == .codex {
            codexContent
                .overlay {
                    if viewModel.isLoading {
                        loadingOverlay
                    }
                }
        } else if viewModel.outcomes.isEmpty {
            if viewModel.isLoading {
                loadingOverlay
            } else {
                ContentUnavailableView(
                    NSLocalizedString("usage.monitor.empty.title", value: "No usage data", comment: "Empty title"),
                    systemImage: "chart.bar",
                    description: Text(NSLocalizedString("usage.monitor.empty.desc", value: "No provider data available yet.", comment: "Empty description"))
                        .dsSecondaryText(font: .body)
                )
            }
        } else {
            genericUsageContent
                .overlay {
                    if viewModel.isLoading {
                        loadingOverlay
                    }
                }
        }
    }

    private var loadingOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DesignSystem.Colors.Background.surface.opacity(0.45))
            ProgressView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(provider.name)
                .font(.headline)

            Spacer()

            if viewModel.usageProvider != .codex {
                Button(NSLocalizedString("usage.monitor.login", value: "Sign in…", comment: "Sign in")) {
                    viewModel.isShowingLogin = true
                }
            }

            actionsMenu
        }
        .onChange(of: viewModel.settings) { _, newValue in
            viewModel.updateSettings(newValue)
        }
    }

    private var actionsMenu: some View {
        Menu {
            Button(NSLocalizedString("usage.monitor.refresh", value: "Refresh", comment: "Refresh")) {
                Task { await viewModel.load() }
            }

            Divider()

            Picker(
                NSLocalizedString("usage.monitor.auto_refresh.title", value: "Auto refresh", comment: "Auto refresh interval"),
                selection: autoRefreshIntervalBinding
            ) {
                ForEach(UsageAutoRefreshInterval.allCases) { option in
                    Text(option.title).tag(option.rawValue)
                }
            }

            if viewModel.usageProvider == .codex {
                Divider()

                Menu(NSLocalizedString("codex.accounts.action.add", value: "Add Account", comment: "Add account")) {
                    Button(NSLocalizedString("codex.accounts.add.source.current", value: "Current auth.json", comment: "Current auth.json")) {
                        viewModel.beginAddAccount(.current)
                    }
                    Button(NSLocalizedString("codex.accounts.add.source.file", value: "Import auth.json file", comment: "Import auth.json file")) {
                        viewModel.beginAddAccount(.file)
                    }
                    Button(NSLocalizedString("codex.accounts.add.source.cli", value: "CLI Login", comment: "CLI login")) {
                        viewModel.beginAddAccount(.cliLogin)
                    }
                    .disabled(viewModel.isRunningCLILogin)

                    if let status = viewModel.cliLoginStatus, viewModel.isRunningCLILogin {
                        Divider()
                        Text(status)
                            .dsSecondaryText(font: .body)
                    }
                }
                .disabled(!viewModel.isMultiAccountEnabled)

                if viewModel.isRunningCLILogin {
                    Button(NSLocalizedString("codex.cli_login.cancel", value: "Cancel Login", comment: "Cancel CLI login")) {
                        viewModel.cancelCLILoginIfNeeded()
                    }
                }

                Toggle(
                    NSLocalizedString("codex.accounts.multi.enable", value: "Multi-account", comment: "Multi-account toggle"),
                    isOn: Binding(
                        get: { viewModel.isMultiAccountEnabled },
                        set: { viewModel.setMultiAccountEnabled($0) }
                    )
                )
            }
        } label: {
            Image(systemName: "ellipsis")
                .dsIconButton()
        }
        .dsBorderlessMenu()
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private var genericUsageContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(viewModel.outcomes) { outcome in
                    ProviderUsageSnapshotView(outcome: outcome)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var codexCurrentOutcome: ProviderAccountUsageOutcome? {
        if let outcome = viewModel.outcomes.first(where: { outcome in
            if case .default = outcome.account { return true }
            return false
        }) {
            return outcome
        }
        return viewModel.outcomes.first
    }

    private func creditsRefreshedAt(for outcome: ProviderAccountUsageOutcome) -> Date? {
        guard viewModel.usageProvider == .codex else { return nil }
        switch outcome.account {
        case let .tokenAccount(account):
            return viewModel.codexAccountCreditsRefreshedAt[account.id]
        case .default:
            if let activeId = viewModel.activeCodexAccountId {
                return viewModel.codexAccountCreditsRefreshedAt[activeId]
            }
            return nil
        }
    }

    private var codexContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                codexTrendSection

                if viewModel.isMultiAccountEnabled {
                    if viewModel.codexAccounts.isEmpty {
                        ContentUnavailableView(
                            NSLocalizedString("codex.accounts.empty.title", value: "No accounts", comment: "Empty state title"),
                            systemImage: "person.crop.circle.badge.plus",
                            description: Text(NSLocalizedString(
                                "codex.accounts.empty.desc",
                                value: "Add a snapshot of Codex auth.json to quickly switch accounts.",
                                comment: "Empty state description"
                            ))
                            .dsSecondaryText(font: .body)
                        )
                    }

                    LazyVGrid(columns: codexAccountColumns, alignment: .leading, spacing: 12) {
                        ForEach(viewModel.codexAccountOutcomes) { outcome in
                            codexOutcomeCard(outcome: outcome)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    if let outcome = codexCurrentOutcome {
                        ProviderUsageSnapshotView(
                            outcome: outcome,
                            creditsRefreshedAt: creditsRefreshedAt(for: outcome)
                        )
                    } else {
                        ContentUnavailableView(
                            NSLocalizedString("usage.monitor.empty.title", value: "No usage data", comment: "Empty title"),
                            systemImage: "chart.bar",
                            description: Text(NSLocalizedString("usage.monitor.empty.desc", value: "No provider data available yet.", comment: "Empty description"))
                                .dsSecondaryText(font: .body)
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var codexTrendSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Text(NSLocalizedString("codex.usage.trend.title", value: "Token Trend", comment: "Codex usage trend title"))
                    .font(.headline)

                Spacer()

                Picker("", selection: Binding(
                    get: { viewModel.codexTrendRange },
                    set: { viewModel.setCodexTrendRange($0) }
                )) {
                    ForEach(ProviderUsageViewModel.CodexTrendRange.allCases) { range in
                        Text(range.title).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)

                Button {
                    viewModel.refreshCodexTokenTrendNow()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help(NSLocalizedString("usage.monitor.refresh", value: "Refresh", comment: "Refresh"))
                .dsBorderlessButton()
            }

            if viewModel.isLoadingCodexTrend {
                ProgressView()
                    .controlSize(.small)
            } else if let errorMessage = viewModel.codexTrendErrorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Status.error)
            } else if let snapshot = viewModel.codexTrendSnapshot, !snapshot.points.isEmpty {
                codexTrendSummaryRow(snapshot: snapshot)
                codexTrendStackedBarChart(snapshot: snapshot)
                codexTrendTable(snapshot: snapshot)
            } else {
                Text(NSLocalizedString("usage.monitor.empty.desc", value: "No provider data available yet.", comment: "Empty description"))
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
            }
        }
        .padding(12)
        .dsCard()
    }

    private func codexTrendSummaryRow(snapshot: CodexTokenTrendSnapshot) -> some View {
        HStack(spacing: 16) {
            summaryPill(
                title: NSLocalizedString("codex.usage.range.today", value: "Today", comment: "Today"),
                value: formatTokenCount(snapshot.todayTokens)
            )
            summaryPill(
                title: NSLocalizedString("codex.usage.range.7d", value: "7D", comment: "7D"),
                value: formatTokenCount(snapshot.last7DaysTokens)
            )
            summaryPill(
                title: NSLocalizedString("codex.usage.range.30d", value: "30D", comment: "30D"),
                value: formatTokenCount(snapshot.last30DaysTokens)
            )
            Spacer()
        }
    }

    private func summaryPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
            Text(value)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(DesignSystem.Colors.Text.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(DesignSystem.Colors.Background.elevated)
        )
    }

    private func codexTrendStackedBarChart(snapshot: CodexTokenTrendSnapshot) -> some View {
        let points = snapshot.points.sorted { $0.date < $1.date }
        let maxTotal = max(points.map(\.totalTokens).max() ?? 1, 1)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                legendMark(
                    title: NSLocalizedString("codex.usage.total.tokens", value: "Total tokens", comment: "Total tokens"),
                    color: DesignSystem.Colors.Text.secondary,
                    outlined: true
                )
                legendMark(title: "Input", color: DesignSystem.Colors.primary)
                legendMark(title: "Output", color: DesignSystem.Colors.Status.success)
                legendMark(title: "Cache", color: DesignSystem.Colors.Status.warning)
                Spacer()
            }
            .font(.caption2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(points, id: \.date) { point in
                        VStack(spacing: 6) {
                            Text(formatTokenCompact(point.totalTokens))
                                .font(.caption2)
                                .monospacedDigit()
                                .foregroundStyle(DesignSystem.Colors.Text.tertiary)

                            ZStack(alignment: .bottom) {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .stroke(DesignSystem.Colors.Text.secondary.opacity(0.6), lineWidth: 1)
                                    .frame(width: 26, height: max(6, CGFloat(point.totalTokens) / CGFloat(maxTotal) * 120))

                                VStack(spacing: 0) {
                                    segmentBlock(height: stackHeight(total: point.totalTokens, part: point.inputTokens, maxTotal: maxTotal), color: DesignSystem.Colors.primary)
                                    segmentBlock(height: stackHeight(total: point.totalTokens, part: point.outputTokens, maxTotal: maxTotal), color: DesignSystem.Colors.Status.success)
                                    segmentBlock(height: stackHeight(total: point.totalTokens, part: point.cacheReadTokens, maxTotal: maxTotal), color: DesignSystem.Colors.Status.warning)
                                }
                                .frame(width: 22)
                                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                            }
                            .frame(width: 28, height: 124, alignment: .bottom)

                            Text(shortDateLabel(point.date))
                                .font(.caption2)
                                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func legendMark(title: String, color: Color, outlined: Bool = false) -> some View {
        HStack(spacing: 4) {
            if outlined {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(color, lineWidth: 1)
                    .frame(width: 10, height: 10)
            } else {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(color)
                    .frame(width: 10, height: 10)
            }
            Text(title)
        }
    }

    private func segmentBlock(height: CGFloat, color: Color) -> some View {
        Rectangle()
            .fill(color)
            .frame(height: max(0, height))
    }

    private func stackHeight(total: Int, part: Int, maxTotal: Int) -> CGFloat {
        guard total > 0, part > 0, maxTotal > 0 else { return 0 }
        let fullHeight = CGFloat(total) / CGFloat(maxTotal) * 120
        return fullHeight * CGFloat(part) / CGFloat(total)
    }

    private func codexTrendTable(snapshot: CodexTokenTrendSnapshot) -> some View {
        let rows = sortedTrendRows(snapshot.points)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                trendHeaderCell(title: "Date", key: .date, width: 96)
                trendHeaderCell(title: "Total", key: .total, width: 108)
                trendHeaderCell(title: "Input", key: .input, width: 108)
                trendHeaderCell(title: "Output", key: .output, width: 108)
                trendHeaderCell(title: "Cache", key: .cache, width: 108)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
            .background(DesignSystem.Colors.Background.elevated)

            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack(spacing: 0) {
                    trendValueCell(row.date, width: 96, isDate: true)
                    trendValueCell(formatTokenCompact(row.totalTokens), width: 108)
                    trendValueCell(formatTokenCompact(row.inputTokens), width: 108)
                    trendValueCell(formatTokenCompact(row.outputTokens), width: 108)
                    trendValueCell(formatTokenCompact(row.cacheReadTokens), width: 108)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 6)
                .background(index.isMultiple(of: 2) ? DesignSystem.Colors.Background.surface : Color.clear)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func trendHeaderCell(title: String, key: CodexTrendSortKey, width: CGFloat) -> some View {
        Button {
            if codexTrendSortKey == key {
                codexTrendSortAscending.toggle()
            } else {
                codexTrendSortKey = key
                codexTrendSortAscending = false
            }
        } label: {
            HStack(spacing: 4) {
                Text(title)
                if codexTrendSortKey == key {
                    Image(systemName: codexTrendSortAscending ? "arrow.up" : "arrow.down")
                        .font(.caption2)
                }
            }
            .frame(width: width, alignment: .leading)
            .font(.caption)
            .foregroundStyle(DesignSystem.Colors.Text.secondary)
        }
        .buttonStyle(.plain)
    }

    private func trendValueCell(_ value: String, width: CGFloat, isDate: Bool = false) -> some View {
        Text(value)
            .frame(width: width, alignment: .leading)
            .font(.caption)
            .foregroundStyle(DesignSystem.Colors.Text.primary)
            .monospacedDigit()
            .if(isDate == false) { view in
                view
                    .textSelection(.enabled)
            }
    }

    private func sortedTrendRows(_ rows: [CodexTokenTrendPoint]) -> [CodexTokenTrendPoint] {
        rows.sorted { lhs, rhs in
            let ascending = codexTrendSortAscending
            switch codexTrendSortKey {
            case .date:
                return ascending ? (lhs.date < rhs.date) : (lhs.date > rhs.date)
            case .total:
                return ascending ? (lhs.totalTokens < rhs.totalTokens) : (lhs.totalTokens > rhs.totalTokens)
            case .input:
                return ascending ? (lhs.inputTokens < rhs.inputTokens) : (lhs.inputTokens > rhs.inputTokens)
            case .output:
                return ascending ? (lhs.outputTokens < rhs.outputTokens) : (lhs.outputTokens > rhs.outputTokens)
            case .cache:
                return ascending ? (lhs.cacheReadTokens < rhs.cacheReadTokens) : (lhs.cacheReadTokens > rhs.cacheReadTokens)
            }
        }
    }

    private func formatTokenCount(_ value: Int?) -> String {
        guard let value else { return "-" }
        return NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
    }

    private func formatTokenCompact(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }
        return "\(value)"
    }

    private func shortDateLabel(_ value: String) -> String {
        let parts = value.split(separator: "-")
        guard parts.count == 3 else { return value }
        return "\(parts[1])/\(parts[2])"
    }

    @ViewBuilder
    private func codexOutcomeCard(outcome: ProviderAccountUsageOutcome) -> some View {
        let accountId: UUID? = {
            switch outcome.account {
            case .default:
                return nil
            case let .tokenAccount(account):
                return account.id
            }
        }()

        let isPending: Bool = {
            guard let accountId else { return false }
            return viewModel.pendingActivateCodexAccount?.id == accountId
        }()

        let isActive: Bool = {
            guard let accountId else { return false }
            guard let saved = viewModel.codexAccounts.first(where: { $0.id == accountId }) else { return false }
            return viewModel.isActiveCodexAccount(saved)
        }()

        let isSelected = isActive || isPending
        let borderColor = isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.Component.border.opacity(0.6)
        let borderStyle = StrokeStyle(
            lineWidth: isSelected ? 2 : 1,
            dash: isPending && !isActive ? [6, 4] : []
        )
        let summary = accountId.flatMap { viewModel.codexAccountSummaries[$0] }
        let isRefreshing = accountId.map { viewModel.codexRefreshingAccountIds.contains($0) } ?? false
        let canLogin = accountId != nil
        let isLoggingIn = accountId != nil
            && viewModel.isRunningCLILogin
            && viewModel.cliLoginPreferredAccountId == accountId
        let onLogin: (() -> Void)? = accountId.map { id in
            { viewModel.requestLoginForCodexAccount(id: id) }
        }

        codexCompactSnapshotView(
            outcome: outcome,
            isSelected: isSelected,
            isRefreshing: isRefreshing,
            summary: summary,
            onRefresh: accountId.map { id in
                { viewModel.refreshCodexAccount(id: id) }
            }
        )
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusL, style: .continuous)
                .strokeBorder(
                    borderColor,
                    style: borderStyle
                )
        }
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusL, style: .continuous)
                    .fill(DesignSystem.Colors.primary.opacity(isActive ? 0.16 : 0.1))
            } else {
                RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusL, style: .continuous)
                    .fill(DesignSystem.Colors.Background.elevated)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusL, style: .continuous))
        .onTapGesture {
            guard let accountId, !isActive else { return }
            viewModel.requestActivateCodexAccount(id: accountId)
        }
        .contextMenu {
            if let accountId {
                Button {
                    viewModel.revealCodexAccountInFinder(id: accountId)
                } label: {
                    Label(NSLocalizedString("action.show_in_finder", comment: "Show in Finder"), systemImage: "folder")
                        .dsIconLabelButton()
                }

                if let onLogin {
                    Divider()
                    Button(NSLocalizedString("codex.cli_login.action", value: "CLI Login…", comment: "CLI login action")) {
                        onLogin()
                    }
                    .disabled(!canLogin)
                }

                if isLoggingIn {
                    Button(NSLocalizedString("codex.accounts.add.cli.running", value: "Logging in…", comment: "CLI login running status")) {}
                        .disabled(true)
                }
            }
        }
    }

    @ViewBuilder
    private func codexCompactSnapshotView(
        outcome: ProviderAccountUsageOutcome,
        isSelected: Bool,
        isRefreshing: Bool,
        summary: CodexAuthSummary?,
        onRefresh: (() -> Void)?
    ) -> some View {
        let title = outcome.displayName
        let fallbackEmail = summary?.email?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackPlan = summary?.plan?.trimmingCharacters(in: .whitespacesAndNewlines)
        let lastLogin = summary?.lastLoginAt
        let lastSync = summary?.lastSyncSucceededAt
        let lastFailure = summary?.lastSyncFailedAt
        let lastFailureMessage = summary?.lastSyncFailureMessage

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.Text.primary)
                    .lineLimit(1)

                Spacer()

                if let onRefresh {
                    Button {
                        onRefresh()
                    } label: {
                        if isRefreshing {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .dsIconButton(size: 18, foreground: DesignSystem.Colors.Text.secondary)
                        }
                    }
                    .dsBorderlessButton()
                    .help(NSLocalizedString("usage.monitor.refresh", value: "Refresh", comment: "Refresh"))
                }
            }

            if let lastFailure, let lastFailureMessage, !lastFailureMessage.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.Status.error)
                    Text(NSLocalizedString("codex.accounts.sync.failure", value: "Last failure", comment: "Last failure label"))
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    Text("\(lastFailure.formatted(date: .abbreviated, time: .shortened)) · \(lastFailureMessage)")
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.Text.primary)
                        .lineLimit(2)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusS, style: .continuous)
                        .fill(DesignSystem.Colors.Status.error.opacity(0.16))
                )
            }

            switch outcome.outcome.result {
            case let .success(result):
                let identity = result.usage.identity?.scoped(to: outcome.provider)
                let email = (identity?.accountEmail?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? fallbackEmail
                let plan = (identity?.plan?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? fallbackPlan

                if let subtitle = codexSubtitleText(title: title, email: email, plan: plan) {
                    Text(subtitle)
                        .font(.caption)
                        .dsSecondaryText(font: .caption)
                        .lineLimit(1)
                }

                let metadata = ProviderUsageRegistry.metadata(for: outcome.provider)
                if result.usage.primary != nil || result.usage.secondary != nil || result.usage.tertiary != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        if let primary = result.usage.primary {
                            codexQuotaRow(
                                title: metadata?.sessionLabel
                                    ?? NSLocalizedString("usage.metric.session", value: "Session", comment: "Session"),
                                window: primary
                            )
                        }
                        if let secondary = result.usage.secondary {
                            codexQuotaRow(
                                title: metadata?.weeklyLabel
                                    ?? NSLocalizedString("usage.metric.weekly", value: "Weekly", comment: "Weekly"),
                                window: secondary
                            )
                        }
                        if let tertiary = result.usage.tertiary {
                            codexQuotaRow(
                                title: metadata?.opusLabel
                                    ?? NSLocalizedString("usage.metric.third", value: "Other", comment: "Other"),
                                window: tertiary
                            )
                        }
                    }
                }
            case let .failure(error):
                if let subtitle = codexSubtitleText(title: title, email: fallbackEmail, plan: fallbackPlan) {
                    Text(subtitle)
                        .font(.caption)
                        .dsSecondaryText(font: .caption)
                        .lineLimit(1)
                }

                let errorText = {
                    let trimmed = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                    return trimmed.isEmpty ? String(describing: error) : trimmed
                }()

                Text(NSLocalizedString("usage.monitor.error.title", value: "Failed to load usage", comment: "Error title"))
                    .dsErrorText(font: .caption)
                    .lineLimit(1)

                Text(errorText)
                    .font(.caption)
                    .dsTertiaryText(font: .caption)
                    .lineLimit(2)
            }

            if let lastLogin {
                HStack(spacing: 6) {
                    Text(NSLocalizedString("codex.accounts.login_at", value: "Last login", comment: "Last login label"))
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    Text(lastLogin.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.Text.primary)
                        .lineLimit(1)
                }
            }

            if let lastSync {
                HStack(spacing: 6) {
                    Text(NSLocalizedString("codex.accounts.sync.success", value: "Last sync", comment: "Last sync label"))
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    Text(lastSync.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.Text.primary)
                        .lineLimit(1)
                }
            }

        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .textSelection(.enabled)
        .dsCard(background: .clear, borderColor: nil, borderWidth: 0)
    }

    private func codexSubtitleText(title: String, email: String?, plan: String?) -> String? {
        let trimmedEmail = email?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPlan = plan?.trimmingCharacters(in: .whitespacesAndNewlines)

        let parts = [
            (trimmedEmail?.isEmpty == false && trimmedEmail != title) ? trimmedEmail : nil,
            (trimmedPlan?.isEmpty == false) ? trimmedPlan : nil,
        ].compactMap { $0 }

        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private func codexQuotaRow(title: String, window: RateWindow) -> some View {
        let percent = min(100, max(0, window.remainingPercent))

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)

                Spacer()

                Text(String(format: "%.0f%%", percent))
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                    .monospacedDigit()
            }

            ProgressView(value: percent, total: 100)
                .tint(DesignSystem.Colors.primary)
                .controlSize(.small)

            let periodText = codexWindowPeriodText(window.windowMinutes)
            let countdownText = codexResetCountdownText(resetsAt: window.resetsAt)
            if periodText != nil || countdownText != nil {
                HStack(spacing: 8) {
                    if let periodText {
                        Text(periodText)
                    }

                    Spacer()

                    if let countdownText {
                        Text(countdownText)
                    }
                }
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                .lineLimit(1)
            }
        }
    }

    private func codexResetCountdownText(resetsAt: Date?) -> String? {
        guard let resetsAt else { return nil }
        let remaining = max(0, resetsAt.timeIntervalSinceNow)
        if remaining <= 0 { return nil }
        let seconds = Int(remaining.rounded(.down))
        let minutes = max(0, seconds / 60)
        let days = minutes / (60 * 24)
        let hours = (minutes % (60 * 24)) / 60
        let mins = minutes % 60

        let isChinese = isChineseLocale
        let dayUnit = isChinese ? "天" : "d"
        let hourUnit = isChinese ? "小时" : "h"
        let minuteUnit = isChinese ? "分钟" : "m"

        var parts: [String] = []
        if days > 0 { parts.append("\(days)\(dayUnit)") }
        if hours > 0 { parts.append("\(hours)\(hourUnit)") }
        if parts.isEmpty, mins > 0 { parts.append("\(mins)\(minuteUnit)") }
        if parts.count < 2, mins > 0, days == 0, hours > 0 {
            parts.append("\(mins)\(minuteUnit)")
        }
        let countdown = parts.joined()
        if countdown.isEmpty { return nil }

        return String(
            format: NSLocalizedString(
                "usage.metric.resets_in_compact",
                value: "resets in %@",
                comment: "Compact resets countdown label"
            ),
            countdown
        )
    }

    private func codexWindowPeriodText(_ windowMinutes: Int?) -> String? {
        guard let windowMinutes, windowMinutes > 0 else { return nil }

        let weekMinutes = 60 * 24 * 7
        let dayMinutes = 60 * 24
        let isChinese = isChineseLocale

        if windowMinutes % weekMinutes == 0 {
            let value = windowMinutes / weekMinutes
            return isChinese ? "\(value)周" : "\(value)w"
        }
        if windowMinutes % dayMinutes == 0 {
            let value = windowMinutes / dayMinutes
            return isChinese ? "\(value)天" : "\(value)d"
        }
        if windowMinutes % 60 == 0 {
            let value = windowMinutes / 60
            return isChinese ? "\(value)小时" : "\(value)h"
        }
        return isChinese ? "\(windowMinutes)分钟" : "\(windowMinutes)m"
    }

    private var isChineseLocale: Bool {
        if #available(macOS 13.0, *) {
            if let code = Locale.current.language.languageCode?.identifier {
                return code.hasPrefix("zh")
            }
        }
        return Locale.current.identifier.hasPrefix("zh")
    }

    private func codexCreditsText(_ value: Double) -> String {
        if value.isInfinite {
            return NSLocalizedString("usage.metric.unlimited", value: "Unlimited", comment: "Unlimited")
        }
        if value.isNaN {
            return NSLocalizedString("usage.metric.unknown", value: "Unknown", comment: "Unknown")
        }
        return String(format: "%.0f", value)
    }

}
