import SwiftUI

/// 远程技能卡片视图 - Grid 布局中的卡片
struct RemoteSkillCardView: View {
    let skill: RemoteSkill
    let isInstalled: Bool
    let targetProvider: Provider?
    let providers: [Provider]
    let onInstall: (Provider) -> Void
    let onTap: () -> Void
    
    @State private var showingInstallSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Name + Install Button (右上角)
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(skill.displayName)
                        .font(.headline)
                        .lineLimit(1)
                    
                    if let version = skill.latestVersion?.version {
                        SkillVersionBadge(version: version)
                    }
                }
                
                Spacer()
                
                // 右上角安装按钮 - Liquid Glass 风格
                installButton
            }
            
            // Description
            if let summary = skill.summary {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            
            Spacer(minLength: 0)
            
            // Footer: Stats
            HStack(spacing: 12) {
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
        }
        .padding()
        .frame(minHeight: 140)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .sheet(isPresented: $showingInstallSheet) {
            SkillInstallSheet(providers: providers, skillName: skill.displayName) { provider in
                onInstall(provider)
            }
        }
    }
    
    /// 安装按钮 - Liquid Glass 风格
    @ViewBuilder
    private var installButton: some View {
        if isInstalled {
            // 已安装状态 - 显示 Installed 标签
            Text("Installed")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color.green.opacity(0.9))
                )
        } else {
            // 未安装状态 - 显示 Install 按钮
            if let target = targetProvider {
                Button {
                    onInstall(target)
                } label: {
                    installButtonLabel
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    showingInstallSheet = true
                } label: {
                    installButtonLabel
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    /// 安装按钮标签 - Liquid Glass 风格
    private var installButtonLabel: some View {
        Text("Install")
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.accentColor.opacity(0.4), radius: 4, x: 0, y: 2)
            )
    }
}

