import Foundation
import ProviderUsage
import STJSON

enum CodexConfigDraftCodec {
    static func parseKeyValueLines(_ text: String) throws -> [String: String] {
        try ProviderUsageEngine.parseKeyValueLines(text)
    }

    static func serializeKeyValueLines(_ values: [String: String]) -> String {
        ProviderUsageEngine.serializeKeyValueLines(values)
    }

    static func formatTimeoutSeconds(_ value: Double) -> String {
        ProviderUsageEngine.formatTimeoutSeconds(value)
    }

    static func stringDictionary(from json: JSON?) -> [String: String] {
        ProviderUsageEngine.stringDictionary(from: json)
    }
}

