import SwiftUI
import ProviderCatalog

/// View for managing skills by provider
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

                // Skills grid
                if viewModel.providerStates.isEmpty {
                    ContentUnavailableView(
                        NSLocalizedString("provider.empty", comment: "No Skills"),
                        systemImage: "folder.badge.questionmark",
                        description: Text(NSLocalizedString("provider.empty_desc", comment: "No skills found in this provider"))
                            .dsSecondaryText(font: .body)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 200, maximum: 280))],
                            spacing: 16
                        ) {
                            ForEach(viewModel.providerStates, id: \.skillName) { state in
                                ProviderSkillCard(
                                    state: state,
                                    hasUpdate: viewModel.skillHasUpdate(state.skillName),
                                    onUninstall: { await viewModel.uninstallSkill(at: state.path) },
                                    onMigrate: { await viewModel.migrateSkill(skillName: state.skillName) },
                                    onRepair: { await viewModel.repairSymlink(skillName: state.skillName) },
                                    onDelete: { await viewModel.deletePath(state.path) },
                                    onUpdate: { 
                                        if let update = viewModel.availableUpdates.first(where: { $0.id == state.skillName }) {
                                            await viewModel.performUpdate(update)
                                        }
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle(NSLocalizedString("provider.title", comment: "Provider Skills"))
            .task(id: viewModel.selectedProviderIndex) {
                 viewModel.onRefreshHandler = onRefresh
                 await viewModel.loadProviderStates()
                 await viewModel.checkForUpdates()
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
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(DesignSystem.Colors.Status.warning)

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
                .dsSecondaryText(font: .caption)
            }

            Spacer()

            Button(NSLocalizedString("action.import_all", value: "Import All", comment: "Import All")) {
                Task {
                    await viewModel.migrateAll()
                }
            }
            .dsPrimaryButton()
            .controlSize(.small)
        }
        .padding()
        .dsCard(
            background: DesignSystem.Colors.Status.warning.opacity(0.12),
            cornerRadius: DesignSystem.Metrics.cornerRadiusM,
            borderColor: DesignSystem.Colors.Status.warning.opacity(0.35)
        )
        .padding(.horizontal)
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
                    .dsSecondaryButton(
                        foreground: DesignSystem.Colors.Status.error,
                        background: DesignSystem.Colors.Status.error.opacity(0.08),
                        borderColor: DesignSystem.Colors.Status.error.opacity(0.45)
                    )

                case .orphaned:
                    Button(NSLocalizedString("action.migrate", comment: "Migrate")) {
                        Task {
                            await onMigrate()
                        }
                    }
                    .dsPrimaryButton()

                case .broken:
                    HStack(spacing: 8) {
                        Button(NSLocalizedString("action.repair", comment: "Repair")) {
                            Task {
                                await onRepair()
                            }
                        }
                        .dsSecondaryButton()

                        Button(NSLocalizedString("action.delete", comment: "Delete")) {
                            showingDeleteConfirmation = true
                        }
                        .dsSecondaryButton(
                            foreground: DesignSystem.Colors.Status.error,
                            background: DesignSystem.Colors.Status.error.opacity(0.08),
                            borderColor: DesignSystem.Colors.Status.error.opacity(0.45)
                        )
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
                .dsIconLabelText(foreground: DesignSystem.Colors.Status.success, font: .caption)
            case .orphaned:
                Label(
                    NSLocalizedString("status.physical", comment: "Physical File"),
                    systemImage: "folder.fill"
                )
                .dsIconLabelText(foreground: DesignSystem.Colors.Status.warning, font: .caption)
            case .broken:
                Label(
                    NSLocalizedString("status.broken", comment: "Broken Link"),
                    systemImage: "exclamationmark.triangle.fill"
                )
                .dsIconLabelText(foreground: DesignSystem.Colors.Status.error, font: .caption)
            }
        }
    }
}
