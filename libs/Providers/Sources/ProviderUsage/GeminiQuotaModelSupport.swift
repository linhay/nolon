import Foundation

enum GeminiQuotaModelSupport {
    private static let displayAliasMap: [String: String] = [
        "auto-gemini-3": "Auto (Gemini 3)",
        "auto-gemini-2.5": "Auto (Gemini 2.5)",
        "pro": "gemini-3-pro-preview",
        "flash": "gemini-3-flash-preview",
        "gemini-3.1-pro-preview-customtools": "gemini-3.1-pro-preview",
    ]

    private static let sortPriority: [String: Int] = [
        "gemini-3.1-pro-preview": 0,
        "gemini-3-pro-preview": 1,
        "gemini-2.5-pro": 2,
        "gemini-3-flash-preview": 3,
        "gemini-2.5-flash": 4,
        "gemini-2.0-flash": 5,
        "gemini-2.5-flash-lite": 6,
    ]

    static func normalizedModelID(_ modelID: String) -> String {
        if let alias = displayAliasMap[modelID] {
            return alias
        }
        if modelID.hasSuffix("-001") {
            return String(modelID.dropLast(4))
        }
        return modelID
    }

    static func displayTitle(for modelID: String) -> String {
        normalizedModelID(modelID)
    }

    static func sortAndDeduplicate(_ buckets: [GeminiQuotaBucket]) -> [GeminiQuotaBucket] {
        let sorted = buckets.sorted { lhs, rhs in
            compare(lhs, rhs)
        }

        var deduplicated: [GeminiQuotaBucket] = []
        var seenTitles = Set<String>()
        for bucket in sorted {
            let title = displayTitle(for: bucket.modelID)
            if seenTitles.insert(title).inserted {
                deduplicated.append(bucket)
            }
        }
        return deduplicated
    }

    private static func compare(_ lhs: GeminiQuotaBucket, _ rhs: GeminiQuotaBucket) -> Bool {
        let lhsKey = sortKey(for: lhs.modelID)
        let rhsKey = sortKey(for: rhs.modelID)
        if lhsKey.priority != rhsKey.priority {
            return lhsKey.priority < rhsKey.priority
        }
        if lhsKey.normalizedTitle != rhsKey.normalizedTitle {
            return lhsKey.normalizedTitle < rhsKey.normalizedTitle
        }
        return lhs.modelID < rhs.modelID
    }

    private static func sortKey(for modelID: String) -> (priority: Int, normalizedTitle: String) {
        let normalizedTitle = normalizedModelID(modelID)
        let priority = sortPriority[normalizedTitle] ?? Int.max
        return (priority, normalizedTitle)
    }
}
