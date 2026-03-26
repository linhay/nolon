import SwiftUI
import ProviderCatalog
import MarkdownUI
import Observation
import STFilePath
import OSLog
import NolonResourceKit

struct SkillFile: Identifiable, Hashable {
    var id: String { url.path }
    let name: String
    let url: URL
    let type: SkillFileType

    var content: String {
        (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    enum SkillFileType {
        case markdown
        case code
        case image
        case other
    }
}

enum SkillDetailMode: Equatable {
    case local
    case remoteInstalled
    case remoteCatalog
}

enum SkillDetailContentMode: Equatable {
    case fileBrowser
    case remoteOverview
}

struct SkillDetailRemoteStats: Equatable {
    let stars: Int?
    let downloads: Int?
}

struct SkillDetailMetadataRow: Identifiable, Equatable {
    let id: String
    let label: String
    let value: String
}

@MainActor
@Observable
final class SkillDetailViewModel {
    private static let logger = Logger(subsystem: "nolon", category: "SkillDetail")

    let localSkill: Skill?
    let remoteSkill: RemoteSkill?

    var title: String
    var detailDescription: String
    var version: String
    var lastUpdated: Date?

    var files: [SkillFile] = []
    var selectedFile: SkillFile?
    var providerInstallationStates: [String: Bool] = [:]
    var isWorkflowLinked: Bool = false

    private let repository = SkillRepository()
    private let installer: SkillInstaller?
    private let remoteInstallAction: ((RemoteSkill, Provider) -> Void)?

    init(skill: Skill, settings: ProviderSettings) {
        self.localSkill = skill
        self.remoteSkill = nil
        self.title = skill.name
        self.detailDescription = skill.description
        self.version = skill.version
        self.lastUpdated = nil
        self.installer = SkillInstaller(repository: repository, settings: settings)
        self.remoteInstallAction = nil
    }

    init(
        remoteSkill: RemoteSkill,
        onInstall: ((RemoteSkill, Provider) -> Void)? = nil
    ) {
        self.localSkill = nil
        self.remoteSkill = remoteSkill
        self.title = remoteSkill.displayName
        self.detailDescription = remoteSkill.summary
            ?? NSLocalizedString("No detailed description available.", comment: "No description")
        self.version = remoteSkill.latestVersion?.version ?? "1.0.0"
        self.lastUpdated = Date(timeIntervalSince1970: remoteSkill.updatedAt)
        self.installer = nil
        self.remoteInstallAction = onInstall
    }

    var detailMode: SkillDetailMode {
        if localSkill != nil {
            return .local
        }
        return resolvedRootURL != nil ? .remoteInstalled : .remoteCatalog
    }

    var contentMode: SkillDetailContentMode {
        detailMode == .remoteCatalog ? .remoteOverview : .fileBrowser
    }

    var showsFileNavigator: Bool {
        contentMode == .fileBrowser && !files.isEmpty
    }

    var showsRevealInFinder: Bool {
        resolvedRootURL != nil
    }

    var showsSyncSection: Bool {
        detailMode == .local
    }

    var showsLocalBadge: Bool {
        detailMode == .remoteInstalled
    }

    var contentTitle: String {
        switch contentMode {
        case .fileBrowser:
            return selectedFile?.name ?? "SKILL.md"
        case .remoteOverview:
            return NSLocalizedString("Overview", comment: "Remote skill overview title")
        }
    }

    var aboutMetadataRows: [SkillDetailMetadataRow] {
        guard detailMode == .remoteInstalled, let rootURL = resolvedRootURL else { return [] }

        var rows: [SkillDetailMetadataRow] = [
            .init(id: "path", label: NSLocalizedString("Path", comment: "Path"), value: rootURL.path)
        ]

        if let lastUpdated {
            rows.append(
                .init(
                    id: "updated",
                    label: NSLocalizedString("Updated", comment: "Updated"),
                    value: DateFormatter.skillDetailSidebar.string(from: lastUpdated)
                )
            )
        }

        return rows
    }

    var remoteStats: SkillDetailRemoteStats? {
        guard let remoteSkill else { return nil }
        return .init(stars: remoteSkill.stats?.stars, downloads: remoteSkill.stats?.downloads)
    }

    var remoteChangelog: String? {
        remoteSkill?.latestVersion?.changelog
    }

    var remoteSummary: String? {
        remoteSkill?.summary
    }

    var installSectionTitle: String {
        NSLocalizedString("Installations", comment: "Installations")
    }

    var summary: String {
        let baseDescription = localSkill?.description ?? detailDescription
        let parts = baseDescription.components(separatedBy: ". Use when")
        return parts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? baseDescription
    }

    var useWhen: [String] {
        let sourceDescription = localSkill?.description ?? detailDescription
        guard let range = sourceDescription.range(of: "Use when\\s+", options: [.caseInsensitive, .regularExpression]) else { return [] }
        let remaining = sourceDescription[range.upperBound...]
        let useWhenPart = remaining.components(separatedBy: " Covers").first ?? String(remaining)
        return useWhenPart
            .replacingOccurrences(of: ".", with: "")
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var covers: [String] {
        let sourceDescription = localSkill?.description ?? detailDescription
        guard let range = sourceDescription.range(of: "Covers\\s+", options: [.caseInsensitive, .regularExpression]) else {
            if let tags = metadata["Tags"] {
                return tags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            }
            return []
        }
        return sourceDescription[range.upperBound...]
            .replacingOccurrences(of: ".", with: "")
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var metadata: [String: String] {
        if let skill = localSkill {
            var dict = [
                "ID": skill.id,
                "Version": skill.version,
                "References": "\(skill.referenceCount)",
                "Scripts": "\(skill.scriptCount)",
                "Path": skill.globalPath
            ]

            if let coversRange = skill.description.range(of: "Covers:?\\s*", options: [.caseInsensitive, .regularExpression]) {
                let tagsPart = skill.description[coversRange.upperBound...]
                dict["Tags"] = tagsPart.replacingOccurrences(of: ".", with: "")
            } else if skill.description.contains("Use when") {
                let keywords = ["UICollectionView", "Combine", "SwiftUI", "Performance", "Layout"]
                let found = keywords.filter { skill.description.contains($0) }
                if !found.isEmpty {
                    dict["Tags"] = found.joined(separator: ", ")
                }
            }

            if skill.content.contains("Swift 6") || skill.description.contains("Swift 6") {
                dict["Runtime"] = "Swift 6.0"
            }

            return dict
        }

        guard let remoteSkill else { return [:] }
        var dict: [String: String] = [
            "ID": remoteSkill.slug,
            "Version": version
        ]
        if let rootURL = resolvedRootURL {
            dict["Path"] = rootURL.path
        }
        return dict
    }

    func loadData(checkProviders: [Provider], currentProvider: Provider?) async {
        if contentMode == .fileBrowser {
            loadFiles()
            if detailMode == .remoteInstalled {
                loadInstalledRemoteMetadata()
            }
        }
        await checkInstallationStatus(providers: checkProviders)
        if let provider = currentProvider, detailMode == .local {
            checkWorkflowStatus(for: provider)
        }
    }

    func performInstallationAction(for provider: Provider) async {
        switch detailMode {
        case .local:
            await toggleLocalInstallation(for: provider)
        case .remoteInstalled, .remoteCatalog:
            installRemoteSkill(to: provider)
        }
    }

    func revealInFinder() {
        guard let rootURL = resolvedRootURL else { return }
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: rootURL.path)
    }

    func handleMarkdownLink(_ url: URL) -> OpenURLAction.Result {
        if selectSkillFile(for: url) {
            return .handled
        }

        NSWorkspace.shared.open(url)
        return .handled
    }

    func checkWorkflowStatus(for provider: Provider) {
        guard let skill = localSkill else { return }
        let workflowPath = provider.workflowPath + "/" + skill.id + ".md"
        isWorkflowLinked = STFile(workflowPath).isExists
    }

    func toggleWorkflow(for provider: Provider) {
        guard localSkill != nil else { return }
        if isWorkflowLinked {
            deleteWorkflow(for: provider)
        } else {
            createWorkflow(for: provider)
        }
        checkWorkflowStatus(for: provider)
    }

    private var resolvedRootURL: URL? {
        if let localSkill {
            return URL(fileURLWithPath: localSkill.globalPath, isDirectory: true)
        }

        guard let path = remoteSkill?.localPath?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty
        else {
            return nil
        }

        let url = URL(fileURLWithPath: path, isDirectory: true)
        let skillMarkdown = url.appendingPathComponent("SKILL.md")
        return STFile(skillMarkdown).isExists ? url : nil
    }

    private var installationLookupSlug: String {
        localSkill?.id ?? remoteSkill?.slug ?? ""
    }

    private func loadFiles() {
        guard let rootURL = resolvedRootURL else {
            files = []
            selectedFile = nil
            return
        }

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
        if selectedFile == nil || !loadedFiles.contains(selectedFile!) {
            selectedFile = loadedFiles.first
        }
    }

    private func loadInstalledRemoteMetadata() {
        guard detailMode == .remoteInstalled,
              let rootURL = resolvedRootURL
        else {
            return
        }

        let skillMdURL = rootURL.appendingPathComponent("SKILL.md")
        guard STFile(skillMdURL).isExists,
              let content = try? STFile(skillMdURL).read()
        else {
            return
        }

        let metadata = FrontmatterParser.parseMetadata(from: content)
        if let name = metadata["name"], !name.isEmpty {
            title = name
        }
        if let description = metadata["description"], !description.isEmpty {
            detailDescription = description
        }
        if let version = metadata["version"], !version.isEmpty {
            self.version = version
        }
        lastUpdated = STFile(skillMdURL).attributes.modificationDate
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

    private func checkInstallationStatus(providers: [Provider]) async {
        for provider in providers {
            let paths = [provider.defaultSkillsPath] + (provider.additionalSkillsPaths ?? [])
            let exists = paths.contains { path in
                STPath("\(path)/\(installationLookupSlug)").isExists || STPath("\(path)/\(installationLookupSlug)").isSymbolicLink
            }
            providerInstallationStates[provider.id] = exists
        }
    }

    private func toggleLocalInstallation(for provider: Provider) async {
        guard let skill = localSkill, let installer else { return }
        let isInstalled = providerInstallationStates[provider.id] ?? false

        do {
            if isInstalled {
                try installer.uninstall(skill: skill, from: provider)
            } else {
                try installer.install(skill: skill, to: provider)
            }
            await checkInstallationStatus(providers: [provider])
        } catch {
            Self.logger.error("Failed to toggle installation for \(provider.name, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private func installRemoteSkill(to provider: Provider) {
        guard let remoteSkill else { return }
        guard providerInstallationStates[provider.id] != true else { return }
        remoteInstallAction?(remoteSkill, provider)
        providerInstallationStates[provider.id] = true
    }

    private func createWorkflow(for provider: Provider) {
        guard let skill = localSkill, let installer else { return }
        do {
            try installer.installWorkflow(skill: skill, to: provider)
        } catch {
            Self.logger.error("Failed to create workflow for \(provider.name, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private func deleteWorkflow(for provider: Provider) {
        guard let skill = localSkill, let installer else { return }
        do {
            try installer.uninstallWorkflow(skill: skill, from: provider)
        } catch {
            Self.logger.error("Failed to delete workflow for \(provider.name, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private func selectSkillFile(for url: URL) -> Bool {
        guard let rootURL = resolvedRootURL else { return false }

        let resolvedURL = resolvedMarkdownLinkURL(for: url)
        guard resolvedURL.isFileURL else { return false }

        let standardizedRoot = rootURL.standardizedFileURL.path
        let standardizedTarget = resolvedURL.standardizedFileURL.path
        guard standardizedTarget.hasPrefix(standardizedRoot) else { return false }

        if let matched = files.first(where: { $0.url.standardizedFileURL == resolvedURL.standardizedFileURL }) {
            selectedFile = matched
            return true
        }

        return false
    }

    private func resolvedMarkdownLinkURL(for url: URL) -> URL {
        guard !url.isFileURL, url.scheme == nil else {
            return url.removingFragment()
        }

        guard let rootURL = resolvedRootURL else {
            return url.removingFragment()
        }

        return rootURL.appendingPathComponent(url.relativeString).removingFragment()
    }
}

private extension URL {
    func removingFragment() -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return self
        }

        components.fragment = nil
        return components.url ?? self
    }
}

private extension DateFormatter {
    static let skillDetailSidebar: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}
