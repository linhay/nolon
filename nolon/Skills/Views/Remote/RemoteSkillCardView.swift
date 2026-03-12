import SwiftUI
import ProviderCatalog
import AppKit
import NolonResourceKit

/// 资源中心技能卡片视图 - Grid 布局中的卡片
struct RemoteSkillCardView: View {
    let skill: RemoteSkill
    let isInstalled: Bool
    let isInstalling: Bool
    let installErrorMessage: String?
    let isSelected: Bool
    let targetProvider: Provider?
    let providers: [Provider]
    let onInstall: (Provider) -> Void
    let onDeleteRequest: (() -> Void)?
    let isDeleting: Bool
    let onTap: () -> Void
    
    @State private var showingInstallSheet = false
    
    var body: some View {
        ResourceCardShell(
            minHeight: 140,
            isSelected: isSelected,
            locatorItems: [
                .init(title: "Skill Card"),
                .init(title: skill.displayName)
            ],
            onTap: onTap,
            headerContent: { headerView },
            summaryContent: { summaryView },
            metaContent: { metaView },
            actionContent: { installActionView },
            menuContent: { contextMenuItems }
        )
        .sheet(isPresented: $showingInstallSheet) {
            SkillInstallSheet(providers: providers, skillName: skill.displayName) { provider in
                onInstall(provider)
            }
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(skill.displayName)
                .font(.headline.weight(.semibold))
                .lineLimit(1)

            if let version = skill.latestVersion {
                Text(version.version)
                    .font(.system(size: 10, weight: .bold))
                    .dsBadge(
                        foreground: DesignSystem.Colors.primary,
                        background: DesignSystem.Colors.primary.opacity(0.15),
                        horizontalPadding: 6,
                        verticalPadding: 2
                    )
            }
        }
    }

    @ViewBuilder
    private var summaryView: some View {
        if let summary = skill.summary {
            Text(summary)
                .dsSecondaryText(font: .subheadline)
                .lineSpacing(2)
                .lineLimit(3)
                .frame(maxHeight: .infinity, alignment: .topLeading)
        } else {
            Spacer()
        }
    }

    @ViewBuilder
    private var metaView: some View {
        let items = ResourceCardMetaBuilder.skillItems(skill)
        if items.isEmpty {
            EmptyView()
        } else {
            HStack(spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    metaLabel(for: item)
                }
            }
        }
    }

    private var installActionView: some View {
        HStack(spacing: 8) {
            ResourceInstallStateView(
                isInstalled: isInstalled,
                isInstalling: isInstalling,
                errorMessage: installErrorMessage,
                onInstall: handleInstall,
                onRetry: handleInstall
            )

            if UITestSupport.shouldExposeDirectDeleteButton,
               (isInstalled || UITestSupport.isEnabled),
               !isDeleting,
               onDeleteRequest != nil {
                Button(role: .destructive) {
                    handleUITestDirectDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("uitest.direct-delete.skill.\(skill.slug)")
            }
        }
    }
    
    @ViewBuilder
    private var contextMenuItems: some View {
        Button {
            onTap()
        } label: {
            Label(NSLocalizedString("View Details", comment: "View resource details"), systemImage: "info.circle")
                .dsIconLabelButton()
        }

        if let revealURL = revealInFinderURL {
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([revealURL])
            } label: {
                Label(NSLocalizedString("action.show_in_finder", comment: "Show in Finder"), systemImage: "folder")
                    .dsIconLabelButton()
            }
        }

        if !isInstalled && !isInstalling {
            Divider()
            Button {
                handleInstall()
            } label: {
                Label(NSLocalizedString("action.install", value: "Install", comment: "Install action"), systemImage: "arrow.down.circle")
                    .dsIconLabelButton()
            }
        }

        if isInstalled && !isDeleting {
            Divider()
            Button(role: .destructive) {
                onDeleteRequest?()
            } label: {
                Label(NSLocalizedString("action.delete", value: "Delete", comment: "Delete action"), systemImage: "trash")
                    .dsIconLabelButton()
            }
            .disabled(onDeleteRequest == nil)
        }
    }
    
    private func handleInstall() {
        if let target = targetProvider {
            onInstall(target)
        } else {
            showingInstallSheet = true
        }
    }

    private func handleUITestDirectDelete() {
        onDeleteRequest?()
    }

    @ViewBuilder
    private func metaLabel(for item: ResourceCardMetaItem) -> some View {
        switch item {
        case let .stars(value):
            Label("\(value)", systemImage: "star.fill")
                .dsIconLabelText(foreground: DesignSystem.Colors.Status.warning, font: .caption2)
        case let .downloads(value):
            Label("\(value)", systemImage: "arrow.down.circle")
                .dsIconLabelText()
        case let .usages(value):
            Label("\(value)", systemImage: "arrow.triangle.branch")
                .dsIconLabelText()
        case let .installs(value):
            Label("\(value)", systemImage: "server.rack")
                .dsIconLabelText()
        case let .command(value):
            HStack(spacing: 4) {
                Image(systemName: "terminal")
                    .font(.caption2)
                Text(value)
                    .font(.system(size: 10, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .dsBadge(
                foreground: DesignSystem.Colors.Text.secondary,
                background: DesignSystem.Colors.Component.controlFillSubtle,
                horizontalPadding: 6,
                verticalPadding: 3,
                cornerRadius: DesignSystem.Metrics.cornerRadiusXS
            )
            .frame(maxWidth: 160, alignment: .leading)
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
