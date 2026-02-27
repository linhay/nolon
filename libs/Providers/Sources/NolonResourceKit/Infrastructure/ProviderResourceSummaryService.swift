import Foundation
import ProviderCatalog

public struct ProviderResourceSummary: Sendable, Equatable {
    public let skillsCount: Int
    public let workflowsCount: Int
    public let rulesCount: Int
    public let agentsCount: Int
    public let mcpCount: Int

    public init(
        skillsCount: Int,
        workflowsCount: Int,
        rulesCount: Int,
        agentsCount: Int,
        mcpCount: Int
    ) {
        self.skillsCount = skillsCount
        self.workflowsCount = workflowsCount
        self.rulesCount = rulesCount
        self.agentsCount = agentsCount
        self.mcpCount = mcpCount
    }
}

@MainActor
public final class ProviderResourceSummaryService: @unchecked Sendable {
    private let resourceService: ProviderResourceService
    private let statusService: InstalledResourceStatusService
    private let repository: SkillRepository
    private let settings: ProviderSettings

    public init(
        resourceService: ProviderResourceService = .init(),
        statusService: InstalledResourceStatusService = .init(),
        repository: SkillRepository = .init(),
        settings: ProviderSettings = .shared
    ) {
        self.resourceService = resourceService
        self.statusService = statusService
        self.repository = repository
        self.settings = settings
    }

    public func summarize(provider: Provider) -> ProviderResourceSummary {
        let skillsCount = (try? statusService.installedSkillIDs(
            provider: provider,
            repository: repository,
            settings: settings
        ).count) ?? 0
        let workflowsCount = resourceService.scanWorkflows(provider: provider).count
        let rulesCount = resourceService.scanRules(provider: provider).count
        let agentsCount = resourceService.scanAgentDocs(provider: provider).count
        let mcpCount = statusService.installedMcpIDs(provider: provider).count
        return ProviderResourceSummary(
            skillsCount: skillsCount,
            workflowsCount: workflowsCount,
            rulesCount: rulesCount,
            agentsCount: agentsCount,
            mcpCount: mcpCount
        )
    }
}
