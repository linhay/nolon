import SwiftUI
import Observation

@Observable
final class RemoteRepositorySidebarViewModel {
    
    // Directory selection for Git repos
    var showingDirectoryPicker = false
    var pendingRepository: RemoteRepository?
    var detectedCandidates: [GitRepositoryService.SkillsDirectoryCandidate] = []
    var selectedDirectoryIndices: Set<Int> = []
    
    // Token input for SSH-unavailable repos
    var showingTokenInput = false
    var tokenInputRepository: RemoteRepository?
    var tokenInputHost: String = ""
    var inputToken: String = ""
    
    // Repository management
    var showingAddRepository = false
    var isSyncing = false
    var syncError: String?
    
    @MainActor
    func handleDirectoryCandidatesFound(repo: RemoteRepository, candidates: [GitRepositoryService.SkillsDirectoryCandidate]) {
        pendingRepository = repo
        detectedCandidates = candidates
        selectedDirectoryIndices = Set(0..<candidates.count)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.showingDirectoryPicker = true
        }
    }
    
    @MainActor
    func syncRepository(_ repo: RemoteRepository, settings: ProviderSettings) async {
        guard repo.templateType == .git else { return }
        
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            let gitService = GitRepositoryService.shared
            let result = try await gitService.syncRepository(repo)
            
            if result.success {
                var updatedRepo = repo
                updatedRepo.lastSyncDate = result.updatedAt
                
                // If no skills paths configured and directories detected, trigger selection
                if repo.skillsPaths.isEmpty && !result.detectedDirectories.isEmpty {
                    pendingRepository = updatedRepo
                    detectedCandidates = result.detectedDirectories
                    selectedDirectoryIndices = Set(0..<result.detectedDirectories.count)
                    showingDirectoryPicker = true
                } else if repo.skillsPaths.isEmpty && result.detectedDirectories.isEmpty {
                    // No paths specified and no directories detected - use repository root
                    // Rescan to detect skills at root level
                    let clonePath = repo.localClonePath
                    if FileManager.default.fileExists(atPath: clonePath.path) {
                        let detected = await gitService.detectSkillsDirectories(at: clonePath)
                        if !detected.isEmpty {
                            updatedRepo.detectedDirectories = detected.map { $0.path }
                            pendingRepository = updatedRepo
                            detectedCandidates = detected
                            selectedDirectoryIndices = Set(0..<detected.count)
                            showingDirectoryPicker = true
                        }
                    }
                }
                
                settings.updateRemoteRepository(updatedRepo)
            } else {
                syncError = result.message
            }
        } catch GitRepositoryError.sshNotAvailable(let host) {
            // SSH not available, prompt for token
            tokenInputRepository = repo
            tokenInputHost = host
            inputToken = repo.accessToken ?? ""
            showingTokenInput = true
        } catch {
            syncError = error.localizedDescription
        }
    }
    
    @MainActor
    func removeRepository(_ repo: RemoteRepository, settings: ProviderSettings) async {
        // For Git repos, also delete the cloned directory
        if repo.templateType == .git {
            do {
                let gitService = GitRepositoryService.shared
                try await gitService.deleteRepository(repo)
            } catch {
                print("Failed to delete cloned repository: \(error)")
            }
        }
        
        settings.removeRemoteRepository(repo)
    }
    
    func revealInFinder(_ repo: RemoteRepository) {
        let paths = repo.effectiveSkillsPaths.map { URL(fileURLWithPath: $0) }
        guard !paths.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(paths)
    }
    
    @MainActor
    func confirmDirectorySelection(settings: ProviderSettings) {
        guard var repo = pendingRepository else { return }
        
        let selectedPaths = selectedDirectoryIndices.compactMap { index -> String? in
            guard index < detectedCandidates.count else { return nil }
            return detectedCandidates[index].path
        }
        
        repo.skillsPaths = selectedPaths
        
        settings.addRemoteRepository(repo)
        pendingRepository = nil
    }
    
    @MainActor
    func confirmTokenInput(settings: ProviderSettings) {
        guard var repo = tokenInputRepository else { return }
        
        repo.accessToken = inputToken.isEmpty ? nil : inputToken
        settings.updateRemoteRepository(repo)
        
        // Retry sync with the new token
        Task {
            await syncRepository(repo, settings: settings)
        }
        
        tokenInputRepository = nil
        inputToken = ""
    }
}

/// Left column 1: Repository sidebar with list and add button
struct RemoteRepositorySidebarView: View {
    @Binding var selectedRepository: RemoteRepository?
    @ObservedObject var settings: ProviderSettings
    
    @State private var viewModel = RemoteRepositorySidebarViewModel()
    
    var body: some View {
        List(selection: $selectedRepository) {
            Section {
                ForEach(settings.remoteRepositories) { repo in
                    repositoryRow(repo)
                        .tag(repo)
                }
                .onDelete(perform: deleteRepository)
            } header: {
                Text("Repositories")
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            addRepositoryButton
        }
        .navigationTitle("Sources")
        .sheet(isPresented: $viewModel.showingAddRepository) {
            AddRepositorySheet(
                isPresented: $viewModel.showingAddRepository,
                settings: settings,
                onDirectoryCandidatesFound: { repo, candidates in
                    viewModel.handleDirectoryCandidatesFound(repo: repo, candidates: candidates)
                }
            )
        }
        .sheet(isPresented: $viewModel.showingDirectoryPicker) {
            DirectoryPickerSheet(
                isPresented: $viewModel.showingDirectoryPicker,
                candidates: viewModel.detectedCandidates,
                selectedIndices: $viewModel.selectedDirectoryIndices,
                onConfirm: {
                    viewModel.confirmDirectorySelection(settings: settings)
                }
            )
        }
        .sheet(isPresented: $viewModel.showingTokenInput) {
            TokenInputSheet(
                isPresented: $viewModel.showingTokenInput,
                host: viewModel.tokenInputHost,
                token: $viewModel.inputToken,
                onConfirm: {
                    viewModel.confirmTokenInput(settings: settings)
                }
            )
        }
        .onAppear {
            if selectedRepository == nil {
                selectedRepository = settings.remoteRepositories.first
            }
            // Check for pending import immediately on appear
            if settings.pendingImportURL != nil {
                viewModel.showingAddRepository = true
            }
        }
        .onChange(of: settings.pendingImportURL) { _, newValue in
            if newValue != nil {
                viewModel.showingAddRepository = true
            }
        }

    }
    
    private func repositoryRow(_ repo: RemoteRepository) -> some View {
        HStack {
            Label(repo.name, systemImage: repo.iconName)
            Spacer()
            
            // Show badges based on type
            if repo.isBuiltIn {
                Text("Built-in")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            } else if repo.templateType == .git {
                if let syncDate = repo.lastSyncDate {
                    Text(syncDate, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Not synced")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                }
            }
        }
        .contextMenu {
            // Sync option for Git repositories
            if repo.templateType == .git {
                Button {
                    Task { await viewModel.syncRepository(repo, settings: settings) }
                } label: {
                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                }
            }
            
            // Reveal in Finder for local folder, global skills and Git repos
            if repo.templateType == .localFolder || repo.templateType == .git || repo.templateType == .globalSkills {
                Button {
                    viewModel.revealInFinder(repo)
                } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                }
            }
            
            // Remove option for non-built-in repositories
            if !repo.isBuiltIn {
                Divider()
                Button(role: .destructive) {
                    Task { await viewModel.removeRepository(repo, settings: settings) }
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
        }
    }
    
    private var addRepositoryButton: some View {
        Button {
            viewModel.showingAddRepository = true
        } label: {
            Label("Add Repository", systemImage: "plus")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.borderless)
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    private func deleteRepository(at offsets: IndexSet) {
        for index in offsets {
            let repo = settings.remoteRepositories[index]
            if !repo.isBuiltIn {
                settings.removeRemoteRepository(repo)
            }
        }
    }
}

// MARK: - Token Input Sheet

struct TokenInputSheet: View {
    @Binding var isPresented: Bool
    let host: String
    @Binding var token: String
    let onConfirm: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "key.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            
            Text("SSH Authentication Unavailable")
                .font(.headline)
            
            Text(
                "SSH key is not configured for **\(host)**. Please provide a Personal Access Token to authenticate."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Personal Access Token")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                SecureField("Enter your token", text: $token)
                    .textFieldStyle(.roundedBorder)
            }
            
            Text("Generate a token from your Git provider's settings with 'read_repository' scope.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                
                Button("Save & Retry") {
                    isPresented = false
                    onConfirm()
                }
                .buttonStyle(.borderedProminent)
                .disabled(token.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400)
    }
}
