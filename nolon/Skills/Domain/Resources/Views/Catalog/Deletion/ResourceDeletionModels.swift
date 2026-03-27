import Foundation
import ProviderCatalog
import NolonResourceKit
import OSLog

enum ResourceDeleteTarget: Equatable, Sendable {
    case provider(Provider.ID)
    case allProvidersAndGlobalCache
}

struct ResourceDeletionProviderTarget: Equatable, Sendable {
    let id: Provider.ID
    let name: String
    let defaultSkillsPath: String
    let workflowPath: String
    let templateId: String?

    init(provider: Provider) {
        id = provider.id
        name = provider.name
        defaultSkillsPath = provider.defaultSkillsPath
        workflowPath = provider.workflowPath
        templateId = provider.templateId
    }
}

struct ResourceDeletionExecutionPlan: Equatable, Sendable {
    let providerIDs: [Provider.ID]
    let removeGlobalCache: Bool
    let globalCachePathHint: String?

    static func make(
        providerIndex: Int?,
        removeGlobalCache: Bool,
        providers: [Provider],
        globalCachePathHint: String? = nil
    ) -> Self {
        if let providerIndex, providers.indices.contains(providerIndex) {
            let providerID = providers[providerIndex].id
            return Self(
                providerIDs: providers.lazy.filter { $0.id == providerID }.map(\.id),
                removeGlobalCache: false,
                globalCachePathHint: nil
            )
        }

        return Self(
            providerIDs: removeGlobalCache ? providers.map(\.id) : [],
            removeGlobalCache: removeGlobalCache,
            globalCachePathHint: removeGlobalCache ? globalCachePathHint : nil
        )
    }

    func resolveProviderTargets(from providers: [Provider]) -> [ResourceDeletionProviderTarget] {
        let providersByID = Dictionary(
            uniqueKeysWithValues: providers.map { ($0.id, ResourceDeletionProviderTarget(provider: $0)) }
        )
        return providerIDs.compactMap { providersByID[$0] }
    }
}

struct RegisteredResourceDeleteRequest: Equatable, Sendable {
    let slug: String
    let resourceType: RemoteContentType
    let providerIndex: Int?
    let removeGlobalCache: Bool
    let globalCachePathHint: String?
}

struct ResourceDeleteRequest: Identifiable, Equatable, Sendable {
    let resourceSlug: String
    let displayName: String
    let resourceType: RemoteContentType
    let localPath: String?
    let defaultTarget: ResourceDeleteTarget?

    var id: String {
        switch resourceType {
        case .skill:
            return "skill-\(resourceSlug)"
        case .workflow:
            return "workflow-\(resourceSlug)"
        case .mcp:
            return "mcp-\(resourceSlug)"
        }
    }

    init(
        resourceSlug: String,
        displayName: String,
        resourceType: RemoteContentType,
        localPath: String? = nil,
        defaultTarget: ResourceDeleteTarget? = nil
    ) {
        self.resourceSlug = resourceSlug
        self.displayName = displayName
        self.resourceType = resourceType
        self.localPath = localPath
        self.defaultTarget = defaultTarget
    }

    init(skill: RemoteSkill, defaultTarget: ResourceDeleteTarget? = nil) {
        self.init(
            resourceSlug: skill.slug,
            displayName: skill.displayName,
            resourceType: .skill,
            localPath: skill.localPath,
            defaultTarget: defaultTarget
        )
    }

    init(workflow: RemoteWorkflow, defaultTarget: ResourceDeleteTarget? = nil) {
        self.init(
            resourceSlug: workflow.slug,
            displayName: workflow.displayName,
            resourceType: .workflow,
            localPath: workflow.localPath,
            defaultTarget: defaultTarget
        )
    }

    init(mcp: RemoteMCP, defaultTarget: ResourceDeleteTarget? = nil) {
        self.init(
            resourceSlug: mcp.slug,
            displayName: mcp.displayName,
            resourceType: .mcp,
            localPath: mcp.localPath,
            defaultTarget: defaultTarget
        )
    }
}

struct ResourceDeleteFailure: Equatable, Sendable {
    let targetName: String
    let reason: String
}

struct ResourceDeleteExecutionResult: Equatable, Sendable {
    let resourceSlug: String
    let resourceType: RemoteContentType
    let attemptedCount: Int
    let successCount: Int
    let removedGlobalCache: Bool
    let failures: [ResourceDeleteFailure]

    var hasFailure: Bool { !failures.isEmpty }
    
    init(resourceSlug: String,
         resourceType: RemoteContentType,
         attemptedCount: Int,
         successCount: Int,
         removedGlobalCache: Bool,
         failures: [ResourceDeleteFailure]) {
        self.resourceSlug = resourceSlug
        self.resourceType = resourceType
        self.attemptedCount = attemptedCount
        self.successCount = successCount
        self.removedGlobalCache = removedGlobalCache
        self.failures = failures
    }
}

struct ResourceDeletionCoordinator: Sendable {
    private static let logger = Logger(subsystem: "com.nolon", category: "ResourceDeletion")
    typealias UninstallAction = @Sendable (_ slug: String, _ type: RemoteContentType, _ provider: ResourceDeletionProviderTarget) async throws -> Void
    typealias RemoveGlobalAction = @Sendable (_ slug: String, _ type: RemoteContentType, _ pathHint: String?) throws -> Bool

    let uninstallAction: UninstallAction
    let removeGlobalAction: RemoveGlobalAction

    init(
        uninstallAction: @escaping UninstallAction,
        removeGlobalAction: @escaping RemoveGlobalAction
    ) {
        self.uninstallAction = uninstallAction
        self.removeGlobalAction = removeGlobalAction
    }

    func execute(
        resourceSlug: String,
        resourceType: RemoteContentType,
        providerTargets: [ResourceDeletionProviderTarget],
        removeGlobalCache: Bool,
        globalCachePathHint: String? = nil
    ) async -> ResourceDeleteExecutionResult {
        var failures: [ResourceDeleteFailure] = []
        var successCount = 0
        var removedGlobalCache = false

        for provider in providerTargets {
            do {
                try await uninstallAction(resourceSlug, resourceType, provider)
                successCount += 1
            } catch {
                Self.logger.error("Delete failed for provider target.")
                failures.append(
                    ResourceDeleteFailure(
                        targetName: provider.name,
                        reason: error.localizedDescription
                    )
                )
            }
        }

        if removeGlobalCache {
            do {
                removedGlobalCache = try removeGlobalAction(resourceSlug, resourceType, globalCachePathHint)
            } catch {
                Self.logger.error("Delete failed for global cache target.")
                failures.append(
                    ResourceDeleteFailure(
                        targetName: "Global Cache",
                        reason: error.localizedDescription
                    )
                )
            }
        }

        return ResourceDeleteExecutionResult(
            resourceSlug: resourceSlug,
            resourceType: resourceType,
            attemptedCount: providerTargets.count,
            successCount: successCount,
            removedGlobalCache: removedGlobalCache,
            failures: failures
        )
    }
}
