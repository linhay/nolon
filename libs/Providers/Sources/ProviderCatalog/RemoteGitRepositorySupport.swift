import Foundation
import SKProcessRunner
import STFilePath

public enum RemoteGitRepositorySupport {
    public struct URLComponents: Sendable, Equatable {
        public let host: String
        public let owner: String
        public let repo: String

        public init(host: String, owner: String, repo: String) {
            self.host = host
            self.owner = owner
            self.repo = repo
        }
    }

    public struct SkillsDirectoryCandidate: Sendable, Identifiable, Equatable {
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

    public struct ResourceFile: Sendable, Equatable {
        public let path: String
        public let kind: String

        public init(path: String, kind: String) {
            self.path = path
            self.kind = kind
        }
    }

    public struct RepositoryResources: Sendable, Equatable {
        public let skillsDirectories: [SkillsDirectoryCandidate]
        public let workflows: [ResourceFile]
        public let mcps: [ResourceFile]

        public init(
            skillsDirectories: [SkillsDirectoryCandidate],
            workflows: [ResourceFile],
            mcps: [ResourceFile]
        ) {
            self.skillsDirectories = skillsDirectories
            self.workflows = workflows
            self.mcps = mcps
        }
    }

    public enum SyncMode: Sendable {
        case cloned
        case pulled
    }

    public enum PullStrategy: String, Sendable, Equatable {
        case ffOnly = "ff-only"
        case rebase
        case merge
    }

    public enum CredentialStrategy: String, Sendable, Equatable {
        case automatic = "automatic"
        case preferSSH = "prefer-ssh"
        case tokenOnly = "token-only"
        case sshOnly = "ssh-only"
    }

    public enum CredentialMode: String, Sendable, Equatable {
        case local = "local"
        case ssh = "ssh"
        case httpsToken = "https_token"
        case httpsAnonymous = "https_anonymous"
    }

    public struct SyncOptions: Sendable, Equatable {
        public let pullStrategy: PullStrategy
        public let credentialStrategy: CredentialStrategy

        public init(
            pullStrategy: PullStrategy = .ffOnly,
            credentialStrategy: CredentialStrategy = .automatic
        ) {
            self.pullStrategy = pullStrategy
            self.credentialStrategy = credentialStrategy
        }
    }

    public struct SyncOutcome: Sendable {
        public let mode: SyncMode
        public let updatedAt: Date
        public let defaultBranch: String?
        public let credentialMode: CredentialMode

        public init(
            mode: SyncMode,
            updatedAt: Date = Date(),
            defaultBranch: String? = nil,
            credentialMode: CredentialMode = .local
        ) {
            self.mode = mode
            self.updatedAt = updatedAt
            self.defaultBranch = defaultBranch
            self.credentialMode = credentialMode
        }
    }

    public enum SyncError: LocalizedError, Sendable, Equatable {
        case invalidURL
        case accessTokenRequired
        case sshNotAvailable(host: String)
        case cloneFailed(String)
        case pullFailed(String)
        case commandFailed(String)

        public var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid Git repository URL"
            case .accessTokenRequired:
                return "Access token is required for token-only credential strategy"
            case let .sshNotAvailable(host):
                return "SSH authentication not configured for \(host)"
            case let .cloneFailed(message):
                return "Failed to clone repository: \(message)"
            case let .pullFailed(message):
                return "Failed to update repository: \(message)"
            case let .commandFailed(message):
                return "Failed to run command: \(message)"
            }
        }
    }

    public static func extractURLComponents(from url: String) -> URLComponents? {
        let cleaned = url
            .replacingOccurrences(of: ".git", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.hasPrefix("git@") {
            let withoutPrefix = cleaned.dropFirst(4)
            if let colonIndex = withoutPrefix.firstIndex(of: ":") {
                let host = String(withoutPrefix[..<colonIndex])
                let path = String(withoutPrefix[withoutPrefix.index(after: colonIndex)...])
                let pathComponents = path.split(separator: "/")
                if pathComponents.count >= 2 {
                    return .init(
                        host: host,
                        owner: String(pathComponents[0]),
                        repo: String(pathComponents[1])
                    )
                }
            }
        }

        if let urlObj = URL(string: cleaned), let host = urlObj.host {
            let pathComponents = urlObj.path
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                .split(separator: "/")
            if pathComponents.count >= 2 {
                return .init(
                    host: host,
                    owner: String(pathComponents[0]),
                    repo: String(pathComponents[1])
                )
            }
        }
        return nil
    }

    public static func normalizeGitURL(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasPrefix(".") || trimmed.hasPrefix("/") || trimmed.hasPrefix("~") {
            return trimmed
        }

        if trimmed.hasPrefix("git@") && trimmed.contains(":") {
            if trimmed.hasSuffix(".git") {
                return trimmed
            }
            return trimmed
        }

        var urlString = trimmed
        if !urlString.contains("://") && !urlString.contains("@") {
            let components = urlString.split(separator: "/")
            if components.count >= 2 {
                let owner = components[0]
                let repo = components[1]
                urlString = "https://github.com/\(owner)/\(repo)"
            } else {
                return trimmed
            }
        }

        if let url = URL(string: urlString), let host = url.host {
            let pathComponents = url.path
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                .split(separator: "/")
            if pathComponents.count >= 2 {
                let owner = pathComponents[0]
                var repo = String(pathComponents[1])
                if repo.hasSuffix(".git") {
                    repo = String(repo.dropLast(4))
                }
                let scheme = url.scheme ?? "https"
                return "\(scheme)://\(host)/\(owner)/\(repo).git"
            }
        }

        return trimmed
    }

    public static func extractSubpath(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasPrefix(".") || trimmed.hasPrefix("/") || trimmed.hasPrefix("~") {
            return nil
        }

        if !trimmed.contains("://") && !trimmed.contains("@") {
            let components = trimmed.split(separator: "/")
            if components.count > 2 {
                return components.dropFirst(2).joined(separator: "/")
            }
            return nil
        }

        if let url = URL(string: trimmed) {
            let pathComponents = url.path
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                .split(separator: "/")
            if pathComponents.count > 2 {
                return pathComponents.dropFirst(2).joined(separator: "/")
            }
        }

        return nil
    }

    public static func suggestedClonePath(gitURL: String, repositoriesRoot: URL) -> URL? {
        guard let components = extractURLComponents(from: gitURL) else { return nil }
        return repositoriesRoot
            .appendingPathComponent(components.host)
            .appendingPathComponent("\(components.owner)@\(components.repo)")
    }

    public static func syncRepository(
        gitURL: String,
        localClonePath: URL,
        accessToken: String?,
        options: SyncOptions = .init()
    ) async throws -> SyncOutcome {
        if STPath(localClonePath).isExists {
            try runGit(arguments: pullArguments(repositoryPath: localClonePath.path, strategy: options.pullStrategy))
            return .init(
                mode: .pulled,
                defaultBranch: detectDefaultBranch(at: localClonePath),
                credentialMode: .local
            )
        }

        guard let components = extractURLComponents(from: gitURL) else {
            throw SyncError.invalidURL
        }

        let cloneEndpoint = try await resolveCloneURL(
            gitURL: gitURL,
            host: components.host,
            owner: components.owner,
            repo: components.repo,
            accessToken: accessToken,
            strategy: options.credentialStrategy
        )

        _ = STFolder(localClonePath.deletingLastPathComponent()).createIfNotExists()
        try runGit(arguments: ["clone", "--depth=1", cloneEndpoint.url, localClonePath.path])
        return .init(
            mode: .cloned,
            defaultBranch: detectDefaultBranch(at: localClonePath),
            credentialMode: cloneEndpoint.mode
        )
    }

    public static func detectDefaultBranch(at repositoryPath: URL) -> String? {
        let originHead = runGitCapture(
            arguments: ["-C", repositoryPath.path, "symbolic-ref", "--short", "refs/remotes/origin/HEAD"]
        )
        if originHead.status == 0 {
            let value = originHead.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if let branch = value.split(separator: "/").last, !branch.isEmpty {
                return String(branch)
            }
        }

        let current = runGitCapture(arguments: ["-C", repositoryPath.path, "branch", "--show-current"])
        if current.status == 0 {
            let value = current.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                return value
            }
        }

        let revParse = runGitCapture(arguments: ["-C", repositoryPath.path, "rev-parse", "--abbrev-ref", "HEAD"])
        if revParse.status == 0 {
            let value = revParse.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty, value != "HEAD" {
                return value
            }
        }

        return nil
    }

    public static func detectSkillsDirectories(at repoPath: URL, maxDepth: Int = 5) -> [SkillsDirectoryCandidate] {
        var candidates: [SkillsDirectoryCandidate] = []
        let root = STFolder(repoPath)

        if root.file("SKILL.md").isExists {
            let name = repoPath.lastPathComponent
            return [SkillsDirectoryCandidate(path: ".", skillCount: 1, skillNames: [name])]
        }

        scanDirectory(root, relativePath: "", currentDepth: 0, maxDepth: maxDepth, candidates: &candidates)

        return candidates.sorted { lhs, rhs in
            if lhs.path == "." { return true }
            if rhs.path == "." { return false }
            return lhs.skillCount > rhs.skillCount
        }
    }

    public static func detectRepositoryResources(at repoPath: URL, maxDepth: Int = 5) -> RepositoryResources {
        let root = STFolder(repoPath)
        let skills = detectSkillsDirectories(at: repoPath, maxDepth: maxDepth)
        var workflows: [ResourceFile] = []
        var mcps: [ResourceFile] = []

        scanResourceFiles(
            root: root,
            folder: root,
            currentDepth: 0,
            maxDepth: maxDepth,
            workflows: &workflows,
            mcps: &mcps
        )

        return RepositoryResources(
            skillsDirectories: skills,
            workflows: dedupResourceFiles(workflows),
            mcps: dedupResourceFiles(mcps)
        )
    }

    private static func scanDirectory(
        _ folder: STFolder,
        relativePath: String,
        currentDepth: Int,
        maxDepth: Int,
        candidates: inout [SkillsDirectoryCandidate]
    ) {
        guard currentDepth <= maxDepth else { return }

        let skills = findDirectSkillDirectories(in: folder)
        if !skills.isEmpty {
            candidates.append(
                SkillsDirectoryCandidate(
                    path: relativePath.isEmpty ? "." : relativePath,
                    skillCount: skills.count,
                    skillNames: Array(skills.prefix(5))
                )
            )
        }

        guard let children = try? folder.folders() else { return }
        for child in children {
            let name = child.url.lastPathComponent
            guard ![".git", "node_modules", "build", "dist", ".build"].contains(name) else { continue }

            if child.file("SKILL.md").isExists {
                continue
            }

            let childRelativePath = relativePath.isEmpty ? name : "\(relativePath)/\(name)"
            scanDirectory(
                child,
                relativePath: childRelativePath,
                currentDepth: currentDepth + 1,
                maxDepth: maxDepth,
                candidates: &candidates
            )
        }
    }

    private static func findDirectSkillDirectories(in folder: STFolder) -> [String] {
        guard let children = try? folder.folders() else { return [] }
        var names: [String] = []
        for child in children {
            let name = child.url.lastPathComponent
            if name.hasPrefix(".") && name != ".agent" {
                continue
            }
            let skillFile = child.file("SKILL.md")
            if skillFile.isExists {
                if let content = try? skillFile.read() {
                    names.append(
                        SkillSpecificationParser.extractSkillDisplayName(
                            from: content,
                            fallbackDirectoryName: name
                        )
                    )
                } else {
                    names.append(name)
                }
            }
        }
        return names.sorted()
    }

    private static func scanResourceFiles(
        root: STFolder,
        folder: STFolder,
        currentDepth: Int,
        maxDepth: Int,
        workflows: inout [ResourceFile],
        mcps: inout [ResourceFile]
    ) {
        guard currentDepth <= maxDepth else { return }

        if let files = try? folder.files([.skipsPackageDescendants]) {
            for file in files {
                let fileName = file.url.lastPathComponent.lowercased()
                let ext = file.url.pathExtension.lowercased()
                let path = relativePath(from: root.url, to: file.url)
                let lowerPath = path.lowercased()

                let isWorkflowFolderFile = lowerPath.contains("workflow")
                    && ["md", "markdown", "yml", "yaml"].contains(ext)
                let isGitHubWorkflowYAML = lowerPath.contains(".github/workflows/")
                    && ["yml", "yaml"].contains(ext)
                if fileName == "workflow.md" || isWorkflowFolderFile || isGitHubWorkflowYAML {
                    workflows.append(ResourceFile(path: path, kind: "workflow"))
                }

                if fileName == "mcp_settings.json" || fileName == "mcp.json" || fileName.contains("mcp") {
                    if file.url.pathExtension.lowercased() == "json" || fileName.hasSuffix(".json") {
                        mcps.append(ResourceFile(path: path, kind: "mcp"))
                    }
                }
            }
        }

        guard let children = try? folder.folders([.skipsPackageDescendants]) else { return }
        for child in children {
            let name = child.url.lastPathComponent
            if name.hasPrefix(".") && ![".github", ".agent", ".agents"].contains(name) {
                continue
            }
            guard ![".git", "node_modules", "build", "dist", ".build"].contains(name) else { continue }
            scanResourceFiles(
                root: root,
                folder: child,
                currentDepth: currentDepth + 1,
                maxDepth: maxDepth,
                workflows: &workflows,
                mcps: &mcps
            )
        }
    }

    private static func relativePath(from root: URL, to target: URL) -> String {
        let normalizedRoot = root.resolvingSymlinksInPath().standardizedFileURL.path
        let normalizedTarget = target.resolvingSymlinksInPath().standardizedFileURL.path
        let rootPath = normalizedRoot.hasSuffix("/") ? normalizedRoot : normalizedRoot + "/"
        let targetPath = normalizedTarget
        if targetPath.hasPrefix(rootPath) {
            return String(targetPath.dropFirst(rootPath.count))
        }
        return target.lastPathComponent
    }

    private static func dedupResourceFiles(_ files: [ResourceFile]) -> [ResourceFile] {
        var seen: Set<String> = []
        var deduped: [ResourceFile] = []
        for file in files.sorted(by: { $0.path < $1.path }) {
            if seen.insert(file.path).inserted {
                deduped.append(file)
            }
        }
        return deduped
    }

    private static func resolveCloneURL(
        gitURL: String,
        host: String,
        owner: String,
        repo: String,
        accessToken: String?,
        strategy: CredentialStrategy
    ) async throws -> (url: String, mode: CredentialMode) {
        let isHTTPS = gitURL.lowercased().hasPrefix("https://")
        guard isHTTPS else {
            if gitURL.lowercased().hasPrefix("git@") {
                return (gitURL, .ssh)
            }
            return (gitURL, .local)
        }

        let hasToken = accessToken?.isEmpty == false

        switch strategy {
        case .tokenOnly:
            guard let token = accessToken, !token.isEmpty else {
                throw SyncError.accessTokenRequired
            }
            return ("https://oauth2:\(token)@\(host)/\(owner)/\(repo).git", .httpsToken)

        case .sshOnly:
            let sshAvailable = await testSSHConnection(host: host)
            guard sshAvailable else {
                throw SyncError.sshNotAvailable(host: host)
            }
            return ("git@\(host):\(owner)/\(repo).git", .ssh)

        case .preferSSH:
            let sshAvailable = await testSSHConnection(host: host)
            if sshAvailable {
                return ("git@\(host):\(owner)/\(repo).git", .ssh)
            }
            if let token = accessToken, !token.isEmpty {
                return ("https://oauth2:\(token)@\(host)/\(owner)/\(repo).git", .httpsToken)
            }
            return (gitURL, .httpsAnonymous)

        case .automatic:
            if hasToken, let token = accessToken, !token.isEmpty {
                return ("https://oauth2:\(token)@\(host)/\(owner)/\(repo).git", .httpsToken)
            }
            return (gitURL, .httpsAnonymous)
        }
    }

    private static func runGit(arguments: [String]) throws {
        let result = runGitCapture(arguments: arguments)
        guard result.status == 0 else {
            let message = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "unknown"
                : result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if arguments.contains("clone") {
                throw SyncError.cloneFailed(message)
            }
            throw SyncError.pullFailed(message)
        }
    }

    private static func runGitCapture(arguments: [String]) -> (status: Int32, stdout: String, stderr: String) {
        var payload = SKProcessPayload.executableURL(STPath("/usr/bin/git").url)
        payload.arguments = arguments
        payload.throwOnNonZeroExit = false
        payload.timeoutMs = 120_000
        do {
            let result = try SKProcessRunner.runSync(payload)
            return (Int32(result.exitCode), result.stdout, result.stderr)
        } catch {
            return (1, "", error.localizedDescription)
        }
    }

    private static func pullArguments(repositoryPath: String, strategy: PullStrategy) -> [String] {
        switch strategy {
        case .ffOnly:
            return ["-C", repositoryPath, "pull", "--ff-only"]
        case .rebase:
            return ["-C", repositoryPath, "pull", "--rebase"]
        case .merge:
            return ["-C", repositoryPath, "pull", "--no-rebase"]
        }
    }

    private static func testSSHConnection(host: String) async -> Bool {
        var payload = SKProcessPayload.executableURL(STPath("/usr/bin/ssh").url)
        payload.arguments = [
            "-T",
            "-o", "BatchMode=yes",
            "-o", "ConnectTimeout=5",
            "-o", "StrictHostKeyChecking=no",
            "git@\(host)",
        ]
        payload.throwOnNonZeroExit = false
        payload.timeoutMs = 10_000
        do {
            let result = try SKProcessRunner.runSync(payload)
            let output = result.stderr.lowercased()
            return result.exitCode != 255 && !output.contains("permission denied")
        } catch {
            return false
        }
    }
}
