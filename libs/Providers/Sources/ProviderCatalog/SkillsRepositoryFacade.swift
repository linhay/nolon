import Foundation
import SKProcessRunner
import STFilePath

/// Unified SDK facade for remote skill repositories.
/// This keeps app-layer orchestration thin and reusable for future CLI entrypoints.
public enum SkillsRepositoryFacade {
    public enum GitHostingProvider: String, Sendable, Equatable {
        case github
        case gitlab
        case bitbucket
        case unknown
    }

    public enum GitSyncMode: Sendable, Equatable {
        case cloned
        case updated
    }

    public enum GitPullStrategy: String, Sendable, Equatable {
        case ffOnly = "ff-only"
        case rebase
        case merge
    }

    public enum GitCredentialStrategy: String, Sendable, Equatable {
        case automatic = "automatic"
        case preferSSH = "prefer-ssh"
        case tokenOnly = "token-only"
        case sshOnly = "ssh-only"
    }

    public enum GitCredentialMode: String, Sendable, Equatable {
        case local = "local"
        case ssh = "ssh"
        case httpsToken = "https_token"
        case httpsAnonymous = "https_anonymous"
    }

    public struct GitSyncOptions: Sendable, Equatable {
        public let pullStrategy: GitPullStrategy
        public let credentialStrategy: GitCredentialStrategy

        public init(
            pullStrategy: GitPullStrategy = .ffOnly,
            credentialStrategy: GitCredentialStrategy = .automatic
        ) {
            self.pullStrategy = pullStrategy
            self.credentialStrategy = credentialStrategy
        }
    }

    public struct ParsedGitURLComponents: Sendable, Equatable {
        public let host: String
        public let owner: String
        public let repo: String

        public init(host: String, owner: String, repo: String) {
            self.host = host
            self.owner = owner
            self.repo = repo
        }
    }

    public struct RepositoryIdentity: Sendable, Equatable {
        public let host: String
        public let owner: String
        public let repo: String
        public let repoFullName: String
        public let provider: GitHostingProvider

        public init(
            host: String,
            owner: String,
            repo: String,
            repoFullName: String,
            provider: GitHostingProvider
        ) {
            self.host = host
            self.owner = owner
            self.repo = repo
            self.repoFullName = repoFullName
            self.provider = provider
        }
    }

    public struct GitImportPlan: Sendable, Equatable {
        public let source: String
        public let normalizedGitURL: String
        public let subpath: String?
        public let providerHost: String
        public let owner: String
        public let repo: String
        public let localClonePath: URL
    }

    public enum PlanError: LocalizedError, Sendable {
        case invalidGitURL(String)

        public var errorDescription: String? {
            switch self {
            case let .invalidGitURL(source):
                return "Invalid Git repository source: \(source)"
            }
        }
    }

    public struct GitSyncResult: Sendable, Equatable {
        public let mode: GitSyncMode
        public let updatedAt: Date
        public let directories: [SkillsDirectoryCandidate]
        public let defaultBranch: String?
        public let credentialMode: GitCredentialMode
    }

    public struct GitSyncPreflight: Sendable, Equatable {
        public let isValidURL: Bool
        public let normalizedGitURL: String
        public let pullStrategy: GitPullStrategy
        public let credentialStrategy: GitCredentialStrategy
        public let credentialMode: GitCredentialMode
        public let requiresAccessToken: Bool
        public let warnings: [String]
        public let issues: [GitSyncPreflightIssue]
    }

    public enum GitSyncPreflightIssueCode: String, Sendable, Equatable {
        case invalidGitURL = "invalid_git_url"
        case accessTokenRequired = "access_token_required"
        case tokenStrategyRequiresHTTPS = "token_strategy_requires_https"
        case sshStrategyRequiresSSH = "ssh_strategy_requires_ssh"
    }

    public enum GitSyncPreflightIssueSeverity: String, Sendable, Equatable {
        case warning
        case error
    }

    public struct GitSyncPreflightIssue: Sendable, Equatable {
        public let code: GitSyncPreflightIssueCode
        public let severity: GitSyncPreflightIssueSeverity
        public let message: String

        public init(
            code: GitSyncPreflightIssueCode,
            severity: GitSyncPreflightIssueSeverity,
            message: String
        ) {
            self.code = code
            self.severity = severity
            self.message = message
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

    public enum RemoteCatalogKind: String, Sendable, Equatable {
        case skill
        case workflow
        case mcp
    }

    public struct RemoteCatalogItem: Sendable, Equatable {
        public let kind: RemoteCatalogKind
        public let slug: String
        public let displayName: String
        public let summary: String?
        public let latestVersion: String?
        public let updatedAt: Date?
        public let downloads: Int?
        public let stars: Int?
        public let installs: Int?

        public init(
            kind: RemoteCatalogKind,
            slug: String,
            displayName: String,
            summary: String?,
            latestVersion: String?,
            updatedAt: Date?,
            downloads: Int?,
            stars: Int?,
            installs: Int?
        ) {
            self.kind = kind
            self.slug = slug
            self.displayName = displayName
            self.summary = summary
            self.latestVersion = latestVersion
            self.updatedAt = updatedAt
            self.downloads = downloads
            self.stars = stars
            self.installs = installs
        }
    }

    public struct RemoteListResult: Sendable, Equatable {
        public let kind: RemoteCatalogKind
        public let baseURL: String
        public let query: String?
        public let limit: Int
        public let items: [RemoteCatalogItem]

        public init(
            kind: RemoteCatalogKind,
            baseURL: String,
            query: String?,
            limit: Int,
            items: [RemoteCatalogItem]
        ) {
            self.kind = kind
            self.baseURL = baseURL
            self.query = query
            self.limit = limit
            self.items = items
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

    public static func planGitImport(source: String, repositoriesRoot: URL) throws -> GitImportPlan {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = RemoteGitRepositorySupport.normalizeGitURL(trimmed)
        guard let components = RemoteGitRepositorySupport.extractURLComponents(from: normalized),
              let clonePath = RemoteGitRepositorySupport.suggestedClonePath(
                gitURL: normalized,
                repositoriesRoot: repositoriesRoot
              )
        else {
            throw PlanError.invalidGitURL(source)
        }

        return GitImportPlan(
            source: source,
            normalizedGitURL: normalized,
            subpath: RemoteGitRepositorySupport.extractSubpath(from: trimmed),
            providerHost: components.host,
            owner: components.owner,
            repo: components.repo,
            localClonePath: clonePath
        )
    }

    public static func syncGitRepository(
        plan: GitImportPlan,
        accessToken: String? = nil,
        options: GitSyncOptions = .init()
    ) async throws -> GitSyncResult {
        try await syncGitRepository(
            gitURL: plan.normalizedGitURL,
            localClonePath: plan.localClonePath,
            accessToken: accessToken,
            options: options
        )
    }

    public static func syncGitRepository(
        gitURL: String,
        localClonePath: URL,
        accessToken: String? = nil,
        options: GitSyncOptions = .init()
    ) async throws -> GitSyncResult {
        do {
            let outcome = try await RemoteGitRepositorySupport.syncRepository(
                gitURL: gitURL,
                localClonePath: localClonePath,
                accessToken: accessToken,
                options: .init(
                    pullStrategy: mapPullStrategy(options.pullStrategy),
                    credentialStrategy: mapCredentialStrategy(options.credentialStrategy)
                )
            )
            let mode: GitSyncMode = {
                switch outcome.mode {
                case .cloned:
                    return .cloned
                case .pulled:
                    return .updated
                }
            }()
            let directories = RemoteGitRepositorySupport.detectSkillsDirectories(at: localClonePath).map {
                SkillsDirectoryCandidate(path: $0.path, skillCount: $0.skillCount, skillNames: $0.skillNames)
            }
            return GitSyncResult(
                mode: mode,
                updatedAt: outcome.updatedAt,
                directories: directories,
                defaultBranch: outcome.defaultBranch,
                credentialMode: mapCredentialMode(outcome.credentialMode)
            )
        } catch let error as RemoteGitRepositorySupport.SyncError {
            throw mapSyncError(error)
        }
    }

    public static func discoverSkillsDirectories(
        at repositoryPath: URL,
        maxDepth: Int = 5
    ) -> [SkillsDirectoryCandidate] {
        RemoteGitRepositorySupport.detectSkillsDirectories(at: repositoryPath, maxDepth: maxDepth).map {
            SkillsDirectoryCandidate(path: $0.path, skillCount: $0.skillCount, skillNames: $0.skillNames)
        }
    }

    public static func discoverRepositoryResources(
        at repositoryPath: URL,
        maxDepth: Int = 5
    ) -> RepositoryResources {
        let resources = RemoteGitRepositorySupport.detectRepositoryResources(
            at: repositoryPath,
            maxDepth: maxDepth
        )
        return RepositoryResources(
            skillsDirectories: resources.skillsDirectories.map {
                SkillsDirectoryCandidate(path: $0.path, skillCount: $0.skillCount, skillNames: $0.skillNames)
            },
            workflows: resources.workflows.map { ResourceFile(path: $0.path, kind: $0.kind) },
            mcps: resources.mcps.map { ResourceFile(path: $0.path, kind: $0.kind) }
        )
    }

    public static func parseSkillMetadata(
        content: String,
        directoryName: String?
    ) -> SkillSpecificationParser.StandardMetadata? {
        SkillSpecificationParser.parseStandardMetadata(from: content, directoryName: directoryName)
    }

    public typealias RemoteDataLoader = @Sendable (URL) async throws -> (Data, HTTPURLResponse)
    public typealias RemoteDownloadLoader = @Sendable (URL) async throws -> (URL, HTTPURLResponse)

    public static func listRemoteResources(
        kind: RemoteCatalogKind,
        query: String?,
        limit: Int,
        baseURL: String,
        loader: RemoteDataLoader? = nil
    ) async throws -> RemoteListResult {
        let base = URL(string: baseURL) ?? URL(string: "https://clawdhub.com")!
        let trimmed = query?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasQuery = trimmed?.isEmpty == false
        let url: URL
        switch (kind, hasQuery) {
        case (.skill, true):
            url = try buildRemoteURL(base: base, path: "/api/v1/search", queryItems: [
                .init(name: "q", value: trimmed), .init(name: "limit", value: String(limit)),
            ])
        case (.skill, false):
            url = try buildRemoteURL(base: base, path: "/api/v1/skills", queryItems: [
                .init(name: "limit", value: String(limit)),
            ])
        case (.workflow, true):
            url = try buildRemoteURL(base: base, path: "/api/v1/search/workflows", queryItems: [
                .init(name: "q", value: trimmed), .init(name: "limit", value: String(limit)),
            ])
        case (.workflow, false):
            url = try buildRemoteURL(base: base, path: "/api/v1/workflows", queryItems: [
                .init(name: "limit", value: String(limit)),
            ])
        case (.mcp, true):
            url = try buildRemoteURL(base: base, path: "/api/v1/search/mcps", queryItems: [
                .init(name: "q", value: trimmed), .init(name: "limit", value: String(limit)),
            ])
        case (.mcp, false):
            url = try buildRemoteURL(base: base, path: "/api/v1/mcps", queryItems: [
                .init(name: "limit", value: String(limit)),
            ])
        }

        let load = loader ?? defaultRemoteDataLoader
        let (data, response) = try await load(url)
        guard (200..<300).contains(response.statusCode) else {
            throw SyncError.commandFailed("Remote list failed with status \(response.statusCode)")
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let items: [RemoteCatalogItem]
        switch (kind, hasQuery) {
        case (.skill, false):
            let payload = try decoder.decode(ClawdhubSkillListResponse.self, from: data)
            items = payload.items.map {
                RemoteCatalogItem(
                    kind: .skill,
                    slug: $0.slug,
                    displayName: $0.displayName,
                    summary: $0.summary,
                    latestVersion: $0.latestVersion?.version,
                    updatedAt: Date(timeIntervalSince1970: $0.updatedAt / 1000),
                    downloads: $0.stats?.downloads,
                    stars: $0.stats?.stars,
                    installs: nil
                )
            }
        case (.workflow, false):
            let payload = try decoder.decode(ClawdhubWorkflowListResponse.self, from: data)
            items = payload.items.map {
                RemoteCatalogItem(
                    kind: .workflow,
                    slug: $0.slug,
                    displayName: $0.displayName,
                    summary: $0.summary,
                    latestVersion: $0.latestVersion?.version,
                    updatedAt: Date(timeIntervalSince1970: $0.updatedAt / 1000),
                    downloads: $0.stats?.downloads,
                    stars: $0.stats?.stars,
                    installs: nil
                )
            }
        case (.mcp, false):
            let payload = try decoder.decode(ClawdhubMCPListResponse.self, from: data)
            items = payload.items.map {
                RemoteCatalogItem(
                    kind: .mcp,
                    slug: $0.slug,
                    displayName: $0.displayName,
                    summary: $0.summary,
                    latestVersion: $0.latestVersion?.version,
                    updatedAt: Date(timeIntervalSince1970: $0.updatedAt / 1000),
                    downloads: $0.stats?.downloads,
                    stars: $0.stats?.stars,
                    installs: $0.stats?.installs
                )
            }
        case (.skill, true), (.workflow, true), (.mcp, true):
            let payload = try decoder.decode(ClawdhubSearchResponse.self, from: data)
            items = payload.results.compactMap {
                guard let slug = $0.slug, let displayName = $0.displayName else { return nil }
                return RemoteCatalogItem(
                    kind: kind,
                    slug: slug,
                    displayName: displayName,
                    summary: $0.summary,
                    latestVersion: $0.version,
                    updatedAt: $0.updatedAt.map { Date(timeIntervalSince1970: $0 / 1000) },
                    downloads: nil,
                    stars: nil,
                    installs: nil
                )
            }
        }

        return RemoteListResult(kind: kind, baseURL: base.absoluteString, query: trimmed, limit: limit, items: items)
    }

    public static func downloadRemoteResource(
        kind: RemoteCatalogKind,
        slug: String,
        version: String?,
        baseURL: String,
        downloader: RemoteDownloadLoader? = nil,
        temporaryDirectory: URL? = nil
    ) async throws -> URL {
        let base = URL(string: baseURL) ?? URL(string: "https://clawdhub.com")!
        let path: String = {
            switch kind {
            case .skill:
                return "/api/v1/download"
            case .workflow:
                return "/api/v1/download/workflow"
            case .mcp:
                return "/api/v1/download/mcp"
            }
        }()

        var queryItems = [URLQueryItem(name: "slug", value: slug)]
        if let version, !version.isEmpty {
            queryItems.append(URLQueryItem(name: "version", value: version))
        } else {
            queryItems.append(URLQueryItem(name: "tag", value: "latest"))
        }

        let url = try buildRemoteURL(base: base, path: path, queryItems: queryItems)
        let download = downloader ?? defaultRemoteDownloadLoader
        let (downloadedURL, response) = try await download(url)
        guard (200..<300).contains(response.statusCode) else {
            throw SyncError.commandFailed("Remote download failed with status \(response.statusCode)")
        }

        let rootFolder: STFolder = {
            if let temporaryDirectory {
                return STFolder(temporaryDirectory)
            }
            return (try? STFolder(sanbox: .temporary)) ?? STFolder("/tmp")
        }()

        let fileExtension: String = {
            switch kind {
            case .skill:
                return "zip"
            case .workflow:
                return "md"
            case .mcp:
                return downloadedURL.pathExtension.isEmpty ? "json" : downloadedURL.pathExtension
            }
        }()

        let destination = rootFolder.file("\(slug)-\(version ?? "latest")-\(UUID().uuidString).\(fileExtension)")
        try STFile(downloadedURL).move(to: destination)
        return destination.url
    }

    /// Stage downloaded remote skill payload into a stable skills root folder.
    /// - Parameters:
    ///   - downloadedFileURL: downloaded payload path (folder or zip).
    ///   - slug: target skill slug.
    ///   - skillsRoot: stable skills root folder (for example: `~/.nolon/skills`).
    /// - Returns: staged skill directory URL (`<skillsRoot>/<slug>`).
    public static func stageRemoteSkillForInstall(
        downloadedFileURL: URL,
        slug: String,
        skillsRoot: URL
    ) throws -> URL {
        let root = STFolder(skillsRoot)
        _ = root.createIfNotExists()

        let stagedPath = root.subpath(slug)
        if stagedPath.isExists || stagedPath.isSymbolicLink {
            try stagedPath.delete()
        }

        let downloadedPath = STPath(downloadedFileURL)
        let sourceSkillRoot: STPath
        if downloadedPath.isFolderExists {
            sourceSkillRoot = try resolveDownloadedSkillRoot(downloadedFolderPath: downloadedPath)
        } else if downloadedFileURL.pathExtension.lowercased() == "zip" {
            let extractionRoot = try STFolder(sanbox: .temporary).folder("nolon-skill-unpack-\(UUID().uuidString)").create()
            defer { try? extractionRoot.delete() }

            var payload = SKProcessPayload.executableURL(STPath("/usr/bin/ditto").url)
            payload.arguments = ["-x", "-k", downloadedFileURL.path, extractionRoot.url.path]
            payload.throwOnNonZeroExit = false
            payload.timeoutMs = 120_000
            let result = try SKProcessRunner.runSync(payload)
            guard result.exitCode == 0 else {
                throw SyncError.commandFailed("Failed to unpack downloaded skill zip: \(downloadedFileURL.path)")
            }
            guard let skillRoot = findSkillRoot(in: extractionRoot.url) else {
                throw SyncError.commandFailed("Unpacked skill zip does not contain SKILL.md")
            }
            try skillRoot.copy(to: stagedPath, isOverlay: true)
            return stagedPath.url
        } else {
            throw SyncError.commandFailed("Unsupported skill package format: \(downloadedFileURL.lastPathComponent)")
        }

        try sourceSkillRoot.copy(to: stagedPath, isOverlay: true)
        return stagedPath.url
    }

    public static func normalizeGitURL(_ input: String) -> String {
        RemoteGitRepositorySupport.normalizeGitURL(input)
    }

    public static func extractSubpath(from input: String) -> String? {
        RemoteGitRepositorySupport.extractSubpath(from: input)
    }

    public static func extractURLComponents(from input: String) -> ParsedGitURLComponents? {
        guard let components = RemoteGitRepositorySupport.extractURLComponents(from: input) else {
            return nil
        }
        return ParsedGitURLComponents(
            host: components.host,
            owner: components.owner,
            repo: components.repo
        )
    }

    public static func parseRepositoryIdentity(from input: String) -> RepositoryIdentity? {
        let normalized = normalizeGitURL(input)
        guard let components = extractURLComponents(from: normalized) else {
            return nil
        }
        return RepositoryIdentity(
            host: components.host,
            owner: components.owner,
            repo: components.repo,
            repoFullName: "\(components.owner)@\(components.repo)",
            provider: detectGitProvider(from: normalized)
        )
    }

    public static func detectGitProvider(from input: String) -> GitHostingProvider {
        let normalized = normalizeGitURL(input).lowercased()
        if normalized.contains("github.com") || normalized.contains("git@github") {
            return .github
        }
        if normalized.contains("gitlab.") || normalized.contains("git@gitlab") {
            return .gitlab
        }
        if normalized.contains("bitbucket.org") || normalized.contains("git@bitbucket") {
            return .bitbucket
        }
        return .unknown
    }

    public static func suggestedClonePath(gitURL: String, repositoriesRoot: URL) -> URL? {
        RemoteGitRepositorySupport.suggestedClonePath(
            gitURL: gitURL,
            repositoriesRoot: repositoriesRoot
        )
    }

    public static func preflightSync(
        source: String,
        accessToken: String?,
        options: GitSyncOptions = .init()
    ) -> GitSyncPreflight {
        let normalized = normalizeGitURL(source)
        let isValid = extractURLComponents(from: normalized) != nil
        let hasToken = accessToken?.isEmpty == false
        let isSSH = normalized.lowercased().hasPrefix("git@")
        let isHTTPS = normalized.lowercased().hasPrefix("https://")

        let mode: GitCredentialMode
        let requiresAccessToken: Bool
        var issues: [GitSyncPreflightIssue] = []

        if !isValid {
            issues.append(
                GitSyncPreflightIssue(
                    code: .invalidGitURL,
                    severity: .error,
                    message: "invalid git url"
                )
            )
        }

        switch options.credentialStrategy {
        case .tokenOnly:
            requiresAccessToken = !hasToken
            mode = hasToken ? .httpsToken : .httpsAnonymous
            if !isHTTPS {
                issues.append(
                    GitSyncPreflightIssue(
                        code: .tokenStrategyRequiresHTTPS,
                        severity: .warning,
                        message: "token-only strategy is intended for https urls"
                    )
                )
            }
            if !hasToken {
                issues.append(
                    GitSyncPreflightIssue(
                        code: .accessTokenRequired,
                        severity: .error,
                        message: "access token is required for token-only strategy"
                    )
                )
            }
        case .sshOnly:
            requiresAccessToken = false
            mode = .ssh
            if !isSSH {
                issues.append(
                    GitSyncPreflightIssue(
                        code: .sshStrategyRequiresSSH,
                        severity: .warning,
                        message: "ssh-only strategy requires ssh-style source or available ssh fallback"
                    )
                )
            }
        case .preferSSH:
            requiresAccessToken = false
            mode = isSSH ? .ssh : (hasToken ? .httpsToken : .httpsAnonymous)
        case .automatic:
            requiresAccessToken = false
            if isSSH {
                mode = .ssh
            } else if hasToken {
                mode = .httpsToken
            } else {
                mode = .httpsAnonymous
            }
        }

        return GitSyncPreflight(
            isValidURL: isValid,
            normalizedGitURL: normalized,
            pullStrategy: options.pullStrategy,
            credentialStrategy: options.credentialStrategy,
            credentialMode: mode,
            requiresAccessToken: requiresAccessToken,
            warnings: issues.map(\.message),
            issues: issues
        )
    }

    private static func mapSyncError(_ error: RemoteGitRepositorySupport.SyncError) -> SyncError {
        switch error {
        case .invalidURL:
            return .invalidURL
        case .accessTokenRequired:
            return .accessTokenRequired
        case let .sshNotAvailable(host):
            return .sshNotAvailable(host: host)
        case let .cloneFailed(message):
            return .cloneFailed(message)
        case let .pullFailed(message):
            return .pullFailed(message)
        case let .commandFailed(message):
            return .commandFailed(message)
        }
    }

    private static func mapPullStrategy(_ strategy: GitPullStrategy) -> RemoteGitRepositorySupport.PullStrategy {
        switch strategy {
        case .ffOnly:
            return .ffOnly
        case .rebase:
            return .rebase
        case .merge:
            return .merge
        }
    }

    private static func mapCredentialStrategy(
        _ strategy: GitCredentialStrategy
    ) -> RemoteGitRepositorySupport.CredentialStrategy {
        switch strategy {
        case .automatic:
            return .automatic
        case .preferSSH:
            return .preferSSH
        case .tokenOnly:
            return .tokenOnly
        case .sshOnly:
            return .sshOnly
        }
    }

    private static func mapCredentialMode(_ mode: RemoteGitRepositorySupport.CredentialMode) -> GitCredentialMode {
        switch mode {
        case .local:
            return .local
        case .ssh:
            return .ssh
        case .httpsToken:
            return .httpsToken
        case .httpsAnonymous:
            return .httpsAnonymous
        }
    }

    private static func buildRemoteURL(base: URL, path: String, queryItems: [URLQueryItem]) throws -> URL {
        var components = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        components?.queryItems = queryItems
        guard let url = components?.url else {
            throw SyncError.invalidURL
        }
        return url
    }

    private static func defaultRemoteDataLoader(url: URL) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw SyncError.commandFailed("Invalid HTTP response")
        }
        return (data, http)
    }

    private static func defaultRemoteDownloadLoader(url: URL) async throws -> (URL, HTTPURLResponse) {
        let (downloadedURL, response) = try await URLSession.shared.download(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw SyncError.commandFailed("Invalid HTTP response")
        }
        return (downloadedURL, http)
    }
}

private func resolveDownloadedSkillRoot(downloadedFolderPath: STPath) throws -> STPath {
    let folder = STFolder(downloadedFolderPath.url)
    if folder.file("SKILL.md").isExists {
        return downloadedFolderPath
    }
    if let nested = findSkillRoot(in: downloadedFolderPath.url) {
        return nested
    }
    throw SkillsRepositoryFacade.SyncError.commandFailed("Downloaded skill payload does not contain SKILL.md")
}

private func findSkillRoot(in directory: URL) -> STPath? {
    let manager = FileManager.default
    guard let enumerator = manager.enumerator(
        at: directory,
        includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else {
        return nil
    }

    for case let url as URL in enumerator where url.lastPathComponent == "SKILL.md" {
        return STPath(url.deletingLastPathComponent())
    }
    return nil
}

private struct ClawdhubSearchResponse: Decodable { let results: [ClawdhubSearchResult] }
private struct ClawdhubSearchResult: Decodable {
    let slug: String?
    let displayName: String?
    let summary: String?
    let version: String?
    let updatedAt: TimeInterval?
}

private struct ClawdhubSkillListResponse: Decodable { let items: [ClawdhubSkillListItem] }
private struct ClawdhubWorkflowListResponse: Decodable { let items: [ClawdhubWorkflowListItem] }
private struct ClawdhubMCPListResponse: Decodable { let items: [ClawdhubMCPListItem] }

private struct ClawdhubLatestVersion: Decodable { let version: String }
private struct ClawdhubStats: Decodable { let downloads: Int?; let stars: Int? }
private struct ClawdhubMCPStats: Decodable { let downloads: Int?; let stars: Int?; let installs: Int? }

private struct ClawdhubSkillListItem: Decodable {
    let slug: String
    let displayName: String
    let summary: String?
    let updatedAt: TimeInterval
    let latestVersion: ClawdhubLatestVersion?
    let stats: ClawdhubStats?
}

private struct ClawdhubWorkflowListItem: Decodable {
    let slug: String
    let displayName: String
    let summary: String?
    let updatedAt: TimeInterval
    let latestVersion: ClawdhubLatestVersion?
    let stats: ClawdhubStats?
}

private struct ClawdhubMCPListItem: Decodable {
    let slug: String
    let displayName: String
    let summary: String?
    let updatedAt: TimeInterval
    let latestVersion: ClawdhubLatestVersion?
    let stats: ClawdhubMCPStats?
}
