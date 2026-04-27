import Darwin
import Foundation
import STFilePath
import TOML

public struct CodexConfigStore: Sendable {
    private let file: STFile

    public init(file: STFile) {
        self.file = file
    }

    public func readRaw() throws -> String {
        try withExclusiveAccess {
            Self.normalizedText((try? file.read()) ?? "")
        }
    }

    public func readConfig() throws -> CodexConfigToml? {
        let raw = try readRaw()
        guard raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return nil
        }
        return try TOMLDecoder().decode(CodexConfigToml.self, from: Data(raw.utf8))
    }

    public func readModelProviderIDs() throws -> [String] {
        Self.modelProviderIDs(in: try readRaw())
    }

    @discardableResult
    public func update(_ mutate: (String) throws -> String) throws -> String {
        try withExclusiveAccess {
            let current = Self.normalizedText((try? file.read()) ?? "")
            let next = Self.normalizedText(try mutate(current))
            guard next != current else {
                return next
            }
            _ = file.parentFolder()?.createIfNotExists()
            try Self.atomicWrite(next, to: file)
            return next
        }
    }

    @discardableResult
    public func setTopLevelStringValue(key: String, value: String) throws -> String {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty, !trimmedValue.isEmpty else {
            return try readRaw()
        }
        return try update { current in
            Self.upsertingTopLevelStringValue(in: current, key: trimmedKey, value: trimmedValue)
        }
    }

    @discardableResult
    public func removeTopLevelValue(key: String) throws -> String {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            return try readRaw()
        }
        return try update { current in
            Self.removingTopLevelValue(in: current, key: trimmedKey)
        }
    }

    public static func modelProviderIDs(in raw: String) -> [String] {
        var result: [String] = []
        var seen: Set<String> = []

        func append(_ candidate: String) {
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            guard seen.insert(trimmed).inserted else { return }
            result.append(trimmed)
        }

        for line in normalizedText(raw).split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmedLine = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
            if let value = extractQuotedValue(from: trimmedLine, key: "model_provider") {
                append(value)
            }
            if let providerID = extractModelProviderSectionID(from: trimmedLine) {
                append(providerID)
            }
        }

        return result
    }

    public static func upsertingTopLevelStringValue(in raw: String, key: String, value: String) -> String {
        let normalized = normalizedText(raw)
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let (preamble, sections) = splitTopLevelDocument(lines)
        let assignment = "\(key) = \"\(escape(value))\""

        var rewritten = preamble
        var replaced = false
        for index in rewritten.indices {
            guard parseAssignmentKey(from: rewritten[index]) == key else { continue }
            rewritten[index] = assignment
            replaced = true
        }

        if !replaced {
            rewritten = trimTrailingEmptyLines(from: rewritten)
            rewritten.append(assignment)
        }

        return renderTopLevelDocument(
            preamble: rewritten,
            sections: sections,
            hasTrailingNewline: normalized.hasSuffix("\n") || !assignment.isEmpty
        )
    }

    public static func removingTopLevelValue(in raw: String, key: String) -> String {
        let normalized = normalizedText(raw)
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let (preamble, sections) = splitTopLevelDocument(lines)
        let filtered = trimTrailingEmptyLines(
            from: preamble.filter { parseAssignmentKey(from: $0) != key }
        )
        return renderTopLevelDocument(
            preamble: filtered,
            sections: sections,
            hasTrailingNewline: normalized.hasSuffix("\n") && (!filtered.isEmpty || !sections.isEmpty)
        )
    }

    public static func extractQuotedValue(from line: String, key: String) -> String? {
        guard let separatorIndex = line.firstIndex(of: "=") else { return nil }
        let left = line[..<separatorIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        guard left == key else { return nil }
        let rawValue = line[line.index(after: separatorIndex)...].trimmingCharacters(in: .whitespacesAndNewlines)
        guard rawValue.first == "\"", rawValue.last == "\"", rawValue.count >= 2 else { return nil }
        return String(rawValue.dropFirst().dropLast())
    }

    public static func extractModelProviderSectionID(from line: String) -> String? {
        let prefix = "[model_providers."
        let suffix = "]"
        guard line.hasPrefix(prefix), line.hasSuffix(suffix), line.count > prefix.count + suffix.count else {
            return nil
        }
        let start = line.index(line.startIndex, offsetBy: prefix.count)
        let end = line.index(before: line.endIndex)
        return String(line[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var standardizedPath: String {
        file.url.standardizedFileURL.path
    }

    private var lockFile: STFile {
        let url = file.url.standardizedFileURL
        return STFile(url.deletingLastPathComponent().appendingPathComponent("\(url.lastPathComponent).lock"))
    }

    private func withExclusiveAccess<T>(_ body: () throws -> T) throws -> T {
        try CodexConfigPathLockRegistry.shared.withLock(for: standardizedPath) {
            try Self.withAdvisoryFileLock(lockFile) {
                try body()
            }
        }
    }

    static func lockFilePath(for file: STFile) -> String {
        let url = file.url.standardizedFileURL
        return url.deletingLastPathComponent().appendingPathComponent("\(url.lastPathComponent).lock").path
    }

    private static func normalizedText(_ raw: String) -> String {
        raw.replacingOccurrences(of: "\r\n", with: "\n")
    }

    private static func atomicWrite(_ text: String, to file: STFile) throws {
        let data = Data(text.utf8)
        try data.write(to: file.url, options: .atomic)
    }

    private static func withAdvisoryFileLock<T>(_ lockFile: STFile, body: () throws -> T) throws -> T {
        _ = lockFile.parentFolder()?.createIfNotExists()
        if !lockFile.isExists {
            try Data().write(to: lockFile.url, options: .atomic)
        }

        let fd = open(lockFile.url.path, O_CREAT | O_RDWR, mode_t(S_IRUSR | S_IWUSR))
        guard fd >= 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
        defer { _ = close(fd) }

        guard flock(fd, LOCK_EX) == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
        defer { _ = flock(fd, LOCK_UN) }

        return try body()
    }

    private static func parseAssignmentKey(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.hasPrefix("#"),
              let separatorIndex = trimmed.firstIndex(of: "=")
        else {
            return nil
        }
        let key = trimmed[..<separatorIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        return key.isEmpty ? nil : String(key)
    }

    private static func parseSectionName(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("["), trimmed.hasSuffix("]"), trimmed.count >= 2 else {
            return nil
        }
        return String(trimmed.dropFirst().dropLast())
    }

    private static func splitTopLevelDocument(_ lines: [String]) -> (preamble: [String], sections: [String]) {
        var preamble: [String] = []
        var sections: [String] = []
        var reachedSection = false

        for line in lines {
            if !reachedSection, parseSectionName(from: line) == nil {
                preamble.append(line)
            } else {
                reachedSection = true
                sections.append(line)
            }
        }

        return (preamble, sections)
    }

    private static func renderTopLevelDocument(
        preamble: [String],
        sections: [String],
        hasTrailingNewline: Bool
    ) -> String {
        var lines = trimTrailingEmptyLines(from: preamble)
        if !sections.isEmpty, !lines.isEmpty, lines.last?.isEmpty == false {
            lines.append("")
        }
        lines.append(contentsOf: sections)
        var output = lines.joined(separator: "\n")
        if hasTrailingNewline, !output.isEmpty {
            output.append("\n")
        }
        return output
    }

    private static func trimTrailingEmptyLines(from lines: [String]) -> [String] {
        var trimmed = lines
        while trimmed.last?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            _ = trimmed.popLast()
        }
        return trimmed
    }

    private static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "\"", with: "\\\"")
    }
}

private final class CodexConfigPathLockRegistry: @unchecked Sendable {
    static let shared = CodexConfigPathLockRegistry()

    private let registryLock = NSLock()
    private var locks: [String: NSLock] = [:]

    private init() {}

    func withLock<T>(for path: String, _ body: () throws -> T) rethrows -> T {
        let lock = registryLock.withLock {
            if let existing = locks[path] {
                return existing
            }
            let created = NSLock()
            locks[path] = created
            return created
        }
        return try lock.withLock(body)
    }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
