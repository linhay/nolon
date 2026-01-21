import SwiftUI

/// Main skill management view with tabs
@MainActor
public struct SkillManagerView: View {
    @StateObject private var settings = ProviderSettings()
    @State private var repository = SkillRepository()
    @State private var installer: SkillInstaller
    @State private var skills: [Skill] = []
    @State private var searchText = ""
    @State private var selectedTab = 0

    public init() {
        let repo = SkillRepository()
        let settings = ProviderSettings()
        _repository = State(initialValue: repo)
        _settings = StateObject(wrappedValue: settings)
        _installer = State(initialValue: SkillInstaller(repository: repo, settings: settings))
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            SkillListView(
                skills: filteredSkills,
                repository: repository,
                installer: installer,
                onRefresh: loadSkills
            )
            .tabItem {
                Label(
                    NSLocalizedString("nav.all_skills", comment: "All Skills"),
                    systemImage: "square.stack.3d.up")
            }
            .tag(0)

            ProviderSkillsView(
                repository: repository,
                installer: installer,
                onRefresh: loadSkills
            )
            .tabItem {
                Label(
                    NSLocalizedString("nav.by_provider", comment: "By Provider"),
                    systemImage: "folder.badge.gearshape")
            }
            .tag(1)

            NavigationStack {
                ProviderSettingsView(settings: settings)
            }
            .tabItem {
                Label(NSLocalizedString("settings.title", comment: "Settings"), systemImage: "gear")
            }
            .tag(2)
        }
        .searchable(
            text: $searchText,
            prompt: Text(NSLocalizedString("nav.search_placeholder", comment: "Search skills"))
        )
        .task {
            await loadSkills()
        }
    }

    private var filteredSkills: [Skill] {
        if searchText.isEmpty {
            return skills
        }
        return skills.filter { $0.matches(query: searchText) }
    }

    private func loadSkills() async {
        do {
            skills = try repository.listSkills()
        } catch {
            print("Failed to load skills: \(error)")
        }
    }
}
