import Foundation

public struct CodexHTTPUsageQuery: Sendable, Codable, Equatable {
    public var enabled: Bool?
    public var timeoutSeconds: Double?
    public var request: CodexHTTPUsageQueryRequest?
    public var credentials: CodexHTTPUsageQueryCredentials?
    public var mapping: CodexHTTPUsageQueryMapping?

    public init(
        enabled: Bool? = nil,
        timeoutSeconds: Double? = nil,
        request: CodexHTTPUsageQueryRequest? = nil,
        credentials: CodexHTTPUsageQueryCredentials? = nil,
        mapping: CodexHTTPUsageQueryMapping? = nil
    ) {
        self.enabled = enabled
        self.timeoutSeconds = timeoutSeconds
        self.request = request
        self.credentials = credentials
        self.mapping = mapping
    }

    enum CodingKeys: String, CodingKey {
        case enabled
        case timeoutSeconds
        case request
        case credentials
        case mapping
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let boolValue = try? container.decodeIfPresent(Bool.self, forKey: .enabled) {
            enabled = boolValue
        } else if let intValue = try? container.decodeIfPresent(Int.self, forKey: .enabled) {
            enabled = intValue != 0
        } else {
            enabled = nil
        }
        timeoutSeconds = try container.decodeIfPresent(Double.self, forKey: .timeoutSeconds)
        request = try container.decodeIfPresent(CodexHTTPUsageQueryRequest.self, forKey: .request)
        credentials = try container.decodeIfPresent(CodexHTTPUsageQueryCredentials.self, forKey: .credentials)
        mapping = try container.decodeIfPresent(CodexHTTPUsageQueryMapping.self, forKey: .mapping)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(enabled, forKey: .enabled)
        try container.encodeIfPresent(timeoutSeconds, forKey: .timeoutSeconds)
        try container.encodeIfPresent(request, forKey: .request)
        try container.encodeIfPresent(credentials, forKey: .credentials)
        try container.encodeIfPresent(mapping, forKey: .mapping)
    }
}

public struct CodexHTTPUsageQueryRequest: Sendable, Codable, Equatable {
    public var method: CodexHTTPMethod?
    public var url: String?
    public var headers: [String: String]?
    public var body: String?

    public init(
        method: CodexHTTPMethod? = nil,
        url: String? = nil,
        headers: [String: String]? = nil,
        body: String? = nil
    ) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
    }
}

public enum CodexHTTPMethod: String, Sendable, Codable, Equatable, CaseIterable {
    case get = "GET"
    case post = "POST"
}

public struct CodexHTTPUsageQueryCredentials: Sendable, Codable, Equatable {
    public var baseURL: String?
    public var apiKey: String?
    public var accessToken: String?
    public var userID: String?

    public init(
        baseURL: String? = nil,
        apiKey: String? = nil,
        accessToken: String? = nil,
        userID: String? = nil
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.accessToken = accessToken
        self.userID = userID
    }
}

public struct CodexHTTPUsageQueryMapping: Sendable, Codable, Equatable {
    public var planPath: String?
    public var creditsRemainingPath: String?
    public var usageUsedPath: String?
    public var usageTotalPath: String?
    public var primaryUsedPercentPath: String?
    public var primaryResetAtPath: String?
    public var primaryWindowSecondsPath: String?
    public var secondaryUsedPercentPath: String?
    public var secondaryResetAtPath: String?
    public var secondaryWindowSecondsPath: String?
    public var costTodayUSDPath: String?
    public var costLast30DaysUSDPath: String?
    public var errorMessagePath: String?

    public init(
        planPath: String? = nil,
        creditsRemainingPath: String? = nil,
        usageUsedPath: String? = nil,
        usageTotalPath: String? = nil,
        primaryUsedPercentPath: String? = nil,
        primaryResetAtPath: String? = nil,
        primaryWindowSecondsPath: String? = nil,
        secondaryUsedPercentPath: String? = nil,
        secondaryResetAtPath: String? = nil,
        secondaryWindowSecondsPath: String? = nil,
        costTodayUSDPath: String? = nil,
        costLast30DaysUSDPath: String? = nil,
        errorMessagePath: String? = nil
    ) {
        self.planPath = planPath
        self.creditsRemainingPath = creditsRemainingPath
        self.usageUsedPath = usageUsedPath
        self.usageTotalPath = usageTotalPath
        self.primaryUsedPercentPath = primaryUsedPercentPath
        self.primaryResetAtPath = primaryResetAtPath
        self.primaryWindowSecondsPath = primaryWindowSecondsPath
        self.secondaryUsedPercentPath = secondaryUsedPercentPath
        self.secondaryResetAtPath = secondaryResetAtPath
        self.secondaryWindowSecondsPath = secondaryWindowSecondsPath
        self.costTodayUSDPath = costTodayUSDPath
        self.costLast30DaysUSDPath = costLast30DaysUSDPath
        self.errorMessagePath = errorMessagePath
    }
}

public enum CodexHTTPUsageQueryConfigurationSource: Sendable, Equatable {
    case explicit
    case defaultChatGPT
}

public enum CodexHTTPUsageQueryError: LocalizedError, Sendable, Equatable {
    case invalidConfiguration(String)
    case unsafeURL(String)
    case timeout
    case networkFailure(String)
    case httpStatus(Int, message: String?)
    case invalidJSON(String)
    case mappingFailed(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidConfiguration(message):
            return message
        case let .unsafeURL(message):
            return message
        case .timeout:
            return "The HTTP usage query timed out."
        case let .networkFailure(message):
            return message
        case let .httpStatus(code, message):
            if let message, !message.isEmpty {
                return "HTTP \(code): \(message)"
            }
            return "HTTP \(code)"
        case let .invalidJSON(message):
            return message
        case let .mappingFailed(message):
            return message
        }
    }
}

public struct CodexHTTPUsageQueryResolvedConfiguration: Sendable, Equatable {
    public let query: CodexHTTPUsageQuery
    public let defaultCredentials: CodexHTTPUsageQueryCredentials
    public let cardKind: CodexAuthSummary.CardKind?
    public let source: CodexHTTPUsageQueryConfigurationSource

    public init(
        query: CodexHTTPUsageQuery,
        defaultCredentials: CodexHTTPUsageQueryCredentials,
        cardKind: CodexAuthSummary.CardKind?,
        source: CodexHTTPUsageQueryConfigurationSource
    ) {
        self.query = query
        self.defaultCredentials = defaultCredentials
        self.cardKind = cardKind
        self.source = source
    }
}

public struct CodexHTTPUsageQueryExecutor: Sendable {
    public static let authSourcePathEnvironmentKey = "NOLON_CODEX_AUTH_SOURCE_PATH"

    private let performRequest: @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)

    public init() {
        self.performRequest = Self.defaultPerformRequest
    }

    public init(
        performRequest: @escaping @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)
    ) {
        self.performRequest = performRequest
    }

    public func executeIfConfigured(
        environment: [String: String],
        includeCredits: Bool
    ) async throws -> ProviderFetchResult? {
        guard let resolved = try Self.resolveConfiguration(from: environment) else {
            return nil
        }
        return try await execute(
            resolved,
            includeCredits: includeCredits
        )
    }

    public func execute(
        _ resolved: CodexHTTPUsageQueryResolvedConfiguration,
        includeCredits: Bool
    ) async throws -> ProviderFetchResult {
        let query = resolved.query
        guard query.enabled ?? false else {
            throw CodexHTTPUsageQueryError.invalidConfiguration("HTTP usage query is disabled.")
        }
        guard let requestConfig = query.request else {
            throw CodexHTTPUsageQueryError.invalidConfiguration("HTTP usage query request is missing.")
        }
        let method = requestConfig.method ?? .get
        let timeout = try validatedTimeout(query.timeoutSeconds)
        let credentials = mergeCredentials(query.credentials, defaults: resolved.defaultCredentials)
        let templatedURL = substitute(requestConfig.url ?? "", credentials: credentials)
        let finalURL = try validatedURL(templatedURL, baseURL: credentials.baseURL)

        var request = URLRequest(url: finalURL, timeoutInterval: timeout)
        request.httpMethod = method.rawValue

        let headers = requestConfig.headers ?? [:]
        for (key, value) in headers {
            request.setValue(substitute(value, credentials: credentials), forHTTPHeaderField: key)
        }

        if method == .post,
           let body = requestConfig.body,
           !body.isEmpty
        {
            request.httpBody = Data(substitute(body, credentials: credentials).utf8)
        }

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await performRequest(request)
        } catch let error as CodexHTTPUsageQueryError {
            throw error
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorTimedOut {
                throw CodexHTTPUsageQueryError.timeout
            }
            throw CodexHTTPUsageQueryError.networkFailure(error.localizedDescription)
        }

        let jsonObject: Any
        do {
            jsonObject = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw CodexHTTPUsageQueryError.invalidJSON("HTTP usage query did not return valid JSON.")
        }

        let mapping = query.mapping ?? .init()

        guard (200 ... 299).contains(response.statusCode) else {
            let message = mappedStringValue(path: mapping.errorMessagePath, in: jsonObject)
            throw CodexHTTPUsageQueryError.httpStatus(response.statusCode, message: message)
        }

        return try makeFetchResult(
            jsonObject: jsonObject,
            mapping: mapping,
            includeCredits: includeCredits,
            cardKind: resolved.cardKind
        )
    }

    public static func resolveConfiguration(
        from environment: [String: String]
    ) throws -> CodexHTTPUsageQueryResolvedConfiguration? {
        guard let data = try loadRawAuthData(from: environment) else { return nil }
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CodexHTTPUsageQueryError.invalidJSON("Codex auth.json is not a JSON object.")
        }
        let summary = CodexAuthSummary.fromJSONData(data)
        let tokens = root["tokens"] as? [String: Any]
        let accountID = stringValue(tokens?["account_id"])
            ?? stringValue(tokens?["accountId"])
            ?? stringValue(root["account_id"])
            ?? stringValue(root["accountId"])

        let credentials = CodexHTTPUsageQueryCredentials(
            baseURL: summary.relayBaseURL,
            apiKey: stringValue(root["OPENAI_API_KEY"]),
            accessToken: stringValue(tokens?["access_token"]) ?? stringValue(tokens?["accessToken"]),
            userID: accountID
        )

        if let nolon = root["nolon"] as? [String: Any],
           let queryObject = nolon["usage_query"]
        {
            let queryData = try JSONSerialization.data(withJSONObject: queryObject)
            let decoder = JSONDecoder()
            let query = try decoder.decode(CodexHTTPUsageQuery.self, from: queryData)

            return CodexHTTPUsageQueryResolvedConfiguration(
                query: query,
                defaultCredentials: credentials,
                cardKind: summary.cardKind,
                source: .explicit
            )
        }

        guard summary.cardKind == .chatgptAccount,
              let query = makeDefaultChatGPTQuery(defaultCredentials: credentials)
        else {
            return nil
        }

        return CodexHTTPUsageQueryResolvedConfiguration(
            query: query,
            defaultCredentials: credentials,
            cardKind: summary.cardKind,
            source: .defaultChatGPT
        )
    }

    private static func makeDefaultChatGPTQuery(
        defaultCredentials: CodexHTTPUsageQueryCredentials
    ) -> CodexHTTPUsageQuery? {
        guard trimmedNonEmpty(defaultCredentials.accessToken) != nil,
              trimmedNonEmpty(defaultCredentials.userID) != nil
        else {
            return nil
        }

        let baseURL = "https://chatgpt.com/backend-api"
        return CodexHTTPUsageQuery(
            enabled: true,
            timeoutSeconds: 15,
            request: .init(
                method: .get,
                url: "{{baseURL}}/wham/usage",
                headers: [
                    "Authorization": "Bearer {{accessToken}}",
                    "chatgpt-account-id": "{{userID}}",
                    "Accept": "application/json",
                ]
            ),
            credentials: .init(baseURL: baseURL),
            mapping: .init(
                planPath: "plan_type",
                creditsRemainingPath: "credits.balance",
                primaryUsedPercentPath: "rate_limit.primary_window.used_percent",
                primaryResetAtPath: "rate_limit.primary_window.reset_at",
                primaryWindowSecondsPath: "rate_limit.primary_window.limit_window_seconds",
                secondaryUsedPercentPath: "rate_limit.secondary_window.used_percent",
                secondaryResetAtPath: "rate_limit.secondary_window.reset_at",
                secondaryWindowSecondsPath: "rate_limit.secondary_window.limit_window_seconds"
            )
        )
    }

    private static func loadRawAuthData(from environment: [String: String]) throws -> Data? {
        if let sourcePath = environment[authSourcePathEnvironmentKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !sourcePath.isEmpty,
           FileManager.default.fileExists(atPath: sourcePath)
        {
            return try Data(contentsOf: URL(fileURLWithPath: sourcePath))
        }

        guard let codexHome = environment["CODEX_HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !codexHome.isEmpty
        else {
            return nil
        }

        let authURL = URL(fileURLWithPath: codexHome, isDirectory: true).appendingPathComponent("auth.json")
        guard FileManager.default.fileExists(atPath: authURL.path) else {
            return nil
        }
        return try Data(contentsOf: authURL)
    }

    private func makeFetchResult(
        jsonObject: Any,
        mapping: CodexHTTPUsageQueryMapping,
        includeCredits: Bool,
        cardKind: CodexAuthSummary.CardKind?
    ) throws -> ProviderFetchResult {
        let plan = mappedStringValue(path: mapping.planPath, in: jsonObject)
        let creditsRemaining = includeCredits ? mappedDoubleValue(path: mapping.creditsRemainingPath, in: jsonObject) : nil
        let usageUsed = mappedDoubleValue(path: mapping.usageUsedPath, in: jsonObject)
        let usageTotal = mappedDoubleValue(path: mapping.usageTotalPath, in: jsonObject)
        let costToday = mappedDoubleValue(path: mapping.costTodayUSDPath, in: jsonObject)
        let costLast30Days = mappedDoubleValue(path: mapping.costLast30DaysUSDPath, in: jsonObject)

        let identity = UsageIdentity(
            accountEmail: nil,
            accountOrganization: nil,
            loginMethod: loginMethod(for: cardKind),
            plan: plan
        )

        let primaryWindow: RateWindow?
        if let usageUsed, let usageTotal {
            guard usageTotal > 0 else {
                throw CodexHTTPUsageQueryError.mappingFailed("usageTotal must be greater than zero.")
            }
            primaryWindow = RateWindow(usedPercent: min(100, max(0, (usageUsed / usageTotal) * 100)))
        } else if let primaryUsedPercent = mappedDoubleValue(path: mapping.primaryUsedPercentPath, in: jsonObject) {
            primaryWindow = makeWindow(
                usedPercent: primaryUsedPercent,
                resetAtUnix: mappedDoubleValue(path: mapping.primaryResetAtPath, in: jsonObject),
                windowSeconds: mappedDoubleValue(path: mapping.primaryWindowSecondsPath, in: jsonObject)
            )
        } else if usageUsed != nil || usageTotal != nil {
            primaryWindow = nil
        } else {
            primaryWindow = nil
        }

        let secondaryWindow: RateWindow? = {
            guard let usedPercent = mappedDoubleValue(path: mapping.secondaryUsedPercentPath, in: jsonObject) else {
                return nil
            }
            return makeWindow(
                usedPercent: usedPercent,
                resetAtUnix: mappedDoubleValue(path: mapping.secondaryResetAtPath, in: jsonObject),
                windowSeconds: mappedDoubleValue(path: mapping.secondaryWindowSecondsPath, in: jsonObject)
            )
        }()

        let credits = creditsRemaining.map { CreditsSnapshot(remaining: $0, updatedAt: Date()) }
        let cost: CostSnapshot? = (costToday != nil || costLast30Days != nil)
            ? CostSnapshot(
                todayCostUSD: costToday,
                todayTokens: nil,
                last30DaysCostUSD: costLast30Days,
                last30DaysTokens: nil,
                updatedAt: Date()
            )
            : nil

        let usage = UsageSnapshot(
            identity: identity.plan == nil && identity.loginMethod == nil ? nil : identity,
            primary: primaryWindow,
            secondary: secondaryWindow,
            tertiary: nil,
            updatedAt: Date()
        )

        guard credits != nil || primaryWindow != nil || secondaryWindow != nil || cost != nil || plan != nil else {
            throw CodexHTTPUsageQueryError.mappingFailed("No usable usage fields found.")
        }

        return ProviderFetchResult(
            usage: usage,
            credits: credits,
            cost: cost,
            sourceLabel: NSLocalizedString("usage.source.http", value: "HTTP", comment: "HTTP"),
            fetchKind: .web,
            strategyKind: .direct
        )
    }

    private func makeWindow(
        usedPercent: Double,
        resetAtUnix: Double?,
        windowSeconds: Double?
    ) -> RateWindow {
        let normalizedUsedPercent = min(100, max(0, usedPercent))
        let resetsAt = resetAtUnix.map { Date(timeIntervalSince1970: $0) }
        let resetDescription = resetsAt.map {
            String(
                format: NSLocalizedString("usage.metric.resets_at", value: "Resets %@", comment: "Resets label"),
                $0.formatted(date: .abbreviated, time: .shortened)
            )
        }
        let windowMinutes = windowSeconds.map { Int(($0 / 60.0).rounded()) }
        return RateWindow(
            usedPercent: normalizedUsedPercent,
            resetDescription: resetDescription,
            resetsAt: resetsAt,
            windowMinutes: windowMinutes
        )
    }

    private func validatedTimeout(_ rawValue: Double?) throws -> TimeInterval {
        let timeout = rawValue ?? 15
        guard timeout >= 3, timeout <= 60 else {
            throw CodexHTTPUsageQueryError.invalidConfiguration("Timeout must be between 3 and 60 seconds.")
        }
        return timeout
    }

    private func mergeCredentials(
        _ overrides: CodexHTTPUsageQueryCredentials?,
        defaults: CodexHTTPUsageQueryCredentials
    ) -> CodexHTTPUsageQueryCredentials {
        .init(
            baseURL: Self.trimmedNonEmpty(overrides?.baseURL) ?? Self.trimmedNonEmpty(defaults.baseURL),
            apiKey: Self.trimmedNonEmpty(overrides?.apiKey) ?? Self.trimmedNonEmpty(defaults.apiKey),
            accessToken: Self.trimmedNonEmpty(overrides?.accessToken) ?? Self.trimmedNonEmpty(defaults.accessToken),
            userID: Self.trimmedNonEmpty(overrides?.userID) ?? Self.trimmedNonEmpty(defaults.userID)
        )
    }

    private func substitute(_ template: String, credentials: CodexHTTPUsageQueryCredentials) -> String {
        template
            .replacingOccurrences(of: "{{baseURL}}", with: credentials.baseURL ?? "")
            .replacingOccurrences(of: "{{apiKey}}", with: credentials.apiKey ?? "")
            .replacingOccurrences(of: "{{accessToken}}", with: credentials.accessToken ?? "")
            .replacingOccurrences(of: "{{userID}}", with: credentials.userID ?? "")
    }

    private func validatedURL(_ rawURL: String, baseURL: String?) throws -> URL {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed), let scheme = url.scheme?.lowercased() else {
            throw CodexHTTPUsageQueryError.invalidConfiguration("Request URL is invalid.")
        }
        guard scheme == "https" else {
            throw CodexHTTPUsageQueryError.unsafeURL("Only HTTPS URLs are allowed.")
        }
        guard let host = url.host?.lowercased(), !host.isEmpty else {
            throw CodexHTTPUsageQueryError.unsafeURL("Request URL host is missing.")
        }
        guard !Self.isBlockedHost(host) else {
            throw CodexHTTPUsageQueryError.unsafeURL("Local and private network URLs are not allowed.")
        }

        if let baseURL = Self.trimmedNonEmpty(baseURL),
           let base = URL(string: baseURL),
           let baseScheme = base.scheme?.lowercased(),
           let baseHost = base.host?.lowercased()
        {
            let requestPort = url.port ?? Self.defaultPort(for: scheme)
            let basePort = base.port ?? Self.defaultPort(for: baseScheme)
            guard scheme == baseScheme, host == baseHost, requestPort == basePort else {
                throw CodexHTTPUsageQueryError.unsafeURL("Request URL must match the configured base URL origin.")
            }
        }

        return url
    }

    private static func defaultPort(for scheme: String) -> Int {
        scheme == "https" ? 443 : 80
    }

    private static func isBlockedHost(_ host: String) -> Bool {
        let lower = host.lowercased()
        if lower == "localhost" || lower == "::1" || lower == "0.0.0.0" {
            return true
        }
        if lower.hasPrefix("127.") {
            return true
        }
        if let ipv4 = IPv4Address(lower) {
            return ipv4.isPrivate
        }
        if lower.hasPrefix("fe80:") || lower.hasPrefix("fc") || lower.hasPrefix("fd") {
            return true
        }
        return false
    }

    private func mappedStringValue(path: String?, in root: Any) -> String? {
        guard let value = value(at: path, in: root) else { return nil }
        switch value {
        case let string as String:
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        case let number as NSNumber:
            return number.stringValue
        default:
            return String(describing: value)
        }
    }

    private func mappedDoubleValue(path: String?, in root: Any) -> Double? {
        guard let value = value(at: path, in: root) else { return nil }
        switch value {
        case let number as NSNumber:
            return number.doubleValue
        case let string as String:
            return Double(string.trimmingCharacters(in: .whitespacesAndNewlines))
        default:
            return nil
        }
    }

    private func value(at path: String?, in root: Any) -> Any? {
        guard let path = Self.trimmedNonEmpty(path) else { return nil }
        guard let tokens = Self.parsePath(path), !tokens.isEmpty else { return nil }

        var current: Any = root
        for token in tokens {
            switch token {
            case let .key(key):
                guard let dictionary = current as? [String: Any],
                      let next = dictionary[key]
                else { return nil }
                current = next
            case let .index(index):
                guard let array = current as? [Any], array.indices.contains(index) else {
                    return nil
                }
                current = array[index]
            }
        }
        return current
    }

    private enum PathToken: Equatable {
        case key(String)
        case index(Int)
    }

    private static func parsePath(_ rawPath: String) -> [PathToken]? {
        var tokens: [PathToken] = []
        var current = ""
        let chars = Array(rawPath)
        var index = 0

        func flushCurrent() {
            if !current.isEmpty {
                tokens.append(.key(current))
                current.removeAll(keepingCapacity: true)
            }
        }

        while index < chars.count {
            let char = chars[index]
            if char == "." {
                flushCurrent()
                index += 1
                continue
            }
            if char == "[" {
                flushCurrent()
                index += 1
                var number = ""
                while index < chars.count, chars[index] != "]" {
                    number.append(chars[index])
                    index += 1
                }
                guard index < chars.count, chars[index] == "]", let value = Int(number) else {
                    return nil
                }
                tokens.append(.index(value))
                index += 1
                continue
            }
            current.append(char)
            index += 1
        }
        flushCurrent()
        return tokens
    }

    private func loginMethod(for cardKind: CodexAuthSummary.CardKind?) -> String? {
        switch cardKind {
        case .officialAPIKey:
            return "api_key"
        case .relayProfile:
            return "relay"
        case .chatgptAccount:
            return "oauth"
        case .none:
            return nil
        }
    }

    private static func defaultPerformRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let session = URLSession(configuration: .ephemeral)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CodexHTTPUsageQueryError.networkFailure("HTTP usage query returned a non-HTTP response.")
        }
        return (data, httpResponse)
    }

    private static func stringValue(_ value: Any?) -> String? {
        switch value {
        case let string as String:
            return trimmedNonEmpty(string)
        case let number as NSNumber:
            return number.stringValue
        default:
            return nil
        }
    }

    private static func trimmedNonEmpty(_ raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        return raw
    }
}

private struct IPv4Address {
    let octets: [UInt8]

    init?(_ raw: String) {
        let components = raw.split(separator: ".")
        guard components.count == 4 else { return nil }
        var parsed: [UInt8] = []
        parsed.reserveCapacity(4)
        for component in components {
            guard let value = UInt8(component) else { return nil }
            parsed.append(value)
        }
        self.octets = parsed
    }

    var isPrivate: Bool {
        switch (octets[0], octets[1]) {
        case (10, _):
            return true
        case (172, 16 ... 31):
            return true
        case (192, 168):
            return true
        case (169, 254):
            return true
        default:
            return false
        }
    }
}
