import SwiftUI
import AppKit
import ProviderCatalog
import STJSON
import TOML
import STFilePath
import OSLog

private let terminalLogger = Logger(subsystem: "com.nolon", category: "TerminalDetection")

// Minimal TOML model for Codex-style config.toml
private struct CodexMCPConfigLite: Codable {
    var mcpServers: [String: CodexMCPServerLite]?
    
    enum CodingKeys: String, CodingKey {
        case mcpServers = "mcp_servers"
    }
}

private struct CodexMCPServerLite: Codable {
    var enabled: Bool?
}

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
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", source]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let data = output.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(
                domain: "CodexTerminalLauncher",
                code: 3001,
                userInfo: [NSLocalizedDescriptionKey: message?.isEmpty == false
                    ? (message ?? "")
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
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-b", bundleID, "--args"] + arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let data = output.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(
                domain: "CodexTerminalLauncher",
                code: 3005,
                userInfo: [NSLocalizedDescriptionKey: message?.isEmpty == false
                    ? (message ?? "")
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
    case mcp = "MCP"
    case binary = "Binary"
    case accounts = "Accounts"
    case usage = "Usage"
    case binary = "Binary"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .skills: return "square.grid.2x2"
        case .workflows: return "arrow.triangle.branch"
        case .mcp: return "server.rack"
        case .binary: return "terminal"
        case .accounts: return "person.2"
        case .usage: return "chart.bar.xaxis"
        case .binary: return "shippingbox"
        }
    }
    
    var localizedName: String {
        switch self {
        case .skills: return NSLocalizedString("tab.skills", comment: "Skills")
        case .workflows: return NSLocalizedString("tab.workflows", comment: "Workflows")
        case .mcp: return NSLocalizedString("tab.mcp", comment: "MCP Server")
        case .binary: return NSLocalizedString("tab.binary", value: "Binary", comment: "Binary")
        case .accounts: return NSLocalizedString("tab.accounts", value: "Accounts", comment: "Accounts")
        case .usage: return NSLocalizedString("tab.usage", value: "Usage", comment: "Usage")
        case .binary: return NSLocalizedString("tab.binary", value: "Binary", comment: "Binary")
        }
    }

    @MainActor
    static func availableTabs(for provider: Provider) -> [ProviderContentTabType] {
        var tabs: [ProviderContentTabType] = [.skills, .workflows, .mcp]
        if provider.templateId == "codex" || provider.templateId == "codexXcode" {
            tabs.append(.binary)
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
    var mcpCount: Int = 0
    var terminalApps: [CodexTerminalApp] = []
    var terminalErrorMessage: String?
    
    private let repository = SkillRepository()
    private let installer: SkillInstaller
    private let binaryManager: CodexBinaryManager
    
    init(settings: ProviderSettings, binaryManager: CodexBinaryManager = .shared) {
        self.installer = SkillInstaller(repository: repository, settings: settings)
        self.binaryManager = binaryManager
    }
    
    func count(for tab: ProviderContentTabType) -> Int {
        switch tab {
        case .skills: return skillsCount
        case .workflows: return workflowsCount
        case .mcp: return mcpCount
        case .binary: return 0
        case .accounts: return 0
        case .usage: return 0
        case .binary: return 0
        }
    }
    
    func loadCounts(for provider: Provider?) async {
        guard let provider = provider else {
            skillsCount = 0
            workflowsCount = 0
            mcpCount = 0
            return
        }
        
        // Skills count
        do {
            let states = try installer.scanProvider(provider: provider)
            skillsCount = states.filter { $0.state == .installed }.count
        } catch {
            Self.logger.error("Failed to count skills: \(String(describing: error), privacy: .public)")
            skillsCount = 0
        }
        
        // Workflows count
        let workflowPath = provider.workflowPath
        let workflowFolder = STFolder(workflowPath)
        if let contents = try? workflowFolder.files() {
            workflowsCount = contents.filter { $0.url.pathExtension == "md" }.count
        } else {
            workflowsCount = 0
        }
        
        // MCP count
        if let templateId = provider.templateId,
           let template = ProviderTemplate(rawValue: templateId) {
           let configPath = template.defaultMcpConfigPath
            guard STFile(configPath).isExists else {
                mcpCount = 0
                return
            }
            
            if configPath.pathExtension.lowercased() == "toml" {
                guard let data = try? Data(contentsOf: configPath),
                      !data.isEmpty,
                      let decoded = try? TOMLDecoder().decode(CodexMCPConfigLite.self, from: data),
                      let servers = decoded.mcpServers
                else {
                    mcpCount = 0
                    return
                }
                mcpCount = servers.count
            } else {
                guard let data = try? Data(contentsOf: configPath),
                      let json = try? JSON(data: data)
                else {
                    mcpCount = 0
                    return
                }

                if template.rawValue == "opencode" {
                    mcpCount = json["mcp"].dictionary?.count ?? 0
                } else {
                    mcpCount = (json["mcpServers"].dictionary ?? json["mcp_servers"].dictionary)?.count ?? 0
                }
            }
        } else {
            mcpCount = 0
        }
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
struct ProviderContentTabView: View {
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
    
    var body: some View {
        Group {
            if let provider = provider {
                List(selection: $selectedTab) {
                    ForEach(ProviderContentTabType.availableTabs(for: provider)) { tab in
                        tabRow(tab)
                            .tag(tab)
                    }
                }
                .listStyle(.sidebar)
                .navigationTitle(provider.displayName)
            } else {
                ContentUnavailableView(
                    NSLocalizedString("content.no_provider", comment: "Select a Provider"),
                    systemImage: "sidebar.left",
                    description: Text(NSLocalizedString("content.no_provider_desc", comment: "Choose a provider from the sidebar"))
                        .dsSecondaryText(font: .body)
                )
            }
        }
        .onAppear {
            if selectedTab == nil {
                selectedTab = .skills
            }
        }
        .onChange(of: provider?.id) { _, _ in
            if let provider, let selectedTab, !ProviderContentTabType.availableTabs(for: provider).contains(selectedTab) {
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
        .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 200)
    }

    @ViewBuilder
    private func tabRow(_ tab: ProviderContentTabType) -> some View {
        HStack {
            Label(tab.localizedName, systemImage: tab.icon)
            Spacer()
            if tab == .skills || tab == .workflows || tab == .mcp {
                Text("\(viewModel.count(for: tab))")
                    .dsSecondaryText(font: .callout)
            }
        }
    }
}
