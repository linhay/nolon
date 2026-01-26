import SwiftUI
import Observation

@Observable
final class AddRepositoryViewModel {
    /// The repository being edited, if any
    var repositoryToEdit: RemoteRepository?
    
    /// Whether we are in edit mode
    var isEditing: Bool { repositoryToEdit != nil }
    
    var selectedTemplate: RepositoryTemplate = .git
    var newRepoName = "" {
        didSet { validateInput() }
    }
    var newGitURL = "" {
        didSet { handleGitURLChange(newGitURL) }
    }
    var newLocalPath = "" {
        didSet { validateInput() }
    }
    var newSkillsPaths: [String] = []
    var newSkillsPathInput = ""
    
    var validationError: String?
    var isAddingRepository = false
    
    var settings: ProviderSettings
    
    var onDirectoryCandidatesFound: ((RemoteRepository, [GitRepositoryService.SkillsDirectoryCandidate]) -> Void)?
    var onDismiss: (() -> Void)?
    
    init(settings: ProviderSettings, repositoryToEdit: RemoteRepository? = nil) {
        self.settings = settings
        self.repositoryToEdit = repositoryToEdit
        
        if let repo = repositoryToEdit {
            // Edit mode: populate fields from existing repository
            selectedTemplate = repo.templateType
            newRepoName = repo.name
            newGitURL = repo.gitURL ?? ""
            newLocalPath = repo.localPath ?? ""
            newSkillsPaths = repo.skillsPaths
        } else {
            resetAddForm()
            
            // Handle pending URL import
            if let importURL = settings.pendingImportURL {
                selectedTemplate = .git
                
                // Extract subpath if present before normalization might strip it
                if let subpath = RemoteRepository.extractSubpath(from: importURL) {
                    newSkillsPaths = [subpath]
                }
                
                let normalized = RemoteRepository.normalizeGitURL(importURL)
                newGitURL = normalized
                
                // Manually trigger update logic since didSet not called in init
                let extractedName = RemoteRepository.extractRepoName(from: normalized)
                if !extractedName.isEmpty {
                    newRepoName = extractedName
                }
                
                validateInput()
                
                // Consume the pending URL
                settings.pendingImportURL = nil
            }
        }
    }

    
    // Templates available for user to add (exclude built-in globalSkills)
    var availableTemplates: [RepositoryTemplate] {
        RepositoryTemplate.allCases.filter { $0 != .globalSkills }
    }
    
    var canAddRepository: Bool {
        if validationError != nil { return false }

        switch selectedTemplate {
        case .localFolder:
            return !newRepoName.isEmpty && !newLocalPath.isEmpty
        case .git:
            return !newRepoName.isEmpty && !newGitURL.isEmpty
        case .globalSkills:
            return false
        }
    }
    
    func handleTemplateChange(_ newTemplate: RepositoryTemplate) {
        newRepoName = newTemplate.defaultName
        newLocalPath = ""
        newGitURL = ""
        newSkillsPaths = []
        newSkillsPathInput = ""
        validationError = nil
    }

    func handleGitURLChange(_ newURL: String) {
        if selectedTemplate == .git && !newURL.isEmpty {
            let extractedName = RemoteRepository.extractRepoName(from: newURL)
            if !extractedName.isEmpty {
                newRepoName = extractedName
            }
        }
        validateInput()
    }

    func addSkillsPath() {
        let trimmed = newSkillsPathInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !newSkillsPaths.contains(trimmed) {
            newSkillsPaths.append(trimmed)
        }
        newSkillsPathInput = ""
    }
    
    func removeSkillsPath(at index: Int) {
        guard index >= 0 && index < newSkillsPaths.count else { return }
        newSkillsPaths.remove(at: index)
    }

    func validateInput() {
        validationError = nil
        
        // Skip duplicate checks when editing the same repository
        let editingId = repositoryToEdit?.id

        if !newRepoName.isEmpty && selectedTemplate != .git && selectedTemplate != .localFolder {
            if settings.remoteRepositories.contains(where: { $0.name == newRepoName && $0.id != editingId }) {
                validationError = "A repository with this name already exists."
                return
            }
        }

        if selectedTemplate == .git && !newGitURL.isEmpty {
            let detectedProvider = RemoteRepository.detectProvider(from: newGitURL) ?? .github
            let normalizedURL = detectedProvider.normalizeURL(newGitURL)
            if settings.remoteRepositories.contains(where: { repo in
                guard repo.id != editingId, repo.templateType == .git, let existingURL = repo.gitURL else {
                    return false
                }
                let existingProvider = RemoteRepository.detectProvider(from: existingURL) ?? .github
                return existingProvider.normalizeURL(existingURL) == normalizedURL
            }) {
                validationError = "This Git repository has already been added."
                return
            }
        }

        if selectedTemplate == .localFolder && !newLocalPath.isEmpty {
            if settings.remoteRepositories.contains(where: {
                $0.id != editingId && $0.templateType == .localFolder && $0.localPath == newLocalPath
            }) {
                validationError = "This folder has already been added."
                return
            }
        }
    }
    
    func resetAddForm() {
        selectedTemplate = .git
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
    func saveRepository() async {
        isAddingRepository = true
        defer { isAddingRepository = false }

        var repo: RemoteRepository
        
        // In edit mode, start from existing repository to preserve ID and other properties
        if let existingRepo = repositoryToEdit {
            repo = existingRepo
            repo.name = newRepoName
            repo.localPath = newLocalPath.isEmpty ? nil : newLocalPath
            repo.gitURL = newGitURL.isEmpty ? nil : newGitURL
            repo.skillsPaths = newSkillsPaths
            if !newGitURL.isEmpty {
                repo.provider = RemoteRepository.detectProvider(from: newGitURL) ?? .github
            }
        } else {
            // Create new repository based on template
            switch selectedTemplate {
            case .localFolder:
                repo = selectedTemplate.createRepository(
                    name: newRepoName,
                    localPath: newLocalPath
                )
            case .git:
                let detectedProvider = RemoteRepository.detectProvider(from: newGitURL) ?? .github
                repo = selectedTemplate.createRepository(
                    name: newRepoName,
                    gitURL: newGitURL,
                    provider: detectedProvider,
                    skillsPaths: newSkillsPaths
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
                    let gitService = GitRepositoryService.shared
                    let result = try await gitService.syncRepository(repo)

                    if !result.success {
                        validationError = "Failed to sync repository: \(result.message)"
                        return
                    }

                    repo.lastSyncDate = result.updatedAt

                    if !newSkillsPaths.isEmpty {
                        if isEditing {
                            settings.updateRemoteRepository(repo)
                        } else {
                            settings.addRemoteRepository(repo)
                        }
                        onDismiss?()
                    } else if result.detectedDirectories.isEmpty {
                        if isEditing {
                            settings.updateRemoteRepository(repo)
                        } else {
                            settings.addRemoteRepository(repo)
                        }
                        onDismiss?()
                    } else {
                        repo.detectedDirectories = result.detectedDirectories.map { $0.path }
                        onDirectoryCandidatesFound?(repo, result.detectedDirectories)
                        onDismiss?()
                    }
                } catch {
                    validationError = "Failed to sync repository: \(error.localizedDescription)"
                    return
                }
                return
            } else {
                // URL unchanged in edit mode, just update metadata
                if isEditing {
                    settings.updateRemoteRepository(repo)
                    onDismiss?()
                    return
                }
            }
        }

        if isEditing {
            settings.updateRemoteRepository(repo)
        } else {
            settings.addRemoteRepository(repo)
        }
        onDismiss?()
    }
}
