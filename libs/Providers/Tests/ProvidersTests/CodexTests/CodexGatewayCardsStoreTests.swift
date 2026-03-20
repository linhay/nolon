import Foundation
import Testing
import ProviderCatalog
@testable import ProviderUsage

@Suite("CodexGatewayCardsStore")
@MainActor
struct CodexGatewayCardsStoreTests {
    @Test("returns empty cards for empty storage")
    func loadsEmptyState() throws {
        let suiteName = "codex-gateway-cards-empty-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let provider = makeProvider(id: "codex-provider")
        let store = CodexGatewayCardsStore(userDefaults: userDefaults)

        let state = store.load(for: provider)

        #expect(state.cards.isEmpty)
        #expect(state.lastUsedCardID == nil)
    }

    @Test("save and load roundtrip keeps stable order")
    func saveLoadRoundtrip() throws {
        let suiteName = "codex-gateway-cards-roundtrip-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let provider = makeProvider(id: "codex-provider")
        let store = CodexGatewayCardsStore(userDefaults: userDefaults)

        let accountA = UUID()
        let accountB = UUID()
        let cardA = CodexGatewayCard(name: "主网关", memberAccountIDs: [accountA])
        let cardB = CodexGatewayCard(name: "备用网关", memberAccountIDs: [accountB])
        let initial = CodexGatewayCardsState(cards: [cardA, cardB], lastUsedCardID: cardA.id)

        store.save(initial, for: provider)
        let loaded = store.load(for: provider)

        #expect(loaded.cards.count == 2)
        #expect(loaded.cards.map(\.id) == [cardA.id, cardB.id])
        #expect(loaded.cards[0].memberAccountIDs == [accountA])
        #expect(loaded.cards[1].memberAccountIDs == [accountB])
        #expect(loaded.lastUsedCardID == cardA.id)
    }

    @Test("provider keys are isolated")
    func providerIsolation() throws {
        let suiteName = "codex-gateway-cards-isolation-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let providerA = makeProvider(id: "codex")
        let providerB = makeProvider(id: "codex-xcode")
        let store = CodexGatewayCardsStore(userDefaults: userDefaults)

        let cardA = CodexGatewayCard(name: "A", memberAccountIDs: [UUID()])
        let cardB = CodexGatewayCard(name: "B", memberAccountIDs: [UUID()])

        store.save(CodexGatewayCardsState(cards: [cardA], lastUsedCardID: cardA.id), for: providerA)
        store.save(CodexGatewayCardsState(cards: [cardB], lastUsedCardID: cardB.id), for: providerB)

        let loadedA = store.load(for: providerA)
        let loadedB = store.load(for: providerB)

        #expect(loadedA.cards.map(\.id) == [cardA.id])
        #expect(loadedB.cards.map(\.id) == [cardB.id])
        #expect(loadedA.lastUsedCardID == cardA.id)
        #expect(loadedB.lastUsedCardID == cardB.id)
    }

    @Test("deduplicates members and filters invalid ids during load/save")
    func dedupeAndFilterMembers() throws {
        let suiteName = "codex-gateway-cards-filter-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let provider = makeProvider(id: "codex-provider")
        let store = CodexGatewayCardsStore(userDefaults: userDefaults)

        let validA = UUID()
        let validB = UUID()
        let invalid = UUID()

        let card = CodexGatewayCard(
            name: "主网关",
            memberAccountIDs: [validA, validA, invalid, validB, invalid]
        )
        let state = CodexGatewayCardsState(cards: [card], lastUsedCardID: card.id)

        store.save(state, for: provider, validAccountIDs: Set([validA, validB]))
        let loaded = store.load(for: provider, validAccountIDs: Set([validA, validB]))

        #expect(loaded.cards.count == 1)
        #expect(loaded.cards[0].memberAccountIDs == [validA, validB])
        #expect(loaded.lastUsedCardID == card.id)
    }

    private func makeProvider(id: String) -> Provider {
        Provider(
            id: id,
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: "~/.codex/skills",
            workflowPath: "~/.codex/prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
    }
}
