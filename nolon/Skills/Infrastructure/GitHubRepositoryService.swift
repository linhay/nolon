import Foundation
import SwiftGit
import os.log

/// Service for managing Git repository cloning and updates (GitHub, GitLab, Bitbucket)
public actor GitRepositoryService {

    public static let shared = GitRepositoryService()

    private let fileManager: FileManager
    private let repositoriesPath: URL
    private let git: Git
    private let logger = Logger(subsystem: "com.nolon", category: "GitRepositoryService")

    public init() {
        self.fileManager = .default
        self.repositoriesPath = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".nolon/repositories")

        // Initialize SwiftGit with auto environment (prefers embedded git)
        self.git = try! Git.shared

        // Ensure repositories directory exists
        try? fileManager.createDirectory(
            at: repositoriesPath,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    // MARK: - Public API

    /// Candidate skills directory with metadata
    public struct SkillsDirectoryCandidate: Sendable, Identifiable {
        public let id: String
        public let path: String  // Relative path from repository root
        public let skillCount: Int  // Number of skills in this directory
        public let skillNames: [String]  // Preview of skill names

        public init(path: String, skillCount: Int, skillNames: [String]) {
            self.id = path
            self.path = path
            self.skillCount = skillCount
            self.skillNames = skillNames
        }
    }

    /// Sync result containing status and any error message
    public struct SyncResult: Sendable {
        public let success: Bool
        public let message: String
        public let isNewClone: Bool
        public let updatedAt: Date
        public let detectedDirectories: [SkillsDirectoryCandidate]

        public static func success(
            isNewClone: Bool, detectedDirectories: [SkillsDirectoryCandidate] = []
        ) -> SyncResult {
            SyncResult(
                success: true,
                message: isNewClone
                    ? NSLocalizedString(
                        "git.clone_success", comment: "Repository cloned successfully")
                    : NSLocalizedString(
                        "git.pull_success", comment: "Repository updated successfully"),
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

    /// Clone or update a repository
    public func syncRepository(_ repository: RemoteRepository) async throws -> SyncResult {
        logger.info("🔄 syncRepository called")
        logger.info("  - Repository ID: \(repository.id)")
        logger.info("  - Repository Name: \(repository.name)")
        logger.info("  - Git URL: \(repository.gitURL ?? "nil")")
        logger.info("  - Has Token: \(repository.accessToken != nil)")

        guard let gitURL = repository.gitURL, !gitURL.isEmpty else {
            logger.error("❌ Invalid or empty Git URL")
            throw GitRepositoryError.invalidURL
        }

        let resolvedPath = repository.localClonePath
        let repoExists = fileManager.fileExists(atPath: resolvedPath.path)

        logger.info("  - Local clone path: \(resolvedPath.path)")
        logger.info("  - Repo exists locally: \(repoExists)")

        if repoExists {
            logger.info("📥 Repository exists, performing pull...")
            return try await pullRepository(at: resolvedPath)
        } else {
            logger.info("📦 Repository not found locally, performing clone...")
            return try await cloneRepository(
                from: gitURL, to: resolvedPath, accessToken: repository.accessToken)
        }
    }

    /// Check if repository exists locally
    public func isCloned(_ repository: RemoteRepository) -> Bool {
        let localPath = repository.localClonePath
        return fileManager.fileExists(atPath: localPath.path)
    }

    public func resolveClonePath(for repository: RemoteRepository) -> URL {
        return repository.localClonePath
    }

    public func deleteRepository(_ repository: RemoteRepository) throws {
        let localPath = repository.localClonePath
        if fileManager.fileExists(atPath: localPath.path) {
            try fileManager.removeItem(at: localPath)
        }
    }

    // MARK: - Git Operations

    private func cloneRepository(from url: String, to destination: URL, accessToken: String? = nil)
        async throws -> SyncResult
    {
        logger.info("🔧 cloneRepository called")
        logger.info("  - URL: \(url)")
        logger.info("  - Destination: \(destination.path)")
        logger.info("  - Has Token: \(accessToken != nil)")

        guard let components = Self.extractURLComponents(from: url) else {
            logger.error("❌ Failed to parse URL: \(url)")
            return .failure("Invalid repository URL")
        }

        let host = components.host
        logger.info("  - Host: \(host)")
        logger.info("  - Owner: \(components.owner)")
        logger.info("  - Repo: \(components.repo)")

        // Determine which URL to use (SSH preferred, then HTTPS with token, then fail)
        var cloneURL = url
        let isHTTPS = url.lowercased().hasPrefix("https://")

        if isHTTPS {
            // If we have a token, use HTTPS with token authentication
            if let token = accessToken, !token.isEmpty {
                // Build authenticated URL: https://oauth2:TOKEN@host/owner/repo.git
                cloneURL =
                    "https://oauth2:\(token)@\(host)/\(components.owner)/\(components.repo).git"
                logger.info("🔑 Using token-authenticated HTTPS URL")
            } else {
                // No token, try SSH
                let sshAvailable = await testSSHConnection(host: host)

                if sshAvailable {
                    // Convert to SSH URL
                    if let sshURL = convertToSSHURL(url) {
                        logger.info("🔀 Using SSH URL: \(sshURL)")
                        cloneURL = sshURL
                    }
                } else {
                    // SSH not available and no token, need token
                    logger.warning("⚠️ SSH not available for host: \(host)")
                    throw GitRepositoryError.sshNotAvailable(host: host)
                }
            }
        }

        guard let repositoryURL = URL(string: cloneURL) else {
            logger.error("❌ Failed to create URL object from string: \(cloneURL)")
            return .failure("Invalid repository URL")
        }

        do {
            logger.info("⏳ Starting git clone with depth=1...")
            // Don't log the full URL if it contains a token
            if accessToken != nil {
                logger.info("  - Clone URL: [contains token, hidden]")
            } else {
                logger.info("  - Clone URL: \(cloneURL)")
            }
            // Use SwiftGit's clone with shallow clone (depth 1)
            try await git.clone([.depth(1)], repository: repositoryURL, directory: destination.path)
            logger.info("✅ Clone completed successfully")

            // Detect skills directories after successful clone
            let detectedDirs = await detectSkillsDirectories(at: destination)
            logger.info("📂 Detected \(detectedDirs.count) skill directories")
            return .success(isNewClone: true, detectedDirectories: detectedDirs)
        } catch {
            logger.error("❌ Clone failed with error: \(error.localizedDescription)")
            logger.error("  - Full error: \(String(describing: error))")
            throw GitRepositoryError.cloneFailed(error.localizedDescription)
        }
    }

    private func pullRepository(at path: URL) async throws -> SyncResult {
        logger.info("🔧 pullRepository called")
        logger.info("  - Path: \(path.path)")

        do {
            // Use SwiftGit's Repository pull with ff-only option
            let repository = git.repository(at: path)
            logger.info("⏳ Starting git pull with ff-only...")
            try await repository.pull([.ffOnly])
            logger.info("✅ Pull completed successfully")

            // Detect skills directories after successful pull
            let detectedDirs = await detectSkillsDirectories(at: path)
            logger.info("📂 Detected \(detectedDirs.count) skill directories")
            return .success(isNewClone: false, detectedDirectories: detectedDirs)
        } catch {
            logger.error("❌ Pull failed with error: \(error.localizedDescription)")
            logger.error("  - Full error: \(String(describing: error))")
            throw GitRepositoryError.pullFailed(error.localizedDescription)
        }
    }

    // MARK: - Skills Directory Detection

    /// Detect all directories containing skills
    /// Supports three repository structures:
    /// 1. Root directory is a single skill (contains SKILL.md)
    /// 2. Root directory is a skill list (subdirectories are skills)
    /// 3. Multiple subdirectories contain skill lists
    public func detectSkillsDirectories(at repoPath: URL) async -> [SkillsDirectoryCandidate] {
        var candidates: [SkillsDirectoryCandidate] = []
        
        // Case 1: Check if root directory itself is a skill
        if SkillParser.isSkillDirectory(at: repoPath.path) {
            // Root is a single skill - return parent as the container
            let skillName = SkillParser.skillName(at: repoPath.path) ?? repoPath.lastPathComponent
            candidates.append(SkillsDirectoryCandidate(
                path: ".",
                skillCount: 1,
                skillNames: [skillName]
            ))
            return candidates
        }
        
        // Case 2 & 3: Search for directories containing skills
        let maxDepth = 5
        searchForSkillsDirectories(
            at: repoPath.path, 
            relativePath: "", 
            currentDepth: 0, 
            maxDepth: maxDepth,
            candidates: &candidates
        )

        return candidates.sorted { a, b in
            if a.path == "." { return true }
            if b.path == "." { return false }
            return a.skillCount > b.skillCount
        }
    }

    private func searchForSkillsDirectories(
        at absolutePath: String,
        relativePath: String,
        currentDepth: Int,
        maxDepth: Int,
        candidates: inout [SkillsDirectoryCandidate]
    ) {
        guard currentDepth <= maxDepth else { return }

        // Check if current directory contains skill subdirectories
        let skillsInCurrentDir = findSkillsInDirectory(absolutePath)

        if !skillsInCurrentDir.isEmpty {
            let candidate = SkillsDirectoryCandidate(
                path: relativePath.isEmpty ? "." : relativePath,
                skillCount: skillsInCurrentDir.count,
                skillNames: Array(skillsInCurrentDir.prefix(5))  // Preview first 5
            )
            candidates.append(candidate)
        }

        // Recursively search subdirectories
        guard let contents = try? fileManager.contentsOfDirectory(atPath: absolutePath) else {
            return
        }

        for item in contents {
            // Skip .git and common build directories, allow hidden dirs like .agent
            guard ![".git", "node_modules", "build", "dist", ".build"].contains(item) else {
                continue
            }

            let itemAbsolutePath = (absolutePath as NSString).appendingPathComponent(item)
            var isDirectory: ObjCBool = false

            guard fileManager.fileExists(atPath: itemAbsolutePath, isDirectory: &isDirectory),
                isDirectory.boolValue
            else {
                continue
            }
            
            // Skip if this directory is itself a skill (it's a leaf node, not a container)
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

    /// Find all skill directories directly under the given path
    /// Uses SkillParser to validate each potential skill directory
    private func findSkillsInDirectory(_ path: String) -> [String] {
        guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else {
            return []
        }

        var skillNames: [String] = []

        for item in contents {
            // Skip hidden files/directories (except .agent which may contain skills)
            if item.hasPrefix(".") && item != ".agent" { continue }

            let itemPath = (path as NSString).appendingPathComponent(item)
            var isDirectory: ObjCBool = false

            guard fileManager.fileExists(atPath: itemPath, isDirectory: &isDirectory),
                isDirectory.boolValue
            else {
                continue
            }

            // Use SkillParser to check if this is a valid skill directory
            if let skillName = SkillParser.skillName(at: itemPath) {
                skillNames.append(skillName)
            }
        }

        return skillNames
    }

    // MARK: - Helpers

    /// Extract host, owner and repo from a Git URL (HTTPS or SSH)
    /// Supports: https://gitlab.dxy.net/ios-developer/tod-skills
    ///           git@gitlab.dxy.net:ios-developer/tod-skills.git
    public static func extractURLComponents(from url: String) -> (
        host: String, owner: String, repo: String
    )? {
        let cleaned =
            url
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
    /// https://gitlab.dxy.net/ios-developer/tod-skills → git@gitlab.dxy.net:ios-developer/tod-skills.git
    public func convertToSSHURL(_ httpsURL: String) -> String? {
        guard let components = Self.extractURLComponents(from: httpsURL) else {
            return nil
        }
        return "git@\(components.host):\(components.owner)/\(components.repo).git"
    }

    /// Test if SSH connection is available for a host
    /// Uses: ssh -T -o BatchMode=yes -o ConnectTimeout=5 git@<host>
    public func testSSHConnection(host: String) async -> Bool {
        logger.info("🔐 Testing SSH connection to: \(host)")

        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
            process.arguments = [
                "-T",
                "-o", "BatchMode=yes",
                "-o", "ConnectTimeout=5",
                "-o", "StrictHostKeyChecking=no",
                "git@\(host)",
            ]

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            try process.run()
            process.waitUntilExit()

            // SSH returns exit code 1 for successful auth with "Hi xxx" message
            // Exit code 255 typically means connection/auth failure
            let exitCode = process.terminationStatus

            // Read stderr for more info
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

            logger.info("  - SSH exit code: \(exitCode)")
            logger.info("  - SSH output: \(errorOutput.prefix(200))")

            // GitLab/GitHub typically return exit code 1 with welcome message on success
            // Exit code 255 or "Permission denied" indicates failure
            let isSuccess =
                exitCode != 255 && !errorOutput.lowercased().contains("permission denied")
            logger.info("  - SSH available: \(isSuccess)")

            return isSuccess
        } catch {
            logger.error("❌ SSH test failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Get the local clone path for a git URL using format: domain/owner@repo
    public static func clonePathForURL(_ gitURL: String, repositoriesPath: URL) -> URL {
        guard let components = extractURLComponents(from: gitURL) else {
            return repositoriesPath.appendingPathComponent("unknown")
        }
        // Format: ~/.nolon/repositories/gitlab.dxy.net/ios-developer@tod-skills
        return
            repositoriesPath
            .appendingPathComponent(components.host)
            .appendingPathComponent("\(components.owner)@\(components.repo)")
    }

}

// MARK: - Errors

public enum GitRepositoryError: LocalizedError {
    case invalidURL
    case cloneFailed(String)
    case pullFailed(String)
    case notCloned
    case sshNotAvailable(host: String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return NSLocalizedString(
                "error.git.invalid_url", comment: "Invalid Git repository URL")
        case .cloneFailed(let reason):
            return String(
                format: NSLocalizedString(
                    "error.git.clone_failed", comment: "Failed to clone repository: %@"), reason)
        case .pullFailed(let reason):
            return String(
                format: NSLocalizedString(
                    "error.git.pull_failed", comment: "Failed to update repository: %@"), reason)
        case .notCloned:
            return NSLocalizedString(
                "error.git.not_cloned", comment: "Repository is not cloned yet")
        case .sshNotAvailable(let host):
            return String(
                format: NSLocalizedString(
                    "error.git.ssh_not_available",
                    comment:
                        "SSH authentication not configured for %@. Please configure SSH key or provide a Personal Access Token."
                ),
                host)
        }
    }
}
