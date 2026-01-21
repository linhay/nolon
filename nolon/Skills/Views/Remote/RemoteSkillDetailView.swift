import SwiftUI

struct RemoteSkillDetailView: View {
    let skill: RemoteSkill
    let providers: [Provider]
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
                        }
                        if let downloads = skill.stats?.downloads {
                            Label("\(downloads) Downloads", systemImage: "arrow.down.circle")
                        }
                        if let version = skill.latestVersion?.version {
                            Label("v\(version)", systemImage: "tag")
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)

                // Content (Placeholder for README)
                // In a real app we would load the README from ClawdhubService.fetchSkillDetail
                VStack(alignment: .leading, spacing: 12) {
                    Text("About this skill")
                        .font(.headline)

                    if let changelog = skill.latestVersion?.changelog {
                        Text("Latest Changes")
                            .font(.subheadline)
                            .bold()
                        Text(changelog)
                            .font(.body)
                    } else {
                        Text("No detailed description available.")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingInstallSheet = true }) {
                    Label("Install", systemImage: "square.and.arrow.down")
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
