import Foundation
import ProviderCatalog
import NolonResourceKit

enum ResourceDeleteTarget: Equatable, Sendable {
    case provider(Provider.ID)
    case allProvidersAndGlobalCache
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
}

struct ResourceDeletionCoordinator: Sendable {
    typealias UninstallAction = @Sendable (_ slug: String, _ type: RemoteContentType, _ provider: Provider) async throws -> Void
    typealias RemoveGlobalAction = @Sendable (_ slug: String, _ type: RemoteContentType) throws -> Bool

    let uninstallAction: UninstallAction
    let removeGlobalAction: RemoveGlobalAction

    init(
        uninstallAction: @escaping UninstallAction,
        removeGlobalAction: @escaping RemoveGlobalAction
    ) {
        self.uninstallAction = uninstallAction
        self.removeGlobalAction = removeGlobalAction
    }

    @MainActor
    func execute(
        resourceSlug: String,
        resourceType: RemoteContentType,
        target: ResourceDeleteTarget,
        providers: [Provider]
    ) async -> ResourceDeleteExecutionResult {
        var failures: [ResourceDeleteFailure] = []
        var successCount = 0
        var removedGlobalCache = false

        let targets: [Provider]
        switch target {
        case let .provider(providerID):
            targets = providers.filter { $0.id == providerID }
        case .allProvidersAndGlobalCache:
            targets = providers
        }

        for provider in targets {
            do {
                try await uninstallAction(resourceSlug, resourceType, provider)
                successCount += 1
            } catch {
                failures.append(
                    ResourceDeleteFailure(
                        targetName: provider.name,
                        reason: error.localizedDescription
                    )
                )
            }
        }

        if case .allProvidersAndGlobalCache = target {
            do {
                removedGlobalCache = try removeGlobalAction(resourceSlug, resourceType)
            } catch {
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
            attemptedCount: targets.count,
            successCount: successCount,
            removedGlobalCache: removedGlobalCache,
            failures: failures
        )
    }
}
