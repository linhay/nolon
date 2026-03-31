import SwiftUI
import AppKit
import Observation
import CodexBarProviderCatalog
import ProviderCatalog
import ProviderUsage
import NolonResourceKit
import STFilePath
import Combine
import NolonUI
import NolonUIFoundation

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

    private enum ListLayout {
        static let usageColumnWidth: CGFloat = 232
    }

    private let settings: ProviderSettings
    private var usageRootViewModel: ProviderUsageRootViewModel?
    private let userDefaults: UserDefaults
    private static let selectedProviderIDDefaultsKey = "menu.codex.quick_switch.selected_provider_id"

    var rows: [Row] {
        guard let usageRootViewModel else { return [] }
        return Self.makeRows(from: usageRootViewModel.accountsViewModel)
    }

    var tableSections: [NolonUI.AccountListModeSection] {
        guard let usageRootViewModel else { return [] }
        let accountsViewModel = usageRootViewModel.accountsViewModel
        let isRunningCLILogin = usageRootViewModel.loginFlowViewModel.isRunningCLILogin
        let items = Self.makeTableItems(
            from: accountsViewModel,
            isRunningCLILogin: isRunningCLILogin
        )
        guard !items.isEmpty else { return [] }
        return [.init(id: "menu-codex-usage-list", items: items)]
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

    private static func makeTableItems(
        from accountsViewModel: ProviderUsageAccountsViewModel,
        isRunningCLILogin: Bool
    ) -> [NolonUI.AccountListModeItem] {
        accountsViewModel.codex.accountOutcomes.map { outcome in
            let model = accountsViewModel.codex.makeUsageCardModel(
                outcome: outcome,
                hasActiveGatewayCardSelection: false,
                isRunningCLILogin: isRunningCLILogin
            )
            return NolonUI.AccountListModeItem(
                id: model.data.id,
                presentation: model.presentation,
                header: model.data.header,
                usageWindows: compactUsageWindows(from: model.data),
                menuActions: []
            )
        }
    }

    private static func compactUsageWindows(from data: AccountCardViewData) -> [NolonUI.AccountListModeUsageWindow] {
        guard case let .quota(quota) = data.body, let usage = quota.usage else {
            return [.init(id: "none", title: "-", progress: 0, percentText: "0%")]
        }
        let metadata = ProviderUsageRegistry.metadata(for: quota.provider)
        return ProviderQuotaSection
            .displayWindows(for: usage, provider: quota.provider)
            .prefix(3)
            .map { item in
                let title: String
                switch item.id {
                case "primary":
                    title = metadata?.sessionLabel ?? "Session"
                case "secondary":
                    title = metadata?.weeklyLabel ?? "Weekly"
                default:
                    title = item.title
                }
                let normalized = max(0, min(100, item.window.remainingPercent.isInfinite ? 100 : item.window.remainingPercent))
                return .init(
                    id: item.id,
                    title: title,
                    progress: CGFloat(normalized / 100),
                    percentText: item.window.remainingPercent.isInfinite ? "∞" : String(format: "%.0f%%", normalized)
                )
            }
    }
}

struct CodexQuickSwitchMenuBarView: View, DebugPageLocatable {
    @Environment(\.openWindow) private var openWindow
    @State private var viewModel = CodexQuickSwitchMenuBarViewModel(settings: ProviderSettings.shared)
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
        NolonUI.MaterialPanelScaffold {
            headerSection
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)
        } content: {
            NolonUI.PaddedScrollContainer(
                showsIndicators: false,
                padding: EdgeInsets(top: 0, leading: 0, bottom: 16, trailing: 0),
                minHeight: 300,
                maxHeight: 1500
            ) {
                if menuTableItems.isEmpty {
                    emptyStateView
                        .padding(.horizontal, 16)
                } else {
                    menuTableRows
                }
            }
        } footer: {
            footerToolbarSection
                .padding(12)
        }
        .debugPageLocator(debugPageMarkerItems)
        .task {
            await viewModel.reload()
        }
        .onReceive(refreshTimer) { _ in
            Task { await viewModel.reload() }
        }
    }

    private var headerSection: some View {
        NolonUI.QuickSwitchHeaderView(
            data: .init(
                providerDisplayName: viewModel.providerDisplayName,
                providers: viewModel.availableProviders.map { provider in
                    .init(
                        id: provider.id,
                        name: provider.name,
                        isSelected: provider.id == viewModel.selectedProviderID
                    )
                },
                isLoading: viewModel.isLoading
            ),
            onSelectProvider: { providerID in
                Task { await viewModel.selectProvider(id: providerID) }
            },
            onRefresh: {
                Task { await viewModel.reload() }
            }
        )
    }

    private var footerToolbarSection: some View {
        NolonUI.QuickSwitchFooterToolbarView(
            data: .init(),
            onTapAction: { actionID in
                switch actionID {
                case "add":
                    guard let provider = viewModel.provider else { return }
                    AppCommandState.shared.pendingNavigation = .providerTab(providerID: provider.id, tab: .usage)
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "main")
                case "refresh":
                    Task { await viewModel.refreshQuotas() }
                case "auth":
                    viewModel.openAuthJSON()
                case "config":
                    viewModel.openConfigTOML()
                default:
                    break
                }
            },
            onTapQuit: {
                NSApp.terminate(nil)
            }
        )
    }

    private var emptyStateView: some View {
        NolonUI.QuickSwitchEmptyStateView()
    }

    private var menuTableItems: [NolonUI.AccountListModeItem] {
        viewModel.tableSections.flatMap { $0.items }
    }

    private var menuTableRows: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(menuTableItems.enumerated()), id: \.element.id) { index, item in
                menuTableRow(item)

                if index < menuTableItems.count - 1 {
                    Divider()
                        .overlay(DesignSystem.Colors.Component.border.opacity(0.25))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func menuTableRow(_ item: NolonUI.AccountListModeItem) -> some View {
        let rowContent = VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Circle()
                    .fill(statusColor(for: item))
                    .frame(width: 6, height: 6)

                Text(item.header.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.Text.primary)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(item.usageWindows) { window in
                    HStack(spacing: 8) {
                        Text(window.title)
                            .font(.caption2)
                            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                            .frame(width: 56, alignment: .leading)

                        NolonUI.AccountInlineQuotaProgress(
                            progress: window.progress,
                            percentText: window.percentText
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())

        if item.menuActions.isEmpty {
            rowContent
                .onTapGesture {
                    guard let id = UUID(uuidString: item.id) else { return }
                    Task { await viewModel.activateAccount(id: id) }
                }
        } else {
            rowContent
                .contextMenu {
                    ForEach(item.menuActions) { action in
                        Button(role: action.role) {
                            // Currently no menu actions in quick switch; keep for future extension.
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
                .onTapGesture {
                    guard let id = UUID(uuidString: item.id) else { return }
                    Task { await viewModel.activateAccount(id: id) }
                }
        }
    }

    private func statusColor(for item: NolonUI.AccountListModeItem) -> Color {
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
        case .selected:
            return DesignSystem.Colors.primary
        case .neutral:
            return DesignSystem.Colors.Text.secondary
        }
    }
}
