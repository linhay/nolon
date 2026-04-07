import SwiftUI
import Observation
import STFilePath
import NolonResourceKit
import NolonUI
import NolonUIFoundation

struct NolonAgentsProfile: Identifiable, Hashable {
    let id: String
    let fileName: String
    let path: String
    let preview: String
    let isActive: Bool
    let isPrimary: Bool
}

final class NolonAgentsProfilesService {
    private let fileManager: FileManager
    private let nolonManager: NolonManager

    init(
        fileManager: FileManager = .default,
        nolonManager: NolonManager = .shared
    ) {
        self.fileManager = fileManager
        self.nolonManager = nolonManager
    }

    var agentsFolderURL: URL { nolonManager.agentsURL }
    var activeAgentsURL: URL { agentsFolderURL.appendingPathComponent("AGENTS.md") }
    var overrideAgentsURL: URL { agentsFolderURL.appendingPathComponent("AGENTS.override.md") }

    func listProfiles() throws -> [NolonAgentsProfile] {
        ensureAgentsFolderExists()

        let activeProfilePath = try resolveActiveProfilePath()
        let entries = try fileManager.contentsOfDirectory(
            at: agentsFolderURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        )

        let candidates = entries.filter { url in
            guard url.pathExtension.lowercased() == "md" else { return false }
            let name = url.lastPathComponent
            return name != "AGENTS.override.md"
        }

        let profiles = candidates.compactMap { url -> NolonAgentsProfile? in
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            let preview = firstNonEmptyLine(from: content)
            let normalizedPath = url.standardizedFileURL.path
            return NolonAgentsProfile(
                id: normalizedPath,
                fileName: url.lastPathComponent,
                path: normalizedPath,
                preview: preview,
                isActive: activeProfilePath == normalizedPath,
                isPrimary: url.lastPathComponent == "AGENTS.md"
            )
        }

        return profiles.sorted { lhs, rhs in
            if lhs.isActive != rhs.isActive { return lhs.isActive }
            if lhs.isPrimary != rhs.isPrimary { return lhs.isPrimary }
            return lhs.fileName.localizedCaseInsensitiveCompare(rhs.fileName) == .orderedAscending
        }
    }

    @discardableResult
    func createProfile() throws -> URL {
        ensureAgentsFolderExists()
        let targetURL = try nextProfileURL()
        let template = """
        # AGENTS Profile

        Describe this profile's instructions here.
        """
        try template.write(to: targetURL, atomically: true, encoding: .utf8)
        return targetURL
    }

    func activateProfile(at profilePath: String) throws {
        ensureAgentsFolderExists()
        let profileURL = URL(fileURLWithPath: profilePath).standardizedFileURL
        let primaryURL = activeAgentsURL.standardizedFileURL

        guard fileManager.fileExists(atPath: profileURL.path) else {
            throw NSError(domain: "NolonAgentsProfilesService", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Profile file does not exist."
            ])
        }

        if profileURL.path == primaryURL.path {
            if STPath(primaryURL).isSymbolicLink {
                let content = (try? String(contentsOf: primaryURL, encoding: .utf8)) ?? ""
                try STPath(primaryURL).deleteIncludingBrokenSymlink()
                try content.write(to: primaryURL, atomically: true, encoding: .utf8)
            }
            return
        }

        if fileManager.fileExists(atPath: primaryURL.path), !STPath(primaryURL).isSymbolicLink {
            let localBackupURL = agentsFolderURL.appendingPathComponent("AGENTS.local.md")
            if !fileManager.fileExists(atPath: localBackupURL.path),
               let content = try? String(contentsOf: primaryURL, encoding: .utf8),
               !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try content.write(to: localBackupURL, atomically: true, encoding: .utf8)
            }
            try STPath(primaryURL).deleteIncludingBrokenSymlink()
        } else if STPath(primaryURL).isSymbolicLink {
            try STPath(primaryURL).deleteIncludingBrokenSymlink()
        }

        try fileManager.createSymbolicLink(at: primaryURL, withDestinationURL: profileURL)
    }

    func deleteProfile(at profilePath: String) throws {
        ensureAgentsFolderExists()
        let profileURL = URL(fileURLWithPath: profilePath).standardizedFileURL
        let primaryURL = activeAgentsURL.standardizedFileURL

        guard fileManager.fileExists(atPath: profileURL.path) else { return }
        guard profileURL.path != primaryURL.path else {
            throw NSError(domain: "NolonAgentsProfilesService", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Cannot delete AGENTS.md directly."
            ])
        }

        let activeProfilePath = try resolveActiveProfilePath()
        if activeProfilePath == profileURL.path {
            if STPath(primaryURL).isSymbolicLink {
                try STPath(primaryURL).deleteIncludingBrokenSymlink()
            }
            let fallback = """
            # AGENTS.md

            Fill instructions for active agents here.
            """
            try fallback.write(to: primaryURL, atomically: true, encoding: .utf8)
        }

        try STPath(profileURL).deleteIncludingBrokenSymlink()
    }

    private func ensureAgentsFolderExists() {
        _ = STFolder(agentsFolderURL).createIfNotExists()
    }

    private func resolveActiveProfilePath() throws -> String? {
        let primaryPath = activeAgentsURL.standardizedFileURL.path
        guard fileManager.fileExists(atPath: primaryPath) else { return nil }

        if STPath(primaryPath).isSymbolicLink {
            let destination = try fileManager.destinationOfSymbolicLink(atPath: primaryPath)
            let resolved = URL(fileURLWithPath: destination, relativeTo: activeAgentsURL.deletingLastPathComponent())
                .standardizedFileURL
            return resolved.path
        }
        return primaryPath
    }

    private func nextProfileURL() throws -> URL {
        let entries = try fileManager.contentsOfDirectory(atPath: agentsFolderURL.path)
        let used = Set(entries)
        var index = 1
        while true {
            let fileName = "AGENTS.profile-\(index).md"
            if !used.contains(fileName) {
                return agentsFolderURL.appendingPathComponent(fileName)
            }
            index += 1
        }
    }

    private func firstNonEmptyLine(from content: String) -> String {
        content
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? ""
    }
}

@MainActor
@Observable
final class NolonAgentsManagementViewModel {
    var profiles: [NolonAgentsProfile] = []
    var searchText = ""
    var errorMessage: String?

    private let service: NolonAgentsProfilesService

    init(service: NolonAgentsProfilesService = NolonAgentsProfilesService()) {
        self.service = service
    }

    var filteredProfiles: [NolonAgentsProfile] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return profiles }
        return profiles.filter {
            $0.fileName.localizedCaseInsensitiveContains(query)
            || $0.preview.localizedCaseInsensitiveContains(query)
        }
    }

    var filteredAgentDocs: [AgentDocInfo] {
        filteredProfiles.map { profile in
            AgentDocInfo(
                id: profile.id,
                fileName: profile.fileName,
                path: profile.path,
                preview: profile.preview,
                kind: profile.isPrimary ? .base : .override
            )
        }
    }

    func load() {
        do {
            profiles = try service.listProfiles()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createProfile() {
        do {
            _ = try service.createProfile()
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func activate(_ profile: NolonAgentsProfile) {
        do {
            try service.activateProfile(at: profile.path)
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ profile: NolonAgentsProfile) {
        do {
            try service.deleteProfile(at: profile.path)
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func revealInFinder(_ profile: NolonAgentsProfile) {
        NSWorkspace.shared.selectFile(profile.path, inFileViewerRootedAtPath: "")
    }

    func openInEditor(_ profile: NolonAgentsProfile) {
        NSWorkspace.shared.open(URL(fileURLWithPath: profile.path))
    }
}

struct NolonAgentsManagementView: View {
    @State private var viewModel = NolonAgentsManagementViewModel()
    private let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 300), alignment: .top)
    ]

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                TextField(
                    NSLocalizedString("detail.search_placeholder", value: "Search", comment: "Search placeholder"),
                    text: $viewModel.searchText
                )
                .textFieldStyle(.roundedBorder)

                Button {
                    viewModel.createProfile()
                } label: {
                    Label(
                        NSLocalizedString("action.new", value: "New", comment: "New action"),
                        systemImage: "plus"
                    )
                }
                .buttonStyle(.borderedProminent)
            }

            NolonUI.ProviderTabSectionView(warningMessage: viewModel.errorMessage) {
                NolonUI.ProviderResourceGridSectionView(
                    isEmpty: viewModel.filteredAgentDocs.isEmpty,
                    searchText: viewModel.searchText,
                    kind: .agents,
                    noResultsDescription: NSLocalizedString(
                        "remote.search.no_results_desc",
                        value: "No matching workflows found",
                        comment: "No search results description"
                    ),
                    columns: columns
                ) {
                    ForEach(viewModel.filteredProfiles) { profile in
                        NolonUI.AgentDocCardView(
                            doc: AgentDocInfo(
                                id: profile.id,
                                fileName: profile.fileName,
                                path: profile.path,
                                preview: profile.preview,
                                kind: profile.isPrimary ? .base : .override
                            ),
                            searchText: viewModel.searchText,
                            onReveal: { viewModel.revealInFinder(profile) },
                            onDelete: { viewModel.delete(profile) },
                            onTap: { viewModel.openInEditor(profile) }
                        ) { _ in
                            if !profile.isActive {
                                Button("Use") {
                                    viewModel.activate(profile)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .onAppear {
            viewModel.load()
        }
    }
}
