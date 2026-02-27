import Foundation

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
        try JSONSerialization.data(withJSONObject: params)
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
            throw errorFactory("Failed to start process: \(error.localizedDescription)")
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
            continuation.resume(throwing: errorFactory("JSON-RPC session shutdown"))
        }
        pending.removeAll()
    }

    public func request(method: String, paramsData: Data = Data("{}".utf8)) async throws -> JsonRPCResponseMessage {
        try startIfNeeded()
        let id = JsonRPCID.int(nextID)
        nextID += 1

        let params = try JSONSerialization.jsonObject(with: paramsData)

        return try await withCheckedThrowingContinuation { continuation in
            pending[id] = continuation
            Task {
                do {
                    try await sendPayload([
                        "jsonrpc": "2.0",
                        "id": id.rawValue,
                        "method": method,
                        "params": params,
                    ])
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
        let paramsValue = try JSONSerialization.jsonObject(with: paramsData)
        try await sendPayload([
            "jsonrpc": "2.0",
            "method": method,
            "params": paramsValue,
        ])
    }

    private func sendPayload(_ payload: [String: Any]) async throws {
        guard let stdinHandle else {
            throw errorFactory("JSON-RPC stdin unavailable")
        }
        let data = try JSONSerialization.data(withJSONObject: payload)
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
        let jsonObj = try JSONSerialization.jsonObject(with: lineData)
        guard let message = jsonObj as? [String: Any] else {
            throw errorFactory("Invalid JSON-RPC message")
        }

        let messageID = JsonRPCID(any: message["id"])
        let hasMethod = message["method"] != nil

        if let messageID, !hasMethod {
            let result = message["result"]
            let errorObj = (message["error"] as? [String: Any]).flatMap { obj -> JsonRPCErrorObject? in
                guard let code = (obj["code"] as? NSNumber)?.intValue,
                      let msg = obj["message"] as? String
                else { return nil }
                return JsonRPCErrorObject(code: code, message: msg)
            }
            let response = JsonRPCResponseMessage(id: messageID, result: result, error: errorObj)
            if let continuation = pending.removeValue(forKey: messageID) {
                continuation.resume(returning: response)
            }
            return
        }

        guard let method = message["method"] as? String else {
            return
        }

        if let messageID {
            let request = JsonRPCServerRequestMessage(id: messageID, method: method, params: message["params"])
            await handleServerRequest(request)
            return
        }

        let notification = JsonRPCNotificationMessage(method: method, params: message["params"])
        if let notificationHandler {
            await notificationHandler(notification)
        }
    }

    private func handleServerRequest(_ request: JsonRPCServerRequestMessage) async {
        do {
            let result = try await serverRequestHandler?(request) ?? [:]
            try await sendPayload([
                "jsonrpc": "2.0",
                "id": request.id.rawValue,
                "result": result,
            ])
        } catch {
            let message = error.localizedDescription
            try? await sendPayload([
                "jsonrpc": "2.0",
                "id": request.id.rawValue,
                "error": [
                    "code": -32000,
                    "message": message,
                ],
            ])
        }
    }
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
