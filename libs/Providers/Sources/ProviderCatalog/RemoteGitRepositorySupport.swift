import Foundation
import SKProcessRunner
import STFilePath

public enum RemoteGitRepositorySupport {
    private enum GitLabTreeKind: String {
        case tree
        case blob
    }

    private struct ParsedGitLabPath {
        let owner: String
        let repo: String
        let subpath: String?
    }

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
                let pathComponents = path
                    .split(separator: "/")
                    .map(String.init)
                if isGitLabHost(host), let parsed = parseGitLabPath(pathComponents) {
                    return .init(
                        host: host,
                        owner: parsed.owner,
                        repo: parsed.repo
                    )
                }
                if pathComponents.count >= 2 {
                    return .init(
                        host: host,
                        owner: pathComponents[0],
                        repo: pathComponents[1]
                    )
                }
            }
        }

        if let urlObj = URL(string: cleaned), let host = urlObj.host {
            let pathComponents = urlObj.path
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                .split(separator: "/")
                .map(String.init)
            if isGitLabHost(host), let parsed = parseGitLabPath(pathComponents) {
                return .init(
                    host: host,
                    owner: parsed.owner,
                    repo: parsed.repo
                )
            }
            if pathComponents.count >= 2 {
                return .init(
                    host: host,
                    owner: pathComponents[0],
                    repo: pathComponents[1]
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
                .map(String.init)
            if isGitLabHost(host), let parsed = parseGitLabPath(pathComponents) {
                let scheme = url.scheme ?? "https"
                return "\(scheme)://\(host)/\(parsed.owner)/\(parsed.repo).git"
            }
            if pathComponents.count >= 2 {
                let owner = pathComponents[0]
                var repo = pathComponents[1]
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
                return normalizeSkillsPath(components.dropFirst(2).joined(separator: "/"))
            }
            return nil
        }

        if let url = URL(string: trimmed) {
            let host = url.host?.lowercased()
            let pathComponents = url.path
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                .split(separator: "/")
                .map(String.init)
            if let host, isGitLabHost(host), let parsed = parseGitLabPath(pathComponents) {
                return parsed.subpath.flatMap { normalizeSkillsPath($0) }
            }
            if pathComponents.count > 2 {
                return normalizeSkillsPath(pathComponents.dropFirst(2).joined(separator: "/"))
            }
        }

        return nil
    }

    public static func normalizeSkillsPath(_ raw: String) -> String? {
        var normalized = raw
            .replacingOccurrences(of: "\\", with: "/")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else { return nil }

        // Backward-compatible: absolute paths may already be persisted; keep as-is except SKILL.md suffix.
        let isAbsolutePath = normalized.hasPrefix("/")

        if !isAbsolutePath {
            if normalized.hasPrefix("./") {
                normalized = String(normalized.dropFirst(2))
            }
            normalized = normalized.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        } else {
            while normalized.count > 1, normalized.hasSuffix("/") {
                normalized.removeLast()
            }
        }

        guard !normalized.isEmpty else {
            return isAbsolutePath ? "/" : "."
        }

        if !isAbsolutePath {
            let components = normalized.split(separator: "/").map(String.init)
            if components.count >= 3,
               (components[0] == "tree" || components[0] == "blob")
            {
                normalized = components.dropFirst(2).joined(separator: "/")
            } else if components.count >= 4,
                      components[0] == "-",
                      (components[1] == "tree" || components[1] == "blob")
            {
                normalized = components.dropFirst(3).joined(separator: "/")
            }
        }

        let lowercased = normalized.lowercased()
        if lowercased == "skill.md" {
            return isAbsolutePath ? "/" : "."
        }
        if lowercased.hasSuffix("/skill.md") {
            normalized = String(normalized.dropLast("/skill.md".count))
        }

        if !isAbsolutePath {
            normalized = normalized.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return normalized.isEmpty ? "." : normalized
        }

        if normalized.isEmpty {
            return "/"
        }
        return normalized
    }

    private static func isGitLabHost(_ host: String) -> Bool {
        host.lowercased().contains("gitlab")
    }

    private static func parseGitLabPath(_ components: [String]) -> ParsedGitLabPath? {
        guard components.count >= 2 else { return nil }

        if let treeMarker = components.firstIndex(of: "-"), treeMarker >= 2 {
            let repoPath = Array(components[..<treeMarker])
            guard let parsedRepoPath = parseNamespaceRepo(repoPath) else { return nil }
            let subpath = parseGitLabTreeSubpath(components, markerIndex: treeMarker)
            return .init(owner: parsedRepoPath.owner, repo: parsedRepoPath.repo, subpath: subpath)
        }

        if let gitIndex = components.firstIndex(where: { $0.hasSuffix(".git") }), gitIndex >= 1 {
            let repoPath = Array(components[...gitIndex])
            guard let parsedRepoPath = parseNamespaceRepo(repoPath) else { return nil }
            let subpath: String?
            if components.count > gitIndex + 1 {
                subpath = components[(gitIndex + 1)...].joined(separator: "/")
            } else {
                subpath = nil
            }
            return .init(owner: parsedRepoPath.owner, repo: parsedRepoPath.repo, subpath: subpath)
        }

        guard let parsedRepoPath = parseNamespaceRepo(components) else { return nil }
        return .init(owner: parsedRepoPath.owner, repo: parsedRepoPath.repo, subpath: nil)
    }

    private static func parseNamespaceRepo(_ components: [String]) -> (owner: String, repo: String)? {
        guard components.count >= 2 else { return nil }
        let owner = components.dropLast().joined(separator: "/")
        var repo = components.last ?? ""
        if repo.hasSuffix(".git") {
            repo = String(repo.dropLast(4))
        }
        guard !owner.isEmpty, !repo.isEmpty else { return nil }
        return (owner, repo)
    }

    private static func parseGitLabTreeSubpath(_ components: [String], markerIndex: Int) -> String? {
        let treeIndex = markerIndex + 1
        guard components.indices.contains(treeIndex) else { return nil }
        guard GitLabTreeKind(rawValue: components[treeIndex]) != nil else {
            if components.count > treeIndex {
                return components[treeIndex...].joined(separator: "/")
            }
            return nil
        }

        let branchIndex = markerIndex + 2
        let subpathStart = markerIndex + 3
        guard components.indices.contains(branchIndex), components.count > subpathStart else { return nil }
        return components[subpathStart...].joined(separator: "/")
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
        do {
            try runGit(arguments: ["clone", "--depth=1", cloneEndpoint.url, localClonePath.path])
            return .init(
                mode: .cloned,
                defaultBranch: detectDefaultBranch(at: localClonePath),
                credentialMode: cloneEndpoint.mode
            )
        } catch let error as SyncError {
            guard shouldRetryCloneWithSSH(
                strategy: options.credentialStrategy,
                cloneMode: cloneEndpoint.mode
            ) else {
                throw error
            }

            let sshAvailable = await testSSHConnection(host: components.host)
            guard sshAvailable else {
                throw error
            }

            cleanupFailedCloneDirectory(localClonePath)

            let sshURL = "git@\(components.host):\(components.owner)/\(components.repo).git"
            do {
                try runGit(arguments: ["clone", "--depth=1", sshURL, localClonePath.path])
                return .init(
                    mode: .cloned,
                    defaultBranch: detectDefaultBranch(at: localClonePath),
                    credentialMode: .ssh
                )
            } catch let sshError as SyncError {
                if case let .cloneFailed(httpsMessage) = error,
                   case let .cloneFailed(sshMessage) = sshError
                {
                    throw SyncError.cloneFailed("\(httpsMessage)\nSSH fallback failed: \(sshMessage)")
                }
                throw sshError
            }
        }
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

    private static func shouldRetryCloneWithSSH(
        strategy: CredentialStrategy,
        cloneMode: CredentialMode
    ) -> Bool {
        strategy == .automatic && cloneMode == .httpsAnonymous
    }

    private static func cleanupFailedCloneDirectory(_ localClonePath: URL) {
        if STPath(localClonePath).isExists {
            try? STPath(localClonePath).delete()
        } else {
            try? FileManager.default.removeItem(at: localClonePath)
        }
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
