import Foundation
import ProviderCatalog

public struct RepositoryDraftInput: Sendable, Equatable {
    public let selectedTemplate: RepositoryTemplate
    public let repositoryName: String
    public let gitURL: String
    public let localPath: String
    public let repositories: [RemoteRepository]
    public let editingRepositoryID: String?

    public init(
        selectedTemplate: RepositoryTemplate,
        repositoryName: String,
        gitURL: String,
        localPath: String,
        repositories: [RemoteRepository],
        editingRepositoryID: String?
    ) {
        self.selectedTemplate = selectedTemplate
        self.repositoryName = repositoryName
        self.gitURL = gitURL
        self.localPath = localPath
        self.repositories = repositories
        self.editingRepositoryID = editingRepositoryID
    }
}

public struct ImportedRepositoryDraft: Sendable, Equatable {
    public let template: RepositoryTemplate
    public let name: String
    public let normalizedGitURL: String
    public let skillsPaths: [String]

    public init(template: RepositoryTemplate, name: String, normalizedGitURL: String, skillsPaths: [String]) {
        self.template = template
        self.name = name
        self.normalizedGitURL = normalizedGitURL
        self.skillsPaths = skillsPaths
    }
}

public struct ImportedResourceIntent: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        case clawhubSkill
        case gitRepository
        case unknown
    }

    public let kind: Kind
    public let host: String?
    public let owner: String?
    public let slug: String?
    public let normalizedGitURL: String?
    public let reason: String?

    public init(
        kind: Kind,
        host: String? = nil,
        owner: String? = nil,
        slug: String? = nil,
        normalizedGitURL: String? = nil,
        reason: String? = nil
    ) {
        self.kind = kind
        self.host = host
        self.owner = owner
        self.slug = slug
        self.normalizedGitURL = normalizedGitURL
        self.reason = reason
    }
}

public struct RepositoryDraftService: Sendable {
    private static let clawhubHosts: Set<String> = [
        "clawhub.ai",
        "www.clawhub.ai",
    ]

    public init() {}

    public func defaultTemplate(hasClawdhubRepository: Bool) -> RepositoryTemplate {
        hasClawdhubRepository ? .git : .clawdhub
    }

    public func importedDraft(from rawURL: String) -> ImportedRepositoryDraft {
        let normalized = RemoteRepository.normalizeGitURL(rawURL)
        let name = RemoteRepository.extractRepoName(from: normalized)
        let subpath = RemoteRepository.extractSubpath(from: rawURL)
            .flatMap { SkillsRepositoryFacade.normalizeSkillsPath($0) }

        return ImportedRepositoryDraft(
            template: .git,
            name: name,
            normalizedGitURL: normalized,
            skillsPaths: subpath.map { [$0] } ?? []
        )
    }

    public func inferredRepositoryName(from gitURL: String) -> String {
        RemoteRepository.extractRepoName(from: gitURL)
    }

    public func parseImportIntent(from rawURL: String) -> ImportedResourceIntent {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ImportedResourceIntent(kind: .unknown, reason: "Empty import URL")
        }

        guard let candidateURL = parseURLAllowingSchemeLessHost(trimmed),
              let host = candidateURL.host?.lowercased()
        else {
            let normalizedGitURL = RemoteRepository.normalizeGitURL(trimmed)
            if RemoteRepository.extractURLComponents(from: normalizedGitURL) != nil {
                return ImportedResourceIntent(kind: .gitRepository, normalizedGitURL: normalizedGitURL)
            }
            return ImportedResourceIntent(kind: .unknown, reason: "Invalid import URL")
        }

        let segments = candidateURL.path
            .split(separator: "/")
            .map(String.init)
            .filter { !$0.isEmpty }

        if Self.clawhubHosts.contains(host) {
            guard segments.count >= 2 else {
                return ImportedResourceIntent(
                    kind: .unknown,
                    host: host,
                    reason: "Unsupported Clawhub URL path"
                )
            }
            let owner = segments[0]
            let slug = segments[1]
                .replacingOccurrences(of: ".git", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !owner.isEmpty, !slug.isEmpty else {
                return ImportedResourceIntent(
                    kind: .unknown,
                    host: host,
                    reason: "Invalid Clawhub skill URL"
                )
            }
            return ImportedResourceIntent(
                kind: .clawhubSkill,
                host: host,
                owner: owner,
                slug: slug
            )
        }

        let normalizedGitURL = RemoteRepository.normalizeGitURL(trimmed)
        if RemoteRepository.extractURLComponents(from: normalizedGitURL) != nil {
            return ImportedResourceIntent(kind: .gitRepository, host: host, normalizedGitURL: normalizedGitURL)
        }

        return ImportedResourceIntent(kind: .unknown, host: host, reason: "Unsupported import URL")
    }

    /// Extract search query from a Clawhub skill URL.
    /// Supports:
    /// - https://clawhub.ai/{owner}/{slug}
    public func clawhubSkillQuery(from rawURL: String) -> String? {
        let intent = parseImportIntent(from: rawURL)
        guard intent.kind == .clawhubSkill else { return nil }
        return intent.slug
    }

    private func parseURLAllowingSchemeLessHost(_ raw: String) -> URL? {
        if let url = URL(string: raw), url.host != nil {
            return url
        }
        guard raw.contains("://") == false else { return nil }
        let prefixed = "https://\(raw)"
        guard let url = URL(string: prefixed), url.host != nil else { return nil }
        return url
    }

    public func validate(_ input: RepositoryDraftInput) -> String? {
        let editingID = input.editingRepositoryID
        let newRepoName = input.repositoryName
        let newGitURL = input.gitURL
        let newLocalPath = input.localPath

        if !newRepoName.isEmpty,
           input.repositories.contains(where: { $0.name == newRepoName && $0.id != editingID }) {
            return "A repository with this name already exists."
        }

        if input.selectedTemplate == .git, !newGitURL.isEmpty {
            let detectedProvider = RemoteRepository.detectProvider(from: newGitURL) ?? .github
            let normalizedURL = detectedProvider.normalizeURL(newGitURL)
            if input.repositories.contains(where: { repo in
                guard repo.id != editingID, repo.templateType == .git, let existingURL = repo.gitURL else {
                    return false
                }
                let existingProvider = RemoteRepository.detectProvider(from: existingURL) ?? .github
                return existingProvider.normalizeURL(existingURL) == normalizedURL
            }) {
                return "This Git repository has already been added."
            }
        }

        if input.selectedTemplate == .localFolder,
           !newLocalPath.isEmpty,
           input.repositories.contains(where: {
               $0.id != editingID && $0.templateType == .localFolder && $0.localPath == newLocalPath
           }) {
            return "This folder has already been added."
        }

        return nil
    }
}
