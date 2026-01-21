import SwiftUI

/// Left column 2: Skills list within selected repository
struct RemoteSkillsContentView: View {
    let repository: RemoteRepository?
    @Binding var selectedSkill: RemoteSkill?

    /// Set of installed skill slugs for marking already installed skills
    let installedSlugs: Set<String>

    @State private var skills: [RemoteSkill] = []
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?

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
                Task { await loadSkills() }
            } else {
                skills = []
                selectedSkill = nil
            }
        }
    }

    private func skillsList(for repository: RemoteRepository) -> some View {
        List(selection: $selectedSkill) {
            if isLoading && skills.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowSeparator(.hidden)
            } else if let error = errorMessage {
                ContentUnavailableView(
                    "Failed to load skills",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
                .listRowSeparator(.hidden)
            } else if skills.isEmpty && !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .listRowSeparator(.hidden)
            } else if skills.isEmpty {
                ContentUnavailableView(
                    "No Skills",
                    systemImage: "tray",
                    description: Text("This repository has no skills yet")
                )
                .listRowSeparator(.hidden)
            } else {
                ForEach(skills) { skill in
                    RemoteSkillRowView(
                        skill: skill,
                        isInstalled: installedSlugs.contains(skill.slug)
                    )
                    .tag(skill)
                }
            }
        }
        .listStyle(.plain)
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search \(repository.name)")
        .navigationTitle(repository.name)
        .onChange(of: searchText) { _, newValue in
            searchTask?.cancel()
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                await loadSkills()
            }
        }
        .refreshable {
            await loadSkills()
        }
        .task {
            await loadSkills()
        }
    }

    private func loadSkills() async {
        guard let repository = repository else { return }

        isLoading = true
        errorMessage = nil

        do {
            // Create a service instance for the selected repository
            let service = ClawdhubService(baseURL: repository.baseURL)
            skills = try await service.fetchSkills(query: searchText.isEmpty ? nil : searchText)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
