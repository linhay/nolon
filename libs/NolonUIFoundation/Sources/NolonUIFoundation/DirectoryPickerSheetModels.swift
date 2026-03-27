import Foundation

public struct DirectoryPickerCandidateInfo: Identifiable, Hashable, Sendable, Codable {
    public let id: Int
    public let path: String
    public let skillCount: Int
    public let skillNames: [String]

    public init(id: Int, path: String, skillCount: Int, skillNames: [String]) {
        self.id = id
        self.path = path
        self.skillCount = skillCount
        self.skillNames = skillNames
    }
}

public struct DirectoryPickerSheetData: Hashable, Sendable, Codable {
    public let candidates: [DirectoryPickerCandidateInfo]

    public init(candidates: [DirectoryPickerCandidateInfo]) {
        self.candidates = candidates
    }
}
