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
    public typealias IsSkillDirectory = @Sendable (String) -> Bool
    public typealias SkillName = @Sendable (String) -> String?

    private let sync: Sync
    private let detectRepositoryResources: Detect
    private let isSkillDirectory: IsSkillDirectory
    private let skillName: SkillName

    public init(
        sync: @escaping Sync = { try await GitRepository.syncRepository($0) },
        detectRepositoryResources: @escaping Detect = { GitRepository.detectRepositoryResources(at: $0) },
        isSkillDirectory: @escaping IsSkillDirectory = { SkillParser.isSkillDirectory(at: $0) },
        skillName: @escaping SkillName = { SkillParser.skillName(at: $0) }
    ) {
        self.sync = sync
        self.detectRepositoryResources = detectRepositoryResources
        self.isSkillDirectory = isSkillDirectory
        self.skillName = skillName
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
        } else {
            updated.detectedDirectories = nil
        }

        // If repo root itself is a skills directory, expose "." as a selectable candidate.
        let rootPath = repository.localClonePath.path
        if isSkillDirectory(rootPath), candidates.contains(where: { $0.path == "." }) == false {
            let inferredName = skillName(rootPath).map { [$0] } ?? []
            candidates.insert(
                .init(path: ".", skillCount: max(1, inferredName.count), skillNames: inferredName),
                at: 0
            )
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
