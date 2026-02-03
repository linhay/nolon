import SwiftUI
import ProviderCatalog
import STJSON
import TOML
import STFilePath

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

/// Provider 内容 Tab 类型
enum ProviderContentTabType: String, CaseIterable, Identifiable {
    case skills = "Skills"
    case workflows = "Workflows"
    case mcp = "MCP"
    case accounts = "Accounts"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .skills: return "square.grid.2x2"
        case .workflows: return "arrow.triangle.branch"
        case .mcp: return "server.rack"
        case .accounts: return "person.2"
        }
    }
    
    var localizedName: String {
        switch self {
        case .skills: return NSLocalizedString("tab.skills", comment: "Skills")
        case .workflows: return NSLocalizedString("tab.workflows", comment: "Workflows")
        case .mcp: return NSLocalizedString("tab.mcp", comment: "MCP Server")
        case .accounts: return NSLocalizedString("tab.accounts", value: "Accounts", comment: "Accounts")
        }
    }

    @MainActor
    static func availableTabs(for provider: Provider) -> [ProviderContentTabType] {
        var tabs: [ProviderContentTabType] = [.skills, .workflows, .mcp]
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
        default:
            return nil
        }
    }
}

/// 中间栏 - Provider 内容导航列表
@MainActor
@Observable
final class ProviderContentTabViewModel {
    var skillsCount: Int = 0
    var workflowsCount: Int = 0
    var mcpCount: Int = 0
    
    private let repository = SkillRepository()
    private let installer: SkillInstaller
    
    init(settings: ProviderSettings) {
        self.installer = SkillInstaller(repository: repository, settings: settings)
    }
    
    func count(for tab: ProviderContentTabType) -> Int {
        switch tab {
        case .skills: return skillsCount
        case .workflows: return workflowsCount
        case .mcp: return mcpCount
        case .accounts: return 0
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
            print("Failed to count skills: \(error)")
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
                      let json = try? JSON(data: data),
                      let servers = json["mcpServers"].dictionary
                else {
                    mcpCount = 0
                    return
                }
                mcpCount = servers.count
            }
        } else {
            mcpCount = 0
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
                        HStack {
                            Label(tab.localizedName, systemImage: tab.icon)
                            Spacer()
                            if tab == .skills || tab == .workflows || tab == .mcp {
                                Text("\(viewModel.count(for: tab))")
                                    .foregroundStyle(.secondary)
                            }
                        }
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
        }
        .task(id: "\(provider?.id ?? "")-\(refreshTrigger)") {
            await viewModel.loadCounts(for: provider)
        }
        .onChange(of: selectedTab) { _, _ in
            Task { await viewModel.loadCounts(for: provider) }
        }
        .onChange(of: refreshTrigger) { _, _ in
            Task { await viewModel.loadCounts(for: provider) }
        }
        .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 200)
    }
}
