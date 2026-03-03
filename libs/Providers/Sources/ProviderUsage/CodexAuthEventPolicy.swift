import Foundation

public enum CodexAuthEventChangeKind: Sendable {
    case renamed
    case other
}

public enum CodexAuthSuppressionKind: Sendable {
    case created
    case deleted
    case modified
    case renamed
    case any

    fileprivate func matches(_ other: CodexAuthSuppressionKind) -> Bool {
        self == .any || other == .any || self == other
    }
}

public enum CodexAuthEventPolicy {
    public static func shouldIgnoreKnownAuthRename(
        changedPath: String,
        kind: CodexAuthEventChangeKind,
        isAuthFolderChange: Bool,
        isAuthFileChange: Bool,
        knownAuthFileNames: Set<String>
    ) -> Bool {
        guard !isAuthFolderChange, !isAuthFileChange, kind == .renamed else {
            return false
        }
        let fileName = (changedPath as NSString).lastPathComponent
        return knownAuthFileNames.contains(fileName)
    }
}

public struct CodexAuthChangeSuppressionStore: Sendable {
    private struct Entry: Sendable {
        let operationID: UUID
        let path: String
        let kind: CodexAuthSuppressionKind
        let expiry: Date
    }

    private var entries: [Entry] = []

    public init() {}

    public mutating func mark(
        filePath: String,
        folderPath: String,
        ttl: TimeInterval,
        now: Date = Date()
    ) {
        markOperation(
            filePath: filePath,
            folderPath: folderPath,
            kind: .any,
            ttl: ttl,
            now: now
        )
    }

    public mutating func markOperation(
        filePath: String,
        folderPath: String,
        kind: CodexAuthSuppressionKind,
        ttl: TimeInterval = 30,
        now: Date = Date()
    ) {
        let expiry = now.addingTimeInterval(ttl)
        let operationID = UUID()
        entries.append(Entry(operationID: operationID, path: filePath, kind: kind, expiry: expiry))
        entries.append(Entry(operationID: operationID, path: folderPath, kind: kind, expiry: expiry))
        cleanup(now: now)
    }

    public mutating func consumeSuppression(
        path: String,
        kind: CodexAuthSuppressionKind,
        now: Date = Date()
    ) -> Bool {
        cleanup(now: now)

        guard !entries.isEmpty else { return false }

        if let matched = entries.first(where: { entry in
            guard entry.kind.matches(kind) else { return false }
            return path == entry.path || path.hasPrefix(entry.path + "/")
        }) {
            entries.removeAll { $0.operationID == matched.operationID }
            return true
        }
        return false
    }

    public mutating func shouldSuppress(path: String, now: Date = Date()) -> Bool {
        consumeSuppression(path: path, kind: .any, now: now)
    }

    public mutating func cleanup(now: Date = Date()) {
        entries.removeAll { $0.expiry <= now }
    }
}
