import SwiftUI
import Observation

@Observable
final class RemoteSkillsBrowserViewModel {
    var selectedRepository: RemoteRepository?
    var selectedTab: RemoteContentTabType? = .skills
    var searchText = ""
    var columnVisibility: NavigationSplitViewVisibility = .all
    var installedSlugs: Set<String> = []
    var installedWorkflowSlugs: Set<String> = []
    var refreshTrigger: Int = 0
    
    /// 刷新已安装技能列表
    /// - Parameters:
    ///   - repository: 全局技能仓库
    ///   - targetProvider: 目标 Provider（可选）
    ///   - settings: Provider 设置
    /// - 逻辑：
    ///   - 有 targetProvider → 检查该 Provider 中已安装的技能
    ///   - 无 targetProvider → 检查全局仓库
    @MainActor
    func refreshInstalledSkills(repository: SkillRepository, targetProvider: Provider?, settings: ProviderSettings) {
        if let provider = targetProvider {
            // 有目标 Provider → 检查该 Provider 中的安装状态
            let installer = SkillInstaller(repository: repository, settings: settings)
            do {
                let states = try installer.scanProvider(provider: provider)
                installedSlugs = Set(states.filter { $0.state == .installed }.map { $0.skillName })
            } catch {
                print("Failed to scan provider: \(error)")
                installedSlugs = []
            }
        } else {
            // 无目标 Provider → 检查全局仓库
            do {
                let skills = try repository.listSkills()
                installedSlugs = Set(skills.map { $0.id })
            } catch {
                print("Failed to load installed skills: \(error)")
                installedSlugs = []
            }
        }
    }

    /// 刷新已安装 workflow 列表（仅针对目标 Provider）
    @MainActor
    func refreshInstalledWorkflows(targetProvider: Provider?) {
        guard let provider = targetProvider else {
            installedWorkflowSlugs = []
            return
        }

        let path = provider.workflowPath
        let url = URL(fileURLWithPath: path)

        guard FileManager.default.fileExists(atPath: path) else {
            installedWorkflowSlugs = []
            return
        }

        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )

            installedWorkflowSlugs = Set(
                contents
                    .filter { $0.pathExtension == "md" }
                    .map { $0.deletingPathExtension().lastPathComponent }
            )
        } catch {
            installedWorkflowSlugs = []
        }
    }

    /// 根据搜索文本过滤技能
    func filterSkills(_ skills: [RemoteSkill]) -> [RemoteSkill] {
        if searchText.isEmpty {
            return skills
        }
        let searchLower = searchText.lowercased()
        return skills.filter { skill in
            skill.displayName.lowercased().contains(searchLower)
            || (skill.summary?.lowercased().contains(searchLower) ?? false)
        }
    }
}

/// Main three-column split view for browsing remote skill repositories
/// 与 MainSplitView 设计模式一致：
/// - 左1: RemoteRepositorySidebarView (仓库列表)
/// - 左2: RemoteContentTabView (Tab 导航)
/// - 左3: RemoteSkillsGridView (网格视图)
struct RemoteSkillsBrowserView: View {
    @ObservedObject var settings: ProviderSettings
    let repository: SkillRepository
    let targetProvider: Provider?
    let onInstall: (RemoteSkill, Provider) -> Void
    let onInstallWorkflow: ((RemoteWorkflow, Provider) -> Void)?
    let onInstallMCP: ((RemoteMCP, Provider) -> Void)?
    
    @State private var viewModel = RemoteSkillsBrowserViewModel()
    @Environment(\.dismiss) private var dismiss
    
    init(
        settings: ProviderSettings,
        repository: SkillRepository,
        targetProvider: Provider? = nil,
        selectedTab: RemoteContentTabType? = .skills,
        onInstall: @escaping (RemoteSkill, Provider) -> Void,
        onInstallWorkflow: ((RemoteWorkflow, Provider) -> Void)? = nil,
        onInstallMCP: ((RemoteMCP, Provider) -> Void)? = nil
    ) {
        self.settings = settings
        self.repository = repository
        self.targetProvider = targetProvider
        self.onInstall = onInstall
        self.onInstallWorkflow = onInstallWorkflow
        self.onInstallMCP = onInstallMCP
        self._viewModel = State(initialValue: {
            var vm = RemoteSkillsBrowserViewModel()
            vm.selectedTab = selectedTab
            return vm
        }())
    }
    
    var body: some View {
        NavigationSplitView(columnVisibility: $viewModel.columnVisibility) {
            // Column 1: Repository sidebar
            RemoteRepositorySidebarView(
                selectedRepository: $viewModel.selectedRepository,
                settings: settings
            )
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        } content: {
            // Column 2: Tab navigation (类似 ProviderContentTabView)
            RemoteContentTabView(
                repository: viewModel.selectedRepository,
                selectedTab: $viewModel.selectedTab,
                refreshTrigger: viewModel.refreshTrigger
            )
        } detail: {
            // Column 3: Grid view
            RemoteSkillsGridView(
                repository: viewModel.selectedRepository,
                selectedTab: viewModel.selectedTab,
                searchText: viewModel.searchText, // 传入搜索文本
                installedSlugs: viewModel.installedSlugs,
                installedWorkflowSlugs: viewModel.installedWorkflowSlugs,
                providers: settings.providers,
                refreshTrigger: viewModel.refreshTrigger,
                targetProvider: targetProvider,
                onInstall: { skill, provider in
                    onInstall(skill, provider)
                    // Refresh after install attempt
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        viewModel.refreshInstalledSkills(repository: repository, targetProvider: targetProvider, settings: settings)
                        viewModel.refreshTrigger += 1
                    }
                },
                onInstallWorkflow: { workflow, provider in
                    onInstallWorkflow?(workflow, provider)
                    // Refresh after install attempt
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        viewModel.refreshInstalledWorkflows(targetProvider: targetProvider)
                        viewModel.refreshTrigger += 1
                    }
                },
                onInstallMCP: { mcp, provider in
                    onInstallMCP?(mcp, provider)
                    // Refresh after install attempt
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        viewModel.refreshTrigger += 1
                    }
                }
            )
        }
        .searchable(text: $viewModel.searchText, placement: .toolbar, prompt: "Search") // 在顶级应用搜索
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    viewModel.refreshInstalledSkills(repository: repository, targetProvider: targetProvider, settings: settings)
                    viewModel.refreshInstalledWorkflows(targetProvider: targetProvider)
                    viewModel.refreshTrigger += 1
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh installed status")
            }
        }
        .onAppear {
            viewModel.refreshInstalledSkills(repository: repository, targetProvider: targetProvider, settings: settings)
            viewModel.refreshInstalledWorkflows(targetProvider: targetProvider)
        }
        .frame(minHeight: 700, maxHeight: .infinity)
    }
}

#Preview {
    RemoteSkillsBrowserView(
        settings: ProviderSettings(),
        repository: SkillRepository(),
        selectedTab: .skills,
        onInstall: { skill, provider in
            print("Install \(skill.displayName) to \(provider.name)")
        }
    )
    .frame(width: 900, height: 600)
}
