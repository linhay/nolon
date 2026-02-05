import SwiftUI
import MarkdownUI
import Observation
import STFilePath

@MainActor
@Observable
final class RemoteLocalSkillDetailViewModel {
    let localPath: String
    private let fallbackName: String
    private let fallbackDescription: String?
    private let fallbackVersion: String?
    private let fallbackUpdatedAt: Date

    var name: String
    var description: String
    var version: String
    var lastUpdated: Date
    var files: [SkillFile] = []
    var selectedFile: SkillFile?

    private var hasLoaded = false

    init(skill: RemoteSkill, localPath: String) {
        self.localPath = localPath
        self.fallbackName = skill.displayName
        self.fallbackDescription = skill.summary
        self.fallbackVersion = skill.latestVersion?.version
        self.fallbackUpdatedAt = Date(timeIntervalSince1970: skill.updatedAt)

        self.name = skill.displayName
        self.description = skill.summary ?? NSLocalizedString(
            "No detailed description available.",
            comment: "No description"
        )
        self.version = skill.latestVersion?.version ?? "1.0.0"
        self.lastUpdated = Date(timeIntervalSince1970: skill.updatedAt)
    }

    func load() {
        guard !hasLoaded else { return }
        hasLoaded = true

        loadMetadata()
        loadFiles()
    }

    private func loadMetadata() {
        let skillMdPath = (localPath as NSString).appendingPathComponent("SKILL.md")
        guard STFile(skillMdPath).isExists, let content = try? STFile(skillMdPath).read() else {
            name = fallbackName
            description = fallbackDescription
                ?? NSLocalizedString("No detailed description available.", comment: "No description")
            version = fallbackVersion ?? "1.0.0"
            lastUpdated = fallbackUpdatedAt
            return
        }

        let metadata = FrontmatterParser.parseMetadata(from: content)
        if metadata.isEmpty {
            name = fallbackName
            description = fallbackDescription
                ?? NSLocalizedString("No detailed description available.", comment: "No description")
            version = fallbackVersion ?? "1.0.0"
        } else {
            name = metadata["name"] ?? fallbackName
            description = metadata["description"]
                ?? fallbackDescription
                ?? NSLocalizedString("No detailed description available.", comment: "No description")
            version = metadata["version"] ?? fallbackVersion ?? "1.0.0"
        }

        if let modified = STFile(skillMdPath).attributes.modificationDate {
            lastUpdated = modified
        } else {
            lastUpdated = fallbackUpdatedAt
        }
    }

    private func loadFiles() {
        let rootURL = URL(fileURLWithPath: localPath)
        var loadedFiles: [SkillFile] = []

        let skillMdURL = rootURL.appendingPathComponent("SKILL.md")
        if STFile(skillMdURL).isExists {
            loadedFiles.append(SkillFile(name: "SKILL.md", url: skillMdURL, type: .markdown))
        }

        func scanSubdir(_ name: String) {
            let dirURL = rootURL.appendingPathComponent(name)
            let folder = STFolder(dirURL)
            guard let contents = try? folder.files() else { return }

            for file in contents {
                let url = file.url
                if url.lastPathComponent.hasPrefix(".") { continue }
                loadedFiles.append(SkillFile(name: "\(name)/\(url.lastPathComponent)", url: url, type: determineType(url)))
            }
        }

        scanSubdir("references")
        scanSubdir("scripts")

        files = loadedFiles
        if selectedFile == nil {
            selectedFile = loadedFiles.first
        }
    }

    private func determineType(_ url: URL) -> SkillFile.SkillFileType {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "md", "markdown": return .markdown
        case "png", "jpg", "jpeg", "gif": return .image
        case "swift", "js", "py", "sh", "json", "yaml", "yml": return .code
        default: return .other
        }
    }
}

struct RemoteLocalSkillDetailView: View {
    let skill: RemoteSkill
    let localPath: String

    @State private var viewModel: RemoteLocalSkillDetailViewModel
    @Environment(\.dismiss) private var dismiss

    init(skill: RemoteSkill, localPath: String) {
        self.skill = skill
        self.localPath = localPath
        self._viewModel = State(initialValue: RemoteLocalSkillDetailViewModel(skill: skill, localPath: localPath))
    }

    var body: some View {
        VStack(spacing: 12) {
            SheetHeaderView(title: viewModel.name) {
                dismiss()
            }

            HStack(spacing: 0) {
                RemoteLocalSkillDetailSidebar(viewModel: viewModel)
                    .frame(width: 210)
                    .background(DesignSystem.Colors.Background.elevated)

                Divider()
                    .background(DesignSystem.Colors.Component.separator.opacity(0.6))

                RemoteLocalSkillDetailContent(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DesignSystem.Colors.Background.surface)

                Divider()
                    .background(DesignSystem.Colors.Component.separator.opacity(0.6))

                RemoteLocalSkillDetailInspector(viewModel: viewModel, localPath: localPath)
                    .frame(width: 240)
                    .background(DesignSystem.Colors.Background.elevated)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(DesignSystem.Colors.Component.border.opacity(0.4), lineWidth: 1)
            )
        }
        .task {
            viewModel.load()
        }
    }
}

private struct RemoteLocalSkillDetailSidebar: View {
    @Bindable var viewModel: RemoteLocalSkillDetailViewModel

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(viewModel.name)
                        .font(.headline)
                        .foregroundStyle(DesignSystem.Colors.Text.primary)
                        .lineLimit(2)

                    Spacer(minLength: 0)
                }

                HStack(spacing: 8) {
                    Text(String(format: NSLocalizedString("v%@", comment: "Version badge"), viewModel.version))
                        .font(.caption2)
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(DesignSystem.Colors.Background.surface.opacity(0.8))
                        .clipShape(Capsule())

                    Text(NSLocalizedString("remote.detail.local_badge", comment: "Local badge"))
                        .font(.caption2)
                        .foregroundStyle(DesignSystem.Colors.Status.success)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(DesignSystem.Colors.Status.success.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .padding(16)

            Divider()
                .background(DesignSystem.Colors.Component.separator.opacity(0.6))

            List(selection: $viewModel.selectedFile) {
                Section(NSLocalizedString("remote.detail.files_title", comment: "Files")) {
                    ForEach(viewModel.files) { file in
                        Label {
                            Text(file.name)
                        } icon: {
                            icon(for: file.type)
                                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                        }
                        .tag(file)
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func icon(for type: SkillFile.SkillFileType) -> Image {
        switch type {
        case .markdown: return Image(systemName: "doc.text")
        case .code: return Image(systemName: "curlybraces")
        case .image: return Image(systemName: "photo")
        case .other: return Image(systemName: "doc")
        }
    }
}

private struct RemoteLocalSkillDetailContent: View {
    @Bindable var viewModel: RemoteLocalSkillDetailViewModel

    var body: some View {
        Group {
            if let file = viewModel.selectedFile {
                if let content = try? String(contentsOf: file.url) {
                    if file.name == "SKILL.md" && file.type == .markdown {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                let metadata = FrontmatterParser.parseMetadata(from: content)
                                if !metadata.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text(NSLocalizedString("Metadata", comment: "Metadata"))
                                            .font(.headline)
                                            .foregroundStyle(DesignSystem.Colors.Text.secondary)

                                        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                                            ForEach(metadata.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                                GridRow(alignment: .top) {
                                                    Text(key)
                                                        .font(.caption)
                                                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                                                        .frame(width: 80, alignment: .trailing)

                                                    Text(value)
                                                        .font(.caption)
                                                        .monospaced()
                                                        .textSelection(.enabled)
                                                }
                                            }
                                        }
                                        .padding()
                                        .background(DesignSystem.Colors.Background.elevated.opacity(0.8))
                                        .cornerRadius(8)
                                    }
                                }

                                Divider()
                                    .background(DesignSystem.Colors.Component.separator.opacity(0.6))

                                let body = FrontmatterParser.stripFrontmatter(from: content)
                                Markdown(body)
                                    .textSelection(.enabled)
                            }
                            .padding()
                        }
                    } else {
                        ScrollView {
                            if file.type == .markdown {
                                Markdown(content)
                                    .padding()
                                    .textSelection(.enabled)
                            } else {
                                Text(content)
                                    .font(.system(.body, design: .monospaced))
                                    .padding()
                                    .textSelection(.enabled)
                            }
                        }
                    }
                } else {
                    ContentUnavailableView(
                        NSLocalizedString("Unable to read file", comment: "Unable to read file"),
                        systemImage: "doc.questionmark"
                    )
                }
            } else {
                ContentUnavailableView(
                    NSLocalizedString("No file selected", comment: "No file selected"),
                    systemImage: "doc"
                )
            }
        }
    }
}

private struct RemoteLocalSkillDetailInspector: View {
    @Bindable var viewModel: RemoteLocalSkillDetailViewModel
    let localPath: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("remote.detail.summary_title", comment: "Summary"))
                        .font(.headline)
                    Text(viewModel.description)
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                }

                Divider()
                    .background(DesignSystem.Colors.Component.separator.opacity(0.6))

                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("remote.detail.local_details_title", comment: "Local details"))
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top) {
                            Text(NSLocalizedString("remote.detail.path_label", comment: "Path"))
                                .font(.caption)
                                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                                .frame(width: 60, alignment: .leading)
                            Text(localPath)
                                .font(.caption)
                                .foregroundStyle(DesignSystem.Colors.Text.primary)
                                .textSelection(.enabled)
                        }

                        HStack {
                            Text(NSLocalizedString("remote.detail.updated_label", comment: "Updated"))
                                .font(.caption)
                                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                                .frame(width: 60, alignment: .leading)
                            Text(viewModel.lastUpdated, style: .date)
                                .font(.caption)
                                .foregroundStyle(DesignSystem.Colors.Text.primary)
                        }
                    }
                }

                Spacer(minLength: 8)

                Button {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: localPath)
                } label: {
                    Label(NSLocalizedString("action.show_in_finder", comment: "Show in Finder"), systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(16)
        }
    }
}
