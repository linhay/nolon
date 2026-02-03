import Foundation

public enum SkillInstallationMethod: String, CaseIterable, Codable, Identifiable, Sendable {
    case symlink
    case copy

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .symlink:
            return NSLocalizedString("install_method.symlink", comment: "Symbolic Link")
        case .copy:
            return NSLocalizedString("install_method.copy", comment: "Copy")
        }
    }
}
