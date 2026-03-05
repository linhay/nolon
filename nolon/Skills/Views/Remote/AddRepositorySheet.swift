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
    
    var settings: ProviderSettings
    
    var onDirectoryCandidatesFound: ((RemoteRepository, [GitRepository.SkillsDirectoryCandidate]) -> Void)?
    var onDismiss: (() -> Void)?
    private let syncOrchestrator = RepositorySyncOrchestrator()
    private let draftService = RepositoryDraftService()
    
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
            
            // Handle pending URL import
            if let importURL = settings.pendingImportURL {
                Self.logger.info("Handling pending import URL: \(importURL, privacy: .public)")
                applyPendingImportURL(importURL)
                
                validateInput()
                
                // Consume the pending URL asynchronously to avoid "Publishing changes from within view updates"
                Task { @MainActor in
                    settings.pendingImportURL = nil
                }
            }
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
        applyPendingImportURL(importURL)
        
        validateInput()
        
        // Consume the pending URL asynchronously
        Task { @MainActor in
            settings.pendingImportURL = nil
        }
    }

    private func applyPendingImportURL(_ importURL: String) {
        let intent = draftService.parseImportIntent(from: importURL)
        guard intent.kind == .gitRepository else {
            Self.logger.info("Skip AddRepositorySheet pending import handling for non-git URL: \(importURL, privacy: .public)")
            return
        }

        let draft = draftService.importedDraft(from: importURL)
        selectedTemplate = draft.template
        preferredSkillsPaths = draft.skillsPaths
        newGitURL = intent.normalizedGitURL ?? draft.normalizedGitURL
        if !draft.name.isEmpty {
            newRepoName = draft.name
        }
        Self.logger.info("Loaded git URL: \(self.newGitURL, privacy: .public), name: \(self.newRepoName, privacy: .public)")
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
                    onDismiss?()
                    return
                }
            }
        }

        settings.upsertRemoteRepository(repo)
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

struct AddRepositorySheet: View {
    @Binding var isPresented: Bool
    @State private var viewModel: AddRepositoryViewModel
    @State private var isLocalFolderDropTargeted = false

    init(isPresented: Binding<Bool>, settings: ProviderSettings, repositoryToEdit: RemoteRepository? = nil, onDirectoryCandidatesFound: @escaping (RemoteRepository, [GitRepository.SkillsDirectoryCandidate]) -> Void) {
        self._isPresented = isPresented
        
        let vm = AddRepositoryViewModel(settings: settings, repositoryToEdit: repositoryToEdit)
        vm.onDirectoryCandidatesFound = onDirectoryCandidatesFound
        self._viewModel = State(initialValue: vm)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                formContent
                    .padding(.horizontal, SheetLayout.horizontalPadding)
                    .padding(.top, SheetLayout.contentVerticalPadding)
                    .padding(.bottom, SheetLayout.contentBottomPadding)
            }
            
            SheetDivider()
            
            footerView
        }
        .frame(width: 640, height: 600)
        .textSelection(.enabled)
        .dsGlassPanel()
        .overlay {
            if viewModel.isAddingRepository {
                loadingOverlay
            }
        }
        .onAppear {
            viewModel.onDismiss = {
                isPresented = false
            }
            // Check for pending URL on appear (handles @State caching issue)
            viewModel.checkPendingImportURL()
        }
    }

    // MARK: - Footer View
    
    private var footerView: some View {
        HStack {
            if let error = viewModel.validationError {
                Text(error)
                    .dsErrorText(font: .system(size: 12))
                    .lineLimit(2)
                    .textSelection(.enabled)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .dsLinkButton()
                .font(.system(size: 13, weight: .medium))
                .dsBadge(
                    foreground: DesignSystem.Colors.Text.primary,
                    background: DesignSystem.Colors.Component.controlFill,
                    horizontalPadding: 16,
                    verticalPadding: 8
                )
                .disabled(viewModel.isAddingRepository)
                
                Button(viewModel.isEditing ? "Save" : "Add") {
                    Task { await viewModel.saveRepository() }
                }
                .dsLinkButton()
                .font(.system(size: 13, weight: .bold))
                .dsBadge(
                    foreground: viewModel.canAddRepository ? DesignSystem.Colors.Text.onAccent : DesignSystem.Colors.Text.tertiary,
                    background: viewModel.canAddRepository ? DesignSystem.Colors.primary : DesignSystem.Colors.Component.disabledFill,
                    horizontalPadding: 24,
                    verticalPadding: 8
                )
                .disabled(!viewModel.canAddRepository || viewModel.isAddingRepository)
            }
        }
        .padding(.horizontal, SheetLayout.footerHorizontalPadding)
        .padding(.vertical, SheetLayout.footerVerticalPadding)
    }

    // MARK: - Form Content

    @ViewBuilder
    private var formContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Repository Type Section
            templateSection

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
                        .foregroundStyle(isSelected ? DesignSystem.Colors.Text.onAccent : DesignSystem.Colors.Text.secondary)
                }
                
                Text(template.displayName)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 14)
            .dsBadgeBorder(
                foreground: isSelected ? DesignSystem.Colors.Text.onAccent : DesignSystem.Colors.Text.primary,
                background: isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.Component.controlFill,
                borderColor: isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.Component.border.opacity(0.25),
                borderWidth: 1,
                horizontalPadding: 12,
                verticalPadding: 5
            )
        }
        .dsLinkButton()
        .disabled(viewModel.isEditing)
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
                .foregroundStyle(DesignSystem.Colors.Text.secondary.opacity(0.8))
        }
    }

    private var localFolderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Skills Folder")
                .font(.system(size: 13, weight: .semibold))

            Button {
                viewModel.selectLocalFolder()
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    Text(viewModel.newLocalPath.isEmpty ? "拖拽本地 skills 文件夹到这里" : viewModel.newLocalPath)
                        .font(.system(size: 13))
                        .foregroundStyle(
                            viewModel.newLocalPath.isEmpty
                                ? DesignSystem.Colors.Text.secondary
                                : DesignSystem.Colors.Text.primary
                        )
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .truncationMode(.middle)
                    Text("或点击选择文件夹")
                        .font(.system(size: 11))
                        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                }
                .frame(maxWidth: .infinity, minHeight: 136)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            isLocalFolderDropTargeted
                                ? DesignSystem.Colors.primary.opacity(0.16)
                                : DesignSystem.Colors.Component.controlFillSubtle.opacity(0.92)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            isLocalFolderDropTargeted
                                ? DesignSystem.Colors.primary
                                : DesignSystem.Colors.Text.primary.opacity(0.45),
                            style: StrokeStyle(lineWidth: isLocalFolderDropTargeted ? 3 : 2)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .inset(by: 4)
                        .strokeBorder(
                            isLocalFolderDropTargeted
                                ? DesignSystem.Colors.primary.opacity(0.95)
                                : DesignSystem.Colors.Text.secondary.opacity(0.95),
                            style: StrokeStyle(lineWidth: 2, dash: [8, 5])
                        )
                )
                .shadow(
                    color: isLocalFolderDropTargeted
                        ? DesignSystem.Colors.primary.opacity(0.45)
                        : DesignSystem.Colors.Text.secondary.opacity(0.2),
                    radius: isLocalFolderDropTargeted ? 10 : 4
                )
            }
            .buttonStyle(.plain)
            .dropDestination(for: URL.self) { items, _ in
                viewModel.applyDroppedFolderURLs(items)
            } isTargeted: { targeted in
                isLocalFolderDropTargeted = targeted
            }
            
            Text("Select a folder containing skill directories (each with a SKILL.md file).")
                .font(.system(size: 11))
                .foregroundStyle(DesignSystem.Colors.Text.secondary.opacity(0.8))
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
                    .dsField(cornerRadius: DesignSystem.Metrics.cornerRadiusM)

                    Button {
                        _ = viewModel.applyGitURL(NSPasteboard.general.string(forType: .string))
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.on.clipboard")
                            Text("Paste")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .dsBadgeBorder(
                            foreground: DesignSystem.Colors.Text.primary,
                            background: DesignSystem.Colors.Component.controlFill,
                            borderColor: DesignSystem.Colors.Component.border.opacity(0.25),
                            borderWidth: 1,
                            horizontalPadding: 12,
                            verticalPadding: 8
                        )
                    }
                    .dsLinkButton()
                }
                
                Text("Supports GitHub, GitLab, Bitbucket and other Git hosting services.")
                    .font(.system(size: 11))
                    .foregroundStyle(DesignSystem.Colors.Text.secondary.opacity(0.8))
            }

            Text("Sync 后将自动扫描仓库中的技能目录，下一步可多选确认。")
                .font(.system(size: 11))
                .foregroundStyle(DesignSystem.Colors.Text.secondary.opacity(0.8))
        }
    }
    
    // MARK: - Helper Views
    
    private func readOnlyField(value: String) -> some View {
        HStack {
            Text(value)
                .font(.system(size: 13))
                .dsSecondaryText(font: .system(size: 13))
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .dsCard(
            background: DesignSystem.Colors.Component.controlFillSubtle,
            cornerRadius: DesignSystem.Metrics.cornerRadiusM,
            borderColor: DesignSystem.Colors.Component.border.opacity(0.20)
        )
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            DesignSystem.Colors.Overlay.scrim
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusXL, style: .continuous))
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                
                Text("Adding repository...")
                    .font(.system(size: 14, weight: .medium))
                    .dsSecondaryText(font: .system(size: 14, weight: .medium))
            }
            .padding(32)
            .dsGlassPanel(cornerRadius: DesignSystem.Metrics.cornerRadiusL)
        }
    }
}
