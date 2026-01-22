import SwiftUI
import Observation

@MainActor
@Observable
class RemoteSkillListViewModel {
    
    var skills: [RemoteSkill] = []
    var searchText = ""
    var isLoading = false
    var errorMessage: String?
    var selectedSkill: RemoteSkill?
    
    private let service: ClawdhubService
    
    init(service: ClawdhubService = .shared) {
        self.service = service
    }
    
    func search() async {
        isLoading = true
        errorMessage = nil
        do {
            skills = try await service.fetchSkills(query: searchText)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct RemoteSkillListView: View {
    @State private var viewModel: RemoteSkillListViewModel
    
    // Injectable for preview or testing
    let providers: [Provider]
    let onInstall: (RemoteSkill, Provider) -> Void

    init(service: ClawdhubService = .shared, providers: [Provider], onInstall: @escaping (RemoteSkill, Provider) -> Void) {
        self._viewModel = State(initialValue: RemoteSkillListViewModel(service: service))
        self.providers = providers
        self.onInstall = onInstall
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $viewModel.selectedSkill) {
                if viewModel.isLoading && viewModel.skills.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if let error = viewModel.errorMessage {
                    ContentUnavailableView(
                        "Failed to load skills",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else if viewModel.skills.isEmpty && !viewModel.searchText.isEmpty {
                    ContentUnavailableView.search(text: viewModel.searchText)
                } else {
                    ForEach(viewModel.skills) { skill in
                        NavigationLink(value: skill) {
                            RemoteSkillRowView(skill: skill)
                        }
                    }
                }
            }
            .searchable(text: $viewModel.searchText, placement: .sidebar, prompt: "Search Clawdhub")
            .navigationTitle("Clawdhub")
            .onSubmit(of: .search) {
                Task { await viewModel.search() }
            }
            .task(id: viewModel.searchText) {
                // Debounce simple implementation
                try? await Task.sleep(nanoseconds: 500_000_000)
                await viewModel.search()
            }
            .refreshable {
                await viewModel.search()
            }
        } detail: {
            if let skill = viewModel.selectedSkill {
                RemoteSkillDetailView(
                    skill: skill, providers: providers,
                    onInstall: { provider in
                        onInstall(skill, provider)
                    })
            } else {
                ContentUnavailableView(
                    "Select a skill",
                    systemImage: "square.grid.2x2",
                    description: Text("Browse and install skills from Clawdhub")
                )
            }
        }
    }
}

struct RemoteSkillRowView: View {
    let skill: RemoteSkill
    var isInstalled: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(skill.displayName)
                    .font(.headline)
                if isInstalled {
                    SkillInstalledBadge()
                }
            }
            if let summary = skill.summary {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            HStack {
                if let stars = skill.stats?.stars {
                    Label("\(stars)", systemImage: "star.fill")
                        .foregroundStyle(.yellow)
                }
                if let downloads = skill.stats?.downloads {
                    Label("\(downloads)", systemImage: "arrow.down.circle")
                }
                Spacer()
                if let version = skill.latestVersion?.version {
                    SkillVersionBadge(version: version)
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }
}
