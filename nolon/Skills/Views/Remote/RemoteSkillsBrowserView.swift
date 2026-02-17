import SwiftUI
import ProviderCatalog
import NolonResourceKit
import Observation
import STFilePath
import STJSON
import TOML
import OSLog

enum RemoteMCPInstallStatusResolver {
    static func slugsFromGlobalCache(at mcpsURL: URL) -> Set<String> {
        let folder = STFolder(mcpsURL)
        guard folder.isExists, let files = try? folder.files() else { return [] }

        return Set(
            files.compactMap { file in
                let name = file.url.lastPathComponent
                guard !name.hasPrefix(".") else { return nil }
                if file.url.pathExtension.lowercased() == "json" {
                    return file.url.deletingPathExtension().lastPathComponent
                }
                return name
            }
        )
    }

    static func slugsFromProviderConfig(at configURL: URL, templateId: String) -> Set<String> {
        guard STFile(configURL).isExists, let data = try? Data(contentsOf: configURL), !data.isEmpty else {
            return []
        }

        if configURL.pathExtension.lowercased() == "toml" {
            guard let config = try? TOMLDecoder().decode(CodexMCPConfig.self, from: data) else {
                return []
            }
            return Set((config.mcpServers ?? [:]).keys)
        }

        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return []
        }

        if templateId == "opencode" {
            return Set((root["mcp"] as? [String: Any] ?? [:]).keys)
        }

        if let servers = root["mcpServers"] as? [String: Any] {
            return Set(servers.keys)
        }

        return Set((root["mcp_servers"] as? [String: Any] ?? [:]).keys)
    }
}

@Observable
final class RemoteSkillsBrowserViewModel {
    private static let logger = Logger(subsystem: "nolon", category: "RemoteSkillsBrowser")

    var selectedRepository: RemoteRepository?
    var selectedTab: RemoteContentTabType? = .skills
    var searchText = ""
    var columnVisibility: NavigationSplitViewVisibility = .all
    var installedSlugs: Set<String> = []
    var installedWorkflowSlugs: Set<String> = []
    var installedMcpSlugs: Set<String> = []
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
                Self.logger.error("Failed to scan provider: \(error.localizedDescription, privacy: .public)")
                installedSlugs = []
            }
        } else {
            // 无目标 Provider → 检查全局仓库
            do {
                let skills = try repository.listSkills()
                installedSlugs = Set(skills.map { $0.id })
            } catch {
                Self.logger.error("Failed to load installed skills: \(error.localizedDescription, privacy: .public)")
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
        let folder = STFolder(path)
        
        guard folder.isExists else {
            installedWorkflowSlugs = []
            return
        }

        do {
            let contents = try folder.files()
            installedWorkflowSlugs = Set(
                contents
                    .filter { $0.url.pathExtension == "md" }
                    .map { $0.url.deletingPathExtension().lastPathComponent }
            )
        } catch {
            installedWorkflowSlugs = []
        }
    }

    /// 刷新已安装 MCP 列表
    @MainActor
    func refreshInstalledMCPs(targetProvider: Provider?) {
        guard let provider = targetProvider else {
            installedMcpSlugs = RemoteMCPInstallStatusResolver.slugsFromGlobalCache(at: NolonManager.shared.mcpsURL)
            return
        }

        guard let templateId = provider.templateId,
              let template = ProviderTemplate(rawValue: templateId) else {
            installedMcpSlugs = []
            return
        }

        installedMcpSlugs = RemoteMCPInstallStatusResolver.slugsFromProviderConfig(
            at: template.defaultMcpConfigPath,
            templateId: templateId
        )
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
            let vm = RemoteSkillsBrowserViewModel()
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
        VStack(spacing: 0) {
            SheetHeaderView(title: NSLocalizedString("remote.browser.title", value: "Remote Skills", comment: "Remote skills browser")) {
                HStack(spacing: 12) {
                    Button {
                        refreshData()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .dsIconButton()
                    }
                    .help(NSLocalizedString("Refresh", comment: "Refresh"))
                    
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .dsIconButton(size: 22, foreground: DesignSystem.Colors.Text.tertiary)
                    }
                    .dsLinkButton()
                    .accessibilityLabel(NSLocalizedString("Close", comment: "Close"))
                }
            }

            SheetDivider()

            if isClawdhub {
                NavigationSplitView {
                    // Column 1: Repository sidebar
                    RemoteRepositorySidebarView(
                        selectedRepository: $viewModel.selectedRepository,
                        settings: settings
                    )
                    .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
                } detail: {
                    // Column 2: Grid view (Clawdhub only)
                    RemoteSkillsGridView(
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
                                viewModel.refreshInstalledMCPs(targetProvider: targetProvider)
                                viewModel.refreshTrigger += 1
                            }
                        }
                    )
                }
                .navigationSplitViewStyle(.balanced)
            } else {
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
                                viewModel.refreshInstalledMCPs(targetProvider: targetProvider)
                                viewModel.refreshTrigger += 1
                            }
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
        .frame(minWidth: 980, idealWidth: 1100, maxWidth: .infinity,
               minHeight: 700, idealHeight: 760, maxHeight: .infinity)
    }
    
    #Preview {
        RemoteSkillsBrowserView(
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
