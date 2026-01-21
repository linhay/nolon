import SwiftUI

/// Left column 2: Skills list for the current provider
/// Shows skills with install/uninstall actions
@MainActor
public struct ProviderSkillsListView: View {
    let provider: Provider?
    @Binding var selectedSkill: Skill?
    @ObservedObject var settings: ProviderSettings

    /// External trigger to force refresh (increment to reload)
    var refreshTrigger: Int = 0

    @State private var repository = SkillRepository()
    @State private var installer: SkillInstaller?
    @State private var allSkills: [Skill] = []
    @State private var installedSkillIds: Set<String> = []
    @State private var orphanedSkillStates: [ProviderSkillState] = []
    @State private var searchText = ""
    @State private var errorMessage: String?

    @State private var skillToDelete: Skill?
    @State private var showingDeleteAlert = false

    @State private var conflictingSkillState: ProviderSkillState?
    @State private var showingConflictAlert = false

    /// Current provider name for display
    private var providerName: String {
        provider?.displayName
            ?? NSLocalizedString("skills_list.no_provider", comment: "Select a Provider")
    }

    public init(
        provider: Provider?,
        selectedSkill: Binding<Skill?>,
        settings: ProviderSettings,
        refreshTrigger: Int = 0
    ) {
        self.provider = provider
        self._selectedSkill = selectedSkill
        self.settings = settings
        self.refreshTrigger = refreshTrigger
    }

    public var body: some View {
        Group {
            if provider != nil {
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
        .onAppear {
            installer = SkillInstaller(repository: repository, settings: settings)
        }
        .task(id: "\(provider?.id ?? "")-\(refreshTrigger)") {
            await loadSkills()
        }
        .refreshable {
            await loadSkills()
        }
        .alert(
            NSLocalizedString(
                "confirm.delete_title", value: "Delete Skill?", comment: "Delete Skill?"),
            isPresented: $showingDeleteAlert,
            presenting: skillToDelete
        ) { skill in
            Button(NSLocalizedString("action.delete", comment: "Delete"), role: .destructive) {
                performDelete(skill)
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
            isPresented: $showingConflictAlert,
            presenting: conflictingSkillState
        ) { skillState in
            Button(
                NSLocalizedString("action.overwrite", comment: "Overwrite"), role: .destructive
            ) {
                Task {
                    await migrateSkillWithOverwrite(skillState)
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
                let installed = installedSkills
                if !installed.isEmpty {
                    Section {
                        ForEach(installed) { skill in
                            SkillListRowView(
                                skill: skill,
                                isInstalled: true,
                                providerPath: provider?.path,
                                canDelete: provider?.installMethod == .copy,
                                onInstall: { await installSkill(skill) },
                                onUninstall: { await uninstallSkill(skill) },
                                onDelete: { confirmDelete(skill) }
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
                                providerPath: nil,
                                canDelete: true,
                                onInstall: { await installSkill(skill) },
                                onUninstall: { await uninstallSkill(skill) },
                                onDelete: { confirmDelete(skill) }
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
                let orphaned = filteredOrphanedSkills
                if !orphaned.isEmpty {
                    Section {
                        ForEach(orphaned, id: \.skillName) { skillState in
                            OrphanedSkillRowView(
                                skillState: skillState,
                                onMigrate: { await migrateSkill(skillState) },
                                onReveal: { revealInFinder(skillState.path) }
                            )
                        }
                    } header: {
                        Label(
                            NSLocalizedString("skills_list.existing", comment: "Existing"),
                            systemImage: "folder.badge.questionmark"
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
        filteredSkills.filter { skill in
            !installedSkillIds.contains(skill.id)
                && !orphanedSkillStates.contains { $0.skillName == skill.id }
        }
    }

    private var filteredOrphanedSkills: [ProviderSkillState] {
        if searchText.isEmpty {
            return orphanedSkillStates
        }
        return orphanedSkillStates.filter {
            $0.skillName.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func loadSkills() async {
        guard let provider = provider, let installer = installer else {
            installedSkillIds = []
            return
        }

        do {
            allSkills = try repository.listSkills()

            // Scan provider directory
            let states = try installer.scanProvider(provider: provider)
            installedSkillIds = Set(states.filter { $0.state == .installed }.map(\.skillName))
            orphanedSkillStates = states.filter { $0.state == .orphaned }

            // Auto-select first skill if none selected
            if selectedSkill == nil, let first = allSkills.first {
                selectedSkill = first
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func installSkill(_ skill: Skill) async {
        guard let installer = installer, let provider = provider else { return }
        do {
            try installer.install(skill: skill, to: provider)
            await loadSkills()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func uninstallSkill(_ skill: Skill) async {
        guard let installer = installer, let provider = provider else { return }
        do {
            try installer.uninstall(skill: skill, from: provider)
            await loadSkills()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func confirmDelete(_ skill: Skill) {
        skillToDelete = skill
        showingDeleteAlert = true
    }

    private func performDelete(_ skill: Skill) {
        do {
            if installedSkillIds.contains(skill.id) {
                // Try to uninstall first if installed
                // Note: We can't await here easily in a button callback, but removing the global source
                // will break the symlink anyway. Ideally we should uninstall cleanly first.
                // For now, let's just remove the global item which is the primary action.
                // Ideally this should make the symlink broken.
            }

            try FileManager.default.removeItem(atPath: skill.globalPath)

            // Refresh
            Task {
                await loadSkills()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func migrateSkill(_ skillState: ProviderSkillState) async {
        guard let installer = installer, let provider = provider else { return }
        do {
            _ = try installer.migrate(skillName: skillState.skillName, from: provider)
            await loadSkills()
        } catch let error as SkillError {
            if case .conflictDetected = error {
                // Show conflict alert for user decision
                conflictingSkillState = skillState
                showingConflictAlert = true
            } else {
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func migrateSkillWithOverwrite(_ skillState: ProviderSkillState) async {
        guard let installer = installer, let provider = provider else { return }
        do {
            _ = try installer.migrate(
                skillName: skillState.skillName, from: provider, overwriteExisting: true)
            await loadSkills()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func revealInFinder(_ path: String) {
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
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
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(skillState.skillName)
                    .font(.headline)

                Text(
                    NSLocalizedString("skills_list.existing_desc", comment: "Not managed by nolon")
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
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
