import CryptoKit
import Foundation
import OSLog

struct CodexAccountInfo: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var createdAt: Date
}

struct CodexAccountsState: Codable, Hashable, Sendable {
    var accounts: [CodexAccountInfo]
    var lastActivatedAccountId: String?

    static let empty = CodexAccountsState(accounts: [], lastActivatedAccountId: nil)
}

final class CodexAccountsStore: @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.nolon", category: "CodexAccountsStore")

    private let nolonManager: NolonManager
    private let fileManager: FileManager

    init(nolonManager: NolonManager = .shared, fileManager: FileManager = .default) {
        self.nolonManager = nolonManager
        self.fileManager = fileManager
    }

    func load() -> CodexAccountsState {
        do {
            let url = stateURL
            guard fileManager.fileExists(atPath: url.path) else { return .empty }
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(CodexAccountsState.self, from: data)
        } catch {
            Self.logger.error("Failed to load Codex accounts: \(error.localizedDescription)")
            return .empty
        }
    }

    func save(_ state: CodexAccountsState) {
        do {
            try ensureDirectoriesExist()
            let data = try JSONEncoder().encode(state)
            try data.write(to: stateURL, options: [.atomic])
        } catch {
            Self.logger.error("Failed to save Codex accounts: \(error.localizedDescription)")
        }
    }

    func accountAuthURL(accountId: String) -> URL {
        accountsDirectoryURL.appendingPathComponent(accountId).appendingPathComponent("auth.json")
    }

    func writeAccountAuth(accountId: String, authData: Data) throws {
        try ensureDirectoriesExist()
        let folder = accountsDirectoryURL.appendingPathComponent(accountId)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        try authData.write(to: folder.appendingPathComponent("auth.json"), options: [.atomic])
    }

    func deleteAccountFiles(accountId: String) throws {
        let folder = accountsDirectoryURL.appendingPathComponent(accountId)
        if fileManager.fileExists(atPath: folder.path) {
            try fileManager.removeItem(at: folder)
        }
    }

    func hashOfAuthFile(at url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Paths

    private var codexRootURL: URL {
        nolonManager.rootURL.appendingPathComponent("providers").appendingPathComponent("codex")
    }

    private var accountsDirectoryURL: URL {
        codexRootURL.appendingPathComponent("accounts", isDirectory: true)
    }

    private var stateURL: URL {
        codexRootURL.appendingPathComponent("accounts.json")
    }

    private func ensureDirectoriesExist() throws {
        try fileManager.createDirectory(at: accountsDirectoryURL, withIntermediateDirectories: true)
    }
}

