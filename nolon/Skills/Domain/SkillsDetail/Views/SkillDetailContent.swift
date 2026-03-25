import SwiftUI
import NolonResourceKit
import MarkdownUI

struct SkillDetailContent: View {
    @Bindable var viewModel: SkillDetailViewModel
    
    var body: some View {
        Group {
            switch viewModel.contentMode {
            case .fileBrowser:
                if let file = viewModel.selectedFile {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            SkillFileContentView(
                                file: file,
                                handleMarkdownLink: viewModel.handleMarkdownLink(_:)
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
                        SkillRemoteOverviewView(viewModel: viewModel)
                            .padding(.horizontal, 64)
                            .padding(.vertical, 48)
                    }
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            SkillContentToolbar(fileName: viewModel.contentTitle)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.Background.surface)
    }
}

/// Simplified file content renderer
struct SkillFileContentView: View {
    let file: SkillFile
    let handleMarkdownLink: (URL) -> OpenURLAction.Result
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch file.type {
            case .markdown:
                Markdown(
                    FrontmatterParser.stripFrontmatter(from: file.content),
                    baseURL: file.url.deletingLastPathComponent()
                )
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
            default:
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
    @Bindable var viewModel: SkillDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Text(viewModel.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(DesignSystem.Colors.Text.primary)

                Text(viewModel.detailDescription)
                    .font(.system(size: 15))
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let stats = viewModel.remoteStats,
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

                if let changelog = viewModel.remoteChangelog,
                   !changelog.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Markdown(changelog)
                        .markdownTheme(.nolon)
                        .markdownSoftBreakMode(.lineBreak)
                        .textSelection(.enabled)
                } else if let summary = viewModel.remoteSummary,
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
