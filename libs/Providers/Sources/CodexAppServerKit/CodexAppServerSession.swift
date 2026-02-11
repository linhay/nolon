import Foundation
import JsonRPCKit
import CodexCLIKit

public actor CodexAppServerSession {
    public typealias NotificationHandler = @Sendable (CodexRPCNotificationMessage) async -> Void
    public typealias ServerRequestHandler = @Sendable (CodexRPCServerRequestMessage) async throws -> Any

    private let rpcSession: JsonRPCLineProcessSession
    private var userNotificationHandler: NotificationHandler?
    private var notificationWaiters: [String: [UUID: CheckedContinuation<CodexRPCNotificationMessage, Error>]] = [:]
    private var handlersInstalled = false

    public init(
        executable: String = "codex",
        environment: [String: String] = ProcessInfo.processInfo.environment,
        startupArguments: [String] = ["app-server"]
    ) {
        let commandExecutor = CodexCommandExecutor(executable: executable, environment: environment)
        let resolved = commandExecutor.resolveExecutable()

        // Delay failure to first request/initialize for compatibility with current callers.
        let executableURL = URL(fileURLWithPath: resolved ?? executable)
        self.rpcSession = JsonRPCLineProcessSession(
            executableURL: executableURL,
            environment: environment,
            startupArguments: startupArguments
        ) { message in
            CodexCLIError.protocolError(message)
        }
    }

    public static func encodeParams(_ params: Any) throws -> Data {
        try JsonRPCLineProcessSession.encodeParams(params)
    }

    public func setNotificationHandler(_ handler: NotificationHandler?) async {
        userNotificationHandler = handler
        await ensureHandlersInstalled()
    }

    public func setServerRequestHandler(_ handler: ServerRequestHandler?) async {
        await rpcSession.setServerRequestHandler(handler)
    }

    public func startIfNeeded() async throws {
        do {
            await ensureHandlersInstalled()
            try await rpcSession.startIfNeeded()
        } catch {
            throw mapError(error)
        }
    }

    public func shutdown() async {
        let waiters = notificationWaiters
        notificationWaiters.removeAll()
        for (_, methodWaiters) in waiters {
            for (_, continuation) in methodWaiters {
                continuation.resume(throwing: CodexCLIError.protocolError("JSON-RPC session shutdown"))
            }
        }
        await rpcSession.shutdown()
    }

    public func initialize(clientName: String, clientVersion: String, experimentalApi: Bool = true) async throws {
        let params: [String: Any] = [
            "clientInfo": [
                "name": clientName,
                "version": clientVersion,
            ],
            "capabilities": [
                "experimentalApi": experimentalApi,
            ],
        ]

        _ = try await request(method: .initialize, params: params)
        try await notify(method: .initialized, params: [:])
    }

    public func request(method: String, paramsData: Data = Data("{}".utf8)) async throws -> CodexRPCResponseMessage {
        do {
            let response = try await rpcSession.request(method: method, paramsData: paramsData)
            let codexResponse = CodexRPCResponseMessage(id: response.id, result: response.result, error: response.error)
            if let error = codexResponse.error {
                throw CodexCLIError.protocolError("\(error.code): \(error.message)")
            }
            return codexResponse
        } catch {
            throw mapError(error)
        }
    }

    public func notify(method: String, paramsData: Data = Data("{}".utf8)) async throws {
        do {
            try await rpcSession.notify(method: method, paramsData: paramsData)
        } catch {
            throw mapError(error)
        }
    }

    private func mapError(_ error: Error) -> Error {
        if let codexError = error as? CodexCLIError {
            return codexError
        }
        return CodexCLIError.protocolError(error.localizedDescription)
    }

    public func request(method: CodexAppServerMethod, params: Any = [:]) async throws -> CodexRPCResponseMessage {
        let data = try Self.encodeParams(params)
        return try await request(method: method.rawValue, paramsData: data)
    }

    public func notify(method: CodexAppServerClientNotification, params: Any = [:]) async throws {
        let data = try Self.encodeParams(params)
        try await notify(method: method.rawValue, paramsData: data)
    }

    public func waitForNotification(
        method: CodexAppServerServerNotification,
        timeout: TimeInterval = 8
    ) async throws -> CodexRPCNotificationMessage {
        try await startIfNeeded()

        let waitID = UUID()
        return try await withCheckedThrowingContinuation { continuation in
            var methodWaiters = notificationWaiters[method.rawValue] ?? [:]
            methodWaiters[waitID] = continuation
            notificationWaiters[method.rawValue] = methodWaiters

            Task {
                let nanoseconds = UInt64(max(0.1, timeout) * 1_000_000_000.0)
                try? await Task.sleep(nanoseconds: nanoseconds)
                await timeoutWaiterIfNeeded(method: method.rawValue, waitID: waitID, timeout: timeout)
            }
        }
    }

    private func ensureHandlersInstalled() async {
        guard !handlersInstalled else { return }
        handlersInstalled = true
        await rpcSession.setNotificationHandler { [weak self] notification in
            guard let self else { return }
            await self.handleIncomingNotification(notification)
        }
    }

    private func handleIncomingNotification(_ notification: JsonRPCNotificationMessage) async {
        let codexNotification = CodexRPCNotificationMessage(method: notification.method, params: notification.params)
        if let handler = userNotificationHandler {
            await handler(codexNotification)
        }

        guard let waiters = notificationWaiters.removeValue(forKey: notification.method), !waiters.isEmpty else { return }
        for (_, continuation) in waiters {
            continuation.resume(returning: codexNotification)
        }
    }

    private func timeoutWaiterIfNeeded(method: String, waitID: UUID, timeout: TimeInterval) async {
        guard var waiters = notificationWaiters[method] else { return }
        guard let continuation = waiters.removeValue(forKey: waitID) else { return }
        if waiters.isEmpty {
            notificationWaiters.removeValue(forKey: method)
        } else {
            notificationWaiters[method] = waiters
        }
        continuation.resume(throwing: CodexCLIError.protocolError("Timed out waiting for notification '\(method)' in \(timeout)s"))
    }
}
