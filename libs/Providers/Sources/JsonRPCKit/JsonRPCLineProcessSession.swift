import Foundation
import STJSON

public actor JsonRPCLineProcessSession {
    public typealias NotificationHandler = @Sendable (JsonRPCNotificationMessage) async -> Void
    public typealias ServerRequestHandler = @Sendable (JsonRPCServerRequestMessage) async throws -> Any

    private let executableURL: URL
    private let environment: [String: String]
    private let startupArguments: [String]
    private let errorFactory: @Sendable (String) -> Error

    private var process: Process?
    private var stdinHandle: FileHandle?
    private var stdoutLines: AsyncStream<Data>?
    private var nextID: Int = 1
    private var readerTask: Task<Void, Never>?

    private var pending: [JsonRPCID: CheckedContinuation<JsonRPCResponseMessage, Error>] = [:]
    private var notificationHandler: NotificationHandler?
    private var serverRequestHandler: ServerRequestHandler?

    public init(
        executableURL: URL,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        startupArguments: [String],
        errorFactory: @escaping @Sendable (String) -> Error
    ) {
        self.executableURL = executableURL
        self.environment = environment
        self.startupArguments = startupArguments
        self.errorFactory = errorFactory
    }

    deinit {
        readerTask?.cancel()
    }

    public static func encodeParams(_ params: Any) throws -> Data {
        let rpcParams = try paramsContainer(from: params)
        return try JSONEncoder().encode(rpcParams)
    }

    public func setNotificationHandler(_ handler: NotificationHandler?) {
        notificationHandler = handler
    }

    public func setServerRequestHandler(_ handler: ServerRequestHandler?) {
        serverRequestHandler = handler
    }

    public func startIfNeeded() throws {
        if process?.isRunning == true {
            return
        }

        let process = Process()
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = executableURL
        process.arguments = startupArguments
        process.environment = environment
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            throw JsonRPCSessionError.transport("Failed to start process: \(error.localizedDescription)")
        }

        let continuationBox = DataStreamContinuationBox()
        let stream = AsyncStream<Data> { continuation in
            continuationBox.set(continuation)
        }

        let lineBuffer = LineBuffer()
        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                continuationBox.finish()
                return
            }
            let lines = lineBuffer.appendAndDrainLines(data)
            for line in lines where !line.isEmpty {
                continuationBox.yield(line)
            }
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                return
            }
        }

        self.process = process
        self.stdinHandle = stdinPipe.fileHandleForWriting
        self.stdoutLines = stream

        readerTask = Task {
            await readLoop()
        }
    }

    public func shutdown() {
        readerTask?.cancel()
        readerTask = nil

        if let process, process.isRunning {
            process.terminate()
        }
        process = nil
        stdinHandle = nil
        stdoutLines = nil

        for (_, continuation) in pending {
            continuation.resume(throwing: JsonRPCSessionError.shutdown)
        }
        pending.removeAll()
    }

    public func request(method: String, paramsData: Data = Data("{}".utf8)) async throws -> JsonRPCResponseMessage {
        try startIfNeeded()
        let id = JsonRPCID.int(nextID)
        nextID += 1

        let requestPayload = try makeOutboundRequest(method: method, paramsData: paramsData, id: id)
        let encodedRequest = try JSONEncoder().encode(requestPayload)

        return try await withCheckedThrowingContinuation { continuation in
            pending[id] = continuation
            Task {
                do {
                    try await sendLineData(encodedRequest)
                } catch {
                    if let pending = self.pending.removeValue(forKey: id) {
                        pending.resume(throwing: error)
                    }
                }
            }
        }
    }

    public func notify(method: String, paramsData: Data = Data("{}".utf8)) async throws {
        try startIfNeeded()
        let requestPayload = try makeOutboundRequest(method: method, paramsData: paramsData, id: nil)
        let encodedRequest = try JSONEncoder().encode(requestPayload)
        try await sendLineData(encodedRequest)
    }

    private func sendLineData(_ data: Data) async throws {
        guard let stdinHandle else {
            throw JsonRPCSessionError.transport("JSON-RPC stdin unavailable")
        }
        stdinHandle.write(data)
        stdinHandle.write(Data([0x0A]))
    }

    private func readLoop() async {
        guard let stream = stdoutLines else { return }
        for await line in stream {
            do {
                try await handleIncomingLine(line)
            } catch {
                continue
            }
        }
    }

    private func handleIncomingLine(_ lineData: Data) async throws {
        let envelope: JsonRPCInboundEnvelope
        do {
            envelope = try JSONDecoder().decode(JsonRPCInboundEnvelope.self, from: lineData)
        } catch {
            throw JsonRPCSessionError.invalidMessage
        }

        if envelope.method == nil, let rawID = envelope.id {
            guard let messageID = try Self.sessionIDOrNil(from: rawID) else {
                return
            }
            do {
                let model = try JSONDecoder().decode(JSONRPC.Response.self, from: lineData)
                if let modelID = model.id {
                    let parsedID = try Self.sessionID(from: modelID)
                    guard parsedID == messageID else {
                        throw JsonRPCSessionError.invalidResponse("JSON-RPC response id mismatch")
                    }
                }
                let response = JsonRPCResponseMessage(
                    id: messageID,
                    result: model.result.map { jsonValue(fromAnyCodable: $0) },
                    error: model.error.map { JsonRPCErrorObject(code: $0.code.value, message: $0.message) }
                )
                if let continuation = pending.removeValue(forKey: messageID) {
                    continuation.resume(returning: response)
                }
            } catch {
                if let continuation = pending.removeValue(forKey: messageID) {
                    let mapped = mapResponseError(error)
                    continuation.resume(throwing: mapped)
                }
            }
            return
        }

        guard let method = envelope.method else {
            return
        }

        // Validate inbound request/notification with JSON-RPC 2.0 strict parser.
        let validatedRequest = try decodeValidatedRequest(from: lineData, expectedMethod: method)
        let paramsValue = jsonValue(from: validatedRequest.params)

        if let requestID = try Self.sessionIDOrNil(from: validatedRequest.id) {
            let request = JsonRPCServerRequestMessage(id: requestID, method: method, params: paramsValue)
            await handleServerRequest(request)
            return
        }

        let notification = JsonRPCNotificationMessage(method: method, params: paramsValue)
        if let notificationHandler {
            await notificationHandler(notification)
        }
    }

    private func decodeValidatedRequest(from lineData: Data, expectedMethod: String) throws -> JSONRPC.Request {
        let inbound: JSONRPC.Inbound
        do {
            inbound = try JSONRPC.decodeInbound(from: lineData)
        } catch {
            throw mapProtocolError(error)
        }
        guard case let .single(request) = inbound else {
            throw JsonRPCSessionError.protocolViolation("Batch JSON-RPC inbound is not supported in line session")
        }
        guard request.method == expectedMethod else {
            throw JsonRPCSessionError.protocolViolation("JSON-RPC method mismatch")
        }
        return request
    }

    private func makeOutboundRequest(method: String, paramsData: Data, id: JsonRPCID?) throws -> JSONRPC.Request {
        let params = try decodeOutboundParams(paramsData)
        do {
            return try JSONRPC.Request(
                method: method,
                params: params,
                id: id.map(Self.jsonRPCID(from:))
            )
        } catch {
            throw mapProtocolError(error)
        }
    }

    private func decodeOutboundParams(_ paramsData: Data) throws -> JSONRPC.Params {
        do {
            return try JSONDecoder().decode(JSONRPC.Params.self, from: paramsData)
        } catch {
            throw JsonRPCSessionError.invalidParams("JSON-RPC params must be object or array")
        }
    }

    private static func jsonRPCID(from id: JsonRPCID) -> JSONRPC.ID {
        switch id {
        case let .int(value):
            return .int(value)
        case let .string(value):
            return .string(value)
        }
    }

    private static func sessionID(from id: JSONRPC.ID) throws -> JsonRPCID {
        switch id {
        case let .int(value):
            return .int(value)
        case let .string(value):
            return .string(value)
        case .null:
            throw JsonRPCSessionError.invalidResponse("JSON-RPC response id must not be null")
        }
    }

    private static func sessionIDOrNil(from id: JSONRPC.ID?) throws -> JsonRPCID? {
        guard let id else { return nil }
        switch id {
        case let .int(value):
            return .int(value)
        case let .string(value):
            return .string(value)
        case .null:
            return nil
        }
    }

    private static func anyCodable(from value: Any) -> AnyCodable {
        switch value {
        case let codable as AnyCodable:
            return codable
        case let dict as [String: Any]:
            return AnyCodable(dict.mapValues(Self.anyCodable(from:)))
        case let array as [Any]:
            return AnyCodable(array.map(Self.anyCodable(from:)))
        case let number as NSNumber:
            return AnyCodable(number)
        case let string as String:
            return AnyCodable(string)
        case let bool as Bool:
            return AnyCodable(bool)
        case is NSNull:
            return AnyCodable(nil)
        default:
            return AnyCodable(value)
        }
    }

    private static func paramsContainer(from value: Any) throws -> JSONRPC.Params {
        if let object = value as? [String: Any] {
            return .object(object.mapValues(Self.anyCodable(from:)))
        }
        if let array = value as? [Any] {
            return .array(array.map(Self.anyCodable(from:)))
        }
        throw JsonRPCSessionError.invalidParams("JSON-RPC params must be object or array")
    }

    private func jsonValue(from params: JSONRPC.Params?) -> Any? {
        guard let params else { return nil }
        switch params {
        case let .object(dict):
            return dict.mapValues { jsonValue(fromAnyCodable: $0) }
        case let .array(values):
            return values.map { jsonValue(fromAnyCodable: $0) }
        }
    }

    private func jsonValue(fromAnyCodable value: AnyCodable) -> Any {
        jsonValue(fromAny: value.value)
    }

    private func jsonValue(fromAny value: Any) -> Any {
        switch value {
        case let object as [String: AnyCodable]:
            return object.mapValues { jsonValue(fromAnyCodable: $0) }
        case let object as [String: Any]:
            return object.mapValues { jsonValue(fromAny: $0) }
        case let array as [AnyCodable]:
            return array.map { jsonValue(fromAnyCodable: $0) }
        case let array as [Any]:
            return array.map { jsonValue(fromAny: $0) }
        case is Void:
            return NSNull()
        default:
            return value
        }
    }

    private func handleServerRequest(_ request: JsonRPCServerRequestMessage) async {
        do {
            let result = try await serverRequestHandler?(request) ?? [:]
            let response = try JSONRPC.Response(
                id: Self.jsonRPCID(from: request.id),
                result: Self.anyCodable(from: result),
                error: nil
            )
            try await sendLineData(try JSONRPC.encodeResponse(response))
        } catch {
            let message = error.localizedDescription
            let errorObject = JSONRPC.ErrorObject(code: .custom(-32000), message: message)
            if let response = try? JSONRPC.Response(
                id: Self.jsonRPCID(from: request.id),
                result: nil,
                error: errorObject
            ), let data = try? JSONRPC.encodeResponse(response) {
                try? await sendLineData(data)
            }
        }
    }

    private func mapProtocolError(_ error: Error) -> JsonRPCSessionError {
        if let protocolError = error as? JSONRPC.ProtocolError {
            return .protocolViolation(protocolError.message)
        }
        if let sessionError = error as? JsonRPCSessionError {
            return sessionError
        }
        return .protocolViolation(error.localizedDescription)
    }

    private func mapResponseError(_ error: Error) -> JsonRPCSessionError {
        if let protocolError = error as? JSONRPC.ProtocolError {
            return .invalidResponse(protocolError.message)
        }
        if let sessionError = error as? JsonRPCSessionError {
            return sessionError
        }
        return .invalidResponse("Invalid JSON-RPC response: \(error.localizedDescription)")
    }
}

private struct JsonRPCInboundEnvelope: Decodable {
    let id: JSONRPC.ID?
    let method: String?
}

private final class LineBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()

    func appendAndDrainLines(_ data: Data) -> [Data] {
        lock.lock()
        defer { lock.unlock() }

        buffer.append(data)
        var lines: [Data] = []
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = Data(buffer[..<newline])
            buffer.removeSubrange(...newline)
            lines.append(line)
        }
        return lines
    }
}

private final class DataStreamContinuationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: AsyncStream<Data>.Continuation?

    func set(_ continuation: AsyncStream<Data>.Continuation) {
        lock.lock()
        defer { lock.unlock() }
        self.continuation = continuation
    }

    func yield(_ data: Data) {
        lock.lock()
        let continuation = self.continuation
        lock.unlock()
        continuation?.yield(data)
    }

    func finish() {
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        continuation?.finish()
    }
}
