import SwiftUI
import AppKit
import ProviderCatalog
import CodexProvider
import STFilePath
import OSLog
import NolonResourceKit
import SKProcessRunner
import NolonUI

private let terminalLogger = Logger(subsystem: "com.nolon", category: "TerminalDetection")
private let codexConfigDocsURL = "https://developers.openai.com/codex/config-basic"

private enum CodexTerminalLauncher {
    static func launchCLI(command: String, in app: CodexTerminalApp) throws {
        switch app {
        case .terminal:
            let script = """
            tell application "Terminal"
                activate
                do script "\(escapeAppleScript(command))"
            end tell
            """
            try runAppleScript(script)
        case .iTerm:
            let script = """
            tell application "iTerm"
                activate
                if (count of windows) = 0 then
                    create window with default profile
                end if
                tell current window
                    create tab with default profile command "\(escapeAppleScript(command))"
                end tell
            end tell
            """
            try runAppleScript(script)
        case .warp, .warpStable, .warpPreview:
            try launchWarp(command: command)
        case .ghostty:
            try launchViaOpen(bundleID: app.bundleIdentifier, arguments: ["-e", "/bin/zsh", "-lc", command])
        }
    }

    private static func runAppleScript(_ source: String) throws {
        let result = try SKProcessRunner.runSync(
            SKProcessPayload
                .command("/usr/bin/osascript")
                .arguments(["-e", source])
        )
        guard result.exitCode == 0 else {
            let message = result.stderr.isEmpty ? result.stdout : result.stderr
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(
                domain: "CodexTerminalLauncher",
                code: 3001,
                userInfo: [NSLocalizedDescriptionKey: trimmed.isEmpty == false
                    ? trimmed
                    : NSLocalizedString(
                        "provider.cli.error.open_terminal",
                        value: "Unable to open terminal app.",
                        comment: "Unable to open terminal app"
                    )]
            )
        }
    }

    private static func escapeAppleScript(_ raw: String) -> String {
        raw.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func launchWarp(command: String) throws {
        guard var components = URLComponents(string: "warp://action/new_tab") else {
            throw NSError(
                domain: "CodexTerminalLauncher",
                code: 3003,
                userInfo: [NSLocalizedDescriptionKey: NSLocalizedString(
                    "provider.cli.error.open_terminal",
                    value: "Unable to open terminal app.",
                    comment: "Unable to open terminal app"
                )]
            )
        }
        components.queryItems = [URLQueryItem(name: "command", value: command)]
        guard let url = components.url, NSWorkspace.shared.open(url) else {
            throw NSError(
                domain: "CodexTerminalLauncher",
                code: 3004,
                userInfo: [NSLocalizedDescriptionKey: NSLocalizedString(
                    "provider.cli.error.open_terminal",
                    value: "Unable to open terminal app.",
                    comment: "Unable to open terminal app"
                )]
            )
        }
    }

    private static func launchViaOpen(bundleID: String, arguments: [String]) throws {
        let result = try SKProcessRunner.runSync(
            SKProcessPayload
                .command("/usr/bin/open")
                .arguments(["-b", bundleID, "--args"] + arguments)
        )
        guard result.exitCode == 0 else {
            let message = result.stderr.isEmpty ? result.stdout : result.stderr
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(
                domain: "CodexTerminalLauncher",
                code: 3005,
                userInfo: [NSLocalizedDescriptionKey: trimmed.isEmpty == false
                    ? trimmed
                    : NSLocalizedString(
                        "provider.cli.error.open_terminal",
                        value: "Unable to open terminal app.",
                        comment: "Unable to open terminal app"
                    )]
            )
        }
    }
}

/// Provider 内容 Tab 类型
enum ProviderContentTabType: String, CaseIterable, Identifiable {
    case skills = "Skills"
    case workflows = "Workflows"
    case rules = "Rules"
    case agents = "Agents"
    case mcp = "MCP"
    case binary = "Binary"
    case advanced = "Advanced"
    case accounts = "Accounts"
    case usage = "Usage"
    case runtime = "Runtime"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .skills: return "square.grid.2x2"
        case .workflows: return "arrow.triangle.branch"
        case .rules: return "list.bullet.rectangle"
        case .agents: return "person.text.rectangle"
        case .mcp: return "server.rack"
        case .binary: return "terminal"
        case .advanced: return "slider.horizontal.3"
        case .accounts: return "person.2"
        case .usage: return "chart.bar.xaxis"
        case .runtime: return "waveform.path.ecg.rectangle"
        }
    }
    
    var localizedName: String {
        switch self {
        case .skills: return NSLocalizedString("tab.skills", comment: "Skills")
        case .workflows: return NSLocalizedString("tab.workflows", comment: "Workflows")
        case .rules: return NSLocalizedString("tab.rules", value: "Rules", comment: "Rules")
        case .agents: return NSLocalizedString("tab.agents", value: "Agents", comment: "Agents")
        case .mcp: return NSLocalizedString("tab.mcp", comment: "MCP Server")
        case .binary: return NSLocalizedString("tab.binary", value: "Binary", comment: "Binary")
        case .advanced: return NSLocalizedString("tab.advanced", value: "Advanced", comment: "Advanced")
        case .accounts: return NSLocalizedString("tab.accounts", value: "Accounts", comment: "Accounts")
        case .usage: return NSLocalizedString("tab.usage", value: "Usage", comment: "Usage")
        case .runtime: return NSLocalizedString("tab.runtime", value: "Runtime", comment: "Runtime")
        }
    }

    func localizedName(for provider: Provider?) -> String {
        switch self {
        case .usage:
            if provider?.templateId == "codex" || provider?.templateId == "codexXcode" {
                return NSLocalizedString("tab.account_usage", value: "账号与用量", comment: "Account and usage")
            }
            return self.localizedName
        default:
            return self.localizedName
        }
    }

    @MainActor
    static func availableTabs(for provider: Provider) -> [ProviderContentTabType] {
        var tabs: [ProviderContentTabType] = [.skills, .workflows, .mcp]
        if provider.templateId == "codex" || provider.templateId == "codexXcode" {
            tabs.append(.rules)
            tabs.append(.agents)
            tabs.append(.binary)
            tabs.append(.advanced)
        }
        guard provider.kind == .vendor else { return tabs }

        guard let templateId = provider.templateId,
              let template = ProviderTemplate(rawValue: templateId),
              let vendorTabs = template.config?.vendorTabs
        else {
            return tabs
        }

        for tabId in vendorTabs {
            if let tab = ProviderContentTabType(vendorTabId: tabId), !tabs.contains(tab) {
                tabs.append(tab)
            }
        }

        if provider.templateId == "codex" {
            tabs = move(tab: .runtime, after: .usage, in: tabs)
        } else if provider.templateId == "codexXcode" {
            tabs = move(tab: .runtime, after: .binary, in: tabs)
        }
        return tabs
    }

    private static func move(tab: ProviderContentTabType, after anchor: ProviderContentTabType, in source: [ProviderContentTabType]) -> [ProviderContentTabType] {
        guard let tabIndex = source.firstIndex(of: tab), let anchorIndex = source.firstIndex(of: anchor) else {
            return source
        }
        var tabs = source
        let removed = tabs.remove(at: tabIndex)
        let normalizedAnchorIndex = tabs.firstIndex(of: anchor) ?? min(anchorIndex, max(0, tabs.count - 1))
        let insertIndex = min(normalizedAnchorIndex + 1, tabs.count)
        tabs.insert(removed, at: insertIndex)
        return tabs
    }
}

extension ProviderContentTabType {
    init?(vendorTabId: String) {
        switch vendorTabId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "accounts":
            self = .accounts
        case "usage":
            self = .usage
        case "binary":
            self = .binary
        case "advanced":
            self = .advanced
        case "rules":
            self = .rules
        case "agents":
            self = .agents
        case "runtime":
            self = .runtime
        default:
            return nil
        }
    }
}

/// 中间栏 - Provider 内容导航列表
@MainActor
@Observable
final class ProviderContentTabViewModel {
    private static let logger = Logger(subsystem: "com.nolon", category: "ProviderContentTabView")

    var skillsCount: Int = 0
    var workflowsCount: Int = 0
    var rulesCount: Int = 0
    var agentsCount: Int = 0
    var mcpCount: Int = 0
    var terminalApps: [CodexTerminalApp] = []
    var terminalErrorMessage: String?
    
    private let repository = SkillRepository()
    private let summaryService: ProviderResourceSummaryService
    private let binaryManager: CodexBinaryManager
    
    init(settings: ProviderSettings, binaryManager: CodexBinaryManager = .shared) {
        self.summaryService = ProviderResourceSummaryService(repository: repository, settings: settings)
        self.binaryManager = binaryManager
    }
    
    func count(for tab: ProviderContentTabType) -> Int {
        switch tab {
        case .skills: return skillsCount
        case .workflows: return workflowsCount
        case .rules: return rulesCount
        case .agents: return agentsCount
        case .mcp: return mcpCount
        case .binary: return 0
        case .advanced: return 0
        case .accounts: return 0
        case .usage: return 0
        case .runtime: return 0
        }
    }
    
    func loadCounts(for provider: Provider?) async {
        guard let provider = provider else {
            skillsCount = 0
            workflowsCount = 0
            rulesCount = 0
            agentsCount = 0
            mcpCount = 0
            return
        }
        let summary = summaryService.summarize(provider: provider)
        skillsCount = summary.skillsCount
        workflowsCount = summary.workflowsCount
        rulesCount = summary.rulesCount
        agentsCount = summary.agentsCount
        mcpCount = summary.mcpCount
    }

    func isCodexProvider(_ provider: Provider) -> Bool {
        provider.templateId == "codex" || provider.templateId == "codexXcode"
    }

    func refreshTerminalApps(for provider: Provider?) {
        guard let provider, isCodexProvider(provider) else {
            terminalApps = []
            return
        }
        let available = CodexTerminalApp.allCases.filter {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0.bundleIdentifier) != nil
        }
        terminalLogger.debug("Detected terminal bundle IDs: \(available.map(\.bundleIdentifier).joined(separator: ", "), privacy: .public)")
        let preferredOrder: [CodexTerminalApp] = [
            .terminal,
            .iTerm,
            .warpStable,
            .warp,
            .warpPreview,
            .ghostty
        ]
        var ordered: [CodexTerminalApp] = []
        var seenNames = Set<String>()
        for app in preferredOrder where available.contains(app) {
            let key = app.displayName.lowercased()
            guard !seenNames.contains(key) else { continue }
            seenNames.insert(key)
            ordered.append(app)
        }
        terminalLogger.debug("Ordered terminal apps: \(ordered.map(\.displayName).joined(separator: ", "), privacy: .public)")
        terminalApps = ordered
    }

    func openCLIInTerminal(for provider: Provider, app: CodexTerminalApp? = nil) async {
        do {
            let target = CodexTerminalApp.resolveTarget(
                explicit: app,
                preferredBundleID: nil,
                available: terminalApps
            )
            guard let target else {
                throw NSError(
                    domain: "ProviderContentTabViewModel",
                    code: 3002,
                    userInfo: [NSLocalizedDescriptionKey: NSLocalizedString(
                        "provider.cli.error.no_terminal",
                        value: "No supported terminal app found. Install Terminal or iTerm.",
                        comment: "No supported terminal app found"
                    )]
                )
            }
            terminalLogger.debug("Launching CLI in terminal: \(target.displayName, privacy: .public)")
            let codexHome = URL(fileURLWithPath: provider.defaultSkillsPath).deletingLastPathComponent().path
            let command = try await binaryManager.cliLaunchCommand(codexHomePath: codexHome)
            try CodexTerminalLauncher.launchCLI(command: command, in: target)
        } catch {
            terminalLogger.error("Failed to launch CLI in terminal: \(error.localizedDescription, privacy: .public)")
            terminalErrorMessage = error.localizedDescription
        }
    }
}

/// 中间栏 - Provider 内容导航列表
struct ProviderContentTabView: View, DebugPageLocatable {
    let provider: Provider?
    @Binding var selectedTab: ProviderContentTabType?
    let settings: ProviderSettings
    var refreshTrigger: Int
    
    @State private var viewModel: ProviderContentTabViewModel
    
    init(provider: Provider?, selectedTab: Binding<ProviderContentTabType?>, settings: ProviderSettings, refreshTrigger: Int = 0) {
        self.provider = provider
        self._selectedTab = selectedTab
        self.settings = settings
        self.refreshTrigger = refreshTrigger
        self._viewModel = State(initialValue: ProviderContentTabViewModel(settings: settings))
    }

    var debugPageMarkerItems: [PageMarkerItem] {
        PageMarkerRouteResolver.providerNavigationItems(provider: provider)
    }

    private var availableTabs: [ProviderContentTabType] {
        guard let provider else { return [] }
        return ProviderContentTabType.availableTabs(for: provider)
    }

    private var sidebarItems: [ProviderContentTabSidebarItem<ProviderContentTabType>] {
        availableTabs.map { tab in
            ProviderContentTabSidebarItem(
                id: tab,
                title: tab.localizedName(for: provider),
                iconName: tab.icon,
                countText: showsCount(for: tab) ? "\(viewModel.count(for: tab))" : nil,
                trailingSymbolName: showsDocumentationButton(for: tab) ? "arrow.up.right.square" : nil,
                trailingHelpText: showsDocumentationButton(for: tab)
                    ? NSLocalizedString(
                        "action.view_official_docs",
                        value: "View Official Documentation",
                        comment: "Open official docs"
                    )
                    : nil
            )
        }
    }

    nonisolated static func shouldShowSidebarComponent(provider: Provider?) -> Bool {
        provider != nil
    }

    // NOTE:
    // Avoid using an exact zero-width split column on macOS.
    // AppKit text field hosting may emit Auto Layout warnings when the column is
    // fully collapsed to 0 with strict equal constraints.
    private static let hiddenColumnMinWidth: CGFloat = 1
    private static let hiddenColumnIdealWidth: CGFloat = 1
    private static let hiddenColumnMaxWidth: CGFloat = 2
    
    var body: some View {
        Group {
            if Self.shouldShowSidebarComponent(provider: provider) {
                NolonUI.ProviderContentTabSidebarComponent(
                    selectedTab: $selectedTab,
                    hasProviderSelection: true,
                    items: sidebarItems,
                    emptyTitle: NSLocalizedString("content.no_provider", comment: "Select a Provider"),
                    emptyDescription: NSLocalizedString(
                        "content.no_provider_desc",
                        comment: "Choose a provider from the sidebar"
                    ),
                    emptySystemImage: "sidebar.left",
                    onTapTrailingAccessory: { tab in
                        if showsDocumentationButton(for: tab) {
                            openAdvancedDocs()
                        }
                    }
                )
            } else {
                EmptyView()
                    .navigationSplitViewColumnWidth(
                        min: Self.hiddenColumnMinWidth,
                        ideal: Self.hiddenColumnIdealWidth,
                        max: Self.hiddenColumnMaxWidth
                    )
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .onAppear {
            if selectedTab == nil {
                selectedTab = .skills
            }
        }
        .onChange(of: provider?.id) { _, _ in
            if let selectedTab, !availableTabs.contains(selectedTab) {
                self.selectedTab = .skills
            }
            viewModel.refreshTerminalApps(for: provider)
        }
        .task(id: "\(provider?.id ?? "")-\(refreshTrigger)") {
            await viewModel.loadCounts(for: provider)
            viewModel.refreshTerminalApps(for: provider)
        }
        .onChange(of: selectedTab) { _, _ in
            Task { await viewModel.loadCounts(for: provider) }
        }
        .onChange(of: refreshTrigger) { _, _ in
            Task { await viewModel.loadCounts(for: provider) }
        }
        .toolbar {
            if let provider, viewModel.isCodexProvider(provider) {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        ForEach(viewModel.terminalApps) { app in
                            Button(app.displayName) {
                                Task { await viewModel.openCLIInTerminal(for: provider, app: app) }
                            }
                        }
                    } label: {
                        Label(
                            NSLocalizedString("provider.cli.open", value: "Open CLI", comment: "Open CLI"),
                            systemImage: "terminal"
                        )
                    }
                    .disabled(viewModel.terminalApps.isEmpty)
                }
            }
        }
        .alert(
            NSLocalizedString("provider.cli.error.title", value: "CLI Error", comment: "CLI error"),
            isPresented: Binding(
                get: { viewModel.terminalErrorMessage != nil },
                set: { if !$0 { viewModel.terminalErrorMessage = nil } }
            )
        ) {
            Button(NSLocalizedString("generic.ok", value: "OK", comment: "OK")) {
                viewModel.terminalErrorMessage = nil
            }
        } message: {
            Text(viewModel.terminalErrorMessage ?? "")
        }
        .debugPageMarkerContextMenu(debugPageMarkerItems, withDivider: false) {
            EmptyView()
        }
        .debugPageLocator(debugPageMarkerItems)
    }

    private func showsCount(for tab: ProviderContentTabType) -> Bool {
        tab == .skills || tab == .workflows || tab == .rules || tab == .agents || tab == .mcp
    }

    private func showsDocumentationButton(for tab: ProviderContentTabType) -> Bool {
        guard tab == .advanced, let provider else { return false }
        return viewModel.isCodexProvider(provider)
    }

    private func openAdvancedDocs() {
        guard let url = URL(string: codexConfigDocsURL) else { return }
        NSWorkspace.shared.open(url)
    }
}
