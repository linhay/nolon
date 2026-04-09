import Foundation

enum TextNormalizationSupport {
    static func trimmed(_ string: String?) -> String? {
        guard let string else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func firstNonEmpty(_ values: String?...) -> String? {
        firstNonEmpty(values)
    }

    static func firstNonEmpty(_ values: [String?]) -> String? {
        for value in values {
            if let normalized = trimmed(value) {
                return normalized
            }
        }
        return nil
    }

    static func joinedNonEmpty(_ values: [String?], separator: String = " • ") -> String? {
        let normalized = values.compactMap { trimmed($0) }
        guard !normalized.isEmpty else { return nil }
        return normalized.joined(separator: separator)
    }
}
