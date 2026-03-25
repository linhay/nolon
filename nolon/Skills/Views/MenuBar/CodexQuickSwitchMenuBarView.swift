import SwiftUI
import AppKit
import Observation
import ProviderCatalog
import ProviderUsage
import NolonResourceKit
import STFilePath
import Combine

enum CodexQuickSwitchProviderResolver {
    static func providers(from providers: [Provider]) -> [Provider] {
        let acceptedTemplateIDs: Set<String> = [
            ProviderTemplate.codex.rawValue.lowercased(),
            ProviderTemplate.codexXcode.rawValue.lowercased(),
            ProviderTemplate.gemini.rawValue.lowercased()
        ]
        return providers.filter { provider in
            acceptedTemplateIDs.contains((provider.templateId ?? "").lowercased())
        }
    }

    static func resolve(from providers: [Provider], preferredProviderID: Provider.ID? = nil) -> Provider? {
        let candidates = self.providers(from: providers)
        if let preferredProviderID,
           let preferred = candidates.first(where: { $0.id == preferredProviderID }) {
            return preferred
        }
        return candidates.first
    }
}

enum CodexQuickSwitchUsageFormatter {
    static func summaryLine(usage: UsageSnapshot?, now: Date = Date()) -> String? {
        guard let usage else { return nil }
        let windows = usage.allWindows
        guard !windows.isEmpty else { return nil }

        let shortWindow = preferredShortWindow(from: windows) ?? windows.first
        let weeklyWindow = preferredWeeklyWindow(from: windows)

        guard let shortWindow else { return nil }

        var parts: [String] = [windowText(window: shortWindow.window, title: shortWindowTitle(for: shortWindow.window), now: now)]
        if let weeklyWindow {
            parts.append(windowText(window: weeklyWindow.window, title: "weekly", now: now, usesAbsoluteResetDate: true))
        }
        return parts.joined(separator: " · ")
    }

    private static func preferredShortWindow(from windows: [UsageWindow]) -> UsageWindow? {
        windows
            .filter { ($0.window.windowMinutes ?? Int.max) < 24 * 60 }
            .min(by: { lhs, rhs in
                let left = abs((lhs.window.windowMinutes ?? 300) - 300)
                let right = abs((rhs.window.windowMinutes ?? 300) - 300)
                return left < right
            })
    }

    private static func preferredWeeklyWindow(from windows: [UsageWindow]) -> UsageWindow? {
        windows.min(by: { lhs, rhs in
            let left = abs((lhs.window.windowMinutes ?? 10_080) - 10_080)
            let right = abs((rhs.window.windowMinutes ?? 10_080) - 10_080)
            return left < right
        })
    }

    private static func shortWindowTitle(for window: RateWindow) -> String {
        guard let minutes = window.windowMinutes, minutes > 0 else { return "5h" }
        if minutes % (24 * 60) == 0 {
            return "\(minutes / (24 * 60))d"
        }
        if minutes % 60 == 0 {
            return "\(minutes / 60)h"
        }
        return "\(minutes)m"
    }

    private static func windowText(window: RateWindow, title: String, now: Date, usesAbsoluteResetDate: Bool = false) -> String {
        let remainingPercent = max(0, Int(round(window.remainingPercent)))
        let resetText: String
        if usesAbsoluteResetDate, let resetsAt = window.resetsAt {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "MM/dd HH:mm"
            resetText = formatter.string(from: resetsAt)
        } else {
            resetText = remainingText(until: window.resetsAt, now: now)
        }
        return "\(title) \(remainingPercent)% (\(resetText))"
    }

    private static func remainingText(until resetsAt: Date?, now: Date) -> String {
        guard let resetsAt else { return "--:--" }
        let remaining = max(0, Int(resetsAt.timeIntervalSince(now)))
        let hours = remaining / 3600
        let minutes = (remaining % 3600) / 60
        return String(format: "%02d:%02d", hours, minutes)
    }
}

@MainActor
@Observable
final class CodexQuickSwitchMenuBarViewModel {
    struct Row: Identifiable, Equatable {
        let id: UUID
        let title: String
        let detail: String?
        let isActive: Bool
        let usageWindows: [UsageWindow]
        
        var isExhausted: Bool {
            usageWindows.contains { $0.window.remainingPercent <= 0.1 }
        }
    }

    private let settings: ProviderSettings
    private var usageRootViewModel: ProviderUsageRootViewModel?
    private let userDefaults: UserDefaults
    private static let selectedProviderIDDefaultsKey = "menu.codex.quick_switch.selected_provider_id"

    var rows: [Row] {
        guard let usageRootViewModel else { return [] }
        return Self.makeRows(from: usageRootViewModel.accountsViewModel)
    }
    
    var activeRows: [Row] {
        rows.filter { $0.isActive }
    }
    
    var availableRows: [Row] {
        rows.filter { !$0.isActive && !$0.isExhausted }
    }
    
    var exhaustedRows: [Row] {
        rows.filter { !$0.isActive && $0.isExhausted }
    }
    
    var availableProviders: [Provider] = []
    var isLoading = false
    var providerDisplayName: String = "Codex"
    var selectedProviderID: Provider.ID?

    private(set) var provider: Provider?

    init(settings: ProviderSettings, userDefaults: UserDefaults = .standard) {
        self.settings = settings
        self.userDefaults = userDefaults
        self.selectedProviderID = userDefaults.string(forKey: Self.selectedProviderIDDefaultsKey)
        self.availableProviders = CodexQuickSwitchProviderResolver.providers(from: settings.providers)
        self.provider = CodexQuickSwitchProviderResolver.resolve(from: settings.providers, preferredProviderID: selectedProviderID)
        self.providerDisplayName = provider?.name ?? "Codex"
    }

    func reload() async {
        availableProviders = CodexQuickSwitchProviderResolver.providers(from: settings.providers)
        provider = CodexQuickSwitchProviderResolver.resolve(from: settings.providers, preferredProviderID: selectedProviderID)
        if provider == nil {
            selectedProviderID = nil
            userDefaults.removeObject(forKey: Self.selectedProviderIDDefaultsKey)
        } else if let provider {
            selectedProviderID = provider.id
            userDefaults.set(provider.id, forKey: Self.selectedProviderIDDefaultsKey)
        }
        providerDisplayName = provider?.name ?? "Codex"
        guard let provider else {
            usageRootViewModel = nil
            return
        }

        if usageRootViewModel?.provider.id != provider.id {
            usageRootViewModel = ProviderUsageRootViewModelStore.shared.viewModel(for: provider)
        }
        guard let usageRootViewModel else { return }

        isLoading = true
        defer { isLoading = false }
        await usageRootViewModel.load()
    }

    func selectProvider(id: Provider.ID) async {
        guard availableProviders.contains(where: { $0.id == id }) else { return }
        selectedProviderID = id
        userDefaults.set(id, forKey: Self.selectedProviderIDDefaultsKey)
        await reload()
    }

    func activateAccount(id: UUID) async {
        guard let usageRootViewModel else { return }
        _ = await usageRootViewModel.accountsViewModel.codex.activateAccount(id: id)
    }

    func refreshQuotas() async {
        guard let usageRootViewModel else { return }
        for account in usageRootViewModel.accountsViewModel.codex.accounts {
            await usageRootViewModel.accountsViewModel.codex.refreshAccountImmediately(id: account.id)
        }
    }

    func deleteAccount(id: UUID) async {
        guard let usageRootViewModel else { return }
        usageRootViewModel.accountsViewModel.codex.requestDeleteAccount(id: id)
        await usageRootViewModel.accountsViewModel.codex.confirmDeleteAccount()
    }

    func openAuthJSON() {
        guard let provider else { return }
        NSWorkspace.shared.open(provider.codexHomeFolder.file("auth.json").url)
    }

    func openConfigTOML() {
        guard let provider else { return }
        NSWorkspace.shared.open(provider.codexHomeFolder.file("config.toml").url)
    }

    private static func makeRows(from accountsViewModel: ProviderUsageAccountsViewModel) -> [Row] {
        let outcomesByAccountID: [UUID: ProviderAccountUsageOutcome] = Dictionary(
            uniqueKeysWithValues: accountsViewModel.codex.accountOutcomes.compactMap { outcome -> (UUID, ProviderAccountUsageOutcome)? in
                guard case let .tokenAccount(account) = outcome.account else { return nil }
                return (account.id, outcome)
            }
        )

        return accountsViewModel.codex.accounts
            .sorted { lhs, rhs in
                lhs.createdAt > rhs.createdAt
            }
            .map { account in
                let summary = accountsViewModel.codex.accountSummaries[account.id]
                let outcome = outcomesByAccountID[account.id]
                let usage: UsageSnapshot? = {
                    guard let outcome else { return nil }
                    if case let .success(result) = outcome.outcome.result {
                        return result.usage
                    }
                    return nil
                }()

                return Row(
                    id: account.id,
                    title: summary?.email?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                        ? (summary?.email ?? account.name)
                        : account.name,
                    detail: CodexQuickSwitchUsageFormatter.summaryLine(usage: usage),
                    isActive: accountsViewModel.codex.activeAccountId == account.id,
                    usageWindows: usage?.allWindows ?? []
                )
            }
    }
}

struct CodexQuickSwitchMenuBarView: View, DebugPageLocatable {
    @Environment(\.openWindow) private var openWindow
    @State private var viewModel = CodexQuickSwitchMenuBarViewModel(settings: ProviderSettings.shared)
    @State private var hoveredRowID: UUID?
    @State private var isExhaustedExpanded = false
    private let refreshTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var debugPageMarkerItems: [PageMarkerItem] {
        var items = [
            PageMarkerItem(title: "Menu Bar"),
            PageMarkerItem(title: "Codex Quick Switch")
        ]
        if !viewModel.providerDisplayName.isEmpty {
            items.append(PageMarkerItem(title: viewModel.providerDisplayName))
        }
        return items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    if viewModel.rows.isEmpty {
                        emptyStateView
                    } else {
                        // 1. Active Account Section
                        if !viewModel.activeRows.isEmpty {
                            sectionHeader(title: "当前活跃")
                            ForEach(viewModel.activeRows) { row in
                                accountCard(row)
                            }
                        }
                        
                        // 2. Available Accounts Section
                        if !viewModel.availableRows.isEmpty {
                            sectionHeader(title: "可用账号")
                            ForEach(viewModel.availableRows) { row in
                                accountCard(row)
                            }
                        }
                        
                        // 3. Exhausted Section
                        if !viewModel.exhaustedRows.isEmpty {
                            exhaustedGroup
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .frame(minHeight: 300, maxHeight: 1500)

            Divider()
                .opacity(0.5)

            footerToolbarSection
                .padding(12)
        }
        .frame(width: 360)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .debugPageLocator(debugPageMarkerItems)
        .task {
            await viewModel.reload()
        }
        .onReceive(refreshTimer) { _ in
            Task { await viewModel.reload() }
        }
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("快速切换账号")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(DesignSystem.Colors.Text.primary)

                providerPicker
            }
            
            Spacer()
            
            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button {
                    Task { await viewModel.reload() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var providerPicker: some View {
        Group {
            if viewModel.availableProviders.count > 1 {
                Menu {
                    ForEach(viewModel.availableProviders, id: \.id) { provider in
                        Button {
                            Task { await viewModel.selectProvider(id: provider.id) }
                        } label: {
                            HStack {
                                Text(provider.name)
                                if provider.id == viewModel.selectedProviderID {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(viewModel.providerDisplayName)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 8))
                    }
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(DesignSystem.Colors.primary.opacity(0.15))
                    .foregroundStyle(DesignSystem.Colors.primary)
                    .clipShape(Capsule())
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            } else {
                Text(viewModel.providerDisplayName)
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(DesignSystem.Colors.primary.opacity(0.15))
                    .foregroundStyle(DesignSystem.Colors.primary)
                    .clipShape(Capsule())
            }
        }
    }

    private func sectionHeader(title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .black))
            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
            .padding(.leading, 4)
    }

    private func accountCard(_ row: CodexQuickSwitchMenuBarViewModel.Row) -> some View {
        Button {
            Task { await viewModel.activateAccount(id: row.id) }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(row.isActive ? DesignSystem.Colors.Text.primary : (row.isExhausted ? DesignSystem.Colors.Text.tertiary : DesignSystem.Colors.Text.secondary))
                            .lineLimit(1)
                        
                        if let detail = row.detail, !detail.isEmpty {
                            Text(detail)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    if row.isActive {
                        Text("ACTIVE")
                            .font(.system(size: 9, weight: .black))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DesignSystem.Colors.primary)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                
                if !row.usageWindows.isEmpty {
                    VStack(spacing: 6) {
                        ForEach(row.usageWindows) { window in
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(window.title.uppercased())
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                                    Spacer()
                                    Text("\(Int(window.window.remainingPercent))%")
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Int(window.window.remainingPercent) <= 10 ? DesignSystem.Colors.Status.error : DesignSystem.Colors.Text.secondary)
                                }
                                usageProgressBar(remainingPercent: window.window.remainingPercent, title: window.title)
                            }
                        }
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(row.isActive ? DesignSystem.Colors.primary.opacity(0.06) : DesignSystem.Colors.Background.elevated.opacity(0.4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(row.isActive ? DesignSystem.Colors.primary.opacity(0.4) : DesignSystem.Colors.Component.border.opacity(0.3), lineWidth: row.isActive ? 2 : 1)
            )
            .shadow(color: row.isActive ? DesignSystem.Colors.primary.opacity(0.1) : Color.clear, radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            withAnimation(.easeOut(duration: 0.15)) {
                hoveredRowID = isHovered ? row.id : nil
            }
        }
        .scaleEffect(hoveredRowID == row.id ? 1.01 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hoveredRowID)
    }

    private var exhaustedGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(DesignSystem.Animations.springQuick) {
                    isExhaustedExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .black))
                        .rotationEffect(.degrees(isExhaustedExpanded ? 90 : 0))
                    
                    Text("已耗尽账号")
                        .font(.system(size: 10, weight: .bold))
                    
                    Spacer()
                    
                    Text("\(viewModel.exhaustedRows.count)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(DesignSystem.Colors.Component.controlFillSubtle)
                        .clipShape(Capsule())
                }
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                .padding(.vertical, 4)
                .padding(.horizontal, 4)
            }
            .buttonStyle(.plain)
            
            if isExhaustedExpanded {
                VStack(spacing: 10) {
                    ForEach(viewModel.exhaustedRows) { row in
                        accountCard(row)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            }
        }
    }

    private func usageProgressBar(remainingPercent: Double, title: String) -> some View {
        let normalized = max(0, min(100, remainingPercent))
        let color: Color = {
            if normalized <= 0.1 { return DesignSystem.Colors.Status.error }
            let t = title.lowercased()
            if t.contains("request") || t.contains("primary") { return DesignSystem.Colors.primary }
            if t.contains("token") || t.contains("secondary") { return DesignSystem.Colors.secondary }
            return DesignSystem.Colors.Status.success
        }()
        
        return ZStack(alignment: .leading) {
            Capsule()
                .fill(DesignSystem.Colors.Component.border.opacity(0.2))
                .frame(height: 6)
            
            Capsule()
                .fill(color)
                .frame(width: max(6, 328 * (normalized / 100.0)), height: 6)
        }
    }

    private var footerToolbarSection: some View {
        HStack(spacing: 12) {
            // Action buttons as icons
            HStack(spacing: 8) {
                actionIconButton(systemName: "plus", tooltip: "添加账号") {
                    guard let provider = viewModel.provider else { return }
                    AppCommandState.shared.pendingNavigation = .providerTab(providerID: provider.id, tab: .usage)
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "main")
                }
                
                actionIconButton(systemName: "arrow.clockwise", tooltip: "刷新配额") {
                    Task { await viewModel.refreshQuotas() }
                }
                
                actionIconButton(systemName: "lock.doc.fill", tooltip: "auth.json") {
                    viewModel.openAuthJSON()
                }
                
                actionIconButton(systemName: "gearshape.fill", tooltip: "config.toml") {
                    viewModel.openConfigTOML()
                }
            }
            
            Spacer()
            
            Button {
                NSApp.terminate(nil)
            } label: {
                Text("退出")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
            }
            .buttonStyle(.plain)
        }
    }
    
    private func actionIconButton(systemName: String, tooltip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 32, height: 32)
                .background(DesignSystem.Colors.Component.controlFillSubtle)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 32))
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
            Text("暂无可用账号")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
