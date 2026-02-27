import Foundation

public enum CodexAuthEventChangeKind: Sendable {
    case renamed
    case other
}

public enum CodexAuthEventPolicy {
    public static func shouldIgnoreKnownAuthRename(
        changedPath: String,
        kind: CodexAuthEventChangeKind,
        isAuthFolderChange: Bool,
        isAuthFileChange: Bool,
        knownAuthFileNames: Set<String>
    ) -> Bool {
        guard isAuthFolderChange, !isAuthFileChange, kind == .renamed else {
            return false
        }
        let fileName = (changedPath as NSString).lastPathComponent
        return knownAuthFileNames.contains(fileName)
    }
}

public struct CodexAuthChangeSuppressionStore: Sendable {
    private var expiryByPath: [String: Date] = [:]

    public init() {}

    public mutating func mark(
        filePath: String,
        folderPath: String,
        ttl: TimeInterval,
        now: Date = Date()
    ) {
        let expiry = now.addingTimeInterval(ttl)
        expiryByPath[filePath] = expiry
        expiryByPath[folderPath] = expiry
        cleanup(now: now)
    }

    public mutating func shouldSuppress(path: String, now: Date = Date()) -> Bool {
        cleanup(now: now)

        guard !expiryByPath.isEmpty else { return false }

        if let expiry = expiryByPath[path], expiry > now {
            return true
        }

        for (key, expiry) in expiryByPath where expiry > now {
            if path.hasPrefix(key + "/") {
                return true
            }
        }

        return false
    }

    public mutating func cleanup(now: Date = Date()) {
        expiryByPath = expiryByPath.filter { $0.value > now }
    }
}
