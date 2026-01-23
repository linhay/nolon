import MarkdownUI
import SwiftUI
import Observation

@Observable
final class SkillDetailViewModel {
    var showingContent = false
    /// Dictionary to track workflow status per provider
    var workflowEnabledByProvider: [String: Bool] = [:]
    
    var skill: Skill
    
    init(skill: Skill) {
        self.skill = skill
    }
    
    func update(skill: Skill, providers: [Provider]) {
        self.skill = skill
        self.showingContent = false
        self.workflowEnabledByProvider = [:]
        checkWorkflowStatus(for: providers)
    }
    
    private func workflowPath(for provider: Provider) -> String {
        provider.workflowPath + "/" + skill.id + ".md"
    }
    
    func checkWorkflowStatus(for providers: [Provider]) {
        for provider in providers {
            let path = workflowPath(for: provider)
            workflowEnabledByProvider[provider.id] = FileManager.default.fileExists(atPath: path)
        }
    }
    
    func isWorkflowEnabled(for provider: Provider) -> Bool {
        workflowEnabledByProvider[provider.id] ?? false
    }
    
    func toggleWorkflow(for provider: Provider, enabled: Bool) {
        if enabled {
            createWorkflow(for: provider)
        } else {
            deleteWorkflow(for: provider)
        }
        workflowEnabledByProvider[provider.id] = enabled
    }
    
    private func createWorkflow(for provider: Provider) {
        do {
            let workflowDir = provider.workflowPath
            if !FileManager.default.fileExists(atPath: workflowDir) {
                try FileManager.default.createDirectory(atPath: workflowDir, withIntermediateDirectories: true)
            }
            
            // Create a simple workflow file referencing the skill
            let content = """
            ---
            description: \(skill.description)
            ---
            
            # \(skill.name)
            
            [Open Skill](nolon://skill/\(skill.id))
            
            """
            let path = workflowPath(for: provider)
            try content.write(toFile: path, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to create workflow: \(error)")
        }
    }
    
    private func deleteWorkflow(for provider: Provider) {
        do {
            let path = workflowPath(for: provider)
            if FileManager.default.fileExists(atPath: path) {
                try FileManager.default.removeItem(atPath: path)
            }
        } catch {
            print("Failed to delete workflow: \(error)")
        }
    }
}

/// Detailed view for a single skill (simplified - no installation UI)
@MainActor
public struct SkillDetailView: View {
    @ObservedObject var settings: ProviderSettings
    let skill: Skill
    @State private var viewModel: SkillDetailViewModel

    public init(skill: Skill, settings: ProviderSettings) {
        self.skill = skill
        self.settings = settings
        self._viewModel = State(initialValue: SkillDetailViewModel(skill: skill))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.skill.name)
                        .font(.title)
                        .bold()

                    Text(viewModel.skill.description)
                        .font(.body)
                        .foregroundStyle(.secondary)

                    HStack {
                        SkillVersionBadge(version: viewModel.skill.version)

                        Spacer()
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)

                // Associated Area
                associatedArea

                // Additional files
                if viewModel.skill.hasReferences || viewModel.skill.hasScripts {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("detail.files", comment: "Additional Files"))
                            .font(.headline)

                        if viewModel.skill.hasReferences {
                            Label(
                                String(
                                    format: NSLocalizedString(
                                        "detail.ref_files", comment: "%d reference files"),
                                    viewModel.skill.referenceCount), systemImage: "doc.text"
                            )
                            .font(.caption)
                        }

                        if viewModel.skill.hasScripts {
                            Label(
                                String(
                                    format: NSLocalizedString(
                                        "detail.script_files", comment: "%d script files"),
                                    viewModel.skill.scriptCount), systemImage: "terminal"
                            )
                            .font(.caption)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(12)
                }

                // Path info
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("detail.location", comment: "Location"))
                        .font(.headline)
                    
                    Text(viewModel.skill.globalPath)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                    
                    Button {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: viewModel.skill.globalPath)
                    } label: {
                        Label(NSLocalizedString("action.show_in_finder", comment: "Show in Finder"), systemImage: "folder")
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)

                // Markdown preview
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        viewModel.showingContent.toggle()
                    } label: {
                        HStack {
                            Text(NSLocalizedString("detail.content", comment: "SKILL.md Content"))
                                .font(.headline)

                            Spacer()

                            Image(systemName: viewModel.showingContent ? "chevron.up" : "chevron.down")
                        }
                    }
                    .buttonStyle(.plain)

                    if viewModel.showingContent {
                        Divider()

                        Markdown(viewModel.skill.content)
                            .padding(.top, 8)
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
            }
            .padding()
            .textSelection(.enabled)
        }
        .navigationTitle(viewModel.skill.name)
        .onAppear {
            viewModel.checkWorkflowStatus(for: settings.providers)
        }
        .onChange(of: skill) { _, newSkill in
            viewModel.update(skill: newSkill, providers: settings.providers)
        }
    }

    @ViewBuilder
    private var associatedArea: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Associated Area")
                .font(.headline)

            // Providers List with Workflow Toggles
            ForEach(settings.providers) { provider in
                if FileManager.default.fileExists(atPath: provider.skillsPath + "/" + viewModel.skill.id) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label(provider.name, systemImage: provider.iconName)
                                .font(.subheadline)
                            Spacer()
                        }
                        
                        Toggle(isOn: Binding(
                            get: { viewModel.isWorkflowEnabled(for: provider) },
                            set: { viewModel.toggleWorkflow(for: provider, enabled: $0) }
                        )) {
                            VStack(alignment: .leading) {
                                Text("Workflow")
                                    .font(.caption)
                                Text(provider.workflowPath)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        .toggleStyle(.switch)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }
}
