import SwiftUI

/// View for managing skills by provider (Legacy view - simplified)
@MainActor
public struct ProviderSkillsView: View {
    let repository: SkillRepository
    let installer: SkillInstaller
    let onRefresh: () async -> Void

    @State private var selectedProviderIndex = 0
    @State private var providerStates: [ProviderSkillState] = []
    @State private var errorMessage: String?
    
    @StateObject private var settings = ProviderSettings()
    
    private var selectedProvider: Provider? {
        guard selectedProviderIndex < settings.providers.count else { return nil }
        return settings.providers[selectedProviderIndex]
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Provider picker
                if !settings.providers.isEmpty {
                    Picker(
                        NSLocalizedString("provider_picker.label", comment: "Provider"),
                        selection: $selectedProviderIndex
                    ) {
                        ForEach(Array(settings.providers.enumerated()), id: \.element.id) { index, provider in
                            Text(provider.displayName).tag(index)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()
                }

                // Migration banner
                if hasOrphanedSkills {
                    migrationBanner
                }

                // Skills list
                if providerStates.isEmpty {
                    ContentUnavailableView(
                        NSLocalizedString("provider.empty", comment: "No Skills"),
                        systemImage: "folder.badge.questionmark",
                        description: Text(NSLocalizedString("provider.empty_desc", comment: "No skills found in this provider"))
                    )
                } else {
                    List(providerStates, id: \.skillName) { state in
                        ProviderSkillRow(
                            state: state,
                            provider: selectedProvider,
                            installer: installer,
                            onUpdate: { await loadProviderStates() }
                        )
                    }
                }
            }
            .navigationTitle(NSLocalizedString("provider.title", comment: "Provider Skills"))
            .task(id: selectedProviderIndex) {
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
        guard let provider = selectedProvider else {
            providerStates = []
            return
        }
        
        do {
            providerStates = try installer.scanProvider(provider: provider)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func migrateAll() async {
        guard let provider = selectedProvider else { return }
        
        do {
            _ = try installer.migrateAll(from: provider)
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
    let provider: Provider?
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
            if let provider = provider {
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
