import SwiftUI
import ProviderCatalog
import MarkdownUI
import STFilePath
import NolonResourceKit

struct RemoteSkillDetailView: View {
    let skill: RemoteSkill
    let providers: [Provider]
    var targetProvider: Provider? = nil // New property
    var isInstalled: Bool = false
    let onInstall: (Provider) -> Void

    @State private var showingInstallSheet = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            if resolvedLocalPath == nil {
                SheetHeaderView(
                    title: skill.displayName,
                    subtitle: skill.summary
                ) {
                    dismiss()
                }

                SheetDivider()
            }

            Group {
                if let localPath = resolvedLocalPath {
                    VStack(alignment: .leading, spacing: 16) {
                        headerView(isLocalAvailable: true)

                        RemoteLocalSkillDetailView(skill: skill, localPath: localPath)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            headerView(isLocalAvailable: false)

                            VStack(alignment: .leading, spacing: 12) {
                                Text(NSLocalizedString("About this skill", comment: "About this skill"))
                                    .font(.headline)

                                if let changelog = skill.latestVersion?.changelog {
                                    Text(NSLocalizedString("Latest Changes", comment: "Latest changes"))
                                        .font(.subheadline)
                                        .bold()
                                    Markdown(changelog)
                                } else {
                                    Text(NSLocalizedString("No detailed description available.", comment: "No description"))
                                        .dsSecondaryText(font: .body)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .dsCard(
                                background: DesignSystem.Colors.Component.controlFill,
                                cornerRadius: DesignSystem.Metrics.cornerRadiusL
                            )
                        }
                        .padding()
                        .textSelection(.enabled)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if let target = targetProvider {
                    Button(action: { onInstall(target) }) {
                        Label(
                            String(
                                format: NSLocalizedString("Install to %@", comment: "Install to provider"),
                                target.name
                            ),
                            systemImage: "square.and.arrow.down"
                        )
                        .dsIconLabelButton()
                    }
                    .disabled(isInstalled)
                } else {
                    Button(action: { showingInstallSheet = true }) {
                        Label(NSLocalizedString("Install", comment: "Install"), systemImage: "square.and.arrow.down")
                            .dsIconLabelButton()
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

    private var resolvedLocalPath: String? {
        guard let path = skill.localPath, STPath(path).isExists else { return nil }
        let skillMdPath = (path as NSString).appendingPathComponent("SKILL.md")
        guard STFile(skillMdPath).isExists else { return nil }
        return path
    }

    private func headerView(isLocalAvailable: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(skill.displayName)
                    .font(.title2)
                    .bold()
                    .foregroundStyle(DesignSystem.Colors.Text.primary)

                if isLocalAvailable {
                    Text(NSLocalizedString("remote.detail.local_badge", comment: "Local badge"))
                        .dsBadge(
                            foreground: DesignSystem.Colors.Status.success,
                            background: DesignSystem.Colors.Status.success.opacity(0.15),
                            horizontalPadding: 6,
                            verticalPadding: 2
                        )
                }

                Spacer()
            }

            if let summary = skill.summary {
                Text(summary)
                    .font(.title3)
                    .dsSecondaryText(font: .title3)
            }

            HStack(spacing: 16) {
                if let stars = skill.stats?.stars {
                    Label {
                        Text(String(format: NSLocalizedString("%lld Stars", comment: "Star count"), Int64(stars)))
                    } icon: {
                        Image(systemName: "star.fill")
                            .foregroundStyle(DesignSystem.Colors.Status.warning)
                    }
                    .accessibilityLabel(String(format: NSLocalizedString("%lld Stars", comment: "Star count"), Int64(stars)))
                }
                if let downloads = skill.stats?.downloads {
                    Label {
                        Text(String(format: NSLocalizedString("%lld Downloads", comment: "Download count"), Int64(downloads)))
                    } icon: {
                        Image(systemName: "arrow.down.circle")
                            .foregroundStyle(DesignSystem.Colors.Status.info)
                    }
                    .accessibilityLabel(String(format: NSLocalizedString("%lld Downloads", comment: "Download count"), Int64(downloads)))
                }
                if let version = skill.latestVersion?.version {
                    Text(String(format: NSLocalizedString("v%@", comment: "Version badge"), version))
                        .dsBadge(
                            foreground: DesignSystem.Colors.Text.secondary,
                            background: DesignSystem.Colors.Component.controlFillSubtle,
                            horizontalPadding: 6,
                            verticalPadding: 2
                        )
                }
            }
            .font(.subheadline)
            .dsSecondaryText(font: .subheadline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCard(
            background: DesignSystem.Colors.Component.controlFill,
            cornerRadius: DesignSystem.Metrics.cornerRadiusL
        )
    }
}
