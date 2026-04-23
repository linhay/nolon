import Foundation

public enum CodexSessionEvent: Sendable, Equatable {
    case sessionMeta(timestamp: String?, payload: CodexRolloutLine.SessionMetaLine)
    case responseItem(timestamp: String?, payload: CodexRolloutLine.ResponseItem)
    case compacted(timestamp: String?, payload: CodexRolloutLine.CompactedItem)
    case turnContext(timestamp: String?, payload: CodexRolloutLine.TurnContext)
    case eventMessage(timestamp: String?, payload: CodexRolloutLine.EventMessage)
    case tokenCount(timestamp: String?, payload: CodexRolloutLine.TokenCount)
    case other(timestamp: String?, type: String)
}

public enum CodexSessionUsageEvent: Sendable, Equatable {
    case sessionMeta(sessionID: String?)
    case turnContext(model: String?)
    case tokenCount(timestamp: String?, payload: CodexRolloutLine.TokenCount)
}

public struct CodexSessionTokenTotals: Sendable, Equatable {
    public let inputTokens: Int
    public let cachedInputTokens: Int
    public let outputTokens: Int
    public let requestCount: Int

    public init(
        inputTokens: Int,
        cachedInputTokens: Int,
        outputTokens: Int,
        requestCount: Int = 0
    ) {
        self.inputTokens = inputTokens
        self.cachedInputTokens = cachedInputTokens
        self.outputTokens = outputTokens
        self.requestCount = requestCount
    }
}

public struct CodexSessionTokenDelta: Sendable, Equatable {
    public let timestamp: String?
    public let model: String
    public let inputTokens: Int
    public let cachedInputTokens: Int
    public let outputTokens: Int
    public let requestCount: Int

    public init(
        timestamp: String?,
        model: String,
        inputTokens: Int,
        cachedInputTokens: Int,
        outputTokens: Int,
        requestCount: Int = 1)
    {
        self.timestamp = timestamp
        self.model = model
        self.inputTokens = inputTokens
        self.cachedInputTokens = cachedInputTokens
        self.outputTokens = outputTokens
        self.requestCount = requestCount
    }
}

public struct CodexSessionUsageReduction: Sendable, Equatable {
    public let sessionID: String?
    public let updatedModel: String?
    public let updatedTotals: CodexSessionTokenTotals?
    public let tokenDelta: CodexSessionTokenDelta?

    public init(
        sessionID: String? = nil,
        updatedModel: String?,
        updatedTotals: CodexSessionTokenTotals?,
        tokenDelta: CodexSessionTokenDelta?)
    {
        self.sessionID = sessionID
        self.updatedModel = updatedModel
        self.updatedTotals = updatedTotals
        self.tokenDelta = tokenDelta
    }
}

public enum CodexSessionEventParser {
    struct FastRolloutEnvelope: Equatable, Sendable {
        let timestamp: String?
        let type: String?
    }

    public static func parseEventLine(data: Data) throws -> CodexSessionEvent {
        let parsed = try CodexGeneratedFilesParser.parseRolloutLine(data: data)
        switch parsed.item {
        case let .sessionMeta(meta):
            return .sessionMeta(timestamp: parsed.timestamp, payload: meta)
        case let .responseItem(item):
            return .responseItem(timestamp: parsed.timestamp, payload: item)
        case let .compacted(item):
            return .compacted(timestamp: parsed.timestamp, payload: item)
        case let .turnContext(context):
            return .turnContext(timestamp: parsed.timestamp, payload: context)
        case let .eventMsg(message):
            return .eventMessage(timestamp: parsed.timestamp, payload: message)
        case let .tokenCount(tokenCount):
            return .tokenCount(timestamp: parsed.timestamp, payload: tokenCount)
        case let .other(type):
            return .other(timestamp: parsed.timestamp, type: type)
        }
    }

    public static func parseEventLine(text: String) throws -> CodexSessionEvent {
        guard let data = text.data(using: .utf8) else {
            throw CodexGeneratedFilesError.invalidUTF8
        }
        return try parseEventLine(data: data)
    }

    // Usage scanner fast path: only parse lines that can affect usage/session stats.
    public static func parseUsageEventLine(data: Data) -> CodexSessionUsageEvent? {
        if data.isEmpty { return nil }
        guard let envelope = fastTopLevelEnvelope(data: data),
              let lineType = envelope.type
        else {
            return nil
        }

        switch lineType {
        case "session_meta", "turn_context", "token_count":
            break
        case "event_msg":
            guard containsASCII(data: data, text: #"token_count"#) else { return nil }
        default:
            return nil
        }

        guard let event = try? parseEventLine(data: data) else { return nil }
        switch event {
        case let .sessionMeta(_, payload):
            return .sessionMeta(sessionID: payload.id)
        case let .turnContext(_, payload):
            return .turnContext(model: payload.model)
        case let .tokenCount(timestamp, payload):
            return .tokenCount(timestamp: timestamp, payload: payload)
        case .responseItem, .compacted, .eventMessage, .other:
            return nil
        }
    }

    // Reduce one rollout JSONL line into usage state updates and optional token delta.
    public static func reduceUsageLine(
        data: Data,
        currentModel: String?,
        previousTotals: CodexSessionTokenTotals?) -> CodexSessionUsageReduction?
    {
        guard let usageEvent = parseUsageEventLine(data: data) else { return nil }

        switch usageEvent {
        case let .sessionMeta(sessionID):
            return .init(
                sessionID: sessionID,
                updatedModel: currentModel,
                updatedTotals: previousTotals,
                tokenDelta: nil)

        case let .turnContext(model):
            let nextModel: String?
            if let model, !model.isEmpty {
                nextModel = model
            } else {
                nextModel = currentModel
            }
            return .init(
                sessionID: nil,
                updatedModel: nextModel,
                updatedTotals: previousTotals,
                tokenDelta: nil)

        case let .tokenCount(timestamp, tokenCount):
            let model = tokenCount.model ?? currentModel ?? "gpt-5"
            var nextTotals = previousTotals

            var deltaInput = 0
            var deltaCached = 0
            var deltaOutput = 0

            if let total = tokenCount.totalUsage {
                let prev = previousTotals
                deltaInput = max(0, total.inputTokens - (prev?.inputTokens ?? 0))
                deltaCached = max(0, total.cachedInputTokens - (prev?.cachedInputTokens ?? 0))
                deltaOutput = max(0, total.outputTokens - (prev?.outputTokens ?? 0))
                nextTotals = .init(
                    inputTokens: total.inputTokens,
                    cachedInputTokens: total.cachedInputTokens,
                    outputTokens: total.outputTokens,
                    requestCount: previousTotals?.requestCount ?? 0
                )
            } else if let last = tokenCount.lastUsage {
                deltaInput = max(0, last.inputTokens)
                deltaCached = max(0, last.cachedInputTokens)
                deltaOutput = max(0, last.outputTokens)
            } else {
                return nil
            }

            let clampedCached = min(deltaCached, deltaInput)
            let tokenDelta: CodexSessionTokenDelta? =
                if deltaInput == 0, clampedCached == 0, deltaOutput == 0 {
                    nil
                } else {
                    .init(
                        timestamp: timestamp,
                        model: model,
                        inputTokens: deltaInput,
                        cachedInputTokens: clampedCached,
                        outputTokens: deltaOutput,
                        requestCount: 1
                    )
                }

            return .init(
                sessionID: nil,
                updatedModel: model,
                updatedTotals: nextTotals,
                tokenDelta: tokenDelta)
        }
    }

    private static func containsASCII(data: Data, text: String) -> Bool {
        data.range(of: Data(text.utf8)) != nil
    }

    static func fastTopLevelTimestamp(data: Data) -> String? {
        fastTopLevelEnvelope(data: data)?.timestamp
    }

    static func fastTopLevelEnvelope(data: Data) -> FastRolloutEnvelope? {
        guard !data.isEmpty else { return nil }

        var depth = 0
        var inString = false
        var escaping = false
        var currentString = [UInt8]()
        var pendingTopLevelKey: String?
        var expectingValueForKey = false
        var currentStringPurpose: StringPurpose?
        var timestamp: String?
        var type: String?

        for byte in data {
            if inString {
                if escaping {
                    currentString.append(byte)
                    escaping = false
                    continue
                }

                switch byte {
                case 0x5C:
                    escaping = true
                case 0x22:
                    let decoded = String(decoding: currentString, as: UTF8.self)
                    currentString.removeAll(keepingCapacity: true)
                    inString = false

                    switch currentStringPurpose {
                    case .key:
                        pendingTopLevelKey = decoded
                    case .value:
                        if pendingTopLevelKey == "timestamp" {
                            timestamp = decoded
                        } else if pendingTopLevelKey == "type" {
                            type = decoded
                        }
                        pendingTopLevelKey = nil
                        expectingValueForKey = false
                        if timestamp != nil, type != nil {
                            return .init(timestamp: timestamp, type: type)
                        }
                    case .none:
                        break
                    }
                    currentStringPurpose = nil
                default:
                    currentString.append(byte)
                }
                continue
            }

            switch byte {
            case 0x7B, 0x5B:
                if depth == 1, expectingValueForKey {
                    pendingTopLevelKey = nil
                    expectingValueForKey = false
                }
                depth += 1

            case 0x7D, 0x5D:
                depth = max(0, depth - 1)
                if depth == 1 {
                    pendingTopLevelKey = nil
                    expectingValueForKey = false
                }

            case 0x22:
                guard depth == 1 else { continue }
                inString = true
                currentString.removeAll(keepingCapacity: true)
                currentStringPurpose = expectingValueForKey ? .value : .key

            case 0x3A:
                if depth == 1, pendingTopLevelKey != nil {
                    expectingValueForKey = true
                }

            case 0x2C:
                if depth == 1 {
                    pendingTopLevelKey = nil
                    expectingValueForKey = false
                }

            case 0x20, 0x09, 0x0A, 0x0D:
                continue

            default:
                if depth == 1, expectingValueForKey {
                    pendingTopLevelKey = nil
                    expectingValueForKey = false
                }
            }
        }

        if timestamp != nil || type != nil {
            return .init(timestamp: timestamp, type: type)
        }
        return nil
    }

    private enum StringPurpose {
        case key
        case value
    }
}
