import Foundation

struct ClaudeSessionFileFingerprint: Codable, Sendable, Equatable {
    let mtimeUnixMs: Int64
    let size: Int64
}

struct ClaudeCachedTokenEvent: Codable, Sendable, Equatable {
    let dedupeKey: String?
    let timestamp: Date
    let input: Int
    let output: Int
    let cacheRead: Int
    let total: Int
}

private struct ClaudeSessionUsageFileCache: Codable, Sendable, Equatable {
    let fingerprint: ClaudeSessionFileFingerprint
    let events: [ClaudeCachedTokenEvent]
}

actor ClaudeSessionUsageStore {
    struct Snapshot: Sendable, Equatable {
        let events: [ClaudeCachedTokenEvent]
    }

    static let shared = ClaudeSessionUsageStore()

    private var files: [String: ClaudeSessionUsageFileCache] = [:]

    func loadSnapshot(
        projectFiles: [URL],
        readFile: @Sendable (URL) throws -> String,
        loadFileFingerprint: @Sendable (URL) -> ClaudeSessionFileFingerprint
    ) async throws -> Snapshot {
        var events: [ClaudeCachedTokenEvent] = []

        for fileURL in projectFiles.sorted(by: { $0.path < $1.path }) {
            let fingerprint = loadFileFingerprint(fileURL)
            let cacheKey = fileURL.path

            if let cached = files[cacheKey], cached.fingerprint == fingerprint {
                events.append(contentsOf: cached.events)
                continue
            }

            let contents = try readFile(fileURL)
            let parsed = ClaudeSessionUsageSupport.parseEvents(from: contents)
            files[cacheKey] = ClaudeSessionUsageFileCache(
                fingerprint: fingerprint,
                events: parsed
            )
            events.append(contentsOf: parsed)
        }

        return Snapshot(events: ClaudeSessionUsageSupport.deduplicated(events: events))
    }

    static func defaultLoadFileFingerprint(_ url: URL) -> ClaudeSessionFileFingerprint {
        let attributes = (try? FileManager.default.attributesOfItem(atPath: url.path)) ?? [:]
        let mtime = (attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        return ClaudeSessionFileFingerprint(
            mtimeUnixMs: Int64(mtime * 1000),
            size: size
        )
    }
}

enum ClaudeSessionUsageSupport {
    static func defaultProjectsRoots() -> [URL] {
        defaultProjectsRoots(environment: ProcessInfo.processInfo.environment)
    }

    static func defaultProjectsRoots(
        environment: [String: String]
    ) -> [URL] {
        let configuredRoots: [URL] = environment["CLAUDE_CONFIG_DIR"]?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { raw in
                URL(fileURLWithPath: raw, isDirectory: true)
                    .appendingPathComponent("projects", isDirectory: true)
            } ?? []

        if !configuredRoots.isEmpty {
            return configuredRoots
        }

        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        return [
            homeDirectory
                .appendingPathComponent(".config", isDirectory: true)
                .appendingPathComponent("claude", isDirectory: true)
                .appendingPathComponent("projects", isDirectory: true),
            homeDirectory
                .appendingPathComponent(".claude", isDirectory: true)
                .appendingPathComponent("projects", isDirectory: true),
        ]
    }

    static func defaultListSessionFiles(roots: [URL]) throws -> [URL] {
        var files: [URL] = []
        var seenPaths = Set<String>()

        for root in roots {
            guard FileManager.default.fileExists(atPath: root.path) else { continue }

            let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )

            while let item = enumerator?.nextObject() as? URL {
                guard item.pathExtension == "jsonl" else { continue }
                guard seenPaths.insert(item.path).inserted else { continue }
                files.append(item)
            }
        }

        return files.sorted { $0.path < $1.path }
    }

    static func makeDayRange(dayKey: String, timezone: TimeZone) -> (start: Date, end: Date)? {
        let formatter = DateFormatter()
        formatter.calendar = calendar(timezone: timezone)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timezone
        formatter.dateFormat = "yyyy-MM-dd"

        guard let start = formatter.date(from: dayKey) else { return nil }
        guard let end = formatter.calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
        return (start, end)
    }

    static func dayKey(from date: Date, timezone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar(timezone: timezone)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timezone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func calendar(timezone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        return calendar
    }

    static func parseEvents(from contents: String) -> [ClaudeCachedTokenEvent] {
        var identified: [String: ClaudeCachedTokenEvent] = [:]
        var anonymous: [ClaudeCachedTokenEvent] = []

        for line in contents.split(whereSeparator: \.isNewline) {
            guard let data = String(line).data(using: .utf8),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let event = parseEvent(from: root)
            else {
                continue
            }

            if let dedupeKey = event.dedupeKey {
                if let existing = identified[dedupeKey] {
                    if shouldReplace(existing: existing, with: event) {
                        identified[dedupeKey] = event
                    }
                } else {
                    identified[dedupeKey] = event
                }
            } else {
                anonymous.append(event)
            }
        }

        return deduplicated(events: Array(identified.values) + anonymous)
    }

    static func deduplicated(events: [ClaudeCachedTokenEvent]) -> [ClaudeCachedTokenEvent] {
        var identified: [String: ClaudeCachedTokenEvent] = [:]
        var anonymous: [ClaudeCachedTokenEvent] = []

        for event in events {
            if let dedupeKey = event.dedupeKey {
                if let existing = identified[dedupeKey] {
                    if shouldReplace(existing: existing, with: event) {
                        identified[dedupeKey] = event
                    }
                } else {
                    identified[dedupeKey] = event
                }
            } else {
                anonymous.append(event)
            }
        }

        return (Array(identified.values) + anonymous).sorted { lhs, rhs in
            if lhs.timestamp != rhs.timestamp {
                return lhs.timestamp < rhs.timestamp
            }
            return lhs.total < rhs.total
        }
    }

    private static func parseEvent(from root: [String: Any]) -> ClaudeCachedTokenEvent? {
        guard stringValue(root["type"]) == "assistant" else { return nil }

        let message = root["message"] as? [String: Any] ?? [:]
        let metadata = root["metadata"] as? [String: Any] ?? [:]
        let requestID = stringValue(root["requestId"])
        let messageID = stringValue(message["id"])

        if stringValue(metadata["provider"]) == "vertexai" {
            return nil
        }
        if requestID?.contains("_vrtx_") == true || messageID?.contains("_vrtx_") == true {
            return nil
        }

        guard let timestampText = stringValue(root["timestamp"]),
              let timestamp = parseTimestamp(timestampText)
        else {
            return nil
        }

        let usage = message["usage"] as? [String: Any] ?? [:]
        let input = intValue(usage["input_tokens"])
        let cacheCreation = intValue(usage["cache_creation_input_tokens"])
        let cacheRead = intValue(usage["cache_read_input_tokens"])
        let output = intValue(usage["output_tokens"])
        let adjustedInput = input + cacheCreation
        let total = adjustedInput + cacheRead + output

        guard total > 0 else { return nil }

        let sessionID = stringValue(root["sessionId"])
        let isSidechain = boolValue(root["isSidechain"]) ?? false
        let dedupeKey: String?
        if messageID != nil || requestID != nil {
            dedupeKey = [
                sessionID ?? "",
                messageID ?? "",
                requestID ?? "",
                isSidechain ? "sidechain" : "primary",
            ].joined(separator: "|")
        } else {
            dedupeKey = nil
        }

        return ClaudeCachedTokenEvent(
            dedupeKey: dedupeKey,
            timestamp: timestamp,
            input: adjustedInput,
            output: output,
            cacheRead: cacheRead,
            total: total
        )
    }

    private static func shouldReplace(existing: ClaudeCachedTokenEvent, with candidate: ClaudeCachedTokenEvent) -> Bool {
        if candidate.total != existing.total {
            return candidate.total > existing.total
        }
        if candidate.timestamp != existing.timestamp {
            return candidate.timestamp > existing.timestamp
        }
        if candidate.output != existing.output {
            return candidate.output > existing.output
        }
        if candidate.input != existing.input {
            return candidate.input > existing.input
        }
        if candidate.cacheRead != existing.cacheRead {
            return candidate.cacheRead > existing.cacheRead
        }
        return false
    }

    private static func parseTimestamp(_ raw: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let parsed = fractional.date(from: raw) {
            return parsed
        }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: raw)
    }

    private static func stringValue(_ raw: Any?) -> String? {
        guard let raw else { return nil }
        if let value = raw as? String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let value = raw as? CustomStringConvertible {
            let trimmed = value.description.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }

    private static func intValue(_ raw: Any?) -> Int {
        if let value = raw as? Int {
            return max(0, value)
        }
        if let value = raw as? NSNumber {
            return max(0, value.intValue)
        }
        if let value = raw as? String,
           let parsed = Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
        {
            return max(0, parsed)
        }
        return 0
    }

    private static func boolValue(_ raw: Any?) -> Bool? {
        if let value = raw as? Bool {
            return value
        }
        if let value = raw as? NSNumber {
            return value.boolValue
        }
        if let value = raw as? String {
            switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "1", "yes":
                return true
            case "false", "0", "no":
                return false
            default:
                return nil
            }
        }
        return nil
    }

}
