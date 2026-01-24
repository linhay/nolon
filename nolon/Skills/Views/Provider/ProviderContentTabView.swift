import SwiftUI
import STJSON

/// Provider 内容 Tab 类型
enum ProviderContentTabType: String, CaseIterable, Identifiable {
    case skills = "Skills"
    case workflows = "Workflows"
    case mcp = "MCP"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .skills: return "square.grid.2x2"
        case .workflows: return "arrow.triangle.branch"
        case .mcp: return "server.rack"
        }
    }
    
    var localizedName: String {
        switch self {
        case .skills: return NSLocalizedString("tab.skills", comment: "Skills")
        case .workflows: return NSLocalizedString("tab.workflows", comment: "Workflows")
        case .mcp: return NSLocalizedString("tab.mcp", comment: "MCP Server")
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
        let url = URL(fileURLWithPath: workflowPath)
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            workflowsCount = contents.filter { $0.pathExtension == "md" }.count
        } catch {
            workflowsCount = 0
        }
        
        // MCP count
        if let templateId = provider.templateId,
           let template = ProviderTemplate(rawValue: templateId) {
            let configPath = template.defaultMcpConfigPath
            if FileManager.default.fileExists(atPath: configPath.path),
               let data = try? Data(contentsOf: configPath),
               let json = try? JSON(data: data),
               let servers = json["mcpServers"].dictionary {
                mcpCount = servers.count
            } else {
                mcpCount = 0
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
                    ForEach(ProviderContentTabType.allCases) { tab in
                        HStack {
                            Label(tab.localizedName, systemImage: tab.icon)
                            Spacer()
                            Text("\(viewModel.count(for: tab))")
                                .foregroundStyle(.secondary)
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
        .task(id: "\(provider?.id ?? "")-\(refreshTrigger)") {
            await viewModel.loadCounts(for: provider)
        }
        .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 200)
    }
}
