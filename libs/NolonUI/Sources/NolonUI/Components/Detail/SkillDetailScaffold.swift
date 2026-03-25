import SwiftUI

public enum SkillDetailScaffoldMetrics {
    public static let sidebarWidth: CGFloat = 280
    public static let closeButtonSize: CGFloat = 32
    public static let closeButtonPadding: CGFloat = 16
}

public struct SkillDetailScaffold<Sidebar: View, Content: View>: View {
    @State private var viewModel = SkillDetailScaffoldViewModel()
    private let onClose: () -> Void
    private let sidebar: Sidebar
    private let content: Content

    public init(
        onClose: @escaping () -> Void,
        @ViewBuilder sidebar: () -> Sidebar,
        @ViewBuilder content: () -> Content
    ) {
        self.onClose = onClose
        self.sidebar = sidebar()
        self.content = content()
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            ThreeColumnScaffold(
                mode: .twoColumn,
                columnVisibility: $viewModel.columnVisibility,
                sidebarWidth: .init(
                    min: SkillDetailScaffoldMetrics.sidebarWidth,
                    ideal: SkillDetailScaffoldMetrics.sidebarWidth,
                    max: SkillDetailScaffoldMetrics.sidebarWidth
                )
            ) {
                sidebar
            } content: {
                EmptyView()
            } detail: {
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            FloatingCloseButton(
                help: "Close",
                enableCancelShortcut: true,
                action: onClose
            )
            .padding(SkillDetailScaffoldMetrics.closeButtonPadding)
        }
        .background(DesignSystem.Colors.Background.canvas)
        .ignoresSafeArea()
    }
}

public struct SkillDetailSidebarContainer<Content: View, Footer: View>: View {
    @State private var viewModel = SkillDetailSidebarContainerViewModel()
    private let content: Content
    private let footer: Footer

    public init(
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.content = content()
        self.footer = footer()
    }

    public var body: some View {
        VStack(spacing: 0) {
            content
            footer
        }
        .background(DesignSystem.Colors.Background.elevated)
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundStyle(DesignSystem.Colors.Component.border.opacity(0.3)),
            alignment: .trailing
        )
    }
}

private enum SkillDetailPreviewScenario {
    case standard
    case noFooter
    case longContent
    case compact
    case emptyState
    case loadingState
    case longHeader
    case footerActions
    case installProviders
    case fileSelected
}

private struct SkillDetailScaffoldPreviewContainer: View {
    let scenario: SkillDetailPreviewScenario

    var body: some View {
        SkillDetailScaffold(onClose: {}) {
            SkillDetailSidebarContainer {
                sidebarContent
            } footer: {
                footerContent
            }
        } content: {
            detailContent
        }
        .frame(width: previewSize.width, height: previewSize.height)
    }

    private var previewSize: CGSize {
        switch scenario {
        case .compact:
            return .init(width: 860, height: 560)
        case .standard, .noFooter, .longContent, .emptyState, .loadingState, .longHeader, .footerActions, .installProviders, .fileSelected:
            return .init(width: 980, height: 620)
        }
    }

    private var sidebarContent: some View {
        ScrollView {
            if scenario == .installProviders {
                installProvidersSidebar
            } else if scenario == .fileSelected {
                fileSelectedSidebar
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    Text(sidebarTitle)
                        .font(.title3.weight(.semibold))
                    Text(sidebarSubtitle)
                        .dsSecondaryText(font: .caption)
                    Divider()

                    ForEach(0..<sidebarSectionCount, id: \.self) { index in
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text")
                                .font(.caption)
                            Text("Section \(index + 1)")
                                .font(.callout)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(24)
            }
        }
    }

    @ViewBuilder
    private var footerContent: some View {
        switch scenario {
        case .noFooter:
            EmptyView()
        case .footerActions:
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 10) {
                    Button(action: {}) {
                        HStack(spacing: 6) {
                            Image(systemName: "folder")
                            Text("Show in Finder")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .background(DesignSystem.Colors.Component.controlFillSubtle)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    Button(action: {}) {
                        Image(systemName: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .background(DesignSystem.Colors.Component.controlFillSubtle)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(16)
            }
        case .standard, .longContent, .compact, .emptyState, .loadingState, .longHeader, .installProviders, .fileSelected:
            VStack(spacing: 0) {
                Divider()
                Button(action: {}) {
                    HStack(spacing: 8) {
                        Image(systemName: "folder")
                        Text("Show in Finder")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .padding(16)
            }
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch scenario {
        case .longContent:
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("README.md")
                        .font(.headline)
                    ForEach(0..<20, id: \.self) { index in
                        Text("Paragraph \(index + 1): Skill detail content preview area with longer markdown-like text.")
                            .font(.body)
                            .dsSecondaryText(font: .body)
                    }
                }
                .padding(32)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .background(DesignSystem.Colors.Background.surface)
        case .emptyState:
            VStack(spacing: 14) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                Text("Select a resource to view")
                    .font(.headline)
                Text("Choose a file from the left sidebar.")
                    .dsSecondaryText(font: .body)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesignSystem.Colors.Background.surface)
        case .loadingState:
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                Text("Loading Skill Details...")
                    .font(.headline)
                Text("Fetching metadata, files and changelog.")
                    .dsSecondaryText(font: .body)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesignSystem.Colors.Background.surface)
        case .fileSelected:
            VStack(alignment: .leading, spacing: 16) {
                Text("SKILL.md")
                    .font(.headline)
                Text("## Usage\n\nThis selected file content is shown in the right pane.")
                    .font(.body)
                    .dsSecondaryText(font: .body)
                Spacer()
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(DesignSystem.Colors.Background.surface)
        case .standard, .noFooter, .compact, .longHeader, .footerActions, .installProviders:
            VStack(alignment: .leading, spacing: 16) {
                Text("README.md")
                    .font(.headline)
                Text("Skill detail content preview area.")
                    .font(.body)
                    .dsSecondaryText(font: .body)
                Spacer()
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(DesignSystem.Colors.Background.surface)
        }
    }

    private var sidebarTitle: String {
        switch scenario {
        case .longHeader:
            return "Super Long Skill Name For Stress Testing The Sidebar Header Layout"
        default:
            return "Skill Name"
        }
    }

    private var sidebarSubtitle: String {
        switch scenario {
        case .loadingState:
            return "Resolving..."
        default:
            return "Version 1.0.0"
        }
    }

    private var sidebarSectionCount: Int {
        switch scenario {
        case .compact:
            return 5
        case .longContent, .longHeader:
            return 16
        default:
            return 8
        }
    }

    private var installProvidersSidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Installations")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                .tracking(0.8)
                .padding(.horizontal, 12)

            VStack(spacing: 6) {
                providerInstallRow(name: "Codex", icon: "c.circle.fill", isInstalled: true, allowsAction: true)
                providerInstallRow(name: "Claude Code", icon: "a.circle.fill", isInstalled: false, allowsAction: true)
                providerInstallRow(name: "MCP Server", icon: "server.rack", isInstalled: false, allowsAction: false)
                providerInstallRow(name: "OpenCode", icon: "o.circle.fill", isInstalled: true, allowsAction: true)
            }
        }
        .padding(16)
    }

    private func providerInstallRow(
        name: String,
        icon: String,
        isInstalled: Bool,
        allowsAction: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(isInstalled ? DesignSystem.Colors.primary : DesignSystem.Colors.Text.tertiary)
                .frame(width: 24, height: 24)

            Text(name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(
                    isInstalled ? DesignSystem.Colors.Text.primary : DesignSystem.Colors.Text.secondary
                )
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: isInstalled ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14))
                .foregroundStyle(isInstalled ? DesignSystem.Colors.primary : DesignSystem.Colors.Text.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isInstalled ? DesignSystem.Colors.primary.opacity(0.08) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isInstalled ? DesignSystem.Colors.primary.opacity(0.2) : Color.clear, lineWidth: 1)
        )
        .opacity(allowsAction ? 1.0 : 0.45)
    }

    private var fileSelectedSidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Files")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                .tracking(0.8)
                .padding(.horizontal, 12)

            VStack(spacing: 6) {
                fileRow(name: "README.md", isSelected: false)
                fileRow(name: "SKILL.md", isSelected: true)
                fileRow(name: "examples/basic.md", isSelected: false)
                fileRow(name: "scripts/install.sh", isSelected: false)
            }
        }
        .padding(16)
    }

    private func fileRow(name: String, isSelected: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.caption)
                .foregroundStyle(
                    isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.Text.tertiary
                )
            Text(name)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(
                    isSelected ? DesignSystem.Colors.Text.primary : DesignSystem.Colors.Text.secondary
                )
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    isSelected
                        ? DesignSystem.Colors.primary.opacity(0.12)
                        : DesignSystem.Colors.Component.controlFillSubtle.opacity(0.4)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isSelected
                        ? DesignSystem.Colors.primary.opacity(0.35)
                        : Color.clear,
                    lineWidth: 1
                )
        )
    }
}

#Preview("Standard") {
    SkillDetailScaffoldPreviewContainer(scenario: .standard)
}

#Preview("NoFooter") {
    SkillDetailScaffoldPreviewContainer(scenario: .noFooter)
}

#Preview("Long") {
    SkillDetailScaffoldPreviewContainer(scenario: .longContent)
}

#Preview("Compact") {
    SkillDetailScaffoldPreviewContainer(scenario: .compact)
}

#Preview("Empty") {
    SkillDetailScaffoldPreviewContainer(scenario: .emptyState)
}

#Preview("Loading") {
    SkillDetailScaffoldPreviewContainer(scenario: .loadingState)
}

#Preview("Header") {
    SkillDetailScaffoldPreviewContainer(scenario: .longHeader)
}

#Preview("Actions") {
    SkillDetailScaffoldPreviewContainer(scenario: .footerActions)
}

#Preview("Install") {
    SkillDetailScaffoldPreviewContainer(scenario: .installProviders)
}

#Preview("Selected") {
    SkillDetailScaffoldPreviewContainer(scenario: .fileSelected)
}
