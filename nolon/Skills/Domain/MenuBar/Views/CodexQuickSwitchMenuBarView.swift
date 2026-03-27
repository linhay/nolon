import SwiftUI
import AppKit
import Observation
import ProviderCatalog
import ProviderUsage
import NolonResourceKit
import STFilePath
import Combine
import NolonUI

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
        NolonUI.MaterialPanelScaffold {
            headerSection
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)
        } content: {
            NolonUI.PaddedScrollContainer(
                showsIndicators: false,
                padding: EdgeInsets(top: 0, leading: 16, bottom: 16, trailing: 16),
                minHeight: 300,
                maxHeight: 1500
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    if viewModel.rows.isEmpty {
                        emptyStateView
                    } else {
                        if !viewModel.activeRows.isEmpty {
                            NolonUI.QuickSwitchSectionHeaderView(preset: .active)
                            ForEach(viewModel.activeRows) { row in
                                accountCard(row)
                            }
                        }

                        if !viewModel.availableRows.isEmpty {
                            NolonUI.QuickSwitchSectionHeaderView(preset: .available)
                            ForEach(viewModel.availableRows) { row in
                                accountCard(row)
                            }
                        }

                        if !viewModel.exhaustedRows.isEmpty {
                            exhaustedGroup
                        }
                    }
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

    private func accountCard(_ row: CodexQuickSwitchMenuBarViewModel.Row) -> some View {
        NolonUI.QuickSwitchAccountCardView(
            data: .init(
                id: row.id.uuidString,
                title: row.title,
                detail: row.detail,
                isActive: row.isActive,
                isExhausted: row.isExhausted,
                usageWindows: row.usageWindows.map { window in
                    .init(
                        id: window.id,
                        title: window.title,
                        remainingPercent: window.window.remainingPercent
                    )
                }
            ),
            onTap: {
                Task { await viewModel.activateAccount(id: row.id) }
            }
        )
    }

    private var exhaustedGroup: some View {
        NolonUI.QuickSwitchExhaustedGroupView(
            count: viewModel.exhaustedRows.count,
            isExpanded: $isExhaustedExpanded
        ) {
            VStack(spacing: 10) {
                ForEach(viewModel.exhaustedRows) { row in
                    accountCard(row)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
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
}
