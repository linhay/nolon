import MarkdownUI
import SwiftUI

/// Detailed view for a single skill (simplified - no installation UI)
@MainActor
public struct SkillDetailView: View {
    let skill: Skill
    @ObservedObject var settings: ProviderSettings

    public init(skill: Skill, settings: ProviderSettings) {
        self.skill = skill
        self.settings = settings
    }

    @State private var showingContent = false

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(skill.name)
                        .font(.title)
                        .bold()

                    Text(skill.description)
                        .font(.body)
                        .foregroundStyle(.secondary)

                    HStack {
                        SkillVersionBadge(version: skill.version)

                        Spacer()
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)

                // Associated Area
                associatedArea

                // Additional files
                if skill.hasReferences || skill.hasScripts {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("detail.files", comment: "Additional Files"))
                            .font(.headline)

                        if skill.hasReferences {
                            Label(
                                String(
                                    format: NSLocalizedString(
                                        "detail.ref_files", comment: "%d reference files"),
                                    skill.referenceCount), systemImage: "doc.text"
                            )
                            .font(.caption)
                        }

                        if skill.hasScripts {
                            Label(
                                String(
                                    format: NSLocalizedString(
                                        "detail.script_files", comment: "%d script files"),
                                    skill.scriptCount), systemImage: "terminal"
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
                    
                    Text(skill.globalPath)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                    
                    Button {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: skill.globalPath)
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
                        showingContent.toggle()
                    } label: {
                        HStack {
                            Text(NSLocalizedString("detail.content", comment: "SKILL.md Content"))
                                .font(.headline)

                            Spacer()

                            Image(systemName: showingContent ? "chevron.up" : "chevron.down")
                        }
                    }
                    .buttonStyle(.plain)

                    if showingContent {
                        Divider()

                        Markdown(skill.content)
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
        .navigationTitle(skill.name)
    }

    @ViewBuilder
    private var associatedArea: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Associated Area")
                .font(.headline)

            // Providers List (Tags)
            VStack(alignment: .leading, spacing: 8) {
                Text("Providers")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(settings.providers) { provider in
                            if FileManager.default.fileExists(atPath: provider.skillsPath + "/" + skill.id) {
                                Label(provider.name, systemImage: provider.iconName)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
            }

            Divider()

            // Global Workflow Toggle
            GlobalWorkflowToggle(skill: skill)
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }
}

struct GlobalWorkflowToggle: View {
    let skill: Skill
    
    // Fixed path as requested
    let globalWorkflowsPath = "/Users/linhey/.gemini/antigravity/global_workflows"
    
    var workflowPath: String {
        globalWorkflowsPath + "/" + skill.id + ".md"
    }

    @State private var isEnabled: Bool = false

    var body: some View {
        Toggle(isOn: Binding(
            get: { isEnabled },
            set: { newValue in
                if newValue {
                    createWorkflow()
                } else {
                    deleteWorkflow()
                }
                isEnabled = newValue
            }
        )) {
            VStack(alignment: .leading) {
                Text("Workflow")
                    .font(.subheadline)
                Text(globalWorkflowsPath)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .toggleStyle(.switch)
        .onAppear {
            checkStatus()
        }
    }

    private func checkStatus() {
        isEnabled = FileManager.default.fileExists(atPath: workflowPath)
    }

    private func createWorkflow() {
        do {
            if !FileManager.default.fileExists(atPath: globalWorkflowsPath) {
                try FileManager.default.createDirectory(atPath: globalWorkflowsPath, withIntermediateDirectories: true)
            }
            
            // Create a simple workflow file referencing the skill
            let content = """
            ---
            description: \(skill.description)
            ---
            
            # \(skill.name)
            
            [Open Skill](nolon://skill/\(skill.id))
            
            """
            try content.write(toFile: workflowPath, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to create workflow: \(error)")
        }
    }

    private func deleteWorkflow() {
        do {
            if FileManager.default.fileExists(atPath: workflowPath) {
                try FileManager.default.removeItem(atPath: workflowPath)
            }
        } catch {
            print("Failed to delete workflow: \(error)")
        }
    }
}
