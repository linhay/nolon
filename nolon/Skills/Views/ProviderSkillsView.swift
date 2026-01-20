import SwiftUI

/// View for managing skills by provider
@MainActor
public struct ProviderSkillsView: View {
    let repository: SkillRepository
    let installer: SkillInstaller
    let onRefresh: () async -> Void

    @State private var selectedProvider: SkillProvider = .codex
    @State private var providerStates: [ProviderSkillState] = []
    @State private var showingMigrationAlert = false
    @State private var errorMessage: String?

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Provider picker
                Picker(
                    NSLocalizedString("provider_picker.label", comment: "Provider"),
                    selection: $selectedProvider
                ) {
                    ForEach(SkillProvider.allCases, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Migration banner
                if hasOrphanedSkills {
                    migrationBanner
                }

                // Skills list
                List(providerStates, id: \.skillName) { state in
                    ProviderSkillRow(
                        state: state,
                        provider: selectedProvider,
                        installer: installer,
                        onUpdate: { await loadProviderStates() }
                    )
                }
            }
            .navigationTitle(NSLocalizedString("provider.title", comment: "Provider Skills"))
            .task(id: selectedProvider) {
                await loadProviderStates()
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
    }

    private var hasOrphanedSkills: Bool {
        providerStates.contains { $0.state == .orphaned }
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
                    await migrateAll()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
    }

    private func loadProviderStates() async {
        do {
            providerStates = try installer.scanProvider(provider: selectedProvider)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func migrateAll() async {
        do {
            _ = try installer.migrateAll(from: selectedProvider)
            await loadProviderStates()
            await onRefresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Row for a skill in provider directory
struct ProviderSkillRow: View {
    let state: ProviderSkillState
    let provider: SkillProvider
    let installer: SkillInstaller
    let onUpdate: () async -> Void

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
                        try? FileManager.default.removeItem(atPath: state.path)
                        await onUpdate()
                    }
                }
                .buttonStyle(.bordered)
                .tint(.red)

            case .orphaned:
                Button(NSLocalizedString("action.migrate", comment: "Migrate")) {
                    Task {
                        try? installer.migrate(skillName: state.skillName, from: provider)
                        await onUpdate()
                    }
                }
                .buttonStyle(.borderedProminent)

            case .broken:
                HStack(spacing: 8) {
                    Button(NSLocalizedString("action.repair", comment: "Repair")) {
                        Task {
                            try? installer.repairSymlink(skillName: state.skillName, for: provider)
                            await onUpdate()
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
                    try? FileManager.default.removeItem(atPath: state.path)
                    await onUpdate()
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
