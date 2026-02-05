import SwiftUI
import Observation
import os.log
import STFilePath

@Observable
final class RemoteRepositorySidebarViewModel {

    private let logger = Logger(subsystem: "com.nolon", category: "RemoteRepositorySidebarViewModel")
    
    // Directory selection for Git repos
    var showingDirectoryPicker = false
    var pendingRepository: RemoteRepository?
    var detectedCandidates: [GitRepository.SkillsDirectoryCandidate] = []
    var selectedDirectoryIndices: Set<Int> = []
    
    // Token input for SSH-unavailable repos
    var showingTokenInput = false
    var tokenInputRepository: RemoteRepository?
    var tokenInputHost: String = ""
    var inputToken: String = ""
    
    // Repository management
    var showingAddRepository = false
    var editingRepository: RemoteRepository?  // For edit mode
    var isSyncing = false
    var syncingRepositoryID: String?
    var syncingRepositoryName: String?
    var syncCompletionMessage: String?
    var syncCompletionRepositoryName: String?
    var syncCompletionStyle: SyncCompletionStyle?

    @ObservationIgnored
    private var syncCompletionToken: UUID?

    @ObservationIgnored
    private let syncSuccessDisplayDuration: TimeInterval = 1.6

    @ObservationIgnored
    private let syncFailureDisplayDuration: TimeInterval = 2.6

    enum SyncCompletionStyle {
        case success
        case failure
    }
    
    @MainActor
    func handleDirectoryCandidatesFound(repo: RemoteRepository, candidates: [GitRepository.SkillsDirectoryCandidate]) {
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
        
        syncCompletionMessage = nil
        syncCompletionRepositoryName = nil
        syncCompletionStyle = nil
        isSyncing = true
        syncingRepositoryID = repo.id
        syncingRepositoryName = repositoryDisplayName(repo)
        defer {
            isSyncing = false
            syncingRepositoryID = nil
            syncingRepositoryName = nil
        }
        
        do {
            let result = try await GitRepository.syncRepository(repo)
            
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
                    if STPath(clonePath).isExists {
                        let detected = GitRepository.detectSkillsDirectories(at: clonePath)
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
                showSyncCompletion(
                    message: result.message,
                    style: .success,
                    repositoryName: repositoryDisplayName(repo)
                )
            } else {
                showSyncCompletion(
                    message: result.message,
                    style: .failure,
                    repositoryName: repositoryDisplayName(repo)
                )
            }
        } catch GitRepository.SyncError.sshNotAvailable(let host) {
            // SSH not available, prompt for token
            tokenInputRepository = repo
            tokenInputHost = host
            inputToken = repo.accessToken ?? ""
            showingTokenInput = true
        } catch {
            showSyncCompletion(
                message: error.localizedDescription,
                style: .failure,
                repositoryName: repositoryDisplayName(repo)
            )
        }
    }

    @MainActor
    private func showSyncCompletion(message: String, style: SyncCompletionStyle, repositoryName: String) {
        let token = UUID()
        syncCompletionToken = token
        withAnimation(.easeInOut(duration: 0.2)) {
            syncCompletionMessage = message.isEmpty
                ? NSLocalizedString("generic.error", comment: "Error")
                : message
            syncCompletionRepositoryName = repositoryName
            syncCompletionStyle = style
        }

        let duration = style == .success ? syncSuccessDisplayDuration : syncFailureDisplayDuration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self, self.syncCompletionToken == token else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                self.syncCompletionMessage = nil
                self.syncCompletionRepositoryName = nil
                self.syncCompletionStyle = nil
            }
        }
    }
    
    @MainActor
    func removeRepository(_ repo: RemoteRepository, settings: ProviderSettings) async {
        // For Git repos, also delete the cloned directory
        if repo.templateType == .git {
            do {
                try GitRepository.deleteRepository(repo)
            } catch {
                logger.error("Failed to delete cloned repository: \(error.localizedDescription)")
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
    @State private var collapsedSectionIDs: Set<String> = []
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        let sections = repositorySections(settings.remoteRepositories)
        let orderedRepositories = sections.flatMap { $0.repositories }
        VStack(spacing: 0) {
            SheetHeaderView(title: NSLocalizedString("Sources", comment: "Sources")) {
                EmptyView()
            }

            SheetDivider()

            List(selection: $selectedRepository) {
                ForEach(sections) { section in
                    Section {
                        sectionHeaderRow(section)
                        if !collapsedSectionIDs.contains(section.id) {
                            ForEach(section.repositories) { repo in
                                repositoryRow(repo)
                                    .tag(repo)
                            }
                            .onDelete { offsets in
                                deleteRepositories(offsets, in: section.repositories)
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .animation(.snappy(duration: 0.2), value: collapsedSectionIDs)
            .safeAreaInset(edge: .bottom) {
                addRepositoryButton
            }
        }
        .overlay(alignment: .top) {
            syncHUDOverlay
        }
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
        .sheet(item: $viewModel.editingRepository) { repo in
            AddRepositorySheet(
                isPresented: Binding(
                    get: { viewModel.editingRepository != nil },
                    set: { if !$0 { viewModel.editingRepository = nil } }
                ),
                settings: settings,
                repositoryToEdit: repo,
                onDirectoryCandidatesFound: { updatedRepo, candidates in
                    viewModel.handleDirectoryCandidatesFound(repo: updatedRepo, candidates: candidates)
                }
            )
        }
        .onAppear {
            if selectedRepository == nil {
                selectedRepository = orderedRepositories.first
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
    
    private func gitStatusRow(_ repo: RemoteRepository) -> some View {
        Group {
            if viewModel.isSyncing, viewModel.syncingRepositoryID == repo.id {
                ProgressView()
                    .controlSize(.mini)
                    .tint(DesignSystem.Colors.Status.info)
            } else if let syncDate = repo.lastSyncDate {
                Text(syncDate, style: .time)
                    .font(.caption2)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
            } else {
                Text("Not synced")
                    .font(.caption2)
                    .foregroundStyle(DesignSystem.Colors.Status.warning)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionHeaderRow(_ section: RepositorySection) -> some View {
        Button {
            toggleSection(section)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: collapsedSectionIDs.contains(section.id) ? "chevron.right" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)

                Text(section.title)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)

                Spacer(minLength: 0)
            }
            .textCase(nil)
            .padding(.top, 6)
            .padding(.bottom, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowSeparator(.hidden)
        .selectionDisabled(true)
    }

    private func toggleSection(_ section: RepositorySection) {
        if collapsedSectionIDs.contains(section.id) {
            collapsedSectionIDs.remove(section.id)
        } else {
            collapsedSectionIDs.insert(section.id)
        }
    }

    private func repositoryRow(_ repo: RemoteRepository) -> some View {
        HStack(alignment: .top, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                if let logoName = repo.logoName ?? repo.provider.logoName {
                    ProviderLogoView(name: repo.name, logoName: logoName, iconSize: 16)
                } else {
                    Image(systemName: repo.iconName)
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(repositoryDisplayName(repo))
                        .font(.body)
                        .foregroundStyle(DesignSystem.Colors.Text.primary)
                        .lineLimit(1)

                    if let secondaryLine = repositorySecondaryLine(repo) {
                        Text(secondaryLine)
                            .font(.caption)
                            .foregroundStyle(DesignSystem.Colors.Text.secondary)
                            .lineLimit(1)
                    }

                    if repo.templateType == .git {
                        gitStatusRow(repo)
                    }
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                if repo.isBuiltIn {
                    Text("Built-in")
                        .font(.caption2)
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(DesignSystem.Colors.Component.controlFillSubtle)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusXS, style: .continuous))
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
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
            
            // Edit option for non-built-in repositories
            if !repo.isBuiltIn {
                Button {
                    viewModel.editingRepository = repo
                } label: {
                    Label("Edit", systemImage: "pencil")
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

    private enum SyncHUDStyle {
        case info
        case success
        case failure
    }

    @ViewBuilder
    private var syncHUDOverlay: some View {
        if viewModel.isSyncing || viewModel.syncCompletionMessage != nil {
            ZStack {
                if viewModel.isSyncing {
                    syncHUDCard(
                        title: NSLocalizedString("Syncing repository...", comment: "Sync in progress"),
                        subtitle: viewModel.syncingRepositoryName,
                        style: .info
                    ) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(DesignSystem.Colors.Status.info)
                    }
                } else if let message = viewModel.syncCompletionMessage {
                    let completionStyle = viewModel.syncCompletionStyle ?? .success
                    let hudStyle: SyncHUDStyle = completionStyle == .success ? .success : .failure
                    syncHUDCard(
                        title: message,
                        subtitle: viewModel.syncCompletionRepositoryName,
                        style: hudStyle
                    ) {
                        Image(systemName: completionStyle == .success ? "checkmark.circle.fill" : "xmark.octagon.fill")
                            .foregroundStyle(completionStyle == .success
                                             ? DesignSystem.Colors.Status.success
                                             : DesignSystem.Colors.Status.error)
                    }
                }
            }
            .padding(.top, 12)
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
            .allowsHitTesting(false)
        }
    }

    private func syncHUDCard(
        title: String,
        subtitle: String?,
        style: SyncHUDStyle,
        @ViewBuilder icon: () -> some View
    ) -> some View {
        HStack(spacing: 12) {
            icon()
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.Text.primary)
                    .lineLimit(2)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(DesignSystem.Colors.Background.elevated.opacity(0.94))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(DesignSystem.Colors.Component.border.opacity(style == .failure ? 0.6 : 0.35), lineWidth: 1)
        )
        .shadow(color: DesignSystem.Colors.Text.primary.opacity(0.14), radius: 12, x: 0, y: 8)
    }
    
    private func deleteRepositories(_ offsets: IndexSet, in repos: [RemoteRepository]) {
        for index in offsets {
            guard index < repos.count else { continue }
            let repo = repos[index]
            if !repo.isBuiltIn {
                settings.removeRemoteRepository(repo)
            }
        }
    }
}

private struct RepositorySection: Identifiable {
    let id: String
    let title: String
    let repositories: [RemoteRepository]
}

private func repositorySections(_ repos: [RemoteRepository]) -> [RepositorySection] {
    var sections: [RepositorySection] = []

    let builtInRepos = repos.filter { $0.isBuiltIn }
    if !builtInRepos.isEmpty {
        let orderedBuiltIn = builtInRepos.sorted { lhs, rhs in
            let lKey = builtInSortKey(lhs)
            let rKey = builtInSortKey(rhs)
            if lKey != rKey { return lKey < rKey }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
        sections.append(
            RepositorySection(
                id: "built_in",
                title: "Built-in",
                repositories: orderedBuiltIn
            )
        )
    }

    for template in RepositoryTemplate.allCases {
        let nonBuiltIn = repos.filter { !$0.isBuiltIn && $0.templateType == template }
        guard !nonBuiltIn.isEmpty else { continue }

        if template == .git {
            var grouped: [String: [RemoteRepository]] = [:]
            for repo in nonBuiltIn {
                let host = gitRepositoryHost(repo) ?? RepositoryTemplate.git.displayName
                grouped[host, default: []].append(repo)
            }

            let orderedHosts = grouped.keys.sorted { lhs, rhs in
                lhs.localizedStandardCompare(rhs) == .orderedAscending
            }

            for host in orderedHosts {
                guard var repositories = grouped[host] else { continue }
                repositories.sort { lhs, rhs in
                    repositorySortKey(lhs).localizedStandardCompare(repositorySortKey(rhs)) == .orderedAscending
                }
                sections.append(
                    RepositorySection(
                        id: "git:\(host)",
                        title: host,
                        repositories: repositories
                    )
                )
            }
        } else {
            sections.append(
                RepositorySection(
                    id: template.rawValue,
                    title: template.displayName,
                    repositories: nonBuiltIn
                )
            )
        }
    }

    return sections
}

private func builtInSortKey(_ repo: RemoteRepository) -> Int {
    switch repo.templateType {
    case .globalSkills: return 0
    case .clawdhub: return 1
    default: return 2
    }
}

private func repositoryDisplayName(_ repo: RemoteRepository) -> String {
    guard repo.templateType == .git else { return repo.name }
    return gitRepositoryDisplayName(repo) ?? repo.name
}

private func repositorySecondaryLine(_ repo: RemoteRepository) -> String? {
    guard repo.templateType == .git else { return nil }
    if let host = gitRepositoryHost(repo) {
        return host
    }
    return nil
}

private func repositorySortKey(_ repo: RemoteRepository) -> String {
    repositoryDisplayName(repo).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
}

private func gitRepositoryDisplayName(_ repo: RemoteRepository) -> String? {
    guard let components = gitRepositoryComponents(repo) else { return nil }
    return "\(components.owner)@\(components.repo)"
}

private func gitRepositoryHost(_ repo: RemoteRepository) -> String? {
    if let host = gitRepositoryComponents(repo)?.host {
        return host
    }
    if let host = URL(string: repo.provider.baseURL)?.host {
        return host
    }
    return nil
}

private struct GitRepositoryComponents {
    let host: String?
    let owner: String
    let repo: String
}

private func gitRepositoryComponents(_ repo: RemoteRepository) -> GitRepositoryComponents? {
    guard let gitURL = repo.gitURL else { return nil }
    if let extracted = RemoteRepository.extractURLComponents(from: gitURL) {
        return GitRepositoryComponents(host: extracted.host, owner: extracted.owner, repo: extracted.repo)
    }
    let fallback = repo.provider.extractComponents(from: gitURL)
    return GitRepositoryComponents(host: nil, owner: fallback.owner, repo: fallback.repoName)
}

// MARK: - Token Input Sheet

struct TokenInputSheet: View {
    @Binding var isPresented: Bool
    let host: String
    @Binding var token: String
    let onConfirm: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            SheetHeaderView(title: NSLocalizedString("SSH Authentication Unavailable", comment: "SSH unavailable")) {
                isPresented = false
            }

            SheetDivider()

            VStack(spacing: 20) {
                Image(systemName: "key.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(DesignSystem.Colors.Status.warning)

                Text(
                    String(
                        format: NSLocalizedString(
                            "SSH key is not configured for %@. Please provide a Personal Access Token to authenticate.",
                            comment: "SSH token prompt"
                        ),
                        host
                    )
                )
                .font(.subheadline)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("Personal Access Token", comment: "Personal access token"))
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)

                    SecureField(NSLocalizedString("Enter your token", comment: "Enter token"), text: $token)
                        .textFieldStyle(.roundedBorder)
                }

                Text(NSLocalizedString("Generate a token from your Git provider's settings with 'read_repository' scope.", comment: "Token help"))
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, SheetLayout.horizontalPadding)
            .padding(.vertical, SheetLayout.contentVerticalPadding)

            SheetDivider()

            HStack(spacing: 12) {
                Button(NSLocalizedString("Cancel", comment: "Cancel")) {
                    isPresented = false
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                Button(NSLocalizedString("Save & Retry", comment: "Save and retry")) {
                    isPresented = false
                    onConfirm()
                }
                .buttonStyle(.borderedProminent)
                .disabled(token.isEmpty)
            }
            .padding(.horizontal, SheetLayout.footerHorizontalPadding)
            .padding(.vertical, SheetLayout.footerVerticalPadding)
        }
        .frame(width: 420)
    }
}
