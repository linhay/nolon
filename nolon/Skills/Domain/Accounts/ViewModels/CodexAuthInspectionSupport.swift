import Foundation

enum CodexAuthInspectionSupport {
    static func rawJSONString(from data: Data) -> String? {
        guard let raw = String(data: data, encoding: .utf8) else { return nil }
        guard !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return raw
    }

    static func writeInspectionFile(accountID: UUID, data: Data) -> URL? {
        let folderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("nolon-auth-inspect", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            let fileURL = folderURL.appendingPathComponent("\(accountID.uuidString.lowercased()).json")
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            return nil
        }
    }
}
