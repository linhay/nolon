import SwiftUI
import AppKit

/// 远程技能卡片视图 - Grid 布局中的卡片
struct RemoteSkillCardView: View {
    let skill: RemoteSkill
    let isInstalled: Bool
    let targetProvider: Provider?
    let providers: [Provider]
    let onInstall: (Provider) -> Void
    let onTap: () -> Void
    
    @State private var showingInstallSheet = false
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 1. Header: Name + Version Badge | More Menu
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(skill.displayName)
                        .font(.headline)
                        .lineLimit(1)
                    
                    if let version = skill.latestVersion {
                        Text(version.version)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())
                    }
                }
                
                Spacer()
                
                moreMenu
            }
            
            // 2. Description 区
            if let summary = skill.summary {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .frame(maxHeight: .infinity, alignment: .topLeading)
            } else {
                Spacer()
            }
            
            // 3. Footer: Stats & Actions
            HStack(alignment: .center) {
                // Left: Stats
                HStack(spacing: 8) {
                    if let stars = skill.stats?.stars {
                        Label("\(stars)", systemImage: "star.fill")
                            .foregroundStyle(.yellow)
                    }
                    if let downloads = skill.stats?.downloads {
                        Label("\(downloads)", systemImage: "arrow.down.circle")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                
                Spacer()
                
                // Right: Install Action
                installActionView
            }
        }
        .padding(16)
        .frame(minHeight: 140)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(12)
        .contentShape(Rectangle())
        .shadow(color: .black.opacity(isHovered ? 0.15 : 0.05), radius: isHovered ? 8 : 4, y: isHovered ? 4 : 2)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            contextMenuItems
        }
        .sheet(isPresented: $showingInstallSheet) {
            SkillInstallSheet(providers: providers, skillName: skill.displayName) { provider in
                onInstall(provider)
            }
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var installActionView: some View {
        if isInstalled {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                Text("Installed")
            }
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.green)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.green.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            Button {
                handleInstall()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle")
                    Text("Install")
                }
                .font(.caption2)
                .fontWeight(.bold)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.1))
                .foregroundStyle(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
    }
    
    @ViewBuilder
    private var contextMenuItems: some View {
        Button {
            onTap()
        } label: {
            Label("View Details", systemImage: "info.circle")
        }

        if let revealURL = revealInFinderURL {
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([revealURL])
            } label: {
                Label(NSLocalizedString("action.show_in_finder", comment: "Show in Finder"), systemImage: "folder")
            }
        }

        if !isInstalled {
            Divider()
            Button {
                handleInstall()
            } label: {
                Label("Install", systemImage: "arrow.down.circle")
            }
        }
    }
    
    private var moreMenu: some View {
        Menu {
            contextMenuItems
        } label: {
            Image(systemName: "ellipsis")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
    
    private func handleInstall() {
        if let target = targetProvider {
            onInstall(target)
        } else {
            showingInstallSheet = true
        }
    }

    private var revealInFinderURL: URL? {
        var candidates: [URL] = []

        if isInstalled, let provider = targetProvider {
            let providerSkillsPath = (provider.defaultSkillsPath as NSString).expandingTildeInPath
            let path = (providerSkillsPath as NSString).appendingPathComponent(skill.slug)
            candidates.append(URL(fileURLWithPath: path))
        }

        if let localPath = skill.localPath {
            candidates.append(URL(fileURLWithPath: (localPath as NSString).expandingTildeInPath))
        }

        if isInstalled {
            candidates.append(NolonManager.shared.skillsURL.appendingPathComponent(skill.slug))
        }

        return candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) })
    }
}
