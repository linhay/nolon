import Foundation
import ProviderUsage
import STJSON

enum CodexConfigDraftCodec {
    static func parseKeyValueLines(_ text: String) throws -> [String: String] {
        try ProviderUsageViewModel.parseKeyValueLines(text)
    }

    static func serializeKeyValueLines(_ values: [String: String]) -> String {
        ProviderUsageViewModel.serializeKeyValueLines(values)
    }

    static func formatTimeoutSeconds(_ value: Double) -> String {
        ProviderUsageViewModel.formatTimeoutSeconds(value)
    }

    static func stringDictionary(from json: JSON?) -> [String: String] {
        ProviderUsageViewModel.stringDictionary(from: json)
    }
}

