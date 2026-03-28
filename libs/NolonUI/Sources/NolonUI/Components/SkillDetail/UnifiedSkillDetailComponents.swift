import Foundation
import MarkdownUI
import NolonUIFoundation
import SwiftUI

// MARK: - SkillDetailView

public struct SkillDetailView: View {
    public struct Config {
        public var viewModel: SkillDetailViewViewModel

        public init(viewModel: SkillDetailViewViewModel) {
            self.viewModel = viewModel
        }
    }

    @Bindable private var viewModel: SkillDetailViewViewModel

    public init(config: Config) {
        self.viewModel = config.viewModel
    }

    public init(viewModel: SkillDetailViewViewModel) {
        self.init(config: Config(viewModel: viewModel))
    }

    public var body: some View {
        SkillDetailScaffold(onClose: viewModel.close) {
            SkillDetailSidebar(viewModel: viewModel)
        } content: {
            SkillDetailContent(viewModel: viewModel)
        }
    }
}

// MARK: - SkillDetailSidebar

struct SkillDetailSidebar: View {
    let viewModel: SkillDetailViewViewModel
    
    var body: some View {
        SkillDetailSidebarContainer {
            ScrollView {
                VStack(spacing: 32) {
                    SkillIdentityModule(
                        title: viewModel.viewData.title,
                        version: viewModel.viewData.version,
                        showsLocalBadge: viewModel.viewData.showsLocalBadge
                    )
                    .padding(.top, 32)

                    SkillInstallationSection(
                        mode: viewModel.viewData.mode,
                        providers: viewModel.viewData.providers,
                        providerInstallationStates: viewModel.viewData.providerInstallationStates,
                        onInstallProvider: viewModel.installProvider
                    )

                    if viewModel.viewData.showsFileNavigator {
                        SkillFileNavigator(
                            files: viewModel.viewData.files,
                            selectedFileID: viewModel.viewData.selectedFileID,
                            onSelectFile: viewModel.selectFile
                        )
                    }

                    SkillAboutSection(
                        description: viewModel.viewData.detailDescription,
                        metadataRows: viewModel.viewData.aboutMetadataRows
                    )

                    if viewModel.viewData.showsSyncSection {
                        SkillSyncSection(
                            isWorkflowLinked: viewModel.viewData.isWorkflowLinked,
                            currentProvider: viewModel.viewData.providers.first(where: { $0.id == viewModel.viewData.currentProviderID }),
                            onToggleWorkflow: viewModel.toggleWorkflow
                        )
                    }
                }
                .padding(.bottom, 24)
            }
        } footer: {
            if viewModel.viewData.showsRevealInFinder {
                VStack(spacing: 0) {
                    Divider()
                        .background(DesignSystem.Colors.Component.border.opacity(0.3))

                    Button(action: viewModel.revealInFinder) {
                        HStack(spacing: 10) {
                            Image(systemName: "folder")
                            Text(NSLocalizedString("action.show_in_finder", comment: "Show in Finder"))
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.Text.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(DesignSystem.Colors.Component.controlFillSubtle)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(DesignSystem.Colors.Component.border.opacity(0.35), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(24)
                }
                .background(DesignSystem.Colors.Background.elevated)
            }
        }
    }
}

// MARK: - SkillDetailContent

struct SkillDetailContent: View {
    let viewModel: SkillDetailViewViewModel

    var body: some View {
        Group {
            switch viewModel.viewData.contentMode {
            case .fileBrowser:
                if let file = viewModel.viewData.files.first(where: { $0.id == viewModel.viewData.selectedFileID }) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            SkillFileContentView(
                                file: file,
                                handleMarkdownLink: viewModel.openMarkdownLink
                            )
                            .padding(.horizontal, 64)
                            .padding(.vertical, 48)
                        }
                    }
                } else {
                    SkillEmptyStateView()
                }
            case .remoteOverview:
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        SkillRemoteOverviewView(viewData: viewModel.viewData)
                            .padding(.horizontal, 64)
                            .padding(.vertical, 48)
                    }
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            SkillContentToolbar(fileName: viewModel.viewData.contentTitle)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.Background.surface)
    }
}

struct SkillFileContentView: View {
    let file: SkillDetailFile
    let handleMarkdownLink: (URL) -> OpenURLAction.Result

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch file.type {
            case .markdown:
                Markdown(file.content, baseURL: file.baseURL)
                    .markdownTheme(.nolon)
                    .markdownSoftBreakMode(.lineBreak)
                    .textSelection(.enabled)
                    .environment(\.openURL, OpenURLAction { url in
                        handleMarkdownLink(url)
                    })
            case .code:
                Text(file.content)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    .padding(24)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(12)
                    .textSelection(.enabled)
            case .image, .other:
                Text("Unsupported file format.")
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
            }
        }
    }
}

struct SkillEmptyStateView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)

            Text("Select a resource to view")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SkillRemoteOverviewView: View {
    let viewData: SkillDetailViewData

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Text(viewData.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(DesignSystem.Colors.Text.primary)

                Text(viewData.detailDescription)
                    .font(.system(size: 15))
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let stats = viewData.remoteStats,
               stats.stars != nil || stats.downloads != nil {
                HStack(spacing: 16) {
                    if let stars = stats.stars {
                        Label {
                            Text("\(stars) Stars")
                        } icon: {
                            Image(systemName: "star.fill")
                                .foregroundStyle(DesignSystem.Colors.Status.warning)
                        }
                    }

                    if let downloads = stats.downloads {
                        Label {
                            Text("\(downloads) Downloads")
                        } icon: {
                            Image(systemName: "arrow.down.circle")
                                .foregroundStyle(DesignSystem.Colors.Status.info)
                        }
                    }
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Latest Changes")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(DesignSystem.Colors.Text.primary)

                if let changelog = viewData.remoteChangelog,
                   !changelog.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Markdown(changelog)
                        .markdownTheme(.nolon)
                        .markdownSoftBreakMode(.lineBreak)
                        .textSelection(.enabled)
                } else if let summary = viewData.remoteSummary,
                          !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(summary)
                        .font(.system(size: 14))
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(NSLocalizedString("No detailed description available.", comment: "No description"))
                        .font(.system(size: 14))
                        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - SkillContentToolbar

struct SkillContentToolbar: View {
    let fileName: String
    
    var body: some View {
        HStack(spacing: 8) {
            Text("Resources")
                .font(.system(size: 12))
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
            
            Image(systemName: "chevron.right")
                .font(.system(size: 9))
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
            
            Text(fileName)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.Text.primary)
            
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(height: 52)
        .background(DesignSystem.Colors.Background.surface.opacity(0.85))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(DesignSystem.Colors.Component.border.opacity(0.3)),
            alignment: .bottom
        )
    }
}

// MARK: - SkillIdentityModule

struct SkillIdentityModule: View {
    let title: String
    let version: String
    let showsLocalBadge: Bool

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignSystem.Colors.primary,
                                DesignSystem.Colors.Status.info
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: DesignSystem.Colors.primary.opacity(0.4), radius: 8, x: 0, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                
                Text(title.prefix(1).uppercased())
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .lineLimit(1)
                    .foregroundStyle(DesignSystem.Colors.Text.primary)

                HStack(spacing: 6) {
                    Text("VERSION \(version)")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(4)

                    if showsLocalBadge {
                        Text(NSLocalizedString("remote.detail.local_badge", comment: "Local badge"))
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.Status.success)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DesignSystem.Colors.Status.success.opacity(0.15))
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - SkillMetadataBoard

struct SkillMetadataBoard: View {
    let metadata: [String: String]
    let covers: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            // 1. Main Grid Tiles
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 180, maximum: .infinity), spacing: 16)
            ], spacing: 16) {
                ForEach(Array(metadata.keys.sorted()), id: \.self) { key in
                    if key.lowercased() != "tags" {
                        MetadataTile(key: key, value: metadata[key] ?? "")
                    }
                }
            }
            
            // 2. Capabilities Section (Covers)
            if !covers.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 16) {
                        Text("CAPABILITIES")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                            .tracking(2.0)
                            .padding(.top, 4)
                        
                        FlowLayout(spacing: 8) {
                            ForEach(covers, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(DesignSystem.Colors.primary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(DesignSystem.Colors.primary.opacity(0.1))
                                    .cornerRadius(20)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(DesignSystem.Colors.primary.opacity(0.25), lineWidth: 1)
                                    )
                            }
                        }
                    }
                }
                .padding(24)
                .background(Color.white.opacity(0.015))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(DesignSystem.Colors.Component.border.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                )
            }
        }
    }
}

private struct MetadataTile: View {
    let key: String
    let value: String
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                icon(for: key)
                    .font(.system(size: 10))
                Text(key.uppercased())
                    .font(.system(size: 9, weight: .black))
                    .tracking(1.5)
            }
            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
            
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.Text.primary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isHovered ? Color.white.opacity(0.06) : Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isHovered ? Color.white.opacity(0.15) : Color.white.opacity(0.08), lineWidth: 1.5)
        )
        .onHover { hovering in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isHovered = hovering
            }
        }
    }
    
    @ViewBuilder
    private func icon(for key: String) -> some View {
        switch key.lowercased() {
        case "author": Image(systemName: "person.fill")
        case "category": Image(systemName: "square.grid.3x3.fill")
        case "runtime", "platform": Image(systemName: "cpu.fill")
        case "license": Image(systemName: "doc.text.fill")
        case "id": Image(systemName: "key.fill")
        case "path": Image(systemName: "folder.fill")
        default: Image(systemName: "info.circle.fill")
        }
    }
}

// MARK: - SkillAboutSection

struct SkillAboutSection: View {
    let description: String
    let metadataRows: [SkillDetailMetadataRow]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About".uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                .tracking(0.8)
            
            Text(description)
                .font(.system(size: 12))
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            if !metadataRows.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(metadataRows) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.label.uppercased())
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                                .tracking(0.6)

                            Text(row.value)
                                .font(.system(size: 11))
                                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - SkillInstallationSection

struct SkillInstallationSection: View {
    let mode: SkillDetailMode
    let providers: [SkillDetailProviderItem]
    let providerInstallationStates: [String: Bool]
    let onInstallProvider: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Installations".uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                .tracking(0.8)
                .padding(.horizontal, 24)
            
            VStack(spacing: 4) {
                ForEach(providers) { provider in
                    let isInstalled = providerInstallationStates[provider.id] ?? false

                    ProviderRow(
                        provider: provider,
                        isInstalled: isInstalled,
                        allowsAction: mode == .local || !isInstalled
                    ) {
                        onInstallProvider(provider.id)
                    }
                }
            }
            .padding(.horizontal, 12)
        }
    }
}

private struct ProviderRow: View {
    let provider: SkillDetailProviderItem
    let isInstalled: Bool
    let allowsAction: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ProviderLogoView(name: provider.name, logoName: provider.logoName, style: .iconOnly, iconSize: 24)
                    .grayscale(isInstalled ? 0 : 1.0)
                    .opacity(isInstalled ? 1.0 : 0.5)
                    .cornerRadius(5)
                
                Text(provider.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isInstalled ? DesignSystem.Colors.Text.primary : DesignSystem.Colors.Text.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Image(systemName: isInstalled ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(isInstalled ? DesignSystem.Colors.primary : DesignSystem.Colors.Text.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isInstalled ? DesignSystem.Colors.primary.opacity(0.08) : (isHovered ? Color.white.opacity(0.04) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isInstalled ? DesignSystem.Colors.primary.opacity(0.2) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!allowsAction)
        .onHover { hovering in
            isHovered = hovering && allowsAction
        }
    }
}

// MARK: - SkillSyncSection

struct SkillSyncSection: View {
    let isWorkflowLinked: Bool
    let currentProvider: SkillDetailProviderItem?
    let onToggleWorkflow: (String) -> Void
    
    var body: some View {
        Group {
            if let provider = currentProvider {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Synchronization".uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                        .tracking(0.8)
                    
                    HStack {
                        Text("Enable Sync")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.Text.primary)
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { isWorkflowLinked },
                            set: { _ in onToggleWorkflow(provider.id) }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )
                    
                    Text("AI will use this skill in \(provider.name)'s workflow.")
                        .font(.system(size: 10))
                        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                }
                .padding(.horizontal, 24)
            }
        }
    }
}

// MARK: - SkillUsageSection

struct SkillUsageSection: View {
    let scenarios: [String]
    
    var body: some View {
        Group {
            if !scenarios.isEmpty {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Use When".uppercased())
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                        .tracking(2.0)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(scenarios, id: \.self) { scenario in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 4))
                                    .padding(.top, 8)
                                    .foregroundStyle(DesignSystem.Colors.primary)
                                
                                Text(scenario)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                                    .lineSpacing(4)
                            }
                        }
                    }
                    .padding(24)
                    .background(Color.white.opacity(0.02))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(DesignSystem.Colors.Component.border.opacity(0.2), lineWidth: 1)
                    )
                }
            }
        }
    }
}

// MARK: - SkillFileNavigator

struct SkillFileNavigator: View {
    let files: [SkillDetailFile]
    let selectedFileID: String?
    let onSelectFile: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Resources".uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                .tracking(0.8)
                .padding(.horizontal, 24)
            
            VStack(spacing: 2) {
                ForEach(files) { file in
                    FileNavItem(file: file, isSelected: selectedFileID == file.id) {
                        onSelectFile(file.id)
                    }
                }
            }
            .padding(.horizontal, 12)
        }
    }
}

private struct FileNavItem: View {
    let file: SkillDetailFile
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                icon(for: file.type)
                    .font(.system(size: 14))
                    .frame(width: 16)
                
                Text(file.name)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? .white : (isHovered ? DesignSystem.Colors.Text.primary : DesignSystem.Colors.Text.secondary))
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? DesignSystem.Colors.primary : (isHovered ? Color.white.opacity(0.05) : Color.clear))
            )
            .shadow(color: isSelected ? DesignSystem.Colors.primary.opacity(0.4) : .clear, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private func icon(for type: SkillDetailFileType) -> Image {
        switch type {
        case .markdown: return Image(systemName: "doc.text")
        case .code: return Image(systemName: "chevron.left.forwardslash.chevron.right")
        case .image: return Image(systemName: "photo")
        case .other: return Image(systemName: "doc")
        }
    }
}
