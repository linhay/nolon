import Combine
import Foundation
import SwiftUI

public enum SkillInstallationMethod: String, CaseIterable, Codable, Identifiable {
    case symlink
    case copy

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .symlink: return NSLocalizedString("install_method.symlink", comment: "Symbolic Link")
        case .copy: return NSLocalizedString("install_method.copy", comment: "Copy")
        }
    }
}

@MainActor
public class ProviderSettings: ObservableObject {
    @AppStorage("provider_paths") private var storedPathsData: Data = Data()
    @AppStorage("provider_methods") private var storedMethodsData: Data = Data()

    @Published public var paths: [SkillProvider: String] = [:] {
        didSet { savePaths() }
    }

    @Published public var installationMethods: [SkillProvider: SkillInstallationMethod] = [:] {
        didSet { saveMethods() }
    }

    public init() {
        loadSettings()
    }

    // MARK: - Accessors

    public func path(for provider: SkillProvider) -> URL {
        if let pathString = paths[provider], !pathString.isEmpty {
            return URL(fileURLWithPath: pathString)
        }
        return defaultPath(for: provider)
    }

    public func method(for provider: SkillProvider) -> SkillInstallationMethod {
        installationMethods[provider] ?? .symlink
    }

    public func updatePath(_ path: URL, for provider: SkillProvider) {
        paths[provider] = path.path
    }

    public func updateMethod(_ method: SkillInstallationMethod, for provider: SkillProvider) {
        installationMethods[provider] = method
    }

    // MARK: - Defaults

    private func defaultPath(for provider: SkillProvider) -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch provider {
        case .codex:
            return home.appendingPathComponent(".codex/skills/public")
        case .claude:
            return home.appendingPathComponent(".claude/skills")
        case .opencode:
            return home.appendingPathComponent(".config/opencode/skills")
        case .copilot:
            return home.appendingPathComponent(".copilot/skills")
        case .gemini:
            return home.appendingPathComponent(".gemini/skills")
        case .antigravity:
            return home.appendingPathComponent(".gemini/antigravity/skills")
        }
    }

    // MARK: - Persistence

    private func loadSettings() {
        if let decodedPaths = try? JSONDecoder().decode(
            [SkillProvider: String].self, from: storedPathsData)
        {
            self.paths = decodedPaths
        } else {
            // Initialize with defaults if empty
            for provider in SkillProvider.allCases {
                self.paths[provider] = defaultPath(for: provider).path
            }
        }

        if let decodedMethods = try? JSONDecoder().decode(
            [SkillProvider: SkillInstallationMethod].self, from: storedMethodsData)
        {
            self.installationMethods = decodedMethods
        } else {
            // Default to symlink
            for provider in SkillProvider.allCases {
                self.installationMethods[provider] = .symlink
            }
        }
    }

    private func savePaths() {
        if let encoded = try? JSONEncoder().encode(paths) {
            storedPathsData = encoded
        }
    }

    private func saveMethods() {
        if let encoded = try? JSONEncoder().encode(installationMethods) {
            storedMethodsData = encoded
        }
    }
}
