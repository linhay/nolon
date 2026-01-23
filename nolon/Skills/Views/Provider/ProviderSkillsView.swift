import SwiftUI

/// View for managing skills by provider (Legacy view - simplified)
@MainActor
public struct ProviderSkillsView: View {
    @State private var viewModel = ProviderSkillsViewModel()
    let onRefresh: () async -> Void

    public init(
        repository: SkillRepository,
        installer: SkillInstaller,
        onRefresh: @escaping () async -> Void
    ) {
        self.onRefresh = onRefresh
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Provider picker
                if !viewModel.settings.providers.isEmpty {
                    Picker(
                        NSLocalizedString("provider_picker.label", comment: "Provider"),
                        selection: $viewModel.selectedProviderIndex
                    ) {
                        ForEach(Array(viewModel.settings.providers.enumerated()), id: \.element.id) { index, provider in
                            Text(provider.displayName).tag(index)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()
                }

                // Migration banner
                if viewModel.hasOrphanedSkills {
                    migrationBanner
                }

                // Skills list
                if viewModel.providerStates.isEmpty {
                    ContentUnavailableView(
                        NSLocalizedString("provider.empty", comment: "No Skills"),
                        systemImage: "folder.badge.questionmark",
                        description: Text(NSLocalizedString("provider.empty_desc", comment: "No skills found in this provider"))
                    )
                } else {
                    List(viewModel.providerStates, id: \.skillName) { state in
                        ProviderSkillRow(
                            state: state,
                            onUninstall: { await viewModel.uninstallSkill(at: state.path) },
                            onMigrate: { await viewModel.migrateSkill(skillName: state.skillName) },
                            onRepair: { await viewModel.repairSymlink(skillName: state.skillName) },
                            onDelete: { await viewModel.deletePath(state.path) }
                        )
                    }
                }
            }
            .navigationTitle(NSLocalizedString("provider.title", comment: "Provider Skills"))
            .task(id: viewModel.selectedProviderIndex) {
                 viewModel.onRefreshHandler = onRefresh
                 await viewModel.loadProviderStates()
            }
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

    private var migrationBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text(
                        NSLocalizedString(
                            "banner.orphaned_title", comment: "Orphaned Skills Detected")
                    )
                    .font(.headline)

                    Text(
                        NSLocalizedString(
                            "banner.orphaned_desc", comment: "Some skills are not managed...")
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Button(NSLocalizedString("action.migrate_all", comment: "Migrate All")) {
                Task {
                    await viewModel.migrateAll()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
    }
}

/// Row for a skill in provider directory
struct ProviderSkillRow: View {
    let state: ProviderSkillState
    let onUninstall: () async -> Void
    let onMigrate: () async -> Void
    let onRepair: () async -> Void
    let onDelete: () async -> Void

    @State private var showingDeleteConfirmation = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(state.skillName)
                    .font(.headline)

                stateLabel
            }

            Spacer()

            // Actions based on state
                switch state.state {
                case .installed:
                    Button(NSLocalizedString("action.uninstall", comment: "Uninstall")) {
                        Task {
                            await onUninstall()
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)

                case .orphaned:
                    Button(NSLocalizedString("action.migrate", comment: "Migrate")) {
                        Task {
                            await onMigrate()
                        }
                    }
                    .buttonStyle(.borderedProminent)

                case .broken:
                    HStack(spacing: 8) {
                        Button(NSLocalizedString("action.repair", comment: "Repair")) {
                            Task {
                                await onRepair()
                            }
                        }
                        .buttonStyle(.bordered)

                        Button(NSLocalizedString("action.delete", comment: "Delete")) {
                            showingDeleteConfirmation = true
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }
        }
        .confirmationDialog(
            NSLocalizedString("confirm.delete_broken_title", comment: "Delete broken symlink?"),
            isPresented: $showingDeleteConfirmation
        ) {
            Button(NSLocalizedString("action.delete", comment: "Delete"), role: .destructive) {
                Task {
                    await onDelete()
                }
            }
        }
    }

    private var stateLabel: some View {
        Group {
            switch state.state {
            case .installed:
                Label(
                    NSLocalizedString("status.symlinked", comment: "Symlinked"),
                    systemImage: "checkmark.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(.green)
            case .orphaned:
                Label(
                    NSLocalizedString("status.physical", comment: "Physical File"),
                    systemImage: "folder.fill"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            case .broken:
                Label(
                    NSLocalizedString("status.broken", comment: "Broken Link"),
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption)
                .foregroundStyle(.red)
            }
        }
    }
}
