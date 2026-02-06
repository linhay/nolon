import SwiftUI
import UniformTypeIdentifiers

/// View displaying all global skills
@MainActor
public struct SkillListView: View {
    let skills: [Skill]
    let repository: SkillRepository
    let installer: SkillInstaller
    let onRefresh: () async -> Void

    @State private var showingImportSheet = false
    @State private var errorMessage: String?
    @State private var installedSkills: Set<String> = []

    public var body: some View {
        NavigationStack {
            Group {
                if skills.isEmpty {
                    emptyStateView
                } else {
                    List(skills) { skill in
                        SkillRow(
                            skill: skill,
                            isInstalled: installedSkills.contains(skill.id),
                            onUpdate: { await refresh() }
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
                        .dsIconLabelButton()
                    }
                    .tint(DesignSystem.Colors.primary)
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
                await refresh()
            }
        }
    }

    private func refresh() async {
        await onRefresh()
        installedSkills = installer.findAllInstalledSkills()
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label {
                Text(NSLocalizedString("list.empty_title", comment: "No Skills Managed"))
                    .dsEmptyStateTitle()
            } icon: {
                Image(systemName: "square.stack.3d.up.slash")
                    .dsEmptyStateIcon()
            }
        } description: {
            Text(NSLocalizedString("list.empty_desc_action", comment: "Import a skill..."))
                .dsSecondaryText(font: .body)
        } actions: {
            Button(NSLocalizedString("list.import_btn", comment: "Import from Folder")) {
                showingImportSheet = true
            }
            .dsPrimaryButton()
            .controlSize(.small)
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) async {
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }

            _ = try repository.importSkill(from: url)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Row view for a single skill
struct SkillRow: View {
    let skill: Skill
    let isInstalled: Bool
    let onUpdate: () async -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(skill.name)
                    .font(.headline)
                
                if isInstalled {
                    Text("Installed")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(DesignSystem.Colors.Text.onAccent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(DesignSystem.Colors.Status.success)
                        .cornerRadius(DesignSystem.Metrics.cornerRadiusXS)
                }
            }

            Text(skill.description)
                .font(.caption)
                .dsSecondaryText(font: .caption)
                .lineLimit(2)

            HStack {
                if skill.hasReferences || skill.hasScripts {
                    HStack(spacing: 12) {
                        if skill.hasReferences {
                            Label("\(skill.referenceCount)", systemImage: "doc.text")
                                .dsIconLabelText()
                        }
                        if skill.hasScripts {
                            Label("\(skill.scriptCount)", systemImage: "terminal")
                                .dsIconLabelText()
                        }
                    }
                }

                Spacer()

                // Version badge
                SkillVersionBadge(version: skill.version)
            }

            if isExpanded {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("skill.path_label", comment: "Path:"))
                        .font(.caption)
                        .dsSecondaryText(font: .caption)

                    Text(skill.globalPath)
                        .dsSecondaryText(font: .system(.caption2, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if skill.hasReferences || skill.hasScripts {
                        // Expanded details if we want more verbose info,
                        // but we moved counts to footer.
                        // We can keep this simple or remove if redundant.
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
}
