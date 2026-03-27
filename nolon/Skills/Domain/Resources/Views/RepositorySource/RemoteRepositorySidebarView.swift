import SwiftUI
import STFilePath
import NolonResourceKit
import NolonUI
import NolonUIFoundation

/// Left column 1: Repository sidebar with list and add button
struct RemoteRepositorySidebarView: View, DebugPageLocatable {
    @Binding var selectedRepository: RemoteRepository?
    let settings: ProviderSettings
    var showsHeader: Bool = true
    var title: String? = NSLocalizedString("resource.center.title", value: "Resource Center", comment: "Resource center title")
    
    @State private var viewModel = RemoteRepositorySidebarViewModel()
    @State private var collapsedSectionIDs: Set<String> = []
    @Environment(\.dismiss) private var dismiss

    var debugPageMarkerItems: [PageMarkerItem] {
        remoteRepositorySidebarMarkerItems(selectedRepository: selectedRepository)
    }
    
    var body: some View {
        let sections = repositorySections(settings.remoteRepositories)
        let orderedRepositories = sections.flatMap { $0.repositories }
        let sectionData = repositorySectionData(sections)
        NolonUI.RepositorySidebarScaffoldView(
            showsHeader: showsHeader,
            sidebarTitle: title,
            selectedRowID: selectedRepositoryIDBinding(orderedRepositories: orderedRepositories),
            sections: sectionData,
            collapsedSectionIDs: collapsedSectionIDs,
            isSyncing: viewModel.isSyncing,
            syncingRepositoryName: viewModel.syncingRepositoryName,
            syncCompletionMessage: viewModel.syncCompletionMessage,
            syncCompletionRepositoryName: viewModel.syncCompletionRepositoryName,
            syncCompletionTone: viewModel.syncCompletionStyle == .failure ? .failure : .success,
            onToggleSection: { sectionID in
                toggleSection(withID: sectionID)
            },
            onDeleteRows: { sectionID, offsets in
                guard let section = sections.first(where: { $0.id == sectionID }) else { return }
                deleteRepositories(offsets, in: section.repositories)
            },
            onTapAddButton: {
                viewModel.showingAddRepository = true
            }
        ) { rowData in
            if let repo = orderedRepositories.first(where: { $0.id == rowData.id }) {
                repositoryContextMenu(for: repo)
            } else {
                EmptyView()
            }
        }
        .repositorySidebarSheetPresenters(
            isAddingRepositoryPresented: $viewModel.showingAddRepository,
            addRepositorySheet: {
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
        },
            isDirectoryPickerPresented: $viewModel.showingDirectoryPicker,
            directoryPickerSheet: {
            NolonUI.DirectoryPickerSheetView(
                viewModel: NolonUI.DirectoryPickerSheetViewModel(
                    data: .init(
                        candidates: Array(viewModel.detectedCandidates.enumerated()).map { index, candidate in
                            DirectoryPickerCandidateInfo(
                                id: index,
                                path: candidate.path,
                                skillCount: candidate.skillCount,
                                skillNames: candidate.skillNames
                            )
                        }
                    ),
                    selectedIDs: viewModel.selectedDirectoryIndices,
                    onConfirm: { selectedIDs in
                        viewModel.selectedDirectoryIndices = selectedIDs
                        if let repo = viewModel.confirmDirectorySelection(settings: settings) {
                            selectedRepository = repo
                        }
                        viewModel.showingDirectoryPicker = false
                    },
                    onCancel: {
                        viewModel.showingDirectoryPicker = false
                    }
                )
            )
        },
            isTokenInputPresented: $viewModel.showingTokenInput,
            tokenInputSheet: {
            NolonUI.TokenInputSheetView(
                isPresented: $viewModel.showingTokenInput,
                host: viewModel.tokenInputHost,
                token: $viewModel.inputToken,
                onConfirm: {
                    viewModel.confirmTokenInput(settings: settings)
                }
            )
        },
            editingItem: $viewModel.editingRepository,
            editRepositorySheet: { repo in
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
        })
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

    private func selectedRepositoryIDBinding(orderedRepositories: [RemoteRepository]) -> Binding<String?> {
        Binding<String?>(
            get: { selectedRepository?.id },
            set: { selectedID in
                selectedRepository = orderedRepositories.first(where: { $0.id == selectedID })
            }
        )
    }

    private func toggleSection(withID sectionID: String) {
        collapsedSectionIDs = GenericSelectionStateResolver.resolveMultiSelection(
            current: collapsedSectionIDs,
            tapped: sectionID
        )
    }

    private func repositorySectionData(_ sections: [RepositorySection]) -> [RepositorySidebarSectionData] {
        sections.map { section in
            RepositorySidebarSectionData(
                id: section.id,
                title: section.title,
                rows: section.repositories.map(repositoryRowData(for:))
            )
        }
    }

    @ViewBuilder
    private func repositoryContextMenu(for repo: RemoteRepository) -> some View {
        NolonUI.RepositoryRowContextMenuView(
            onSync: repo.templateType == .git ? {
                Task { await viewModel.syncRepository(repo, settings: settings) }
            } : nil,
            onRevealInFinder: (repo.templateType == .localFolder || repo.templateType == .git || repo.templateType == .globalSkills) ? {
                viewModel.revealInFinder(repo)
            } : nil,
            onEdit: !repo.isBuiltIn ? {
                viewModel.editingRepository = repo
            } : nil,
            onRemove: !repo.isBuiltIn ? {
                Task {
                    await viewModel.removeRepository(repo, settings: settings)
                    selectedRepository = viewModel.selectedRepositoryAfterRemoving(
                        removedRepositoryIDs: [repo.id],
                        currentSelection: selectedRepository
                    )
                }
            } : nil
        ) {
            debugPageMarkerMenuItem(
                remoteRepositorySidebarMarkerItems(selectedRepository: repo)
            )
        }
    }

    private func repositoryRowData(for repo: RemoteRepository) -> RepositorySidebarRowData {
        RepositorySidebarRowData(
            id: repo.id,
            title: repositoryDisplayName(repo),
            secondaryText: repositorySecondaryLine(repo),
            logoName: repo.logoName ?? repo.provider.logoName,
            fallbackSystemIconName: repo.iconName,
            showGitStatus: repo.templateType == .git,
            syncStatus: syncStatusData(for: repo),
            isBuiltIn: repo.isBuiltIn
        )
    }

    private func syncStatusData(for repo: RemoteRepository) -> RepositorySyncStatusData? {
        guard repo.templateType == .git else { return nil }
        if viewModel.isSyncing, viewModel.syncingRepositoryID == repo.id {
            return .syncing
        }
        if let syncDate = repo.lastSyncDate {
            return .lastSynced(syncDate)
        }
        return .notSyncedDefault()
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
                    repositoryDisplayName(lhs)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .lowercased()
                        .localizedStandardCompare(
                            repositoryDisplayName(rhs)
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                                .lowercased()
                        ) == .orderedAscending
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
