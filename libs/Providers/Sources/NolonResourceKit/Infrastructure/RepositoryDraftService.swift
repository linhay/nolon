import Foundation

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

public struct RepositoryDraftService: Sendable {
    public init() {}

    public func defaultTemplate(hasClawdhubRepository: Bool) -> RepositoryTemplate {
        hasClawdhubRepository ? .git : .clawdhub
    }

    public func importedDraft(from rawURL: String) -> ImportedRepositoryDraft {
        let normalized = RemoteRepository.normalizeGitURL(rawURL)
        let name = RemoteRepository.extractRepoName(from: normalized)
        let subpath = RemoteRepository.extractSubpath(from: rawURL)

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
