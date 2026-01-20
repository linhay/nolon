import MarkdownUI
import SwiftUI

/// Detailed view for a single skill
@MainActor
public struct SkillDetailView: View {
    let skill: Skill
    let installer: SkillInstaller
    let onUpdate: () async -> Void

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
                        Label(
                            String(
                                format: NSLocalizedString("detail.version", comment: "Version %@"),
                                skill.version), systemImage: "number"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        Spacer()
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)

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

                // Installation status
                VStack(alignment: .leading, spacing: 12) {
                    Text(NSLocalizedString("detail.install_title", comment: "Installation"))
                        .font(.headline)

                    ForEach(SkillProvider.allCases, id: \.self) { provider in
                        HStack {
                            Text(provider.displayName)

                            Spacer()

                            if skill.isInstalledFor(provider) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)

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
                                Image(systemName: "circle")
                                    .foregroundStyle(.secondary)

                                Button(NSLocalizedString("action.install", comment: "Install")) {
                                    Task {
                                        try? installer.install(skill: skill, to: provider)
                                        await onUpdate()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }
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
        }
        .navigationTitle(skill.name)

    }
}
