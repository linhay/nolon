import SwiftUI
import UniformTypeIdentifiers

/// View displaying all global skills
@MainActor
public struct SkillListView: View {
    let skills: [Skill]
    let repository: SkillRepository
    let installer: SkillInstaller
    let onRefresh: () async -> Void

    @State private var selectedSkills: Set<String> = []
    @State private var showingImportSheet = false
    @State private var errorMessage: String?
    @State private var showingMigrationSheet = false
    @State private var orphanedSkills: [SkillProvider: [String]] = [:]

    public var body: some View {
        NavigationStack {
            Group {
                if skills.isEmpty {
                    emptyStateView
                } else {
                    List(skills) { skill in
                        SkillRow(
                            skill: skill,
                            installer: installer,
                            onUpdate: { await onRefresh() }
                        )
                    }
                }
            }
            .navigationTitle(NSLocalizedString("list.title", comment: "Global Skills"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingImportSheet = true
                    } label: {
                        Label(
                            NSLocalizedString("list.import", comment: "Import Skill"),
                            systemImage: "plus")
                    }
                }
            }
            .fileImporter(
                isPresented: $showingImportSheet,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                Task {
                    await handleImport(result)
                }
            }
            .sheet(isPresented: $showingMigrationSheet) {
                BatchMigrationView(
                    orphanedSkills: orphanedSkills,
                    installer: installer,
                    onCompletion: {
                        showingMigrationSheet = false
                        await onRefresh()
                    }
                )
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
            .task {
                await checkForOrphans()
            }
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label(
                NSLocalizedString("list.empty_title", comment: "No Skills Managed"),
                systemImage: "square.stack.3d.up.slash")
        } description: {
            if !orphanedSkills.isEmpty {
                Text(
                    NSLocalizedString("list.empty_desc_found", comment: "Found existing skills..."))
            } else {
                Text(NSLocalizedString("list.empty_desc_action", comment: "Import a skill..."))
            }
        } actions: {
            VStack(spacing: 12) {
                if !orphanedSkills.isEmpty {
                    Button(
                        NSLocalizedString("list.migrate_btn", comment: "Migrate Existing Skills")
                    ) {
                        showingMigrationSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button(NSLocalizedString("list.import_btn", comment: "Import from Folder")) {
                    showingImportSheet = true
                }
            }
        }
    }

    private func checkForOrphans() async {
        var found: [SkillProvider: [String]] = [:]

        for provider in SkillProvider.allCases {
            if let states = try? installer.scanProvider(provider: provider) {
                let orphans = states.filter { $0.state == .orphaned }.map(\.skillName)
                if !orphans.isEmpty {
                    found[provider] = orphans
                }
            }
        }

        orphanedSkills = found
    }

    private func handleImport(_ result: Result<[URL], Error>) async {
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }

            _ = try repository.importSkill(from: url)
            await onRefresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct BatchMigrationView: View {
    let orphanedSkills: [SkillProvider: [String]]
    let installer: SkillInstaller
    let onCompletion: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedSelections: Set<String> = []
    @State private var migrationError: String?

    // Unique identifier: "providerID:skillName"
    private func id(for provider: SkillProvider, skill: String) -> String {
        "\(provider.id):\(skill)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if orphanedSkills.isEmpty {
                    ContentUnavailableView(
                        NSLocalizedString("migration.empty", comment: "No orphaned skills found"),
                        systemImage: "checkmark.circle"
                    )
                    .padding(.top, 40)
                } else {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(SkillProvider.allCases, id: \.self) { provider in
                            if let skills = orphanedSkills[provider], !skills.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(provider.displayName)
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal)

                                    ForEach(skills, id: \.self) { skill in
                                        Button {
                                            toggleSelection(provider: provider, skill: skill)
                                        } label: {
                                            HStack {
                                                Image(
                                                    systemName: isSelected(
                                                        provider: provider, skill: skill)
                                                        ? "checkmark.circle.fill" : "circle"
                                                )
                                                .foregroundStyle(
                                                    isSelected(provider: provider, skill: skill)
                                                        ? .blue : .secondary
                                                )
                                                .font(.title3)

                                                Text(skill)
                                                    .foregroundStyle(.primary)
                                                    .font(.body)

                                                Spacer()
                                            }
                                            .padding(.horizontal)
                                            .padding(.vertical, 8)
                                            .background(Color.secondary.opacity(0.05))
                                            .cornerRadius(8)
                                        }
                                        .buttonStyle(.plain)
                                        .padding(.horizontal)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .alert(
                NSLocalizedString("generic.error", comment: "Error"),
                isPresented: .constant(migrationError != nil)
            ) {
                Button(NSLocalizedString("generic.ok", comment: "OK")) { migrationError = nil }
            } message: {
                if let error = migrationError {
                    Text(error)
                }
            }
            .navigationTitle(NSLocalizedString("migration.title", comment: "Migrate Skills"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("generic.cancel", comment: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(
                        String(
                            format: NSLocalizedString("migration.action", comment: "Migrate (%d)"),
                            selectedSelections.count)
                    ) {
                        Task {
                            await performMigration()
                        }
                    }
                    .disabled(selectedSelections.isEmpty)
                }
            }
            .onAppear {
                // Select all by default
                var all: Set<String> = []
                for (provider, skills) in orphanedSkills {
                    for skill in skills {
                        all.insert(id(for: provider, skill: skill))
                    }
                }
                selectedSelections = all
            }
        }
    }

    private func isSelected(provider: SkillProvider, skill: String) -> Bool {
        selectedSelections.contains(id(for: provider, skill: skill))
    }

    private func toggleSelection(provider: SkillProvider, skill: String) {
        let key = id(for: provider, skill: skill)
        if selectedSelections.contains(key) {
            selectedSelections.remove(key)
        } else {
            selectedSelections.insert(key)
        }
    }

    private func performMigration() async {
        for selection in selectedSelections {
            let parts = selection.split(separator: ":")
            guard parts.count == 2,
                let provider = SkillProvider(rawValue: String(parts[0]))
            else { continue }

            let skillName = String(parts[1])
            do {
                _ = try installer.migrate(skillName: skillName, from: provider)
            } catch {
                migrationError = "Failed to migrate '\(skillName)': \(error.localizedDescription)"
                return  // Stop on error
            }
        }

        await onCompletion()
        dismiss()
    }
}

/// Row view for a single skill
struct SkillRow: View {
    let skill: Skill
    let installer: SkillInstaller
    let onUpdate: () async -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(skill.name)
                        .font(.headline)

                    Text(skill.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                // Status badge
                statusBadge
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Version: \(skill.version)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if skill.hasReferences || skill.hasScripts {
                        HStack(spacing: 12) {
                            if skill.hasReferences {
                                Label("\(skill.referenceCount) refs", systemImage: "doc.text")
                                    .font(.caption)
                            }
                            if skill.hasScripts {
                                Label("\(skill.scriptCount) scripts", systemImage: "terminal")
                                    .font(.caption)
                            }
                        }
                        .foregroundStyle(.secondary)
                    }

                    Divider()

                    // Provider installation controls
                    ForEach(SkillProvider.allCases, id: \.self) { provider in
                        HStack {
                            Text(provider.displayName)
                            Spacer()

                            if skill.isInstalledFor(provider) {
                                Button(NSLocalizedString("action.uninstall", comment: "Uninstall"))
                                {
                                    Task {
                                        try? installer.uninstall(skill: skill, from: provider)
                                        await onUpdate()
                                    }
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                            } else {
                                Button(NSLocalizedString("action.install", comment: "Install")) {
                                    Task {
                                        try? installer.install(skill: skill, to: provider)
                                        await onUpdate()
                                    }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .font(.caption)
                    }
                }
                .padding(.top, 4)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation {
                isExpanded.toggle()
            }
        }
    }

    private var statusBadge: some View {
        Group {
            if skill.isFullyInstalled {
                Label(
                    NSLocalizedString("status.installed", comment: "Installed"),
                    systemImage: "checkmark.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(.green)
            } else if skill.isInstalled {
                Label(
                    NSLocalizedString("status.partial", comment: "Partial"),
                    systemImage: "checkmark.circle"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            } else {
                Label(
                    NSLocalizedString("status.available", comment: "Available"),
                    systemImage: "square.dashed"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
}
