import SwiftUI

/// Left column 2: Skills list for the current provider
/// Shows skills with install/uninstall actions
@MainActor
public struct ProviderSkillsListView: View {
    let provider: SkillProvider?
    let customProvider: CustomProvider?
    @Binding var selectedSkill: Skill?
    @ObservedObject var settings: ProviderSettings
    
    @State private var repository = SkillRepository()
    @State private var installer: SkillInstaller?
    @State private var allSkills: [Skill] = []
    @State private var installedSkillIds: Set<String> = []
    @State private var searchText = ""
    @State private var errorMessage: String?
    
    /// Current provider name for display
    private var providerName: String {
        if let provider = provider {
            return provider.displayName
        } else if let customProvider = customProvider {
            return customProvider.displayName
        }
        return NSLocalizedString("skills_list.no_provider", comment: "Select a Provider")
    }
    
    public init(
        provider: SkillProvider?,
        customProvider: CustomProvider?,
        selectedSkill: Binding<Skill?>,
        settings: ProviderSettings
    ) {
        self.provider = provider
        self.customProvider = customProvider
        self._selectedSkill = selectedSkill
        self.settings = settings
    }
    
    public var body: some View {
        Group {
            if provider != nil || customProvider != nil {
                skillsListContent()
            } else {
                ContentUnavailableView(
                    NSLocalizedString("skills_list.no_provider", comment: "Select a Provider"),
                    systemImage: "sidebar.left",
                    description: Text(NSLocalizedString("skills_list.no_provider_desc", comment: "Choose a provider from the sidebar"))
                )
            }
        }
        .onAppear {
            installer = SkillInstaller(repository: repository, settings: settings)
        }
        .task(id: provider?.id ?? customProvider?.id ?? "") {
            await loadSkills()
        }
        .refreshable {
            await loadSkills()
        }
    }
    
    @ViewBuilder
    private func skillsListContent() -> some View {
        VStack(spacing: 0) {
            List(selection: $selectedSkill) {
                // Installed skills section
                let installed = installedSkills
                if !installed.isEmpty {
                    Section {
                        ForEach(installed) { skill in
                            SkillListRowView(
                                skill: skill,
                                isInstalled: true,
                                onInstall: { await installSkill(skill) },
                                onUninstall: { await uninstallSkill(skill) }
                            )
                            .tag(skill)
                        }
                    } header: {
                        Label(
                            NSLocalizedString("skills_list.installed", comment: "Installed"),
                            systemImage: "checkmark.circle.fill"
                        )
                    }
                }
                
                // Available skills section
                let available = availableSkills
                if !available.isEmpty {
                    Section {
                        ForEach(available) { skill in
                            SkillListRowView(
                                skill: skill,
                                isInstalled: false,
                                onInstall: { await installSkill(skill) },
                                onUninstall: { await uninstallSkill(skill) }
                            )
                            .tag(skill)
                        }
                    } header: {
                        Label(
                            NSLocalizedString("skills_list.available", comment: "Available"),
                            systemImage: "square.dashed"
                        )
                    }
                }
            }
            .listStyle(.inset)
            .searchable(
                text: $searchText,
                prompt: Text(NSLocalizedString("skills_list.search", comment: "Search skills"))
            )
        }
        .navigationTitle(providerName)
        .alert(
            NSLocalizedString("generic.error", comment: "Error"),
            isPresented: .constant(errorMessage != nil)
        ) {
            Button(NSLocalizedString("generic.ok", comment: "OK")) { errorMessage = nil }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }
    
    private var filteredSkills: [Skill] {
        if searchText.isEmpty {
            return allSkills
        }
        return allSkills.filter { $0.matches(query: searchText) }
    }
    
    private var installedSkills: [Skill] {
        filteredSkills.filter { installedSkillIds.contains($0.id) }
    }
    
    private var availableSkills: [Skill] {
        filteredSkills.filter { !installedSkillIds.contains($0.id) }
    }
    
    private func loadSkills() async {
        do {
            allSkills = try repository.listSkills()
            
            // Determine installed skills based on provider type
            if let provider = provider {
                installedSkillIds = Set(allSkills.filter { $0.isInstalledFor(provider) }.map(\.id))
            } else if let customProvider = customProvider, let installer = installer {
                // Scan custom provider directory
                let states = try installer.scanCustomProvider(customProvider: customProvider)
                installedSkillIds = Set(states.filter { $0.state == .installed }.map(\.skillName))
            } else {
                installedSkillIds = []
            }
            
            // Auto-select first skill if none selected
            if selectedSkill == nil, let first = allSkills.first {
                selectedSkill = first
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func installSkill(_ skill: Skill) async {
        guard let installer = installer else { return }
        do {
            if let provider = provider {
                try installer.install(skill: skill, to: provider)
            } else if let customProvider = customProvider {
                try installer.installToCustomProvider(skill: skill, customProvider: customProvider)
            }
            await loadSkills()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func uninstallSkill(_ skill: Skill) async {
        guard let installer = installer else { return }
        do {
            if let provider = provider {
                try installer.uninstall(skill: skill, from: provider)
            } else if let customProvider = customProvider {
                try installer.uninstallFromCustomProvider(skill: skill, customProvider: customProvider)
            }
            await loadSkills()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Row view for a skill in the list
struct SkillListRowView: View {
    let skill: Skill
    let isInstalled: Bool
    let onInstall: () async -> Void
    let onUninstall: () async -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(skill.name)
                    .font(.headline)
                
                Text(skill.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if isInstalled {
                Button {
                    Task { await onUninstall() }
                } label: {
                    Text(NSLocalizedString("action.uninstall", comment: "Uninstall"))
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .controlSize(.small)
            } else {
                Button {
                    Task { await onInstall() }
                } label: {
                    Text(NSLocalizedString("action.install", comment: "Install"))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .contentShape(Rectangle())
    }
}
