import SwiftUI
import MarkdownUI
import NolonUIFoundation

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
