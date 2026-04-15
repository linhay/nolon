import Foundation
import STFilePath

public enum CodexSessionScanner {
    public struct DayRange: Sendable, Equatable {
        public let sinceKey: String
        public let untilKey: String

        public init(sinceKey: String, untilKey: String) {
            self.sinceKey = sinceKey
            self.untilKey = untilKey
        }

        public init(since: Date, until: Date) {
            self.init(
                sinceKey: Self.dayKey(from: since),
                untilKey: Self.dayKey(from: until)
            )
        }

        public static func dayKey(from date: Date) -> String {
            let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
            let year = components.year ?? 1970
            let month = components.month ?? 1
            let day = components.day ?? 1
            return String(format: "%04d-%02d-%02d", year, month, day)
        }

        public static func isInRange(dayKey: String, since: String, until: String) -> Bool {
            guard dayKey >= since else { return false }
            guard dayKey <= until else { return false }
            return true
        }
    }

    public struct ScannedFile: Sendable, Equatable {
        public let file: STFile
        public let relativePath: String
        public let archived: Bool
        public let fileIdentity: String?

        public init(
            file: STFile,
            relativePath: String,
            archived: Bool,
            fileIdentity: String?
        ) {
            self.file = file
            self.relativePath = relativePath
            self.archived = archived
            self.fileIdentity = fileIdentity
        }
    }

    public struct SessionMeta: Sendable, Equatable {
        public let threadID: String?
        public let forkedFromID: String?
        public let originator: String?
        public let source: String?
        public let modelProvider: String?
        public let cwd: String?
        public let timestamp: String?

        public init(
            threadID: String?,
            forkedFromID: String?,
            originator: String?,
            source: String?,
            modelProvider: String?,
            cwd: String?,
            timestamp: String?
        ) {
            self.threadID = threadID
            self.forkedFromID = forkedFromID
            self.originator = originator
            self.source = source
            self.modelProvider = modelProvider
            self.cwd = cwd
            self.timestamp = timestamp
        }
    }

    public static func scanFiles(
        codexHome: STFolder,
        includeArchived: Bool = true,
        dayRange: DayRange? = nil
    ) -> [ScannedFile] {
        scanFiles(
            sessionsRoot: codexHome.folder("sessions"),
            includeArchivedSibling: includeArchived,
            dayRange: dayRange
        )
    }

    public static func scanFiles(
        sessionsRoot: STFolder,
        includeArchivedSibling: Bool = true,
        dayRange: DayRange? = nil
    ) -> [ScannedFile] {
        var roots = [sessionsRoot]
        if includeArchivedSibling, let archivedRoot = archivedSessionsRoot(for: sessionsRoot) {
            roots.append(archivedRoot)
        }

        var seenPaths: Set<String> = []
        var scannedFiles: [ScannedFile] = []

        for root in roots {
            let files = listJSONLFiles(root: root, dayRange: dayRange)
            for file in files where seenPaths.insert(file.url.path).inserted {
                scannedFiles.append(
                    ScannedFile(
                        file: file,
                        relativePath: relativePath(for: file.url.path, baseURL: root.parentFolder()?.url),
                        archived: root.url.lastPathComponent == "archived_sessions",
                        fileIdentity: fileIdentityString(file: file)
                    )
                )
            }
        }

        return scannedFiles.sorted { lhs, rhs in
            lhs.file.url.path < rhs.file.url.path
        }
    }

    public static func readSessionMeta(from file: ScannedFile) -> SessionMeta? {
        guard let handle = try? FileHandle(forReadingFrom: file.file.url) else { return nil }
        defer { try? handle.close() }

        var pending = Data()
        let chunkSize = 16 * 1024

        while true {
            let chunk = handle.readData(ofLength: chunkSize)
            if chunk.isEmpty {
                break
            }
            pending.append(chunk)

            while let newlineRange = pending.firstRange(of: Data([0x0A])) {
                let lineData = pending.subdata(in: 0..<newlineRange.lowerBound)
                pending.removeSubrange(0..<newlineRange.upperBound)
                if let meta = parseSessionMetaLine(data: lineData) {
                    return meta
                }
            }
        }

        return parseSessionMetaLine(data: pending)
    }

    public static func normalizedProviderID(_ raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        return raw.lowercased()
    }

    public static func relativePath(for absolutePath: String, baseURL: URL?) -> String {
        guard let baseURL else {
            return URL(fileURLWithPath: absolutePath).standardizedFileURL.path
        }

        let absoluteURL = URL(fileURLWithPath: absolutePath).standardizedFileURL
        let basePath = baseURL.standardizedFileURL.path
        let absolute = absoluteURL.path
        guard absolute.hasPrefix(basePath) else { return absolute }
        let trimmed = String(absolute.dropFirst(basePath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return trimmed.isEmpty ? absoluteURL.lastPathComponent : trimmed
    }

    private static func archivedSessionsRoot(for sessionsRoot: STFolder) -> STFolder? {
        guard sessionsRoot.url.lastPathComponent == "sessions" else { return nil }
        return sessionsRoot.parentFolder()?.folder("archived_sessions")
    }

    private static func parseSessionMetaLine(data: Data) -> SessionMeta? {
        guard !data.isEmpty else { return nil }
        guard let line = try? CodexGeneratedFilesParser.parseRolloutLine(data: data) else { return nil }
        guard case let .sessionMeta(meta) = line.item else { return nil }
        return SessionMeta(
            threadID: trimmedOptionalText(meta.id),
            forkedFromID: trimmedOptionalText(meta.forkedFromID),
            originator: trimmedOptionalText(meta.originator),
            source: trimmedOptionalText(meta.source),
            modelProvider: normalizedProviderID(meta.modelProvider),
            cwd: meta.cwd,
            timestamp: meta.timestamp
        )
    }

    private static func trimmedOptionalText(_ raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        return raw
    }

    private static let filenameDateRegex = try? NSRegularExpression(pattern: "(\\d{4}-\\d{2}-\\d{2})")

    private static func dayKeyFromFilename(_ filename: String) -> String? {
        guard let filenameDateRegex else { return nil }
        let range = NSRange(filename.startIndex..<filename.endIndex, in: filename)
        guard let match = filenameDateRegex.firstMatch(in: filename, range: range) else { return nil }
        guard let matchRange = Range(match.range(at: 1), in: filename) else { return nil }
        return String(filename[matchRange])
    }

    private static func listJSONLFiles(root: STFolder, dayRange: DayRange?) -> [STFile] {
        guard root.isExists else { return [] }
        guard let dayRange else {
            let paths = (try? root.allSubFilePaths([.skipsHiddenFiles, .skipsPackageDescendants])) ?? []
            return paths
                .compactMap(\.asFile)
                .filter { $0.url.pathExtension.lowercased() == "jsonl" }
                .sorted { $0.url.path < $1.url.path }
        }

        var results: [STFile] = []
        var seenPaths: Set<String> = []

        let partitioned = listJSONLFilesByDatePartition(root: root, dayRange: dayRange)
        let flat = listJSONLFilesFlat(root: root, dayRange: dayRange)

        for file in partitioned + flat where seenPaths.insert(file.url.path).inserted {
            results.append(file)
        }

        return results.sorted { $0.url.path < $1.url.path }
    }

    private static func listJSONLFilesByDatePartition(root: STFolder, dayRange: DayRange) -> [STFile] {
        guard root.isExists else { return [] }
        var results: [STFile] = []
        var date = parseDayKey(dayRange.sinceKey) ?? Date()
        let untilDate = parseDayKey(dayRange.untilKey) ?? date

        while date <= untilDate {
            let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
            let year = String(format: "%04d", components.year ?? 1970)
            let month = String(format: "%02d", components.month ?? 1)
            let day = String(format: "%02d", components.day ?? 1)

            let dayDirectory = root.folder(year).folder(month).folder(day)
            if let files = try? dayDirectory.files([.skipsHiddenFiles]) {
                for file in files where file.url.pathExtension.lowercased() == "jsonl" {
                    results.append(file)
                }
            }

            date = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? untilDate.addingTimeInterval(1)
        }

        return results
    }

    private static func listJSONLFilesFlat(root: STFolder, dayRange: DayRange) -> [STFile] {
        guard root.isExists else { return [] }
        guard let files = try? root.files([.skipsHiddenFiles, .skipsPackageDescendants]) else { return [] }

        var results: [STFile] = []
        for file in files where file.url.pathExtension.lowercased() == "jsonl" {
            if let dayKey = dayKeyFromFilename(file.url.lastPathComponent),
               !DayRange.isInRange(dayKey: dayKey, since: dayRange.sinceKey, until: dayRange.untilKey)
            {
                continue
            }
            results.append(file)
        }
        return results
    }

    private static func parseDayKey(_ key: String) -> Date? {
        let parts = key.split(separator: "-")
        guard parts.count == 3 else { return nil }
        guard
            let year = Int(parts[0]),
            let month = Int(parts[1]),
            let day = Int(parts[2])
        else {
            return nil
        }

        var components = DateComponents()
        components.calendar = Calendar.current
        components.timeZone = TimeZone.current
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return components.date
    }

    private static func fileIdentityString(file: STFile) -> String? {
        guard let values = try? file.url.resourceValues(forKeys: [.fileResourceIdentifierKey]) else { return nil }
        guard let identifier = values.fileResourceIdentifier else { return nil }
        if let data = identifier as? Data {
            return data.base64EncodedString()
        }
        return String(describing: identifier)
    }
}
