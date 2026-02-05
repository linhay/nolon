import Foundation

actor CodexAuthAccountStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileURL: URL = CodexAuthAccountStore.defaultFileURL()) {
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func load() throws -> [CodexAuthAccount] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode([CodexAuthAccount].self, from: data)
    }

    func save(_ accounts: [CodexAuthAccount]) throws {
        let folder = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)
        let data = try encoder.encode(accounts)
        try data.write(to: fileURL, options: [.atomic])
    }

    private static func defaultFileURL() -> URL {
        let root = NolonManager.shared.rootURL
        return root
            .appendingPathComponent("codex", isDirectory: true)
            .appendingPathComponent("accounts.json")
    }
}
