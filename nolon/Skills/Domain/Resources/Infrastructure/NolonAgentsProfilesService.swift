import Foundation
import STFilePath
import NolonResourceKit

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
