import SwiftUI
import Observation
import OSLog
import UniformTypeIdentifiers
import NolonResourceKit

@Observable
final class AddRepositoryViewModel {
    private static let logger = Logger(subsystem: "nolon", category: "AddRepository")
    static let selectableTemplates: [RepositoryTemplate] = RepositoryTemplate.allCases.filter {
        $0 != .globalSkills && $0 != .clawdhub
    }

    /// The repository being edited, if any
    var repositoryToEdit: RemoteRepository?
    
    /// Whether we are in edit mode
    var isEditing: Bool { repositoryToEdit != nil }
    
    var selectedTemplate: RepositoryTemplate = .git {
        didSet {
            // Only handle change if not in edit mode (template is locked during edit)
            if !isEditing {
                handleTemplateChange(selectedTemplate)
            }
        }
    }
    var newRepoName = "" {
        didSet { validateInput() }
    }
    var newGitURL = "" {
        didSet { handleGitURLChange(newGitURL) }
    }
    var newLocalPath = "" {
        didSet { validateInput() }
    }
    var preferredSkillsPaths: [String] = []
    
    var validationError: String?
    var isAddingRepository = false
    
    @ObservationIgnored var settings: ProviderSettings
    
    @ObservationIgnored var onDirectoryCandidatesFound: ((RemoteRepository, [GitRepository.SkillsDirectoryCandidate]) -> Void)?
    @ObservationIgnored var onRepositorySaved: ((RemoteRepository) -> Void)?
    @ObservationIgnored var onDismiss: (() -> Void)?
    @ObservationIgnored private let syncOrchestrator = RepositorySyncOrchestrator()
    @ObservationIgnored private let draftService = RepositoryDraftService()

    struct PendingImportPrefill: Equatable {
        let template: RepositoryTemplate
        let name: String
        let normalizedGitURL: String
        let skillsPaths: [String]
    }
    
    init(settings: ProviderSettings, repositoryToEdit: RemoteRepository? = nil) {
        self.settings = settings
        self.repositoryToEdit = repositoryToEdit
        
        if let repo = repositoryToEdit {
            // Edit mode: populate fields from existing repository
            selectedTemplate = repo.templateType
            newRepoName = repo.name
            newGitURL = repo.gitURL ?? ""
            newLocalPath = repo.localPath ?? ""
            preferredSkillsPaths = repo.skillsPaths
        } else {
            resetAddForm()
        }
    }

    
    // Templates available for user to add (exclude built-in repositories)
    var availableTemplates: [RepositoryTemplate] {
        Self.selectableTemplates
    }
    
    var canAddRepository: Bool {
        if validationError != nil { return false }

        switch selectedTemplate {
        case .clawdhub:
            return !settings.remoteRepositories.contains { $0.templateType == .clawdhub }
        case .localFolder:
            return !newLocalPath.isEmpty
        case .git:
            return !newGitURL.isEmpty
        case .globalSkills:
            return false
        }
    }
    
    func handleTemplateChange(_ newTemplate: RepositoryTemplate) {
        newRepoName = newTemplate.defaultName
        newLocalPath = ""
        newGitURL = ""
        preferredSkillsPaths = []
        validationError = nil
    }

    func handleGitURLChange(_ newURL: String) {
        if selectedTemplate == .git && !newURL.isEmpty {
            let extractedName = draftService.inferredRepositoryName(from: newURL)
            if !extractedName.isEmpty {
                newRepoName = extractedName
            }
        }
        validateInput()
    }

    func validateInput() {
        validationError = draftService.validate(
            RepositoryDraftInput(
                selectedTemplate: selectedTemplate,
                repositoryName: newRepoName,
                gitURL: newGitURL,
                localPath: newLocalPath,
                repositories: settings.remoteRepositories,
                editingRepositoryID: repositoryToEdit?.id
            )
        )
    }
    
    /// Check and load pending import URL (called on appear to handle @State caching)
    func checkPendingImportURL() {
        guard !isEditing else { return }
        guard let importURL = settings.pendingImportURL else { return }
        
        Self.logger.info("checkPendingImportURL: \(importURL, privacy: .public)")
        guard applyPendingImportURL(importURL) else { return }
        validateInput()
        consumePendingImportURL(afterViewUpdate: true)
    }

    private func consumePendingImportURL(afterViewUpdate: Bool) {
        if afterViewUpdate, !UITestSupport.isRunningUnitTests {
            Task { @MainActor [weak settings] in
                settings?.pendingImportURL = nil
            }
            return
        }

        settings.pendingImportURL = nil
    }

    @discardableResult
    private func applyPendingImportURL(_ importURL: String) -> Bool {
        guard let prefill = Self.pendingImportPrefill(for: importURL, draftService: draftService) else {
            Self.logger.info("Skip AddRepositorySheet pending import handling for non-git URL: \(importURL, privacy: .public)")
            return false
        }

        selectedTemplate = prefill.template
        preferredSkillsPaths = prefill.skillsPaths
        newGitURL = prefill.normalizedGitURL
        if !prefill.name.isEmpty {
            newRepoName = prefill.name
        }
        Self.logger.info("Loaded git URL: \(self.newGitURL, privacy: .public), name: \(self.newRepoName, privacy: .public)")
        return true
    }
    
    func resetAddForm() {
        let suggestedTemplate = draftService.defaultTemplate(
            hasClawdhubRepository: settings.remoteRepositories.contains(where: { $0.templateType == .clawdhub })
        )
        selectedTemplate = suggestedTemplate == .clawdhub ? .git : suggestedTemplate
        // Force update fields based on new template
        handleTemplateChange(selectedTemplate)
    }
    
    @MainActor
    func selectLocalFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = NSLocalizedString(
            "select_skills_folder", comment: "Select a folder containing skills")
        panel.prompt = NSLocalizedString("select", comment: "Select")

        if panel.runModal() == .OK, let url = panel.url {
            newLocalPath = url.path
            if newRepoName.isEmpty {
                newRepoName = url.lastPathComponent
            }
        }
    }

    @MainActor
    func applyDroppedFolderURLs(_ urls: [URL]) -> Bool {
        guard let folder = Self.firstDirectoryURL(in: urls) else { return false }
        newLocalPath = folder.path
        if newRepoName.isEmpty {
            newRepoName = folder.lastPathComponent
        }
        return true
    }

    static func firstDirectoryURL(in urls: [URL], fileManager: FileManager = .default) -> URL? {
        for url in urls {
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
                return url
            }
        }
        return nil
    }

    static func normalizedGitURLInput(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func pendingImportPrefill(
        for importURL: String,
        draftService: RepositoryDraftService = RepositoryDraftService()
    ) -> PendingImportPrefill? {
        let intent = draftService.parseImportIntent(from: importURL)
        guard intent.kind == .gitRepository else { return nil }

        let draft = draftService.importedDraft(from: importURL)
        return PendingImportPrefill(
            template: draft.template,
            name: draft.name,
            normalizedGitURL: intent.normalizedGitURL ?? draft.normalizedGitURL,
            skillsPaths: draft.skillsPaths
        )
    }

    @MainActor
    func applyGitURL(_ raw: String?) -> Bool {
        guard let normalized = Self.normalizedGitURLInput(raw) else { return false }
        newGitURL = normalized
        return true
    }
    
    @MainActor
    func saveRepository() async {
        isAddingRepository = true
        defer { isAddingRepository = false }

        let resolvedName = autoRepositoryName()
        var repo: RemoteRepository
        
        // In edit mode, start from existing repository to preserve ID and other properties
        if let existingRepo = repositoryToEdit {
            repo = existingRepo
            repo.name = resolvedName
            repo.localPath = newLocalPath.isEmpty ? nil : newLocalPath
            repo.gitURL = newGitURL.isEmpty ? nil : newGitURL
            repo.skillsPaths = preferredSkillsPaths
            if !newGitURL.isEmpty {
                repo.provider = RemoteRepository.detectProvider(from: newGitURL) ?? .github
            }
        } else {
            // Create new repository based on template
            switch selectedTemplate {
            case .clawdhub:
                repo = selectedTemplate.createRepository()
            case .localFolder:
                repo = selectedTemplate.createRepository(
                    name: resolvedName,
                    localPath: newLocalPath
                )
            case .git:
                let detectedProvider = RemoteRepository.detectProvider(from: newGitURL) ?? .github
                repo = selectedTemplate.createRepository(
                    name: resolvedName,
                    gitURL: newGitURL,
                    provider: detectedProvider,
                    skillsPaths: preferredSkillsPaths
                )
            case .globalSkills:
                return
            }
        }

        // Handle Git repository sync for new repos or URL changes
        if selectedTemplate == .git || repo.templateType == .git {
            let needsSync = repositoryToEdit == nil || repositoryToEdit?.gitURL != newGitURL
            
            if needsSync {
                do {
                    let (result, plan) = try await syncOrchestrator.sync(repository: repo)

                    if !result.success {
                        validationError = "Failed to sync repository: \(result.message)"
                        return
                    }

                    repo = plan.repository
                    if !preferredSkillsPaths.isEmpty || !plan.shouldPromptDirectorySelection {
                        settings.upsertRemoteRepository(repo)
                        onRepositorySaved?(repo)
                    } else {
                        onDirectoryCandidatesFound?(repo, plan.detectedDirectories)
                    }
                    onDismiss?()
                } catch {
                    validationError = "Failed to sync repository: \(error.localizedDescription)"
                    return
                }
                return
            } else {
                // URL unchanged in edit mode, just update metadata
                if isEditing {
                    settings.updateRemoteRepository(repo)
                    onRepositorySaved?(repo)
                    onDismiss?()
                    return
                }
            }
        }

        settings.upsertRemoteRepository(repo)
        onRepositorySaved?(repo)
        onDismiss?()
    }

    private func autoRepositoryName() -> String {
        switch selectedTemplate {
        case .localFolder:
            if !newRepoName.isEmpty { return newRepoName }
            let trimmed = newLocalPath.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return "" }
            return URL(fileURLWithPath: trimmed).lastPathComponent
        case .git:
            if !newRepoName.isEmpty { return newRepoName }
            let inferred = draftService.inferredRepositoryName(from: newGitURL)
            if !inferred.isEmpty { return inferred }
            return "git-repo"
        case .clawdhub:
            return "Clawdhub"
        case .globalSkills:
            return selectedTemplate.defaultName
        }
    }
}
