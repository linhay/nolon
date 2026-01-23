import SwiftUI

/// Left column 2: Skills list for the current provider
/// Shows skills with install/uninstall actions
@MainActor
public struct ProviderSkillsListView: View {
    @State private var viewModel: ProviderSkillsListViewModel
    @Binding var selectedSkill: Skill?
    
    /// External trigger to force refresh (increment to reload)
    var refreshTrigger: Int
    
    var provider: Provider?
    
    public init(
        provider: Provider?,
        selectedSkill: Binding<Skill?>,
        settings: ProviderSettings,
        refreshTrigger: Int = 0
    ) {
        self.provider = provider
        self._selectedSkill = selectedSkill
        self.refreshTrigger = refreshTrigger
        let vm = ProviderSkillsListViewModel(provider: provider, settings: settings)
        self._viewModel = State(initialValue: vm)
    }
    
    public var body: some View {
        Group {
            if viewModel.provider != nil {
                skillsListContent()
            } else {
                ContentUnavailableView(
                    NSLocalizedString("skills_list.no_provider", comment: "Select a Provider"),
                    systemImage: "sidebar.left",
                    description: Text(
                        NSLocalizedString(
                            "skills_list.no_provider_desc",
                            comment: "Choose a provider from the sidebar"))
                )
            }
        }
        .task(id: "\(viewModel.provider?.id ?? "")-\(refreshTrigger)") {
            await viewModel.loadSkills()
            if selectedSkill == nil, let first = viewModel.allSkills.first {
                selectedSkill = first
            }
        }
        .onChange(of: provider) { _, newProvider in
            Task {
                await viewModel.updateProvider(newProvider)
            }
        }
        .refreshable {
            await viewModel.loadSkills()
        }
        .alert(
            NSLocalizedString(
                "confirm.delete_title", value: "Delete Skill?", comment: "Delete Skill?"),
            isPresented: $viewModel.showingDeleteAlert,
            presenting: viewModel.skillToDelete
        ) { skill in
            Button(NSLocalizedString("action.delete", comment: "Delete"), role: .destructive) {
                viewModel.performDelete(skill)
            }
            Button(NSLocalizedString("generic.cancel", comment: "Cancel"), role: .cancel) {}
        } message: { skill in
            Text(
                String(
                    format: NSLocalizedString(
                        "confirm.delete_message",
                        value:
                            "Are you sure you want to delete '%@'? This action cannot be undone.",
                        comment: "Delete confirmation"), skill.name))
        }
        .alert(
            NSLocalizedString(
                "confirm.migrate_conflict_title", value: "Skill Already Exists",
                comment: "Migration conflict title"),
            isPresented: $viewModel.showingConflictAlert,
            presenting: viewModel.conflictingSkillState
        ) { skillState in
            Button(
                NSLocalizedString("action.overwrite", comment: "Overwrite"), role: .destructive
            ) {
                Task {
                    await viewModel.migrateSkillWithOverwrite(skillState)
                }
            }
            Button(NSLocalizedString("generic.cancel", comment: "Cancel"), role: .cancel) {}
        } message: { skillState in
            Text(
                String(
                    format: NSLocalizedString(
                        "confirm.migrate_conflict_message",
                        value:
                            "'%@' already exists in global storage with a different version. Overwrite with the provider version?",
                        comment: "Migration conflict message"), skillState.skillName))
        }
    }

    @ViewBuilder
    private func skillsListContent() -> some View {
        VStack(spacing: 0) {
            List(selection: $selectedSkill) {
                // Installed skills section
                let installed = viewModel.installedSkills
                if !installed.isEmpty {
                    Section {
                        ForEach(installed) { skill in
                            SkillListRowView(
                                skill: skill,
                                isInstalled: true,
                                providerPath: viewModel.provider?.skillsPath,
                                canDelete: viewModel.provider?.installMethod == .copy,
                                onInstall: { await viewModel.installSkill(skill) },
                                onUninstall: { await viewModel.uninstallSkill(skill) },
                                onDelete: { viewModel.confirmDelete(skill) }
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
                let available = viewModel.availableSkills
                if !available.isEmpty {
                    Section {
                        ForEach(available) { skill in
                            SkillListRowView(
                                skill: skill,
                                isInstalled: false,
                                providerPath: nil,
                                canDelete: true,
                                onInstall: { await viewModel.installSkill(skill) },
                                onUninstall: { await viewModel.uninstallSkill(skill) },
                                onDelete: { viewModel.confirmDelete(skill) }
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

                // Existing (orphaned) skills section - skills in provider not managed by app
                let orphaned = viewModel.filteredOrphanedSkills
                if !orphaned.isEmpty {
                    Section {
                        ForEach(orphaned, id: \.skillName) { skillState in
                            OrphanedSkillRowView(
                                skillState: skillState,
                                onMigrate: { await viewModel.migrateSkill(skillState) },
                                onReveal: { viewModel.revealInFinder(skillState.path) }
                            )
                        }
                    } header: {
                        Label(
                            NSLocalizedString("skills_list.existing", comment: "Existing"),
                            systemImage: "folder.badge.questionmark"
                        )
                    }
                }
                
                // Broken skills section
                let broken = viewModel.filteredBrokenSkills
                if !broken.isEmpty {
                    Section {
                        ForEach(broken, id: \.skillName) { skillState in
                            BrokenSkillRowView(
                                skillState: skillState,
                                onRepair: { await viewModel.repairSymlink(skillState) },
                                onUninstall: { await viewModel.uninstallBrokenSkill(skillState) },
                                onReveal: { viewModel.revealInFinder(skillState.path) }
                            )
                        }
                    } header: {
                        Label(
                            NSLocalizedString("skills_list.broken", value: "Broken Links", comment: "Broken Links"),
                            systemImage: "exclamationmark.triangle.fill"
                        )
                    }
                }
            }
            .listStyle(.inset)
            .searchable(
                text: $viewModel.searchText,
                prompt: Text(NSLocalizedString("skills_list.search", comment: "Search skills"))
            )
        }
        .navigationTitle(viewModel.providerName)
        .alert(
            NSLocalizedString("generic.error", comment: "Error"),
            isPresented: .constant(viewModel.errorMessage != nil)
        ) {
            Button(NSLocalizedString("generic.ok", comment: "OK")) { viewModel.errorMessage = nil }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }


}

/// Row view for a skill in the list
struct SkillListRowView: View {
    let skill: Skill
    let isInstalled: Bool
    let providerPath: String?
    let canDelete: Bool
    let onInstall: () async -> Void
    let onUninstall: () async -> Void
    let onDelete: () -> Void

    /// Path to show in Finder - provider path for installed, global path for available
    private var revealPath: String {
        if isInstalled, let providerPath = providerPath {
            return (providerPath as NSString).appendingPathComponent(skill.name)
        }
        return skill.globalPath
    }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(skill.name)
                        .font(.headline)
                    if isInstalled {
                        SkillInstalledBadge()
                    }
                }

                Text(skill.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack {
                    if skill.hasReferences || skill.hasScripts {
                        HStack(spacing: 12) {
                            if skill.hasReferences {
                                Label("\(skill.referenceCount)", systemImage: "doc.text")
                            }
                            if skill.hasScripts {
                                Label("\(skill.scriptCount)", systemImage: "terminal")
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    SkillVersionBadge(version: skill.version)
                }
            }

            Menu {
                // 1. Install / Uninstall
                if isInstalled {
                    Button {
                        Task { await onUninstall() }
                    } label: {
                        Label(
                            NSLocalizedString("action.uninstall", comment: "Uninstall"),
                            systemImage: "trash")
                    }
                } else {
                    Button {
                        Task { await onInstall() }
                    } label: {
                        Label(
                            NSLocalizedString("action.install", comment: "Install"),
                            systemImage: "plus")
                    }
                }

                // 2. Reveal in Finder
                Button {
                    NSWorkspace.shared.selectFile(revealPath, inFileViewerRootedAtPath: "")
                } label: {
                    Label(
                        NSLocalizedString(
                            "detail.open_folder", value: "Reveal in Finder",
                            comment: "Open in Finder"), systemImage: "folder")
                }

                if canDelete {
                    Divider()

                    // 3. Delete
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label(
                            NSLocalizedString("action.delete", comment: "Delete"),
                            systemImage: "xmark.bin")
                    }
                }

            } label: {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .contentShape(Rectangle())
        .contextMenu {
            // 1. Install / Uninstall
            if isInstalled {
                Button {
                    Task { await onUninstall() }
                } label: {
                    Label(
                        NSLocalizedString("action.uninstall", comment: "Uninstall"),
                        systemImage: "trash")
                }
            } else {
                Button {
                    Task { await onInstall() }
                } label: {
                    Label(
                        NSLocalizedString("action.install", comment: "Install"),
                        systemImage: "plus")
                }
            }

            // 2. Reveal in Finder
            Button {
                NSWorkspace.shared.selectFile(revealPath, inFileViewerRootedAtPath: "")
            } label: {
                Label(
                    NSLocalizedString(
                        "detail.open_folder", value: "Reveal in Finder",
                        comment: "Open in Finder"), systemImage: "folder")
            }

            if canDelete {
                Divider()

                // 3. Delete
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label(
                        NSLocalizedString("action.delete", comment: "Delete"),
                        systemImage: "xmark.bin")
                }
            }
        }
    }
}

/// Row view for an orphaned skill (existing in provider but not managed by app)
struct OrphanedSkillRowView: View {
    let skillState: ProviderSkillState
    let onMigrate: () async -> Void
    let onReveal: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(skillState.skillName)
                        .font(.headline)

                    Text(
                        NSLocalizedString(
                            "skills_list.orphaned_badge", value: "Unmanaged",
                            comment: "Orphaned skill badge")
                    )
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange)
                    .cornerRadius(4)
                }

                Text(
                    NSLocalizedString("skills_list.existing_desc", comment: "Not managed by nolon")
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }

            Spacer()

            Menu {
                // 1. Migrate to global storage
                Button {
                    Task { await onMigrate() }
                } label: {
                    Label(
                        NSLocalizedString("action.migrate", comment: "Migrate"),
                        systemImage: "arrow.up.doc")
                }

                // 2. Reveal in Finder
                Button {
                    onReveal()
                } label: {
                    Label(
                        NSLocalizedString(
                            "detail.open_folder", value: "Reveal in Finder",
                            comment: "Open in Finder"), systemImage: "folder")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .contentShape(Rectangle())
        .contextMenu {
            // 1. Migrate to global storage
            Button {
                Task { await onMigrate() }
            } label: {
                Label(
                    NSLocalizedString("action.migrate", comment: "Migrate"),
                    systemImage: "arrow.up.doc")
            }

            // 2. Reveal in Finder
            Button {
                onReveal()
            } label: {
                Label(
                    NSLocalizedString(
                        "detail.open_folder", value: "Reveal in Finder",
                        comment: "Open in Finder"), systemImage: "folder")
            }
        }
    }
}

/// Row view for a broken skill link
struct BrokenSkillRowView: View {
    let skillState: ProviderSkillState
    let onRepair: () async -> Void
    let onUninstall: () async -> Void
    let onReveal: () -> Void
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(skillState.skillName)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Text(NSLocalizedString("skills_list.broken_badge", value: "Broken", comment: "Broken"))
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .cornerRadius(4)
                }
                
                Text(NSLocalizedString("skills_list.broken_desc", value: "Link destination not found", comment: "Link broken"))
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Menu {
                // 1. Repair
                Button {
                    Task { await onRepair() }
                } label: {
                    Label(NSLocalizedString("action.repair", value: "Repair", comment: "Repair"), systemImage: "wrench.and.screwdriver")
                }
                
                // 2. Reveal in Finder
                Button {
                    onReveal()
                } label: {
                    Label(NSLocalizedString("detail.open_folder", value: "Reveal in Finder", comment: "Reveal"), systemImage: "folder")
                }
                
                Divider()
                
                // 3. Uninstall (Remove Link)
                Button(role: .destructive) {
                    Task { await onUninstall() }
                } label: {
                    Label(NSLocalizedString("action.remove_link", value: "Remove Link", comment: "Remove Link"), systemImage: "trash")
                }
            } label: {
                Image(systemName: "exclamationmark.circle")
                    .font(.title2)
                    .foregroundStyle(.red)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                Task { await onRepair() }
            } label: {
                Label(NSLocalizedString("action.repair", value: "Repair", comment: "Repair"), systemImage: "wrench.and.screwdriver")
            }
            
            Button {
                onReveal()
            } label: {
                Label(NSLocalizedString("detail.open_folder", value: "Reveal in Finder", comment: "Reveal"), systemImage: "folder")
            }
            
            Button(role: .destructive) {
                Task { await onUninstall() }
            } label: {
                Label(NSLocalizedString("action.remove_link", value: "Remove Link", comment: "Remove Link"), systemImage: "trash")
            }
        }
    }
}
