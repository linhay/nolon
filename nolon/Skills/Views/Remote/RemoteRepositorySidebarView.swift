import SwiftUI
import Observation
import os.log
import STFilePath
import NolonResourceKit

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
    @ObservationIgnored
    private let syncOrchestrator = RepositorySyncOrchestrator()

    enum SyncCompletionStyle {
        case success
        case failure
    }
    
    @MainActor
    func handleDirectoryCandidatesFound(repo: RemoteRepository, candidates: [GitRepository.SkillsDirectoryCandidate]) {
        pendingRepository = repo
        detectedCandidates = candidates
        let preferredPaths = Set(repo.skillsPaths)
        if preferredPaths.isEmpty {
            selectedDirectoryIndices = Set(0..<candidates.count)
        } else {
            selectedDirectoryIndices = Set(
                candidates.enumerated().compactMap { index, candidate in
                    preferredPaths.contains(candidate.path) ? index : nil
                }
            )
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + RemoteRefreshPolicy.repositorySelectionDelay) {
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
            let (result, plan) = try await syncOrchestrator.sync(repository: repo)
            
            if result.success {
                let updatedRepo = plan.repository
                if plan.shouldPromptDirectorySelection {
                    pendingRepository = updatedRepo
                    detectedCandidates = plan.detectedDirectories
                    selectedDirectoryIndices = Set(0..<plan.detectedDirectories.count)
                    showingDirectoryPicker = true
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
        
        settings.upsertRemoteRepository(repo)
        pendingRepository = nil
        detectedCandidates = []
        selectedDirectoryIndices = []
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
    var showsHeader: Bool = true
    var title: String? = nil
    
    @State private var viewModel = RemoteRepositorySidebarViewModel()
    @State private var collapsedSectionIDs: Set<String> = []
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        let sections = repositorySections(settings.remoteRepositories)
        let orderedRepositories = sections.flatMap { $0.repositories }
        VStack(spacing: 0) {
            if showsHeader {
                SheetHeaderView(title: NSLocalizedString("Sources", comment: "Sources")) { EmptyView() }
                SheetDivider()
            } else if let title, !title.isEmpty {
                HStack {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(DesignSystem.Colors.Text.primary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }

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
            .padding(.bottom, 52)
        }
        .overlay(alignment: .bottomTrailing) {
            floatingAddRepositoryButton
                .padding(.trailing, 12)
                .padding(.bottom, 12)
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
                    .dsSecondaryText(font: .caption2)
            } else {
                Text(NSLocalizedString("Not synced", comment: "Repository not synced"))
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
                    .dsSecondaryText(font: .caption)

                Text(section.title)
                    .font(.caption)
                    .dsSecondaryText(font: .caption)

                Spacer(minLength: 0)
            }
            .textCase(nil)
            .padding(.top, 6)
            .padding(.bottom, 2)
            .contentShape(Rectangle())
        }
        .dsLinkButton()
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
                        .dsSecondaryText(font: .caption)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(repositoryDisplayName(repo))
                        .font(.body)
                        .foregroundStyle(DesignSystem.Colors.Text.primary)
                        .lineLimit(1)

                    if let secondaryLine = repositorySecondaryLine(repo) {
                        Text(secondaryLine)
                            .font(.caption)
                            .dsSecondaryText(font: .caption)
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
                        .dsBadge(
                            foreground: DesignSystem.Colors.Text.secondary,
                            background: DesignSystem.Colors.Component.controlFillSubtle,
                            horizontalPadding: 6,
                            verticalPadding: 2
                        )
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
                        .dsIconLabelButton()
                }
            }
            
            // Reveal in Finder for local folder, global skills and Git repos
            if repo.templateType == .localFolder || repo.templateType == .git || repo.templateType == .globalSkills {
                Button {
                    viewModel.revealInFinder(repo)
                } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                        .dsIconLabelButton()
                }
            }
            
            // Edit option for non-built-in repositories
            if !repo.isBuiltIn {
                Button {
                    viewModel.editingRepository = repo
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .dsIconLabelButton()
                }
            }
            
            // Remove option for non-built-in repositories
            if !repo.isBuiltIn {
                Divider()
                Button(role: .destructive) {
                    Task { await viewModel.removeRepository(repo, settings: settings) }
                } label: {
                    Label("Remove", systemImage: "trash")
                        .dsIconLabelButton()
                }
            }
        }
    }
    
    private var floatingAddRepositoryButton: some View {
        Button {
            viewModel.showingAddRepository = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.Text.onAccent)
                .frame(width: 34, height: 34)
                .background(DesignSystem.Colors.primary, in: Circle())
                .shadow(color: DesignSystem.Colors.primary.opacity(0.35), radius: 6, x: 0, y: 3)
        }
        .dsLinkButton()
        .help(NSLocalizedString("Add Repository", comment: "Add Repository"))
        .accessibilityLabel(NSLocalizedString("Add Repository", comment: "Add Repository"))
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
                        .dsSecondaryText(font: .system(size: 11))
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .dsCard(
            background: DesignSystem.Colors.Background.elevated.opacity(0.94),
            cornerRadius: DesignSystem.Metrics.cornerRadiusM,
            borderColor: DesignSystem.Colors.Component.border.opacity(style == .failure ? 0.6 : 0.35),
            shadow: DesignSystem.CardShadow(
                color: DesignSystem.Colors.Text.primary.opacity(0.14),
                radius: 12,
                x: 0,
                y: 8
            )
        )
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
                .dsSecondaryText(font: .subheadline)
                .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("Personal Access Token", comment: "Personal access token"))
                        .font(.caption)
                        .dsSecondaryText(font: .caption)

                    SecureField(NSLocalizedString("Enter your token", comment: "Enter token"), text: $token)
                        .textFieldStyle(.roundedBorder)
                }

                Text(NSLocalizedString("Generate a token from your Git provider's settings with 'read_repository' scope.", comment: "Token help"))
                    .font(.caption)
                    .dsTertiaryText(font: .caption)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, SheetLayout.horizontalPadding)
            .padding(.vertical, SheetLayout.contentVerticalPadding)

            SheetDivider()

            HStack(spacing: 12) {
                Button(NSLocalizedString("Cancel", comment: "Cancel")) {
                    isPresented = false
                }
                .dsLinkButton()

                Spacer(minLength: 0)

                Button(NSLocalizedString("Save & Retry", comment: "Save and retry")) {
                    isPresented = false
                    onConfirm()
                }
                .dsPrimaryButton()
                .disabled(token.isEmpty)
            }
            .padding(.horizontal, SheetLayout.footerHorizontalPadding)
            .padding(.vertical, SheetLayout.footerVerticalPadding)
        }
        .frame(width: 420)
    }
}
