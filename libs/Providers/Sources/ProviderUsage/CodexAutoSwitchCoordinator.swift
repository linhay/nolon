import Foundation
import ProviderCatalog
import STFilePath

public struct CodexAutoSwitchConfig: Sendable, Equatable, Codable {
    public var enabled: Bool
    public var thresholdPercent: Double
    public var minimumCandidateRemainingPercent: Double
    public var skipRelayAccounts: Bool
    public var cooldown: TimeInterval

    public init(
        enabled: Bool = false,
        thresholdPercent: Double = 10,
        minimumCandidateRemainingPercent: Double = 20,
        skipRelayAccounts: Bool = true,
        cooldown: TimeInterval = 10 * 60
    ) {
        self.enabled = enabled
        self.thresholdPercent = thresholdPercent
        self.minimumCandidateRemainingPercent = minimumCandidateRemainingPercent
        self.skipRelayAccounts = skipRelayAccounts
        self.cooldown = cooldown
    }
}

public struct CodexAutoSwitchState: Sendable, Equatable, Codable {
    public var lastSwitchedAtByProviderID: [String: Date]

    public init(lastSwitchedAtByProviderID: [String: Date] = [:]) {
        self.lastSwitchedAtByProviderID = lastSwitchedAtByProviderID
    }
}

public struct CodexAutoSwitchCandidate: Sendable, Equatable {
    public var account: CodexAuthAccount
    public var cardKind: CodexAuthSummary.CardKind?
    public var usage: UsageSnapshot?
    public var isSchedulable: Bool
    public var lastActivatedAt: Date?

    public init(
        account: CodexAuthAccount,
        cardKind: CodexAuthSummary.CardKind?,
        usage: UsageSnapshot?,
        isSchedulable: Bool,
        lastActivatedAt: Date?
    ) {
        self.account = account
        self.cardKind = cardKind
        self.usage = usage
        self.isSchedulable = isSchedulable
        self.lastActivatedAt = lastActivatedAt
    }

    public var primaryRemainingPercent: Double? {
        if let primary = usage?.primary?.remainingPercent {
            return primary
        }
        return usage?.allWindows.first?.window.remainingPercent
    }
}

public enum CodexAutoSwitchDecisionReason: String, Sendable, Equatable, Codable {
    case disabled
    case noActiveAccount
    case missingQuota
    case thresholdNotReached
    case cooldownActive
    case noCandidate
    case switched
}

public struct CodexAutoSwitchDecision: Sendable, Equatable, Codable {
    public var reason: CodexAutoSwitchDecisionReason
    public var fromAccountID: UUID?
    public var toAccountID: UUID?
    public var currentRemainingPercent: Double?
    public var targetRemainingPercent: Double?
    public var checkedAt: Date
    public var cooldownUntil: Date?

    public init(
        reason: CodexAutoSwitchDecisionReason,
        fromAccountID: UUID?,
        toAccountID: UUID?,
        currentRemainingPercent: Double?,
        targetRemainingPercent: Double?,
        checkedAt: Date,
        cooldownUntil: Date? = nil
    ) {
        self.reason = reason
        self.fromAccountID = fromAccountID
        self.toAccountID = toAccountID
        self.currentRemainingPercent = currentRemainingPercent
        self.targetRemainingPercent = targetRemainingPercent
        self.checkedAt = checkedAt
        self.cooldownUntil = cooldownUntil
    }
}

public struct CodexAutoSwitchEvent: Sendable, Equatable, Codable {
    public var providerID: String
    public var reason: CodexAutoSwitchDecisionReason
    public var fromAccountID: UUID?
    public var toAccountID: UUID?
    public var currentRemainingPercent: Double?
    public var targetRemainingPercent: Double?
    public var checkedAt: Date
    public var cooldownUntil: Date?

    public init(
        providerID: String,
        reason: CodexAutoSwitchDecisionReason,
        fromAccountID: UUID?,
        toAccountID: UUID?,
        currentRemainingPercent: Double?,
        targetRemainingPercent: Double?,
        checkedAt: Date,
        cooldownUntil: Date? = nil
    ) {
        self.providerID = providerID
        self.reason = reason
        self.fromAccountID = fromAccountID
        self.toAccountID = toAccountID
        self.currentRemainingPercent = currentRemainingPercent
        self.targetRemainingPercent = targetRemainingPercent
        self.checkedAt = checkedAt
        self.cooldownUntil = cooldownUntil
    }

    public init(providerID: String, decision: CodexAutoSwitchDecision) {
        self.init(
            providerID: providerID,
            reason: decision.reason,
            fromAccountID: decision.fromAccountID,
            toAccountID: decision.toAccountID,
            currentRemainingPercent: decision.currentRemainingPercent,
            targetRemainingPercent: decision.targetRemainingPercent,
            checkedAt: decision.checkedAt,
            cooldownUntil: decision.cooldownUntil
        )
    }
}

public struct CodexAutoSwitchStatusSnapshot: Sendable, Equatable, Codable {
    public var providerID: String
    public var config: CodexAutoSwitchConfig
    public var lastDecision: CodexAutoSwitchDecision?
    public var lastUpdatedAt: Date

    public init(
        providerID: String,
        config: CodexAutoSwitchConfig,
        lastDecision: CodexAutoSwitchDecision?,
        lastUpdatedAt: Date
    ) {
        self.providerID = providerID
        self.config = config
        self.lastDecision = lastDecision
        self.lastUpdatedAt = lastUpdatedAt
    }
}

public actor CodexAutoSwitchCoordinator {
    public typealias LoadState = @Sendable () async -> CodexAutoSwitchState
    public typealias SaveState = @Sendable (CodexAutoSwitchState) async throws -> Void
    public typealias Clock = @Sendable () -> Date
    public typealias ActivateAccount = @Sendable (CodexAuthAccount, Provider) async throws -> Void

    private let config: CodexAutoSwitchConfig
    private let loadState: LoadState
    private let saveState: SaveState
    private let now: Clock
    private let activateAccount: ActivateAccount

    public init(
        config: CodexAutoSwitchConfig,
        loadState: @escaping LoadState,
        saveState: @escaping SaveState,
        now: @escaping Clock = Date.init,
        activateAccount: @escaping ActivateAccount
    ) {
        self.config = config
        self.loadState = loadState
        self.saveState = saveState
        self.now = now
        self.activateAccount = activateAccount
    }

    public func evaluateAndSwitch(
        provider: Provider,
        activeAccountID: UUID,
        candidates: [CodexAutoSwitchCandidate]
    ) async throws -> CodexAutoSwitchDecision {
        let checkedAt = now()

        guard config.enabled else {
            return CodexAutoSwitchDecision(
                reason: .disabled,
                fromAccountID: activeAccountID,
                toAccountID: nil,
                currentRemainingPercent: nil,
                targetRemainingPercent: nil,
                checkedAt: checkedAt
            )
        }

        guard let activeCandidate = candidates.first(where: { $0.account.id == activeAccountID }) else {
            return CodexAutoSwitchDecision(
                reason: .noActiveAccount,
                fromAccountID: activeAccountID,
                toAccountID: nil,
                currentRemainingPercent: nil,
                targetRemainingPercent: nil,
                checkedAt: checkedAt
            )
        }

        guard let currentRemainingPercent = activeCandidate.primaryRemainingPercent else {
            return CodexAutoSwitchDecision(
                reason: .missingQuota,
                fromAccountID: activeAccountID,
                toAccountID: nil,
                currentRemainingPercent: nil,
                targetRemainingPercent: nil,
                checkedAt: checkedAt
            )
        }

        guard currentRemainingPercent <= config.thresholdPercent else {
            return CodexAutoSwitchDecision(
                reason: .thresholdNotReached,
                fromAccountID: activeAccountID,
                toAccountID: nil,
                currentRemainingPercent: currentRemainingPercent,
                targetRemainingPercent: nil,
                checkedAt: checkedAt
            )
        }

        let state = await loadState()
        if let lastSwitchedAt = state.lastSwitchedAtByProviderID[provider.id],
           config.cooldown > 0,
           checkedAt.timeIntervalSince(lastSwitchedAt) < config.cooldown
        {
            return CodexAutoSwitchDecision(
                reason: .cooldownActive,
                fromAccountID: activeAccountID,
                toAccountID: nil,
                currentRemainingPercent: currentRemainingPercent,
                targetRemainingPercent: nil,
                checkedAt: checkedAt,
                cooldownUntil: lastSwitchedAt.addingTimeInterval(config.cooldown)
            )
        }

        let rankedCandidates = candidates
            .filter { candidate in
                guard candidate.account.id != activeAccountID else { return false }
                guard candidate.isSchedulable else { return false }
                guard let remainingPercent = candidate.primaryRemainingPercent else { return false }
                guard remainingPercent >= config.minimumCandidateRemainingPercent else { return false }
                if config.skipRelayAccounts, candidate.cardKind == .relayProfile {
                    return false
                }
                return true
            }
            .sorted { lhs, rhs in
                let lhsRemaining = lhs.primaryRemainingPercent ?? 0
                let rhsRemaining = rhs.primaryRemainingPercent ?? 0
                if lhsRemaining != rhsRemaining {
                    return lhsRemaining > rhsRemaining
                }
                if lhs.account.createdAt != rhs.account.createdAt {
                    return lhs.account.createdAt < rhs.account.createdAt
                }
                return lhs.account.id.uuidString < rhs.account.id.uuidString
            }

        guard let selected = rankedCandidates.first,
              let targetRemainingPercent = selected.primaryRemainingPercent
        else {
            return CodexAutoSwitchDecision(
                reason: .noCandidate,
                fromAccountID: activeAccountID,
                toAccountID: nil,
                currentRemainingPercent: currentRemainingPercent,
                targetRemainingPercent: nil,
                checkedAt: checkedAt
            )
        }

        try await activateAccount(selected.account, provider)

        var nextState = state
        nextState.lastSwitchedAtByProviderID[provider.id] = checkedAt
        try await saveState(nextState)

        return CodexAutoSwitchDecision(
            reason: .switched,
            fromAccountID: activeAccountID,
            toAccountID: selected.account.id,
            currentRemainingPercent: currentRemainingPercent,
            targetRemainingPercent: targetRemainingPercent,
            checkedAt: checkedAt
        )
    }
}

public protocol CodexAutoSwitchStateStoring: Sendable {
    func load() async -> CodexAutoSwitchState
    func save(_ state: CodexAutoSwitchState) async throws
}

public protocol CodexAutoSwitchEventStoring: Sendable {
    func append(_ event: CodexAutoSwitchEvent) async throws
    func recentEvents(limit: Int) async -> [CodexAutoSwitchEvent]
}

public protocol CodexAutoSwitchStatusStoring: Sendable {
    func load() async -> CodexAutoSwitchStatusSnapshot?
    func save(_ snapshot: CodexAutoSwitchStatusSnapshot) async throws
}

public actor CodexAutoSwitchStateStore: CodexAutoSwitchStateStoring {
    private let file: STFile

    public init(file: STFile) {
        self.file = file
    }

    public init(authManager: CodexAuthManager = CodexAuthManager()) {
        self.file = authManager.nolonCodexRootFolder().folder("auto-switch").file("state.json")
    }

    public func load() async -> CodexAutoSwitchState {
        guard let data = try? file.data(),
              !data.isEmpty,
              let state = try? JSONDecoder().decode(CodexAutoSwitchState.self, from: data)
        else {
            return CodexAutoSwitchState()
        }
        return state
    }

    public func save(_ state: CodexAutoSwitchState) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(state)
        _ = file.parentFolder()?.createIfNotExists()
        try file.overlay(with: data)
    }
}

public actor CodexAutoSwitchEventStore: CodexAutoSwitchEventStoring {
    private let file: STFile
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(file: STFile) {
        self.file = file
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    public init(authManager: CodexAuthManager = CodexAuthManager()) {
        self.init(file: authManager.nolonCodexRootFolder().folder("auto-switch").file("events.jsonl"))
    }

    public func append(_ event: CodexAutoSwitchEvent) async throws {
        let data = try encoder.encode(event)
        let line = String(decoding: data, as: UTF8.self) + "\n"
        _ = file.parentFolder()?.createIfNotExists()
        let existing = (try? file.read()) ?? ""
        try file.overlay(with: existing + line)
    }

    public func recentEvents(limit: Int) async -> [CodexAutoSwitchEvent] {
        guard limit > 0,
              let content = try? file.read(),
              !content.isEmpty
        else {
            return []
        }

        let lines = content
            .split(separator: "\n")
            .suffix(limit)

        return lines.reversed().compactMap { line in
            guard let data = String(line).data(using: .utf8) else { return nil }
            return try? decoder.decode(CodexAutoSwitchEvent.self, from: data)
        }
    }
}

public actor CodexAutoSwitchStatusStore: CodexAutoSwitchStatusStoring {
    private let file: STFile

    public init(file: STFile) {
        self.file = file
    }

    public init(authManager: CodexAuthManager = CodexAuthManager()) {
        self.init(file: authManager.nolonCodexRootFolder().folder("auto-switch").file("status.json"))
    }

    public func load() async -> CodexAutoSwitchStatusSnapshot? {
        guard let data = try? file.data(),
              !data.isEmpty
        else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(CodexAutoSwitchStatusSnapshot.self, from: data)
    }

    public func save(_ snapshot: CodexAutoSwitchStatusSnapshot) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        _ = file.parentFolder()?.createIfNotExists()
        try file.overlay(with: data)
    }
}

public actor CodexAutoSwitchService {
    public typealias LoadAccounts = @Sendable () async throws -> [CodexAuthAccount]
    public typealias ActiveAccountID = @Sendable (Provider) async -> UUID?
    public typealias LoadUsageCache = @Sendable (CodexAuthAccount) async throws -> CodexAuthUsageCache?
    public typealias LoadSummary = @Sendable (CodexAuthAccount) async -> CodexAuthSummary

    private let coordinator: CodexAutoSwitchCoordinator
    private let loadAccounts: LoadAccounts
    private let activeAccountID: ActiveAccountID
    private let loadUsageCache: LoadUsageCache
    private let loadSummary: LoadSummary
    private let statusStore: (any CodexAutoSwitchStatusStoring)?
    private let eventStore: (any CodexAutoSwitchEventStoring)?
    private let config: CodexAutoSwitchConfig

    public init(
        config: CodexAutoSwitchConfig = CodexAutoSwitchConfig(),
        authManager: CodexAuthManager = CodexAuthManager(),
        stateStore: (any CodexAutoSwitchStateStoring)? = nil,
        statusStore: (any CodexAutoSwitchStatusStoring)? = nil,
        eventStore: (any CodexAutoSwitchEventStoring)? = nil,
        activationCoordinator: CodexAuthActivationCoordinator = .shared
    ) {
        self.config = config
        let resolvedStateStore = stateStore ?? CodexAutoSwitchStateStore(authManager: authManager)
        let resolvedStatusStore = statusStore ?? CodexAutoSwitchStatusStore(authManager: authManager)
        let resolvedEventStore = eventStore ?? CodexAutoSwitchEventStore(authManager: authManager)
        self.coordinator = CodexAutoSwitchCoordinator(
            config: config,
            loadState: { await resolvedStateStore.load() },
            saveState: { state in try await resolvedStateStore.save(state) },
            activateAccount: { account, provider in
                _ = try await activationCoordinator.activate(account: account, provider: provider)
            }
        )
        self.loadAccounts = { try await authManager.loadAccounts() }
        self.activeAccountID = { provider in await authManager.activeAccountId(for: provider) }
        self.loadUsageCache = { account in try await authManager.loadUsageCache(for: account) }
        self.loadSummary = { account in
            let file = authManager.accountAuthFile(relativeAuthPath: account.relativeAuthPath)
            guard let data = try? file.data(), !data.isEmpty else {
                return CodexAuthSummary()
            }
            return CodexAuthSummary.fromJSONData(data)
        }
        self.statusStore = resolvedStatusStore
        self.eventStore = resolvedEventStore
    }

    init(
        coordinator: CodexAutoSwitchCoordinator,
        loadAccounts: @escaping LoadAccounts,
        activeAccountID: @escaping ActiveAccountID,
        loadUsageCache: @escaping LoadUsageCache,
        loadSummary: @escaping LoadSummary,
        config: CodexAutoSwitchConfig = CodexAutoSwitchConfig(),
        statusStore: (any CodexAutoSwitchStatusStoring)? = nil,
        eventStore: (any CodexAutoSwitchEventStoring)? = nil
    ) {
        self.config = config
        self.coordinator = coordinator
        self.loadAccounts = loadAccounts
        self.activeAccountID = activeAccountID
        self.loadUsageCache = loadUsageCache
        self.loadSummary = loadSummary
        self.statusStore = statusStore
        self.eventStore = eventStore
    }

    public func evaluateAndSwitchIfNeeded(for provider: Provider) async throws -> CodexAutoSwitchDecision {
        let decision: CodexAutoSwitchDecision

        guard let activeAccountID = await activeAccountID(provider) else {
            decision = CodexAutoSwitchDecision(
                reason: .noActiveAccount,
                fromAccountID: nil,
                toAccountID: nil,
                currentRemainingPercent: nil,
                targetRemainingPercent: nil,
                checkedAt: Date()
            )
            await persist(decision: decision, for: provider)
            return decision
        }

        let accounts = try await loadAccounts()
        let candidates = try await accounts.asyncMap { account in
            let usageCache = try await loadUsageCache(account)
            let summary = await loadSummary(account)
            return CodexAutoSwitchCandidate(
                account: account,
                cardKind: summary.cardKind,
                usage: usageCache?.usage,
                isSchedulable: true,
                lastActivatedAt: nil
            )
        }

        decision = try await coordinator.evaluateAndSwitch(
            provider: provider,
            activeAccountID: activeAccountID,
            candidates: candidates
        )
        await persist(decision: decision, for: provider)
        return decision
    }

    private func persist(decision: CodexAutoSwitchDecision, for provider: Provider) async {
        if let statusStore {
            let snapshot = CodexAutoSwitchStatusSnapshot(
                providerID: provider.id,
                config: config,
                lastDecision: decision,
                lastUpdatedAt: decision.checkedAt
            )
            try? await statusStore.save(snapshot)
        }
        if let eventStore {
            try? await eventStore.append(CodexAutoSwitchEvent(providerID: provider.id, decision: decision))
        }
    }
}

private extension Array {
    func asyncMap<T: Sendable>(_ transform: @Sendable (Element) async throws -> T) async rethrows -> [T] {
        var results: [T] = []
        results.reserveCapacity(count)
        for element in self {
            let value = try await transform(element)
            results.append(value)
        }
        return results
    }
}
