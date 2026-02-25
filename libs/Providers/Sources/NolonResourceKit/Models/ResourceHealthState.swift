import Foundation

public enum ResourceHealthState: String, Sendable, Equatable, Codable, CaseIterable {
    case installed
    case orphaned
    case broken
}
