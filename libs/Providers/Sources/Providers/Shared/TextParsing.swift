import Foundation

/// Text parsing utilities for extracting numbers, percentages, and other data from terminal output
public enum TextParsing {
    /// Removes ANSI escape sequences so regex parsing works on colored terminal output.
    public static func stripANSICodes(_ text: String) -> String {
        // CSI sequences: ESC [ ... ending in 0x40–0x7E
        let pattern = #"\u001B\[[0-?]*[ -/]*[@-~]"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
    }

    /// Extracts the first number matching a pattern from text
    public static func firstNumber(pattern: String, text: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges >= 2,
              let r = Range(match.range(at: 1), in: text) else { return nil }
        let raw = String(text[r])
        return Self.parseNumber(raw)
    }

    private static func parseNumber(_ raw: String) -> Double? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        text = text.replacingOccurrences(of: "\u{00A0}", with: "")
        text = text.replacingOccurrences(of: "\u{202F}", with: "")
        text = text.replacingOccurrences(of: " ", with: "")

        let hasComma = text.contains(",")
        let hasDot = text.contains(".")

        if hasComma, hasDot {
            if let lastComma = text.lastIndex(of: ","), let lastDot = text.lastIndex(of: ".") {
                if lastComma > lastDot {
                    text = text.replacingOccurrences(of: ".", with: "")
                    text = text.replacingOccurrences(of: ",", with: ".")
                } else {
                    text = text.replacingOccurrences(of: ",", with: "")
                }
            }
        } else if hasComma {
            if text.range(of: #"^\d{1,3}(,\d{3})+$"#, options: .regularExpression) != nil {
                text = text.replacingOccurrences(of: ",", with: "")
            } else {
                text = text.replacingOccurrences(of: ",", with: ".")
            }
        } else if hasDot {
            if text.range(of: #"^\d{1,3}(\.\d{3})+$"#, options: .regularExpression) != nil {
                text = text.replacingOccurrences(of: ".", with: "")
            }
        }

        return Double(text)
    }

    /// Extracts the first integer matching a pattern from text
    public static func firstInt(pattern: String, text: String) -> Int? {
        guard let v = firstNumber(pattern: pattern, text: text) else { return nil }
        return Int(v)
    }

    /// Extracts the first line matching a pattern from text
    public static func firstLine(matching pattern: String, text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              let r = Range(match.range(at: 0), in: text) else { return nil }
        return String(text[r])
    }

    /// Extracts percentage left from a line (e.g., "50% left")
    public static func percentLeft(fromLine line: String) -> Int? {
        guard let pct = firstInt(pattern: #"([0-9]{1,3})%\s+left"#, text: line) else { return nil }
        return pct
    }

    /// Extracts reset string from a line (e.g., "resets in 1 hour")
    public static func resetString(fromLine line: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"\bresets\b\s+(.+)"#, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, options: [], range: range),
              match.numberOfRanges >= 2,
              let r = Range(match.range(at: 1), in: line) else { return nil }
        var value = String(line[r]).trimmingCharacters(in: .whitespacesAndNewlines)
        while value.hasSuffix(")") {
            value.removeLast()
            value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return value.isEmpty ? nil : value
    }
}
