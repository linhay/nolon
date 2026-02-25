import Foundation
import STFilePath

public struct RepositorySyncPlan: Sendable {
    public let repository: RemoteRepository
    public let detectedDirectories: [GitRepository.SkillsDirectoryCandidate]
    public let shouldPromptDirectorySelection: Bool

    public init(
        repository: RemoteRepository,
        detectedDirectories: [GitRepository.SkillsDirectoryCandidate],
        shouldPromptDirectorySelection: Bool
    ) {
        self.repository = repository
        self.detectedDirectories = detectedDirectories
        self.shouldPromptDirectorySelection = shouldPromptDirectorySelection
    }
}

public struct RepositorySyncOrchestrator: Sendable {
    public typealias Sync = @Sendable (RemoteRepository) async throws -> GitRepository.SyncResult
    public typealias Detect = @Sendable (URL) -> GitRepository.RepositoryResources

    private let sync: Sync
    private let detectRepositoryResources: Detect

    public init(
        sync: @escaping Sync = { try await GitRepository.syncRepository($0) },
        detectRepositoryResources: @escaping Detect = { GitRepository.detectRepositoryResources(at: $0) }
    ) {
        self.sync = sync
        self.detectRepositoryResources = detectRepositoryResources
    }

    public func sync(repository: RemoteRepository) async throws -> (GitRepository.SyncResult, RepositorySyncPlan) {
        let result = try await sync(repository)

        var updated = repository
        updated.lastSyncDate = result.updatedAt

        var candidates = result.detectedDirectories
        if candidates.isEmpty && repository.skillsPaths.isEmpty {
            let clonePath = repository.localClonePath
            if STPath(clonePath).isExists {
                let resources = detectRepositoryResources(clonePath)
                candidates = resources.skillsDirectories
            }
        }

        if !candidates.isEmpty {
            updated.detectedDirectories = candidates.map(\.path)
        }

        let plan = RepositorySyncPlan(
            repository: updated,
            detectedDirectories: candidates,
            shouldPromptDirectorySelection: repository.skillsPaths.isEmpty && !candidates.isEmpty
        )
        return (result, plan)
    }
}
