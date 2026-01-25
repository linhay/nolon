import SwiftUI
import MarkdownUI

struct RemoteSkillDetailView: View {
    let skill: RemoteSkill
    let providers: [Provider]
    var targetProvider: Provider? = nil // New property
    var isInstalled: Bool = false
    let onInstall: (Provider) -> Void

    @State private var showingInstallSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(skill.displayName)
                        .font(.title)
                        .bold()

                    if let summary = skill.summary {
                        Text(summary)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 16) {
                        if let stars = skill.stats?.stars {
                            Label("\(stars) Stars", systemImage: "star.fill")
                                .foregroundStyle(.yellow)
                                .accessibilityLabel("\(stars) stars")
                        }
                        if let downloads = skill.stats?.downloads {
                            Label("\(downloads) Downloads", systemImage: "arrow.down.circle")
                                .accessibilityLabel("\(downloads) downloads")
                        }
                        if let version = skill.latestVersion?.version {
                            SkillVersionBadge(version: version)
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Content (Placeholder for README)
                // In a real app we would load the README from ClawdhubService.fetchSkillDetail
                VStack(alignment: .leading, spacing: 12) {
                    Text("About this skill")
                        .font(.headline)

                    if let changelog = skill.latestVersion?.changelog {
                        Text("Latest Changes")
                            .font(.subheadline)
                            .bold()
                        Markdown(changelog)
                    } else {
                        Text("No detailed description available.")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            }
            .padding()
            .textSelection(.enabled)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if let target = targetProvider {
                    Button(action: { onInstall(target) }) {
                        Label("Install to \(target.name)", systemImage: "square.and.arrow.down")
                    }
                    .disabled(isInstalled)
                } else {
                    Button(action: { showingInstallSheet = true }) {
                        Label("Install", systemImage: "square.and.arrow.down")
                    }
                    .disabled(isInstalled)
                }
            }
        }
        .sheet(isPresented: $showingInstallSheet) {
            SkillInstallSheet(providers: providers, skillName: skill.displayName) { provider in
                onInstall(provider)
            }
        }
    }
}
