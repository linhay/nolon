import Foundation
import SwiftGit
import os.log
import STFilePath

/// Git repository implementation using SwiftGit
/// Supports GitHub, GitLab, and other Git hosting services
/// Replaces GitHubRepositoryService.swift
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

    public struct SyncResult: Sendable {
        public let success: Bool
        public let message: String
        public let isNewClone: Bool
        public let updatedAt: Date
        public let detectedDirectories: [SkillsDirectoryCandidate]

        public static func success(isNewClone: Bool, detectedDirectories: [SkillsDirectoryCandidate] = []) -> SyncResult {
            SyncResult(
                success: true,
                message: isNewClone
                    ? NSLocalizedString("git.clone_success", comment: "Repository cloned successfully")
                    : NSLocalizedString("git.pull_success", comment: "Repository updated successfully"),
                isNewClone: isNewClone,
                updatedAt: Date(),
                detectedDirectories: detectedDirectories
            )
        }

        public static func failure(_ message: String) -> SyncResult {
            SyncResult(
                success: false,
                message: message,
                isNewClone: false,
                updatedAt: Date(),
                detectedDirectories: []
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
    private let git: Git
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
        self.git = try Git.shared

        // If the repository already exists locally, initialize the scanner without pulling.
        if STPath(localClonePath).isExists {
            localFolderRepo = makeLocalFolderRepository()
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
        self.git = try Git.shared

        // If the repository already exists locally, initialize the scanner without pulling.
        if STPath(localClonePath).isExists {
            localFolderRepo = makeLocalFolderRepository()
        }
    }
    
    // MARK: - Sync Operations
    
    public func sync() async throws -> Bool {
        logger.info("🔄 Syncing Git repository: \(self.name)")
        logger.info("  - Git URL: \(self.gitURL)")
        logger.info("  - Local path: \(self.localClonePath.path)")
        
        let repoExists = STPath(localClonePath).isExists
        
        if repoExists {
            logger.info("📥 Repository exists, performing pull...")
            try await pullRepository()
        } else {
            logger.info("📦 Repository not found locally, performing clone...")
            try await cloneRepository()
        }
        
        lastSyncDate = Date()
        
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
        let existedBefore = STPath(resolvedPath).isExists

        do {
            let gitRepo = try GitRepository(repository: repository)
            _ = try await gitRepo.sync()

            let detected = detectSkillsDirectories(at: resolvedPath)
            return .success(isNewClone: !existedBefore, detectedDirectories: detected)
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

    private func makeLocalFolderRepository() -> LocalFolderRepository {
        LocalFolderRepository(
            id: id,
            name: name,
            basePaths: resolveBasePaths(from: skillsPaths)
        )
    }
    
    private func cloneRepository() async throws {
        logger.info("🔧 Cloning repository")
        
        guard let components = Self.extractURLComponents(from: gitURL) else {
            logger.error("❌ Failed to parse URL: \(self.gitURL)")
            throw SyncError.invalidURL
        }
        
        let host = components.host
        logger.info("  - Host: \(host)")
        logger.info("  - Owner: \(components.owner)")
        logger.info("  - Repo: \(components.repo)")
        
        // Determine which URL to use
        var cloneURL = gitURL
        let isHTTPS = gitURL.lowercased().hasPrefix("https://")
        
        if isHTTPS {
            // If we have a token, use HTTPS with token authentication
            if let token = accessToken, !token.isEmpty {
                cloneURL = "https://oauth2:\(token)@\(host)/\(components.owner)/\(components.repo).git"
                logger.info("🔑 Using token-authenticated HTTPS URL")
            } else {
                // No token, try SSH
                let sshAvailable = await testSSHConnection(host: host)
                
                if sshAvailable {
                    if let sshURL = convertToSSHURL(gitURL) {
                        logger.info("🔀 Using SSH URL: \(sshURL)")
                        cloneURL = sshURL
                    }
                } else {
                    logger.warning("⚠️ SSH not available for host: \(host)")
                    throw SyncError.sshNotAvailable(host: host)
                }
            }
        }
        
        guard let repositoryURL = URL(string: cloneURL) else {
            logger.error("❌ Failed to create URL object from string: \(cloneURL)")
            throw SyncError.invalidURL
        }
        
        do {
            let parent = localClonePath.deletingLastPathComponent()
            STFolder(parent).createIfNotExists()

            logger.info("⏳ Starting git clone with depth=1...")
            try await git.clone([.depth(1)], repository: repositoryURL, directory: localClonePath.path)
            logger.info("✅ Clone completed successfully")
        } catch {
            logger.error("❌ Clone failed with error: \(error.localizedDescription)")
            throw SyncError.cloneFailed(error.localizedDescription)
        }
    }
    
    private func pullRepository() async throws {
        logger.info("🔧 Pulling repository updates")
        
        do {
            let repository = git.repository(at: localClonePath)
            logger.info("⏳ Starting git pull with ff-only...")
            try await repository.pull([.ffOnly])
            logger.info("✅ Pull completed successfully")
        } catch {
            logger.error("❌ Pull failed with error: \(error.localizedDescription)")
            throw SyncError.pullFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Git Utilities
    
    /// Extract host, owner and repo from a Git URL (HTTPS or SSH)
    private static func extractURLComponents(from url: String) -> (host: String, owner: String, repo: String)? {
        let cleaned = url
            .replacingOccurrences(of: ".git", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // SSH format: git@host:owner/repo
        if cleaned.hasPrefix("git@") {
            let withoutPrefix = cleaned.dropFirst(4)  // Remove "git@"
            if let colonIndex = withoutPrefix.firstIndex(of: ":") {
                let host = String(withoutPrefix[..<colonIndex])
                let path = String(withoutPrefix[withoutPrefix.index(after: colonIndex)...])
                let pathComponents = path.split(separator: "/")
                if pathComponents.count >= 2 {
                    let owner = String(pathComponents[0])
                    let repo = String(pathComponents[1])
                    return (host, owner, repo)
                }
            }
        }
        
        // HTTPS format: https://host/owner/repo
        if let urlObj = URL(string: cleaned), let host = urlObj.host {
            let pathComponents = urlObj.path
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                .split(separator: "/")
            if pathComponents.count >= 2 {
                let owner = String(pathComponents[0])
                let repo = String(pathComponents[1])
                return (host, owner, repo)
            }
        }
        
        return nil
    }
    
    /// Convert HTTPS URL to SSH URL
    private func convertToSSHURL(_ httpsURL: String) -> String? {
        guard let components = Self.extractURLComponents(from: httpsURL) else {
            return nil
        }
        return "git@\(components.host):\(components.owner)/\(components.repo).git"
    }
    
    /// Test if SSH connection is available for a host
    private func testSSHConnection(host: String) async -> Bool {
        logger.info("🔐 Testing SSH connection to: \(host)")
        
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
            process.arguments = [
                "-T",
                "-o", "BatchMode=yes",
                "-o", "ConnectTimeout=5",
                "-o", "StrictHostKeyChecking=no",
                "git@\(host)"
            ]
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            try process.run()
            process.waitUntilExit()
            
            let exitCode = process.terminationStatus
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
            
            logger.info("  - SSH exit code: \(exitCode)")
            logger.info("  - SSH output: \(errorOutput.prefix(200))")
            
            let isSuccess = exitCode != 255 && !errorOutput.lowercased().contains("permission denied")
            logger.info("  - SSH available: \(isSuccess)")
            
            return isSuccess
        } catch {
            logger.error("❌ SSH test failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Skills Directory Detection (replacing GitRepositoryService)

    /// Detect all directories containing skills.
    /// Supports three repository structures:
    /// 1. Root directory is a single skill (contains SKILL.md)
    /// 2. Root directory is a skill list (subdirectories are skills)
    /// 3. Multiple subdirectories contain skill lists
    public static func detectSkillsDirectories(at repoPath: URL) -> [SkillsDirectoryCandidate] {
        var candidates: [SkillsDirectoryCandidate] = []

        if SkillParser.isSkillDirectory(at: repoPath.path) {
            let skillName = SkillParser.skillName(at: repoPath.path) ?? repoPath.lastPathComponent
            candidates.append(
                SkillsDirectoryCandidate(
                    path: ".",
                    skillCount: 1,
                    skillNames: [skillName]
                )
            )
            return candidates
        }

        searchForSkillsDirectories(
            at: repoPath.path,
            relativePath: "",
            currentDepth: 0,
            maxDepth: 5,
            candidates: &candidates
        )

        return candidates.sorted { a, b in
            if a.path == "." { return true }
            if b.path == "." { return false }
            return a.skillCount > b.skillCount
        }
    }

    private static func searchForSkillsDirectories(
        at absolutePath: String,
        relativePath: String,
        currentDepth: Int,
        maxDepth: Int,
        candidates: inout [SkillsDirectoryCandidate]
    ) {
        guard currentDepth <= maxDepth else { return }

        let skillsInCurrentDir = findSkillsInDirectory(absolutePath)
        if !skillsInCurrentDir.isEmpty {
            candidates.append(
                SkillsDirectoryCandidate(
                    path: relativePath.isEmpty ? "." : relativePath,
                    skillCount: skillsInCurrentDir.count,
                    skillNames: Array(skillsInCurrentDir.prefix(5))
                )
            )
        }

        guard let folders = try? STFolder(absolutePath).folders() else { return }

        for folder in folders {
            let item = folder.url.lastPathComponent
            guard ![".git", "node_modules", "build", "dist", ".build"].contains(item) else { continue }
            let itemAbsolutePath = folder.url.path

            if SkillParser.isSkillDirectory(at: itemAbsolutePath) {
                continue
            }

            let itemRelativePath = relativePath.isEmpty ? item : "\(relativePath)/\(item)"
            searchForSkillsDirectories(
                at: itemAbsolutePath,
                relativePath: itemRelativePath,
                currentDepth: currentDepth + 1,
                maxDepth: maxDepth,
                candidates: &candidates
            )
        }
    }

    private static func findSkillsInDirectory(_ path: String) -> [String] {
        guard let folders = try? STFolder(path).folders() else {
            return []
        }

        var skillNames: [String] = []
        for folder in folders {
            let item = folder.url.lastPathComponent
            if item.hasPrefix(".") && item != ".agent" { continue }

            let itemPath = folder.url.path
            if let skillName = SkillParser.skillName(at: itemPath) {
                skillNames.append(skillName)
            }
        }

        return skillNames
    }
}
