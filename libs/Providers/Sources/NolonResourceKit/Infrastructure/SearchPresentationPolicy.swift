import Foundation

public struct SearchSelection<Item> {
    public let exactMatch: Item?
    public let displayed: [Item]
    public let alternatives: [Item]

    public init(exactMatch: Item?, displayed: [Item], alternatives: [Item]) {
        self.exactMatch = exactMatch
        self.displayed = displayed
        self.alternatives = alternatives
    }
}

public enum SearchPresentationPolicy {
    public static func select<Item>(
        query: String?,
        items: [Item],
        maxDisplayCount: Int = 10,
        slug: (Item) -> String
    ) -> SearchSelection<Item> {
        let rawQuery = query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let normalizedQuery = normalizedSlug(rawQuery)
        let exactCandidate = rawQuery.isEmpty
            ? nil
            : items.first(where: { normalizedSlug(slug($0)) == normalizedQuery })
        let exact = items.count <= maxDisplayCount ? exactCandidate : nil
        let pool = exact.map { [$0] } ?? items
        let alternatives = exact.map { match in
            items.filter { normalizedSlug(slug($0)) != normalizedSlug(slug(match)) }
        } ?? []
        return SearchSelection(
            exactMatch: exact,
            displayed: Array(pool.prefix(maxDisplayCount)),
            alternatives: alternatives
        )
    }

    private static func normalizedSlug(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
