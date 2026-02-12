import Foundation
import os.log
import STFilePath
import ProviderCatalog

/// Git repository implementation backed by ProviderCatalog remote git support
/// Supports GitHub, GitLab, and other Git hosting services
public actor GitRepository: RemoteResourceRepository {

    // MARK: - Types (replacing GitRepositoryService)

    public enum SyncError: LocalizedError, Sendable {
        case invalidURL
        case sshNotAvailable(host: String)
        case cloneFailed(String)
        case pullFailed(String)
        case fileOperationFailed(String)

        public var errorDescription: String? {
            switch self {
            case .invalidURL:
                return NSLocalizedString("error.git.invalid_url", comment: "Invalid Git repository URL")
            case .sshNotAvailable(let host):
                return String(
                    format: NSLocalizedString(
                        "error.git.ssh_not_available",
                        comment: "SSH authentication not configured for %@. Please configure SSH key or provide a Personal Access Token."
                    ),
                    host
                )
            case .cloneFailed(let message):
                return String(
                    format: NSLocalizedString("error.git.clone_failed", comment: "Failed to clone repository: %@"),
                    message
                )
            case .pullFailed(let message):
                return String(
                    format: NSLocalizedString("error.git.pull_failed", comment: "Failed to update repository: %@"),
                    message
                )
            case .fileOperationFailed(let message):
                return message
            }
        }
    }

    public struct SkillsDirectoryCandidate: Sendable, Identifiable {
        public let id: String
        public let path: String
        public let skillCount: Int
        public let skillNames: [String]

        public init(path: String, skillCount: Int, skillNames: [String]) {
            self.id = path
            self.path = path
            self.skillCount = skillCount
            self.skillNames = skillNames
        }
    }

    public struct RepositoryResources: Sendable {
        public let skillsDirectories: [SkillsDirectoryCandidate]
        public let workflowPaths: [String]
        public let mcpPaths: [String]

        public init(
            skillsDirectories: [SkillsDirectoryCandidate],
            workflowPaths: [String],
            mcpPaths: [String]
        ) {
            self.skillsDirectories = skillsDirectories
            self.workflowPaths = workflowPaths
            self.mcpPaths = mcpPaths
        }
    }

    public struct SyncResult: Sendable {
        public let success: Bool
        public let message: String
        public let isNewClone: Bool
        public let updatedAt: Date
        public let detectedDirectories: [SkillsDirectoryCandidate]
        public let workflowPaths: [String]
        public let mcpPaths: [String]

        public static func success(
            isNewClone: Bool,
            detectedDirectories: [SkillsDirectoryCandidate] = [],
            workflowPaths: [String] = [],
            mcpPaths: [String] = []
        ) -> SyncResult {
            SyncResult(
                success: true,
                message: isNewClone
                    ? NSLocalizedString("git.clone_success", comment: "Repository cloned successfully")
                    : NSLocalizedString("git.pull_success", comment: "Repository updated successfully"),
                isNewClone: isNewClone,
                updatedAt: Date(),
                detectedDirectories: detectedDirectories,
                workflowPaths: workflowPaths,
                mcpPaths: mcpPaths
            )
        }

        public static func failure(_ message: String) -> SyncResult {
            SyncResult(
                success: false,
                message: message,
                isNewClone: false,
                updatedAt: Date(),
                detectedDirectories: [],
                workflowPaths: [],
                mcpPaths: []
            )
        }
    }
    
    // MARK: - RemoteResourceRepository Protocol
    
    public let id: String
    public let name: String
    public let supportedTypes: Set<RemoteContentType> = [.skill, .workflow, .mcp]
    public private(set) var lastSyncDate: Date?
    
    // MARK: - Private Properties
    
    private let gitURL: String
    private let localClonePath: URL
    private let skillsPaths: [String]
    private let accessToken: String?
    private let logger = Logger(subsystem: "com.nolon", category: "GitRepository")
    
    // Lazy initialized local folder repository for scanning
    private var localFolderRepo: LocalFolderRepository?
    
    // MARK: - Initialization
    
    public init(
        id: String,
        name: String,
        gitURL: String,
        localClonePath: URL,
        skillsPaths: [String] = ["."],
        accessToken: String? = nil
    ) throws {
        self.id = id
        self.name = name
        self.gitURL = gitURL
        self.localClonePath = localClonePath
        self.skillsPaths = skillsPaths
        self.accessToken = accessToken

        // If the repository already exists locally, initialize the scanner without pulling.
        if STPath(localClonePath).isExists {
            localFolderRepo = Self.makeLocalFolderRepository(
                id: id,
                name: name,
                localClonePath: localClonePath,
                skillsPaths: skillsPaths
            )
        }

        let watchPaths = Self.resolveBasePaths(localClonePath: localClonePath, skillsPaths: skillsPaths)
        Task { @MainActor in
            RemoteRepositoryWatchCenter.shared.ensureWatchingGit(
                repoId: id,
                clonePath: localClonePath.path,
                effectiveSkillsPaths: watchPaths
            )
        }
    }
    
    public init(repository: RemoteRepository) throws {
        guard let gitURL = repository.gitURL else {
            throw RepositoryError.invalidConfiguration
        }
        
        self.id = repository.id
        self.name = repository.name
        self.gitURL = gitURL
        self.localClonePath = repository.localClonePath
        // `skillsPaths` stores paths relative to repository root (e.g. ".", "skills", "subdir/skills").
        // Do NOT use `effectiveSkillsPaths` here because it expands to absolute paths and breaks path joining.
        self.skillsPaths = repository.skillsPaths.isEmpty ? ["."] : repository.skillsPaths
        self.accessToken = repository.accessToken

        // If the repository already exists locally, initialize the scanner without pulling.
        if STPath(localClonePath).isExists {
            localFolderRepo = Self.makeLocalFolderRepository(
                id: id,
                name: name,
                localClonePath: localClonePath,
                skillsPaths: skillsPaths
            )
        }
    }
    
    // MARK: - Sync Operations
    
    public func sync() async throws -> Bool {
        logger.info("🔄 Syncing Git repository: \(self.name)")
        logger.info("  - Git URL: \(self.gitURL)")
        logger.info("  - Local path: \(self.localClonePath.path)")

        do {
            let outcome = try await SkillsRepositoryFacade.syncGitRepository(
                gitURL: gitURL,
                localClonePath: localClonePath,
                accessToken: accessToken
            )
            logger.info("✅ Git sync mode: \(String(describing: outcome.mode), privacy: .public)")
            lastSyncDate = outcome.updatedAt
        } catch let error as SkillsRepositoryFacade.SyncError {
            throw Self.mapSyncError(error)
        }

        // Initialize local folder repository after sync
        localFolderRepo = makeLocalFolderRepository()

        return true
    }

    /// Clone or pull a Git repository (used by UI "Sync" actions), returning detected skill directories.
    public static func syncRepository(_ repository: RemoteRepository) async throws -> SyncResult {
        guard repository.templateType == .git else {
            return .failure("Not a Git repository")
        }

        let resolvedPath = repository.localClonePath

        do {
            let outcome = try await SkillsRepositoryFacade.syncGitRepository(
                gitURL: repository.gitURL ?? "",
                localClonePath: resolvedPath,
                accessToken: repository.accessToken
            )

            let resources = SkillsRepositoryFacade.discoverRepositoryResources(at: resolvedPath)
            let detected = resources.skillsDirectories.map {
                SkillsDirectoryCandidate(path: $0.path, skillCount: $0.skillCount, skillNames: $0.skillNames)
            }
            return .success(
                isNewClone: outcome.mode == .cloned,
                detectedDirectories: detected,
                workflowPaths: resources.workflows.map(\.path),
                mcpPaths: resources.mcps.map(\.path)
            )
        } catch let error as SkillsRepositoryFacade.SyncError {
            let mapped = mapSyncError(error)
            switch mapped {
            case .sshNotAvailable:
                throw mapped
            default:
                return .failure(mapped.localizedDescription)
            }
        } catch let error as SyncError {
            switch error {
            case .sshNotAvailable:
                throw error
            default:
                return .failure(error.localizedDescription)
            }
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    /// Delete local clone directory for a Git repository.
    public static func deleteRepository(_ repository: RemoteRepository) throws {
        let localPath = repository.localClonePath
        do {
            try STPath(localPath).deleteIncludingBrokenSymlink()
        } catch {
            throw SyncError.fileOperationFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Resource Fetching
    
    public func fetchSkills(query: String? = nil, limit: Int = 100) async throws -> [RemoteSkill] {
        try await ensureLocalRepoInitialized()
        guard let repo = localFolderRepo else {
            throw RepositoryError.gitOperationFailed("Repository not initialized")
        }
        return try await repo.fetchSkills(query: query, limit: limit)
    }
    
    public func fetchWorkflows(query: String? = nil, limit: Int = 100) async throws -> [RemoteWorkflow] {
        try await ensureLocalRepoInitialized()
        guard let repo = localFolderRepo else {
            throw RepositoryError.gitOperationFailed("Repository not initialized")
        }
        return try await repo.fetchWorkflows(query: query, limit: limit)
    }
    
    public func fetchMCPs(query: String? = nil, limit: Int = 100) async throws -> [RemoteMCP] {
        try await ensureLocalRepoInitialized()
        guard let repo = localFolderRepo else {
            throw RepositoryError.gitOperationFailed("Repository not initialized")
        }
        return try await repo.fetchMCPs(query: query, limit: limit)
    }
    
    public func downloadSkill(slug: String) async throws -> URL {
        try await ensureLocalRepoInitialized()
        guard let repo = localFolderRepo else {
            throw RepositoryError.gitOperationFailed("Repository not initialized")
        }
        return try await repo.downloadSkill(slug: slug)
    }
    
    public func downloadWorkflow(slug: String) async throws -> URL {
        try await ensureLocalRepoInitialized()
        guard let repo = localFolderRepo else {
            throw RepositoryError.gitOperationFailed("Repository not initialized")
        }
        return try await repo.downloadWorkflow(slug: slug)
    }
    
    public func downloadMCP(slug: String) async throws -> URL {
        try await ensureLocalRepoInitialized()
        guard let repo = localFolderRepo else {
            throw RepositoryError.gitOperationFailed("Repository not initialized")
        }
        return try await repo.downloadMCP(slug: slug)
    }
    
    // MARK: - Private Helpers
    
    private func ensureLocalRepoInitialized() async throws {
        if localFolderRepo != nil {
            return
        }

        // Do not auto-sync on browse. Only allow reading if a local clone already exists.
        guard STPath(localClonePath).isExists else {
            throw RepositoryError.gitOperationFailed(
                NSLocalizedString("error.git.not_cloned", comment: "Repository is not cloned yet")
            )
        }

        localFolderRepo = makeLocalFolderRepository()

        let watchPaths = resolveBasePaths(from: skillsPaths)
        await MainActor.run {
            RemoteRepositoryWatchCenter.shared.ensureWatchingGit(
                repoId: id,
                clonePath: localClonePath.path,
                effectiveSkillsPaths: watchPaths
            )
        }
    }

    private func resolveBasePaths(from skillsPaths: [String]) -> [String] {
        skillsPaths.map { path in
            // Backward-compatible: if settings already store absolute paths, use as-is.
            if path.hasPrefix("/") {
                return path
            }
            return path == "." ? localClonePath.path : localClonePath.appendingPathComponent(path).path
        }
    }

    private static func resolveBasePaths(localClonePath: URL, skillsPaths: [String]) -> [String] {
        skillsPaths.map { path in
            if path.hasPrefix("/") {
                return path
            }
            return path == "." ? localClonePath.path : localClonePath.appendingPathComponent(path).path
        }
    }

    private func makeLocalFolderRepository() -> LocalFolderRepository {
        Self.makeLocalFolderRepository(
            id: id,
            name: name,
            localClonePath: localClonePath,
            skillsPaths: skillsPaths
        )
    }

    private static func makeLocalFolderRepository(
        id: String,
        name: String,
        localClonePath: URL,
        skillsPaths: [String]
    ) -> LocalFolderRepository {
        LocalFolderRepository(
            id: id,
            name: name,
            basePaths: resolveBasePaths(localClonePath: localClonePath, skillsPaths: skillsPaths)
        )
    }
    
    private static func mapSyncError(_ error: SkillsRepositoryFacade.SyncError) -> SyncError {
        switch error {
        case .invalidURL:
            return .invalidURL
        case .accessTokenRequired:
            return .cloneFailed("Access token is required for token-only credential strategy")
        case let .sshNotAvailable(host):
            return .sshNotAvailable(host: host)
        case let .cloneFailed(message):
            return .cloneFailed(message)
        case let .pullFailed(message):
            return .pullFailed(message)
        case let .commandFailed(message):
            return .pullFailed(message)
        }
    }

    // MARK: - Skills Directory Detection

    public static func detectSkillsDirectories(at repoPath: URL) -> [SkillsDirectoryCandidate] {
        SkillsRepositoryFacade.discoverSkillsDirectories(at: repoPath).map {
            SkillsDirectoryCandidate(
                path: $0.path,
                skillCount: $0.skillCount,
                skillNames: $0.skillNames
            )
        }
    }

    public static func detectRepositoryResources(at repoPath: URL) -> RepositoryResources {
        let resources = SkillsRepositoryFacade.discoverRepositoryResources(at: repoPath)
        return RepositoryResources(
            skillsDirectories: resources.skillsDirectories.map {
                SkillsDirectoryCandidate(
                    path: $0.path,
                    skillCount: $0.skillCount,
                    skillNames: $0.skillNames
                )
            },
            workflowPaths: resources.workflows.map(\.path),
            mcpPaths: resources.mcps.map(\.path)
        )
    }
}
