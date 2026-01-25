import SwiftUI
import Observation

@Observable
final class AddRepositoryViewModel {
    /// The repository being edited, if any
    var repositoryToEdit: RemoteRepository?
    
    /// Whether we are in edit mode
    var isEditing: Bool { repositoryToEdit != nil }
    
    var selectedTemplate: RepositoryTemplate = .clawdhub {
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
        case .clawdhub:
            return !settings.remoteRepositories.contains { $0.templateType == .clawdhub }
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

        if !newRepoName.isEmpty {
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
        if settings.remoteRepositories.contains(where: { $0.templateType == .clawdhub }) {
            selectedTemplate = .git
        } else {
            selectedTemplate = .clawdhub
        }
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
            case .clawdhub:
                repo = selectedTemplate.createRepository()
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

struct AddRepositorySheet: View {
    @Binding var isPresented: Bool
    @State private var viewModel: AddRepositoryViewModel

    init(isPresented: Binding<Bool>, settings: ProviderSettings, repositoryToEdit: RemoteRepository? = nil, onDirectoryCandidatesFound: @escaping (RemoteRepository, [GitRepositoryService.SkillsDirectoryCandidate]) -> Void) {
        self._isPresented = isPresented
        
        let vm = AddRepositoryViewModel(settings: settings, repositoryToEdit: repositoryToEdit)
        vm.onDirectoryCandidatesFound = onDirectoryCandidatesFound
        self._viewModel = State(initialValue: vm)
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            ScrollView {
                formContent
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            footerView
        }
        .frame(width: 500, height: 480)
        .background(.ultraThinMaterial)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 30, x: 0, y: 15)
        .overlay {
            if viewModel.isAddingRepository {
                loadingOverlay
            }
        }
        .onAppear {
            viewModel.onDismiss = {
                isPresented = false
            }
        }
    }

    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            Text(viewModel.isEditing ? "Edit Repository" : "Add Repository")
                .font(.system(size: 20, weight: .bold))
            
            Spacer()
            
            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary.opacity(0.5))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isAddingRepository)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }
    
    // MARK: - Footer View
    
    private var footerView: some View {
        HStack {
            if let error = viewModel.validationError {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(.red.opacity(0.8))
                    .lineLimit(2)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.05))
                .cornerRadius(16)
                .disabled(viewModel.isAddingRepository)
                
                Button(viewModel.isEditing ? "Save" : "Add") {
                    Task { await viewModel.saveRepository() }
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .bold))
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(viewModel.canAddRepository ? Color.accentColor : Color.gray.opacity(0.2))
                .foregroundColor(viewModel.canAddRepository ? .white : .secondary)
                .cornerRadius(16)
                .disabled(!viewModel.canAddRepository || viewModel.isAddingRepository)
            }
        }
        .padding(20)
    }

    // MARK: - Form Content

    @ViewBuilder
    private var formContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Repository Type Section
            templateSection
            
            // Name Section
            nameSection
            
            // Type-Specific Section
            typeSpecificSection
        }
    }

    // MARK: - Template Section

    private var templateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Repository Type")
                .font(.system(size: 13, weight: .semibold))
            
            HStack(spacing: 10) {
                ForEach(viewModel.availableTemplates) { template in
                    templateButton(for: template)
                }
            }
        }
    }
    
    private func templateButton(for template: RepositoryTemplate) -> some View {
        let isSelected = viewModel.selectedTemplate == template
        
        return Button {
            if !viewModel.isEditing {
                viewModel.selectedTemplate = template
            }
        } label: {
            HStack(spacing: 8) {
                if let logoName = template.logoName {
                    ProviderLogoView(name: template.displayName, logoName: logoName, iconSize: 16)
                } else {
                    Image(systemName: template.iconName)
                        .font(.system(size: 14))
                        .foregroundStyle(isSelected ? .white : .secondary)
                }
                
                Text(template.displayName)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color.white.opacity(0.05))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.accentColor : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isEditing)
    }

    // MARK: - Name Section

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Name")
                .font(.system(size: 13, weight: .semibold))
            
            nameContent
        }
    }

    @ViewBuilder
    private var nameContent: some View {
        switch viewModel.selectedTemplate {
        case .clawdhub:
            readOnlyField(value: "Clawdhub")
        case .localFolder:
            textInputField(placeholder: "Repository Name", text: $viewModel.newRepoName)
        case .git, .globalSkills:
            readOnlyField(value: viewModel.newRepoName.isEmpty ? "Auto-detected from URL" : viewModel.newRepoName)
        }
    }

    // MARK: - Type-Specific Section

    @ViewBuilder
    private var typeSpecificSection: some View {
        switch viewModel.selectedTemplate {
        case .clawdhub:
            clawdhubSection
        case .localFolder:
            localFolderSection
        case .git:
            gitSection
        case .globalSkills:
            EmptyView()
        }
    }

    private var clawdhubSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.system(size: 13, weight: .semibold))
            
            readOnlyField(value: viewModel.selectedTemplate.defaultBaseURL)
            
            Text("Clawdhub is the official skill marketplace.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary.opacity(0.8))
        }
    }

    private var localFolderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Skills Folder")
                .font(.system(size: 13, weight: .semibold))
            
            HStack(spacing: 12) {
                HStack {
                    Text(viewModel.newLocalPath.isEmpty ? "No folder selected" : viewModel.newLocalPath)
                        .font(.system(size: 13))
                        .foregroundStyle(viewModel.newLocalPath.isEmpty ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.2))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                
                Button {
                    viewModel.selectLocalFolder()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "folder")
                        Text("Choose...")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(20)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            
            Text("Select a folder containing skill directories (each with a SKILL.md file).")
                .font(.system(size: 11))
                .foregroundStyle(.secondary.opacity(0.8))
        }
    }

    private var gitSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Git URL
            VStack(alignment: .leading, spacing: 12) {
                Text("Git Repository")
                    .font(.system(size: 13, weight: .semibold))
                
                HStack(spacing: 12) {
                    HStack {
                        TextField("https://github.com/...", text: $viewModel.newGitURL)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .textContentType(.URL)
                        
                        if !viewModel.newGitURL.isEmpty {
                            let provider = RemoteRepository.detectProvider(from: viewModel.newGitURL) ?? .github
                            if let logoName = provider.logoName {
                                ProviderLogoView(name: provider.displayName, logoName: logoName, iconSize: 18)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
                
                Text("Supports GitHub, GitLab, Bitbucket and other Git hosting services.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary.opacity(0.8))
            }
            
            // Skills Paths
            VStack(alignment: .leading, spacing: 12) {
                Text("Skills Paths")
                    .font(.system(size: 13, weight: .semibold))
                
                skillsPathsSection
                
                Text("Add one or more paths containing skills (e.g., 'skills', 'python', '.agent/skills'). Use '.' for repository root.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary.opacity(0.8))
            }
        }
    }

    // MARK: - Skills Paths Section

    @ViewBuilder
    private var skillsPathsSection: some View {
        VStack(spacing: 8) {
            ForEach(Array(viewModel.newSkillsPaths.enumerated()), id: \.offset) { index, path in
                HStack {
                    Text(path)
                        .font(.system(size: 13))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Spacer()
                    
                    Button {
                        viewModel.removeSkillsPath(at: index)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.03))
                .cornerRadius(8)
            }
            
            HStack(spacing: 8) {
                HStack {
                    TextField("Path (e.g., skills, .agent)", text: $viewModel.newSkillsPathInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.2))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                
                Button {
                    viewModel.addSkillsPath()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.newSkillsPathInput.isEmpty)
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func textInputField(placeholder: String, text: Binding<String>) -> some View {
        HStack {
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.2))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func readOnlyField(value: String) -> some View {
        HStack {
            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.03))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .cornerRadius(24)
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                
                Text("Adding repository...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
        }
    }
}

