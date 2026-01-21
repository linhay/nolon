import SwiftUI

struct RemoteSkillListView: View {
    @State private var skills: [RemoteSkill] = []
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedSkill: RemoteSkill?

    // Injectable for preview or testing
    var service: ClawdhubService = .shared
    let providers: [Provider]
    let onInstall: (RemoteSkill, Provider) -> Void

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSkill) {
                if isLoading && skills.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if let error = errorMessage {
                    ContentUnavailableView(
                        "Failed to load skills",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else if skills.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ForEach(skills) { skill in
                        NavigationLink(value: skill) {
                            RemoteSkillRowView(skill: skill)
                        }
                    }
                }
            }
            .searchable(text: $searchText, placement: .sidebar, prompt: "Search Clawdhub")
            .navigationTitle("Clawdhub")
            .onSubmit(of: .search) {
                Task { await search() }
            }
            .task(id: searchText) {
                // Debounce simple implementation
                try? await Task.sleep(nanoseconds: 500_000_000)
                await search()
            }
            .refreshable {
                await search()
            }
        } detail: {
            if let skill = selectedSkill {
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

    private func search() async {
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

struct RemoteSkillRowView: View {
    let skill: RemoteSkill
    var isInstalled: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(skill.displayName)
                    .font(.headline)
                if isInstalled {
                    Text("Installed")
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green)
                        .cornerRadius(4)
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
                    Text("v\(version)")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
