import Foundation
import ProviderCatalog

public struct CodexGatewayCard: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var memberAccountIDs: [UUID]
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        memberAccountIDs: [UUID] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.memberAccountIDs = memberAccountIDs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct CodexGatewayCardsState: Codable, Equatable, Sendable {
    public var cards: [CodexGatewayCard]
    public var lastUsedCardID: UUID?

    public init(cards: [CodexGatewayCard] = [], lastUsedCardID: UUID? = nil) {
        self.cards = cards
        self.lastUsedCardID = lastUsedCardID
    }
}

public final class CodexGatewayCardsStore: @unchecked Sendable {
    public static let shared = CodexGatewayCardsStore()

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
    }

    public func load(for provider: Provider, validAccountIDs: Set<UUID>? = nil) -> CodexGatewayCardsState {
        let key = storageKey(for: provider)
        guard let data = defaults.data(forKey: key),
              let decoded = try? decoder.decode(CodexGatewayCardsState.self, from: data)
        else {
            return CodexGatewayCardsState()
        }

        let normalized = normalized(decoded, validAccountIDs: validAccountIDs)
        if normalized != decoded {
            save(normalized, for: provider, validAccountIDs: validAccountIDs)
        }
        return normalized
    }

    public func save(
        _ state: CodexGatewayCardsState,
        for provider: Provider,
        validAccountIDs: Set<UUID>? = nil
    ) {
        let key = storageKey(for: provider)
        let normalized = normalized(state, validAccountIDs: validAccountIDs)
        guard let data = try? encoder.encode(normalized) else { return }
        defaults.set(data, forKey: key)
    }

    public func normalized(
        _ state: CodexGatewayCardsState,
        validAccountIDs: Set<UUID>? = nil
    ) -> CodexGatewayCardsState {
        var cardsByID: [UUID: CodexGatewayCard] = [:]
        var orderedCardIDs: [UUID] = []

        for card in state.cards {
            let uniqueMembers = orderedUniqueMembers(card.memberAccountIDs, validAccountIDs: validAccountIDs)
            if var existing = cardsByID[card.id] {
                let merged = orderedUniqueMembers(existing.memberAccountIDs + uniqueMembers, validAccountIDs: validAccountIDs)
                existing.memberAccountIDs = merged
                existing.updatedAt = max(existing.updatedAt, card.updatedAt)
                cardsByID[card.id] = existing
                continue
            }

            var normalizedCard = card
            normalizedCard.memberAccountIDs = uniqueMembers
            cardsByID[card.id] = normalizedCard
            orderedCardIDs.append(card.id)
        }

        let cards = orderedCardIDs.compactMap { cardsByID[$0] }
        let lastUsedCardID: UUID? = {
            guard let id = state.lastUsedCardID else { return nil }
            return cards.contains(where: { $0.id == id }) ? id : nil
        }()

        return CodexGatewayCardsState(cards: cards, lastUsedCardID: lastUsedCardID)
    }

    private func orderedUniqueMembers(_ ids: [UUID], validAccountIDs: Set<UUID>?) -> [UUID] {
        var seen: Set<UUID> = []
        var result: [UUID] = []

        for id in ids {
            if seen.contains(id) { continue }
            if let validAccountIDs, !validAccountIDs.contains(id) { continue }
            seen.insert(id)
            result.append(id)
        }

        return result
    }

    private func storageKey(for provider: Provider) -> String {
        "nolon.codex.gateway_cards.\(provider.id)"
    }
}
