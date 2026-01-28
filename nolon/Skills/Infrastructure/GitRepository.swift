import Foundation
import SwiftGit
import os.log

/// Git repository implementation using SwiftGit
/// Supports GitHub, GitLab, and other Git hosting services
/// Replaces GitHubRepositoryService.swift
public actor GitRepository: RemoteResourceRepository {
    
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
    private let fileManager: FileManager
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
        accessToken: String? = nil,
        fileManager: FileManager = .default
    ) throws {
        self.id = id
        self.name = name
        self.gitURL = gitURL
        self.localClonePath = localClonePath
        self.skillsPaths = skillsPaths
        self.accessToken = accessToken
        self.fileManager = fileManager
        self.git = try Git.shared

        // If the repository already exists locally, initialize the scanner without pulling.
        if fileManager.fileExists(atPath: localClonePath.path) {
            localFolderRepo = LocalFolderRepository(
                id: id,
                name: name,
                basePaths: resolveBasePaths(from: skillsPaths)
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
        self.fileManager = .default
        self.git = try Git.shared

        // If the repository already exists locally, initialize the scanner without pulling.
        if fileManager.fileExists(atPath: localClonePath.path) {
            localFolderRepo = LocalFolderRepository(
                id: id,
                name: name,
                basePaths: resolveBasePaths(from: skillsPaths)
            )
        }
    }
    
    // MARK: - Sync Operations
    
    public func sync() async throws -> Bool {
        logger.info("🔄 Syncing Git repository: \(self.name)")
        logger.info("  - Git URL: \(self.gitURL)")
        logger.info("  - Local path: \(self.localClonePath.path)")
        
        let repoExists = fileManager.fileExists(atPath: localClonePath.path)
        
        if repoExists {
            logger.info("📥 Repository exists, performing pull...")
            try await pullRepository()
        } else {
            logger.info("📦 Repository not found locally, performing clone...")
            try await cloneRepository()
        }
        
        lastSyncDate = Date()
        
        // Initialize local folder repository after sync
        localFolderRepo = LocalFolderRepository(
            id: id,
            name: name,
            basePaths: resolveBasePaths(from: skillsPaths)
        )
        
        return true
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
        guard fileManager.fileExists(atPath: localClonePath.path) else {
            throw RepositoryError.gitOperationFailed(
                NSLocalizedString("error.git.not_cloned", comment: "Repository is not cloned yet")
            )
        }

        localFolderRepo = LocalFolderRepository(
            id: id,
            name: name,
            basePaths: resolveBasePaths(from: skillsPaths)
        )
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
    
    private func cloneRepository() async throws {
        logger.info("🔧 Cloning repository")
        
        guard let components = Self.extractURLComponents(from: gitURL) else {
            logger.error("❌ Failed to parse URL: \(self.gitURL)")
            throw RepositoryError.invalidURL
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
                    throw RepositoryError.gitOperationFailed("SSH not available and no access token provided")
                }
            }
        }
        
        guard let repositoryURL = URL(string: cloneURL) else {
            logger.error("❌ Failed to create URL object from string: \(cloneURL)")
            throw RepositoryError.invalidURL
        }
        
        do {
            logger.info("⏳ Starting git clone with depth=1...")
            try await git.clone([.depth(1)], repository: repositoryURL, directory: localClonePath.path)
            logger.info("✅ Clone completed successfully")
        } catch {
            logger.error("❌ Clone failed with error: \(error.localizedDescription)")
            throw RepositoryError.gitOperationFailed("Clone failed: \(error.localizedDescription)")
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
            throw RepositoryError.gitOperationFailed("Pull failed: \(error.localizedDescription)")
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
}
