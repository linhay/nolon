import SwiftUI

/// Top-right toolbar: Global skills popover
/// Shows all global skills with option to install to current provider
@MainActor
public struct GlobalSkillsPopover: View {
    let currentProvider: SkillProvider?
    let customProvider: CustomProvider?
    @ObservedObject var settings: ProviderSettings
    let onInstall: (Skill) async -> Void
    let onDismiss: () -> Void
    
    @State private var repository = SkillRepository()
    @State private var installer: SkillInstaller?
    @State private var skills: [Skill] = []
    @State private var installedSkillIds: Set<String> = []
    @State private var searchText = ""
    @State private var errorMessage: String?
    
    /// Current provider name for display
    private var currentProviderName: String? {
        if let provider = currentProvider {
            return provider.displayName
        } else if let customProvider = customProvider {
            return customProvider.displayName
        }
        return nil
    }
    
    public init(
        currentProvider: SkillProvider?,
        customProvider: CustomProvider?,
        settings: ProviderSettings,
        onInstall: @escaping (Skill) async -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.currentProvider = currentProvider
        self.customProvider = customProvider
        self.settings = settings
        self.onInstall = onInstall
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        NavigationStack {
            Group {
                if skills.isEmpty {
                    ContentUnavailableView(
                        NSLocalizedString("global.empty", comment: "No Skills"),
                        systemImage: "square.stack.3d.up.slash",
                        description: Text(NSLocalizedString("global.empty_desc", comment: "Import skills to get started"))
                    )
                } else {
                    List {
                        ForEach(filteredSkills) { skill in
                            GlobalSkillRowView(
                                skill: skill,
                                currentProviderName: currentProviderName,
                                isInstalled: installedSkillIds.contains(skill.id),
                                onInstall: {
                                    Task {
                                        await onInstall(skill)
                                        await loadSkills()
                                    }
                                }
                            )
                        }
                    }
                    .searchable(
                        text: $searchText,
                        prompt: Text(NSLocalizedString("global.search", comment: "Search skills"))
                    )
                }
            }
            .navigationTitle(NSLocalizedString("global.title", comment: "Global Skills"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("generic.close", comment: "Close")) {
                        onDismiss()
                    }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 500)
        .onAppear {
            installer = SkillInstaller(repository: repository, settings: settings)
        }
        .task {
            await loadSkills()
        }
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
            return skills
        }
        return skills.filter { $0.matches(query: searchText) }
    }
    
    private func loadSkills() async {
        do {
            skills = try repository.listSkills()
            
            // Determine installed skills based on provider type
            if let provider = currentProvider {
                installedSkillIds = Set(skills.filter { $0.isInstalledFor(provider) }.map(\.id))
            } else if let customProvider = customProvider, let installer = installer {
                let states = try installer.scanCustomProvider(customProvider: customProvider)
                installedSkillIds = Set(states.filter { $0.state == .installed }.map(\.skillName))
            } else {
                installedSkillIds = []
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Row view for a skill in the global skills popover
struct GlobalSkillRowView: View {
    let skill: Skill
    let currentProviderName: String?
    let isInstalled: Bool
    let onInstall: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(skill.name)
                        .font(.headline)
                    
                    Text("v\(skill.version)")
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
                
                Text(skill.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                
                // Show installed providers
                if !skill.installedProviders.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(skill.installedProviders).prefix(3), id: \.self) { provider in
                            Text(provider.displayName)
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.1))
                                .foregroundStyle(.green)
                                .cornerRadius(4)
                        }
                        
                        if skill.installedProviders.count > 3 {
                            Text("+\(skill.installedProviders.count - 3)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            if let providerName = currentProviderName {
                if isInstalled {
                    Label(
                        NSLocalizedString("status.installed", comment: "Installed"),
                        systemImage: "checkmark.circle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.green)
                } else {
                    Button {
                        onInstall()
                    } label: {
                        Label(
                            String(format: NSLocalizedString("global.install_to", comment: "Install to %@"), providerName),
                            systemImage: "plus.circle"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            } else {
                Text(NSLocalizedString("global.select_provider", comment: "Select a provider first"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
