import SwiftUI
import Observation

@Observable
final class RemoteSkillsContentViewModel {
    var skills: [RemoteSkill] = []
    // var searchText = ""  <-- Removed
    var isLoading = false
    var errorMessage: String?
    
    private var searchTask: Task<Void, Never>?
    
    @MainActor
    func loadSkills(for repository: RemoteRepository?, searchText: String = "") async {
        guard let repository = repository else {
            skills = []
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            switch repository.templateType {
            case .clawdhub:
                // Use ClawdhubService for API-based repositories
                let service = ClawdhubService(baseURL: repository.baseURL)
                skills = try await service.fetchSkills(query: searchText.isEmpty ? nil : searchText)
                
            case .localFolder, .git, .globalSkills:
                let paths = repository.effectiveSkillsPaths
                guard !paths.isEmpty else {
                    throw LocalFolderError.pathNotFound("No path configured")
                }
                
                if repository.templateType == .git {
                    let gitService = GitRepositoryService.shared
                    if await !gitService.isCloned(repository) {
                        let result = try await gitService.syncRepository(repository)
                        if !result.success {
                            throw LocalFolderError.cannotReadDirectory(result.message)
                        }
                    }
                }
                
                let localService = LocalFolderService()
                var allSkills = try await localService.fetchSkills(fromPaths: paths)
                
                // Filter by search text if provided
                if !searchText.isEmpty {
                    let searchLower = searchText.lowercased()
                    allSkills = allSkills.filter { skill in
                        skill.displayName.lowercased().contains(searchLower)
                        || (skill.summary?.lowercased().contains(searchLower) ?? false)
                    }
                }
                
                skills = allSkills
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    @MainActor
    func handleSearchTextChange(text: String, repository: RemoteRepository?) {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await loadSkills(for: repository, searchText: text)
        }
    }
}

/// Left column 2: Skills list within selected repository
struct RemoteSkillsContentView: View {
    let repository: RemoteRepository?
    @Binding var selectedSkill: RemoteSkill?
    @Binding var searchText: String
    
    /// Set of installed skill slugs for marking already installed skills
    let installedSlugs: Set<String>
    
    @State private var viewModel = RemoteSkillsContentViewModel()
    
    var body: some View {
        Group {
            if let repository = repository {
                skillsList(for: repository)
            } else {
                ContentUnavailableView(
                    "Select a Repository",
                    systemImage: "tray",
                    description: Text("Choose a repository from the sidebar")
                )
            }
        }
        .onChange(of: repository) { _, newValue in
            if newValue != nil {
                Task { await viewModel.loadSkills(for: newValue) }
            } else {
                // We don't reset viewModel.skills here because loadSkills(nil) clears it
                // But passing nil to loadSkills checks guard first. 
                // Wait, loadSkills(nil) does clear skills.
                Task { await viewModel.loadSkills(for: nil) }
                selectedSkill = nil
            }
        }
    }
    
    private func skillsList(for repository: RemoteRepository) -> some View {
        List(selection: $selectedSkill) {
            if viewModel.isLoading && viewModel.skills.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowSeparator(.hidden)
            } else if let error = viewModel.errorMessage {
                ContentUnavailableView(
                    "Failed to load skills",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
                .listRowSeparator(.hidden)
                if !searchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                        .listRowSeparator(.hidden)
                } else if viewModel.skills.isEmpty {
                    ContentUnavailableView(
                        "No Skills",
                        systemImage: "tray",
                        description: Text("This repository has no skills yet")
                    )
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(viewModel.skills) { skill in
                        RemoteSkillRowView(
                            skill: skill,
                            isInstalled: installedSlugs.contains(skill.slug)
                        )
                        .tag(skill)
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(repository.name)
        .onChange(of: searchText) { _, newValue in
            viewModel.handleSearchTextChange(text: newValue, repository: repository)
        }
        .refreshable {
            await viewModel.loadSkills(for: repository)
        }
        .task {
            // Initial load
            if viewModel.skills.isEmpty {
                await viewModel.loadSkills(for: repository)
            }
        }
    }
}
