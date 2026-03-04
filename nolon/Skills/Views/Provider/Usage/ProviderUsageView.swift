import SwiftUI
import AppKit
import ProviderCatalog
import WebKit
import ProviderUsage
import CodexBarProviderCatalog
import CodexProvider
import UniformTypeIdentifiers

enum CodexUsageCardStatusKind: Equatable {
    case healthy
    case error
    case pending
}

enum CodexUsageCardActionLayout: Equatable {
    case singleFullWidth
    case dualEqualWidth
}

enum ProviderUsageHeaderAction: Equatable {
    case refreshAll
    case login
    case importAuth

    static func orderedActions(for provider: Provider) -> [ProviderUsageHeaderAction] {
        if provider.templateId == "codex" || provider.templateId == "codexXcode" {
            return [.refreshAll, .login, .importAuth]
        }
        return [.login]
    }
}

enum CodexUsageCardPresentationPolicy {
    static func statusKind(for state: ProviderUsageViewModel.CodexAccountDisplayState) -> CodexUsageCardStatusKind {
        switch state {
        case .needsReauth, .failed:
            return .error
        case .healthy:
            return .healthy
        case .pending:
            return .pending
        }
    }

    static func actionLayout(needsReauth: Bool, hasLoginAction: Bool) -> CodexUsageCardActionLayout {
        if needsReauth, hasLoginAction {
            return .dualEqualWidth
        }
        return .singleFullWidth
    }
}

struct ProviderUsageView: View {
    let provider: Provider
    let isEmbedded: Bool
    @State private var viewModel: ProviderUsageViewModel
    @State private var codexTrendSortKey: CodexTrendSortKey = .date
    @State private var codexTrendSortAscending = false
    @State private var selectedTrendDate: String?

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
            view.navigationTitle(usageNavigationTitle)
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
        .sheet(isPresented: $viewModel.isShowingLoginURLSheet, onDismiss: {
            viewModel.handleLoginURLSheetDismissed()
        }) {
            CodexLoginURLSheet(
                mode: viewModel.loginModeForSheet ?? "Login",
                url: viewModel.loginURLForSheet,
                onCopy: { viewModel.copyLoginURL() },
                onOpen: { viewModel.reopenLoginURLInBrowser() },
                onCancel: { viewModel.cancelCLILoginIfNeeded() }
            )
        }
        .fileImporter(
            isPresented: $viewModel.isShowingAuthFileImporter,
            allowedContentTypes: [.json, .data],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                Task { await viewModel.validateImportedAuthFiles(urls) }
            case .failure:
                viewModel.importedAuthFileURLs = []
                viewModel.pendingImportValidationResults = []
                viewModel.importValidationSummaryMessage = nil
            }
        }
        .alert(
            NSLocalizedString("codex.import.validate.title", value: "Import Validation", comment: "Import validation title"),
            isPresented: $viewModel.isShowingImportValidationConfirm
        ) {
            Button(NSLocalizedString("generic.cancel", value: "Cancel", comment: "Cancel"), role: .cancel) {}
            Button(NSLocalizedString("codex.import.apply_valid", value: "Import Valid Files", comment: "Import valid files")) {
                Task { await viewModel.applyValidatedImports() }
            }
        } message: {
            Text(viewModel.importValidationSummaryMessage ?? "")
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
        .alert(
            NSLocalizedString("codex.accounts.delete.title", value: "Delete Account", comment: "Delete account title"),
            isPresented: $viewModel.isShowingDeleteConfirm
        ) {
            Button(NSLocalizedString("generic.cancel", value: "Cancel", comment: "Cancel"), role: .cancel) {
                viewModel.pendingDeleteCodexAccount = nil
            }
            Button(NSLocalizedString("generic.delete", value: "Delete", comment: "Delete"), role: .destructive) {
                Task { await viewModel.confirmDeleteCodexAccount() }
            }
        } message: {
            let account = viewModel.pendingDeleteCodexAccount
            let baseName = account?.name ?? ""
            let email = account.flatMap { candidate in
                viewModel.codexAccountSummaries[candidate.id]?.email?.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let displayName: String = {
                guard let email, !email.isEmpty else { return baseName }
                return "\(baseName) (\(email))"
            }()
            let format = NSLocalizedString(
                "codex.accounts.delete.message",
                value: "Delete \"%@\"? This will not log you out of Codex, it only removes the saved snapshot in Nolon.",
                comment: "Delete account message"
            )
            Text(String(format: format, displayName))
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
        .overlay(alignment: .bottomTrailing) {
            if viewModel.isShowingCopyToast {
                ToastView(
                    text: viewModel.copyToastMessage,
                    systemImage: "doc.on.doc",
                    style: .success
                )
                .padding(.trailing, 16)
                .padding(.bottom, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: viewModel.isShowingCopyToast)
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

            if viewModel.usageProvider == .codex {
                ForEach(ProviderUsageHeaderAction.orderedActions(for: provider), id: \.self) { action in
                    switch action {
                    case .refreshAll:
                        Button(NSLocalizedString("codex.accounts.refresh_all", value: "刷新", comment: "Codex refresh all")) {
                            viewModel.handleHeaderRefreshButtonTap()
                        }
                        .disabled(viewModel.isLoading && !viewModel.isCodexHeaderRefreshing)
                    case .login:
                        Button(NSLocalizedString("codex.accounts.login", value: "登录", comment: "Codex login")) {
                            viewModel.startLoginFlow()
                        }
                        .disabled(viewModel.isRunningCLILogin)
                    case .importAuth:
                        Button(NSLocalizedString("codex.accounts.import", value: "导入", comment: "Codex import")) {
                            viewModel.beginImportAuthFiles()
                        }
                    }
                }
                actionsMenu
            } else {
                Button(NSLocalizedString("usage.monitor.login", value: "Sign in…", comment: "Sign in")) {
                    viewModel.isShowingLogin = true
                }
                actionsMenu
            }
        }
        .onChange(of: viewModel.settings) { _, newValue in
            viewModel.updateSettings(newValue)
        }
    }

    private var usageNavigationTitle: String {
        if provider.templateId == "codex" || provider.templateId == "codexXcode" {
            return NSLocalizedString("tab.account_usage", value: "账号与用量", comment: "Account and usage")
        }
        return NSLocalizedString("tab.usage", value: "Usage", comment: "Usage")
    }

    private var actionsMenu: some View {
        Menu {
            if viewModel.usageProvider != .codex {
                Button {
                    Task { await viewModel.load() }
                } label: {
                    Label(NSLocalizedString("usage.monitor.refresh", value: "Refresh", comment: "Refresh"), systemImage: "arrow.clockwise")
                }

                Divider()
            }

            Picker(selection: autoRefreshIntervalBinding) {
                ForEach(UsageAutoRefreshInterval.allCases) { option in
                    Text(option.title).tag(option.rawValue)
                }
            } label: {
                Label(
                    NSLocalizedString("usage.monitor.auto_refresh.title", value: "Auto refresh", comment: "Auto refresh interval"),
                    systemImage: "timer"
                )
            }

            if viewModel.usageProvider == .codex {
                if viewModel.isRunningCLILogin {
                    Button {
                        viewModel.cancelCLILoginIfNeeded()
                    } label: {
                        Label(
                            NSLocalizedString("codex.cli_login.cancel", value: "Cancel Login", comment: "Cancel CLI login"),
                            systemImage: "xmark.circle"
                        )
                    }
                }
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
                codexManagementCard

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

                if viewModel.isLoading && viewModel.codexAccountOutcomes.isEmpty {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text(NSLocalizedString("usage.monitor.refreshing", value: "Refreshing…", comment: "Refreshing status"))
                            .font(.caption)
                            .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    }
                }

                codexTrendSection
            }
            .padding(.trailing, 12)
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var codexManagementCard: some View {
        if let status = viewModel.codexManagementStatus, status.needsEnable || status.needsMigration {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("codex.management.title", value: "管理状态", comment: "Codex management status"))
                        .font(.headline)
                    Text(NSLocalizedString("codex.management.desc", value: "首次使用建议先启用管理并执行数据迁移。", comment: "Codex management description"))
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                }
                Spacer()
                Button(NSLocalizedString("codex.management.enable", value: "启用管理", comment: "Enable codex management")) {
                    Task { await viewModel.enableCodexManagement() }
                }
                Button(NSLocalizedString("codex.management.migrate", value: "数据迁移", comment: "Migrate codex data")) {
                    Task { await viewModel.migrateCodexManagementData() }
                }
            }
            .padding(12)
            .dsCard()
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
                codexTrendStackedBarChart(points: filteredTrendPoints(from: snapshot))
                codexTrendTable(points: filteredTrendPoints(from: snapshot))
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
                value: formatTokenCountCompact(snapshot.todayTokens)
            )
            summaryPill(
                title: NSLocalizedString("codex.usage.range.7d", value: "7D", comment: "7D"),
                value: formatTokenCountCompact(snapshot.last7DaysTokens)
            )
            summaryPill(
                title: NSLocalizedString("codex.usage.range.30d", value: "30D", comment: "30D"),
                value: formatTokenCountCompact(snapshot.last30DaysTokens)
            )
            summaryPill(
                title: NSLocalizedString("codex.usage.range.all", value: "ALL", comment: "ALL"),
                value: formatTokenCountCompact(snapshot.points.reduce(0) { $0 + $1.totalTokens })
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

    private func codexTrendStackedBarChart(points: [CodexTokenTrendPoint]) -> some View {
        let sortedPoints = points.sorted { $0.date < $1.date }
        let maxTotal = max(sortedPoints.map(\.totalTokens).max() ?? 1, 1)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                legendMark(title: "Input", color: DesignSystem.Colors.primary)
                legendMark(title: "Output", color: DesignSystem.Colors.Status.success)
                legendMark(title: "Cache", color: DesignSystem.Colors.Status.warning)
                Spacer()
            }
            .font(.caption2)

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(sortedPoints, id: \.date) { point in
                            let isSelected = selectedTrendDate == point.date
                            VStack(spacing: 6) {
                                VStack(spacing: 0) {
                                    segmentBlock(height: stackHeight(total: point.totalTokens, part: point.inputTokens, maxTotal: maxTotal), color: DesignSystem.Colors.primary)
                                    segmentBlock(height: stackHeight(total: point.totalTokens, part: point.outputTokens, maxTotal: maxTotal), color: DesignSystem.Colors.Status.success)
                                    segmentBlock(height: stackHeight(total: point.totalTokens, part: point.cacheReadTokens, maxTotal: maxTotal), color: DesignSystem.Colors.Status.warning)
                                }
                                .frame(width: 22)
                                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                                .overlay {
                                    if isSelected {
                                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                                            .stroke(DesignSystem.Colors.primary, lineWidth: 2)
                                    }
                                }
                                .frame(width: 28, height: 124, alignment: .bottom)
                                .opacity(selectedTrendDate == nil || isSelected ? 1 : 0.55)

                                Text(shortDateLabel(point.date))
                                    .font(.caption2)
                                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                            }
                            .id(point.date)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedTrendDate == point.date {
                                    selectedTrendDate = nil
                                } else {
                                    selectedTrendDate = point.date
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onChange(of: selectedTrendDate) { _, newValue in
                    guard let newValue else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
                .onAppear {
                    guard let selectedTrendDate else { return }
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(selectedTrendDate, anchor: .center)
                        }
                    }
                }
                .onChange(of: viewModel.codexTrendRange) { _, _ in
                    guard let selectedTrendDate else { return }
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(selectedTrendDate, anchor: .center)
                        }
                    }
                }
                .onChange(of: sortedPoints.map(\.date)) { _, dates in
                    guard let selectedTrendDate, dates.contains(selectedTrendDate) else {
                        if let selectedTrendDate, !dates.contains(selectedTrendDate) {
                            self.selectedTrendDate = nil
                        }
                        return
                    }
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(selectedTrendDate, anchor: .center)
                        }
                    }
                }
            }
            .onChange(of: selectedTrendDate) { _, newValue in
                guard let newValue else { return }
                if !sortedPoints.contains(where: { $0.date == newValue }) {
                    selectedTrendDate = nil
                }
            }
        }
    }

    private func legendMark(title: String, color: Color) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
                .frame(width: 10, height: 10)
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

    private func codexTrendTable(points: [CodexTokenTrendPoint]) -> some View {
        let rows = sortedTrendRows(points)
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
                let isSelected = selectedTrendDate == row.date
                HStack(spacing: 0) {
                    trendValueCell(row.date, width: 96, isDate: true)
                    trendValueCell(formatTokenCompact(row.totalTokens), width: 108)
                    trendValueCell(formatTokenCompact(row.inputTokens), width: 108)
                    trendValueCell(formatTokenCompact(row.outputTokens), width: 108)
                    trendValueCell(formatTokenCompact(row.cacheReadTokens), width: 108)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 6)
                .background(
                    isSelected
                    ? DesignSystem.Colors.primary.opacity(0.14)
                    : (index.isMultiple(of: 2) ? DesignSystem.Colors.Background.surface : Color.clear)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    if selectedTrendDate == row.date {
                        selectedTrendDate = nil
                    } else {
                        selectedTrendDate = row.date
                    }
                }
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
                        .font(.body)
                }
            }
            .frame(width: width, alignment: .center)
            .font(.body)
            .foregroundStyle(DesignSystem.Colors.Text.secondary)
        }
        .buttonStyle(.plain)
    }

    private func trendValueCell(_ value: String, width: CGFloat, isDate: Bool = false) -> some View {
        Text(value)
            .frame(width: width, alignment: .center)
            .font(.body)
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

    private func formatTokenCountCompact(_ value: Int?) -> String {
        guard let value else { return "-" }
        return formatTokenCompact(value)
    }

    private func formatTokenCompact(_ value: Int) -> String {
        TokenCountCompactFormatter.format(value)
    }

    private func shortDateLabel(_ value: String) -> String {
        let parts = value.split(separator: "-")
        guard parts.count == 3 else { return value }
        return "\(parts[1])/\(parts[2])"
    }

    private func filteredTrendPoints(from snapshot: CodexTokenTrendSnapshot) -> [CodexTokenTrendPoint] {
        let sorted = snapshot.points.sorted { $0.date > $1.date }
        switch viewModel.codexTrendRange {
        case .days7:
            return Array(sorted.prefix(7))
        case .days30:
            return Array(sorted.prefix(30))
        case .all:
            return sorted
        }
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
        let displayState = viewModel.displayState(accountID: accountId, outcome: outcome, summary: summary)
        let statusTitle = codexAccountStatusTitle(for: displayState)
        let lastSync = summary?.lastSyncSucceededAt
        let liveFailureError: Error? = {
            if case let .failure(error) = outcome.outcome.result { return error }
            return nil
        }()
        let persistedFailureDetail = summary?.lastSyncFailureMessage?.trimmingCharacters(in: .whitespacesAndNewlines)
        let failureDetail: String? = {
            if let persistedFailureDetail, !persistedFailureDetail.isEmpty { return persistedFailureDetail }
            if let liveFailureError { return ProviderUsageViewModel.errorDetailText(error: liveFailureError) }
            return nil
        }()
        let failureSummary: String? = {
            if let liveFailureError {
                return ProviderUsageViewModel.errorSummaryText(error: liveFailureError)
            }
            if let failureDetail {
                if CodexAuthFailureClassifier.isAuthFailure(errorText: failureDetail) {
                    return NSLocalizedString(
                        "codex.accounts.error.auth_expired",
                        value: "Authentication expired. Please sign in again.",
                        comment: "Codex auth expired summary"
                    )
                }
                return failureDetail
            }
            return nil
        }()

        codexCompactSnapshotView(
            outcome: outcome,
            isSelected: isSelected,
            isRefreshing: isRefreshing,
            summary: summary,
            onRefresh: accountId.map { id in
                { viewModel.refreshCodexAccount(id: id) }
            },
            onLogin: onLogin,
            isLoggingIn: isLoggingIn
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
                } label: {
                    Label(statusTitle, systemImage: "circle.fill")
                }
                .disabled(true)

                if isRefreshing {
                    Button {} label: {
                        Label(
                            NSLocalizedString("usage.monitor.refreshing", value: "Refreshing…", comment: "Refreshing status"),
                            systemImage: "arrow.trianglehead.clockwise"
                        )
                    }
                        .disabled(true)
                }

                if let failureSummary {
                    Button {} label: {
                        Label(failureSummary, systemImage: "exclamationmark.triangle")
                    }
                        .disabled(true)
                }

                if let lastSync {
                    let prefix = NSLocalizedString("codex.accounts.sync.success", value: "Last sync", comment: "Last sync label")
                    Button {} label: {
                        Label(
                            "\(prefix): \(lastSync.formatted(date: .abbreviated, time: .shortened))",
                            systemImage: "clock"
                        )
                    }
                        .disabled(true)
                }

                Divider()

                Button {
                    viewModel.refreshCodexAccount(id: accountId)
                } label: {
                    Label(NSLocalizedString("usage.monitor.refresh", value: "Refresh", comment: "Refresh"), systemImage: "arrow.clockwise")
                }
                .disabled(isRefreshing)

                if !isActive {
                    Button {
                        viewModel.requestActivateCodexAccount(id: accountId)
                    } label: {
                        Label(
                            NSLocalizedString("codex.accounts.action.activate", value: "Activate", comment: "Activate account"),
                            systemImage: "checkmark.circle"
                        )
                    }
                }

                if let onLogin {
                    Button {
                        onLogin()
                    } label: {
                        Label(
                            NSLocalizedString("codex.accounts.relogin", value: "Re-login", comment: "Re-login account"),
                            systemImage: "person.badge.key"
                        )
                    }
                    .disabled(!canLogin || isLoggingIn)
                }

                if let failureDetail {
                    Button {
                        viewModel.copyErrorText(failureDetail)
                    } label: {
                        Label(
                            NSLocalizedString("codex.accounts.copy_error", value: "Copy error", comment: "Copy account error"),
                            systemImage: "doc.on.doc"
                        )
                    }
                }

                if isLoggingIn {
                    Button {} label: {
                        Label(
                            NSLocalizedString("codex.accounts.add.cli.running", value: "Logging in…", comment: "CLI login running status"),
                            systemImage: "hourglass"
                        )
                    }
                        .disabled(true)
                }

                Divider()

                Button {
                    viewModel.revealCodexAccountInFinder(id: accountId)
                } label: {
                    Label(NSLocalizedString("action.show_in_finder", comment: "Show in Finder"), systemImage: "folder")
                }

                Button {
                    viewModel.copyCodexAccountID(id: accountId)
                } label: {
                    Label(
                        NSLocalizedString("codex.accounts.menu.copy_account_id", value: "Copy Account ID", comment: "Copy account id"),
                        systemImage: "number"
                    )
                }

                Button {
                    viewModel.copyCodexAccountPath(id: accountId)
                } label: {
                    Label(
                        NSLocalizedString("codex.accounts.menu.copy_auth_path", value: "Copy Auth Path", comment: "Copy auth path"),
                        systemImage: "doc.text"
                    )
                }

                Divider()

                Button(role: .destructive) {
                    viewModel.requestDeleteCodexAccount(id: accountId)
                } label: {
                    Label(NSLocalizedString("codex.accounts.delete.title", value: "Delete Account", comment: "Delete account title"), systemImage: "trash")
                }
            }
        }
    }

    private func codexAccountStatusTitle(for state: ProviderUsageViewModel.CodexAccountDisplayState) -> String {
        switch state {
        case .healthy:
            return NSLocalizedString("codex.accounts.status.normal", value: "Normal", comment: "Account status normal")
        case .pending:
            return NSLocalizedString("codex.accounts.status.pending", value: "Pending", comment: "Account status pending")
        case .needsReauth:
            return NSLocalizedString("codex.accounts.status.reauth_needed", value: "Needs re-login", comment: "Account status reauth")
        case .failed:
            return NSLocalizedString("codex.accounts.status.failed", value: "Failed", comment: "Account status failed")
        }
    }

    @ViewBuilder
    private func codexCompactSnapshotView(
        outcome: ProviderAccountUsageOutcome,
        isSelected: Bool,
        isRefreshing: Bool,
        summary: CodexAuthSummary?,
        onRefresh: (() -> Void)?,
        onLogin: (() -> Void)?,
        isLoggingIn: Bool
    ) -> some View {
        let accountId: UUID? = {
            switch outcome.account {
            case .default:
                return nil
            case let .tokenAccount(account):
                return account.id
            }
        }()
        let title = outcome.displayName
        let fallbackEmail = summary?.email?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackPlan = summary?.plan?.trimmingCharacters(in: .whitespacesAndNewlines)
        let lastLogin = summary?.lastLoginAt
        let lastSync = summary?.lastSyncSucceededAt
        let loginInlineText: String? = {
            guard let lastLogin else { return nil }
            return String(
                format: NSLocalizedString(
                    "codex.accounts.time.login.inline",
                    value: "Login %@",
                    comment: "Inline login time"
                ),
                CodexAccountInlineTimeFormatter.loginTimestamp(lastLogin)
            )
        }()
        let syncInlineText: String? = {
            guard let lastSync else { return nil }
            let syncDisplay = CodexAccountInlineTimeFormatter.syncDisplay(
                since: lastSync,
                isChinese: isChineseLocale
            )
            switch syncDisplay {
            case .justNow:
                return NSLocalizedString(
                    "codex.accounts.time.sync.just_now",
                    value: "Synced just now",
                    comment: "Inline sync just now text"
                )
            case let .relative(relativeText):
                return String(
                    format: NSLocalizedString(
                        "codex.accounts.time.sync.inline",
                        value: "Synced %@ ago",
                        comment: "Inline sync ago time"
                    ),
                    relativeText
                )
            case let .absolute(absoluteText):
                return String(
                    format: NSLocalizedString(
                        "codex.accounts.time.sync.absolute",
                        value: "Synced %@",
                        comment: "Inline absolute sync time"
                    ),
                    absoluteText
                )
            }
        }()
        let inlineTimeLineText = CodexAccountInlineTimeFormatter.joinInlineTimeLine(
            loginSegment: loginInlineText,
            syncSegment: syncInlineText
        )
        let displayState = viewModel.displayState(accountID: accountId, outcome: outcome, summary: summary)
        let liveFailureError: Error? = {
            if case let .failure(error) = outcome.outcome.result { return error }
            return nil
        }()
        let persistedFailureDetail = summary?.lastSyncFailureMessage?.trimmingCharacters(in: .whitespacesAndNewlines)
        let failureDetail: String? = {
            if let persistedFailureDetail, !persistedFailureDetail.isEmpty { return persistedFailureDetail }
            if let liveFailureError { return ProviderUsageViewModel.errorDetailText(error: liveFailureError) }
            return nil
        }()
        let failureSummary: String? = {
            if let liveFailureError {
                return ProviderUsageViewModel.errorSummaryText(error: liveFailureError)
            }
            if let failureDetail {
                if CodexAuthFailureClassifier.isAuthFailure(errorText: failureDetail) {
                    return NSLocalizedString(
                        "codex.accounts.error.auth_expired",
                        value: "Authentication expired. Please sign in again.",
                        comment: "Codex auth expired summary"
                    )
                }
                return failureDetail
            }
            return nil
        }()
        let needsReauth = displayState == .needsReauth
        let shouldShowUsageMetrics = failureSummary == nil && (displayState == .healthy || displayState == .pending)
        let statusKind = CodexUsageCardPresentationPolicy.statusKind(for: displayState)
        let statusColor = statusColor(for: statusKind)

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
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
                if shouldShowUsageMetrics, result.usage.primary != nil || result.usage.secondary != nil || result.usage.tertiary != nil {
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
            case .failure:
                if let subtitle = codexSubtitleText(title: title, email: fallbackEmail, plan: fallbackPlan) {
                    Text(subtitle)
                        .font(.caption)
                        .dsSecondaryText(font: .caption)
                        .lineLimit(1)
                }
            }

            if let failureSummary, let failureDetail {
                VStack(alignment: .leading, spacing: 6) {
                    Text(failureSummary)
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.Text.primary)
                        .lineLimit(2)

                    let actionLayout = CodexUsageCardPresentationPolicy.actionLayout(
                        needsReauth: needsReauth,
                        hasLoginAction: onLogin != nil
                    )
                    if actionLayout == .dualEqualWidth, let onLogin {
                        HStack(spacing: 8) {
                            Button {
                                viewModel.copyErrorText(failureDetail)
                            } label: {
                                Text(NSLocalizedString("codex.accounts.copy_error", value: "Copy error", comment: "Copy account error"))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .frame(maxWidth: .infinity)

                            Button {
                                onLogin()
                            } label: {
                                Text(NSLocalizedString("codex.accounts.relogin", value: "Re-login", comment: "Re-login account"))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .frame(maxWidth: .infinity)
                            .disabled(isLoggingIn)
                        }
                    } else {
                        Button {
                            viewModel.copyErrorText(failureDetail)
                        } label: {
                            Text(NSLocalizedString("codex.accounts.copy_error", value: "Copy error", comment: "Copy account error"))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                    }

                    if isLoggingIn {
                        Text(NSLocalizedString("codex.accounts.add.cli.running", value: "Logging in…", comment: "CLI login running status"))
                            .font(.caption2)
                            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                    }
                }
            }

            if let inlineTimeLineText {
                Text(inlineTimeLineText)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .multilineTextAlignment(.trailing)
            }

        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .textSelection(.enabled)
        .dsCard(background: .clear, borderColor: nil, borderWidth: 0)
    }

    private func statusColor(for statusKind: CodexUsageCardStatusKind) -> Color {
        switch statusKind {
        case .error:
            return DesignSystem.Colors.Status.error
        case .healthy:
            return DesignSystem.Colors.Status.success
        case .pending:
            return DesignSystem.Colors.Text.secondary
        }
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
