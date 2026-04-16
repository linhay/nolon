import Foundation

enum GeminiSessionUsageSupport {
    static func defaultSessionRoot() -> URL? {
        defaultSessionRoot(environment: ProcessInfo.processInfo.environment)
    }

    static func defaultSessionRoot(environment: [String: String]) -> URL? {
        if let home = environment["HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !home.isEmpty {
            return URL(fileURLWithPath: home, isDirectory: true)
                .appendingPathComponent(".gemini", isDirectory: true)
                .appendingPathComponent("tmp", isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".gemini", isDirectory: true)
            .appendingPathComponent("tmp", isDirectory: true)
    }

    static func defaultListSessionFiles(root: URL) throws -> [URL] {
        guard FileManager.default.fileExists(atPath: root.path) else {
            return []
        }

        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        var files: [URL] = []
        while let item = enumerator?.nextObject() as? URL {
            let values = try? item.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])

            if values?.isDirectory == true {
                guard item.lastPathComponent == "chats" else { continue }

                let chatFiles = try FileManager.default.contentsOfDirectory(
                    at: item,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                )

                for chatFile in chatFiles {
                    let chatFileValues = try? chatFile.resourceValues(forKeys: [.isRegularFileKey])
                    guard chatFileValues?.isRegularFile == true,
                          chatFile.lastPathComponent.hasPrefix("session-"),
                          chatFile.pathExtension == "json" else {
                        continue
                    }
                    files.append(chatFile)
                }

                enumerator?.skipDescendants()
                continue
            }

            guard values?.isRegularFile == true,
                  item.lastPathComponent.hasPrefix("session-"),
                  item.pathExtension == "json",
                  item.path.contains("/chats/") else {
                continue
            }
            files.append(item)
        }

        return Array(Set(files.map(\.standardizedFileURL)))
            .sorted { $0.path < $1.path }
    }
}
