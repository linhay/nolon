import SwiftUI
import ProviderCatalog
import NolonResourceKit
import Observation
import NolonUIFoundation

/// 资源中心内容 Tab 视图 ViewModel
@MainActor
@Observable
final class ResourceCenterTabViewModel {
    var skillsCount: Int = 0
    var workflowsCount: Int = 0
    var mcpsCount: Int = 0
    var agentsCount: Int = 0
    private let countService = RemoteRepositoryCountService()
    private let agentsProfilesService = NolonAgentsProfilesService()
    
    func count(for tab: ResourceCenterTabID) -> Int {
        switch tab {
        case .skills: return skillsCount
        case .workflows: return workflowsCount
        case .mcps: return mcpsCount
        case .agents: return agentsCount
        }
    }
    
    func loadCounts(for repository: RemoteRepository?) async {
        let counts = await countService.countAll(repository: repository, limit: 100)
        skillsCount = counts.skills
        workflowsCount = counts.workflows
        mcpsCount = counts.mcps
        agentsCount = (try? agentsProfilesService.listProfiles().count) ?? 0
    }
}
