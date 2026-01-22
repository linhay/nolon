import SwiftUI

struct AddRepositorySheet: View {
    @Binding var isPresented: Bool
    @ObservedObject var settings: ProviderSettings
    var onDirectoryCandidatesFound:
        (RemoteRepository, [GitRepositoryService.SkillsDirectoryCandidate]) -> Void

    @State private var selectedTemplate: RepositoryTemplate = .clawdhub
    @State private var newRepoName = ""
    @State private var newGitURL = ""
    @State private var newLocalPath = ""
    @State private var newSkillsPaths: [String] = []
    @State private var newSkillsPathInput = ""

    @State private var validationError: String?
    @State private var isAddingRepository = false

    var body: some View {
        NavigationStack {
            formContent
        }
        .frame(width: 450, height: 420)
    }

    // MARK: - Form Content

    @ViewBuilder
    private var formContent: some View {
        Form {
            templateSection
            nameSection
            typeSpecificSection
            errorSection
        }
        .formStyle(.grouped)
        .navigationTitle("Add Repository")
        .toolbar {
            toolbarContent
        }
        .overlay {
            loadingOverlay
        }
        .onAppear {
            resetAddForm()
        }
        .onChange(of: selectedTemplate) { _, newTemplate in
            handleTemplateChange(newTemplate)
        }
        .onChange(of: newGitURL) { _, newURL in
            handleGitURLChange(newURL)
        }
        .onChange(of: newRepoName) { _, _ in validateInput() }
        .onChange(of: newLocalPath) { _, _ in validateInput() }
    }

    // MARK: - Template Section

    // Templates available for user to add (exclude built-in globalSkills)
    private var availableTemplates: [RepositoryTemplate] {
        RepositoryTemplate.allCases.filter { $0 != .globalSkills }
    }
    
    private var templateSection: some View {
        Section {
            Picker("Type", selection: $selectedTemplate) {
                ForEach(availableTemplates) { template in
                    Label(template.displayName, systemImage: template.iconName)
                        .tag(template)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } header: {
            Text("Repository Type")
        }
    }

    // MARK: - Name Section

    private var nameSection: some View {
        Section {
            nameContent
        } header: {
            Text("Name")
        } footer: {
            if selectedTemplate == .git {
                Text("Repository name is automatically detected from the URL.")
            }
        }
    }

    @ViewBuilder
    private var nameContent: some View {
        switch selectedTemplate {
        case .clawdhub:
            HStack {
                Text("Name")
                Spacer()
                Text("Clawdhub")
                    .foregroundStyle(.secondary)
            }
        case .localFolder:
            TextField("Repository Name", text: $newRepoName)
        case .git, .globalSkills:
            HStack {
                Text("Name")
                Spacer()
                Text(newRepoName.isEmpty ? "Auto-detected" : newRepoName)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Type-Specific Section

    @ViewBuilder
    private var typeSpecificSection: some View {
        switch selectedTemplate {
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
        Section {
            HStack {
                Text("Base URL")
                Spacer()
                Text(selectedTemplate.defaultBaseURL)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Details")
        } footer: {
            Text("Clawdhub is the official skill marketplace.")
        }
    }

    private var localFolderSection: some View {
        Section {
            HStack {
                Text(newLocalPath.isEmpty ? "No folder selected" : newLocalPath)
                    .foregroundStyle(newLocalPath.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("Choose...") {
                    selectLocalFolder()
                }
            }
        } header: {
            Text("Skills Folder")
        } footer: {
            Text("Select a folder containing skill directories (each with a SKILL.md file).")
        }
    }

    private var gitSection: some View {
        Group {
            Section {
                TextField("Repository URL", text: $newGitURL)
                    .textContentType(.URL)
            } header: {
                Text("Git Repository")
            } footer: {
                Text("Supports GitHub, GitLab, Bitbucket and other Git hosting services.")
            }

            Section {
                skillsPathsSection
            } header: {
                Text("Skills Paths")
            } footer: {
                Text("Add one or more paths containing skills (e.g., 'skills', 'python', '.agent/skills'). Use '.' for repository root.")
            }
        }
    }

    // MARK: - Skills Paths Section

    @ViewBuilder
    private var skillsPathsSection: some View {
        ForEach(Array(newSkillsPaths.enumerated()), id: \.offset) { index, path in
            HStack {
                Text(path)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button {
                    newSkillsPaths.remove(at: index)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }

        HStack {
            TextField("Path (e.g., skills, .agent)", text: $newSkillsPathInput)
            Button {
                addSkillsPath()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)
            .disabled(newSkillsPathInput.isEmpty)
        }
    }

    // MARK: - Error Section

    private var errorSection: some View {
        Group {
            if let error = validationError {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
    }

    // MARK: - Toolbar

    private var toolbarContent: some ToolbarContent {
        Group {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    isPresented = false
                }
                .disabled(isAddingRepository)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    Task { await addRepository() }
                }
                .disabled(!canAddRepository || isAddingRepository)
            }
        }
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        Group {
            if isAddingRepository {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView("Adding repository...")
                        .padding()
                        .background(Color(nsColor: .windowBackgroundColor))
                        .cornerRadius(8)
                        .shadow(radius: 4)
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var canAddRepository: Bool {
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

    // MARK: - Actions

    private func handleTemplateChange(_ newTemplate: RepositoryTemplate) {
        newRepoName = newTemplate.defaultName
        newLocalPath = ""
        newGitURL = ""
        newSkillsPaths = []
        newSkillsPathInput = ""
        validationError = nil
    }

    private func handleGitURLChange(_ newURL: String) {
        if selectedTemplate == .git && !newURL.isEmpty {
            let extractedName = RemoteRepository.extractRepoName(from: newURL)
            if !extractedName.isEmpty {
                newRepoName = extractedName
            }
        }
        validateInput()
    }

    private func addSkillsPath() {
        let trimmed = newSkillsPathInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !newSkillsPaths.contains(trimmed) {
            newSkillsPaths.append(trimmed)
        }
        newSkillsPathInput = ""
    }

    private func validateInput() {
        validationError = nil

        if !newRepoName.isEmpty {
            if settings.remoteRepositories.contains(where: { $0.name == newRepoName }) {
                validationError = "A repository with this name already exists."
                return
            }
        }

        if selectedTemplate == .git && !newGitURL.isEmpty {
            let detectedProvider = RemoteRepository.detectProvider(from: newGitURL) ?? .github
            let normalizedURL = detectedProvider.normalizeURL(newGitURL)
            if settings.remoteRepositories.contains(where: { repo in
                guard repo.templateType == .git, let existingURL = repo.gitURL else {
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
                $0.templateType == .localFolder && $0.localPath == newLocalPath
            }) {
                validationError = "This folder has already been added."
                return
            }
        }
    }

    private func addRepository() async {
        isAddingRepository = true
        defer { isAddingRepository = false }

        let repo: RemoteRepository

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

            do {
                let gitService = GitRepositoryService.shared
                let result = try await gitService.syncRepository(repo)

                if !result.success {
                    validationError = "Failed to sync repository: \(result.message)"
                    return
                }

                var updatedRepo = repo
                updatedRepo.lastSyncDate = result.updatedAt

                if !newSkillsPaths.isEmpty {
                    settings.addRemoteRepository(updatedRepo)
                    isPresented = false
                } else if result.detectedDirectories.isEmpty {
                    settings.addRemoteRepository(updatedRepo)
                    isPresented = false
                } else {
                    updatedRepo.detectedDirectories = result.detectedDirectories.map { $0.path }
                    onDirectoryCandidatesFound(updatedRepo, result.detectedDirectories)
                    isPresented = false
                }
            } catch {
                validationError = "Failed to sync repository: \(error.localizedDescription)"
                return
            }

            return
        case .globalSkills:
            return
        }

        settings.addRemoteRepository(repo)
        isPresented = false
    }

    private func resetAddForm() {
        if settings.remoteRepositories.contains(where: { $0.templateType == .clawdhub }) {
            selectedTemplate = .git
        } else {
            selectedTemplate = .clawdhub
        }
        newRepoName = selectedTemplate.defaultName
        newLocalPath = ""
        newGitURL = ""
        newSkillsPaths = []
        newSkillsPathInput = ""
        validationError = nil
    }

    private func selectLocalFolder() {
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
}
