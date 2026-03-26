import SwiftUI
import STFilePath
import NolonResourceKit
import NolonUI

/// Left column 1: Repository sidebar with list and add button
struct RemoteRepositorySidebarView: View, DebugPageLocatable {
    @Binding var selectedRepository: RemoteRepository?
    let settings: ProviderSettings
    var showsHeader: Bool = true
    var title: String? = nil
    
    @State private var viewModel = RemoteRepositorySidebarViewModel()
    @State private var collapsedSectionIDs: Set<String> = []
    @Environment(\.dismiss) private var dismiss

    var debugPageMarkerItems: [PageMarkerItem] {
        remoteRepositorySidebarMarkerItems(selectedRepository: selectedRepository)
    }
    
    var body: some View {
        let sections = repositorySections(settings.remoteRepositories)
        let orderedRepositories = sections.flatMap { $0.repositories }
        VStack(spacing: 0) {
            if showsHeader {
                UISheetHeaderView(title: NSLocalizedString("Sources", comment: "Sources")) { EmptyView() }
                SheetDivider()
            } else if let title, !title.isEmpty {
                HStack(spacing: 12) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.Text.primary)
                    Spacer(minLength: 0)
                }
                .frame(height: 52)
                .padding(.horizontal, 16)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(DesignSystem.Colors.Component.separator)
                        .frame(height: 1)
                }
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
                },
                onRepositorySaved: { repo in
                    selectedRepository = repo
                }
            )
        }
        .sheet(isPresented: $viewModel.showingDirectoryPicker) {
            DirectoryPickerSheet(
                isPresented: $viewModel.showingDirectoryPicker,
                candidates: viewModel.detectedCandidates,
                selectedIndices: $viewModel.selectedDirectoryIndices,
                onConfirm: {
                    if let repo = viewModel.confirmDirectorySelection(settings: settings) {
                        selectedRepository = repo
                    }
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
                },
                onRepositorySaved: { savedRepo in
                    selectedRepository = savedRepo
                }
            )
        }
        .onAppear {
            if selectedRepository == nil {
                selectedRepository = orderedRepositories.first
            }
        }
        .task(id: settings.pendingImportURL) {
            if viewModel.shouldPresentAddRepositorySheet(for: settings.pendingImportURL) {
                viewModel.showingAddRepository = true
            }
        }
        .onDisappear {
            viewModel.cancelPendingTasks()
        }
        .debugPageMarkerContextMenu(debugPageMarkerItems, withDivider: false) {
            EmptyView()
        }
        .debugPageLocator(debugPageMarkerItems)

    }
    private func gitStatusRow(_ repo: RemoteRepository) -> some View {
        Group {
            if viewModel.isSyncing, viewModel.syncingRepositoryID == repo.id {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.Status.info)
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
        collapsedSectionIDs = GenericSelectionStateResolver.resolveMultiSelection(
            current: collapsedSectionIDs,
            tapped: section.id
        )
    }

    private func repositoryRow(_ repo: RemoteRepository) -> some View {
        HStack(alignment: .top, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                if let logoName = repo.logoName ?? repo.provider.logoName {
                    NolonUI.ProviderLogoView(name: repo.name, logoName: logoName, iconSize: 16)
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
                    Task {
                        await viewModel.removeRepository(repo, settings: settings)
                        selectedRepository = viewModel.selectedRepositoryAfterRemoving(
                            removedRepositoryIDs: [repo.id],
                            currentSelection: selectedRepository
                        )
                    }
                } label: {
                    Label("Remove", systemImage: "trash")
                        .dsIconLabelButton()
                }
            }

            debugPageMarkerMenuItem(
                remoteRepositorySidebarMarkerItems(selectedRepository: repo)
            )
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
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(DesignSystem.Colors.Status.info)
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
        var removedRepositoryIDs = Set<String>()
        for index in offsets {
            guard index < repos.count else { continue }
            let repo = repos[index]
            if !repo.isBuiltIn {
                settings.removeRemoteRepository(repo)
                removedRepositoryIDs.insert(repo.id)
            }
        }
        selectedRepository = viewModel.selectedRepositoryAfterRemoving(
            removedRepositoryIDs: removedRepositoryIDs,
            currentSelection: selectedRepository
        )
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

func remoteRepositorySidebarMarkerItems(selectedRepository: RemoteRepository?) -> [PageMarkerItem] {
    var items = [PageMarkerItem(title: "Repository Sidebar")]
    if let selectedRepository {
        items.append(PageMarkerItem(title: repositoryDisplayName(selectedRepository)))
    }
    return items
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
            UISheetHeaderView(title: NSLocalizedString("SSH Authentication Unavailable", comment: "SSH unavailable")) {
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
