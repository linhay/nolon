import SwiftUI
import ProviderCatalog
import NolonResourceKit
import Observation
import OSLog

@MainActor
@Observable
final class ResourceCenterViewModel {
    private static let logger = Logger(subsystem: "nolon", category: "ResourceCenter")
    enum PostInstallRefreshKind: Hashable {
        case skill
        case workflow
        case mcp
    }

    var selectedRepository: RemoteRepository?
    var selectedTab: ResourceContentTabType? = .skills
    var searchText = ""
    var columnVisibility: NavigationSplitViewVisibility = .all
    var installedSlugs: Set<String> = []
    var installedSkills: [RemoteSkill] = []
    var installedWorkflowSlugs: Set<String> = []
    var installedMcpSlugs: Set<String> = []
    var importErrorMessage: String?
    var refreshTrigger: Int = 0
    private let statusService = InstalledResourceStatusService()
    @ObservationIgnored
    private var postInstallRefreshTasks: [PostInstallRefreshKind: Task<Void, Never>] = [:]

    init(selectedTab: ResourceContentTabType? = .skills) {
        self.selectedTab = selectedTab
    }

    deinit {
        postInstallRefreshTasks.values.forEach { $0.cancel() }
    }

    func effectiveTargetProvider(
        for repository: RemoteRepository?,
        fallback targetProvider: Provider?
    ) -> Provider? {
        guard repository?.templateType != .globalSkills else {
            return nil
        }
        return targetProvider
    }

    @MainActor
    func refreshInstalledResources(
        repository: SkillRepository,
        selectedRepository: RemoteRepository?,
        fallbackTargetProvider: Provider?,
        settings: ProviderSettings
    ) {
        let effectiveTargetProvider = effectiveTargetProvider(
            for: selectedRepository,
            fallback: fallbackTargetProvider
        )
        refreshInstalledSkills(repository: repository, targetProvider: effectiveTargetProvider, settings: settings)
        refreshInstalledWorkflows(targetProvider: effectiveTargetProvider)
        refreshInstalledMCPs(targetProvider: effectiveTargetProvider)
        refreshTrigger += 1
    }
    
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
            let installedIDs = try statusService.installedSkillIDs(
                provider: targetProvider,
                repository: repository,
                settings: settings
            )
            installedSlugs = installedIDs
            installedSkills = try repository.listSkills()
                .filter { installedIDs.contains($0.id) }
                .map { skill in
                    RemoteSkill(
                        slug: skill.id,
                        displayName: skill.name,
                        summary: skill.description,
                        latestVersion: skill.version,
                        updatedAt: nil,
                        downloads: nil,
                        stars: nil,
                        localPath: skill.globalPath
                    )
                }
                .sorted {
                    $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                }
        } catch {
            Self.logger.error("Failed to scan provider: \(error.localizedDescription, privacy: .public)")
            installedSlugs = []
            installedSkills = []
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

    @MainActor
    func schedulePostInstallRefresh(
        kind: PostInstallRefreshKind,
        repository: SkillRepository,
        selectedRepository: RemoteRepository?,
        fallbackTargetProvider: Provider?,
        settings: ProviderSettings
    ) {
        postInstallRefreshTasks[kind]?.cancel()
        postInstallRefreshTasks[kind] = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(RemoteRefreshPolicy.installPropagationDelay))
            guard let self, !Task.isCancelled else { return }

            let effectiveTargetProvider = self.effectiveTargetProvider(
                for: selectedRepository,
                fallback: fallbackTargetProvider
            )

            switch kind {
            case .skill:
                self.refreshInstalledSkills(
                    repository: repository,
                    targetProvider: effectiveTargetProvider,
                    settings: settings
                )
            case .workflow:
                self.refreshInstalledWorkflows(targetProvider: effectiveTargetProvider)
            case .mcp:
                self.refreshInstalledMCPs(targetProvider: effectiveTargetProvider)
            }

            self.refreshTrigger += 1
            self.postInstallRefreshTasks[kind] = nil
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

