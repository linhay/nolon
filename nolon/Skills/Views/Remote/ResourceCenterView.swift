import SwiftUI
import ProviderCatalog
import NolonResourceKit
import Observation
import OSLog

@Observable
final class ResourceCenterViewModel {
    private static let logger = Logger(subsystem: "nolon", category: "ResourceCenter")

    var selectedRepository: RemoteRepository?
    var selectedTab: ResourceContentTabType? = .skills
    var searchText = ""
    var columnVisibility: NavigationSplitViewVisibility = .all
    var installedSlugs: Set<String> = []
    var installedWorkflowSlugs: Set<String> = []
    var installedMcpSlugs: Set<String> = []
    var refreshTrigger: Int = 0
    private let statusService = InstalledResourceStatusService()
    
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
        do {
            installedSlugs = try statusService.installedSkillIDs(
                provider: targetProvider,
                repository: repository,
                settings: settings
            )
        } catch {
            Self.logger.error("Failed to scan provider: \(error.localizedDescription, privacy: .public)")
            installedSlugs = []
        }
    }

    /// 刷新已安装 workflow 列表（仅针对目标 Provider）
    @MainActor
    func refreshInstalledWorkflows(targetProvider: Provider?) {
        installedWorkflowSlugs = statusService.installedWorkflowIDs(provider: targetProvider)
    }

    /// 刷新已安装 MCP 列表
    @MainActor
    func refreshInstalledMCPs(targetProvider: Provider?) {
        installedMcpSlugs = statusService.installedMcpIDs(provider: targetProvider)
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

/// Main three-column split view for browsing resource catalogs
/// 与 MainSplitView 设计模式一致：
/// - 左1: RemoteRepositorySidebarView (仓库列表)
/// - 左2: ResourceCenterTabView (Tab 导航)
/// - 左3: ResourceCatalogGridView (网格视图)
struct ResourceCenterView: View {
    @ObservedObject var settings: ProviderSettings
    let repository: SkillRepository
    let targetProvider: Provider?
    let onInstall: (RemoteSkill, Provider) -> Void
    let onInstallWorkflow: ((RemoteWorkflow, Provider) -> Void)?
    let onInstallMCP: ((RemoteMCP, Provider) -> Void)?
    
    @State private var viewModel = ResourceCenterViewModel()
    @Environment(\.dismiss) private var dismiss
    
    init(
        settings: ProviderSettings,
        repository: SkillRepository,
        targetProvider: Provider? = nil,
        selectedTab: ResourceContentTabType? = .skills,
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
            let vm = ResourceCenterViewModel()
            vm.selectedTab = selectedTab
            return vm
        }())
    }
    
    private func refreshData() {
        viewModel.refreshInstalledSkills(repository: repository, targetProvider: targetProvider, settings: settings)
        viewModel.refreshInstalledWorkflows(targetProvider: targetProvider)
        viewModel.refreshInstalledMCPs(targetProvider: targetProvider)
        viewModel.refreshTrigger += 1
    }
    
    var body: some View {
        let isClawdhub = viewModel.selectedRepository?.templateType == .clawdhub
        Group {
            if isClawdhub {
                NavigationSplitView {
                    // Column 1: Repository sidebar
                    RemoteRepositorySidebarView(
                        selectedRepository: $viewModel.selectedRepository,
                        settings: settings,
                        showsHeader: false,
                        title: NSLocalizedString("resource.center.title", value: "Resource Center", comment: "Resource center title")
                    )
                    .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 240)
                } detail: {
                    // Column 2: Grid view (Clawdhub only)
                    ResourceCatalogGridView(
                        repository: viewModel.selectedRepository,
                        selectedTab: .skills,
                        searchText: $viewModel.searchText,
                        installedSlugs: viewModel.installedSlugs,
                        installedWorkflowSlugs: viewModel.installedWorkflowSlugs,
                        installedMcpSlugs: viewModel.installedMcpSlugs,
                        providers: settings.providers,
                        refreshTrigger: viewModel.refreshTrigger,
                        targetProvider: targetProvider,
                        onInstall: { skill, provider in
                            onInstall(skill, provider)
                            // Refresh after install attempt
                            DispatchQueue.main.asyncAfter(deadline: .now() + RemoteRefreshPolicy.installPropagationDelay) {
                                viewModel.refreshInstalledSkills(repository: repository, targetProvider: targetProvider, settings: settings)
                                viewModel.refreshTrigger += 1
                            }
                        },
                        onInstallWorkflow: { workflow, provider in
                            onInstallWorkflow?(workflow, provider)
                            // Refresh after install attempt
                            DispatchQueue.main.asyncAfter(deadline: .now() + RemoteRefreshPolicy.installPropagationDelay) {
                                viewModel.refreshInstalledWorkflows(targetProvider: targetProvider)
                                viewModel.refreshTrigger += 1
                            }
                        },
                        onInstallMCP: { mcp, provider in
                            onInstallMCP?(mcp, provider)
                            // Refresh after install attempt
                            DispatchQueue.main.asyncAfter(deadline: .now() + RemoteRefreshPolicy.installPropagationDelay) {
                                viewModel.refreshInstalledMCPs(targetProvider: targetProvider)
                                viewModel.refreshTrigger += 1
                            }
                        },
                        onRefresh: {
                            refreshData()
                        },
                        onClose: {
                            dismiss()
                        }
                    )
                }
                .navigationSplitViewStyle(.balanced)
            } else {
                NavigationSplitView(columnVisibility: $viewModel.columnVisibility) {
                    // Column 1: Repository sidebar
                    RemoteRepositorySidebarView(
                        selectedRepository: $viewModel.selectedRepository,
                        settings: settings,
                        showsHeader: false,
                        title: NSLocalizedString("resource.center.title", value: "Resource Center", comment: "Resource center title")
                    )
                    .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 240)
                } content: {
                    // Column 2: Tab navigation (类似 ProviderContentTabView)
                    ResourceCenterTabView(
                        repository: viewModel.selectedRepository,
                        selectedTab: $viewModel.selectedTab,
                        refreshTrigger: viewModel.refreshTrigger
                    )
                } detail: {
                    // Column 3: Grid view
                    ResourceCatalogGridView(
                        repository: viewModel.selectedRepository,
                        selectedTab: viewModel.selectedTab,
                        searchText: $viewModel.searchText,
                        installedSlugs: viewModel.installedSlugs,
                        installedWorkflowSlugs: viewModel.installedWorkflowSlugs,
                        installedMcpSlugs: viewModel.installedMcpSlugs,
                        providers: settings.providers,
                        refreshTrigger: viewModel.refreshTrigger,
                        targetProvider: targetProvider,
                        onInstall: { skill, provider in
                            onInstall(skill, provider)
                            // Refresh after install attempt
                            DispatchQueue.main.asyncAfter(deadline: .now() + RemoteRefreshPolicy.installPropagationDelay) {
                                viewModel.refreshInstalledSkills(repository: repository, targetProvider: targetProvider, settings: settings)
                                viewModel.refreshTrigger += 1
                            }
                        },
                        onInstallWorkflow: { workflow, provider in
                            onInstallWorkflow?(workflow, provider)
                            // Refresh after install attempt
                            DispatchQueue.main.asyncAfter(deadline: .now() + RemoteRefreshPolicy.installPropagationDelay) {
                                viewModel.refreshInstalledWorkflows(targetProvider: targetProvider)
                                viewModel.refreshTrigger += 1
                            }
                        },
                        onInstallMCP: { mcp, provider in
                            onInstallMCP?(mcp, provider)
                            // Refresh after install attempt
                            DispatchQueue.main.asyncAfter(deadline: .now() + RemoteRefreshPolicy.installPropagationDelay) {
                                viewModel.refreshInstalledMCPs(targetProvider: targetProvider)
                                viewModel.refreshTrigger += 1
                            }
                        },
                        onRefresh: {
                            refreshData()
                        },
                        onClose: {
                            dismiss()
                        }
                    )
                }
                .navigationSplitViewStyle(.balanced)
            }
        }
        .onAppear {
            refreshData()
            if viewModel.selectedRepository?.templateType == .clawdhub {
                viewModel.selectedTab = .skills
            }
        }
        .onChange(of: viewModel.selectedRepository) { _, repository in
            if repository?.templateType == .clawdhub {
                viewModel.selectedTab = .skills
            } else {
                if viewModel.selectedTab == nil {
                    viewModel.selectedTab = .skills
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    #Preview {
        ResourceCenterView(
            settings: ProviderSettings(),
            repository: SkillRepository(),
            selectedTab: .skills,
            onInstall: { skill, provider in
                _ = skill
                _ = provider
            }
        )
        .frame(width: 900, height: 600)
    }
    
}
